import crypto from 'node:crypto';
import { getDatabase } from '../db/database.js';
import { AuditService } from './auditService.js';

export interface InviteRecord {
  inviteId: string;
  homeId: string;
  invitedBy: string;
  role: 'admin' | 'member' | 'guest';
  expiresAt: number;
  isConsumed: boolean;
  consumedBy: string | null;
  createdAt: number;
}

export class InviteService {
  /**
   * Generates a single-use expiring invite. Only owner or admin may invite.
   * Disallows generating owner invites.
   */
  public static createInvite(params: {
    homeId: string;
    invitedBy: string;
    requesterRole: string;
    role: 'admin' | 'member' | 'guest';
    durationMs?: number;
  }): InviteRecord {
    if (params.requesterRole !== 'owner' && params.requesterRole !== 'admin') {
      throw new Error('Only owners and admins can create home invites');
    }

    if ((params.role as any) === 'owner') {
      throw new Error('Cannot create an invite for the owner role');
    }

    const now = Date.now();
    const duration = params.durationMs ?? 24 * 60 * 60 * 1000; // default 24h
    const expiresAt = now + duration;
    const inviteId = `inv_${now}_${crypto.randomBytes(6).toString('hex')}`;

    const db = getDatabase();
    db.prepare(`
      INSERT INTO home_invites (invite_id, home_id, invited_by, role, expires_at, is_consumed, created_at)
      VALUES (?, ?, ?, ?, ?, 0, ?)
    `).run(inviteId, params.homeId, params.invitedBy, params.role, expiresAt, now);

    AuditService.log('CREATE_INVITE', {
      homeId: params.homeId,
      userId: params.invitedBy,
      details: { inviteId, role: params.role, expiresAt },
    });

    return {
      inviteId,
      homeId: params.homeId,
      invitedBy: params.invitedBy,
      role: params.role,
      expiresAt,
      isConsumed: false,
      consumedBy: null,
      createdAt: now,
    };
  }

  /**
   * Accepts and redeems an invite.
   * Enforces single-use, expiry, and adds user to home_members.
   */
  public static acceptInvite(inviteId: string, userId: string): { homeId: string; role: string } {
    const db = getDatabase();
    const invite = db.prepare('SELECT * FROM home_invites WHERE invite_id = ?').get(inviteId) as any;

    if (!invite) {
      throw new Error('Invite not found');
    }

    if (invite.is_consumed === 1) {
      throw new Error('Invite has already been used (single-use violation)');
    }

    const now = Date.now();
    if (now > invite.expires_at) {
      throw new Error('Invite has expired');
    }

    // Check if user is already a member
    const existing = db
      .prepare('SELECT role FROM home_members WHERE home_id = ? AND user_id = ?')
      .get(invite.home_id, userId) as { role: string } | undefined;

    if (existing) {
      throw new Error(`User is already a member of home ${invite.home_id} with role ${existing.role}`);
    }

    // Consume invite and add member atomically
    db.transaction(() => {
      db.prepare(`
        UPDATE home_invites
        SET is_consumed = 1, consumed_by = ?
        WHERE invite_id = ?
      `).run(userId, inviteId);

      db.prepare(`
        INSERT INTO home_members (home_id, user_id, role, joined_at)
        VALUES (?, ?, ?, ?)
      `).run(invite.home_id, userId, invite.role, now);
    })();

    AuditService.log('ACCEPT_INVITE', {
      homeId: invite.home_id,
      userId,
      details: { inviteId, assignedRole: invite.role },
    });

    return {
      homeId: invite.home_id,
      role: invite.role,
    };
  }
}
