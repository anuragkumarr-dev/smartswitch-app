import { getDatabase } from '../db/database.js';

export class AuditService {
  public static log(
    action: string,
    params: { homeId?: string; userId?: string; deviceId?: string; details?: Record<string, unknown> }
  ): void {
    const db = getDatabase();
    db.prepare(`
      INSERT INTO audit_logs (action, home_id, user_id, device_id, details_json, timestamp)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(
      action,
      params.homeId ?? null,
      params.userId ?? null,
      params.deviceId ?? null,
      params.details ? JSON.stringify(params.details) : null,
      Date.now()
    );
  }

  public static getLogs(homeId?: string): Array<Record<string, unknown>> {
    const db = getDatabase();
    if (homeId) {
      return db.prepare('SELECT * FROM audit_logs WHERE home_id = ? ORDER BY timestamp DESC').all(homeId) as Array<Record<string, unknown>>;
    }
    return db.prepare('SELECT * FROM audit_logs ORDER BY timestamp DESC').all() as Array<Record<string, unknown>>;
  }
}
