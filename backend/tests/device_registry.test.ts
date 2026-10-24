import { describe, it, expect, beforeEach } from 'vitest';
import { getDatabase } from '../src/db/database.js';
import { RegistryService } from '../src/services/registryService.js';
import { TokenService } from '../src/services/tokenService.js';

describe('Device Registry & Anti-Hijack Suite (Blueprint §2.3 & §5)', () => {
  beforeEach(() => {
    getDatabase();
  });

  it('Binds an unclaimed device using valid token and transitions state to bound', () => {
    const token = TokenService.issueToken('usr_main_1', 'h_main', 'dev_fresh_01');

    const bound = RegistryService.bindDevice({
      deviceId: 'dev_fresh_01',
      homeId: 'h_main',
      userId: 'usr_main_1',
      token: token.serialized,
      name: 'Hall Switch 1G',
      roomId: 'r_hall',
      isRoot: true,
    });

    expect(bound.status).toBe('bound');
    expect(bound.boundHomeId).toBe('h_main');
    expect(bound.isRoot).toBe(true);
    expect(bound.name).toBe('Hall Switch 1G');
  });

  it('Strictly prevents a second account or home from claiming an already-bound device', () => {
    // Attempting to request activation token for already-bound device fails at issuance
    expect(() => {
      TokenService.issueToken('usr_other_4', 'h_other', 'dev_bound_root');
    }).toThrow(/already bound to a home/);

    // Attempting to bind directly with any token also fails in RegistryService
    expect(() => {
      RegistryService.bindDevice({
        deviceId: 'dev_bound_root',
        homeId: 'h_other',
        userId: 'usr_other_4',
        token: 'fake.token',
      });
    }).toThrow(/already bound to home h_main\. Another account cannot claim it\./);
  });

  it('Allows owner-confirmed unbind and releases device to unclaimed state', () => {
    // Unbind dev_fresh_01 by owner
    RegistryService.unbindDevice({
      deviceId: 'dev_fresh_01',
      homeId: 'h_main',
      requesterUserId: 'usr_main_1',
      requesterRole: 'owner',
    });

    const released = RegistryService.getDevice('dev_fresh_01');
    expect(released).toBeDefined();
    expect(released!.status).toBe('unclaimed');
    expect(released!.boundHomeId).toBeNull();
  });

  it('Blocks non-admin / non-owner from unbinding a device', () => {
    expect(() => {
      RegistryService.unbindDevice({
        deviceId: 'dev_bound_root',
        homeId: 'h_main',
        requesterUserId: 'usr_guest_3',
        requesterRole: 'guest',
      });
    }).toThrow(/Only the Home Owner or Admin can unbind and release a device/);
  });
});
