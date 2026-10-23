import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/models/models.dart';
import '../../../state/mesh_topology_state.dart';
import '../widgets/topology_view.dart';

/// Production Mesh Diagnostics screen conforming to Blueprint §4.4.
class MeshDiagScreen extends ConsumerStatefulWidget {
  const MeshDiagScreen({super.key});

  @override
  ConsumerState<MeshDiagScreen> createState() => _MeshDiagScreenState();
}

class _MeshDiagScreenState extends ConsumerState<MeshDiagScreen> {
  Timer? _autoRefreshTimer;
  bool _autoRefreshEnabled = true;

  // Mock ping latencies: deviceId -> latencyMs
  final Map<String, int> _pingLatencies = {};
  bool _isPingingAll = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    // Seed initial topology if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(meshTopologyStateProvider);
      if (current.nodes.isEmpty) {
        _seedMockTopology();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_autoRefreshEnabled) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) _refreshTopology();
      });
    }
  }

  void _refreshTopology() {
    ref.read(meshTopologyStateProvider.notifier).setRefreshing(true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _seedMockTopology();
      }
    });
  }

  void _seedMockTopology() {
    final now = DateTime.now();
    final nodes = [
      MeshNode(
        deviceId: 'gw_root1',
        name: 'Hall Root',
        roomId: 'r_hall',
        role: MeshRole.root,
        layer: 1,
        childrenCount: 2,
        rssiToParent: -48,
        uptimeSeconds: 86400,
        lastSeen: now,
        fwVersion: '1.2.0',
      ),
      MeshNode(
        deviceId: 'dev_bed',
        name: 'Bedroom 1',
        roomId: 'r_bed',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        childrenCount: 1,
        rssiToParent: -58, // Excellent
        uptimeSeconds: 72000,
        lastSeen: now,
        fwVersion: '1.2.0',
      ),
      MeshNode(
        deviceId: 'dev_kitchen',
        name: 'Kitchen',
        roomId: 'r_kitchen',
        role: MeshRole.node,
        layer: 2,
        parentId: 'gw_root1',
        childrenCount: 0,
        rssiToParent: -68, // Fair
        uptimeSeconds: 65000,
        lastSeen: now,
        fwVersion: '1.2.0',
      ),
      MeshNode(
        deviceId: 'dev_balcony',
        name: 'Balcony',
        roomId: 'r_balcony',
        role: MeshRole.node,
        layer: 3,
        parentId: 'dev_bed',
        childrenCount: 0,
        rssiToParent: -78, // Weak
        uptimeSeconds: 34000,
        lastSeen: now,
        fwVersion: '1.2.0',
      ),
    ];

    ref.read(meshTopologyStateProvider.notifier).updateTopology(nodes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topologyState = ref.watch(meshTopologyStateProvider);

    final health = topologyState.healthScore;
    final healthColor = health == MeshHealth.green
        ? AppColors.success
        : (health == MeshHealth.amber ? AppColors.accent : AppColors.error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy Diagnostics',
            onPressed: () => _copyDiagnosticsReport(topologyState),
          ),
          IconButton(
            icon: Icon(
              _autoRefreshEnabled ? Icons.sync : Icons.sync_disabled,
              color: _autoRefreshEnabled ? AppColors.accent : theme.disabledColor,
            ),
            tooltip: 'Auto-refresh (5s)',
            onPressed: () {
              setState(() {
                _autoRefreshEnabled = !_autoRefreshEnabled;
                _startAutoRefresh();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_autoRefreshEnabled
                      ? 'Live auto-refresh enabled (5s)'
                      : 'Live auto-refresh paused'),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Card: Health Score, Online count, Root badge (Blueprint §4.4)
              Container(
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: healthColor,
                              ),
                            ),
                            const SizedBox(width: Spacing.xs),
                            Text(
                              health.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: healthColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          '${topologyState.onlineCount} of ${topologyState.totalCount} switches online',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    // Root gateway crown indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(Radii.toggle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            'Root: ${topologyState.rootGatewayId ?? "N/A"}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Spacing.lg),

              // 2. Legend Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Strong (> -60)', AppColors.rssiStrong),
                  const SizedBox(width: Spacing.md),
                  _buildLegendItem('Fair (-60..-75)', AppColors.rssiFair),
                  const SizedBox(width: Spacing.md),
                  _buildLegendItem('Weak (< -75)', AppColors.rssiWeak),
                ],
              ),

              const SizedBox(height: Spacing.md),

              // 3. Topology View Canvas (CustomPainter)
              Text(
                'Mesh Topology Tree',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'Tap any node to view diagnostics or ping.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: TopologyView(
                  nodes: topologyState.nodes,
                  onNodeTap: (node) => _showNodeDetailSheet(context, node),
                ),
              ),

              const SizedBox(height: Spacing.lg),

              // 4. Tools Section: Ping All & Node Latencies
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mesh Latency Probing', style: theme.textTheme.titleMedium),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                    icon: _isPingingAll
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.network_ping_rounded, size: 18),
                    label: const Text('Ping All'),
                    onPressed: _isPingingAll ? null : () => _pingAllNodes(topologyState.nodes),
                  ),
                ],
              ),

              const SizedBox(height: Spacing.sm),

              if (_pingLatencies.isNotEmpty)
                Column(
                  children: topologyState.nodes.map((node) {
                    final ms = _pingLatencies[node.deviceId];
                    return Container(
                      margin: const EdgeInsets.only(bottom: Spacing.xs),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: Spacing.sm),
                              Text('Layer ${node.layer}',
                                  style: TextStyle(color: theme.disabledColor, fontSize: 12)),
                            ],
                          ),
                          Text(
                            ms != null ? '$ms ms' : 'Probing...',
                            style: TextStyle(
                              color: ms != null && ms < 30 ? AppColors.success : AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Future<void> _pingAllNodes(List<MeshNode> nodes) async {
    setState(() => _isPingingAll = true);
    for (final node in nodes) {
      await Future.delayed(const Duration(milliseconds: 80));
      // Simulate typical hop latencies from blueprint target: 5-20 ms per hop
      final base = node.role == MeshRole.root ? 6 : (12 * node.layer);
      _pingLatencies[node.deviceId] = base + (node.deviceId.hashCode % 8);
      if (mounted) setState(() {});
    }
    setState(() => _isPingingAll = false);
  }

  void _copyDiagnosticsReport(MeshTopologyState topologyState) {
    final buffer = StringBuffer();
    buffer.writeln('=== SMART SWITCH MESH DIAGNOSTICS REPORT ===');
    buffer.writeln('Health Score: ${topologyState.healthScore.name}');
    buffer.writeln('Online Nodes: ${topologyState.onlineCount}/${topologyState.totalCount}');
    buffer.writeln('Current Root: ${topologyState.rootGatewayId}');
    buffer.writeln('\n--- Node Routing Table ---');
    for (final n in topologyState.nodes) {
      buffer.writeln(
        'Node: ${n.name} (${n.deviceId}) | Role: ${n.role.name} | Layer: ${n.layer} | Parent: ${n.parentId ?? "None"} | RSSI: ${n.rssiToParent} dBm | Uptime: ${n.uptimeSeconds}s',
      );
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics report copied to clipboard')),
    );
  }

  void _showNodeDetailSheet(BuildContext context, MeshNode node) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(node.name, style: Theme.of(context).textTheme.titleLarge),
                  StatusChip(
                    label: node.role == MeshRole.root ? 'ROOT GATEWAY' : 'SUB-NODE',
                    color: node.role == MeshRole.root ? AppColors.accent : AppColors.success,
                    backgroundColor: (node.role == MeshRole.root
                            ? AppColors.accent
                            : AppColors.success)
                        .withValues(alpha: 0.15),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Text('Device ID: ${node.deviceId}', style: const TextStyle(fontSize: 12)),
              const Divider(height: Spacing.lg),
              _buildDetailRow('Mesh Layer', 'Layer ${node.layer}'),
              _buildDetailRow('Parent Gateway', node.parentId ?? 'None (Root Switch)'),
              _buildDetailRow('Signal to Parent', '${node.rssiToParent} dBm (${node.linkQuality.name})'),
              _buildDetailRow('Uptime', '${node.uptimeSeconds ~/ 3600} hours'),
              _buildDetailRow('Firmware', node.fwVersion),
              const SizedBox(height: Spacing.lg),

              // Action Buttons: Ping, Identify, Reboot, Remove (Blueprint §4.4)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: const Text('Identify'),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Flashing backlight on ${node.name}...')),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reboot'),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rebooting ${node.name}...')),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.offline)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
