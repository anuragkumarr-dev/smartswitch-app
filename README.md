# SmartSwitch Ecosystem

SmartSwitch is a resilient smart home switch system featuring:
- **Mobile Application (`lib/`):** A high-performance Flutter mobile client for local BLE onboarding, direct WebSocket control, MQTT cloud shadow synchronization, and Blynk IoT bridge support.
- **Switch Mesh Firmware (`smart_switch_mesh/`):** Multi-platform Arduino firmware (ESP32-S3, ESP32 DevKit V1, NodeMCU 1.0 / ESP8266) supporting self-organizing ESP-NOW mesh networking with dynamic leader election and Blynk IoT integration.
- **Reference Backend (`backend/`):** Express/TypeScript service with activation token minting, device registry, and MQTT message broker.

## Quick Links
- **Switch Mesh Firmware:** See [`smart_switch_mesh/README.md`](smart_switch_mesh/README.md) for pinouts, election protocol, and flashing guide.
- **Architecture & Roadmap:** See [`docs/blueprint.md`](docs/blueprint.md) for system design.
- **Agent Guidelines:** See [`AGENTS.md`](AGENTS.md) for architectural rules and conventions.
