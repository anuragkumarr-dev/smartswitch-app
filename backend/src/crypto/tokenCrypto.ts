import crypto from 'node:crypto';
import { config } from '../config/env.js';

export interface ActivationTokenPayload {
  tokenId: string;
  userId: string;
  homeId: string;
  deviceId: string;
  createdAt: number;
  expiresAt: number; // 10 minutes from creation
}

export interface SignedActivationToken {
  payload: ActivationTokenPayload;
  signature: string; // Base64 signature
  serialized: string; // Base64(payloadJson).Base64(sig)
}

export class TokenCrypto {
  private static privateKey: crypto.KeyObject | null = null;
  private static publicKey: crypto.KeyObject | null = null;

  private static getKeys(): { privateKey: crypto.KeyObject; publicKey: crypto.KeyObject } {
    if (!this.privateKey || !this.publicKey) {
      if (config.tokenPrivateKey && config.tokenPublicKey) {
        this.privateKey = crypto.createPrivateKey(config.tokenPrivateKey);
        this.publicKey = crypto.createPublicKey(config.tokenPublicKey);
      } else {
        // Fallback for tests or unconfigured environment: generate ephemeral in-memory Ed25519 keypair
        const pair = crypto.generateKeyPairSync('ed25519');
        this.privateKey = pair.privateKey;
        this.publicKey = pair.publicKey;
      }
    }
    return { privateKey: this.privateKey, publicKey: this.publicKey };
  }

  /**
   * Signs an activation token payload using Ed25519 asymmetric cryptography.
   */
  public static signToken(payload: ActivationTokenPayload): SignedActivationToken {
    const { privateKey } = this.getKeys();
    const data = Buffer.from(JSON.stringify(payload), 'utf8');
    const signature = crypto.sign(null, data, privateKey).toString('base64');
    const b64Payload = Buffer.from(data).toString('base64url');
    const serialized = `${b64Payload}.${signature}`;

    return {
      payload,
      signature,
      serialized,
    };
  }

  /**
   * Verifies an Ed25519 signed token and returns the payload if signature is valid.
   */
  public static verifyToken(serializedToken: string): ActivationTokenPayload | null {
    try {
      const parts = serializedToken.split('.');
      if (parts.length !== 2) return null;

      const [b64Payload, signature] = parts;
      const data = Buffer.from(b64Payload, 'base64url');
      const sigBuf = Buffer.from(signature, 'base64');
      const { publicKey } = this.getKeys();

      const isValid = crypto.verify(null, data, publicKey, sigBuf);
      if (!isValid) return null;

      const payload = JSON.parse(data.toString('utf8')) as ActivationTokenPayload;
      return payload;
    } catch {
      return null;
    }
  }

  /**
   * Wraps a 256-bit home key using AES-256-GCM under a target key (e.g., device transport or session key).
   */
  public static wrapKey(keyHex: string, wrappingKeyHex: string): { wrappedHex: string; ivHex: string; tagHex: string } {
    const iv = crypto.randomBytes(12);
    const keyBuf = Buffer.from(keyHex, 'hex');
    const wrappingBuf = Buffer.from(wrappingKeyHex.padStart(64, '0').slice(0, 64), 'hex');

    const cipher = crypto.createCipheriv('aes-256-gcm', wrappingBuf, iv);
    const encrypted = Buffer.concat([cipher.update(keyBuf), cipher.final()]);
    const tag = cipher.getAuthTag();

    return {
      wrappedHex: encrypted.toString('hex'),
      ivHex: iv.toString('hex'),
      tagHex: tag.toString('hex'),
    };
  }

  /**
   * Generates a random 256-bit cryptographically secure hex key.
   */
  public static generateRandomKeyHex(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  /**
   * Hashes a secret with SHA-256.
   */
  public static sha256(secret: string): string {
    return crypto.createHash('sha256').update(secret, 'utf8').digest('hex');
  }
}
