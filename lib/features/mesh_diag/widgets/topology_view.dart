import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../domain/models/models.dart';

/// Interactive tree topology view custom-painted for ESP-WIFI-MESH (Blueprint §4.4).
class TopologyView extends StatefulWidget {
  final List<MeshNode> nodes;
  final ValueChanged<MeshNode>? onNodeTap;
  final double height;

  const TopologyView({
    super.key,
    required this.nodes,
    this.onNodeTap,
    this.height = 340,
  });

  @override
  State<TopologyView> createState() => _TopologyViewState();
}

class _TopologyViewState extends State<TopologyView> {
  final Map<String, Offset> _nodePositions = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, widget.height);
          _computeLayout(size);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(details.localPosition),
            child: CustomPaint(
              size: size,
              painter: _TopologyPainter(
                nodes: widget.nodes,
                nodePositions: _nodePositions,
                isDark: isDark,
              ),
            ),
          );
        },
      ),
    );
  }

  void _computeLayout(Size size) {
    _nodePositions.clear();
    if (widget.nodes.isEmpty) return;

    // Group nodes by layer: Layer 1 is Root at top
    final Map<int, List<MeshNode>> layers = {};
    for (final node in widget.nodes) {
      layers.putIfAbsent(node.layer, () => []).add(node);
    }

    final sortedLayers = layers.keys.toList()..sort();
    final verticalStep = size.height / (sortedLayers.length + 1);

    for (int l = 0; l < sortedLayers.length; l++) {
      final layerNum = sortedLayers[l];
      final layerNodes = layers[layerNum]!;
      final y = verticalStep * (l + 1);

      final horizontalStep = size.width / (layerNodes.length + 1);
      for (int i = 0; i < layerNodes.length; i++) {
        final x = horizontalStep * (i + 1);
        _nodePositions[layerNodes[i].deviceId] = Offset(x, y);
      }
    }
  }

  void _handleTap(Offset tapPos) {
    const nodeRadius = 26.0;
    for (final entry in _nodePositions.entries) {
      final center = entry.value;
      final distance = (tapPos - center).distance;
      if (distance <= nodeRadius) {
        final tappedNode = widget.nodes.firstWhere((n) => n.deviceId == entry.key);
        widget.onNodeTap?.call(tappedNode);
        return;
      }
    }
  }
}

class _TopologyPainter extends CustomPainter {
  final List<MeshNode> nodes;
  final Map<String, Offset> nodePositions;
  final bool isDark;

  _TopologyPainter({
    required this.nodes,
    required this.nodePositions,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty) return;

    // 1. Draw Links between parents and children
    for (final node in nodes) {
      if (node.parentId != null && nodePositions.containsKey(node.parentId)) {
        final p1 = nodePositions[node.parentId]!;
        final p2 = nodePositions[node.deviceId]!;

        final linkColor = _getLinkColor(node.rssiToParent);
        final linkWidth = _getLinkWidth(node.rssiToParent);

        final linkPaint = Paint()
          ..color = linkColor
          ..strokeWidth = linkWidth
          ..style = PaintingStyle.stroke;

        canvas.drawLine(p1, p2, linkPaint);
      }
    }

    // 2. Draw Nodes
    const nodeRadius = 24.0;

    for (final node in nodes) {
      final center = nodePositions[node.deviceId];
      if (center == null) continue;

      final isRoot = node.role == MeshRole.root;

      // Outer glow for Root
      if (isRoot) {
        final glowPaint = Paint()
          ..color = AppColors.accent.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        canvas.drawCircle(center, nodeRadius + 4, glowPaint);
      }

      // Node background circle
      final bgPaint = Paint()
        ..color = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, nodeRadius, bgPaint);

      // Node border
      final borderPaint = Paint()
        ..color = isRoot ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.lightBorder)
        ..strokeWidth = isRoot ? 2.5 : 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, nodeRadius, borderPaint);

      // Icon / Crown for Root
      if (isRoot) {
        _drawIcon(canvas, center.translate(0, -2), Icons.star_rounded, AppColors.accent, 22);
      } else {
        _drawIcon(
          canvas,
          center.translate(0, -2),
          Icons.developer_board_rounded,
          isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
          18,
        );
      }

      // Node Name Label
      final textSpan = TextSpan(
        text: node.name,
        style: TextStyle(
          color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
          fontSize: 10,
          fontWeight: isRoot ? FontWeight.bold : FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);

      textPainter.paint(
        canvas,
        Offset(center.dx - (textPainter.width / 2), center.dy + nodeRadius + 4),
      );
    }
  }

  void _drawIcon(Canvas canvas, Offset offset, IconData icon, Color color, double size) {
    final textSpan = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(offset.dx - (textPainter.width / 2), offset.dy - (textPainter.height / 2)),
    );
  }

  Color _getLinkColor(int rssi) {
    if (rssi > -60) return AppColors.rssiStrong;
    if (rssi >= -75) return AppColors.rssiFair;
    return AppColors.rssiWeak;
  }

  double _getLinkWidth(int rssi) {
    if (rssi > -60) return 3.0;
    if (rssi >= -75) return 2.0;
    return 1.2;
  }

  @override
  bool shouldRepaint(covariant _TopologyPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.isDark != isDark;
  }
}
