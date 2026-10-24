import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/data/local_db/in_memory_local_database.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/features/home/presentation/home_screen.dart';
import 'package:smartswitch_app/features/settings/presentation/settings_screen.dart';
import 'package:smartswitch_app/state/app_mode_state.dart';
import 'package:smartswitch_app/state/auth_state.dart';
import 'package:smartswitch_app/state/devices_state.dart';
import 'package:smartswitch_app/state/homes_state.dart';
import 'package:smartswitch_app/transport/blynk_bridge_controller.dart';
import 'package:smartswitch_app/transport/blynk_transport.dart';
import 'package:smartswitch_app/transport/models/blynk_node_map.dart';

import '../transport/fake_blynk_server.dart';

class _TestHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });
  group('Blynk Bridge Wiring & Mode Switching Tests', () {
    late FakeBlynkHttpServer server;
    late FakeSecureKeyStore secureStorage;
    late InMemoryLocalDatabase localDb;

    setUp(() async {
      server = FakeBlynkHttpServer();
      await server.start();
      secureStorage = FakeSecureKeyStore();
      localDb = InMemoryLocalDatabase();
    });

    tearDown(() async {
      await server.stop();
    });

    test('1. V16 parsing works with dynamic master and peers', () {
      const v16 =
          '244CAB112233;244CAB112233:0:1:-45:1,244CAB445566:1:0:-62:1,244CAB778899:2:1:-75:0';
      final nodeMap = BlynkNodeMap.parse(v16);

      expect(nodeMap.masterMac, '244CAB112233');
      expect(nodeMap.nodesByMac.length, 3);

      final master = nodeMap.nodesByMac['244CAB112233'];
      expect(master, isNotNull);
      expect(master!.isMaster, isTrue);
      expect(master.pin, 0);
      expect(master.state, isTrue);
      expect(master.rssi, -45);
      expect(master.isLive, isTrue);

      final peer1 = nodeMap.nodesByMac['244CAB445566'];
      expect(peer1, isNotNull);
      expect(peer1!.isMaster, isFalse);
      expect(peer1.pin, 1);
      expect(peer1.state, isFalse);
      expect(peer1.rssi, -62);
      expect(peer1.isLive, isTrue);

      final peer2 = nodeMap.nodesByMac['244CAB778899'];
      expect(peer2, isNotNull);
      expect(peer2!.isLive, isFalse);
      expect(peer2.pin, 2);
    });

    testWidgets('2. Switching modes changes what Home shows (Demo -> Blynk -> Demo)',
        (tester) async {
      final transport = BlynkCloudTransport(
        authToken: server.validToken,
        customBaseUrl: '${server.url}/external/api',
        pollingInterval: const Duration(milliseconds: 100),
      );

      final container = ProviderContainer(
        overrides: [
          secureKeyStoreProvider.overrideWithValue(secureStorage),
          appLocalDatabaseProvider.overrideWithValue(localDb),
          blynkTransportProvider.overrideWithValue(transport),
        ],
      );

      // Pre-seed Demo devices and home
      container.read(homesStateProvider.notifier).addHome(
            const Home(
              homeId: 'h_main',
              name: 'My Living Space',
              timezone: 'Asia/Kolkata',
              homeKey: [],
              meshId: '1234',
              meshApPassword: 'pass',
            ),
          );
      container.read(homesStateProvider.notifier).setActiveHome('h_main');
      container.read(devicesStateProvider.notifier).setDevices(DemoDataService.demoDevices);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Step A: In Demo mode, Home displays demo switches
      expect(find.text('Hall Chandelier'), findsOneWidget);
      expect(find.text('Kitchen Lights'), findsOneWidget);
      // No Blynk banner in demo mode
      expect(find.textContaining('Connected to Blynk'), findsNothing);

      // Step B: Switch to Blynk mode
      await secureStorage.saveBlynkConfig(token: server.validToken, region: 'blr1');
      await tester.runAsync(() async {
        await container.read(appModeProvider.notifier).setMode(AppMode.blynk);
        await transport.pollNow();
      });
      await tester.pump();

      // Home now displays Blynk hardware switches from fake server V16
      expect(find.text('ESP-NOW Master'), findsOneWidget);
      expect(find.text('Switch E502'), findsOneWidget);
      // Banner appears indicating Blynk connection
      expect(find.textContaining('Connected to Blynk'), findsOneWidget);

      // Step C: Switch back to Demo mode
      await tester.runAsync(() async {
        await container.read(appModeProvider.notifier).setMode(AppMode.demo);
      });
      await tester.pumpAndSettle();

      // Home restores Demo switches
      expect(find.text('Hall Chandelier'), findsOneWidget);
      expect(find.text('Kitchen Lights'), findsOneWidget);
      expect(find.textContaining('Connected to Blynk'), findsNothing);

      await tester.runAsync(() async {
        await transport.disconnect();
        transport.dispose();
      });
      container.dispose();
    });

    testWidgets('3. Wrong token shows error banner on Home screen',
        (tester) async {
      final transport = BlynkCloudTransport(
        authToken: 'wrong_invalid_token',
        customBaseUrl: '${server.url}/external/api',
        pollingInterval: const Duration(milliseconds: 100),
      );

      final container = ProviderContainer(
        overrides: [
          secureKeyStoreProvider.overrideWithValue(secureStorage),
          appLocalDatabaseProvider.overrideWithValue(localDb),
          blynkTransportProvider.overrideWithValue(transport),
        ],
      );

      container.read(homesStateProvider.notifier).addHome(
            const Home(
              homeId: 'h_main',
              name: 'My Living Space',
              timezone: 'Asia/Kolkata',
              homeKey: [],
              meshId: '1234',
              meshApPassword: 'pass',
            ),
          );
      container.read(homesStateProvider.notifier).setActiveHome('h_main');

      await secureStorage.saveBlynkConfig(token: 'wrong_invalid_token', region: 'blr1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Trigger Blynk mode with wrong token and wait for 401 response
      await tester.runAsync(() async {
        await container.read(appModeProvider.notifier).setMode(AppMode.blynk);
        await transport.pollNow();
      });
      await tester.pump();

      // Error banner is displayed
      expect(find.textContaining('401'), findsOneWidget);

      await tester.runAsync(() async {
        await transport.disconnect();
        transport.dispose();
      });
      container.dispose();
    });

    testWidgets('4. Settings screen exposes Mode switch, Token entry and Diagnostics panel',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final transport = BlynkCloudTransport(
        authToken: 'test_token',
        customBaseUrl: '${server.url}/external/api',
      );

      final container = ProviderContainer(
        overrides: [
          secureKeyStoreProvider.overrideWithValue(secureStorage),
          appLocalDatabaseProvider.overrideWithValue(localDb),
          blynkTransportProvider.overrideWithValue(transport),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Mode switch buttons exist
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Blynk'), findsOneWidget);

      // Auth Token and Region controls exist
      expect(find.text('Auth Token'), findsOneWidget);
      expect(find.text('Cloud Region'), findsOneWidget);
      expect(find.text('Test Connection'), findsOneWidget);
      expect(find.text('Save & Connect'), findsOneWidget);

      // Debug diagnostics panel exists
      expect(find.text('Blynk Diagnostics (Debug Panel)'), findsOneWidget);
      expect(find.text('Poll Now'), findsOneWidget);

      await tester.runAsync(() async {
        await transport.disconnect();
        transport.dispose();
      });
      container.dispose();
    });
  });
}
