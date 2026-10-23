import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/rssi_bar.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/models/models.dart';
import '../../../state/devices_state.dart';
import '../../../transport/command_router.dart';
import '../widgets/power_button.dart';

/// Full production device control page conforming to Blueprint §4.3.
class DeviceControlScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final CommandRouter? commandRouter;

  const DeviceControlScreen({
    super.key,
    required this.deviceId,
    this.commandRouter,
  });

  @override
  ConsumerState<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends ConsumerState<DeviceControlScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Countdown state
  Duration _selectedCountdownDuration = const Duration(minutes: 30);
  ScheduleAction _countdownAction = ScheduleAction.turnOff;
  Countdown? _activeCountdown;

  // Local device settings
  String _backlightMode = 'dim';
  double _backlightBrightness = 30.0;
  String _indicatorBehaviour = 'follow'; // follow, inverse, always_on
  String _powerOnBehaviour = 'last_state'; // last_state, off, on
  bool _touchLock = false;

  // Schedules state
  final List<Schedule> _schedules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initial mock schedules
    _schedules.addAll([
      Schedule(
        scheduleId: 'sch_1',
        deviceId: widget.deviceId,
        gangId: 'gang1',
        hour: 6,
        minute: 30,
        repeatDays: const [1, 2, 3, 4, 5],
        action: ScheduleAction.turnOn,
        isEnabled: true,
        syncedToDevice: true,
      ),
      Schedule(
        scheduleId: 'sch_2',
        deviceId: widget.deviceId,
        gangId: 'gang1',
        hour: 23,
        minute: 0,
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        action: ScheduleAction.turnOff,
        isEnabled: true,
        syncedToDevice: true,
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final devicesMap = ref.watch(devicesStateProvider);
    final uiState = devicesMap[widget.deviceId];

    // Fallback device if not yet seeded
    final dev = uiState?.device ??
        Device(
          deviceId: widget.deviceId,
          homeId: 'h1',
          roomId: 'r_living',
          name: 'Living Room Switch',
          product: 'SW1-2G',
          gangsCount: 2,
          gatewayId: 'gw_root1',
          gangs: const [
            Gang(gangId: 'gang1', name: 'Ceiling Fan', isOn: false),
            Gang(gangId: 'gang2', name: 'Main Lights', isOn: true),
          ],
        );

    final primaryGang = dev.gangs.isNotEmpty ? dev.gangs.first : null;
    final primaryGangId = primaryGang?.gangId ?? 'gang1';
    final isMasterOn = uiState != null
        ? uiState.effectiveGangIsOn(primaryGangId)
        : dev.isAnyOn;
    final isPending = uiState?.isPending ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              dev.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              dev.product,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _tabController.animateTo(2), // jump to settings
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Hero Power Button Section (Blueprint §4.3)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Center(
                child: PowerButton(
                  isOn: isMasterOn,
                  isPending: isPending,
                  onToggle: () => _handleToggleGang(primaryGangId, isMasterOn),
                ),
              ),
            ),

            // 2. Status Row (Wi-Fi, RSSI, Layer) (Blueprint §4.3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isMasterOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: isMasterOn ? AppColors.accent : theme.disabledColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  const Text('•'),
                  const SizedBox(width: Spacing.sm),
                  const Icon(Icons.wifi_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  const Text('Wi-Fi ok', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: Spacing.sm),
                  const Text('•'),
                  const SizedBox(width: Spacing.sm),
                  const RssiBar(rssi: -58),
                  const SizedBox(width: 4),
                  const Text('-58 dBm', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),

            const SizedBox(height: Spacing.md),

            // 3. Multi-gang Tiles for switches with 2+ gangs (Blueprint §4.3)
            if (dev.gangs.length > 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
                child: _buildGangSelector(dev, uiState),
              ),
              const SizedBox(height: Spacing.md),
            ],

            // 4. Tab Bar (Countdown, Schedule, Settings)
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.lightOnSurfaceVariant,
              tabs: const [
                Tab(text: 'Countdown'),
                Tab(text: 'Schedules'),
                Tab(text: 'Settings'),
              ],
            ),

            // 5. Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCountdownTab(context),
                  _buildSchedulesTab(context),
                  _buildSettingsTab(context, dev),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGangSelector(Device dev, DeviceUiState? uiState) {
    return Row(
      children: dev.gangs.map((gang) {
        final isOn = uiState != null
            ? uiState.effectiveGangIsOn(gang.gangId)
            : gang.isOn;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              avatar: Icon(
                isOn ? Icons.power_rounded : Icons.power_off_rounded,
                size: 16,
                color: isOn ? Colors.white : AppColors.accent,
              ),
              label: Text(gang.name),
              selected: isOn,
              selectedColor: AppColors.accent,
              onSelected: (_) => _handleToggleGang(gang.gangId, isOn),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────
  //  Countdown Tab (Blueprint §4.3)
  // ──────────────────────────────────────────

  Widget _buildCountdownTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.screenMargin),
      child: Column(
        children: [
          // If countdown is active, show running chip & cancel button
          if (_activeCountdown != null && _activeCountdown!.isRunning) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: AppColors.accent),
                      const SizedBox(width: Spacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Turning ${_activeCountdown!.action.displayName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Remaining: ${_activeCountdown!.formattedRemaining}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => setState(() => _activeCountdown = null),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          Text(
            'Set Countdown Timer',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'The timer runs on-device even if the phone disconnects.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Cupertino timer wheel picker
          SizedBox(
            height: 180,
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: _selectedCountdownDuration,
              onTimerDurationChanged: (duration) {
                setState(() => _selectedCountdownDuration = duration);
              },
            ),
          ),

          const SizedBox(height: Spacing.md),

          // Action selector: Turn OFF or Turn ON
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Turn OFF'),
                selected: _countdownAction == ScheduleAction.turnOff,
                selectedColor: AppColors.accent,
                onSelected: (_) => setState(() => _countdownAction = ScheduleAction.turnOff),
              ),
              const SizedBox(width: Spacing.sm),
              ChoiceChip(
                label: const Text('Turn ON'),
                selected: _countdownAction == ScheduleAction.turnOn,
                selectedColor: AppColors.accent,
                onSelected: (_) => setState(() => _countdownAction = ScheduleAction.turnOn),
              ),
            ],
          ),

          const SizedBox(height: Spacing.lg),

          // Start button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.button),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Countdown'),
              onPressed: () {
                final seconds = _selectedCountdownDuration.inSeconds > 0
                    ? _selectedCountdownDuration.inSeconds
                    : 60;
                setState(() {
                  _activeCountdown = Countdown(
                    deviceId: widget.deviceId,
                    gangId: 'gang1',
                    durationSeconds: seconds,
                    remainingSeconds: seconds,
                    action: _countdownAction,
                    isRunning: true,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Countdown started on device')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //  Schedules Tab (Blueprint §4.3)
  // ──────────────────────────────────────────

  Widget _buildSchedulesTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(Spacing.screenMargin),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Active Schedules (${_schedules.length}/20)',
                  style: theme.textTheme.titleMedium),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: _showAddScheduleSheet,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          Expanded(
            child: _schedules.isEmpty
                ? Center(
                    child: Text(
                      'No schedules yet. Tap Add to create one.',
                      style: TextStyle(color: theme.disabledColor),
                    ),
                  )
                : ListView.separated(
                    itemCount: _schedules.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
                    itemBuilder: (context, index) {
                      final sch = _schedules[index];
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sch.formattedTime,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.sm),
                                    StatusChip(
                                      label: sch.action.displayName,
                                      color: sch.action == ScheduleAction.turnOn
                                          ? AppColors.success
                                          : AppColors.error,
                                      backgroundColor: (sch.action == ScheduleAction.turnOn
                                              ? AppColors.success
                                              : AppColors.error)
                                          .withValues(alpha: 0.15),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _formatRepeatDays(sch.repeatDays),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.lightOnSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(width: Spacing.sm),
                                    StatusChip.synced(isSynced: sch.syncedToDevice),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: sch.isEnabled,
                              activeThumbColor: AppColors.accent,
                              onChanged: (val) {
                                setState(() {
                                  _schedules[index] = sch.copyWith(isEnabled: val);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatRepeatDays(List<int> days) {
    if (days.isEmpty) return 'Once';
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'Weekdays';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => names[d - 1]).join(', ');
  }

  void _showAddScheduleSheet() {
    TimeOfDay selectedTime = const TimeOfDay(hour: 7, minute: 0);
    ScheduleAction action = ScheduleAction.turnOn;
    final List<int> repeatDays = [1, 2, 3, 4, 5];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.cardLg)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: Spacing.md,
                right: Spacing.md,
                top: Spacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Schedule', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(),
                  ListTile(
                    title: const Text('Time'),
                    trailing: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: Spacing.sm),
                  const Text('Repeat Days:'),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final dayIndex = i + 1;
                      const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final isSelected = repeatDays.contains(dayIndex);
                      return FilterChip(
                        label: Text(dayLabels[i]),
                        selected: isSelected,
                        selectedColor: AppColors.accent,
                        onSelected: (val) {
                          setSheetState(() {
                            if (val) {
                              repeatDays.add(dayIndex);
                            } else {
                              repeatDays.remove(dayIndex);
                            }
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: Spacing.md),
                  Row(
                    children: [
                      const Text('Action: '),
                      ChoiceChip(
                        label: const Text('Turn ON'),
                        selected: action == ScheduleAction.turnOn,
                        selectedColor: AppColors.accent,
                        onSelected: (_) => setSheetState(() => action = ScheduleAction.turnOn),
                      ),
                      const SizedBox(width: Spacing.sm),
                      ChoiceChip(
                        label: const Text('Turn OFF'),
                        selected: action == ScheduleAction.turnOff,
                        selectedColor: AppColors.accent,
                        onSelected: (_) => setSheetState(() => action = ScheduleAction.turnOff),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
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
                      child: const Text('Save Schedule'),
                      onPressed: () {
                        setState(() {
                          _schedules.add(
                            Schedule(
                              scheduleId: 'sch_${DateTime.now().millisecondsSinceEpoch}',
                              deviceId: widget.deviceId,
                              gangId: 'gang1',
                              hour: selectedTime.hour,
                              minute: selectedTime.minute,
                              repeatDays: repeatDays,
                              action: action,
                              isEnabled: true,
                              syncedToDevice: true,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────
  //  Settings Tab (Blueprint §4.3)
  // ──────────────────────────────────────────

  Widget _buildSettingsTab(BuildContext context, Device dev) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(Spacing.screenMargin),
      children: [
        Text('Backlight & LED Indicator', style: theme.textTheme.titleMedium),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: 8,
          children: ['off', 'dim', 'bright', 'auto'].map((mode) {
            return ChoiceChip(
              label: Text(mode.toUpperCase()),
              selected: _backlightMode == mode,
              selectedColor: AppColors.accent,
              onSelected: (_) => setState(() => _backlightMode = mode),
            );
          }).toList(),
        ),
        if (_backlightMode != 'off') ...[
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              const Icon(Icons.brightness_6_rounded, size: 20),
              Expanded(
                child: Slider(
                  value: _backlightBrightness,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  activeColor: AppColors.accent,
                  label: '${_backlightBrightness.round()}%',
                  onChanged: (v) => setState(() => _backlightBrightness = v),
                ),
              ),
            ],
          ),
        ],

        const Divider(height: Spacing.xl),

        Text('Indicator Behaviour', style: theme.textTheme.titleMedium),
        DropdownButton<String>(
          value: _indicatorBehaviour,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'follow', child: Text('Follow relay (On when switch is ON)')),
            DropdownMenuItem(value: 'inverse', child: Text('Inverse (On when switch is OFF)')),
            DropdownMenuItem(value: 'always_on', child: Text('Always ON as night locator')),
          ],
          onChanged: (v) => setState(() => _indicatorBehaviour = v ?? 'follow'),
        ),

        const Divider(height: Spacing.xl),

        Text('Power-On Behaviour', style: theme.textTheme.titleMedium),
        DropdownButton<String>(
          value: _powerOnBehaviour,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'last_state', child: Text('Restore last state before power cut')),
            DropdownMenuItem(value: 'off', child: Text('Default to OFF')),
            DropdownMenuItem(value: 'on', child: Text('Default to ON')),
          ],
          onChanged: (v) => setState(() => _powerOnBehaviour = v ?? 'last_state'),
        ),

        const Divider(height: Spacing.xl),

        SwitchListTile(
          title: const Text('Touch Lock (Child Lock)'),
          subtitle: const Text('Disable physical touch buttons on the switch wall plate'),
          value: _touchLock,
          activeThumbColor: AppColors.accent,
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _touchLock = v),
        ),

        const Divider(height: Spacing.xl),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Firmware Version'),
          subtitle: Text(dev.fwVersion),
          trailing: const Text('Up to date', style: TextStyle(color: AppColors.success)),
        ),

        const SizedBox(height: Spacing.lg),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.button),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Remove Switch'),
            onPressed: () => _confirmRemoveDevice(context),
          ),
        ),
      ],
    );
  }

  void _confirmRemoveDevice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Switch?'),
          content: const Text(
            'Removing this switch will clear home keys and unbind it. '
            'To set it up again, press and hold the physical button for 5 seconds to reset it.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Remove', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _handleToggleGang(String gangId, bool currentIsOn) {
    if (widget.commandRouter != null) {
      ref.read(devicesStateProvider.notifier).toggleGang(
            deviceId: widget.deviceId,
            gangId: gangId,
            router: widget.commandRouter!,
          );
    } else {
      ref.read(devicesStateProvider.notifier).markPending(
            deviceId: widget.deviceId,
            gangId: gangId,
            desired: !currentIsOn,
            commandId: 'cmd_${DateTime.now().millisecondsSinceEpoch}',
          );
    }
  }
}
