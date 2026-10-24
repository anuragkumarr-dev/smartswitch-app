import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../data/secure_store/secure_key_store.dart';
import '../../../transport/blynk_transport.dart';

/// Modal bottom sheet in Settings enabling prototype Blynk bridge configuration.
/// Allows user to input Blynk Auth Token, pick cloud region (default blr1), test connection, and clear.
class BlynkSettingsSheet extends ConsumerStatefulWidget {
  final SecureKeyStore secureStorage;
  final BlynkCloudTransport transport;

  const BlynkSettingsSheet({
    super.key,
    required this.secureStorage,
    required this.transport,
  });

  @override
  ConsumerState<BlynkSettingsSheet> createState() => _BlynkSettingsSheetState();
}

class _BlynkSettingsSheetState extends ConsumerState<BlynkSettingsSheet> {
  final TextEditingController _tokenController = TextEditingController();
  String _selectedRegion = 'blr1';
  bool _isLoading = false;
  bool? _testConnectionSuccess;
  String? _testMessage;

  static const List<String> _regions = [
    'blr1',
    'sgp1',
    'lon1',
    'fra1',
    'ny3',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    final token = await widget.secureStorage.getBlynkToken();
    final region = await widget.secureStorage.getBlynkRegion();
    if (mounted) {
      setState(() {
        if (token != null) _tokenController.text = token;
        if (region != null && _regions.contains(region)) {
          _selectedRegion = region;
        }
      });
    }
  }

  Future<void> _testConnection() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      setState(() {
        _testConnectionSuccess = false;
        _testMessage = 'Please enter an Auth Token first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _testMessage = null;
      _testConnectionSuccess = null;
    });

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      final url = 'https://$_selectedRegion.blynk.cloud/external/api/isHardwareConnected';
      final res = await dio.get<dynamic>(url, queryParameters: {'token': token});

      final bool isConnected = res.statusCode == 200 &&
          (res.data.toString().toLowerCase() == 'true' ||
              res.data.toString() == '1');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _testConnectionSuccess = isConnected;
          _testMessage = isConnected
              ? 'Success: Blynk Master hardware is connected and online!'
              : 'Server reached, but Master hardware is currently offline.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _testConnectionSuccess = false;
          _testMessage = 'Connection failed: Check token and network connection.';
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auth token cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await widget.secureStorage.saveBlynkConfig(
      token: token,
      region: _selectedRegion,
    );
    widget.transport.updateCredentials(token: token, region: _selectedRegion);
    await widget.transport.connect(homeId: 'h_blynk', brokerUrl: '');

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blynk bridge connected (Region: $_selectedRegion)'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _clearConfig() async {
    setState(() => _isLoading = true);
    await widget.secureStorage.clearBlynkConfig();
    await widget.transport.disconnect();

    if (mounted) {
      setState(() {
        _tokenController.clear();
        _testConnectionSuccess = null;
        _testMessage = null;
        _isLoading = false;
      });
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blynk configuration cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.screenMargin,
        right: Spacing.screenMargin,
        top: Spacing.screenMargin,
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.screenMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prototype Connection (Blynk)',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Connects your existing ESP-NOW Master node via Blynk Cloud REST API (V0..V16). Virtual pin mapping is dynamically resolved at runtime from V16.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Region Dropdown
          Text('Blynk Cloud Region', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _selectedRegion,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _regions.map((r) {
              return DropdownMenuItem(
                value: r,
                child: Text('$r (${r == 'blr1' ? 'India / Bangalore - Default' : r.toUpperCase()})'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRegion = val);
            },
          ),
          const SizedBox(height: Spacing.md),

          // Auth Token Input
          Text('Blynk Auth Token', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          TextField(
            controller: _tokenController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Enter 32-character Blynk Device Token',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan Token QR',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paste your token or scan QR')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),

          // Test Result message banner
          if (_testMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: (_testConnectionSuccess == true
                        ? AppColors.success
                        : AppColors.error)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(
                  color: _testConnectionSuccess == true
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testConnectionSuccess == true
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: _testConnectionSuccess == true
                        ? AppColors.success
                        : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      _testMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _testConnectionSuccess == true
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
          ],

          // Buttons: Test Connection & Save
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check_rounded),
                  label: const Text('Test Connection'),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _saveConfig,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save & Connect'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),

          // Clear Button
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Clear Blynk Connection'),
              onPressed: _isLoading ? null : _clearConfig,
            ),
          ),
        ],
      ),
    );
  }
}
