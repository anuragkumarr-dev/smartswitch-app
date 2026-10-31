/*
 =====================================================================================
  SMART SWITCH MESH  -  ESP-NOW + Blynk IoT       (Arduino-ESP32 3.x / ESP8266 3.x)
  One sketch for:
    1. ESP32-S3 DevKit
    2. ESP32 DevKit V1 (ESP32-WROOM-32)
    3. NodeMCU 1.0 (ESP-12E) / WeMos D1 (ESP8266)
  v2 = STABLE ELECTION (term-based hand-over, averaged RSSI, strict challenge rules)
 =====================================================================================

  WIRING GUIDE (when BENCH_TEST_MODE is 0):
   - NodeMCU 1.0 (ESP-12E) : Relay IN -> D6 (GPIO12)  |  Push Button -> D7 (GPIO13) to GND
   - ESP32 DevKit V1       : Relay IN -> GPIO26       |  Push Button -> GPIO27 to GND
   - ESP32-S3 DevKit       : Relay IN -> GPIO41       |  Push Button -> GPIO13 to GND

  BENCH TEST (when BENCH_TEST_MODE is 1, no relays attached):
   - NodeMCU 1.0 (ESP-12E) : Onboard LED (D4/GPIO2) + D5 (GPIO14) = relay, FLASH button (D3/GPIO0) = switch
   - ESP32 DevKit V1       : GPIO2 blue LED = relay, BOOT button (GPIO0) = switch
   - ESP32-S3              : GPIO2 test LED + onboard RGB LED = relay/status, BOOT button (GPIO0) = switch
                             RGB: solid green  = relay ON  (Master)    solid cyan   = relay ON  (Slave)
                                  purple pulse = relay OFF (Master)    amber pulse  = relay OFF (Slave)

  SERIAL MENU (115200 baud)
   t  toggle relay/LED (same as the button)      m  mesh / node table
   f  simulate Wi-Fi failure for 20 s            r  RSSI check + election math      h  help
 =====================================================================================
*/

// ============================ USER CONFIG ========================================
#define BLYNK_TEMPLATE_ID "TMPL6mAGoYmfE"
#define BLYNK_TEMPLATE_NAME "New Template"
#define BLYNK_AUTH_TOKEN "YOUR_BLYNK_AUTH_TOKEN" // Replace with your Blynk Device Auth Token
#define BLYNK_PRINT Serial                   // Blynk debug log (must be defined before the include)

static const char* WIFI_SSID = "YOUR_WIFI_SSID";     // Replace with your 2.4 GHz Wi-Fi SSID
static const char* WIFI_PASS = "YOUR_WIFI_PASSWORD"; // Replace with your Wi-Fi password

#define BENCH_TEST_MODE        0             // 0 = REAL RELAY & BUTTON PINS, 1 = onboard LEDs + BOOT/FLASH button
#define RESTORE_RELAY_ON_BOOT  1             // restore the last relay state from NVS/EEPROM after power-up
//#define EXT_BUTTON_PIN       4             // optional extra push button (to GND, internal pull-up)
//#define S3_RGB_PIN           38            // S3 boards whose RGB LED is on GPIO38 (default = RGB_BUILTIN)

#if defined(ARDUINO_ARCH_ESP8266)
  #define PLATFORM_ESP8266 1
  #include <ESP8266WiFi.h>
  #include <espnow.h>
  #include <EEPROM.h>
  #include <BlynkSimpleEsp8266.h>
  extern "C" {
    #include "user_interface.h"
  }
#else
  #define PLATFORM_ESP8266 0
  #include <WiFi.h>
  #include <esp_now.h>
  #include <esp_wifi.h>
  #include <Preferences.h>
  #include <BlynkSimpleEsp32.h>
#endif

// ============================ HARDWARE (auto-detected) ===========================
// NOTE: If your relay module is Active-LOW (turns ON when pin is LOW), swap HIGH and LOW below:
#define RELAY_ON   HIGH
#define RELAY_OFF  LOW

#if PLATFORM_ESP8266
  #define BOARD_NAME      "NodeMCU 1.0 (ESP-12E) / ESP8266"
  #define HAS_RGB_STATUS  0
  // Drive the onboard ESP-12E blue LED (GPIO2 / D4, active-LOW) in both modes for easy visual status
  #define RELAY2_PIN      2                  // NodeMCU D4 (onboard LED on ESP-12E module, active LOW)
  #define RELAY2_ON       LOW
  #define RELAY2_OFF      HIGH
  #if BENCH_TEST_MODE
    #define RELAY_PIN     14                 // NodeMCU D5 (GPIO14)
    #define BUTTON_PIN    0                  // NodeMCU D3 / onboard FLASH button (GPIO0 to GND)
  #else
    #define RELAY_PIN     12                 // NodeMCU D6 (GPIO12) -> Connect Relay IN here
    #define BUTTON_PIN    13                 // NodeMCU D7 (GPIO13) -> Connect Button between D7 and GND
  #endif
#elif CONFIG_IDF_TARGET_ESP32S3
  #define BOARD_NAME      "ESP32-S3"
  #define HAS_RGB_STATUS  1
  #if BENCH_TEST_MODE
    #define RELAY_PIN     2                  // plain test LED pin
    #define BUTTON_PIN    0                  // onboard BOOT button
  #else
    #define RELAY_PIN     41                 // Connect Relay IN to GPIO 41
    #define BUTTON_PIN    13                 // Connect Button between GPIO 13 and GND
  #endif
  #ifndef S3_RGB_PIN
    #ifdef RGB_BUILTIN
      #define S3_RGB_PIN  RGB_BUILTIN
    #else
      #define S3_RGB_PIN  48
    #endif
  #endif
#elif CONFIG_IDF_TARGET_ESP32
  #define BOARD_NAME      "ESP32 DevKit V1"
  #define HAS_RGB_STATUS  0
  #if BENCH_TEST_MODE
    #define RELAY_PIN     2                  // onboard blue LED (active HIGH)
    #define BUTTON_PIN    0                  // onboard BOOT button (active LOW)
  #else
    #define RELAY_PIN     26                 // Connect Relay IN to GPIO 26
    #define BUTTON_PIN    27                 // Connect Button between GPIO 27 and GND
  #endif
#else
  #error "Unsupported chip: this sketch targets ESP32, ESP32-S3, and ESP8266 (NodeMCU/WeMos)"
#endif

#if HAS_RGB_STATUS
  #if defined(ESP_ARDUINO_VERSION_VAL) && (ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 5))
    #define RGB_WRITE(r, g, b)  rgbLedWrite(S3_RGB_PIN, (r), (g), (b))
  #else
    #define RGB_WRITE(r, g, b)  neopixelWrite(S3_RGB_PIN, (r), (g), (b))
  #endif
#endif

// ============================ TUNING =============================================
// --- liveness / latency ---
#define HEARTBEAT_MS          2000UL         // periodic state broadcast (+0..200 ms jitter)
#define PEER_TIMEOUT_MS       8000UL         // peer counts as offline after 4 missed heartbeats
#define ELECTION_TICK_MS       250UL
#define NO_MASTER_GRACE_MS    1500UL         // "no Master" must last this long before a new election
#define BOOT_LISTEN_MS        6000UL         // after boot only listen + scan (avoids instant split-brain)
#define SCAN_REFRESH_MS      10000UL         // Slave: 1-channel RSSI sample every 10 s (feeds the average)
#define SCAN_OFFLINE_MS      20000UL         // router not visible: full scan retry interval
#define SCAN_MISSES_OFFLINE      2           // router must be missed by this many full scans in a row
// --- STABILITY: when may a healthy Master be replaced? ---
#define HYSTERESIS_DB            8           // no-Master election: nodes within this band of the best tie -> highest MAC
#define MASTER_GOOD_RSSI      (-67)          // Master link at least this strong -> nobody challenges it
#define CHALLENGE_MARGIN_DB     10           // challenger's averaged RSSI must beat the Master by this much ...
#define CHALLENGE_HOLD_MS    25000UL         // ... continuously for this long
#define CHALLENGE_MIN_SAMPLES    3           // ... based on at least this many scan samples
#define MASTER_MIN_TENURE_MS 45000UL         // a new Master can not be challenged during this time
#define DEMOTE_COOLDOWN_MS   90000UL         // a node that just lost the role can not challenge for this long
#define MASTER_WIFI_DOWN_TAKEOVER_MS 10000UL // Master reports no Wi-Fi this long -> best Slave takes over
#define RSSI_ALPHA_SCAN       0.35f          // weight of a new scan sample in the RSSI average
#define RSSI_ALPHA_LIVE       0.15f          // weight of a new live (connected) sample on the Master
// --- Master Wi-Fi ---
#define MASTER_WIFI_GRACE_MS 20000UL         // Master gives up the role if Wi-Fi stays down this long
#define WIFI_RETRY_MS        10000UL
#define WIFI_FAIL_PENALTY_MS 30000UL         // base time a node that could not reach Wi-Fi sits out (doubles, max x8)
#define SIM_FAIL_MS          20000UL         // serial 'f' test duration
#define OFFLINE_CHANNEL          1           // channel used when the router is not visible
#define RSSI_NONE             (-100)
// --- commands / Blynk ---
#define CMD_RETRY_MS           120UL         // Master -> Slave command retry period
#define CMD_MAX_TRIES           10
#define BURST_REPEATS            2           // extra heartbeats after a state change (loss protection)
#if PLATFORM_ESP8266
  #define BLYNK_CONNECT_MS   1500UL          // ESP8266 has no RTOS: keep the blocking time of loop() short
#else
  #define BLYNK_CONNECT_MS   5000UL          // runs in the Blynk task only
#endif
#define BLYNK_RETRY_BASE_MS  3000UL
#define BLYNK_RETRY_MAX_MS  30000UL
#define BLYNK_FULL_SYNC_MS  30000UL          // re-push every pin this often
#define NVS_SAVE_DELAY_MS    1500UL
#define BTN_DEBOUNCE_MS        40UL

// ============================ PROTOCOL / TYPES ===================================
#define MAX_PEERS      15                    // + this node = 16 nodes = V0..V15
#define PKT_MAGIC      0xA7
#define MSG_HEARTBEAT  1                     // periodic + on-change state broadcast (seq = Master term)
#define MSG_SET_CMD    2                     // Master -> Slave "set relay to X" (idempotent, retried until ACK)
#define MSG_ACK        3                     // Slave -> Master "applied", carries the real relay state
#define F_RELAY        0x01
#define F_MASTER       0x02
#define F_WIFI_UP      0x04
#define F_ELIGIBLE     0x08                  // sees the router and may take part in the election

typedef struct __attribute__((packed)) {
  uint8_t magic;
  uint8_t type;
  uint8_t target[6];                         // SET_CMD / ACK only
  int8_t  rssi;                              // averaged router RSSI used for the election (-100 = none)
  uint8_t channel;                           // Wi-Fi channel the sender is on
  uint8_t flags;                             // F_*
  uint8_t seq;                               // SET_CMD/ACK: command number | HEARTBEAT: Master term
} Packet;
static_assert(sizeof(Packet) == 12, "Packet layout changed");

typedef struct {
  uint8_t  mac[6];
  uint8_t  term;                             // Master term this node last advertised
  int8_t   rssi;
  uint8_t  channel;
  bool     relay;
  bool     master;
  bool     eligible;
  bool     wifiUp;
  uint32_t lastSeen;
} NodeInfo;

typedef struct { uint8_t src[6]; Packet p; } RxItem;
typedef struct { bool active; bool state; uint8_t seq; uint8_t tries; uint32_t firstTx; uint32_t nextTx; } PendingCmd;
typedef struct { uint8_t pin; uint8_t value; } UiCmd;
typedef struct { uint8_t pin; uint8_t stable; uint8_t last; uint32_t changedAt; const char* name; } Btn;

#define SCAN_FULL      1
#define SCAN_DIRECTED  2

// ============================ GLOBAL STATE =======================================
#if !PLATFORM_ESP8266
static Preferences prefs;
#endif
static uint8_t     myMac[6];
static uint8_t     BCAST[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
static bool        espnowOk = false;
static uint32_t    bootMs = 0;

static bool        relayState = false;
static bool        isMaster = false;
static bool        relayDirty = false;
static uint32_t    relayDirtyAt = 0;

static NodeInfo    nodes[MAX_PEERS];
static int         nodeCount = 0;
static PendingCmd  pend[MAX_PEERS];
static uint8_t     cmdSeq = 0;

static int         myRssi = RSSI_NONE;
static float       rssiAvg = RSSI_NONE;
static uint8_t     rssiSamples = 0;
static uint8_t     scanMisses = 0;
static uint8_t     routerChannel = 0;
static bool        scanDone = false, scanRunning = false;
static uint8_t     scanKind = 0;
static uint32_t    scanStartedAt = 0, lastScanEnd = 0;
static bool        forceScan = false, forceFullScan = false, printMathAfterScan = false;
static uint32_t    lastWifiOk = 0, lastWifiAttempt = 0;
static bool        wifiBegun = false;
static uint8_t     wifiFails = 0;
static uint32_t    simFailUntil = 0, penaltyUntil = 0;

static uint8_t     myTerm = 0;
static uint8_t     knownTerm = 0;
static uint32_t    lastDemotedAt = (uint32_t)(0UL - DEMOTE_COOLDOWN_MS);
static uint8_t     trackMac[6] = {0};
static uint8_t     trackTerm = 0;
static uint32_t    trackSince = 0;
static bool        masterDownActive = false;
static uint32_t    masterDownSince = 0;

static bool        challengeActive = false, noMasterActive = false;
static uint32_t    challengeSince = 0, noMasterSince = 0;

static uint32_t    nextHeartbeatAt = 0, nextBurstAt = 0;
static uint8_t     burstLeft = 0;

#if PLATFORM_ESP8266
  #define RXQ_LEN   12
  #define CMDQ_LEN   8
  #define TXQ_LEN    8
  static RxItem rxRing[RXQ_LEN];    static volatile uint8_t rxHead = 0, rxTail = 0;
  static UiCmd  cmdRing[CMDQ_LEN];  static volatile uint8_t cmdHead = 0, cmdTail = 0;
  static Packet txRing[TXQ_LEN];    static volatile uint8_t txHead = 0, txTail = 0;
  static volatile bool txBusy = false;
  static uint32_t txBusySince = 0;
#else
  static QueueHandle_t    rxQueue = nullptr;
  static QueueHandle_t    cmdQueue = nullptr;
#endif
static volatile bool    blynkWanted = false;
static volatile bool    blynkOnline = false;
static volatile uint8_t pinVal[16];
static volatile uint8_t pinVer[16];
static volatile bool    pinUsed[16];
static volatile bool    pinBusy[16];

static Btn btns[] = {
  { BUTTON_PIN, HIGH, HIGH, 0, "BUTTON" },
#ifdef EXT_BUTTON_PIN
  { EXT_BUTTON_PIN, HIGH, HIGH, 0, "EXT BUTTON" },
#endif
};

static void printElectionMath(uint32_t now);

// ---- queue wrappers ----
static inline void rxPush(const RxItem& it){
#if PLATFORM_ESP8266
  uint8_t n = (uint8_t)((rxHead + 1) % RXQ_LEN);
  if (n == rxTail) return;
  rxRing[rxHead] = it;
  rxHead = n;
#else
  xQueueSend(rxQueue, &it, 0);
#endif
}
static inline bool rxPop(RxItem& it){
#if PLATFORM_ESP8266
  if (rxTail == rxHead) return false;
  it = rxRing[rxTail];
  rxTail = (uint8_t)((rxTail + 1) % RXQ_LEN);
  return true;
#else
  return xQueueReceive(rxQueue, &it, 0) == pdTRUE;
#endif
}
static inline void cmdPush(const UiCmd& c){
#if PLATFORM_ESP8266
  uint8_t n = (uint8_t)((cmdHead + 1) % CMDQ_LEN);
  if (n == cmdTail) return;
  cmdRing[cmdHead] = c;
  cmdHead = n;
#else
  xQueueSend(cmdQueue, &c, 0);
#endif
}
static inline bool cmdPop(UiCmd& c){
#if PLATFORM_ESP8266
  if (cmdTail == cmdHead) return false;
  c = cmdRing[cmdTail];
  cmdTail = (uint8_t)((cmdTail + 1) % CMDQ_LEN);
  return true;
#else
  return xQueueReceive(cmdQueue, &c, 0) == pdTRUE;
#endif
}

// ============================ SMALL HELPERS ======================================
static const char* macC(const uint8_t* m){
  static char buf[4][18];
  static uint8_t k = 0;
  char* b = buf[k++ & 3];
  snprintf(b, 18, "%02X:%02X:%02X:%02X:%02X:%02X", m[0], m[1], m[2], m[3], m[4], m[5]);
  return b;
}

static const char* pinC(int pin){
  static char buf[4][5];
  static uint8_t k = 0;
  char* b = buf[k++ & 3];
  if (pin < 0) snprintf(b, 5, "-");
  else         snprintf(b, 5, "V%d", pin);
  return b;
}

static uint8_t currentChannel(){
#if PLATFORM_ESP8266
  return (uint8_t)wifi_get_channel();
#else
  uint8_t ch = 0;
  wifi_second_chan_t sc;
  if (esp_wifi_get_channel(&ch, &sc) != ESP_OK) return 0;
  return ch;
#endif
}

static bool radioSetChannel(uint8_t ch){
#if PLATFORM_ESP8266
  bool ok = wifi_set_channel(ch);
  if (espnowOk) {
    esp_now_del_peer(BCAST);
    esp_now_add_peer(BCAST, ESP_NOW_ROLE_COMBO, ch, NULL, 0);
  }
  return ok;
#else
  esp_wifi_set_promiscuous(true);
  esp_err_t e = esp_wifi_set_channel(ch, WIFI_SECOND_CHAN_NONE);
  esp_wifi_set_promiscuous(false);
  return e == ESP_OK;
#endif
}

static void lockChannel(uint8_t ch, bool force){
  if (ch < 1 || ch > 13) ch = OFFLINE_CHANNEL;
  if (WiFi.status() == WL_CONNECTED) return;
  uint8_t before = currentChannel();
  if (!force && before == ch) return;
  bool ok = radioSetChannel(ch);
  if (!ok) Serial.printf("[CHAN] set channel %u failed\n", ch);
  else if (before != ch) Serial.printf("[CHAN] locked to channel %u\n", ch);
}

static bool simFailActive(uint32_t now){ return simFailUntil != 0 && (int32_t)(simFailUntil - now) > 0; }
static bool penaltyActive(uint32_t now){ return penaltyUntil != 0 && (int32_t)(penaltyUntil - now) > 0; }

static bool isEligible(uint32_t now){
  return scanDone && myRssi > RSSI_NONE && !simFailActive(now) && !penaltyActive(now);
}
static int8_t advertisedRssi(uint32_t now){ return isEligible(now) ? (int8_t)myRssi : (int8_t)RSSI_NONE; }

static inline int8_t termDiff(uint8_t a, uint8_t b){ return (int8_t)(uint8_t)(a - b); }

static void rssiFeed(int sample, float alpha){
  if (rssiSamples == 0 || myRssi <= RSSI_NONE) rssiAvg = (float)sample;
  else rssiAvg += alpha * ((float)sample - rssiAvg);
  if (rssiSamples < 255) rssiSamples++;
  myRssi = (int)lroundf(rssiAvg);
}

// ============================ ESP-NOW TX / RX ====================================
#if PLATFORM_ESP8266
static void onEspNowSent(uint8_t* mac, uint8_t status){
  (void)mac; (void)status;
  if (txTail != txHead) txTail = (uint8_t)((txTail + 1) % TXQ_LEN);
  txBusy = false;
}
static void txTick(uint32_t now){
  if (txBusy && (uint32_t)(now - txBusySince) > 60) {
    if (txTail != txHead) txTail = (uint8_t)((txTail + 1) % TXQ_LEN);
    txBusy = false;
  }
  if (!txBusy && txTail != txHead) {
    txBusy = true;
    txBusySince = now;
    if (esp_now_send(BCAST, (uint8_t*)&txRing[txTail], sizeof(Packet)) != 0) {
      txTail = (uint8_t)((txTail + 1) % TXQ_LEN);
      txBusy = false;
    }
  }
}
#endif

static void nowTransmit(const Packet& p){
#if PLATFORM_ESP8266
  uint8_t n = (uint8_t)((txHead + 1) % TXQ_LEN);
  if (n == txTail) return;
  txRing[txHead] = p;
  txHead = n;
#else
  esp_now_send(BCAST, (const uint8_t*)&p, sizeof(p));
#endif
}

static void sendPkt(uint8_t type, const uint8_t* target, uint8_t seq, bool relayBit){
  if (!espnowOk) return;
  uint32_t now = millis();
  Packet p;
  memset(&p, 0, sizeof(p));
  p.magic   = PKT_MAGIC;
  p.type    = type;
  if (target) memcpy(p.target, target, 6);
  p.rssi    = advertisedRssi(now);
  p.channel = currentChannel();
  p.flags   = (relayBit ? F_RELAY : 0) | (isMaster ? F_MASTER : 0) |
              (WiFi.status() == WL_CONNECTED ? F_WIFI_UP : 0) | (isEligible(now) ? F_ELIGIBLE : 0);
  p.seq     = seq;
  nowTransmit(p);
}

static void sendHeartbeat(){ sendPkt(MSG_HEARTBEAT, nullptr, isMaster ? myTerm : knownTerm, relayState); }

static void startBurst(){
  sendHeartbeat();
  burstLeft = BURST_REPEATS;
  nextBurstAt = millis() + 120;
}
static void burstTick(uint32_t now){
  if (burstLeft && (int32_t)(now - nextBurstAt) >= 0) {
    sendHeartbeat();
    burstLeft--;
    nextBurstAt = now + 180;
  }
}

#if PLATFORM_ESP8266
static void onEspNowRecv(uint8_t* mac, uint8_t* data, uint8_t len){
  const uint8_t* src = mac;
#else
static void onEspNowRecv(const esp_now_recv_info_t* info, const uint8_t* data, int len){
  const uint8_t* src = info->src_addr;
#endif
  if (len != (int)sizeof(Packet) || data[0] != PKT_MAGIC) return;
  if (memcmp(src, myMac, 6) == 0) return;
  RxItem it;
  memcpy(it.src, src, 6);
  memcpy(&it.p, data, sizeof(Packet));
  rxPush(it);
}

static bool nowInit(){
#if PLATFORM_ESP8266
  if (esp_now_init() != 0) return false;
  esp_now_set_self_role(ESP_NOW_ROLE_COMBO);
  esp_now_register_recv_cb(onEspNowRecv);
  esp_now_register_send_cb(onEspNowSent);
  return esp_now_add_peer(BCAST, ESP_NOW_ROLE_COMBO, currentChannel(), NULL, 0) == 0;
#else
  if (esp_now_init() != ESP_OK) return false;
  esp_now_register_recv_cb(onEspNowRecv);
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, BCAST, 6);
  peer.channel = 0;
  peer.ifidx   = WIFI_IF_STA;
  peer.encrypt = false;
  return esp_now_add_peer(&peer) == ESP_OK;
#endif
}

static void nowRefreshPeer(){
#if PLATFORM_ESP8266
  if (!espnowOk) return;
  esp_now_del_peer(BCAST);
  esp_now_add_peer(BCAST, ESP_NOW_ROLE_COMBO, currentChannel(), NULL, 0);
#endif
}

// ============================ RELAY + NVS ========================================
static void relayWrite(bool on){
  digitalWrite(RELAY_PIN, on ? RELAY_ON : RELAY_OFF);
#ifdef RELAY2_PIN
  digitalWrite(RELAY2_PIN, on ? RELAY2_ON : RELAY2_OFF);
#endif
}

static void nvsBegin(){
#if PLATFORM_ESP8266
  EEPROM.begin(8);
#else
  prefs.begin("swmesh", false);
#endif
}
static bool nvsLoadRelay(){
#if PLATFORM_ESP8266
  return EEPROM.read(0) == 0xA5 && EEPROM.read(1) == 1;
#else
  return prefs.getBool("relay", false);
#endif
}
static void nvsSaveRelay(bool v){
#if PLATFORM_ESP8266
  EEPROM.write(0, 0xA5);
  EEPROM.write(1, v ? 1 : 0);
  EEPROM.commit();
#else
  prefs.putBool("relay", v);
#endif
}

static void applyRelay(bool on, const char* why){
  bool changed = (on != relayState);
  relayState = on;
  relayWrite(on);
  Serial.printf("[RELAY] %s -> %s%s\n", why, on ? "ON" : "OFF", changed ? "" : " (unchanged)");
  if (changed) {
    relayDirty = true;
    relayDirtyAt = millis();
    startBurst();
  }
}

static void persistTick(uint32_t now){
  if (relayDirty && (uint32_t)(now - relayDirtyAt) >= NVS_SAVE_DELAY_MS) {
    nvsSaveRelay(relayState);
    relayDirty = false;
    Serial.printf("[NVS] saved relay=%s\n", relayState ? "ON" : "OFF");
  }
}

// ============================ MESH TABLE =========================================
static int findNode(const uint8_t* mac){
  for (int i = 0; i < nodeCount; i++)
    if (memcmp(nodes[i].mac, mac, 6) == 0) return i;
  return -1;
}

static bool peerLive(int i, uint32_t now){ return (uint32_t)(now - nodes[i].lastSeen) <= PEER_TIMEOUT_MS; }

static int liveMasterIndex(uint32_t now){
  int best = -1;
  for (int i = 0; i < nodeCount; i++) {
    if (!nodes[i].master || !peerLive(i, now)) continue;
    if (best < 0) { best = i; continue; }
    int8_t d = termDiff(nodes[i].term, nodes[best].term);
    if (d > 0 || (d == 0 && memcmp(nodes[i].mac, nodes[best].mac, 6) > 0)) best = i;
  }
  return best;
}

static int updateNode(const uint8_t* mac, const Packet& p, uint32_t now){
  int idx = findNode(mac);
  bool isNew = false;
  if (idx < 0) {
    if (nodeCount >= MAX_PEERS) return -1;
    idx = nodeCount++;
    memset(&nodes[idx], 0, sizeof(NodeInfo));
    memcpy(nodes[idx].mac, mac, 6);
    memset(&pend[idx], 0, sizeof(PendingCmd));
    nodes[idx].lastSeen = now;
    isNew = true;
  }
  NodeInfo& n = nodes[idx];
  bool relay  = (p.flags & F_RELAY) != 0;
  bool master = (p.flags & F_MASTER) != 0;
  if (isNew) {
    Serial.printf("[MESH] new node %s  relay %s%s\n", macC(mac), relay ? "ON" : "OFF", master ? "  (MASTER)" : "");
  } else {
    if ((uint32_t)(now - n.lastSeen) > PEER_TIMEOUT_MS) Serial.printf("[MESH] %s is back online\n", macC(mac));
    if (n.relay != relay)   Serial.printf("[MESH] %s relay -> %s\n", macC(mac), relay ? "ON" : "OFF");
    if (n.master != master) Serial.printf("[MESH] %s %s Master (term %u)\n", macC(mac), master ? "now claims" : "gave up", p.seq);
  }
  n.rssi     = p.rssi;
  n.channel  = p.channel;
  n.relay    = relay;
  n.master   = master;
  n.eligible = (p.flags & F_ELIGIBLE) != 0;
  n.wifiUp   = (p.flags & F_WIFI_UP) != 0;
  n.term     = p.seq;
  n.lastSeen = now;
  return idx;
}

static void buildPinMap(uint32_t now, int8_t* pins){
  const uint8_t* macs[MAX_PEERS + 1];
  int total = nodeCount + 1;
  macs[0] = myMac;
  for (int i = 0; i < nodeCount; i++) macs[i + 1] = nodes[i].mac;

  int masterAll = -1;
  if (isMaster) masterAll = 0;
  else {
    int mi = liveMasterIndex(now);
    if (mi >= 0) masterAll = mi + 1;
  }
  for (int a = 0; a < total; a++) {
    if (a == masterAll) { pins[a] = 0; continue; }
    int rank = 1;
    for (int b = 0; b < total; b++) {
      if (b == a || b == masterAll) continue;
      if (memcmp(macs[b], macs[a], 6) < 0) rank++;
    }
    pins[a] = (rank <= 15) ? (int8_t)rank : (int8_t)-1;
  }
}

static void forcePin(int pin){
  if (pin >= 0 && pin < 16) pinVer[pin] = (uint8_t)(pinVer[pin] + 1);
}

// ============================ ELECTION ===========================================
static bool electWinner(bool mastersOnly, uint32_t now, uint8_t* winMac, int* bestOut){
  const uint8_t* cm[MAX_PEERS + 1];
  int cr[MAX_PEERS + 1];
  int nc = 0;

  if (mastersOnly ? isMaster : isEligible(now)) { cm[nc] = myMac; cr[nc] = advertisedRssi(now); nc++; }
  for (int i = 0; i < nodeCount; i++) {
    if (!peerLive(i, now)) continue;
    if (mastersOnly ? !nodes[i].master : !nodes[i].eligible) continue;
    cm[nc] = nodes[i].mac; cr[nc] = nodes[i].rssi; nc++;
  }
  if (nc == 0) return false;

  int best = -1000;
  for (int k = 0; k < nc; k++) if (cr[k] > best) best = cr[k];
  const uint8_t* win = nullptr;
  for (int k = 0; k < nc; k++) {
    if (cr[k] < best - HYSTERESIS_DB) continue;
    if (!win || memcmp(cm[k], win, 6) > 0) win = cm[k];
  }
  memcpy(winMac, win, 6);
  *bestOut = best;
  return true;
}

static void becomeMaster(const char* why, uint32_t now){
  isMaster = true;
  myTerm = (uint8_t)(knownTerm + 1);
  knownTerm = myTerm;
  challengeActive = false;
  noMasterActive = false;
  masterDownActive = false;
  wifiBegun = false;
  lastWifiOk = now;
  WiFi.setAutoReconnect(true);
  blynkWanted = true;
  Serial.printf("\n[SYSTEM] *** PROMOTED TO MASTER *** term %u (%s)\n", myTerm, why);
  startBurst();
}

static void becomeSlave(const char* why, uint32_t now){
  bool was = isMaster;
  isMaster = false;
  blynkWanted = false;
  challengeActive = false;
  noMasterActive = false;
  masterDownActive = false;
  wifiBegun = false;
  WiFi.setAutoReconnect(false);
  WiFi.disconnect(false);
  if (was) {
    lastDemotedAt = now;
    rssiSamples = 0;
    lastScanEnd = (uint32_t)(now - SCAN_REFRESH_MS + 1500UL);
    Serial.printf("\n[SYSTEM] *** DEMOTED TO SLAVE *** (%s)\n", why);
  }
  startBurst();
}

static bool outranksMe(int i){
  int8_t d = termDiff(nodes[i].term, myTerm);
  return d > 0 || (d == 0 && memcmp(nodes[i].mac, myMac, 6) > 0);
}

static void electionTick(uint32_t now){
  static uint32_t last = 0;
  if ((uint32_t)(now - last) < ELECTION_TICK_MS) return;
  last = now;
  bool eligible = isEligible(now);

  if (isMaster) {
    challengeActive = false;
    if (!eligible) {
      becomeSlave(simFailActive(now) ? "simulated Wi-Fi failure" : "router lost / Wi-Fi penalty", now);
      return;
    }
    for (int i = 0; i < nodeCount; i++) {
      if (nodes[i].master && peerLive(i, now) && outranksMe(i)) {
        becomeSlave("another Master has a newer term (or same term + higher MAC)", now);
        return;
      }
    }
    return;
  }

  // ---- Slave ----
  int mi = liveMasterIndex(now);
  if (mi >= 0 && (memcmp(trackMac, nodes[mi].mac, 6) != 0 || trackTerm != nodes[mi].term)) {
    memcpy(trackMac, nodes[mi].mac, 6);
    trackTerm = nodes[mi].term;
    trackSince = now;
    challengeActive = false;
    masterDownActive = false;
  }
  if (!eligible) { challengeActive = false; noMasterActive = false; masterDownActive = false; return; }
  if (scanRunning) return;
  if ((uint32_t)(now - bootMs) < BOOT_LISTEN_MS) return;

  if (mi >= 0) {
    noMasterActive = false;
    const NodeInfo& m = nodes[mi];
    uint8_t win[6];
    int best;

    if (!m.wifiUp) {
      challengeActive = false;
      if (!masterDownActive) { masterDownActive = true; masterDownSince = now; }
      else if ((uint32_t)(now - masterDownSince) >= MASTER_WIFI_DOWN_TAKEOVER_MS &&
               electWinner(false, now, win, &best) && memcmp(win, myMac, 6) == 0)
        becomeMaster("Master has had no Wi-Fi for too long", now);
      return;
    }
    masterDownActive = false;

    bool can = rssiSamples >= CHALLENGE_MIN_SAMPLES
            && (int)m.rssi < MASTER_GOOD_RSSI
            && (myRssi - (int)m.rssi) >= CHALLENGE_MARGIN_DB
            && (uint32_t)(now - trackSince) >= MASTER_MIN_TENURE_MS
            && (uint32_t)(now - lastDemotedAt) >= DEMOTE_COOLDOWN_MS;
    if (can) {
      if (!challengeActive) {
        challengeActive = true;
        challengeSince = now;
        Serial.printf("[ELECT] challenging Master %s: me %d dBm vs %d dBm (+%d dB, n=%u), holding %lu s\n",
                      macC(m.mac), myRssi, (int)m.rssi, myRssi - (int)m.rssi, rssiSamples,
                      (unsigned long)(CHALLENGE_HOLD_MS / 1000));
      } else if ((uint32_t)(now - challengeSince) >= CHALLENGE_HOLD_MS &&
                 electWinner(false, now, win, &best) && memcmp(win, myMac, 6) == 0) {
        becomeMaster("clearly better router RSSI for the whole hold time", now);
      }
    } else if (challengeActive) {
      challengeActive = false;
      Serial.println("[ELECT] challenge dropped (conditions no longer met)");
    }
  } else {
    challengeActive = false;
    masterDownActive = false;
    if (!noMasterActive) {
      noMasterActive = true;
      noMasterSince = now;
      if ((uint32_t)(now - lastScanEnd) > 8000) forceScan = true;
    } else if ((uint32_t)(now - noMasterSince) >= NO_MASTER_GRACE_MS) {
      uint8_t win[6];
      int best;
      if (electWinner(false, now, win, &best) && memcmp(win, myMac, 6) == 0)
        becomeMaster("no live Master: best RSSI band, highest MAC", now);
    }
  }
}

// ============================ WI-FI SCAN / CHANNEL SYNC ==========================
static void startScan(uint8_t kind, uint32_t now){
  if (scanRunning) return;
  WiFi.scanDelete();
  int r;
  if (kind == SCAN_DIRECTED && routerChannel >= 1) {
#if PLATFORM_ESP8266
    r = WiFi.scanNetworks(true, false, routerChannel, (uint8_t*)WIFI_SSID);
#else
    r = WiFi.scanNetworks(true, false, false, 200, routerChannel, WIFI_SSID);
#endif
  } else {
    kind = SCAN_FULL;
#if PLATFORM_ESP8266
    r = WiFi.scanNetworks(true, false);
#else
    r = WiFi.scanNetworks(true, false, false, 150);
#endif
  }
  if (r == WIFI_SCAN_FAILED) {
    Serial.println("[SCAN] could not start");
    lastScanEnd = now;
    return;
  }
  scanRunning = true;
  scanKind = kind;
  scanStartedAt = now;
}

static void finishScan(uint32_t now){
  int n = WiFi.scanComplete();
  if (n == WIFI_SCAN_RUNNING) {
    if ((uint32_t)(now - scanStartedAt) > 12000) {
      WiFi.scanDelete();
      scanRunning = false;
      lastScanEnd = now;
    }
    return;
  }
  scanRunning = false;
  lastScanEnd = now;
  if (n < 0) {
    WiFi.scanDelete();
    Serial.println("[SCAN] failed");
    lockChannel(routerChannel ? routerChannel : OFFLINE_CHANNEL, true);
    return;
  }

  int best = RSSI_NONE;
  int bestCh = 0;
  for (int i = 0; i < n; i++) {
    if (WiFi.SSID(i) == WIFI_SSID) {
      int r = WiFi.RSSI(i);
      if (bestCh == 0 || r > best) { best = r; bestCh = WiFi.channel(i); }
    }
  }
  WiFi.scanDelete();
  scanDone = true;

  if (bestCh > 0) {
    scanMisses = 0;
    if (bestCh != routerChannel) rssiSamples = 0;
    rssiFeed(best, RSSI_ALPHA_SCAN);
    routerChannel = (uint8_t)bestCh;
    Serial.printf("[SCAN] \"%s\" %d dBm -> avg %d dBm (n=%u), channel %d (%s scan)\n", WIFI_SSID, best, myRssi,
                  rssiSamples, bestCh, scanKind == SCAN_DIRECTED ? "1-channel" : "full");
    lockChannel(routerChannel, true);
  } else if (scanKind == SCAN_DIRECTED) {
    Serial.println("[SCAN] router not on the known channel -> full scan next");
    forceFullScan = true;
    lockChannel(routerChannel, true);
  } else if (++scanMisses < SCAN_MISSES_OFFLINE) {
    Serial.println("[SCAN] router not seen (1st miss) -> rescanning, role and channel unchanged");
    forceFullScan = true;
    lockChannel(routerChannel ? routerChannel : OFFLINE_CHANNEL, true);
  } else {
    myRssi = RSSI_NONE;
    routerChannel = 0;
    rssiSamples = 0;
    uint8_t ch = OFFLINE_CHANNEL;
    int mi = liveMasterIndex(now);
    if (mi >= 0 && nodes[mi].wifiUp && nodes[mi].channel >= 1 && nodes[mi].channel <= 13) ch = nodes[mi].channel;
    Serial.printf("[SCAN] \"%s\" not visible -> not eligible, channel %u, local mesh only\n", WIFI_SSID, ch);
    lockChannel(ch, true);
  }
  sendHeartbeat();
  if (printMathAfterScan) { printMathAfterScan = false; printElectionMath(now); }
}

static void scanTick(uint32_t now){
  if (scanRunning) { finishScan(now); return; }
  if (isMaster) { forceScan = forceFullScan = printMathAfterScan = false; return; }
  if (simFailActive(now)) {
    if (printMathAfterScan) { printMathAfterScan = false; printElectionMath(now); }
    forceScan = false;
    return;
  }
  uint8_t kind = 0;
  if (forceFullScan)            kind = SCAN_FULL;
  else if (forceScan)           kind = routerChannel ? SCAN_DIRECTED : SCAN_FULL;
  else if (!scanDone)           { if (lastScanEnd == 0 || (uint32_t)(now - lastScanEnd) > 3000) kind = SCAN_FULL; }
  else if (routerChannel == 0)  { if ((uint32_t)(now - lastScanEnd) >= SCAN_OFFLINE_MS) kind = SCAN_FULL; }
  else if ((uint32_t)(now - lastScanEnd) >= SCAN_REFRESH_MS) kind = SCAN_DIRECTED;
  if (kind) {
    forceScan = forceFullScan = false;
    startScan(kind, now);
  }
}

static void followMasterChannel(uint8_t ch){
  if (isMaster || scanRunning || ch < 1 || ch > 13) return;
  if (WiFi.status() == WL_CONNECTED || ch == currentChannel()) return;
  routerChannel = ch;
  Serial.printf("[CHAN] following Master to channel %u\n", ch);
  lockChannel(ch, true);
}

// ============================ MASTER WI-FI =======================================
static void masterWifiTick(uint32_t now){
  static uint32_t lastTick = 0;
  static bool wasUp = false;
  if (!isMaster) { wasUp = false; return; }
  if ((uint32_t)(now - lastTick) < 1000) return;
  lastTick = now;

  if (WiFi.status() == WL_CONNECTED) {
    if (!wasUp) {
      wasUp = true;
      wifiFails = 0;
      rssiSamples = 0;
      routerChannel = currentChannel();
      nowRefreshPeer();
      Serial.printf("[WIFI] connected to \"%s\"  ch %u  %d dBm  IP %s\n", WIFI_SSID, routerChannel,
                    WiFi.RSSI(), WiFi.localIP().toString().c_str());
      sendHeartbeat();
    }
    lastWifiOk = now;
    int r = WiFi.RSSI();
    if (r < 0 && r > RSSI_NONE) rssiFeed(r, RSSI_ALPHA_LIVE);
    return;
  }

  if (wasUp) { wasUp = false; Serial.println("[WIFI] connection lost"); }
  uint32_t sinceOk = now - lastWifiOk;
  if (!wifiBegun || (sinceOk > 5000 && (uint32_t)(now - lastWifiAttempt) > WIFI_RETRY_MS)) {
    wifiBegun = true;
    lastWifiAttempt = now;
    Serial.printf("[WIFI] connecting to \"%s\" ...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
  }
  if (sinceOk > MASTER_WIFI_GRACE_MS) {
    penaltyUntil = now + (WIFI_FAIL_PENALTY_MS << (wifiFails < 3 ? wifiFails : 3));
    if (penaltyUntil == 0) penaltyUntil = 1;
    if (wifiFails < 255) wifiFails++;
    becomeSlave("Wi-Fi unreachable too long", now);
  }
}

// ============================ MASTER -> SLAVE COMMANDS (ACK + retry) ============
static void resolvePending(int i, bool ok, uint32_t now){
  int8_t pins[MAX_PEERS + 1];
  buildPinMap(now, pins);
  PendingCmd& c = pend[i];
  Serial.printf("[CMD] %s -> %s : %s\n", macC(nodes[i].mac), c.state ? "ON" : "OFF",
                ok ? "confirmed" : "FAILED (no ACK) - Blynk switch will be reverted");
  c.active = false;
  forcePin(pins[i + 1]);
}

static void servicePending(uint32_t now){
  for (int i = 0; i < nodeCount; i++) {
    PendingCmd& c = pend[i];
    if (!c.active) continue;
    if (!isMaster) { c.active = false; continue; }
    if (nodes[i].relay == c.state && (int32_t)(nodes[i].lastSeen - c.firstTx) > 0) { resolvePending(i, true, now); continue; }
    if ((int32_t)(now - c.nextTx) < 0) continue;
    if (c.tries >= CMD_MAX_TRIES) { resolvePending(i, false, now); continue; }
    sendPkt(MSG_SET_CMD, nodes[i].mac, c.seq, c.state);
    c.tries++;
    c.nextTx = now + CMD_RETRY_MS;
  }
}

static void handleUiCmd(const UiCmd& c, uint32_t now){
  if (!isMaster) return;
  if (c.pin == 0) { applyRelay(c.value != 0, "Blynk V0"); return; }
  int8_t pins[MAX_PEERS + 1];
  buildPinMap(now, pins);
  for (int i = 0; i < nodeCount; i++) {
    if (pins[i + 1] != (int8_t)c.pin) continue;
    if (!peerLive(i, now)) {
      Serial.printf("[BLYNK] V%u -> %s is offline, ignored\n", c.pin, macC(nodes[i].mac));
      forcePin(c.pin);
      return;
    }
    PendingCmd& pc = pend[i];
    pc.active  = true;
    pc.state   = (c.value != 0);
    pc.seq     = ++cmdSeq;
    pc.tries   = 0;
    pc.firstTx = now;
    pc.nextTx  = now;
    Serial.printf("[BLYNK] V%u -> node %s : %s (seq %u)\n", c.pin, macC(nodes[i].mac), pc.state ? "ON" : "OFF", pc.seq);
    return;
  }
  Serial.printf("[BLYNK] V%u has no node assigned\n", c.pin);
  forcePin(c.pin);
}

static void blynkCmdTick(uint32_t now){
  UiCmd c;
  while (cmdPop(c)) handleUiCmd(c, now);
}

static void handleSetCmd(const uint8_t* src, const Packet& p){
  bool want = (p.flags & F_RELAY) != 0;
  if (want != relayState) applyRelay(want, "ESP-NOW command");
  sendPkt(MSG_ACK, src, p.seq, relayState);
}

static void handleAck(const uint8_t* src, const Packet& p, uint32_t now){
  if (!isMaster) return;
  int idx = findNode(src);
  if (idx < 0 || !pend[idx].active || pend[idx].seq != p.seq) return;
  bool st = (p.flags & F_RELAY) != 0;
  nodes[idx].relay = st;
  resolvePending(idx, st == pend[idx].state, now);
}

static void processRx(uint32_t now){
  RxItem it;
  while (rxPop(it)) {
    const Packet& p = it.p;
    if (p.type == MSG_HEARTBEAT) {
      int idx = updateNode(it.src, p, now);
      if (termDiff(p.seq, knownTerm) > 0) knownTerm = p.seq;
      if (idx >= 0 && (p.flags & F_MASTER) && (p.flags & F_WIFI_UP)) followMasterChannel(p.channel);
    } else if (p.type == MSG_SET_CMD) {
      if (memcmp(p.target, myMac, 6) == 0) handleSetCmd(it.src, p);
    } else if (p.type == MSG_ACK) {
      if (memcmp(p.target, myMac, 6) == 0) handleAck(it.src, p, now);
    }
  }
}

// ============================ BLYNK (own FreeRTOS task on the ESP32) =============
BLYNK_WRITE_DEFAULT() {
  UiCmd c;
  c.pin   = (uint8_t)request.pin;
  c.value = (uint8_t)(param.asInt() != 0);
  cmdPush(c);
}

static bool blynkTryConnect(){
#if PLATFORM_ESP8266
  IPAddress probe;
  if (!WiFi.hostByName("blynk.cloud", probe, 700)) return false;
#endif
  return Blynk.connect(BLYNK_CONNECT_MS);
}

static void blynkService(uint32_t now){
  static uint8_t  pushedVer[16];
  static bool     pushedOk[16];
  static uint32_t lastTry = 0, lastFull = 0, cooldown = BLYNK_RETRY_BASE_MS;
  static bool     configured = false;

  {
    bool want   = blynkWanted;
    bool wifiUp = (WiFi.status() == WL_CONNECTED);

    if (!want || !wifiUp) {
      if (Blynk.connected()) {
        Blynk.disconnect();
        Serial.println("[BLYNK] disconnected (not Master, or Wi-Fi down)");
      }
      blynkOnline = false;
      cooldown = BLYNK_RETRY_BASE_MS;
      lastTry = 0;
    } else if (Blynk.connected()) {
      blynkOnline = true;
      Blynk.run();
      if ((uint32_t)(now - lastFull) >= BLYNK_FULL_SYNC_MS) {
        memset(pushedOk, 0, sizeof(pushedOk));
        lastFull = now;
      }
      for (uint8_t n = 0; n < 16; n++) {
        if (!pinUsed[n] || pinBusy[n]) continue;
        uint8_t ver = pinVer[n];
        if (pushedOk[n] && pushedVer[n] == ver) continue;
        Blynk.virtualWrite(n, (int)pinVal[n]);
        pushedVer[n] = ver;
        pushedOk[n]  = true;
      }
    } else {
      blynkOnline = false;
      if (!configured) { Blynk.config(BLYNK_AUTH_TOKEN); configured = true; }
      if (lastTry == 0 || (uint32_t)(now - lastTry) >= cooldown) {
        lastTry = (now == 0) ? 1 : now;
        Serial.printf("[BLYNK] connecting (%lu ms timeout) ...\n", (unsigned long)BLYNK_CONNECT_MS);
        if (blynkTryConnect()) {
          Serial.println("[BLYNK] ONLINE");
          cooldown = BLYNK_RETRY_BASE_MS;
          memset(pushedOk, 0, sizeof(pushedOk));
          lastFull = millis();
        } else {
          cooldown = (cooldown * 2 > BLYNK_RETRY_MAX_MS) ? BLYNK_RETRY_MAX_MS : cooldown * 2;
          Serial.printf("[BLYNK] connect failed (slow link or internet down?) - retry in %lu s, mesh keeps working\n",
                        (unsigned long)(cooldown / 1000));
        }
      }
    }
  }
}

#if !PLATFORM_ESP8266
static void blynkTask(void*){
  for (;;) {
    blynkService(millis());
    vTaskDelay(pdMS_TO_TICKS(5));
  }
}
#endif

static void pinShadowTick(uint32_t now){
  static uint32_t last = 0;
  if ((uint32_t)(now - last) < 50) return;
  last = now;

  bool    used[16] = {false};
  bool    busy[16] = {false};
  uint8_t val[16]  = {0};
  if (isMaster) {
    int8_t pins[MAX_PEERS + 1];
    buildPinMap(now, pins);
    used[0] = true;
    val[0]  = relayState ? 1 : 0;
    for (int i = 0; i < nodeCount; i++) {
      int p = pins[i + 1];
      if (p < 1 || p > 15) continue;
      used[p] = true;
      val[p]  = nodes[i].relay ? 1 : 0;
      busy[p] = pend[i].active;
    }
  }
  for (int n = 0; n < 16; n++) {
    if (val[n] != pinVal[n] || used[n] != pinUsed[n]) pinVer[n] = (uint8_t)(pinVer[n] + 1);
    pinVal[n]  = val[n];
    pinUsed[n] = used[n];
    pinBusy[n] = busy[n];
  }
}

// ============================ STATUS LEDs ========================================
#if HAS_RGB_STATUS
static void rgbSet(uint8_t r, uint8_t g, uint8_t b){
  static uint8_t lr = 255, lg = 255, lb = 255;
  if (r == lr && g == lg && b == lb) return;
  lr = r; lg = g; lb = b;
  RGB_WRITE(r, g, b);
}

static uint8_t triWave(uint32_t t, uint32_t start, uint32_t width){
  if (t < start || t >= start + width) return 0;
  uint32_t x = t - start, half = width / 2;
  return (uint8_t)(((x < half) ? x : (width - x)) * 255 / half);
}

static uint8_t heartbeatLevel(uint32_t now){
  uint32_t ph = now % 1600;
  uint32_t a = triWave(ph, 0, 260);
  uint32_t b = triWave(ph, 330, 260) * 6 / 10;
  uint32_t v = (a > b) ? a : b;
  return (uint8_t)(3 + (v * 42) / 255);
}

static void statusLedTick(uint32_t now){
  static uint32_t last = 0;
  if ((uint32_t)(now - last) < 20) return;
  last = now;
  if (relayState) {
    if (isMaster) rgbSet(0, 110, 0);
    else          rgbSet(0, 70, 120);
  } else {
    uint8_t l = heartbeatLevel(now);
    if (isMaster) rgbSet((uint8_t)(l * 3 / 4), 0, l);
    else          rgbSet(l, (uint8_t)(l * 45 / 100), 0);
  }
}
#else
static void statusLedTick(uint32_t now){ (void)now; }
#endif

static void bootSelfTest(){
#if BENCH_TEST_MODE
  Serial.println("[TEST] LED self-test: relay LED x2"
#if HAS_RGB_STATUS
                 ", RGB red/green/blue/purple/amber"
#endif
                 );
  for (int i = 0; i < 2; i++) {
    relayWrite(true);  delay(120);
    relayWrite(false); delay(120);
  }
#if HAS_RGB_STATUS
  const uint8_t seq[][3] = { {80, 0, 0}, {0, 80, 0}, {0, 0, 80}, {60, 0, 80}, {80, 35, 0} };
  for (auto& c : seq) { RGB_WRITE(c[0], c[1], c[2]); delay(180); }
  RGB_WRITE(0, 0, 0);
#endif
#endif
}

// ============================ SERIAL MENU / PRINTS ===============================
static void printHelp(){
  Serial.println();
  Serial.println("Serial test menu (115200 baud):");
  Serial.println("  t  toggle relay/LED (same as pressing the button)");
  Serial.println("  m  print mesh routing / node table");
  Serial.println("  f  simulate Wi-Fi failure for 20 s (Master steps down, the other board must take over)");
  Serial.println("  r  immediate RSSI check + election math");
  Serial.println("  h  this help");
}

static void printMeshTable(uint32_t now){
  int8_t pins[MAX_PEERS + 1];
  buildPinMap(now, pins);
  int mi = liveMasterIndex(now);
  Serial.println();
  Serial.printf("================ MESH TABLE  [%s]  up %lu s  my channel %u ================\n",
                BOARD_NAME, (unsigned long)(now / 1000), currentChannel());
  Serial.println(" #  MAC                Role     RSSI   Ch  Relay  Last seen  Vpin");
  Serial.printf(" 0  %-17s  %-7s  %4d   %2u  %-5s  %-9s  %-4s <- this board\n",
                macC(myMac), isMaster ? "MASTER" : "SLAVE", (int)advertisedRssi(now), currentChannel(),
                relayState ? "ON" : "OFF", "-", pinC(pins[0]));
  for (int i = 0; i < nodeCount; i++) {
    uint32_t age = now - nodes[i].lastSeen;
    bool live = age <= PEER_TIMEOUT_MS;
    char seen[16];
    snprintf(seen, sizeof(seen), "%lu.%lus", (unsigned long)(age / 1000), (unsigned long)((age % 1000) / 100));
    Serial.printf("%2d  %-17s  %-7s  %4d   %2u  %-5s  %-9s  %-4s\n", i + 1, macC(nodes[i].mac),
                  live ? (nodes[i].master ? "MASTER" : "SLAVE") : "OFFLINE", (int)nodes[i].rssi,
                  nodes[i].channel, nodes[i].relay ? "ON" : "OFF", seen, pinC(pins[i + 1]));
  }
  Serial.printf("Master: %s | term %u | Blynk: %s | challenge: +%d dB for %lu s | router ch %u | RSSI avg %d (n=%u)\n",
                isMaster ? "this board" : (mi >= 0 ? macC(nodes[mi].mac) : "none"),
                isMaster ? myTerm : knownTerm,
                isMaster ? (blynkOnline ? "ONLINE" : "offline") : "(Master only)",
                CHALLENGE_MARGIN_DB, (unsigned long)(CHALLENGE_HOLD_MS / 1000), routerChannel, myRssi, rssiSamples);
  Serial.println("=================================================================================");
}

static void printElectionMath(uint32_t now){
  Serial.println("\n---------------- ELECTION MATH ----------------");
  Serial.printf("me      %s  role=%s  eligible=%s  RSSI avg=%d dBm (n=%u)  ch=%u  term=%u\n", macC(myMac),
                isMaster ? "MASTER" : "SLAVE", isEligible(now) ? "yes" : "NO", myRssi, rssiSamples, currentChannel(),
                isMaster ? myTerm : knownTerm);
  if (!isEligible(now))
    Serial.printf("        not eligible: %s\n", !scanDone ? "first scan not finished" :
                  simFailActive(now) ? "simulated Wi-Fi failure" : penaltyActive(now) ? "Wi-Fi failure penalty" :
                  "router not visible");
  int mi = liveMasterIndex(now);
  if (isMaster) {
    Serial.println("rule    I am Master: I only lose the role to a Master with a newer term, or if I lose the router / Wi-Fi.");
    for (int i = 0; i < nodeCount; i++) {
      if (!peerLive(i, now)) continue;
      int d = (int)nodes[i].rssi - myRssi;
      Serial.printf("peer    %s  %d dBm  delta vs me %+d dB -> %s\n", macC(nodes[i].mac), (int)nodes[i].rssi, d,
                    myRssi >= MASTER_GOOD_RSSI ? "my link is good, nobody challenges" :
                    d >= CHALLENGE_MARGIN_DB ? "may challenge after the hold time" : "inside the margin, stays Slave");
    }
  } else if (mi >= 0) {
    int d = myRssi - nodes[mi].rssi;
    Serial.printf("master  %s  %d dBm  term %u  wifi=%s  (heard %lu ms ago, tenure %lu s)\n", macC(nodes[mi].mac),
                  (int)nodes[mi].rssi, nodes[mi].term, nodes[mi].wifiUp ? "up" : "DOWN",
                  (unsigned long)(now - nodes[mi].lastSeen), (unsigned long)((now - trackSince) / 1000));
    Serial.printf("delta   me - master = %+d dB ; challenge needs >= %+d dB, Master weaker than %d dBm, n >= %d (have %u), "
                  "hold %lu s, tenure >= %lu s%s\n", d, CHALLENGE_MARGIN_DB, MASTER_GOOD_RSSI, CHALLENGE_MIN_SAMPLES,
                  rssiSamples, (unsigned long)(CHALLENGE_HOLD_MS / 1000), (unsigned long)(MASTER_MIN_TENURE_MS / 1000),
                  challengeActive ? "  (CHALLENGE RUNNING)" : "");
  } else {
    Serial.println("master  none alive");
  }
  uint8_t win[6];
  int best;
  if (electWinner(false, now, win, &best))
    Serial.printf("no-Master election: best %d dBm, tie band >= %d dBm, highest MAC in band wins -> %s%s\n", best,
                  best - HYSTERESIS_DB, macC(win), memcmp(win, myMac, 6) == 0 ? "  (me)" : "");
  else
    Serial.println("no-Master election: nobody eligible (router not visible) -> mesh stays local on channel 1");
  Serial.println("-----------------------------------------------");
}

static void simulateWifiFailure(uint32_t now){
  simFailUntil = now + SIM_FAIL_MS;
  if (simFailUntil == 0) simFailUntil = 1;
  Serial.printf("[SIM] Wi-Fi failure for %lu s: I am not eligible for Master until it ends\n", (unsigned long)(SIM_FAIL_MS / 1000));
  if (isMaster) becomeSlave("simulated Wi-Fi failure", now);
  else startBurst();
}

static void simTick(uint32_t now){
  static bool was = false;
  bool act = simFailActive(now);
  if (was && !act) {
    simFailUntil = 0;
    Serial.println("[SIM] Wi-Fi failure ended -> rescanning and rejoining the mesh as a Slave");
    forceScan = true;
    startBurst();
  }
  was = act;
}

static void rssiCheck(uint32_t now){
  Serial.println("[RSSI] immediate check");
  if (isMaster) {
    if (WiFi.status() == WL_CONNECTED) {
      int r = WiFi.RSSI();
      Serial.printf("[RSSI] Master: live Wi-Fi RSSI %d dBm, averaged %d dBm (no scan - it would drop the connection)\n", r, myRssi);
    }
    printElectionMath(now);
  } else if (simFailActive(now)) {
    printElectionMath(now);
  } else {
    forceScan = true;
    printMathAfterScan = true;
  }
}

static void serialTick(uint32_t now){
  while (Serial.available() > 0) {
    int c = Serial.read();
    switch (c) {
      case 't': case 'T': applyRelay(!relayState, "SERIAL 't'"); break;
      case 'm': case 'M': printMeshTable(now); break;
      case 'f': case 'F': simulateWifiFailure(now); break;
      case 'r': case 'R': rssiCheck(now); break;
      case 'h': case 'H': case '?': printHelp(); break;
      default: break;
    }
  }
}

// ============================ BUTTONS ============================================
static void buttonsTick(uint32_t now){
  for (auto& b : btns) {
    uint8_t r = (uint8_t)digitalRead(b.pin);
    if (r != b.last) { b.last = r; b.changedAt = now; }
    if ((uint32_t)(now - b.changedAt) >= BTN_DEBOUNCE_MS && r != b.stable) {
      b.stable = r;
      if (r == LOW) applyRelay(!relayState, b.name);
    }
  }
}

// ============================ SETUP / LOOP =======================================
void setup(){
  Serial.begin(115200);
#if defined(ARDUINO_USB_CDC_ON_BOOT) && ARDUINO_USB_CDC_ON_BOOT
  Serial.setTxTimeoutMs(0);
#endif
  delay(250);
  bootMs = millis();

  pinMode(RELAY_PIN, OUTPUT);
#ifdef RELAY2_PIN
  pinMode(RELAY2_PIN, OUTPUT);
#endif
  relayWrite(false);
  for (auto& b : btns) pinMode(b.pin, INPUT_PULLUP);

  nvsBegin();
  bool saved = nvsLoadRelay();

  Serial.println();
  Serial.println("=====================================================");
  Serial.printf(" SMART SWITCH MESH v2 | %s | bench test: %s\n", BOARD_NAME, BENCH_TEST_MODE ? "ON (onboard LEDs)" : "OFF (Real Relay)");
  Serial.printf(" relay pin GPIO %d | button pin GPIO %d | target Wi-Fi \"%s\"\n", RELAY_PIN, BUTTON_PIN, WIFI_SSID);
#if PLATFORM_ESP8266
  Serial.printf(" ESP8266 core %s\n", ESP.getCoreVersion().c_str());
#elif defined(ESP_ARDUINO_VERSION_MAJOR)
  Serial.printf(" Arduino-ESP32 core %d.%d.%d\n", ESP_ARDUINO_VERSION_MAJOR, ESP_ARDUINO_VERSION_MINOR, ESP_ARDUINO_VERSION_PATCH);
#endif
  Serial.println("=====================================================");
  bootSelfTest();

  relayState = RESTORE_RELAY_ON_BOOT ? saved : false;
  relayWrite(relayState);
  Serial.printf("[BOOT] relay restored from NVS: %s\n", relayState ? "ON" : "OFF");

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
#if PLATFORM_ESP8266
  WiFi.setSleepMode(WIFI_NONE_SLEEP);
#else
  WiFi.setSleep(false);
#endif
  WiFi.setAutoReconnect(false);
  WiFi.disconnect();
  WiFi.macAddress(myMac);
  Serial.printf("[BOOT] MAC %s\n", macC(myMac));
  lockChannel(OFFLINE_CHANNEL, true);

#if !PLATFORM_ESP8266
  rxQueue  = xQueueCreate(24, sizeof(RxItem));
  cmdQueue = xQueueCreate(8, sizeof(UiCmd));
#endif

  espnowOk = nowInit();
  Serial.printf("[ESP-NOW] %s\n", espnowOk ? "ready" : "init FAILED - local switching only");

#if !PLATFORM_ESP8266
  xTaskCreatePinnedToCore(blynkTask, "blynk", 12288, nullptr, 1, nullptr, 0);
#endif
  nextHeartbeatAt = millis() + 500;
  printHelp();
}

void loop(){
  uint32_t now = millis();

  processRx(now);
  blynkCmdTick(now);
  serialTick(now);
  buttonsTick(now);
  servicePending(now);
  burstTick(now);

  if ((int32_t)(now - nextHeartbeatAt) >= 0) {
    sendHeartbeat();
    nextHeartbeatAt = now + HEARTBEAT_MS + (uint32_t)random(0, 200);
  }

  simTick(now);
  scanTick(now);
  masterWifiTick(now);
  electionTick(now);
  pinShadowTick(now);
  persistTick(now);
  statusLedTick(now);
#if PLATFORM_ESP8266
  blynkService(now);
  txTick(millis());
#endif

  delay(1);
}
