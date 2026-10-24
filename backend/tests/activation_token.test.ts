import { describe, it, expect, beforeEach } from 'vitest';
import { getDatabase } from '../src/db/database.js';
import { TokenService } from '../src/services/tokenService.js';
import { TokenCrypto } from '../src/crypto/tokenCrypto.js';

describe('Activation Token Security Suite (Blueprint §2.2, §2.3 & §5)', () => {
  beforeEach(() => {
    // Reset or ensure DB is loaded
    getDatabase();
  });

  it('Issues a valid signed token for unclaimed device with 10 min expiry', () => {
    const token = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_01');

    expect(token).toBeDefined();
    expect(token.serialized).toContain('.');
    expect(token.payload.deviceId).toBe('dev_fresh_01');
    expect(token.payload.homeId).toBe('h_main');
    expect(token.payload.userId).toBe('usr_main_1');
    expect(token.payload.expiresAt).toBeGreaterThan(Date.now() + 9 * 60 * 1000);
  });

  it('Consumes token and marks it consumed (single-use control)', () => {
    const token = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_02');

    const consumed = TokenService.consumeToken(token.serialized, 'dev_fresh_02', 'h_main');
    expect(consumed.tokenId).toBe(token.payload.tokenId);

    // Immediate replay must be rejected!
    expect(() => {
      TokenService.consumeToken(token.serialized, 'dev_fresh_02', 'h_main');
    }).toThrow(/already been consumed \(replay blocked\)/);
  });

  it('Rejects token for mismatched deviceId', () => {
    const token = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_03');

    expect(() => {
      TokenService.consumeToken(token.serialized, 'dev_fresh_01', 'h_main');
    }).toThrow(/Token deviceId mismatch/);
  });

  it('Rejects token for mismatched homeId', () => {
    const token = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_03');

    expect(() => {
      TokenService.consumeToken(token.serialized, 'dev_fresh_03', 'h_other_home');
    }).toThrow(/Token homeId mismatch/);
  });

  it('Rejects expired token', () => {
    const now = Date.now();
    // Forge expired payload with valid signature
    const expiredPayload = {
      tokenId: 'act_expired_test',
      userId: 'usr_main_1',
      homeId: 'h_main',
      deviceId: 'dev_fresh_01',
      createdAt: now - 20 * 60 * 1000,
      expiresAt: now - 5 * 60 * 1000, // expired 5 mins ago
    };

    const signed = TokenCrypto.signToken(expiredPayload);

    // Insert into db as unconsumed
    const db = getDatabase();
    db.prepare(`
      INSERT OR REPLACE INTO activation_tokens (token_id, user_id, home_id, device_id, serialized_token, expires_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      expiredPayload.tokenId,
      expiredPayload.userId,
      expiredPayload.homeId,
      expiredPayload.deviceId,
      signed.serialized,
      expiredPayload.expiresAt,
      expiredPayload.createdAt
    );

    expect(() => {
      TokenService.consumeToken(signed.serialized, 'dev_fresh_01', 'h_main');
    }).toThrow(/Activation token expired/);
  });
});
