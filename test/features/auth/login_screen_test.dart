import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/auth/auth_service.dart';
import 'package:smartswitch_app/core/auth/biometric_auth_service.dart';
import 'package:smartswitch_app/core/theme.dart';
import 'package:smartswitch_app/data/secure_store/secure_key_store.dart';
import 'package:smartswitch_app/features/auth/presentation/login_screen.dart';
import 'package:smartswitch_app/features/auth/presentation/sign_up_screen.dart';
import 'package:smartswitch_app/state/auth_state.dart';

void main() {
  group('LoginScreen & SignUpScreen Tests (Blueprint §4 & §5)', () {
    late FakeSecureKeyStore secureStorage;
    late FakeAuthService authService;
    late FakeBiometricAuthService biometricService;

    setUp(() {
      secureStorage = FakeSecureKeyStore();
      authService = FakeAuthService(secureStorage: secureStorage);
      biometricService = FakeBiometricAuthService(secureStorage: secureStorage);
    });

    Widget buildLoginScreen({bool isBiometricLocked = false, VoidCallback? onLoginSuccess}) {
      return ProviderScope(
        overrides: [
          secureKeyStoreProvider.overrideWithValue(secureStorage),
          authServiceProvider.overrideWithValue(authService),
          biometricAuthServiceProvider.overrideWithValue(biometricService),
        ],
        child: MaterialApp(
          theme: lightTheme,
          home: LoginScreen(onLoginSuccess: onLoginSuccess),
        ),
      );
    }

    testWidgets('Renders login screen with branding, email, password, and sign-in button', (tester) async {
      await tester.pumpWidget(buildLoginScreen());

      expect(find.text('Welcome to SmartSwitch'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('Login with valid credentials triggers onLoginSuccess callback', (tester) async {
      bool loginSucceeded = false;

      await tester.pumpWidget(
        buildLoginScreen(
          onLoginSuccess: () => loginSucceeded = true,
        ),
      );

      // Default fields are seeded with user@example.com / password123
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(loginSucceeded, isTrue);
    });

    testWidgets('Login with invalid credentials displays error banner', (tester) async {
      await tester.pumpWidget(buildLoginScreen());

      // Enter wrong password
      await tester.enterText(find.byType(TextFormField).last, 'wrong_password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });

    testWidgets('Tapping Sign Up navigates to SignUpScreen', (tester) async {
      await tester.pumpWidget(buildLoginScreen());

      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(find.text('Join SmartSwitch'), findsOneWidget);
    });
  });
}
