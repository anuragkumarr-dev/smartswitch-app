import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/models.dart';
import '../../../state/devices_state.dart';
import '../domain/qr_payload.dart';
import 'onboarding_success_screen.dart';
import 'permission_pre_prompt_screen.dart';
import 'provisioning_controller.dart';
import 'provisioning_progress_screen.dart';
import 'qr_scan_screen.dart';
import 'wifi_credentials_screen.dart';

enum OnboardingStep {
  permissions,
  qrScan,
  wifiCredentials,
  progress,
  success,
}

/// Orchestrator screen for the complete onboarding flow (Blueprint §2.2 & §4.5).
class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  OnboardingStep _currentStep = OnboardingStep.permissions;
  QrPayload? _scannedQr;
  String _wifiSsid = '';
  String _wifiPassword = '';

  @override
  Widget build(BuildContext context) {
    switch (_currentStep) {
      case OnboardingStep.permissions:
        return PermissionPrePromptScreen(
          onPermissionsGranted: () {
            setState(() => _currentStep = OnboardingStep.qrScan);
          },
        );

      case OnboardingStep.qrScan:
        return QrScanScreen(
          onQrScanned: (payload) {
            setState(() {
              _scannedQr = payload;
              _currentStep = OnboardingStep.wifiCredentials;
            });
          },
        );

      case OnboardingStep.wifiCredentials:
        return WifiCredentialsScreen(
          onConnect: (ssid, password) {
            _wifiSsid = ssid;
            _wifiPassword = password;
            setState(() => _currentStep = OnboardingStep.progress);
            _startProvisioning();
          },
        );

      case OnboardingStep.progress:
        return ProvisioningProgressScreen(
          onSuccess: () {
            setState(() => _currentStep = OnboardingStep.success);
          },
          onRetry: () {
            setState(() => _currentStep = OnboardingStep.wifiCredentials);
          },
        );

      case OnboardingStep.success:
        return OnboardingSuccessScreen(
          deviceId: _scannedQr?.deviceId ?? 'dev_${DateTime.now().millisecondsSinceEpoch}',
          onComplete: (name, roomId) {
            final devId = _scannedQr?.deviceId ?? 'dev_${DateTime.now().millisecondsSinceEpoch}';
            final newDevice = Device(
              deviceId: devId,
              homeId: 'h1',
              roomId: roomId,
              name: name,
              product: _scannedQr?.productId ?? 'SW1-1G',
              gangsCount: 1,
              gatewayId: 'gw_root1',
              gangs: [Gang(gangId: 'gang1', name: name, isOn: false)],
              shadow: const Shadow(
                ver: 1,
                online: true,
                reported: {'gang1': {'on': false}},
              ),
            );

            // Add newly provisioned switch into devices state
            final currentDevices = ref.read(devicesStateProvider).values.map((u) => u.device).toList();
            ref.read(devicesStateProvider.notifier).setDevices([...currentDevices, newDevice]);

            context.go('/');
          },
        );
    }
  }

  void _startProvisioning() {
    final qr = _scannedQr ??
        const QrPayload(
          productId: 'SW1-1G',
          deviceId: 'sw_test_01',
          pop: 'pop_test_123',
        );

    final params = ProvisioningParams(
      wifiSsid: _wifiSsid,
      wifiPassword: _wifiPassword,
      deviceName: 'Smart Switch',
    );

    ref.read(provisioningControllerProvider.notifier).runProvisioning(
          qrPayload: qr,
          params: params,
        );
  }
}
