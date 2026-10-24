import { getDatabase } from '../db/database.js';

export interface DeviceShadow {
  deviceId: string;
  desired: Record<string, unknown>;
  reported: Record<string, unknown>;
  online: boolean;
  rssi: number;
  layer: number;
  parentId: string | null;
  ver: number;
  updatedAt: number;
}

export class ShadowService {
  /**
   * Retrieves the current shadow snapshot for a single device.
   */
  public static getShadow(deviceId: string): DeviceShadow | null {
    const db = getDatabase();
    const row = db.prepare('SELECT * FROM device_shadows WHERE device_id = ?').get(deviceId) as any;
    if (!row) return null;
    return this.mapRow(row);
  }

  /**
   * Returns snapshot for all devices belonging to a home.
   * Matches GET /homes/{id}/devices schema.
   */
  public static getHomeSnapshot(homeId: string): Array<Record<string, unknown>> {
    const db = getDatabase();
    const rows = db
      .prepare(`
        SELECT r.device_id, r.product_id, r.name, r.bound_room_id, r.gangs, r.fw_version, r.is_root,
               s.desired_json, s.reported_json, s.online, s.rssi, s.layer, s.ver, s.updated_at
        FROM device_registry r
        LEFT JOIN device_shadows s ON r.device_id = s.device_id
        WHERE r.bound_home_id = ? AND r.status = 'bound'
      `)
      .all(homeId) as any[];

    return rows.map((r) => ({
      deviceId: r.device_id,
      productId: r.product_id,
      homeId,
      roomId: r.bound_room_id,
      name: r.name,
      gangs: r.gangs,
      fwVersion: r.fw_version,
      isRoot: r.is_root === 1,
      shadow: {
        desired: r.desired_json ? JSON.parse(r.desired_json) : {},
        reported: r.reported_json ? JSON.parse(r.reported_json) : {},
        online: r.online === 1,
        rssi: r.rssi ?? -60,
        layer: r.layer ?? 1,
        ver: r.ver ?? 1,
      },
    }));
  }

  /**
   * Updates reported device state (e.g. from MQTT or WebSocket delta).
   * Monotonically increments version `ver`.
   */
  public static updateReported(deviceId: string, delta: Record<string, unknown>, ver?: number): DeviceShadow {
    const db = getDatabase();
    const current = this.getShadow(deviceId);
    const now = Date.now();

    const mergedReported = { ...(current?.reported ?? {}), ...delta };
    const nextVer = ver ?? (current ? current.ver + 1 : 1);

    db.prepare(`
      INSERT INTO device_shadows (device_id, desired_json, reported_json, online, rssi, layer, ver, updated_at)
      VALUES (?, '{}', ?, 1, ?, ?, ?, ?)
      ON CONFLICT(device_id) DO UPDATE SET
        reported_json = excluded.reported_json,
        online = 1,
        ver = excluded.ver,
        updated_at = excluded.updated_at
    `).run(
      deviceId,
      JSON.stringify(mergedReported),
      (delta.rssi as number) ?? current?.rssi ?? -60,
      (delta.layer as number) ?? current?.layer ?? 1,
      nextVer,
      now
    );

    return this.getShadow(deviceId)!;
  }

  /**
   * Sets online status based on broker connection or last-will death message.
   */
  public static setOnlineStatus(deviceId: string, online: boolean): void {
    const db = getDatabase();
    db.prepare(`
      UPDATE device_shadows
      SET online = ?, updated_at = ?
      WHERE device_id = ?
    `).run(online ? 1 : 0, Date.now(), deviceId);
  }

  private static mapRow(row: any): DeviceShadow {
    return {
      deviceId: row.device_id,
      desired: JSON.parse(row.desired_json || '{}'),
      reported: JSON.parse(row.reported_json || '{}'),
      online: row.online === 1,
      rssi: row.rssi,
      layer: row.layer,
      parentId: row.parent_id,
      ver: row.ver,
      updatedAt: row.updated_at,
    };
  }
}
