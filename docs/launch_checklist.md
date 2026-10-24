# SmartSwitch Production Launch Checklist

This checklist documents every engineering, infrastructure, security, and operational prerequisite required before launching the SmartSwitch ecosystem to real customers.

---

## 1. Cloud Infrastructure & Domain Setup
- [ ] **Production Domain & DNS**: Register production domain (e.g. `api.smartswitch.io`, `mqtt.smartswitch.io`) with DNSSEC enabled and Cloudflare / Route53 DDoS mitigation.
- [ ] **Production Cloud Region**: Deploy compute and database clusters in a low-latency target region (e.g. AWS `ap-south-1` Mumbai or GCP `asia-south1`) to satisfy latency and data residency requirements.
- [ ] **Managed MQTT Broker**:
  - Deploy AWS IoT Core or clustered EMQX Enterprise on Kubernetes.
  - Configure mutual TLS (mTLS) with AWS IoT Device Defender or EMQX ACL webhooks.
  - Enable broker audit logging and metrics export to Grafana / CloudWatch.
- [ ] **Database & Backup**:
  - Migrate local SQLite database to high-availability PostgreSQL with automated point-in-time recovery (PITR) and encrypted at rest (AES-256).

---

## 2. TLS Certificates & Mobile Certificate Pinning
- [ ] **Public CA Certificates**: Provision TLS 1.3 certificates via DigiCert, Let's Encrypt, or AWS Certificate Manager for all public REST and WSS endpoints.
- [ ] **SPKI SHA-256 Fingerprints**:
  - Calculate Subject Public Key Info (SPKI) hashes for the primary leaf certificate:
    ```bash
    openssl s_client -servername api.smartswitch.io -connect api.smartswitch.io:443 | \
    openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | \
    openssl dgst -sha256 -binary | openssl enc -base64
    ```
  - Generate a secure offline **backup keypair** and calculate `backupPin`.
  - Update `CertificatePinningConfig` in Flutter `lib/data/api_client/certificate_pinning_interceptor.dart` with both pins before building release binaries.

---

## 3. Push Notifications (FCM & APNs)
- [ ] **Apple Push Notification service (APNs)**:
  - Generate an APNs Auth Key (`.p8`) in the Apple Developer Portal.
  - Record the Key ID, Team ID, and Bundle ID (`com.smartswitch.app`).
  - Configure HTTP/2 APNs client in cloud push microservice.
- [ ] **Firebase Cloud Messaging (FCM)**:
  - Create a Firebase production project and register Android package `com.smartswitch.app`.
  - Download `google-services.json` and configure `flutter_local_notifications` + `firebase_messaging`.
  - Download Firebase Service Account private key JSON for cloud push sender.

---

## 4. Factory PoP & Device Identity Pipeline
- [ ] **Hardware Security & Flash Partitioning**:
  - Enable ESP32 **Flash Encryption** (AES-XTS) and **Secure Boot v2** (RSA-3072 / ECDSA).
  - Provision factory data into an encrypted Non-Volatile Storage (NVS) partition (`nvs_keys`).
- [ ] **PoP Secret Generation**:
  - During factory flashing, generate a cryptographically random 128-bit Proof-of-Possession (`PoP`) secret using a hardware true random number generator (TRNG).
  - Print QR code sticker matching `SW1:<productId>:<deviceId>:<PoP>`.
  - Upload `(deviceId, productId, sha256(PoP))` securely into the cloud device registry database with status `unclaimed`.
- [ ] **Per-Device X.509 Certificate Pipeline**:
  - Generate per-device private key in ESP32 hardware partition or generate CSR during factory test.
  - Sign device certificate using an intermediate Device CA (stored in an HSM or AWS Private CA).

---

## 5. Security & Penetration Testing
- [ ] **Third-Party Penetration Test**:
  - Commission an independent black-box & white-box security audit covering:
    - Mobile app reverse engineering and binary analysis (Frida detection, jailbreak detection).
    - BLE provisioning packet inspection (verifying SRP6a zero-knowledge exchange).
    - WebSocket and MQTT fuzzing.
    - Cloud API penetration test (OWASP Top 10, IDOR, token replay, privilege escalation).
- [ ] **Threat Model Sign-off**:
  - Verify every countermeasure in [`docs/threat_model.md`](file:///c:/Users/abhin/Downloads/smart%20switch/docs/threat_model.md) against real hardware test rigs.

---

## 6. Privacy & DPDP Act Compliance (India & Global)
- [ ] **Digital Personal Data Protection (DPDP) Act Compliance**:
  - Provide explicit consent notices in English and scheduled regional languages prior to collecting email or phone numbers.
  - Implement self-serve data download (`GET /users/me/export`) and account deletion (`DELETE /users/me`).
  - Appoint a Data Protection Officer (DPO) and publish contact details in the app settings and privacy policy.
- [ ] **Privacy Policy & Declarations**:
  - Host privacy policy at `https://smartswitch.io/privacy`.
  - Complete Google Play Safety section (declare Bluetooth, Location/Local Network, camera permissions).
  - Complete Apple App Store Privacy Nutrition Labels.

---

## 7. App Store & Google Play Release
- [ ] **Android Production Signing**:
  - Create production upload keystore (`upload-keystore.jks`).
  - Configure Google Play App Signing.
  - Validate 64-bit ARM builds (`arm64-v8a`) via `flutter build appbundle --release`.
- [ ] **iOS Production Signing**:
  - Configure App Store Distribution Provisioning Profile and Distribution Certificate.
  - Verify Bonjour service entries and Local Network description in `Info.plist`.
  - Run `flutter build ipa --release`.
- [ ] **Store Review Submissions**:
  - Provide App Review demo credentials (`demo@smartswitch.io` / `DemoPass2026!`) with a pre-bound cloud switch and simulated video showing hardware responsiveness.
