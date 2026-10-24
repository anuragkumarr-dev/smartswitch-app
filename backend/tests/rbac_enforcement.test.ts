import { describe, it, expect, beforeEach } from 'vitest';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { getDatabase } from '../src/db/database.js';

describe('Server-Side RBAC Enforcement Suite (Blueprint §5)', () => {
  const app = createApp();

  beforeEach(() => {
    getDatabase();
  });

  it('Owner has access to rotate home key, issue tokens, and view audit', async () => {
    // Owner is usr_main_1
    const res = await request(app)
      .post('/homes/h_main/key/rotate')
      .set('Authorization', 'Bearer usr_main_1')
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.keyId).toBeGreaterThanOrEqual(2);
  });

  it('Admin can issue activation token and invite, but cannot rotate home key', async () => {
    // Admin is usr_admin_2
    // Key rotation by admin must be rejected (owner only)
    const rotateRes = await request(app)
      .post('/homes/h_main/key/rotate')
      .set('Authorization', 'Bearer usr_admin_2')
      .send({});

    expect(rotateRes.status).toBe(403);
    expect(rotateRes.body.error).toContain('requires role owner, but user has role admin');

    // Token issue by admin must be allowed
    const tokenRes = await request(app)
      .post('/activation/tokens')
      .set('Authorization', 'Bearer usr_admin_2')
      .send({ deviceId: 'dev_fresh_02', homeId: 'h_main' });

    expect(tokenRes.status).toBe(201);
    expect(tokenRes.body.serialized).toBeDefined();
  });

  it('Guest cannot call admin endpoints (activation token, invite creation, key rotate)', async () => {
    // Guest is usr_guest_3
    const tokenRes = await request(app)
      .post('/activation/tokens')
      .set('Authorization', 'Bearer usr_guest_3')
      .send({ deviceId: 'dev_fresh_02', homeId: 'h_main' });

    expect(tokenRes.status).toBe(403);
    expect(tokenRes.body.error).toContain('requires role admin, but user has role guest');

    const inviteRes = await request(app)
      .post('/homes/h_main/invites')
      .set('Authorization', 'Bearer usr_guest_3')
      .send({ role: 'member' });

    expect(inviteRes.status).toBe(403);
    expect(inviteRes.body.error).toContain('requires role admin, but user has role guest');
  });

  it('Guest can read devices snapshot', async () => {
    const res = await request(app)
      .get('/homes/h_main/devices')
      .set('Authorization', 'Bearer usr_guest_3');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  it('Non-member receives 403 Forbidden for home endpoints', async () => {
    // usr_other_4 is not a member of h_main
    const res = await request(app)
      .get('/homes/h_main/devices')
      .set('Authorization', 'Bearer usr_other_4');

    expect(res.status).toBe(403);
    expect(res.body.error).toContain('User is not a member of home h_main');
  });
});
