import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/features/mesh_diag/widgets/topology_view.dart';

void main() {
  final now = DateTime.now();
  final testNodes = [
    MeshNode(
      deviceId: 'gw_root1',
      name: 'Hall (Root)',
      roomId: 'r_hall',
      role: MeshRole.root,
      layer: 1,
      childrenCount: 2,
      rssiToParent: -48,
      lastSeen: now,
    ),
    MeshNode(
      deviceId: 'node_bed',
      name: 'Bedroom',
      roomId: 'r_bed',
      role: MeshRole.node,
      layer: 2,
      parentId: 'gw_root1',
      rssiToParent: -58, // Green link
      lastSeen: now,
    ),
    MeshNode(
      deviceId: 'node_kitchen',
      name: 'Kitchen',
      roomId: 'r_kitchen',
      role: MeshRole.node,
      layer: 2,
      parentId: 'gw_root1',
      rssiToParent: -78, // Red link
      lastSeen: now,
    ),
  ];

  Widget buildTopologyView({
    required List<MeshNode> nodes,
    ValueChanged<MeshNode>? onNodeTap,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: brightness == Brightness.dark ? darkTheme : lightTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 300,
            child: TopologyView(
              nodes: nodes,
              height: 300,
              onNodeTap: onNodeTap,
            ),
          ),
        ),
      ),
    );
  }

  group('TopologyView Component & Golden Tests (Blueprint §4.4)', () {
    testWidgets('Tapping a node triggers onNodeTap callback', (tester) async {
      MeshNode? tapped;

      await tester.pumpWidget(
        buildTopologyView(
          nodes: testNodes,
          onNodeTap: (node) => tapped = node,
        ),
      );

      expect(find.byType(TopologyView), findsOneWidget);

      // Tap Root node location (center top of TopologyView: local (180, 100))
      final topLeft = tester.getTopLeft(find.byType(TopologyView));
      await tester.tapAt(topLeft + const Offset(180, 100));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped?.deviceId, 'gw_root1');
      expect(tapped?.role, MeshRole.root);
    });

    testWidgets('Golden: TopologyView Light Mode', (tester) async {
      await tester.pumpWidget(buildTopologyView(nodes: testNodes, brightness: Brightness.light));
      await expectLater(
        find.byType(TopologyView),
        matchesGoldenFile('goldens/topology_view_light.png'),
      );
    });

    testWidgets('Golden: TopologyView Dark Mode', (tester) async {
      await tester.pumpWidget(buildTopologyView(nodes: testNodes, brightness: Brightness.dark));
      await expectLater(
        find.byType(TopologyView),
        matchesGoldenFile('goldens/topology_view_dark.png'),
      );
    });
  });
}
