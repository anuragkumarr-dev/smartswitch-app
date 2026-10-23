import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'permission_service.dart';

/// Pre-permission explanation screen conforming to Blueprint §2.2 & §4.5.
class PermissionPrePromptScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionPrePromptScreen({
    super.key,
    required this.onPermissionsGranted,
  });

  @override
  State<PermissionPrePromptScreen> createState() => _PermissionPrePromptScreenState();
}

class _PermissionPrePromptScreenState extends State<PermissionPrePromptScreen> {
  final PermissionService _permissionService = const AppPermissionService();
  bool _isChecking = false;

  Future<void> _handleContinue() async {
    setState(() => _isChecking = true);
    final granted = await _permissionService.checkAndRequestAllOnboardingPermissions();
    if (mounted) setState(() => _isChecking = false);

    if (granted) {
      widget.onPermissionsGranted();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Some permissions were not granted. You can still test with manual input.'),
          ),
        );
        widget.onPermissionsGranted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Switch')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before we begin',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                'To detect and securely configure your switch, SmartSwitch needs temporary access to these device features.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.lg),

              _buildPermissionCard(
                icon: Icons.camera_alt_outlined,
                title: 'Camera Access',
                description: 'Used to scan the QR code printed on your switch box or sticker.',
                isDark: isDark,
              ),
              const SizedBox(height: Spacing.md),

              _buildPermissionCard(
                icon: Icons.bluetooth_rounded,
                title: 'Bluetooth & Nearby Devices',
                description: 'Connects directly to your switch over BLE to push Wi-Fi and mesh keys securely.',
                isDark: isDark,
              ),
              const SizedBox(height: Spacing.md),

              _buildPermissionCard(
                icon: Icons.wifi_tethering_rounded,
                title: 'Local Network Access',
                description: 'Enables sub-millisecond local LAN control without going through the cloud.',
                isDark: isDark,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                  ),
                  onPressed: _isChecking ? null : _handleContinue,
                  child: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
