import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Large circular PowerButton with animated amber glow when energized (Blueprint §4.1 & §4.3).
class PowerButton extends StatefulWidget {
  final bool isOn;
  final bool isPending;
  final VoidCallback? onToggle;
  final double size;

  const PowerButton({
    super.key,
    required this.isOn,
    this.isPending = false,
    this.onToggle,
    this.size = 130,
  });

  @override
  State<PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final baseColor = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.lightSurfaceCard;

    final Color buttonColor;
    final Color iconColor;
    final List<BoxShadow> shadows;

    if (widget.isOn) {
      buttonColor = AppColors.accent;
      iconColor = Colors.white;
      shadows = AppShadows.glow(color: AppColors.accent, blur: 28);
    } else {
      buttonColor = baseColor;
      iconColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
      shadows = isDark ? AppShadows.cardDark : AppShadows.cardLight;
    }

    final semanticLabel = 'Power button, ${widget.isOn ? "on" : "off"}, switch';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: AnimatedScale(
        scale: _isPressed && !reduceMotion ? 0.94 : 1.0,
        duration: AppDurations.cardPress,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {
            AppHaptics.light(reduceMotion: reduceMotion);
            widget.onToggle?.call();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer subtle pulse or pending indicator
              if (widget.isPending)
                SizedBox(
                  width: widget.size + 16,
                  height: widget.size + 16,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),

              // Main circular power button
              AnimatedContainer(
                duration: AppDurations.toggle,
                curve: Curves.easeOut,
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor,
                  border: Border.all(
                    color: widget.isOn
                        ? AppColors.accent
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: 2.0,
                  ),
                  boxShadow: shadows,
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    size: widget.size * 0.45,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
