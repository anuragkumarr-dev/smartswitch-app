import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/security/role_permissions.dart';
import '../../../core/theme.dart';
import '../../../data/invite/invite_service.dart';
import '../../../state/app_mode_state.dart';
import '../../../state/auth_state.dart';
import '../../../state/homes_state.dart';
import '../../../transport/blynk_bridge_controller.dart';
import 'create_invite_sheet.dart';

final inviteServiceProvider = Provider<InviteService>((ref) => FakeInviteService());

/// Settings screen conforming to Phase 5A security and role-based permissions (Blueprint §5),
/// including the Blynk Prototype connection bridge and live diagnostics panel.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;

  // Blynk prototype connection controllers
  final TextEditingController _tokenController = TextEditingController();
  String _selectedRegion = 'blr1';
  bool _obscureToken = true;
  bool _isTestingConnection = false;
  bool? _testConnectionSuccess;
  String? _testMessage;
  bool _isDiagnosticsExpanded = true;

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
    _loadBiometricSetting();
    _loadBlynkConfig();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSetting() async {
    final bioService = ref.read(biometricAuthServiceProvider);
    final enabled = await bioService.isAppLockEnabled();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _loadBlynkConfig() async {
    final storage = ref.read(secureKeyStoreProvider);
    final token = await storage.getBlynkToken();
    final region = await storage.getBlynkRegion();

    if (mounted) {
      setState(() {
        if (token != null) _tokenController.text = token;
        if (region != null && _regions.contains(region)) {
          _selectedRegion = region;
        }
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _tokenController.text = text;
      });
      AppHaptics.light();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pasted token from clipboard')),
        );
      }
    }
  }

  Future<void> _scanTokenQr() async {
    AppHaptics.light();
    final scanned = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Scan Blynk Token QR')),
        body: MobileScanner(
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final val = barcode.rawValue;
              if (val != null && val.trim().isNotEmpty) {
                Navigator.of(ctx).pop(val.trim());
                break;
              }
            }
          },
        ),
      ),
    );

    if (scanned != null && mounted) {
      setState(() {
        _tokenController.text = scanned;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token scanned successfully')),
      );
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
      _isTestingConnection = true;
      _testMessage = null;
      _testConnectionSuccess = null;
    });

    final transport = ref.read(blynkTransportProvider);
    final isOnline = await transport.checkHardwareConnected(
      token: token,
      region: _selectedRegion,
    );

    if (mounted) {
      setState(() {
        _isTestingConnection = false;
        _testConnectionSuccess = isOnline;
        _testMessage = isOnline
            ? 'Success: Blynk Master hardware is connected and online!'
            : 'Master hardware is offline or token is invalid.';
      });
    }
  }

  Future<void> _saveBlynkConfig() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auth token cannot be empty')),
      );
      return;
    }

    final controller = ref.read(blynkBridgeControllerProvider);
    await controller.configure(token: token, region: _selectedRegion);

    // Switch mode to Blynk immediately
    await ref.read(appModeProvider.notifier).setMode(AppMode.blynk);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to Blynk (Region: $_selectedRegion)'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _clearBlynkConfig() async {
    final controller = ref.read(blynkBridgeControllerProvider);
    await controller.clearConfig();

    // Reset mode back to demo
    await ref.read(appModeProvider.notifier).setMode(AppMode.demo);

    if (mounted) {
      setState(() {
        _tokenController.clear();
        _testConnectionSuccess = null;
        _testMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blynk configuration cleared. Switched to Demo mode.')),
      );
    }
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
    final appMode = ref.watch(appModeProvider);
    final blynkStatus = ref.watch(blynkStatusProvider);
    final blynkTransport = ref.watch(blynkTransportProvider);

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

            // SECTION: PROTOTYPE CONNECTION (BLYNK)
            Text(
              'PROTOTYPE CONNECTION (BLYNK)',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: Spacing.xs),

            // App Mode Selector Card
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active App Mode',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            appMode.isBlynk ? 'Real ESP-NOW Switches' : 'Simulated Test Switches',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      SegmentedButton<AppMode>(
                        segments: const [
                          ButtonSegment(
                            value: AppMode.demo,
                            label: Text('Demo'),
                            icon: Icon(Icons.science_outlined),
                          ),
                          ButtonSegment(
                            value: AppMode.blynk,
                            label: Text('Blynk'),
                            icon: Icon(Icons.cloud_queue_rounded),
                          ),
                        ],
                        selected: {appMode},
                        onSelectionChanged: (newSelection) async {
                          AppHaptics.light();
                          final selected = newSelection.first;
                          await ref.read(appModeProvider.notifier).setMode(selected);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    'Default is Demo until a Blynk token is saved. Blynk mode connects to your Master ESP32 and resolves pins dynamically from V16.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // Blynk Token & Region Configuration Card
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Blynk Cloud Configuration',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: Spacing.sm),

                  // Auth Token Field
                  TextFormField(
                    controller: _tokenController,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: 'Auth Token',
                      hintText: 'Enter 32-char Blynk Auth Token',
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            tooltip: _obscureToken ? 'Show token' : 'Hide token',
                            onPressed: () => setState(() => _obscureToken = !_obscureToken),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_paste_rounded),
                            tooltip: 'Paste from clipboard',
                            onPressed: _pasteFromClipboard,
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            tooltip: 'Scan QR code',
                            onPressed: _scanTokenQr,
                          ),
                        ],
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),

                  // Region Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRegion,
                    decoration: const InputDecoration(
                      labelText: 'Cloud Region',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _regions.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text('$r (${r == 'blr1' ? 'Bangalore / India' : r.toUpperCase()})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRegion = val);
                    },
                  ),
                  const SizedBox(height: Spacing.md),

                  // Test Message / Feedback Banner
                  if (_testMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: (_testConnectionSuccess == true ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(Radii.button),
                        border: Border.all(
                          color: _testConnectionSuccess == true ? AppColors.success : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testConnectionSuccess == true
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 16,
                            color: _testConnectionSuccess == true ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _testConnectionSuccess == true ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                  ],

                  // Action Buttons: Test, Save & Clear
                  Row(
                    children: [
                      // Test Connection Button
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _isTestingConnection
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded, size: 18),
                          label: const Text('Test Connection'),
                          onPressed: _isTestingConnection ? null : _testConnection,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),

                      // Save Button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Save & Connect'),
                          onPressed: _saveBlynkConfig,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),

                  // Clear Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Clear Token', style: TextStyle(fontSize: 12)),
                      onPressed: _clearBlynkConfig,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // SECTION: DEBUG DIAGNOSTICS PANEL
            Material(
              color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.card),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: ExpansionTile(
                initiallyExpanded: _isDiagnosticsExpanded,
                onExpansionChanged: (val) => setState(() => _isDiagnosticsExpanded = val),
                leading: const Icon(Icons.analytics_outlined, color: AppColors.accent),
                title: const Text(
                  'Blynk Diagnostics (Debug Panel)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  blynkStatus.isConnected
                      ? 'Connected • ${blynkStatus.nodeCount} node(s) parsed'
                      : 'Offline / Poller inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: blynkStatus.isConnected ? AppColors.success : AppColors.error,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poller Time & Manual Poll Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Last Poll Time:', style: theme.textTheme.labelSmall),
                                Text(
                                  blynkStatus.lastPollTime != null
                                      ? '${blynkStatus.lastPollTime!.toIso8601String().substring(11, 19)} (every 1.5s)'
                                      : 'Never / Not polled yet',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Poll Now', style: TextStyle(fontSize: 12)),
                              onPressed: () async {
                                AppHaptics.light();
                                await blynkTransport.pollNow();
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Raw V16 String
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Raw V16 String (Node Map):', style: theme.textTheme.labelSmall),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy V16 string',
                              onPressed: () {
                                final text = blynkStatus.lastRawV16 ?? '';
                                if (text.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied V16 string to clipboard')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black45 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            (blynkStatus.lastRawV16 != null && blynkStatus.lastRawV16!.isNotEmpty)
                                ? blynkStatus.lastRawV16!
                                : '<No V16 payload received yet>',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Divider(height: 20),

                        // Parsed Nodes
                        Text(
                          'Parsed Nodes (${blynkTransport.currentNodeMap.nodesByMac.length}):',
                          style: theme.textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        if (blynkTransport.currentNodeMap.nodesByMac.isEmpty)
                          const Text(
                            'No switches mapped from V16 yet.',
                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          )
                        else
                          ...blynkTransport.currentNodeMap.nodesByMac.values.map((node) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (node.isLive ? AppColors.success : AppColors.error)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(Radii.sm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        node.isMaster ? Icons.hub_rounded : Icons.toggle_on_outlined,
                                        size: 16,
                                        color: node.isMaster ? AppColors.accent : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        node.mac,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (node.isMaster) ...[
                                        const SizedBox(width: 4),
                                        const Text(
                                          '(Master)',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Pin: V${node.pin} • ${node.state ? "ON" : "OFF"} • ${node.rssi} dBm',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }),
                        const Divider(height: 20),

                        // Last Command and Result
                        Text('Last Command & Result:', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.black45 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Command: ${blynkStatus.lastCommandInfo ?? "None"}',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Result: ${blynkStatus.lastCommandResult ?? "N/A"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: (blynkStatus.lastCommandResult?.contains('Confirmed') == true)
                                      ? AppColors.success
                                      : (blynkStatus.lastCommandResult?.contains('Rolled') == true
                                          ? AppColors.error
                                          : null),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Last Error Display
                        if (blynkStatus.lastError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Last Error: ${blynkStatus.lastError}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: Spacing.xs),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

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
