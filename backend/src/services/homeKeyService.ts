import { getDatabase } from '../db/database.js';
import { TokenCrypto } from '../crypto/tokenCrypto.js';
import { AuditService } from './auditService.js';

export interface HomeRecord {
  homeId: string;
  name: string;
  timezone: string;
  meshId: string;
  meshApPassword: string;
  homeKey: string;
  keyId: number;
  createdAt: number;
}

export class HomeKeyService {
  /**
   * Retrieves home details.
   */
  public static getHome(homeId: string): HomeRecord | null {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM homes WHERE home_id = ?').get(homeId) as any;
    if (!row) return null;

    return {
      homeId: row.home_id,
      name: row.name,
      timezone: row.timezone,
      meshId: row.mesh_id,
      meshApPassword: row.mesh_ap_password,
      homeKey: row.home_key,
      keyId: row.key_id,
      createdAt: row.created_at,
    };
  }

  /**
   * Rotates the home key: increments key_id, generates a fresh 256-bit network key,
   * updates the database, and creates an audit log entry.
   */
  public static rotateHomeKey(homeId: string, requestedByUserId: string, userRole: string): HomeRecord {
    if (userRole !== 'owner') {
      throw new Error('Only the home owner can rotate the home cryptographic key');
    }

    const home = this.getHome(homeId);
    if (!home) {
      throw new Error(`Home ${homeId} not found`);
    }

    const oldKeyId = home.keyId;
    const newKeyId = oldKeyId + 1;
    const newKeyHex = TokenCrypto.generateRandomKeyHex();

    const db = getDatabase();
    db.prepare(`
      UPDATE homes
      SET home_key = ?, key_id = ?
      WHERE home_id = ?
    `).run(newKeyHex, newKeyId, homeId);

    AuditService.log('ROTATE_HOME_KEY', {
      homeId,
      userId: requestedByUserId,
      details: {
        previousKeyId: oldKeyId,
        newKeyId,
      },
    });

    return this.getHome(homeId)!;
  }

  /**
   * Returns the home key wrapped under the client/device's session or transport key.
   */
  public static getWrappedKey(
    homeId: string,
    wrappingKeyHex: string
  ): { keyId: number; wrappedKey: { wrappedHex: string; ivHex: string; tagHex: string } } {
    const home = this.getHome(homeId);
    if (!home) {
      throw new Error(`Home ${homeId} not found`);
    }

    const wrapped = TokenCrypto.wrapKey(home.homeKey, wrappingKeyHex);

    return {
      keyId: home.keyId,
      wrappedKey: wrapped,
    };
  }
}
