import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Lightweight embedded HTTP server simulating Blynk Cloud REST API:
/// https://{region}.blynk.cloud/external/api/
/// Supports:
/// - GET /external/api/isHardwareConnected?token=...
/// - GET /external/api/get?token=...&V0=&V1=...
/// - GET /external/api/update?token=...&V0=1
/// - Simulating Master runtime re-election (dynamic pin shift in V16)
/// - Simulating node drop / offline
/// - Invalid / expired token rejection
/// - Network disconnect / drop simulation
class FakeBlynkHttpServer {
  HttpServer? _server;
  int get port => _server?.port ?? 0;
  String get url => 'http://127.0.0.1:$port';

  String validToken = 'valid_test_blynk_token_12345';
  bool isHardwareOnline = true;
  bool dropNetwork = false;

  // Pin values 0..15 (0 or 1)
  final Map<int, int> pinValues = {for (int i = 0; i <= 15; i++) i: 0};

  // Node Map V16
  // Format: "<masterMAC>;<MAC>:<pin>:<state>:<rssi>:<live>,..."
  String v16NodeMap =
      'A1B2C3D4E501;A1B2C3D4E501:0:0:-55:1,A1B2C3D4E502:1:0:-68:1,A1B2C3D4E503:2:0:-82:1';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Simulates Master node change at runtime:
  /// The new master is A1B2C3D4E502, pins shift.
  void simulateMasterReElection() {
    v16NodeMap =
        'A1B2C3D4E502;A1B2C3D4E502:0:0:-52:1,A1B2C3D4E501:1:0:-70:1,A1B2C3D4E503:2:0:-80:1';
  }

  /// Simulates one node going offline (live = 0)
  void simulateNodeOffline(String mac) {
    final parts = v16NodeMap.split(';');
    final master = parts[0];
    final nodes = parts[1].split(',').map((entry) {
      if (entry.startsWith(mac)) {
        final tokens = entry.split(':');
        tokens[4] = '0'; // live = 0
        return tokens.join(':');
      }
      return entry;
    }).join(',');
    v16NodeMap = '$master;$nodes';
  }

  void _handleRequest(HttpRequest request) async {
    if (dropNetwork) {
      request.response.statusCode = HttpStatus.gatewayTimeout;
      request.response.close();
      return;
    }

    final uri = request.uri;
    final path = uri.path;
    final token = uri.queryParameters['token'];

    // Auth check
    if (token != validToken) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Invalid auth token'}))
        ..close();
      return;
    }

    if (path.endsWith('/isHardwareConnected')) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write(isHardwareOnline ? 'true' : 'false')
        ..close();
      return;
    }

    if (path.endsWith('/update')) {
      // Find which pin is being updated
      for (final key in uri.queryParameters.keys) {
        if (key.startsWith('V')) {
          final pinNum = int.tryParse(key.substring(1));
          final val = int.tryParse(uri.queryParameters[key] ?? '0') ?? 0;
          if (pinNum != null) {
            pinValues[pinNum] = val;
          }
        }
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.text
        ..write('OK')
        ..close();
      return;
    }

    if (path.endsWith('/get')) {
      // Check if querying single pin or batch
      final vParams = uri.queryParameters.keys.where((k) => k.startsWith('V')).toList();
      if (vParams.length == 1) {
        final pin = vParams.first;
        if (pin == 'V16') {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write(v16NodeMap)
            ..close();
          return;
        } else {
          final pinNum = int.tryParse(pin.substring(1)) ?? 0;
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.text
            ..write(pinValues[pinNum]?.toString() ?? '0')
            ..close();
          return;
        }
      }

      // Batch query response: JSON object with V0..V16
      final Map<String, dynamic> responseMap = {};
      for (int i = 0; i <= 15; i++) {
        responseMap['V$i'] = pinValues[i]?.toString() ?? '0';
      }
      responseMap['V16'] = v16NodeMap;

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(responseMap))
        ..close();
      return;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}
