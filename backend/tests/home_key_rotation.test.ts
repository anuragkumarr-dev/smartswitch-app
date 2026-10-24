import { describe, it, expect, beforeEach } from 'vitest';
import { getDatabase } from '../src/db/database.js';
import { HomeKeyService } from '../src/services/homeKeyService.js';
import { AuditService } from '../src/services/auditService.js';

describe('Home Key Service & Rotation Suite (Blueprint §2.4, §3.5 & §5)', () => {
  beforeEach(() => {
    getDatabase();
  });

  it('Rotates home key, advances key_id monotonically, and records audit entry', () => {
    const initialHome = HomeKeyService.getHome('h_main')!;
    const initialKeyId = initialHome.keyId;

    const rotated = HomeKeyService.rotateHomeKey('h_main', 'usr_main_1', 'owner');
    expect(rotated.keyId).toBe(initialKeyId + 1);
    expect(rotated.homeKey).not.toBe(initialHome.homeKey);

    // Verify audit entry
    const logs = AuditService.getLogs('h_main');
    const rotateLog = logs.find((l) => l.action === 'ROTATE_HOME_KEY');
    expect(rotateLog).toBeDefined();
    expect((rotateLog as any).user_id).toBe('usr_main_1');
  });

  it('Wraps home key securely with AES-256-GCM under client wrapping key', () => {
    const wrappingKeyHex = '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';
    const result = HomeKeyService.getWrappedKey('h_main', wrappingKeyHex);

    expect(result.keyId).toBeGreaterThanOrEqual(1);
    expect(result.wrappedKey.wrappedHex).toBeDefined();
    expect(result.wrappedKey.ivHex).toHaveLength(24); // 12-byte IV = 24 hex chars
    expect(result.wrappedKey.tagHex).toHaveLength(32); // 16-byte tag = 32 hex chars
  });
});
