import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartswitch_app/main.dart';

void main() {
  testWidgets('Placeholder home screen renders correctly', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartSwitchApp(),
      ),
    );

    // Verify the placeholder screen shows key elements.
    expect(find.text('SmartSwitch'), findsOneWidget);
    expect(find.text('Welcome to SmartSwitch'), findsOneWidget);
    expect(find.text('Phase 0 — Foundation ready.'), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsOneWidget);
  });
}
