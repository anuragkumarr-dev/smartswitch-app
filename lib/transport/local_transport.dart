import 'dart:async';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'crypto/local_crypto.dart';
import 'mdns_service.dart';
import 'models/message_envelope.dart';

/// Manages local LAN communication with the Root switch (Blueprint §3.3 & §3.4).
/// Features:
/// - mDNS resolution of _smartsw._tcp
/// - Persistent WebSocket with exponential backoff reconnection
/// - Application-layer AES-256-GCM encryption
/// - Challenge-response HKDF session key handshake from Home Key
/// - 5-second heartbeat reachability probing
class LocalTransport {
  final MdnsService mdnsService;
  final List<int> homeKey;
  final LocalCrypto crypto;
  final Duration heartbeatInterval;

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _activeGatewayId;
  DiscoveredRootGateway? _activeRootGateway;
  DiscoveredRootGateway? get activeRootGateway => _activeRootGateway;

  SecretKey? _sessionKey;
  bool _isAuthenticated = false;
  DateTime? _lastHeartbeatReceived;

  // Counter and prefix for AES-GCM nonce generation
  int _sendCounter = 0;
  final Uint8List _clientPrefix8 = LocalCrypto.generateRandomBytes(8);

  // Exponential backoff configuration
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelayMs = 5000;
  static const int _baseReconnectDelayMs = 150;

  // Pending command completers: commandId -> Completer<MessageEnvelope>
  final Map<String, Completer<MessageEnvelope>> _pendingAcks = {};

  final StreamController<MessageEnvelope> _incomingController =
      StreamController<MessageEnvelope>.broadcast();

  LocalTransport({
    required this.mdnsService,
    required this.homeKey,
    LocalCrypto? crypto,
    this.heartbeatInterval = const Duration(seconds: 5),
  })  : crypto = crypto ?? LocalCrypto();

  /// Stream of all incoming decrypted messages (state reports, ACKs, events).
  Stream<MessageEnvelope> get incomingMessages => _incomingController.stream;

  /// Returns true if:
  /// 1. Connected to gateway with an authenticated session
  /// 2. Heartbeat received within the last 5 seconds (Blueprint §3.3)
  bool isReachable(String gatewayId) {
    if (_activeGatewayId != gatewayId) return false;
    if (!_isAuthenticated || _channel == null || _sessionKey == null) return false;
    if (_lastHeartbeatReceived == null) return false;

    final elapsed = DateTime.now().difference(_lastHeartbeatReceived!);
    return elapsed.inMilliseconds <= (heartbeatInterval.inMilliseconds + 1500);
  }

  /// Initiates connection and challenge-response handshake with the Root switch.
  Future<bool> connect(String gatewayId) async {
    _activeGatewayId = gatewayId;
    _reconnectAttempts = 0;
    return _attemptConnect(gatewayId);
  }

  Future<bool> _attemptConnect(String gatewayId) async {
    _tearDownSocket();

    try {
      final gateway = await mdnsService.resolveGateway(gatewayId);
      if (gateway == null) {
        _scheduleReconnect();
        return false;
      }
      _activeRootGateway = gateway;

      final uri = Uri.parse(gateway.wsUrl);
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10),
      );

      final handshakeCompleter = Completer<bool>();
      final clientNonce = LocalCrypto.generateRandomBytes(16);

      _socketSubscription = _channel!.stream.listen(
        (dynamic message) async {
          if (message is String) {
            await _handlePlaintextMessage(message, clientNonce, handshakeCompleter);
          } else if (message is List<int>) {
            await _handleBinaryMessage(message);
          }
        },
        onError: (Object error) {
          debugPrint('LocalTransport socket error: $error');
          _onDisconnect();
        },
        onDone: () {
          debugPrint('LocalTransport socket closed');
          _onDisconnect();
        },
      );

      // Step 1: Send handshake_init
      final initEnvelope = MessageEnvelope.handshakeInit(
        gatewayId: gatewayId,
        clientNonceHex: LocalCrypto.bytesToHex(clientNonce),
      );
      _channel!.sink.add(initEnvelope.toJsonString());

      final success = await handshakeCompleter.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      if (success) {
        _reconnectAttempts = 0;
        _startHeartbeat();
        return true;
      } else {
        _scheduleReconnect();
        return false;
      }
    } catch (e) {
      debugPrint('LocalTransport connection error: $e');
      _scheduleReconnect();
      return false;
    }
  }

  Future<void> _handlePlaintextMessage(
    String raw,
    Uint8List clientNonce,
    Completer<bool> handshakeCompleter,
  ) async {
    try {
      final envelope = MessageEnvelope.fromJsonString(raw);

      if (envelope.type == 'handshake_resp') {
        // Step 2: Derive session key using HKDF-SHA256
        final serverNonceHex = envelope.reported?['serverNonce'] as String?;
        if (serverNonceHex == null) {
          if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(false);
          return;
        }

        final serverNonce = LocalCrypto.hexToBytes(serverNonceHex);
        _sessionKey = await crypto.deriveSessionKey(
          homeKeyBytes: homeKey,
          clientNonce: clientNonce,
          serverNonce: serverNonce,
        );

        // Step 3: Confirm handshake
        final confirm = MessageEnvelope.handshakeConfirm(
          gatewayId: _activeGatewayId ?? envelope.deviceId,
          commandId: envelope.commandId,
        );
        _channel!.sink.add(confirm.toJsonString());
      } else if (envelope.type == 'ack' && envelope.commandId.startsWith('hs_init_')) {
        _isAuthenticated = true;
        _lastHeartbeatReceived = DateTime.now();
        if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(true);
      } else if (envelope.type == 'heartbeat') {
        _lastHeartbeatReceived = DateTime.now();
      }
    } catch (e) {
      if (!handshakeCompleter.isCompleted) handshakeCompleter.complete(false);
    }
  }

  Future<void> _handleBinaryMessage(List<int> bytes) async {
    if (_sessionKey == null) return;

    try {
      final decryptedJson = await crypto.decryptString(
        packedPayload: bytes,
        secretKey: _sessionKey!,
      );
      final envelope = MessageEnvelope.fromJsonString(decryptedJson);

      if (envelope.type == 'heartbeat') {
        _lastHeartbeatReceived = DateTime.now();
      }

      // Check if this fulfills a pending command ACK
      if (_pendingAcks.containsKey(envelope.commandId)) {
        _pendingAcks.remove(envelope.commandId)?.complete(envelope);
      }

      _incomingController.add(envelope);
    } catch (e) {
      debugPrint('Failed to decrypt local binary message: $e');
    }
  }

  /// Sends a command envelope over the encrypted WebSocket session.
  Future<MessageEnvelope?> send(
    String gatewayId,
    MessageEnvelope envelope, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (!isReachable(gatewayId)) {
      // Attempt connect if not connected
      final connected = await connect(gatewayId);
      if (!connected) return null;
    }

    if (_channel == null || _sessionKey == null) return null;

    final completer = Completer<MessageEnvelope>();
    _pendingAcks[envelope.commandId] = completer;

    try {
      final nonce = LocalCrypto.createNonce(_clientPrefix8, ++_sendCounter);
      final encryptedBytes = await crypto.encryptString(
        text: envelope.toJsonString(),
        secretKey: _sessionKey!,
        nonce: nonce,
      );

      _channel!.sink.add(encryptedBytes);

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingAcks.remove(envelope.commandId);
          return null as dynamic;
        },
      );
    } catch (e) {
      _pendingAcks.remove(envelope.commandId);
      return null;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_channel != null && _isAuthenticated) {
        final hb = MessageEnvelope.heartbeat(gatewayId: _activeGatewayId ?? 'gw');
        _channel!.sink.add(hb.toJsonString());
      }
    });
  }

  void _scheduleReconnect() {
    if (_activeGatewayId == null) return;
    _reconnectTimer?.cancel();

    final delayMs = min(
      _maxReconnectDelayMs,
      _baseReconnectDelayMs * pow(2, _reconnectAttempts).toInt(),
    );
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_activeGatewayId != null) {
        _attemptConnect(_activeGatewayId!);
      }
    });
  }

  void _onDisconnect() {
    _isAuthenticated = false;
    _lastHeartbeatReceived = null;
    _tearDownSocket();
    _scheduleReconnect();
  }

  void _tearDownSocket() {
    _heartbeatTimer?.cancel();
    _socketSubscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Manually force a re-probe and re-discovery.
  Future<void> reprobe() async {
    if (_activeGatewayId != null) {
      await connect(_activeGatewayId!);
    }
  }

  void dispose() {
    _activeGatewayId = null;
    _reconnectTimer?.cancel();
    _tearDownSocket();
    _incomingController.close();
  }
}
