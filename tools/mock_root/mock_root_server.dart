import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:smartswitch_app/transport/crypto/local_crypto.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';

/// Standalone Mock Root switch server for integration testing and benchmarking (Blueprint §3.4).
/// Simulates an ESP32 Root switch:
/// - mDNS advertisement emulation
/// - WebSocket server on loopback
/// - Challenge-response HKDF handshake + AES-256-GCM message encryption
/// - 5s heartbeat replies
/// - Idempotent command de-duplication cache
/// - Sub-millisecond to low-millisecond local switching responses (<30 ms p50)
/// - Configurable LAN failure / connection drop simulation
class MockRootServer {
  final String gatewayId;
  final List<int> homeKey;
  final int requestedPort;
  final Duration simulatedDelay;

  HttpServer? _server;
  int _port = 0;
  int get port => _port;
  String get wsUrl => 'ws://127.0.0.1:$_port/ws';

  final LocalCrypto _crypto = LocalCrypto();

  // Internal state
  SecretKey? _sessionKey;
  bool _isAuthenticated = false;
  int _currentVer = 100;
  int _sendCounter = 0;
  Uint8List? _serverPrefix8;

  // Idempotency de-duplication cache: commandId -> cached ACK envelope
  final Map<String, MessageEnvelope> _commandCache = {};

  // Metrics
  int executionCount = 0;
  int duplicateCount = 0;
  int totalCommandsReceived = 0;

  // Active client sockets
  final List<WebSocket> _clients = [];

  // Failure simulation switches
  bool dropNextCommandMidExecution = false;
  bool refuseConnections = false;

  MockRootServer({
    this.gatewayId = 'gw_root_01',
    required this.homeKey,
    this.requestedPort = 0, // 0 picks an ephemeral available port
    this.simulatedDelay = Duration.zero,
  });

  /// Starts the HTTP / WebSocket server on 127.0.0.1.
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, requestedPort);
    _port = _server!.port;

    _server!.listen((HttpRequest request) async {
      if (refuseConnections) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        _handleClient(socket);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });
  }

  void _handleClient(WebSocket socket) {
    socket.listen(
      (dynamic data) async {
        if (data is String) {
          await _handlePlaintextMessage(socket, data);
        } else if (data is List<int>) {
          await _handleBinaryMessage(socket, data);
        }
      },
      onDone: () => _clients.remove(socket),
      onError: (_) => _clients.remove(socket),
    );
  }

  Future<void> _handlePlaintextMessage(WebSocket socket, String raw) async {
    try {
      final envelope = MessageEnvelope.fromJsonString(raw);

      if (envelope.type == 'handshake_init') {
        // Step 1: Handshake challenge-response
        final clientNonceHex = envelope.desired?['clientNonce'] as String?;
        if (clientNonceHex == null) return;

        final clientNonce = LocalCrypto.hexToBytes(clientNonceHex);
        final serverNonce = LocalCrypto.generateRandomBytes(16);
        _serverPrefix8 = LocalCrypto.generateRandomBytes(8);

        _sessionKey = await _crypto.deriveSessionKey(
          homeKeyBytes: homeKey,
          clientNonce: clientNonce,
          serverNonce: serverNonce,
        );

        final resp = MessageEnvelope.handshakeResp(
          gatewayId: gatewayId,
          commandId: envelope.commandId,
          serverNonceHex: LocalCrypto.bytesToHex(serverNonce),
        );
        socket.add(resp.toJsonString());
      } else if (envelope.type == 'handshake_confirm') {
        // Handshake completed
        _isAuthenticated = true;
        final ack = MessageEnvelope.ack(
          deviceId: gatewayId,
          commandId: envelope.commandId,
        );
        socket.add(ack.toJsonString());
      } else if (envelope.type == 'heartbeat') {
        // Heartbeat reply
        final ack = MessageEnvelope(
          type: 'heartbeat',
          deviceId: gatewayId,
          commandId: envelope.commandId,
          ts: DateTime.now().millisecondsSinceEpoch,
        );
        socket.add(ack.toJsonString());
      }
    } catch (_) {}
  }

  Future<void> _handleBinaryMessage(WebSocket socket, List<int> data) async {
    if (!_isAuthenticated || _sessionKey == null) {
      socket.close(WebSocketStatus.policyViolation, 'Unauthenticated');
      return;
    }

    try {
      final decryptedJson = await _crypto.decryptString(
        packedPayload: data,
        secretKey: _sessionKey!,
      );
      final envelope = MessageEnvelope.fromJsonString(decryptedJson);

      if (dropNextCommandMidExecution) {
        dropNextCommandMidExecution = false;
        // Simulate immediate LAN drop mid-command
        socket.close(WebSocketStatus.goingAway, 'Simulated LAN connection drop');
        return;
      }

      if (simulatedDelay > Duration.zero) {
        await Future<void>.delayed(simulatedDelay);
      }

      final response = _processCommand(envelope);
      if (response != null) {
        final nonce = LocalCrypto.createNonce(_serverPrefix8!, ++_sendCounter);
        final encryptedResp = await _crypto.encryptString(
          text: response.toJsonString(),
          secretKey: _sessionKey!,
          nonce: nonce,
        );
        socket.add(encryptedResp);
      }
    } catch (_) {}
  }

  MessageEnvelope? _processCommand(MessageEnvelope envelope) {
    if (envelope.type == 'heartbeat') {
      return MessageEnvelope(
        type: 'heartbeat',
        deviceId: gatewayId,
        commandId: envelope.commandId,
        ts: DateTime.now().millisecondsSinceEpoch,
      );
    }

    if (envelope.type != 'cmd') return null;

    totalCommandsReceived++;

    // Idempotency Check: if commandId already seen, do NOT execute again!
    if (_commandCache.containsKey(envelope.commandId)) {
      duplicateCount++;
      return _commandCache[envelope.commandId];
    }

    // New command: execute
    executionCount++;
    _currentVer++;

    final ack = MessageEnvelope.ack(
      deviceId: envelope.deviceId,
      commandId: envelope.commandId,
      reported: envelope.desired,
      ver: _currentVer,
      ts: DateTime.now().millisecondsSinceEpoch,
    );

    _commandCache[envelope.commandId] = ack;
    return ack;
  }

  /// Closes all sockets and shuts down the HTTP server.
  Future<void> stop() async {
    for (final client in _clients.toList()) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();
    await _server?.close(force: true);
    _server = null;
    _isAuthenticated = false;
    _sessionKey = null;
  }
}
