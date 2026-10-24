import { describe, it, expect, beforeEach } from 'vitest';
import { getDatabase } from '../src/db/database.js';
import { InviteService } from '../src/services/inviteService.js';

describe('Home Invite Expiry and Single-Use Suite (Blueprint §5)', () => {
  beforeEach(() => {
    getDatabase();
  });

  it('Creates expiring single-use invite for member or admin role', () => {
    const invite = InviteService.createInvite({
      homeId: 'h_main',
      invitedBy: 'usr_main_1',
      requesterRole: 'owner',
      role: 'member',
      durationMs: 3600 * 1000,
    });

    expect(invite.inviteId).toBeDefined();
    expect(invite.role).toBe('member');
    expect(invite.isConsumed).toBe(false);
  });

  it('Blocks creation of owner invites', () => {
    expect(() => {
      InviteService.createInvite({
        homeId: 'h_main',
        invitedBy: 'usr_main_1',
        requesterRole: 'owner',
        role: 'owner' as any,
      });
    }).toThrow(/Cannot create an invite for the owner role/);
  });

  it('Consumes invite on acceptance and blocks reuse', () => {
    const invite = InviteService.createInvite({
      homeId: 'h_main',
      invitedBy: 'usr_main_1',
      requesterRole: 'owner',
      role: 'member',
    });

    const accepted = InviteService.acceptInvite(invite.inviteId, 'usr_other_4');
    expect(accepted.homeId).toBe('h_main');
    expect(accepted.role).toBe('member');

    // Immediate reuse must be blocked
    expect(() => {
      InviteService.acceptInvite(invite.inviteId, 'usr_other_4');
    }).toThrow(/Invite has already been used/);
  });

  it('Rejects expired invite', () => {
    const invite = InviteService.createInvite({
      homeId: 'h_main',
      invitedBy: 'usr_main_1',
      requesterRole: 'owner',
      role: 'guest',
      durationMs: -1000, // already expired
    });

    expect(() => {
      InviteService.acceptInvite(invite.inviteId, 'usr_new_user');
    }).toThrow(/Invite has expired/);
  });
});
