import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/transport/local_transport.dart';
import 'package:smartswitch_app/transport/mdns_service.dart';
import 'package:smartswitch_app/transport/models/message_envelope.dart';
import '../../tools/mock_root/mock_root_server.dart';

void main() {
  group('MockRootServer & LocalTransport Integration', () {
    late MockRootServer mockServer;
    late FakeMdnsService fakeMdns;
    late LocalTransport localTransport;
    final homeKey = List<int>.generate(32, (i) => (i * 7) % 256);
    const gatewayId = 'gw_root_test';

    setUp(() async {
      mockServer = MockRootServer(
        gatewayId: gatewayId,
        homeKey: homeKey,
        requestedPort: 0, // pick available ephemeral port
      );
      await mockServer.start();

      fakeMdns = FakeMdnsService(
        initial: [
          DiscoveredRootGateway(
            gatewayId: gatewayId,
            host: '127.0.0.1',
            port: mockServer.port,
          ),
        ],
      );

      localTransport = LocalTransport(
        mdnsService: fakeMdns,
        homeKey: homeKey,
        heartbeatInterval: const Duration(seconds: 2),
      );
    });

    tearDown(() async {
      localTransport.dispose();
      await mockServer.stop();
    });

    test('establishes authenticated session and exchanges encrypted commands', () async {
      final connected = await localTransport.connect(gatewayId);
      expect(connected, isTrue);
      expect(localTransport.isReachable(gatewayId), isTrue);

      final cmd = MessageEnvelope.cmd(
        deviceId: 'dev_sw_01',
        commandId: 'cmd_test_1',
        desired: {'gang1': {'on': true}},
      );

      final ack = await localTransport.send(gatewayId, cmd);
      expect(ack, isNotNull);
      expect(ack!.type, 'ack');
      expect(ack.commandId, 'cmd_test_1');
      expect(ack.reported?['gang1']?['on'], isTrue);
      expect(mockServer.executionCount, 1);
    });

    test('ACCEPTANCE TEST: p50 local round trip is under 30 ms against the mock', () async {
      final connected = await localTransport.connect(gatewayId);
      expect(connected, isTrue);

      const iterations = 40;
      final latencies = <int>[];

      // Warm-up iteration
      await localTransport.send(
        gatewayId,
        MessageEnvelope.cmd(
          deviceId: 'dev_warmup',
          commandId: 'cmd_warmup',
          desired: {'on': true},
        ),
      );

      for (var i = 0; i < iterations; i++) {
        final sw = Stopwatch()..start();
        final ack = await localTransport.send(
          gatewayId,
          MessageEnvelope.cmd(
            deviceId: 'dev_bench',
            commandId: 'cmd_bench_$i',
            desired: {'gang1': {'on': i.isEven}},
          ),
        );
        sw.stop();
        expect(ack, isNotNull);
        latencies.add(sw.elapsedMilliseconds);
      }

      latencies.sort();
      final p50 = latencies[latencies.length ~/ 2];

      // Acceptance criterion: p50 under 30 ms
      expect(p50, lessThan(30),
          reason: 'p50 latency ($p50 ms) must be under 30 ms. Latencies: $latencies');
    });

    test('Idempotency: duplicate commands return cached ACK without duplicate execution', () async {
      final connected = await localTransport.connect(gatewayId);
      expect(connected, isTrue);

      final cmd = MessageEnvelope.cmd(
        deviceId: 'dev_sw_02',
        commandId: 'idempotent_cmd_999',
        desired: {'relay': 'on'},
      );

      // First delivery
      final ack1 = await localTransport.send(gatewayId, cmd);
      expect(ack1, isNotNull);
      expect(mockServer.executionCount, 1);
      expect(mockServer.duplicateCount, 0);

      // Duplicate delivery with same commandId
      final ack2 = await localTransport.send(gatewayId, cmd);
      expect(ack2, isNotNull);
      expect(ack2!.commandId, 'idempotent_cmd_999');

      // Assert device executed EXACTLY ONCE
      expect(mockServer.executionCount, 1);
      expect(mockServer.duplicateCount, 1);
      expect(mockServer.totalCommandsReceived, 2);
    });
  });
}
