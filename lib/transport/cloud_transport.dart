import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'models/message_envelope.dart';

/// Contract for Cloud communications over MQTT (Blueprint §3.5).
abstract interface class CloudTransport {
  /// Whether the cloud connection is active.
  bool get isConnected;

  /// Connects to the cloud broker over WSS with TLS.
  Future<bool> connect({
    required String homeId,
    required String brokerUrl,
    int port = 8883,
    String? clientIdentifier,
  });

  /// Sends a command envelope over the cloud path to `home/{homeId}/dev/{deviceId}/cmd`.
  Future<MessageEnvelope?> send(
    String homeId,
    String deviceId,
    MessageEnvelope envelope, {
    Duration timeout = const Duration(seconds: 4),
  });

  /// Subscribes to device state updates for all switches in [homeId].
  Future<void> subscribeToHome(String homeId);

  /// Stream of all incoming state and event envelopes received from the cloud.
  Stream<MessageEnvelope> get incomingMessages;

  /// Closes connection and releases resources.
  Future<void> disconnect();
}

/// Production implementation of [CloudTransport] using `mqtt_client` over WSS with TLS.
class MqttCloudTransport implements CloudTransport {
  MqttServerClient? _client;
  String? _homeId;
  String? get currentHomeId => _homeId;
  bool _isConnected = false;

  final StreamController<MessageEnvelope> _incomingController =
      StreamController<MessageEnvelope>.broadcast();

  final Map<String, Completer<MessageEnvelope>> _pendingAcks = {};

  @override
  bool get isConnected => _isConnected && (_client?.connectionStatus?.state == MqttConnectionState.connected);

  @override
  Stream<MessageEnvelope> get incomingMessages => _incomingController.stream;

  @override
  Future<bool> connect({
    required String homeId,
    required String brokerUrl,
    int port = 8883,
    String? clientIdentifier,
  }) async {
    _homeId = homeId;
    final clientId = clientIdentifier ?? 'app_${DateTime.now().millisecondsSinceEpoch}';

    _client = MqttServerClient.withPort(brokerUrl, clientId, port);
    _client!.useWebSocket = true;
    _client!.secure = true;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;

    // Last-Will and Testament (Blueprint §3.5)
    final willMsg = jsonEncode({
      'online': false,
      'clientId': clientId,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    final willTopic = 'home/$homeId/client/$clientId/status';
    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic(willTopic)
        .withWillMessage(willMsg)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain();

    try {
      final status = await _client!.connect();
      _isConnected = status?.state == MqttConnectionState.connected;

      if (_isConnected) {
        _listenToIncoming();
        await subscribeToHome(homeId);
      }
      return _isConnected;
    } catch (e) {
      debugPrint('MqttCloudTransport connect error: $e');
      _isConnected = false;
      return false;
    }
  }

  void _listenToIncoming() {
    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        final raw = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final envelope = MessageEnvelope.fromJsonString(raw);

          // Complete any matching pending command ACK
          if (_pendingAcks.containsKey(envelope.commandId)) {
            _pendingAcks.remove(envelope.commandId)?.complete(envelope);
          }

          _incomingController.add(envelope);
        } catch (_) {}
      }
    });
  }

  @override
  Future<void> subscribeToHome(String homeId) async {
    if (!isConnected || _client == null) return;

    // Subscribe to state reports: home/{homeId}/dev/+/state
    final stateTopic = 'home/$homeId/dev/+/state';
    _client!.subscribe(stateTopic, MqttQos.atLeastOnce);

    // Subscribe to gateway status / LWT: home/{homeId}/gw/+/status
    final gwTopic = 'home/$homeId/gw/+/status';
    _client!.subscribe(gwTopic, MqttQos.atLeastOnce);

    // Subscribe to events: home/{homeId}/events
    final eventsTopic = 'home/$homeId/events';
    _client!.subscribe(eventsTopic, MqttQos.atLeastOnce);
  }

  @override
  Future<MessageEnvelope?> send(
    String homeId,
    String deviceId,
    MessageEnvelope envelope, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!isConnected || _client == null) return null;

    final topic = 'home/$homeId/dev/$deviceId/cmd';
    final payload = envelope.toJsonString();

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    final completer = Completer<MessageEnvelope>();
    _pendingAcks[envelope.commandId] = completer;

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingAcks.remove(envelope.commandId);
          return null as dynamic;
        },
      );
    } catch (_) {
      _pendingAcks.remove(envelope.commandId);
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _client?.disconnect();
    _client = null;
    await _incomingController.close();
  }
}

/// In-memory Mock Cloud Transport for testing (no external broker dependency).
class MockCloudTransport implements CloudTransport {
  bool _connected = false;
  final StreamController<MessageEnvelope> _incomingController =
      StreamController<MessageEnvelope>.broadcast();

  final List<MessageEnvelope> publishedCommands = [];
  Duration responseDelay;
  bool shouldFailSend;

  MockCloudTransport({
    bool startConnected = true,
    this.responseDelay = const Duration(milliseconds: 10),
    this.shouldFailSend = false,
  }) : _connected = startConnected;

  @override
  bool get isConnected => _connected;

  set isConnected(bool val) => _connected = val;

  @override
  Stream<MessageEnvelope> get incomingMessages => _incomingController.stream;

  @override
  Future<bool> connect({
    required String homeId,
    required String brokerUrl,
    int port = 8883,
    String? clientIdentifier,
  }) async {
    _connected = true;
    return true;
  }

  @override
  Future<void> subscribeToHome(String homeId) async {}

  @override
  Future<MessageEnvelope?> send(
    String homeId,
    String deviceId,
    MessageEnvelope envelope, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (!_connected || shouldFailSend) return null;

    publishedCommands.add(envelope);

    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    // Generate cloud ACK
    final ack = MessageEnvelope.ack(
      deviceId: deviceId,
      commandId: envelope.commandId,
      reported: envelope.desired,
      ver: 101,
      ts: DateTime.now().millisecondsSinceEpoch,
    );

    _incomingController.add(ack);
    return ack;
  }

  void emitIncoming(MessageEnvelope envelope) {
    _incomingController.add(envelope);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _incomingController.close();
  }
}
