import Database from 'better-sqlite3';
import { config } from '../config/env.js';

let dbInstance: Database.Database | null = null;

export function getDatabase(): Database.Database {
  if (!dbInstance) {
    dbInstance = new Database(config.databasePath);
    // Optimize performance and enforce foreign keys
    dbInstance.pragma('journal_mode = WAL');
    dbInstance.pragma('foreign_keys = ON');
    initSchema(dbInstance);
  }
  return dbInstance;
}

export function closeDatabase(): void {
  if (dbInstance) {
    dbInstance.close();
    dbInstance = null;
  }
}

function initSchema(db: Database.Database): void {
  db.exec(`
    -- Users table
    CREATE TABLE IF NOT EXISTS users (
      user_id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      display_name TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );

    -- Homes table
    CREATE TABLE IF NOT EXISTS homes (
      home_id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
      mesh_id TEXT NOT NULL,
      mesh_ap_password TEXT NOT NULL,
      home_key TEXT NOT NULL,
      key_id INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL
    );

    -- Home members table with roles: owner, admin, member, guest
    CREATE TABLE IF NOT EXISTS home_members (
      home_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('owner', 'admin', 'member', 'guest')),
      joined_at INTEGER NOT NULL,
      PRIMARY KEY (home_id, user_id),
      FOREIGN KEY (home_id) REFERENCES homes(home_id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
    );

    -- Invites table (single-use, expiring)
    CREATE TABLE IF NOT EXISTS home_invites (
      invite_id TEXT PRIMARY KEY,
      home_id TEXT NOT NULL,
      invited_by TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('admin', 'member', 'guest')),
      expires_at INTEGER NOT NULL,
      is_consumed INTEGER NOT NULL DEFAULT 0,
      consumed_by TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (home_id) REFERENCES homes(home_id) ON DELETE CASCADE
    );

    -- Device Registry table: states 'unclaimed', 'bound', or 'revoked'
    CREATE TABLE IF NOT EXISTS device_registry (
      device_id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      pop_secret_hash TEXT NOT NULL,
      status TEXT NOT NULL CHECK(status IN ('unclaimed', 'bound', 'revoked')),
      bound_home_id TEXT,
      bound_user_id TEXT,
      bound_room_id TEXT,
      name TEXT,
      gangs INTEGER NOT NULL DEFAULT 1,
      fw_version TEXT NOT NULL DEFAULT '1.0.0',
      is_root INTEGER NOT NULL DEFAULT 0,
      bound_at INTEGER,
      last_seen INTEGER,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (bound_home_id) REFERENCES homes(home_id) ON DELETE SET NULL
    );

    -- Activation Tokens table: single-use, 10 min expiry
    CREATE TABLE IF NOT EXISTS activation_tokens (
      token_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      home_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      serialized_token TEXT NOT NULL,
      expires_at INTEGER NOT NULL,
      is_consumed INTEGER NOT NULL DEFAULT 0,
      consumed_at INTEGER,
      created_at INTEGER NOT NULL
    );

    -- Device Shadow and State table
    CREATE TABLE IF NOT EXISTS device_shadows (
      device_id TEXT PRIMARY KEY,
      desired_json TEXT NOT NULL DEFAULT '{}',
      reported_json TEXT NOT NULL DEFAULT '{}',
      online INTEGER NOT NULL DEFAULT 0,
      rssi INTEGER NOT NULL DEFAULT -60,
      layer INTEGER NOT NULL DEFAULT 1,
      parent_id TEXT,
      ver INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (device_id) REFERENCES device_registry(device_id) ON DELETE CASCADE
    );

    -- Schedules table
    CREATE TABLE IF NOT EXISTS schedules (
      schedule_id TEXT PRIMARY KEY,
      device_id TEXT NOT NULL,
      gang_index INTEGER NOT NULL DEFAULT 0,
      hour INTEGER NOT NULL,
      minute INTEGER NOT NULL,
      days_mask INTEGER NOT NULL,
      action_on INTEGER NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      is_synced INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (device_id) REFERENCES device_registry(device_id) ON DELETE CASCADE
    );

    -- Firmware OTA Jobs table
    CREATE TABLE IF NOT EXISTS ota_jobs (
      job_id TEXT PRIMARY KEY,
      product_id TEXT NOT NULL,
      target_version TEXT NOT NULL,
      firmware_url TEXT NOT NULL,
      sha256 TEXT NOT NULL,
      signature TEXT NOT NULL,
      allow_rollback INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );

    -- Audit Logs table
    CREATE TABLE IF NOT EXISTS audit_logs (
      log_id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      home_id TEXT,
      user_id TEXT,
      device_id TEXT,
      details_json TEXT,
      timestamp INTEGER NOT NULL
    );
  `);

  seedDefaultData(db);
}

function seedDefaultData(db: Database.Database): void {
  // Check if test devices already exist
  const count = db.prepare('SELECT count(*) as count FROM device_registry').get() as { count: number };
  if (count.count > 0) return;

  const now = Date.now();

  // Seed default test user (Main Owner)
  db.prepare(`
    INSERT OR IGNORE INTO users (user_id, email, password_hash, display_name, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).run('usr_main_1', 'owner@smartswitch.io', 'hashed_owner_password', 'Home Owner', now);

  // Seed default test user 2 (Admin)
  db.prepare(`
    INSERT OR IGNORE INTO users (user_id, email, password_hash, display_name, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).run('usr_admin_2', 'admin@smartswitch.io', 'hashed_admin_password', 'Home Admin', now);

  // Seed default test user 3 (Guest)
  db.prepare(`
    INSERT OR IGNORE INTO users (user_id, email, password_hash, display_name, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).run('usr_guest_3', 'guest@smartswitch.io', 'hashed_guest_password', 'Home Guest', now);

  // Seed default test user 4 (Other Home Owner)
  db.prepare(`
    INSERT OR IGNORE INTO users (user_id, email, password_hash, display_name, created_at)
    VALUES (?, ?, ?, ?, ?)
  `).run('usr_other_4', 'other@smartswitch.io', 'hashed_other_password', 'Other Owner', now);

  // Seed default home
  db.prepare(`
    INSERT OR IGNORE INTO homes (home_id, name, timezone, mesh_id, mesh_ap_password, home_key, key_id, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    'h_main',
    'Main Villa',
    'Asia/Kolkata',
    '123456',
    'MeshPassphrase2026!',
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    1,
    now
  );

  // Memberships
  db.prepare(`
    INSERT OR IGNORE INTO home_members (home_id, user_id, role, joined_at)
    VALUES (?, ?, ?, ?)
  `).run('h_main', 'usr_main_1', 'owner', now);

  db.prepare(`
    INSERT OR IGNORE INTO home_members (home_id, user_id, role, joined_at)
    VALUES (?, ?, ?, ?)
  `).run('h_main', 'usr_admin_2', 'admin', now);

  db.prepare(`
    INSERT OR IGNORE INTO home_members (home_id, user_id, role, joined_at)
    VALUES (?, ?, ?, ?)
  `).run('h_main', 'usr_guest_3', 'guest', now);

  // Seed factory unclaimed devices for testing onboarding
  // PoP secrets are stored as SHA256 hashes
  const factoryDevices = [
    { id: 'dev_fresh_01', product: 'SW-1G', popHash: 'fresh_pop_hash_01', gangs: 1 },
    { id: 'dev_fresh_02', product: 'SW-2G', popHash: 'fresh_pop_hash_02', gangs: 2 },
    { id: 'dev_fresh_03', product: 'SW-4G', popHash: 'fresh_pop_hash_03', gangs: 4 },
  ];

  for (const d of factoryDevices) {
    db.prepare(`
      INSERT OR IGNORE INTO device_registry (device_id, product_id, pop_secret_hash, status, gangs, fw_version, created_at)
      VALUES (?, ?, ?, 'unclaimed', ?, '1.0.0', ?)
    `).run(d.id, d.product, d.popHash, d.gangs, now);
  }

  // Seed one already-bound device to verify duplicate/second-claim blocking
  db.prepare(`
    INSERT OR IGNORE INTO device_registry (
      device_id, product_id, pop_secret_hash, status, bound_home_id, bound_user_id, bound_room_id, name, gangs, fw_version, is_root, bound_at, last_seen, created_at
    ) VALUES (?, ?, ?, 'bound', ?, ?, ?, ?, ?, '1.0.0', 1, ?, ?, ?)
  `).run(
    'dev_bound_root',
    'SW-2G',
    'root_pop_hash',
    'h_main',
    'usr_main_1',
    'r_living',
    'Living Room Light',
    2,
    now,
    now,
    now
  );

  // Seed shadow for dev_bound_root
  db.prepare(`
    INSERT OR IGNORE INTO device_shadows (device_id, desired_json, reported_json, online, rssi, layer, ver, updated_at)
    VALUES (?, ?, ?, 1, -55, 1, 100, ?)
  `).run(
    'dev_bound_root',
    JSON.stringify({ gang1: { on: false }, gang2: { on: false } }),
    JSON.stringify({ gang1: { on: false }, gang2: { on: false }, backlight: { mode: 'dim', level: 30 } }),
    now
  );
}
