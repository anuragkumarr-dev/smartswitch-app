import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/role_permissions.dart';
import '../../../core/theme.dart';
import '../../../data/invite/invite_service.dart';
import '../../../state/auth_state.dart';
import '../../../state/homes_state.dart';
import 'create_invite_sheet.dart';

final inviteServiceProvider = Provider<InviteService>((ref) => FakeInviteService());

/// Settings screen conforming to Phase 5A security and role-based permissions (Blueprint §5).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final bioService = ref.read(biometricAuthServiceProvider);
    final enabled = await bioService.isAppLockEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  void _openCreateInviteSheet(BuildContext context, AuthState authState) {
    final homesState = ref.read(homesStateProvider);
    final home = homesState.activeHome;
    final homeId = home?.homeId ?? authState.currentHomeId ?? 'h_main';
    final homeName = home?.name ?? 'My Home';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      builder: (_) => CreateInviteSheet(
        homeId: homeId,
        homeName: homeName,
        creatorRole: authState.currentRole,
        inviteService: ref.read(inviteServiceProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final bioService = ref.watch(biometricAuthServiceProvider);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              authState.userId ?? 'SmartSwitch User',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            // Role Badge (Blueprint §5)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(Radii.button),
                                border: Border.all(color: AppColors.accent),
                              ),
                              child: Text(
                                authState.currentRole.displayName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Member of Home: ${authState.currentHomeId ?? "Main Home"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.lg),

            // Role-guarded action: Invite Member (Blueprint §5)
            if (authState.can(RoleAction.inviteMember)) ...[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent),
                title: const Text('Invite to Home'),
                subtitle: const Text('Generate single-use QR or link invite'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openCreateInviteSheet(context, authState),
              ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Manage Homes & Members'),
              subtitle: const Text('Roles, member invites, and home keys'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
            const Divider(),

            // Biometric App Lock Toggle (Blueprint §5)
            SwitchListTile.adaptive(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric App Lock'),
              subtitle: const Text('Require biometrics to access application'),
              value: _biometricEnabled,
              activeThumbColor: AppColors.accent,
              onChanged: (val) async {
                final available = await bioService.isBiometricsAvailable();
                if (!available) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Biometrics not available on this device.')),
                    );
                  }
                  return;
                }
                final authed = await bioService.authenticate(reason: 'Confirm biometrics to enable app lock');
                if (authed) {
                  await bioService.setAppLockEnabled(val);
                  setState(() => _biometricEnabled = val);
                }
              },
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

            // Role-guarded action: Factory Reset Home (Owner only)
            if (authState.can(RoleAction.factoryReset)) ...[
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                title: const Text('Factory Reset Home', style: TextStyle(color: AppColors.error)),
                subtitle: const Text('Disband mesh and unbind all switches (Owner only)'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset confirmation required.')),
                  );
                },
              ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About SmartSwitch'),
              subtitle: const Text('Version 1.0.0 (Phase 5A Build)'),
              onTap: () {},
            ),
            const SizedBox(height: Spacing.xl),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                onPressed: () async {
                  AppHaptics.medium();
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out successfully.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
