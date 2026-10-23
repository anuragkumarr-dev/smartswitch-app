import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/errors/provisioning_error.dart';
import '../../../core/theme.dart';
import '../domain/qr_payload.dart';
import 'permission_service.dart';

/// Screen for scanning device QR codes using [MobileScanner].
/// Adheres to design tokens from `core/theme.dart`.
class QrScanScreen extends StatefulWidget {
  final PermissionService permissionService;
  final ValueChanged<QrPayload>? onQrScanned;

  const QrScanScreen({
    super.key,
    this.permissionService = const AppPermissionService(),
    this.onQrScanned,
  });

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _hasCameraPermission = false;
  bool _isCheckingPermission = true;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isCheckingPermission = true);
    final granted = await widget.permissionService.checkAndRequestCameraPermission();
    if (mounted) {
      setState(() {
        _hasCameraPermission = granted;
        _isCheckingPermission = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      try {
        final payload = QrPayload.parse(rawValue);
        _isScanned = true;
        _controller.stop();

        if (widget.onQrScanned != null) {
          widget.onQrScanned!(payload);
        }

        if (mounted) {
          Navigator.of(context).pop(payload);
        }
        return;
      } on ProvisioningException catch (e) {
        _showErrorSnackBar('${e.userMessage}: ${e.recoveryAction}');
      } catch (e) {
        _showErrorSnackBar('Invalid QR code format: $rawValue');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showManualInputDialog() {
    final textController = TextEditingController(
      text: 'SW1:smartswitch_v1:dev_test_01:secret_pop_123',
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          title: Text('Enter QR Payload', style: theme.textTheme.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Format: SW1:<productId>:<deviceId>:<PoP>',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                  hintText: 'SW1:prod:devId:pop',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final input = textController.text.trim();
                try {
                  final payload = QrPayload.parse(input);
                  Navigator.of(dialogCtx).pop();
                  if (widget.onQrScanned != null) {
                    widget.onQrScanned!(payload);
                  }
                  if (mounted) {
                    Navigator.of(context).pop(payload);
                  }
                } on ProvisioningException catch (e) {
                  _showErrorSnackBar('${e.userMessage}: ${e.recoveryAction}');
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isCheckingPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasCameraPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.screenMargin),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 64,
                  color: AppColors.offline,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Camera Permission Needed',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'SmartSwitch needs camera access to scan the device QR code printed on your switch.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                ElevatedButton(
                  onPressed: _checkPermission,
                  child: const Text('Grant Permission'),
                ),
                const SizedBox(height: Spacing.md),
                TextButton(
                  onPressed: _showManualInputDialog,
                  child: const Text('Enter Code Manually'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Device QR'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Toggle Flash',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Manual Entry',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // Framing Guide Overlay
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ViewfinderOverlayPainter(
              viewfinderSize: 260,
              accentColor: AppColors.accent,
            ),
          ),

          // Instruction label
          Positioned(
            bottom: Spacing.xxl + Spacing.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(Radii.card),
              ),
              child: Text(
                'Point camera at the QR code on your switch',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering a dark mask with a rounded square cutout for the QR viewfinder.
class _ViewfinderOverlayPainter extends CustomPainter {
  final double viewfinderSize;
  final Color accentColor;

  _ViewfinderOverlayPainter({
    required this.viewfinderSize,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: viewfinderSize,
      height: viewfinderSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(Radii.card));

    // Dark backdrop with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Frame border
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.viewfinderSize != viewfinderSize ||
        oldDelegate.accentColor != accentColor;
  }
}
