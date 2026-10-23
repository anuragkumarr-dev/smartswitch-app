import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/device_control/presentation/device_control_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/mesh_diag/presentation/mesh_diag_screen.dart';
import '../../features/onboarding/presentation/onboarding_flow_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../theme.dart';

/// Factory function that creates a fresh [GoRouter] instance.
/// Useful for testing each route tree independently without state leakage.
GoRouter createAppRouter({
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final navKey = navigatorKey ?? GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: navKey,
    initialLocation: initialLocation,
    routes: [
      // Bottom Navigation Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) {
                AppHaptics.light();
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.device_hub_rounded),
                  activeIcon: Icon(Icons.device_hub_rounded),
                  label: 'Mesh',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
        branches: [
          // Tab 1: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Tab 2: Mesh Diagnostics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mesh',
                builder: (context, state) => const MeshDiagScreen(),
              ),
            ],
          ),

          // Tab 3: Settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen Route: Device Control
      GoRoute(
        path: '/device/:id',
        parentNavigatorKey: navKey,
        builder: (context, state) {
          final deviceId = state.pathParameters['id'] ?? 'dev_unknown';
          return DeviceControlScreen(deviceId: deviceId);
        },
      ),

      // Full-screen Route: Onboarding Flow
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: navKey,
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
    ],
  );
}

/// Declarative AppRouter using go_router with persistent Shell navigation (Blueprint §4).
final GoRouter appRouter = createAppRouter();

