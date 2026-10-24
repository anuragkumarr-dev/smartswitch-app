# AGENTS.md — SmartSwitch Project Conventions

## Key Decisions

| Decision | Detail |
|----------|--------|
| **Framework** | Flutter (Dart) — single renderer, 60/120 fps, mature BLE/MQTT/mDNS packages |
| **State management** | Riverpod (`flutter_riverpod`) — providers and notifiers |
| **Development strategy** | Mock-first — build and test with fakes/mocks before integrating real hardware or cloud services |
| **Credentials** | No real credentials, API keys, or secrets in code — ever. Use mock services and environment config |
| **Build cadence** | One phase at a time, following the roadmap in `docs/blueprint.md` |
| **Blueprint rule** | Always read `docs/blueprint.md` before starting any new phase |

## Architecture (from blueprint §3.1)

```
lib/
  core/        theme, errors, logging, result types
  data/        local_db, secure_store, api_client
  transport/   ble_provisioner, local_transport, cloud_transport, command_router
  domain/      models: Home, Room, Device, Shadow, Command, Schedule
  state/       providers: auth, homes, devices, connectivity, mesh
  features/    onboarding, home, device_control, schedules, mesh_diag, settings
```

## Phase Roadmap

| Phase | Description | Status |
|-------|-------------|--------|
| 0. Foundations | Repo, CI, design tokens, folder layout | ✅ Done |
| 1. BLE provisioning engine | QR scan, BLE session, config push, status stream | ✅ Done |
| 2. Local & cloud comms | mDNS, WebSocket, MQTT, CommandRouter | ✅ Done |
| 3. State & models | Domain models, Riverpod providers, local DB, shadow sync | ✅ Done |
| 4. Production UI | Home, control, schedules, mesh diagnostics, onboarding | ✅ Done |
| 5A. Client security & auth | Login, roles, tokens, secure storage, cert pinning | ✅ Done |
| 5B. Reference backend | Express/TS, activation tokens, device registry, Mosquitto | ✅ Done |
| Prototype: Blynk Bridge | Dynamic V16 node map, real ESP-NOW hardware control | ✅ Done |

## Rules for AI Agents

1. **Read `docs/blueprint.md`** before starting any phase.
2. **Mock first** — never depend on real hardware or cloud in tests.
3. **No real credentials** in source code. Use placeholder/mock values.
4. **One phase at a time** — complete and verify before moving on.
5. **Preserve comments and docs** — don't remove existing documentation unless explicitly asked.
6. **Follow the folder layout** — place code in the correct layer per §3.1.
7. **Design tokens** — use `core/theme.dart` tokens, never hard-coded colours or sizes.
