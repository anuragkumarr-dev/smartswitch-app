import { getDatabase } from '../db/database.js';
import { TokenService } from './tokenService.js';
import { AuditService } from './auditService.js';

export interface DeviceRecord {
  deviceId: string;
  productId: string;
  status: 'unclaimed' | 'bound' | 'revoked';
  boundHomeId: string | null;
  boundUserId: string | null;
  boundRoomId: string | null;
  name: string | null;
  gangs: number;
  fwVersion: string;
  isRoot: boolean;
  boundAt: number | null;
  lastSeen: number | null;
}

export class RegistryService {
  /**
   * Retrieves a device record by deviceId.
   */
  public static getDevice(deviceId: string): DeviceRecord | null {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM device_registry WHERE device_id = ?').get(deviceId) as any;
    if (!row) return null;
    return this.mapRow(row);
  }

  /**
   * Retrieves all devices bound to a specific home.
   */
  public static getDevicesForHome(homeId: string): DeviceRecord[] {
    const db = getDatabase();
    const rows = db.prepare('SELECT * FROM device_registry WHERE bound_home_id = ?').all(homeId) as any[];
    return rows.map((r) => this.mapRow(r));
  }

  /**
   * Binds an unclaimed device using an activation token.
   * Invalidates the activation token.
   * Blocks second account from claiming an already-bound device.
   */
  public static bindDevice(params: {
    deviceId: string;
    homeId: string;
    userId: string;
    token: string;
    name?: string;
    roomId?: string;
    isRoot?: boolean;
  }): DeviceRecord {
    const db = getDatabase();

    // 1. Check current registry state
    const current = db.prepare('SELECT device_id, status, bound_home_id FROM device_registry WHERE device_id = ?').get(
      params.deviceId
    ) as { device_id: string; status: string; bound_home_id: string | null } | undefined;

    if (!current) {
      throw new Error(`Device ${params.deviceId} not found in factory registry`);
    }

    if (current.status === 'bound') {
      throw new Error(
        `Device ${params.deviceId} is already bound to home ${current.bound_home_id}. Another account cannot claim it.`
      );
    }

    if (current.status === 'revoked') {
      throw new Error(`Device ${params.deviceId} is revoked`);
    }

    // 2. Consume and cryptographically verify activation token (replays & expiry checked)
    TokenService.consumeToken(params.token, params.deviceId, params.homeId);

    // 3. Atomically update registry to bound
    const now = Date.now();
    db.prepare(`
      UPDATE device_registry
      SET status = 'bound',
          bound_home_id = ?,
          bound_user_id = ?,
          bound_room_id = ?,
          name = ?,
          is_root = ?,
          bound_at = ?,
          last_seen = ?
      WHERE device_id = ?
    `).run(
      params.homeId,
      params.userId,
      params.roomId ?? 'r_default',
      params.name ?? 'Smart Switch',
      params.isRoot ? 1 : 0,
      now,
      now,
      params.deviceId
    );

    // 4. Initialize device shadow if not already present
    db.prepare(`
      INSERT OR IGNORE INTO device_shadows (device_id, desired_json, reported_json, online, rssi, layer, ver, updated_at)
      VALUES (?, '{}', '{}', 1, -50, 1, 1, ?)
    `).run(params.deviceId, now);

    AuditService.log('BIND_DEVICE', {
      homeId: params.homeId,
      userId: params.userId,
      deviceId: params.deviceId,
      details: { name: params.name, isRoot: params.isRoot },
    });

    return this.getDevice(params.deviceId)!;
  }

  /**
   * Releases/unbinds a device. Must be owner-confirmed or admin-confirmed.
   * Reverts device status to 'unclaimed' so it can be re-provisioned after factory reset.
   */
  public static unbindDevice(params: {
    deviceId: string;
    homeId: string;
    requesterUserId: string;
    requesterRole: string;
  }): void {
    const db = getDatabase();

    if (params.requesterRole !== 'owner' && params.requesterRole !== 'admin') {
      throw new Error('Only the Home Owner or Admin can unbind and release a device');
    }

    const device = this.getDevice(params.deviceId);
    if (!device) {
      throw new Error(`Device ${params.deviceId} not found`);
    }

    if (device.boundHomeId !== params.homeId) {
      throw new Error(`Device ${params.deviceId} is not bound to home ${params.homeId}`);
    }

    // Reset device to unclaimed
    db.prepare(`
      UPDATE device_registry
      SET status = 'unclaimed',
          bound_home_id = NULL,
          bound_user_id = NULL,
          bound_room_id = NULL,
          name = NULL,
          is_root = 0,
          bound_at = NULL
      WHERE device_id = ?
    `).run(params.deviceId);

    // Delete shadow
    db.prepare('DELETE FROM device_shadows WHERE device_id = ?').run(params.deviceId);

    AuditService.log('UNBIND_DEVICE', {
      homeId: params.homeId,
      userId: params.requesterUserId,
      deviceId: params.deviceId,
      details: { requesterRole: params.requesterRole },
    });
  }

  private static mapRow(row: any): DeviceRecord {
    return {
      deviceId: row.device_id,
      productId: row.product_id,
      status: row.status,
      boundHomeId: row.bound_home_id,
      boundUserId: row.bound_user_id,
      boundRoomId: row.bound_room_id,
      name: row.name,
      gangs: row.gangs,
      fwVersion: row.fw_version,
      isRoot: row.is_root === 1,
      boundAt: row.bound_at,
      lastSeen: row.last_seen,
    };
  }
}
