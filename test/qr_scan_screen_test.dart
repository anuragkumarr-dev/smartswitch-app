import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/features/onboarding/presentation/permission_service.dart';
import 'package:smartswitch_app/features/onboarding/presentation/qr_scan_screen.dart';

void main() {
  testWidgets('QrScanScreen displays permission denied prompt when camera permission not granted', (tester) async {
    final fakePerms = FakePermissionService(cameraGranted: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: QrScanScreen(permissionService: fakePerms),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera Permission Needed'), findsOneWidget);
    expect(find.text('Grant Permission'), findsOneWidget);
    expect(find.text('Enter Code Manually'), findsOneWidget);
  });

  testWidgets('QrScanScreen opens manual input dialog', (tester) async {
    final fakePerms = FakePermissionService(cameraGranted: false);

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme,
        home: QrScanScreen(permissionService: fakePerms),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter Code Manually'));
    await tester.pumpAndSettle();

    expect(find.text('Enter QR Payload'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
