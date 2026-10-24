# SmartSwitch Threat Model & Security Controls

This document details the threat model for the SmartSwitch ecosystem (Blueprint §2.3, §2.4, §3.4, §3.5, and §5). It enumerates the threat vectors, attacker goals, countermeasure controls, and corresponding verification test suites.

---

## 1. Threat Matrix

| Threat Vector | Description & Attacker Goal | Countermeasure Control | Verification Phase & Test |
|---|---|---|---|
| **Neighbour Adoption** | A neighbour attempts to scan, claim, or adopt a newly installed switch in an adjacent apartment using Bluetooth or Wi-Fi. | • Physical possession proof: QR code embeds unique high-entropy Proof-of-Possession (PoP) secret.<br>• ESP-IDF Security 2 (SRP6a) mutual handshake; eavesdroppers learn nothing.<br>• Targeted BLE scanning by `deviceId` matches only the scanned QR.<br>• Provisioned devices disable BLE advertisement immediately upon joining mesh. | Phase 1 (`test/provisioning_test.dart`) & Phase 5A (`test/core/security/security_audit_test.dart`) |
| **Token Replay** | An attacker captures an activation token over the network and attempts to replay it to bind a rogue device or re-claim a device. | • Single-use activation tokens cryptographically bound to `(userId, homeId, deviceId)`.<br>• Monotonic counter and short expiration (10 minutes).<br>• Backend invalidates token immediately upon first redemption in cloud registry. | Phase 1 & Phase 5A (`test/core/security/invite_and_tokens_test.dart`) |
| **Stolen Phone** | An unauthorized person obtains physical access to an unlocked or lost phone to switch appliances or inspect keys. | • Optional biometric app lock (`local_auth`) requiring fingerprint or Face ID.<br>• Sensitive secrets (refresh tokens, `homeKey`, `key_id`) stored strictly in hardware-backed secure storage (iOS Keychain / Android KeyStore EncryptedSharedPreferences).<br>• Remote session revocation and instant secure storage purge on logout. | Phase 5A (`test/core/security/auth_and_secure_store_test.dart`) |
| **Cloned `deviceId`** | A malicious manufacturer or attacker flashes a valid `deviceId` onto unauthorized hardware to impersonate a legitimate switch. | • Cloud manufacturing registry tracks device lifecycle (`unclaimed`, `bound`, `revoked`).<br>• Per-device X.509 client certificate stored in hardware secure partition.<br>• Root gateway and backend reject duplicate concurrent client registrations. | Blueprint §2.3 & Phase 5A (`docs/threat_model.md`) |
| **Malicious Invite** | An attacker intercepts, tampers with, or reuses a home invitation code or link to gain unauthorized home access. | • Role-based access control: Only `Owner` and `Admin` can generate invites.<br>• Cryptographic signature verification (`HMAC-SHA256`).<br>• Strict single-use flag (`isConsumed`) marked upon first use.<br>• Hard expiration timestamp checked before redemption.<br>• Prohibition against generating `Owner` invites. | Phase 5A (`test/core/security/invite_and_tokens_test.dart`) |
| **Rogue Mesh Node** | An unauthorized ESP32 node attempts to join the local ESP-WIFI-MESH network to inject switching packets or bridge traffic. | • Isolated mesh credentials per home: unique `meshId`, random 16+ character AP password (`meshApPassword`), and AES-128 network key.<br>• `nonmesh_max_connection = 0` configured in firmware.<br>• Root serializes commands; untrusted packets lacking AES-GCM envelope are dropped. | Blueprint §2.3 & §2.4 (`test/transport/local_crypto_test.dart`) |
| **MITM on LAN** | An adversary on the same local Wi-Fi router attempts to sniff or alter WebSocket packets between phone and Root switch. | • Application-layer AES-256-GCM authenticated encryption.<br>• Ephemeral session key derived via HKDF-SHA256 from the pre-shared `homeKey` and random nonces during challenge-response handshake.<br>• Monotonic packet counters prevent replay or reordering.<br>• Dynamic IP changes handled with Root address re-discovery. | Phase 2 (`test/transport/local_crypto_test.dart`) & Phase 5A (`test/core/security/key_rotation_test.dart`) |
| **MITM on Cloud** | A network attacker intercepts WAN traffic between mobile app, cloud backend, and MQTT broker. | • TLS 1.3 encryption with strict Certificate Pinning (`Dio` SPKI SHA-256 hash checking).<br>• Dual-pin support (`primaryPin` + `backupPin`) for zero-downtime certificate rotation.<br>• Mutual TLS (mTLS) for Root-to-broker connections.<br>• Rejection of untrusted or altered certificates. | Phase 5A (`test/data/api_client/certificate_pinning_test.dart`) |

---

## 2. Role-Based Access Control (RBAC) Enforcement Matrix

| Action | Owner | Admin | Member | Guest |
|---|:---:|:---:|:---:|:---:|
| **Control Switches (`toggleSwitch`)** | ✅ Allowed | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **View Topology & Diagnostics (`viewDiagnostics`)** | ✅ Allowed | ✅ Allowed | ✅ Allowed | ✅ Allowed |
| **Edit Schedules & Timers (`editSchedules`)** | ✅ Allowed | ✅ Allowed | ✅ Allowed | ❌ Blocked |
| **Add Device via BLE (`addDevice`)** | ✅ Allowed | ✅ Allowed | ❌ Blocked | ❌ Blocked |
| **Remove Device (`removeDevice`)** | ✅ Allowed | ✅ Allowed | ❌ Blocked | ❌ Blocked |
| **Invite Members (`inviteMember`)** | ✅ Allowed | ✅ Allowed | ❌ Blocked | ❌ Blocked |
| **Re-elect Root Gateway (`reElectRoot`)** | ✅ Allowed | ✅ Allowed | ❌ Blocked | ❌ Blocked |
| **Change Member Roles (`changeRoles`)** | ✅ Allowed | ❌ Blocked | ❌ Blocked | ❌ Blocked |
| **Factory Reset Home (`factoryReset`)** | ✅ Allowed | ❌ Blocked | ❌ Blocked | ❌ Blocked |

> [!IMPORTANT]
> Permissions are checked **both** at the UI presentation layer (hiding or disabling interactive buttons and navigation links) and enforced in the state layer (`DevicesNotifier`, `HomesNotifier`, and `InviteService`), raising `UnauthorizedRoleException` if bypassed.

---

## 3. Cryptographic Key Lifecycle & Zero-Leakage Policy

1. **Storage Isolation**:
   - `homeKey`, `key_id`, access tokens, and refresh tokens are stored exclusively in `FlutterSecureStorage` (iOS Keychain / Android EncryptedSharedPreferences).
   - Plaintext keys and tokens are **never** committed to SQLite databases, disk caches, or SharedPreferences.

2. **Key Rotation Protocol**:
   - When a security compromise occurs or a member is removed from a Home, the cloud rotates the `key_id` and distributes a new wrapped network key.
   - Mobile app receives the new `key_id`, un-wraps the new key, saves it to `SecureKeyStore`, updates `LocalTransport`, re-derives the local session key, and reconnects to the Root switch seamlessly.

3. **Log Sanitization**:
   - All runtime loggers wrap diagnostic output in `SecureLogger.sanitize()`.
   - Regular expressions scrub Bearer tokens, refresh tokens, PoP secrets, home keys, and Wi-Fi/mesh passwords from logs.
