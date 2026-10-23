import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/models/models.dart';
import '../../../state/devices_state.dart';

/// Reusable device card component conforming to Blueprint §4.1 & §4.2.
///
/// States:
/// - `on`: Amber glow on icon, energized toggle
/// - `off`: Neutral surface card
/// - `pending`: Thin spinner ring around toggle, instant optimistic feedback
/// - `offline`: Greyed card, toggle disabled, tap opens help sheet
/// - `error`: Shake animation + error snackbar with retry
class DeviceCard extends StatefulWidget {
  final DeviceUiState uiState;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onOfflineHelp;
  final Countdown? activeCountdown;

  const DeviceCard({
    super.key,
    required this.uiState,
    this.onToggle,
    this.onTap,
    this.onLongPress,
    this.onOfflineHelp,
    this.activeCountdown,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: AppDurations.shake,
    );
  }

  @override
  void didUpdateWidget(DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If an error message arrives, trigger error shake animation
    if (widget.uiState.errorMessage != null &&
        widget.uiState.errorMessage != oldWidget.uiState.errorMessage) {
      if (!MediaQuery.of(context).disableAnimations) {
        _shakeController.forward(from: 0.0);
      }
      AppHaptics.error();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final dev = widget.uiState.device;
    final isOnline = widget.uiState.shadow.online;
    final primaryGang = dev.gangs.isNotEmpty ? dev.gangs.first : null;
    final gangId = primaryGang?.gangId ?? 'gang1';

    final isOn = widget.uiState.effectiveGangIsOn(gangId);
    final isPending = widget.uiState.isPending;
    final hasError = widget.uiState.errorMessage != null;

    final baseCardColor = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.lightSurfaceCard;

    // Visual styling for states
    final Color cardBackground;
    final Color borderColor;
    final List<BoxShadow> shadows;

    if (!isOnline) {
      cardBackground = isDark ? const Color(0xFF1F1F21) : const Color(0xFFEBEBEF);
      borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      shadows = const [];
    } else if (isOn) {
      cardBackground = baseCardColor;
      borderColor = AppColors.accent.withValues(alpha: 0.5);
      shadows = AppShadows.glow(color: AppColors.accent, blur: 14);
    } else {
      cardBackground = baseCardColor;
      borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
      shadows = isDark ? AppShadows.cardDark : AppShadows.cardLight;
    }

    final semanticLabel =
        '${dev.name}, ${!isOnline ? "offline, switch disabled" : (isOn ? "on" : "off")}, switch';

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // Shake calculation: sine wave oscillation
        final shakeOffset = hasError && !reduceMotion
            ? math.sin(_shakeController.value * math.pi * 4) * 6
            : 0.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: child,
        );
      },
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: semanticLabel,
        button: isOnline,
        enabled: isOnline,
        child: AnimatedScale(
          scale: _isPressed && !reduceMotion ? 0.97 : 1.0,
          duration: AppDurations.cardPress,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTapDown: (_) {
                if (isOnline) setState(() => _isPressed = true);
              },
              onTapUp: (_) {
                if (isOnline) setState(() => _isPressed = false);
              },
              onTapCancel: () {
                if (isOnline) setState(() => _isPressed = false);
              },
              onTap: () {
                if (!isOnline) {
                  widget.onOfflineHelp?.call();
                } else {
                  widget.onTap?.call();
                }
              },
              onLongPress: isOnline
                  ? () {
                      AppHaptics.medium(reduceMotion: reduceMotion);
                      widget.onLongPress?.call();
                    }
                  : null,
              child: AnimatedContainer(
                duration: AppDurations.toggle,
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(Radii.card),
                  border: Border.all(
                    color: hasError ? AppColors.error : borderColor,
                    width: isOn || hasError ? 1.5 : 1.0,
                  ),
                  boxShadow: shadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row: Device Icon and Toggle Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon with glow when ON
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: !isOnline
                                ? AppColors.offline.withValues(alpha: 0.2)
                                : (isOn
                                    ? AppColors.accent.withValues(alpha: 0.2)
                                    : (isDark
                                        ? const Color(0xFF38383A)
                                        : const Color(0xFFE5E5EA))),
                          ),
                          child: Icon(
                            _getDeviceIcon(dev.product),
                            size: 22,
                            color: !isOnline
                                ? AppColors.offline
                                : (isOn
                                    ? AppColors.accent
                                    : (isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.lightOnSurfaceVariant)),
                          ),
                        ),

                        // Switch Toggle Pill / Pending Spinner (Blueprint §4.1)
                        _buildToggle(
                          context: context,
                          isOnline: isOnline,
                          isOn: isOn,
                          isPending: isPending,
                          reduceMotion: reduceMotion,
                        ),
                      ],
                    ),

                    const SizedBox(height: Spacing.sm),

                    // Middle/Bottom details: Name, Room, Status / Countdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dev.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: !isOnline
                                ? (isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.lightOnSurfaceVariant)
                                : (isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.lightOnSurface),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (!isOnline) ...[
                              StatusChip.offline(onTap: widget.onOfflineHelp),
                            ] else if (widget.activeCountdown != null &&
                                widget.activeCountdown!.isRunning) ...[
                              StatusChip.countdown(
                                remainingText: widget.activeCountdown!.formattedRemaining,
                              ),
                            ] else ...[
                              Text(
                                dev.gangsCount > 1
                                    ? '${dev.gangsCount} Gangs'
                                    : (isOn ? 'Turned ON' : 'Turned OFF'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.lightOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 48 dp touch-target toggle pill with thin spinner ring when pending.
  Widget _buildToggle({
    required BuildContext context,
    required bool isOnline,
    required bool isOn,
    required bool isPending,
    required bool reduceMotion,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pillBg = !isOnline
        ? (isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6))
        : (isOn
            ? AppColors.accent
            : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA)));

    final knobColor = !isOnline
        ? (isDark ? const Color(0xFF636366) : const Color(0xFF8E8E93))
        : (isOn
            ? Colors.white
            : (isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93)));

    return SizedBox(
      width: 48,
      height: 48, // 48 dp touch target (Blueprint §4.1)
      child: Center(
        child: GestureDetector(
          key: const Key('device_card_toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: isOnline
              ? () {
                  AppHaptics.light(reduceMotion: reduceMotion);
                  widget.onToggle?.call();
                }
              : () => widget.onOfflineHelp?.call(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer thin spinner ring when pending
              if (isPending)
                SizedBox(
                  width: 46,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),

              // Pill body
              AnimatedContainer(
                duration: AppDurations.toggle,
                curve: Curves.easeOut,
                width: 42,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.toggle),
                  color: pillBg,
                ),
                padding: const EdgeInsets.all(2),
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: knobColor,
                    boxShadow: isOn
                        ? [
                            const BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getDeviceIcon(String product) {
    if (product.toLowerCase().contains('fan')) return Icons.mode_fan_off_rounded;
    if (product.toLowerCase().contains('socket')) return Icons.power_rounded;
    return Icons.lightbulb_outline_rounded;
  }
}
