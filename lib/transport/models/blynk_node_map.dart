/// Represents an ESP-NOW peer node parsed dynamically from the Blynk V16 node map.
/// Firmware protocol format: `"<masterMAC>;<MAC>:<pin>:<state>:<rssi>:<live>,..."`
class BlynkNodeEntry {
  final String mac; // 12-char hex MAC address, e.g. "A1B2C3D4E5F6"
  final int pin; // Virtual pin number, e.g. 0..15
  final bool state; // Relay switch on/off
  final int rssi; // Signal strength in dBm, e.g. -65
  final bool isLive; // 1 = live, 0 = offline
  final bool isMaster; // Whether this node is currently the Master node

  const BlynkNodeEntry({
    required this.mac,
    required this.pin,
    required this.state,
    required this.rssi,
    required this.isLive,
    this.isMaster = false,
  });

  /// Virtual pin string formatted as "V[pin]" (e.g. "V0")
  String get pinName => 'V$pin';

  @override
  String toString() =>
      'BlynkNodeEntry(mac: $mac, pin: V$pin, state: $state, rssi: $rssi, live: $isLive, master: $isMaster)';
}

/// Parsed snapshot of the V16 node map and pin states from the Blynk Master.
class BlynkNodeMap {
  final String masterMac;
  final Map<String, BlynkNodeEntry> nodesByMac; // MAC -> NodeEntry
  final Map<int, String> macByPin; // Pin index (0..15) -> MAC

  const BlynkNodeMap({
    required this.masterMac,
    required this.nodesByMac,
    required this.macByPin,
  });

  /// Parses the raw V16 string payload.
  /// Format: `"<masterMAC>;<MAC>:<pin>:<state>:<rssi>:<live>,..."`
  /// Example: "AABBCCDDEEFF;AABBCCDDEEFF:0:1:-50:1,112233445566:1:0:-65:1"
  static BlynkNodeMap parse(String v16Raw) {
    final raw = v16Raw.trim();
    if (raw.isEmpty) {
      return const BlynkNodeMap(masterMac: '', nodesByMac: {}, macByPin: {});
    }

    final semicolonIdx = raw.indexOf(';');
    final String masterMac;
    final String nodesPart;

    if (semicolonIdx != -1) {
      masterMac = raw.substring(0, semicolonIdx).trim().toUpperCase();
      nodesPart = raw.substring(semicolonIdx + 1).trim();
    } else {
      masterMac = '';
      nodesPart = raw;
    }

    final nodesByMac = <String, BlynkNodeEntry>{};
    final macByPin = <int, String>{};

    if (nodesPart.isNotEmpty) {
      final entries = nodesPart.split(',');
      for (final entry in entries) {
        final tokens = entry.trim().split(':');
        if (tokens.length >= 5) {
          final mac = tokens[0].trim().toUpperCase();
          final pin = int.tryParse(tokens[1].replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
          final state = tokens[2].trim() == '1';
          final rssi = int.tryParse(tokens[3].trim()) ?? -70;
          final isLive = tokens[4].trim() == '1';

          final node = BlynkNodeEntry(
            mac: mac,
            pin: pin,
            state: state,
            rssi: rssi,
            isLive: isLive,
            isMaster: mac == masterMac,
          );

          nodesByMac[mac] = node;
          macByPin[pin] = mac;
        }
      }
    }

    return BlynkNodeMap(
      masterMac: masterMac,
      nodesByMac: nodesByMac,
      macByPin: macByPin,
    );
  }
}
