import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { getDatabase } from '../src/db/database.js';
import { RegistryService } from '../src/services/registryService.js';
import { TokenService } from '../src/services/tokenService.js';

describe('Reset-and-Transfer Acceptance Test (Blueprint §2.3, §5)', () => {
  const app = createApp();

  beforeEach(() => {
    getDatabase();
  });

  it('Executes reset-and-transfer end-to-end with explicit owner confirmation', async () => {
    // 1. Initial State: dev_fresh_03 is bound to Home 1 (h_main) by Owner 1 (usr_main_1)
    const token1 = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_03');
    RegistryService.bindDevice({
      deviceId: 'dev_fresh_03',
      homeId: 'h_main',
      userId: 'usr_main_1',
      token: token1.serialized,
      name: 'Old Home Switch',
    });

    const boundDevice = RegistryService.getDevice('dev_fresh_03');
    expect(boundDevice?.status).toBe('bound');
    expect(boundDevice?.boundHomeId).toBe('h_main');

    // 2. Second account (usr_other_4) attempts to claim or activate this device WITHOUT unbind
    // Must be blocked by backend!
    const badTokenRes = await request(app)
      .post('/activation/tokens')
      .set('Authorization', 'Bearer usr_other_4')
      .send({ deviceId: 'dev_fresh_03', homeId: 'h_other' });

    // usr_other_4 is not in h_other yet or device is already bound
    expect(badTokenRes.status).toBeGreaterThanOrEqual(400);

    // 3. User 2 tries to consume an activation payload for dev_fresh_03
    const directConsume = await request(app)
      .post('/activation/consume')
      .send({
        token: 'invalid_token',
        deviceId: 'dev_fresh_03',
        homeId: 'h_other',
      });
    expect(directConsume.status).toBe(400);

    // 4. Physical Reset & Explicit Owner Confirmation:
    // Owner of Home 1 explicitly calls DELETE /homes/h_main/devices/dev_fresh_03
    const unbindRes = await request(app)
      .delete('/homes/h_main/devices/dev_fresh_03')
      .set('Authorization', 'Bearer usr_main_1');

    expect(unbindRes.status).toBe(200);
    expect(unbindRes.body.success).toBe(true);

    const releasedDevice = RegistryService.getDevice('dev_fresh_03');
    expect(releasedDevice?.status).toBe('unclaimed');
    expect(releasedDevice?.boundHomeId).toBeNull();

    // 5. Transfer to Home 2:
    // Now create membership for usr_other_4 in a new home h_transfer
    const db = getDatabase();
    db.prepare(`
      INSERT OR IGNORE INTO homes (home_id, name, mesh_id, mesh_ap_password, home_key, key_id, created_at)
      VALUES (?, ?, ?, ?, ?, 1, ?)
    `).run('h_transfer', 'Second Home', '998877', 'NewMeshPass!', 'fresh_home_key_hex', Date.now());

    db.prepare(`
      INSERT OR IGNORE INTO home_members (home_id, user_id, role, joined_at)
      VALUES (?, ?, 'owner', ?)
    `).run('h_transfer', 'usr_other_4', Date.now());

    // 6. Owner 2 can now successfully issue a new activation token for dev_fresh_03
    const tokenRes2 = await request(app)
      .post('/activation/tokens')
      .set('Authorization', 'Bearer usr_other_4')
      .send({ deviceId: 'dev_fresh_03', homeId: 'h_transfer' });

    expect(tokenRes2.status).toBe(201);
    const signedToken2 = tokenRes2.body.serialized;

    // 7. Device activation service consumes the new token and binds to Home 2
    const consumeRes = await request(app)
      .post('/activation/consume')
      .send({
        token: signedToken2,
        deviceId: 'dev_fresh_03',
        homeId: 'h_transfer',
        name: 'Transferred Switch in Home 2',
      });

    expect(consumeRes.status).toBe(200);
    expect(consumeRes.body.success).toBe(true);

    // 8. Verify the device is now bound to Home 2 under Owner 2
    const transferred = RegistryService.getDevice('dev_fresh_03');
    expect(transferred?.status).toBe('bound');
    expect(transferred?.boundHomeId).toBe('h_transfer');
    expect(transferred?.name).toBe('Transferred Switch in Home 2');
  });
});
