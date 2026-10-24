import crypto from 'node:crypto';
import { getDatabase } from '../db/database.js';
import { TokenCrypto, ActivationTokenPayload, SignedActivationToken } from '../crypto/tokenCrypto.js';
import { AuditService } from './auditService.js';

export class TokenService {
  /**
   * Issues a single-use signed activation token bound to (userId, homeId, deviceId).
   * Valid for 10 minutes.
   */
  public static issueToken(userId: string, homeId: string, deviceId: string): SignedActivationToken {
    const db = getDatabase();

    // 1. Check if device exists in registry
    const device = db.prepare('SELECT device_id, status FROM device_registry WHERE device_id = ?').get(deviceId) as
      | { device_id: string; status: string }
      | undefined;

    if (!device) {
      throw new Error(`Device ${deviceId} is not registered in factory database`);
    }

    if (device.status === 'bound') {
      throw new Error(`Device ${deviceId} is already bound to a home. Reset and unbind first.`);
    }

    if (device.status === 'revoked') {
      throw new Error(`Device ${deviceId} is revoked and cannot be activated`);
    }

    // 2. Build payload with 10 minute expiry
    const now = Date.now();
    const expiresAt = now + 10 * 60 * 1000; // 10 minutes
    const tokenId = `act_${now}_${crypto.randomBytes(6).toString('hex')}`;

    const payload: ActivationTokenPayload = {
      tokenId,
      userId,
      homeId,
      deviceId,
      createdAt: now,
      expiresAt,
    };

    const signed = TokenCrypto.signToken(payload);

    // 3. Persist in database
    db.prepare(`
      INSERT INTO activation_tokens (token_id, user_id, home_id, device_id, serialized_token, expires_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(tokenId, userId, homeId, deviceId, signed.serialized, expiresAt, now);

    AuditService.log('ISSUE_ACTIVATION_TOKEN', {
      homeId,
      userId,
      deviceId,
      details: { tokenId, expiresAt },
    });

    return signed;
  }

  /**
   * Consumes and verifies the activation token during device cloud onboarding.
   * Throws if expired, already used, or signatures/parameters don't match.
   */
  public static consumeToken(
    serializedToken: string,
    expectedDeviceId: string,
    expectedHomeId: string
  ): ActivationTokenPayload {
    const db = getDatabase();

    // 1. Cryptographically verify signature
    const payload = TokenCrypto.verifyToken(serializedToken);
    if (!payload) {
      throw new Error('Invalid token cryptographic signature');
    }

    // 2. Validate parameter bindings
    if (payload.deviceId !== expectedDeviceId) {
      throw new Error(`Token deviceId mismatch: token is bound to ${payload.deviceId}, requested ${expectedDeviceId}`);
    }

    if (payload.homeId !== expectedHomeId) {
      throw new Error(`Token homeId mismatch: token is bound to ${payload.homeId}, requested ${expectedHomeId}`);
    }

    // 3. Check expiry
    const now = Date.now();
    if (now > payload.expiresAt) {
      throw new Error(`Activation token expired at ${new Date(payload.expiresAt).toISOString()}`);
    }

    // 4. Check single-use state in database
    const record = db.prepare('SELECT token_id, is_consumed, expires_at FROM activation_tokens WHERE token_id = ?').get(
      payload.tokenId
    ) as { token_id: string; is_consumed: number; expires_at: number } | undefined;

    if (!record) {
      throw new Error('Activation token not found in registry');
    }

    if (record.is_consumed === 1) {
      throw new Error('Activation token has already been consumed (replay blocked)');
    }

    // 5. Mark as consumed atomically
    db.prepare(`
      UPDATE activation_tokens
      SET is_consumed = 1, consumed_at = ?
      WHERE token_id = ?
    `).run(now, payload.tokenId);

    AuditService.log('CONSUME_ACTIVATION_TOKEN', {
      homeId: payload.homeId,
      userId: payload.userId,
      deviceId: payload.deviceId,
      details: { tokenId: payload.tokenId },
    });

    return payload;
  }
}
