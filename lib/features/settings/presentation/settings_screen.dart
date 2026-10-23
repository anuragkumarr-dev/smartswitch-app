import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../state/auth_state.dart';

/// Settings screen stub conforming to Phase 4 roadmap.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          children: [
            // Account / User Header Card
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
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                    child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: Spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.userId ?? 'SmartSwitch User',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Member of Home: ${authState.currentHomeId ?? "Main Home"}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.lg),

            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Manage Homes & Members'),
              subtitle: const Text('Roles, member invites, and home keys'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded),
              title: const Text('Notifications'),
              subtitle: const Text('Offline alerts and schedule events'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.system_update_rounded),
              title: const Text('OTA Firmware Updates'),
              subtitle: const Text('Check for ESP32 mesh updates'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('Security & Biometrics'),
              subtitle: const Text('App lock and session encryption'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About SmartSwitch'),
              subtitle: const Text('Version 1.0.0 (Phase 4 Build)'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}
