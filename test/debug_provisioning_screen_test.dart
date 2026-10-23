import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/features/onboarding/presentation/debug_provisioning_screen.dart';

void main() {
  testWidgets('DebugProvisioningScreen renders inputs, buttons, and scenario selector', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: lightTheme,
          home: const DebugProvisioningScreen(),
        ),
      ),
    );

    expect(find.text('Provisioning Debug Tool'), findsOneWidget);
    expect(find.text('Simulation Scenario'), findsOneWidget);
    expect(find.text('Configuration Inputs'), findsOneWidget);
    expect(find.text('Run Provisioning Flow'), findsOneWidget);
    expect(find.text('Stage'), findsOneWidget);
    expect(find.text('IDLE'), findsOneWidget);
  });
}
