import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// Resolved Root switch discovery entry from mDNS.
@immutable
class DiscoveredRootGateway {
  final String gatewayId;
  final String host;
  final int port;
  final Map<String, String> txtAttributes;

  const DiscoveredRootGateway({
    required this.gatewayId,
    required this.host,
    required this.port,
    this.txtAttributes = const {},
  });

  String get wsUrl => 'ws://$host:$port/ws';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredRootGateway &&
          runtimeType == other.runtimeType &&
          gatewayId == other.gatewayId &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => Object.hash(gatewayId, host, port);

  @override
  String toString() => 'DiscoveredRootGateway($gatewayId at $host:$port)';
}

/// Abstract contract for discovering Root switches via mDNS.
abstract interface class MdnsService {
  /// Resolves the current network address of a target Root gateway by ID.
  Future<DiscoveredRootGateway?> resolveGateway(
    String gatewayId, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Scans for all available `_smartsw._tcp` Root switches.
  Stream<DiscoveredRootGateway> discoverSmartSwitches({
    Duration timeout = const Duration(seconds: 3),
  });

  void dispose();
}

/// In-memory/fake mDNS service for testing and mock environments.
class FakeMdnsService implements MdnsService {
  final Map<String, DiscoveredRootGateway> _registeredGateways = {};
  final StreamController<DiscoveredRootGateway> _discoveryController =
      StreamController<DiscoveredRootGateway>.broadcast();

  FakeMdnsService({List<DiscoveredRootGateway>? initial}) {
    if (initial != null) {
      for (final gw in initial) {
        _registeredGateways[gw.gatewayId] = gw;
      }
    }
  }

  void registerOrUpdate(DiscoveredRootGateway gateway) {
    _registeredGateways[gateway.gatewayId] = gateway;
    _discoveryController.add(gateway);
  }

  void remove(String gatewayId) {
    _registeredGateways.remove(gatewayId);
  }

  @override
  Future<DiscoveredRootGateway?> resolveGateway(
    String gatewayId, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return _registeredGateways[gatewayId];
  }

  @override
  Stream<DiscoveredRootGateway> discoverSmartSwitches({
    Duration timeout = const Duration(seconds: 3),
  }) async* {
    for (final gw in _registeredGateways.values) {
      yield gw;
    }
    yield* _discoveryController.stream;
  }

  @override
  void dispose() {
    _discoveryController.close();
  }
}

/// Production mDNS service using `multicast_dns` package to find `_smartsw._tcp`.
class MulticastDnsService implements MdnsService {
  final MDnsClient _client;
  bool _isStarted = false;

  MulticastDnsService({MDnsClient? client})
      : _client = client ?? MDnsClient();

  Future<void> _ensureStarted() async {
    if (!_isStarted) {
      await _client.start();
      _isStarted = true;
    }
  }

  @override
  Future<DiscoveredRootGateway?> resolveGateway(
    String gatewayId, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await _ensureStarted();

    try {
      final stream = discoverSmartSwitches(timeout: timeout);
      await for (final gw in stream) {
        if (gw.gatewayId == gatewayId) {
          return gw;
        }
      }
    } catch (e) {
      debugPrint('mDNS resolve error: $e');
    }
    return null;
  }

  @override
  Stream<DiscoveredRootGateway> discoverSmartSwitches({
    Duration timeout = const Duration(seconds: 3),
  }) async* {
    await _ensureStarted();

    const serviceType = '_smartsw._tcp.local';
    final ptrStream = _client.lookup<PtrResourceRecord>(
      ResourceRecordQuery.serverPointer(serviceType),
    );

    await for (final ptr in ptrStream) {
      // Resolve SRV (port and target host)
      final srvStream = _client.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(ptr.domainName),
      );

      await for (final srv in srvStream) {
        // Resolve IP address (A record)
        final ipStream = _client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4(srv.target),
        );

        await for (final ip in ipStream) {
          final gatewayId = ptr.domainName.split('.').first;
          yield DiscoveredRootGateway(
            gatewayId: gatewayId,
            host: ip.address.address,
            port: srv.port,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    if (_isStarted) {
      _client.stop();
      _isStarted = false;
    }
  }
}
