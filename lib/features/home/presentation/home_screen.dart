import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/security/role_permissions.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../domain/models/models.dart';
import '../../../state/active_transport_provider.dart';
import '../../../state/app_mode_state.dart';
import '../../../state/auth_state.dart';
import '../../../state/devices_state.dart';
import '../../../state/homes_state.dart';
import '../../../transport/blynk_bridge_controller.dart';
import '../../../transport/command_router.dart';
import '../widgets/device_card.dart';

/// Production Home screen conforming to Blueprint §4.2.
class HomeScreen extends ConsumerStatefulWidget {
  final CommandRouter? commandRouter;
  final VoidCallback? onAddDevice;

  const HomeScreen({
    super.key,
    this.commandRouter,
    this.onAddDevice,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedRoomId = 'all';
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final homesState = ref.watch(homesStateProvider);
    final devicesMap = ref.watch(devicesStateProvider);

    // Active home info
    final activeHome = homesState.activeHome;
    final homeName = activeHome?.name ?? 'My Home';

    // Mock rooms if none in state
    final rooms = [
      const Room(roomId: 'all', homeId: 'h1', name: 'All', order: 0),
      const Room(roomId: 'r_living', homeId: 'h1', name: 'Living Room', order: 1),
      const Room(roomId: 'r_bed', homeId: 'h1', name: 'Bedroom', order: 2),
      const Room(roomId: 'r_kitchen', homeId: 'h1', name: 'Kitchen', order: 3),
      const Room(roomId: 'r_balcony', homeId: 'h1', name: 'Balcony', order: 4),
    ];

    // Filter devices by selected room
    final allDevices = devicesMap.values.toList();
    final filteredDevices = _selectedRoomId == 'all'
        ? allDevices
        : allDevices.where((d) => d.device.roomId == _selectedRoomId).toList();

    // Check if any device in this filtered group is ON
    final hasAnyOn = filteredDevices.any((d) => d.effectiveGangIsOn('gang1'));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Top Bar: Home selector, Bell, Add button (Blueprint §4.2)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.screenMargin,
                    vertical: Spacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Home Selector Dropdown
                      _buildHomeSelector(context, homeName, homesState.homes),

                      // Actions: Notification bell + Add button
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded),
                            tooltip: 'Notifications',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No new notifications')),
                              );
                            },
                          ),
                          if (authState.can(RoleAction.addDevice))
                            Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add, color: Colors.white),
                                tooltip: 'Add Switch',
                                onPressed: () {
                                  if (widget.onAddDevice != null) {
                                    widget.onAddDevice!();
                                  } else {
                                    context.push('/onboarding');
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Room Chips & Turn-All-Off action (Blueprint §4.2)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Mode banner: Blynk real switch status or error banner
                    _buildModeBanner(context, ref),

                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
                        scrollDirection: Axis.horizontal,
                        itemCount: rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(width: Spacing.sm),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          final isSelected = room.roomId == _selectedRoomId;

                          return ChoiceChip(
                            label: Text(room.name),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedRoomId = room.roomId);
                            },
                            selectedColor: AppColors.accent,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.lightOnSurface),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                            backgroundColor: isDark
                                ? AppColors.darkSurfaceCard
                                : AppColors.lightSurfaceCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(Radii.toggle),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick action bar: Active count + "Turn All Off" per room
                    if (filteredDevices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.screenMargin,
                          vertical: Spacing.xs,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${filteredDevices.length} ${filteredDevices.length == 1 ? "Switch" : "Switches"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.lightOnSurfaceVariant,
                              ),
                            ),
                            if (hasAnyOn)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.power_settings_new_rounded,
                                    size: 16, color: AppColors.accent),
                                label: const Text(
                                  'Turn all off',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () => _turnAllOff(filteredDevices),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.sm)),

              // 3. Device Grid / Skeletons / Empty State (Blueprint §4.2)
              if (_isRefreshing) ...[
                _buildSkeletonGrid(context),
              ] else if (filteredDevices.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                ),
              ] else ...[
                _buildDeviceGrid(context, filteredDevices),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeSelector(BuildContext context, String currentHome, List<Home> homes) {
    return PopupMenuButton<String>(
      onSelected: (homeId) {
        ref.read(homesStateProvider.notifier).setActiveHome(homeId);
      },
      itemBuilder: (context) {
        if (homes.isEmpty) {
          return [
            PopupMenuItem(
              value: 'default',
              child: Text(currentHome),
            ),
          ];
        }
        return homes
            .map((h) => PopupMenuItem(
                  value: h.homeId,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(h.name),
                      if (h.name == currentHome)
                        const Icon(Icons.check, size: 18, color: AppColors.accent),
                    ],
                  ),
                ))
            .toList();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentHome,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: Spacing.xs),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
        ],
      ),
    );
  }

  Widget _buildDeviceGrid(BuildContext context, List<DeviceUiState> devices) {
    // 2 columns on phones, 3+ on tablets (Blueprint §4.2)
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: Spacing.md,
          crossAxisSpacing: Spacing.md,
          childAspectRatio: 1.15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final uiState = devices[index];
            return DeviceCard(
              uiState: uiState,
              onToggle: () => _handleToggle(uiState),
              onTap: () => _openDeviceControl(uiState),
              onLongPress: () => _showQuickActionsSheet(uiState),
              onOfflineHelp: () => _showOfflineHelpSheet(uiState),
            );
          },
          childCount: devices.length,
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: Spacing.md,
          crossAxisSpacing: Spacing.md,
          childAspectRatio: 1.15,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const SkeletonCard(),
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'No Switches Added',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Scan a QR code or tap the button below to add your first smart switch.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.lightOnSurfaceVariant,
                  ),
            ),
            if (authState.can(RoleAction.addDevice)) ...[
              const SizedBox(height: Spacing.lg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Add your first switch'),
                onPressed: () {
                  if (widget.onAddDevice != null) {
                    widget.onAddDevice!();
                  } else {
                    context.push('/onboarding');
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _handleToggle(DeviceUiState uiState) {
    final dev = uiState.device;
    final primaryGang = dev.gangs.isNotEmpty ? dev.gangs.first : null;
    final gangId = primaryGang?.gangId ?? 'gang1';

    final CommandRouter router = widget.commandRouter ?? ref.read(commandRouterProvider);

    ref.read(devicesStateProvider.notifier).toggleGang(
          deviceId: dev.deviceId,
          gangId: gangId,
          router: router,
        );
  }

  void _turnAllOff(List<DeviceUiState> devices) {
    for (final ui in devices) {
      if (ui.effectiveGangIsOn('gang1')) {
        _handleToggle(ui);
      }
    }
  }

  void _openDeviceControl(DeviceUiState uiState) {
    context.push('/device/${uiState.device.deviceId}');
  }

  void _showOfflineHelpSheet(DeviceUiState uiState) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.offline, size: 28),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${uiState.device.name} is Offline',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                const Text('Why might this switch be unreachable?'),
                const SizedBox(height: Spacing.sm),
                _buildHelpBullet('1. Physical switch power may be disconnected or breaker tripped.'),
                _buildHelpBullet('2. Wi-Fi router is offline or 2.4 GHz signal is weak.'),
                _buildHelpBullet('3. The switch is too far from the nearest mesh node.'),
                const SizedBox(height: Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.button),
                      ),
                    ),
                    child: const Text('Got it'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('• $text', style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  void _showQuickActionsSheet(DeviceUiState uiState) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  uiState.device.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename Switch'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rename dialog')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: const Text('Move to Room'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Move room dialog')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded),
                  title: const Text('Add to Favourites'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to favourites')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeBanner(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    if (mode.isDemo) return const SizedBox.shrink();

    final blynkStatus = ref.watch(blynkStatusProvider);
    final isConnected = blynkStatus.isConnected;
    final nodeCount = blynkStatus.nodeCount;
    final lastError = blynkStatus.lastError;

    final Color bannerColor = isConnected ? AppColors.success : AppColors.error;
    final String message = isConnected
        ? 'Connected to Blynk, $nodeCount switch${nodeCount == 1 ? "" : "es"}'
        : (lastError ?? 'Blynk hardware is offline or connecting...');

    return Padding(
      padding: const EdgeInsets.only(
        left: Spacing.screenMargin,
        right: Spacing.screenMargin,
        bottom: Spacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bannerColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.button),
          border: Border.all(color: bannerColor),
        ),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 18,
              color: bannerColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            InkWell(
              onTap: () => context.push('/settings'),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: bannerColor,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
