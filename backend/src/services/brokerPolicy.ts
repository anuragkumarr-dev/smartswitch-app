export interface ClientIdentity {
  type: 'app_user' | 'root_gateway' | 'sub_device';
  id: string; // userId or deviceId
  homeId?: string; // Home the client belongs to or is Root for
  subDeviceIds?: string[]; // If root_gateway, the list of sub-devices in its mesh
  userHomes?: string[]; // If app_user, the list of homes the user is a member of
}

export type AccessAction = 'publish' | 'subscribe';

export interface BrokerAccessDecision {
  allowed: boolean;
  reason: string;
}

/**
 * Broker Access Policy Engine (Blueprint §3.5 & §5).
 * Enforces strict topic authorization for MQTT brokers (EMQX, Mosquitto, AWS IoT).
 *
 * Topic Patterns:
 * 1. home/{homeId}/dev/{deviceId}/cmd   - app or backend -> device (via Root)
 * 2. home/{homeId}/dev/{deviceId}/state - device -> everyone (reported state)
 * 3. home/{homeId}/gw/{gatewayId}/status- Root online, topology snapshot
 * 4. home/{homeId}/events               - bound, removed, alarms
 */
export class BrokerPolicyEngine {
  public static evaluate(
    client: ClientIdentity,
    action: AccessAction,
    topic: string
  ): BrokerAccessDecision {
    const parts = topic.split('/');

    // Validate prefix
    if (parts.length < 3 || parts[0] !== 'home') {
      return { allowed: false, reason: 'Invalid topic hierarchy: must begin with home/{homeId}' };
    }

    const homeId = parts[1];
    const category = parts[2]; // 'dev', 'gw', 'events'

    // =========================================================================
    // 1. App User Evaluation
    // =========================================================================
    if (client.type === 'app_user') {
      const authorizedHomes = client.userHomes ?? [];
      if (!authorizedHomes.includes(homeId)) {
        return {
          allowed: false,
          reason: `App user ${client.id} is not a member of home ${homeId} (cross-home access blocked)`,
        };
      }

      if (action === 'subscribe') {
        // App user can subscribe to any topic within their authorized home
        return { allowed: true, reason: 'Authorized home member subscription' };
      }

      if (action === 'publish') {
        // App user can ONLY publish commands to devices: home/{homeId}/dev/{deviceId}/cmd
        if (category === 'dev' && parts.length === 5 && parts[4] === 'cmd') {
          return { allowed: true, reason: 'Authorized command publish' };
        }
        return {
          allowed: false,
          reason: 'App users are only permitted to publish to /cmd topics; cannot publish state or gw status',
        };
      }
    }

    // =========================================================================
    // 2. Sub-Device (Standalone Node) Evaluation
    // =========================================================================
    if (client.type === 'sub_device') {
      if (client.homeId !== homeId) {
        return {
          allowed: false,
          reason: `Sub-device ${client.id} does not belong to home ${homeId}`,
        };
      }

      const targetDeviceId = parts[3];

      if (category === 'dev') {
        // Sub-device can ONLY interact with its own deviceId topic
        if (targetDeviceId !== client.id) {
          return {
            allowed: false,
            reason: `Device ${client.id} cannot access other device topics (${targetDeviceId})`,
          };
        }

        if (action === 'subscribe') {
          // May subscribe to its own command topic
          if (parts[4] === 'cmd') return { allowed: true, reason: 'Device command subscribe' };
          return { allowed: false, reason: 'Devices only subscribe to their own /cmd topic' };
        }

        if (action === 'publish') {
          // May publish only to its own /state topic
          if (parts[4] === 'state') return { allowed: true, reason: 'Device state publish' };
          return { allowed: false, reason: 'Devices only publish to their own /state topic' };
        }
      }

      return { allowed: false, reason: 'Unauthorized topic for sub-device' };
    }

    // =========================================================================
    // 3. Root Gateway Evaluation (Acting for Mesh Sub-Devices)
    // =========================================================================
    if (client.type === 'root_gateway') {
      if (client.homeId !== homeId) {
        return {
          allowed: false,
          reason: `Root gateway ${client.id} is not the gateway for home ${homeId}`,
        };
      }

      const validDevices = [client.id, ...(client.subDeviceIds ?? [])];

      if (category === 'dev') {
        const targetDeviceId = parts[3];
        const subCategory = parts[4];

        if (!validDevices.includes(targetDeviceId)) {
          return {
            allowed: false,
            reason: `Root gateway ${client.id} cannot publish/subscribe for unassociated device ${targetDeviceId}`,
          };
        }

        if (action === 'subscribe') {
          // Root subscribes to /cmd for itself and all sub-devices to forward across mesh
          if (subCategory === 'cmd') return { allowed: true, reason: 'Root mesh command proxy subscription' };
        }

        if (action === 'publish') {
          // Root publishes /state for itself and any sub-device in its mesh
          if (subCategory === 'state') return { allowed: true, reason: 'Root mesh state proxy publish' };
        }
      }

      if (category === 'gw') {
        const targetGatewayId = parts[3];
        if (targetGatewayId === client.id) {
          return { allowed: true, reason: 'Root gateway status' };
        }
        return { allowed: false, reason: 'Root gateway can only publish its own status' };
      }

      if (category === 'events' && action === 'publish') {
        return { allowed: true, reason: 'Root gateway events publish' };
      }
    }

    return { allowed: false, reason: 'Access denied by default policy' };
  }
}
