# SmartSwitch Protocol Specification (v1)

## 1. Overview

The SmartSwitch system employs a unified message envelope across all communication paths:
- **Local LAN**: Persistent WebSocket connection from phone to Root switch with application-layer AES-GCM encryption over TCP.
- **Cloud WAN**: MQTT over WebSocket Secure (WSS) with TLS to cloud broker (e.g., AWS IoT Core / EMQX).
- **ESP-WIFI-MESH**: Internal packet routing between Root gateway and sub-nodes.

---

## 2. JSON Message Envelope

All command, state, and acknowledgement messages share a common JSON envelope structure.

```json
{
  "v": 1,
  "type": "cmd",
  "deviceId": "dev_living_switch_01",
  "commandId": "c_1729683920_a1b2c3d4",
  "desired": {
    "gang1": { "on": true }
  },
  "reported": {
    "gang1": { "on": true },
    "online": true,
    "rssi": -58,
    "layer": 1,
    "fw": "1.0.0",
    "ver": 104
  },
  "ver": 104,
  "ts": 1729683920000
}
```

### 2.1 Envelope Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `v` | integer | Yes | Protocol version. Current version is `1`. |
| `type` | string | Yes | Message type: `cmd`, `ack`, `state`, `heartbeat`, `handshake_init`, `handshake_resp`, `handshake_confirm`, `error`. |
| `deviceId` | string | Yes | Target or reporting switch identifier. |
| `commandId` | string | Yes | Unique idempotency key (e.g. `c_<timestamp>_<random>`). |
| `desired` | object | Optional | Desired state payload sent to device (commands). |
| `reported` | object | Optional | Reported state payload published by device. |
| `ver` | integer | Optional | Monotonically increasing state version counter. |
| `ts` | integer | Yes | Unix timestamp in milliseconds when the message was originated. |

---

## 3. Message Types

### 3.1 `cmd` (Command)
Sent from phone app or backend to change device state. Commands are **absolute** (`{"gang1": {"on": true}}`), never relative (`"toggle"`).
```json
{
  "v": 1,
  "type": "cmd",
  "deviceId": "dev_01",
  "commandId": "c_1729683920001_8f9a",
  "desired": { "gang1": { "on": true } },
  "ts": 1729683920001
}
```

### 3.2 `ack` (Acknowledgement)
Returned by the Root switch immediately after receiving and de-duplicating a command.
```json
{
  "v": 1,
  "type": "ack",
  "deviceId": "dev_01",
  "commandId": "c_1729683920001_8f9a",
  "reported": { "gang1": { "on": true } },
  "ver": 105,
  "ts": 1729683920015
}
```

### 3.3 `state` (Device Shadow Report)
Broadcast whenever physical actuation or status change occurs.
```json
{
  "v": 1,
  "type": "state",
  "deviceId": "dev_01",
  "commandId": "c_1729683920001_8f9a",
  "reported": {
    "gang1": { "on": true },
    "backlight": { "mode": "dim", "level": 30 },
    "online": true,
    "rssi": -58,
    "layer": 1,
    "fw": "1.0.0",
    "ver": 105
  },
  "ver": 105,
  "ts": 1729683920020
}
```

### 3.4 `heartbeat`
Exchanged every 5 seconds between phone and Root switch over WebSocket to verify reachability.
```json
{
  "v": 1,
  "type": "heartbeat",
  "deviceId": "gateway_root",
  "commandId": "hb_1729683925000",
  "ts": 1729683925000
}
```

---

## 4. Local Transport Security (AES-GCM + HKDF)

To prevent eavesdropping or tampering by local network attackers, WebSocket messages are encrypted at the application layer using **AES-256-GCM** with keys derived from the shared **Home Key** via **HKDF-SHA256**.

### 4.1 Handshake Sequence
1. **Client Hello (`handshake_init`)**:
   Client generates a random 16-byte nonce `clientNonce` (hex-encoded) and sends:
   ```json
   {
     "v": 1,
     "type": "handshake_init",
     "deviceId": "gateway_root",
     "commandId": "hs_init_1",
     "desired": { "clientNonce": "<32 hex chars>" },
     "ts": 1729683900000
   }
   ```
2. **Server Challenge (`handshake_resp`)**:
   Root switch generates a random 16-byte nonce `serverNonce` and returns:
   ```json
   {
     "v": 1,
     "type": "handshake_resp",
     "deviceId": "gateway_root",
     "commandId": "hs_init_1",
     "reported": { "serverNonce": "<32 hex chars>" },
     "ts": 1729683900010
   }
   ```
3. **Session Key Derivation**:
   Both parties compute:
   $$\text{SessionKey} = \text{HKDF-SHA256}(\text{IKM}=\text{HomeKey}, \text{salt}=\text{clientNonce} \parallel \text{serverNonce}, \text{info}=\text{"smartswitch-local-session"}, \text{len}=32)$$
4. **Encrypted Confirmation (`handshake_confirm`)**:
   Client sends an encrypted handshake verification message. Once verified by the Root, the session transitions to `authenticated`.

### 4.2 Application-Layer Framing
After handshake, WebSocket binary frames carry:
`[ 12-byte IV/Nonce ] [ Ciphertext ] [ 16-byte GCM Tag ]`
- Nonce is composed of an 8-byte fixed prefix plus a 4-byte monotonic counter (big-endian).
- Any frame failing MAC validation or with a non-monotonic counter is rejected and dropped.

---

## 5. Cloud Transport Topics (MQTT)

MQTT topics follow a strict hierarchy with broker-enforced ACLs:

| Topic Pattern | Direction | Description |
|---|---|---|
| `home/{homeId}/dev/{deviceId}/cmd` | Phone/Cloud $\rightarrow$ Root | Desired state commands targeting a device |
| `home/{homeId}/dev/{deviceId}/state` | Root $\rightarrow$ Phone/Cloud | Retained reported shadow of device state |
| `home/{homeId}/gw/{gatewayId}/status` | Root $\rightarrow$ Phone/Cloud | Gateway online status and mesh topology snapshot (LWT) |
| `home/{homeId}/events` | Device $\rightarrow$ Phone/Cloud | Bind, unbind, OTA progress, and alarm events |

### 5.1 Last-Will and Testament (LWT)
When the Root switch connects to the MQTT broker, it registers an LWT:
- **Topic**: `home/{homeId}/gw/{gatewayId}/status`
- **Payload**: `{"online": false, "ts": <timestamp>, "reason": "unexpected_disconnect"}`
- **QoS**: 1, **Retain**: true

---

## 6. Dual-Path Routing and Idempotency Rules

1. **Local-First with Fallback**:
   - Phone checks `local.isReachable(gatewayId)`.
   - If reachable, sends command locally with an **800 ms** timeout.
   - If local times out or is unreachable, falls back to Cloud with a **4 s** timeout.
2. **Idempotency De-duplication**:
   - Every command carries an immutable `commandId`.
   - Devices and the Root switch maintain a rolling cache of recent `commandId`s (last 200 commands or 60 seconds).
   - If a duplicate `commandId` arrives on both Local and Cloud paths, the device executes the command **exactly once** and returns the cached ACK.
3. **Command Expiry**:
   - Commands older than **30 seconds** (`current_time - ts > 30000 ms`) are rejected (`CmdResult.expired`) and never replayed.
4. **Monotonic Versioning (`ver`)**:
   - State reports carry a monotonic integer `ver`.
   - Clients and brokers ignore any report with `ver <= current_held_ver`.
