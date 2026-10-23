import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/provisioning_error.dart';
import '../../../core/theme.dart';
import '../../../transport/ble_provisioner.dart';
import '../../../transport/fake_ble_provisioner.dart';
import '../domain/qr_payload.dart';
import 'permission_service.dart';
import 'provisioning_controller.dart';

/// Preset simulation scenario for testing against [FakeBleProvisioner].
enum DebugSimulationScenario {
  happyPath('Happy Path (Success)'),
  deviceIdMismatch('Failure: Device ID Mismatch'),
  deviceNotFound('Failure: Device Not Found (Timeout)'),
  wrongPop('Failure: Wrong PoP (Handshake Failed)'),
  alreadyBound('Failure: Device Already Bound'),
  wifiAuthFailed('Failure: Wi-Fi Password Rejected'),
  routerNotFound('Failure: Router Not Found / 5 GHz'),
  meshTimeout('Failure: Mesh Join Timeout'),
  tokenRejected('Failure: Token Expired / Rejected');

  final String label;
  const DebugSimulationScenario(this.label);
}

/// A comprehensive debug and verification screen that executes the complete
/// onboarding flow against [FakeBleProvisioner].
class DebugProvisioningScreen extends ConsumerStatefulWidget {
  const DebugProvisioningScreen({super.key});

  @override
  ConsumerState<DebugProvisioningScreen> createState() =>
      _DebugProvisioningScreenState();
}

class _DebugProvisioningScreenState extends ConsumerState<DebugProvisioningScreen> {
  final TextEditingController _qrController = TextEditingController(
    text: 'SW1:smartswitch_v1:switch_ab12:secret_pop_42',
  );
  final TextEditingController _ssidController = TextEditingController(
    text: 'HomeWiFi-2.4G',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'supersecretpass',
  );

  DebugSimulationScenario _scenario = DebugSimulationScenario.happyPath;

  @override
  void dispose() {
    _qrController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Configures the [FakeBleProvisioner] for the selected [DebugSimulationScenario].
  FakeBleProvisioner _buildConfiguredFake(QrPayload qr) {
    switch (_scenario) {
      case DebugSimulationScenario.happyPath:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
        );

      case DebugSimulationScenario.deviceIdMismatch:
        return FakeBleProvisioner(
          availableDevices: [
            const BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:99',
              name: 'PROV_switch_other_neighbour',
              deviceId: 'switch_other_neighbour',
              rssi: -45,
            ),
          ],
          expectedPoP: qr.pop,
        );

      case DebugSimulationScenario.deviceNotFound:
        return FakeBleProvisioner(
          availableDevices: [], // Empty scan result
        );

      case DebugSimulationScenario.wrongPop:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: 'different_pop_secret', // Handshake mismatch
        );

      case DebugSimulationScenario.alreadyBound:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
          customDeviceInfo: ProvisioningDeviceInfo(
            productId: qr.productId,
            deviceId: qr.deviceId,
            firmwareVersion: '1.0.0',
            isProvisioned: true, // Already provisioned
          ),
        );

      case DebugSimulationScenario.wifiAuthFailed:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
          customStatuses: [
            DeviceProvisioningStatus.wifiConnecting(),
            DeviceProvisioningStatus.wifiAuthFailed(),
          ],
        );

      case DebugSimulationScenario.routerNotFound:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
          customStatuses: [
            DeviceProvisioningStatus.wifiConnecting(),
            DeviceProvisioningStatus.routerNotFound(),
          ],
        );

      case DebugSimulationScenario.meshTimeout:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
          customStatuses: [
            DeviceProvisioningStatus.wifiConnecting(),
            DeviceProvisioningStatus.wifiOk(),
            DeviceProvisioningStatus.meshTimeout(),
          ],
        );

      case DebugSimulationScenario.tokenRejected:
        return FakeBleProvisioner(
          availableDevices: [
            BleDiscoveredDevice(
              id: 'AA:BB:CC:DD:EE:01',
              name: 'PROV_${qr.deviceId}',
              deviceId: qr.deviceId,
              rssi: -54,
            ),
          ],
          expectedPoP: qr.pop,
          customStatuses: [
            DeviceProvisioningStatus.wifiConnecting(),
            DeviceProvisioningStatus.wifiOk(),
            DeviceProvisioningStatus.tokenRejected(),
          ],
        );
    }
  }

  Future<void> _startProvisioning() async {
    final controller = ref.read(provisioningControllerProvider.notifier);

    // 1. Parse QR
    QrPayload payload;
    try {
      payload = controller.parseQr(_qrController.text.trim());
    } on ProvisioningException {
      return;
    }

    // 2. Configure fake provisioner into Riverpod container
    final fakeProvisioner = _buildConfiguredFake(payload);

    // Run using configured params
    final params = ProvisioningParams(
      wifiSsid: _ssidController.text.trim(),
      wifiPassword: _passwordController.text.trim(),
      deviceName: 'Living Room Switch',
      roomId: 'r_living_01',
    );

    try {
      await controller.runProvisioning(
        qrPayload: payload,
        params: params,
        scanTimeout: const Duration(milliseconds: 1000),
        provisionerOverride: fakeProvisioner,
        permissionServiceOverride: FakePermissionService(
          cameraGranted: true,
          bluetoothGranted: true,
        ),
      );
    } catch (_) {
      // Handled in state
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(provisioningControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provisioning Debug Tool'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset State',
            onPressed: () {
              ref.read(provisioningControllerProvider.notifier).reset();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.screenMargin),
        children: [
          // Scenario selector card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Simulation Scenario', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Select a scenario to verify happy path and error taxonomy handling.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  DropdownButtonFormField<DebugSimulationScenario>(
                    initialValue: _scenario,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                    ),
                    items: DebugSimulationScenario.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      );
                    }).toList(),
                    onChanged: state.isBusy
                        ? null
                        : (val) {
                            if (val != null) setState(() => _scenario = val);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Inputs Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuration Inputs', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Spacing.sm),
                  TextField(
                    controller: _qrController,
                    enabled: !state.isBusy,
                    decoration: InputDecoration(
                      labelText: 'QR Payload (SW1:<productId>:<deviceId>:<PoP>)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  TextField(
                    controller: _ssidController,
                    enabled: !state.isBusy,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi SSID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  TextField(
                    controller: _passwordController,
                    enabled: !state.isBusy,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Wi-Fi Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
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
                      onPressed: state.isBusy ? null : _startProvisioning,
                      child: state.isBusy
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Run Provisioning Flow',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Stage & Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Stage', style: theme.textTheme.titleLarge),
                      _buildStageChip(state.stage),
                    ],
                  ),
                  if (state.currentStatus != null) ...[
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Device Stream Status: ${state.currentStatus!.rawStatus}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: state.currentStatus!.state ==
                                DeviceProvisioningState.error
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    if (state.currentStatus!.message != null)
                      Text(
                        state.currentStatus!.message!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Failure / Error Banner from Blueprint §2.4 table
          if (state.isFailure && state.error != null)
            Card(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.error),
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            state.error!.userMessage,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Recovery Action: ${state.error!.recoveryAction}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Technical Details: ${state.error!.message}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (state.isSuccess)
            Card(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.success),
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provisioning Successful!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Switch connected to Wi-Fi, mesh joined, and cloud registered.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Spacing.sm),

          // Logs Console Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provisioning Logs', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Spacing.sm),
                  Container(
                    height: 180,
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(Radii.button),
                      border: Border.all(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: state.logs.isEmpty
                        ? Text(
                            'No logs yet. Click "Run Provisioning Flow" above.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          )
                        : ListView.builder(
                            itemCount: state.logs.length,
                            itemBuilder: (context, idx) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '• ${state.logs[idx]}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageChip(ProvisioningStage stage) {
    Color bg;
    Color fg;

    switch (stage) {
      case ProvisioningStage.idle:
        bg = AppColors.offline.withValues(alpha: 0.2);
        fg = AppColors.offline;
        break;
      case ProvisioningStage.success:
        bg = AppColors.success.withValues(alpha: 0.2);
        fg = AppColors.success;
        break;
      case ProvisioningStage.failure:
        bg = AppColors.error.withValues(alpha: 0.2);
        fg = AppColors.error;
        break;
      default:
        bg = AppColors.accent.withValues(alpha: 0.2);
        fg = AppColors.accent;
    }

    return Chip(
      label: Text(
        stage.name.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.toggle),
      ),
    );
  }
}
