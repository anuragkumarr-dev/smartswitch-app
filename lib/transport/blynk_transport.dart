import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'cloud_transport.dart';
import 'models/blynk_node_map.dart';
import 'models/message_envelope.dart';

/// Callback signature when Blynk polling discovers or updates node mappings.
typedef OnBlynkNodesUpdated = Future<void> Function(
    BlynkNodeMap nodeMap, Map<int, int> rawPinStates);

/// Callback signature when Blynk transport diagnostic status updates.
typedef OnBlynkStatusChanged = void Function(BlynkStatus status);

/// Immutable diagnostic status for the Blynk prototype bridge.
@immutable
class BlynkStatus {
  final bool isConnected;
  final int nodeCount;
  final DateTime? lastPollTime;
  final String? lastRawV16;
  final String? lastCommandInfo;
  final String? lastCommandResult;
  final String? lastError;

  const BlynkStatus({
    this.isConnected = false,
    this.nodeCount = 0,
    this.lastPollTime,
    this.lastRawV16,
    this.lastCommandInfo,
    this.lastCommandResult,
    this.lastError,
  });

  BlynkStatus copyWith({
    bool? isConnected,
    int? nodeCount,
    DateTime? lastPollTime,
    String? lastRawV16,
    String? lastCommandInfo,
    String? lastCommandResult,
    String? lastError,
    bool clearError = false,
  }) {
    return BlynkStatus(
      isConnected: isConnected ?? this.isConnected,
      nodeCount: nodeCount ?? this.nodeCount,
      lastPollTime: lastPollTime ?? this.lastPollTime,
      lastRawV16: lastRawV16 ?? this.lastRawV16,
      lastCommandInfo: lastCommandInfo ?? this.lastCommandInfo,
      lastCommandResult: lastCommandResult ?? this.lastCommandResult,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Prototype [CloudTransport] bridge to connect ESP-NOW + Blynk firmware.
/// Interacts with the Blynk REST API: https://{region}.blynk.cloud/external/api
/// - Dynamically resolves switch pins from the V16 node map
/// - Polls every 1.5 s in foreground with exponential backoff on errors
/// - Keyed strictly by MAC address
/// - Never hardcodes virtual pins or stores secrets in source code
class BlynkCloudTransport implements CloudTransport {
  final Dio dio;
  String authToken;
  String region;

  bool _isConnected = false;
  bool _stopped = true;
  Timer? _pollerTimer;

  // Polling rate: 1.5 seconds default
  final Duration pollingInterval;

  // Backoff on connection failure
  int _consecutiveFailures = 0;
  static const int _maxBackoffSeconds = 15;

  // Dynamic runtime node map (V16)
  BlynkNodeMap _currentNodeMap =
      const BlynkNodeMap(masterMac: '', nodesByMac: {}, macByPin: {});

  // Debug Diagnostics Information
  DateTime? lastPollTime;
  String? lastRawV16;
  String? lastCommandInfo;
  String? lastCommandResult;
  String? lastError;

  BlynkStatus status = const BlynkStatus();
  OnBlynkStatusChanged? onStatusChanged;

  final Map<int, int> _pinStates = {}; // pinNumber -> 0 or 1
  int _localVer = 1000;

  final StreamController<MessageEnvelope> _incomingController =
      StreamController<MessageEnvelope>.broadcast();

  OnBlynkNodesUpdated? onNodesUpdated;

  /// Optional base URL override for unit testing with local loopback mock servers.
  final String? customBaseUrl;

  BlynkCloudTransport({
    required this.authToken,
    this.region = 'blr1',
    this.customBaseUrl,
    Dio? dioClient,
    this.pollingInterval = const Duration(milliseconds: 1500),
    this.onNodesUpdated,
  }) : dio = dioClient ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<MessageEnvelope> get incomingMessages => _incomingController.stream;

  BlynkNodeMap get currentNodeMap => _currentNodeMap;

  String get baseUrl => customBaseUrl ?? 'https://$region.blynk.cloud/external/api';

  void _updateStatus({
    bool? isConnected,
    int? nodeCount,
    DateTime? lastPollTime,
    String? lastRawV16,
    String? lastCommandInfo,
    String? lastCommandResult,
    String? lastError,
    bool clearError = false,
  }) {
    if (isConnected != null) _isConnected = isConnected;
    if (lastPollTime != null) this.lastPollTime = lastPollTime;
    if (lastRawV16 != null) this.lastRawV16 = lastRawV16;
    if (lastCommandInfo != null) this.lastCommandInfo = lastCommandInfo;
    if (lastCommandResult != null) this.lastCommandResult = lastCommandResult;
    if (clearError) {
      this.lastError = null;
    } else if (lastError != null) {
      this.lastError = lastError;
    }

    status = status.copyWith(
      isConnected: isConnected,
      nodeCount: nodeCount,
      lastPollTime: lastPollTime,
      lastRawV16: lastRawV16,
      lastCommandInfo: lastCommandInfo,
      lastCommandResult: lastCommandResult,
      lastError: lastError,
      clearError: clearError,
    );

    onStatusChanged?.call(status);
  }

  void updateCredentials({required String token, String region = 'blr1'}) {
    authToken = token;
    this.region = region;
    _updateStatus(clearError: true);
  }

  @override
  Future<bool> connect({
    required String homeId,
    required String brokerUrl,
    int port = 8883,
    String? clientIdentifier,
  }) async {
    if (authToken.trim().isEmpty) {
      _isConnected = false;
      _updateStatus(isConnected: false, lastError: 'No Blynk Auth Token provided');
      return false;
    }

    // Verify hardware is connected
    final isOnline = await checkHardwareConnected();
    _isConnected = isOnline;
    _updateStatus(
      isConnected: isOnline,
      lastError: isOnline ? null : 'Hardware offline',
      clearError: isOnline,
    );

    _startPolling();
    return _isConnected;
  }

  /// Checks https://{region}.blynk.cloud/external/api/isHardwareConnected?token={token}
  Future<bool> checkHardwareConnected({String? token, String? region}) async {
    final useToken = token ?? authToken;
    final useRegion = region ?? this.region;
    if (useToken.trim().isEmpty) return false;

    try {
      final host = customBaseUrl ?? 'https://$useRegion.blynk.cloud/external/api';
      final res = await dio.get<dynamic>(
        '$host/isHardwareConnected',
        queryParameters: {'token': useToken},
      );
      if (res.statusCode == 200) {
        final val = res.data.toString().toLowerCase();
        return val == 'true' || val == '1';
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sends command: maps deviceId (MAC) to current dynamic pin from V16,
  /// calls https://{region}.blynk.cloud/external/api/update?token={token}&V{pin}={0|1},
  /// reads back within 4 s to confirm, rolls back on mismatch.
  @override
  Future<MessageEnvelope?> send(
    String homeId,
    String deviceId, // Expected to be the 12-char hex MAC address
    MessageEnvelope envelope, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final mac = deviceId.toUpperCase();
    final node = _currentNodeMap.nodesByMac[mac];

    if (node == null) {
      debugPrint('[BlynkBridge] Unknown node MAC: $mac in current node map');
      return null;
    }

    final pin = node.pin;
    final desired = envelope.desired;
    final gang1 = desired?['gang1'];
    bool targetOn = false;
    if (gang1 is Map<String, dynamic>) {
      targetOn = gang1['on'] == true;
    } else if (gang1 is bool) {
      targetOn = gang1;
    }

    final int targetVal = targetOn ? 1 : 0;
    final cmdInfo =
        'SET $mac (V$pin) -> $targetVal (${targetOn ? "ON" : "OFF"}) at ${DateTime.now().toIso8601String().substring(11, 19)}';
    _updateStatus(lastCommandInfo: cmdInfo);

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Issue update command
      final updateRes = await dio.get<dynamic>(
        '$baseUrl/update',
        queryParameters: {
          'token': authToken,
          'V$pin': targetVal,
        },
      ).timeout(timeout);

      if (updateRes.statusCode != 200) {
        _updateStatus(lastCommandResult: 'HTTP Error: ${updateRes.statusCode}');
        return null;
      }

      // 2. Read-back confirmation loop within timeout
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 300));

        final readRes = await dio.get<dynamic>(
          '$baseUrl/get',
          queryParameters: {
            'token': authToken,
            'V$pin': '',
          },
        );

        if (readRes.statusCode == 200) {
          final currentVal = int.tryParse(readRes.data.toString().trim());
          if (currentVal == targetVal) {
            // Confirmed!
            _localVer++;
            _updateStatus(
              lastCommandResult:
                  'Confirmed (${stopwatch.elapsedMilliseconds} ms)',
            );
            final ackEnvelope = MessageEnvelope.ack(
              deviceId: mac,
              commandId: envelope.commandId,
              reported: {
                'gang1': {'on': targetOn},
                'online': true,
                'ver': _localVer,
              },
              ver: _localVer,
              ts: DateTime.now().millisecondsSinceEpoch,
            );
            return ackEnvelope;
          }
        }
      }

      // Timeout or mismatch -> null indicates rollback
      _updateStatus(
        lastCommandResult:
            'Mismatch / Timeout (${stopwatch.elapsedMilliseconds} ms) -> Rolled back',
      );
      return null;
    } catch (e) {
      _updateStatus(lastCommandResult: 'Exception: $e');
      debugPrint('[BlynkBridge] Command failed: $e');
      return null;
    } finally {
      stopwatch.stop();
    }
  }

  @override
  Future<void> subscribeToHome(String homeId) async {
    // In Blynk HTTP API, subscriptions are implemented via the background poller
    _startPolling();
  }

  @override
  Future<void> disconnect() async {
    _stopped = true;
    _pollerTimer?.cancel();
    _pollerTimer = null;
    _isConnected = false;
    _updateStatus(isConnected: false);
  }

  void _startPolling() {
    _stopped = false;
    _pollerTimer?.cancel();
    _scheduleNextPoll(Duration.zero);
  }

  void _scheduleNextPoll(Duration delay) {
    if (_stopped) return;
    _pollerTimer?.cancel();
    _pollerTimer = Timer(delay, () async {
      if (_stopped) return;
      await _pollOnce();
      if (_stopped) return;
      if (_isConnected) {
        _consecutiveFailures = 0;
        _scheduleNextPoll(pollingInterval);
      } else {
        // Exponential backoff when offline / errors
        _consecutiveFailures++;
        final backoffSec =
            (_consecutiveFailures * 2).clamp(2, _maxBackoffSeconds);
        _scheduleNextPoll(Duration(seconds: backoffSec));
      }
    });
  }

  /// Triggers an immediate poll cycle.
  Future<void> pollNow() async {
    await _pollOnce();
  }

  /// Reads V0..V16 in batch via /get endpoint.
  Future<void> _pollOnce() async {
    if (authToken.trim().isEmpty) return;

    try {
      // Query V0 through V16 in one HTTP request
      final query = <String, String>{'token': authToken};
      for (int i = 0; i <= 16; i++) {
        query['V$i'] = '';
      }

      final res = await dio.get<dynamic>(
        '$baseUrl/get',
        queryParameters: query,
      );

      if (res.statusCode == 200) {
        _isConnected = true;
        _updateStatus(
          isConnected: true,
          lastPollTime: DateTime.now(),
          clearError: true,
        );
        await _parseBatchResponse(res.data);
      } else {
        _isConnected = false;
        _updateStatus(
          isConnected: false,
          lastError: 'HTTP ${res.statusCode} from Blynk Cloud',
        );
      }
    } on DioException catch (e) {
      _isConnected = false;
      final code = e.response?.statusCode;
      final msg = code != null
          ? 'Blynk Cloud Error ($code): ${code == 401 ? "Invalid Auth Token" : e.message}'
          : (e.message ?? 'Network Error');
      _updateStatus(
        isConnected: false,
        lastError: msg,
      );
    } catch (e) {
      _isConnected = false;
      _updateStatus(
        isConnected: false,
        lastError: e.toString(),
      );
    }
  }

  /// Parses the Blynk batch response.
  /// Depending on Blynk server version, response can be JSON object {"V0":"0","V1":"1",..."V16":"..."}
  /// or a JSON array of strings / values.
  Future<void> _parseBatchResponse(dynamic data) async {
    String v16String = '';
    final newPinStates = <int, int>{};

    if (data is Map<String, dynamic>) {
      for (int i = 0; i <= 15; i++) {
        final val = data['V$i'];
        if (val != null) {
          newPinStates[i] = int.tryParse(val.toString()) ?? 0;
        }
      }
      v16String = (data['V16'] ?? '').toString();
    } else if (data is List) {
      // Array indexed 0..16
      for (int i = 0; i <= 15 && i < data.length; i++) {
        newPinStates[i] = int.tryParse(data[i].toString()) ?? 0;
      }
      if (data.length > 16) {
        v16String = data[16].toString();
      }
    }

    _pinStates.addAll(newPinStates);

    if (v16String.isNotEmpty) {
      final parsedMap = BlynkNodeMap.parse(v16String);
      _currentNodeMap = parsedMap;
      _updateStatus(
        lastRawV16: v16String,
        nodeCount: parsedMap.nodesByMac.length,
      );
      await onNodesUpdated?.call(parsedMap, _pinStates);

      // Emit MessageEnvelope.state for each node in map
      for (final entry in parsedMap.nodesByMac.values) {
        _localVer++;
        final pinVal = _pinStates[entry.pin] ?? (entry.state ? 1 : 0);
        final isOn = pinVal == 1;

        final envelope = MessageEnvelope.state(
          deviceId: entry.mac,
          commandId: 'blynk_sync_${entry.mac}_$_localVer',
          reported: {
            'gang1': {'on': isOn},
            'online': entry.isLive,
            'rssi': entry.rssi,
            'isMaster': entry.isMaster,
            'pin': entry.pin,
            'ver': _localVer,
          },
          ver: _localVer,
          ts: DateTime.now().millisecondsSinceEpoch,
        );

        if (!_incomingController.isClosed) {
          _incomingController.add(envelope);
        }
      }
    } else {
      _updateStatus(lastRawV16: '');
    }
  }

  void dispose() {
    _stopped = true;
    _pollerTimer?.cancel();
    _pollerTimer = null;
    if (!_incomingController.isClosed) {
      _incomingController.close();
    }
  }
}
