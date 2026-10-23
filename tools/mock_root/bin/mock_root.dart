import 'dart:io';
import '../mock_root_server.dart';

void main(List<String> args) async {
  final homeKey = List<int>.filled(32, 0x42); // Placeholder mock key
  final server = MockRootServer(
    gatewayId: 'gw_root_01',
    homeKey: homeKey,
    requestedPort: 8088,
  );

  await server.start();
  stdout.writeln('Mock Root switch running at ${server.wsUrl}');
  stdout.writeln('Press Ctrl+C to terminate.');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down Mock Root server...');
    await server.stop();
    exit(0);
  });
}
