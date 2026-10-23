import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../transport/ble_provisioner.dart';
import 'provisioning_controller.dart';

/// Live status progress screen matching BLE unified provisioning stream (Blueprint §2.2 & §4.5).
class ProvisioningProgressScreen extends ConsumerWidget {
  final VoidCallback onSuccess;
  final VoidCallback onRetry;

  const ProvisioningProgressScreen({
    super.key,
    required this.onSuccess,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(provisioningControllerProvider);

    if (state.isSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onSuccess());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuring Switch')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: Spacing.xl),

              // Animated Status Icon
              if (state.isFailure)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.error.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
                )
              else
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        value: state.isSuccess ? 1.0 : null,
                      ),
                      Icon(
                        state.isSuccess ? Icons.check_circle_rounded : Icons.bluetooth_searching_rounded,
                        color: state.isSuccess ? AppColors.success : AppColors.accent,
                        size: 36,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: Spacing.lg),

              Text(
                state.isFailure ? 'Configuration Failed' : 'Connecting to your switch...',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                state.isFailure
                    ? (state.error?.message ?? 'Please check your Wi-Fi credentials and retry.')
                    : 'Keep your phone within 5 meters of the switch.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                ),
              ),

              const SizedBox(height: Spacing.xl),

              // Progress Stepper List
              Expanded(
                child: ListView(
                  children: [
                    _buildStepRow(
                      context: context,
                      title: 'BLE Connection & SRP6a Security',
                      isCompleted: state.stage.index > ProvisioningStage.establishingSession.index,
                      isActive: state.stage == ProvisioningStage.connectingBle ||
                          state.stage == ProvisioningStage.establishingSession,
                    ),
                    _buildStepRow(
                      context: context,
                      title: 'Sending Wi-Fi & Mesh Credentials',
                      isCompleted: state.stage.index > ProvisioningStage.sendingCustomConfig.index,
                      isActive: state.stage == ProvisioningStage.sendingWifiCredentials ||
                          state.stage == ProvisioningStage.sendingCustomConfig,
                    ),
                    _buildStepRow(
                      context: context,
                      title: 'Router Authentication (WIFI_OK)',
                      isCompleted:
                          state.currentStatus?.state == DeviceProvisioningState.wifiOk ||
                              state.isSuccess,
                      isActive: state.stage == ProvisioningStage.waitingForDeviceStatus,
                    ),
                    _buildStepRow(
                      context: context,
                      title: 'Mesh Network Joined',
                      isCompleted:
                          state.currentStatus?.state == DeviceProvisioningState.meshJoined ||
                              state.isSuccess,
                      isActive: false,
                    ),
                    _buildStepRow(
                      context: context,
                      title: 'Cloud Activation Token Bound',
                      isCompleted: state.isSuccess,
                      isActive: false,
                    ),
                  ],
                ),
              ),

              if (state.isFailure)
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
                    onPressed: onRetry,
                    child: const Text('Retry Setup'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required BuildContext context,
    required String title,
    required bool isCompleted,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color iconColor;
    final Widget indicator;

    if (isCompleted) {
      iconColor = AppColors.success;
      indicator = const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20);
    } else if (isActive) {
      iconColor = AppColors.accent;
      indicator = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
      );
    } else {
      iconColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      indicator = Icon(Icons.radio_button_unchecked_rounded, color: iconColor, size: 20);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        children: [
          indicator,
          const SizedBox(width: Spacing.md),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isCompleted || isActive
                  ? (isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface)
                  : theme.disabledColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
