import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/models.dart';

/// Overall mesh network health category (Blueprint §4.4).
enum MeshHealth {
  green, // Excellent health, all nodes strong and online
  amber, // Fair health, some weak links or minor packet drops
  red; // Poor health, disconnected nodes or missing root

  String get displayName {
    switch (this) {
      case MeshHealth.green:
        return 'Healthy';
      case MeshHealth.amber:
        return 'Degraded';
      case MeshHealth.red:
        return 'Critical';
    }
  }
}

/// Presentation state for the Mesh Diagnostics screen (Blueprint §4.4).
@immutable
class MeshTopologyState {
  final List<MeshNode> nodes;
  final String? rootGatewayId;
  final MeshHealth healthScore;
  final int onlineCount;
  final int totalCount;
  final bool isRefreshing;

  const MeshTopologyState({
    this.nodes = const [],
    this.rootGatewayId,
    this.healthScore = MeshHealth.green,
    this.onlineCount = 0,
    this.totalCount = 0,
    this.isRefreshing = false,
  });

  MeshNode? get rootNode {
    return nodes.cast<MeshNode?>().firstWhere(
          (n) => n?.role == MeshRole.root,
          orElse: () => null,
        );
  }

  MeshTopologyState copyWith({
    List<MeshNode>? nodes,
    String? rootGatewayId,
    MeshHealth? healthScore,
    int? onlineCount,
    int? totalCount,
    bool? isRefreshing,
  }) {
    return MeshTopologyState(
      nodes: nodes ?? this.nodes,
      rootGatewayId: rootGatewayId ?? this.rootGatewayId,
      healthScore: healthScore ?? this.healthScore,
      onlineCount: onlineCount ?? this.onlineCount,
      totalCount: totalCount ?? this.totalCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshTopologyState &&
          runtimeType == other.runtimeType &&
          listEquals(nodes, other.nodes) &&
          rootGatewayId == other.rootGatewayId &&
          healthScore == other.healthScore &&
          onlineCount == other.onlineCount &&
          totalCount == other.totalCount &&
          isRefreshing == other.isRefreshing;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(nodes),
        rootGatewayId,
        healthScore,
        onlineCount,
        totalCount,
        isRefreshing,
      );

  @override
  String toString() =>
      'MeshTopologyState(nodes: $totalCount, online: $onlineCount, health: ${healthScore.name}, root: $rootGatewayId)';
}

class MeshTopologyNotifier extends Notifier<MeshTopologyState> {
  @override
  MeshTopologyState build() {
    return const MeshTopologyState();
  }

  void setRefreshing(bool refreshing) {
    state = state.copyWith(isRefreshing: refreshing);
  }

  /// Sets nodes directly with optional root gateway ID override
  void setNodes({
    required List<MeshNode> nodes,
    String? rootGatewayId,
  }) {
    final root = nodes.cast<MeshNode?>().firstWhere(
          (n) => n?.role == MeshRole.root,
          orElse: () => null,
        );

    final total = nodes.length;
    final now = DateTime.now();
    final online = nodes.where((n) => now.difference(n.lastSeen).inSeconds < 60).length;
    final score = _computeHealthScore(nodes, online, total);

    state = state.copyWith(
      nodes: nodes,
      rootGatewayId: rootGatewayId ?? root?.deviceId,
      healthScore: score,
      onlineCount: online,
      totalCount: total,
      isRefreshing: false,
    );
  }

  void updateTopology(List<MeshNode> nodes) {
    final root = nodes.cast<MeshNode?>().firstWhere(
          (n) => n?.role == MeshRole.root,
          orElse: () => null,
        );

    final total = nodes.length;
    final now = DateTime.now();
    // A node is considered online if seen within 60s
    final online = nodes.where((n) => now.difference(n.lastSeen).inSeconds < 60).length;

    final score = _computeHealthScore(nodes, online, total);

    state = state.copyWith(
      nodes: nodes,
      rootGatewayId: root?.deviceId,
      healthScore: score,
      onlineCount: online,
      totalCount: total,
      isRefreshing: false,
    );
  }

  static MeshHealth _computeHealthScore(List<MeshNode> nodes, int online, int total) {
    if (total == 0) return MeshHealth.green;
    if (online == 0) return MeshHealth.red;

    final ratio = online / total;
    if (ratio < 0.6) return MeshHealth.red;

    // Check RSSI health across child nodes
    final childNodes = nodes.where((n) => n.role == MeshRole.node).toList();
    if (childNodes.isEmpty) {
      return ratio >= 0.9 ? MeshHealth.green : MeshHealth.amber;
    }

    final weakLinksCount = childNodes.where((n) => n.rssiToParent < -75).length;
    final weakRatio = weakLinksCount / childNodes.length;

    if (weakRatio > 0.4 || ratio < 0.8) {
      return MeshHealth.amber;
    }

    return MeshHealth.green;
  }
}

final meshTopologyStateProvider =
    NotifierProvider<MeshTopologyNotifier, MeshTopologyState>(MeshTopologyNotifier.new);
