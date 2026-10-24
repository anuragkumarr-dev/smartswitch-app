# SmartSwitch Reference Backend Setup & Developer Guide

## 1. Overview
The reference backend (`backend/`) implements the cloud API, activation token service, device registry, home key service, and broker access control policies according to **Blueprint §2, §3.5, §3.6, and §5**.

Key Characteristics:
- **Language & Runtime**: Node.js 22 LTS with TypeScript (`tsx`, `vitest`).
- **Database**: Local SQLite database via `better-sqlite3` (zero cloud dependencies, supports in-memory `:memory:` for high-speed tests).
- **Asymmetric Cryptography**: Single-use activation tokens signed with **Ed25519** (or ES256) via native `node:crypto`.
- **Zero Secrets in Code**: Environment configuration is parsed from a gitignored `.env` file (copied from `.env.example`).
- **Containerization**: `docker-compose.yml` orchestrates the backend along with an Eclipse Mosquitto MQTT broker (supporting TCP port `1883` and WebSocket port `9001`).

---

## 2. Quickstart: Running Locally

### Step 1: Environment Setup
Navigate to `backend/` and copy the example environment file:
```bash
cd backend
cp .env.example .env
```
*(On Windows PowerShell: `Copy-Item .env.example .env`)*

### Step 2: Install Dependencies
```bash
npm install
```

### Step 3: Run Automated Test Suite
Run the 29 automated security, token replay, anti-hijack, and broker policy tests:
```bash
npm test
```

### Step 4: Start Development Server
```bash
npm start
```
The server will boot and display:
```
[SmartSwitch Backend] Listening on http://0.0.0.0:3000
[SmartSwitch Backend] Environment: development
```

Health check verification:
```bash
curl http://localhost:3000/health
# {"status":"ok","timestamp":1729760000000}
```

---

## 3. Running with Docker Compose

To run the complete stack (Backend + Mosquitto MQTT Broker) with containerization:

```bash
cd backend
docker-compose up --build
```

Ports mapped:
- `http://localhost:3000`: REST API (Activation tokens, snapshots, invites, keys)
- `mqtt://localhost:1883`: MQTT TCP Broker
- `ws://localhost:9001`: MQTT over WebSockets

---

## 4. Connecting the Flutter App (`DioApiClient`)

To point the Flutter mobile application's [`DioApiClient`](file:///c:/Users/abhin/Downloads/smart%20switch/lib/data/api_client/dio_api_client.dart) to the local reference backend:

### In Flutter:
```dart
import 'package:smartswitch/data/api_client/dio_api_client.dart';
import 'package:smartswitch/data/secure_store/secure_key_store.dart';
import 'package:smartswitch/core/auth/auth_service.dart';

// Android Emulator: use http://10.0.2.2:3000
// iOS Simulator / Desktop: use http://localhost:3000
// Physical Device: use http://<your_local_ip>:3000
final apiClient = DioApiClient(
  baseUrl: 'http://localhost:3000',
  secureStorage: secureKeyStore,
  authService: authService,
);

// Fetch live homes and device snapshot:
final homes = await apiClient.getHomes();
final snapshot = await apiClient.getDevicesSnapshot(homes.first.homeId);
```

---

## 5. Seeded Factory Data for Testing

The SQLite database automatically seeds test entities upon startup:
- **Homes**:
  - `h_main` ("Main Villa", Owner: `usr_main_1`, Admin: `usr_admin_2`, Guest: `usr_guest_3`)
- **Factory Unclaimed Devices**:
  - `dev_fresh_01` (1-gang switch)
  - `dev_fresh_02` (2-gang switch)
  - `dev_fresh_03` (4-gang switch)
- **Bound Devices**:
  - `dev_bound_root` (Bound to `h_main` under `usr_main_1`)

---

## 6. Broker Access Control Architecture

### MQTT Topic Hierarchy
```
home/{homeId}/dev/{deviceId}/cmd        (Publish: App User / Backend -> Subscribe: Root / Device)
home/{homeId}/dev/{deviceId}/state      (Publish: Device / Root -> Subscribe: App User)
home/{homeId}/gw/{gatewayId}/status     (Publish: Root -> Subscribe: App User)
home/{homeId}/events                   (Publish: Root -> Subscribe: App User)
```

### AWS IoT Core Policy Example (Reference Only)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["iot:Publish"],
      "Resource": [
        "arn:aws:iot:ap-south-1:123456789012:topic/home/${iot:Connection.CustomAuthorizer.homeId}/dev/${iot:ClientId}/state",
        "arn:aws:iot:ap-south-1:123456789012:topic/home/${iot:Connection.CustomAuthorizer.homeId}/gw/${iot:ClientId}/status"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["iot:Subscribe"],
      "Resource": [
        "arn:aws:iot:ap-south-1:123456789012:topicfilter/home/${iot:Connection.CustomAuthorizer.homeId}/dev/${iot:ClientId}/cmd"
      ]
    }
  ]
}
```

### EMQX Dynamic ACL Configuration Example (Reference Only)
In `emqx.conf` using HTTP authorization webhook pointing to `/broker/acl`:
```hocon
authorization {
  sources = [
    {
      type = http
      enable = true
      url = "http://localhost:3000/broker/acl"
      method = post
      headers { "Content-Type" = "application/json" }
      body {
        clientid = "${clientid}"
        username = "${username}"
        topic = "${topic}"
        action = "${action}"
      }
    }
  ]
}
```
