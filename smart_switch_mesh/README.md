# Smart Switch Mesh Firmware (ESP-NOW + Blynk IoT)

Unified multi-platform Arduino sketch (`smart_switch_mesh.ino`) supporting **ESP32-S3 DevKit**, **ESP32 DevKit V1 (ESP32-WROOM-32)**, and **NodeMCU 1.0 (ESP-12E) / WeMos D1 (ESP8266)**.

The firmware implements a self-organizing mesh network using **ESP-NOW** for low-latency peer-to-peer communication and dynamically elects the node with the best Wi-Fi link as **Master** to bridge all mesh nodes to **Blynk IoT**.

---

## ⚡ Key Capabilities

- **Zero-Cloud Local Mesh:** Slaves communicate directly with the Master over ESP-NOW without needing separate Wi-Fi connections to the home router.
- **Dynamic Leader Election (v2 Stable):**
  - Continuous Wi-Fi RSSI monitoring with exponential moving average.
  - Term-based election hand-over with challenge hold times (`CHALLENGE_HOLD_MS = 25s`) and hysteresis (`HYSTERESIS_DB = 8dB`) to prevent flapping.
  - Automatic failover if the Master loses Wi-Fi connectivity or goes offline.
- **Dynamic Virtual Pin Mapping (V0 – V15):**
  - **V0:** Master node's relay.
  - **V1 – V15:** Slaves dynamically assigned by sorted MAC address order.
  - Bidirectional synchronization with ACK and retry logic.
- **Local Control & Resilience:**
  - Debounced hardware push button toggle on every node.
  - Relay state persistence in non-volatile storage (NVS on ESP32, EEPROM on ESP8266).
  - Automatic channel synchronization to follow the Master's Wi-Fi channel.

---

## 🔌 Hardware Pinout & Wiring

### 1. Production Mode (`BENCH_TEST_MODE 0`)

| Target Board | Relay IN Pin | Push Button Pin (to GND) |
|---|---|---|
| **NodeMCU 1.0 (ESP-12E / ESP8266)** | `D6` (GPIO 12) | `D7` (GPIO 13) |
| **ESP32 DevKit V1 (ESP32-WROOM-32)** | `GPIO 26` | `GPIO 27` |
| **ESP32-S3 DevKit** | `GPIO 41` | `GPIO 13` |

> *Note:* By default, active-HIGH relays are assumed (`RELAY_ON = HIGH`). If using active-LOW relays, swap `RELAY_ON` and `RELAY_OFF` in the sketch.

### 2. Bench Test Mode (`BENCH_TEST_MODE 1`)
Enables quick hardware testing using onboard LEDs and buttons without wiring external relays:

| Target Board | Test Relay Output | Switch / Button Input | Status Indicator |
|---|---|---|---|
| **NodeMCU 1.0 (ESP-12E)** | `D5` (GPIO 14) + Onboard LED `D4` (GPIO 2) | FLASH button `D3` (GPIO 0) | Module blue LED |
| **ESP32 DevKit V1** | GPIO 2 (Onboard Blue LED) | BOOT button (GPIO 0) | Blue LED |
| **ESP32-S3 DevKit** | GPIO 2 (Test LED) | BOOT button (GPIO 0) | Onboard RGB LED (Green = Master ON, Cyan = Slave ON, Purple pulse = Master OFF, Amber pulse = Slave OFF) |

---

## 🛠️ Build & Flashing Setup

### Requirements
1. **Arduino IDE 2.x** or **Arduino CLI**
2. **Board Packages:**
   - **ESP32:** `esp32` by Espressif Systems (v3.0.x recommended)
   - **ESP8266:** `esp8266` by ESP8266 Community (v3.1.x recommended)
3. **Libraries:**
   - `Blynk` by Volodymyr Shymanskyy (install via Arduino Library Manager)

### Configuration
Open `smart_switch_mesh.ino` and update the user configuration section:

```cpp
// ============================ USER CONFIG ========================================
#define BLYNK_TEMPLATE_ID "TMPLxxxxxxx"
#define BLYNK_TEMPLATE_NAME "Smart Switch"
#define BLYNK_AUTH_TOKEN "YOUR_BLYNK_AUTH_TOKEN" // From Blynk console device settings

static const char* WIFI_SSID = "YOUR_WIFI_SSID";     // 2.4 GHz Wi-Fi SSID
static const char* WIFI_PASS = "YOUR_WIFI_PASSWORD"; // Wi-Fi password

#define BENCH_TEST_MODE 0 // 0 = External relays/buttons, 1 = Onboard LEDs/buttons
```

---

## 🖥️ Serial Diagnostic Interface (115200 Baud)

Connect over USB Serial to view diagnostics or send single-character commands:

| Key | Command | Description |
|---|---|---|
| `t` | **Toggle Relay** | Simulates a physical push button press. |
| `m` | **Mesh Table** | Displays all discovered nodes, RSSI, channels, relay states, and V-pin assignments. |
| `f` | **Simulate Wi-Fi Drop** | Forces a simulated Wi-Fi outage for 20 seconds to test Master failover. |
| `r` | **RSSI / Election Math** | Prints real-time signal strength and leader election qualification checks. |
| `h` | **Help** | Prints the serial menu guide. |

---

## 📱 Integration with SmartSwitch Mobile App

This firmware directly integrates with the Flutter SmartSwitch app's **Blynk Bridge** feature:
- Configure your Blynk Auth Token under **Settings > Blynk Bridge Settings** in the app.
- The app syncs state seamlessly with V0–V15 datastreams, providing real-time grid toggles and live status updates for all switches on the mesh.
