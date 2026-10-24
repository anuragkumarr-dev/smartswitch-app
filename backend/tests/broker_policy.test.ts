import { describe, it, expect } from 'vitest';
import { BrokerPolicyEngine, ClientIdentity } from '../src/services/brokerPolicy.js';

describe('Broker Access Control Policy Suite (Blueprint §3.5 & §5)', () => {
  const appUser: ClientIdentity = {
    type: 'app_user',
    id: 'usr_main_1',
    userHomes: ['h_main'],
  };

  const rootGateway: ClientIdentity = {
    type: 'root_gateway',
    id: 'dev_root_01',
    homeId: 'h_main',
    subDeviceIds: ['dev_sub_02', 'dev_sub_03'],
  };

  const subDevice: ClientIdentity = {
    type: 'sub_device',
    id: 'dev_sub_02',
    homeId: 'h_main',
  };

  // ===========================================================================
  // App User ACL Tests
  // ===========================================================================
  it('Allows app user to subscribe to home topics within their own home', () => {
    const dec = BrokerPolicyEngine.evaluate(appUser, 'subscribe', 'home/h_main/dev/dev_sub_02/state');
    expect(dec.allowed).toBe(true);
  });

  it('Denies app user from subscribing or publishing to a foreign home (cross-home denial)', () => {
    const subDec = BrokerPolicyEngine.evaluate(appUser, 'subscribe', 'home/h_foreign/dev/dev_01/state');
    expect(subDec.allowed).toBe(false);
    expect(subDec.reason).toContain('cross-home access blocked');

    const pubDec = BrokerPolicyEngine.evaluate(appUser, 'publish', 'home/h_foreign/dev/dev_01/cmd');
    expect(pubDec.allowed).toBe(false);
    expect(pubDec.reason).toContain('cross-home access blocked');
  });

  it('Allows app user to publish commands to devices in their home', () => {
    const dec = BrokerPolicyEngine.evaluate(appUser, 'publish', 'home/h_main/dev/dev_sub_02/cmd');
    expect(dec.allowed).toBe(true);
  });

  it('Denies app user from publishing device state or gateway status', () => {
    const statePub = BrokerPolicyEngine.evaluate(appUser, 'publish', 'home/h_main/dev/dev_sub_02/state');
    expect(statePub.allowed).toBe(false);
    expect(statePub.reason).toContain('only permitted to publish to /cmd topics');

    const gwPub = BrokerPolicyEngine.evaluate(appUser, 'publish', 'home/h_main/gw/dev_root_01/status');
    expect(gwPub.allowed).toBe(false);
  });

  // ===========================================================================
  // Device & Sub-device ACL Tests
  // ===========================================================================
  it('Allows sub-device to publish its own state and subscribe to its own cmd', () => {
    const pubState = BrokerPolicyEngine.evaluate(subDevice, 'publish', 'home/h_main/dev/dev_sub_02/state');
    expect(pubState.allowed).toBe(true);

    const subCmd = BrokerPolicyEngine.evaluate(subDevice, 'subscribe', 'home/h_main/dev/dev_sub_02/cmd');
    expect(subCmd.allowed).toBe(true);
  });

  it('Denies sub-device from publishing or subscribing to another device (device-to-device denial)', () => {
    const pubOther = BrokerPolicyEngine.evaluate(subDevice, 'publish', 'home/h_main/dev/dev_sub_03/state');
    expect(pubOther.allowed).toBe(false);
    expect(pubOther.reason).toContain('cannot access other device topics');

    const subOther = BrokerPolicyEngine.evaluate(subDevice, 'subscribe', 'home/h_main/dev/dev_sub_03/cmd');
    expect(subOther.allowed).toBe(false);
  });

  // ===========================================================================
  // Root Gateway ACL Tests (Acting for Mesh Sub-devices)
  // ===========================================================================
  it('Allows Root Gateway to proxy state and cmd for itself and associated sub-devices', () => {
    // Root acting for sub-device 02
    const pubSubState = BrokerPolicyEngine.evaluate(rootGateway, 'publish', 'home/h_main/dev/dev_sub_02/state');
    expect(pubSubState.allowed).toBe(true);

    const subSubCmd = BrokerPolicyEngine.evaluate(rootGateway, 'subscribe', 'home/h_main/dev/dev_sub_02/cmd');
    expect(subSubCmd.allowed).toBe(true);

    // Root status
    const pubGwStatus = BrokerPolicyEngine.evaluate(rootGateway, 'publish', 'home/h_main/gw/dev_root_01/status');
    expect(pubGwStatus.allowed).toBe(true);
  });

  it('Denies Root Gateway from accessing devices not in its mesh', () => {
    const pubUnassociated = BrokerPolicyEngine.evaluate(
      rootGateway,
      'publish',
      'home/h_main/dev/dev_unknown_99/state'
    );
    expect(pubUnassociated.allowed).toBe(false);
    expect(pubUnassociated.reason).toContain('unassociated device');
  });
});
