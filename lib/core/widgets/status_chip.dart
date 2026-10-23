import 'package:flutter/material.dart';
import '../theme.dart';

/// Small status pill chip used on cards and control pages (Blueprint §4.2 & §4.3).
class StatusChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatusChip({
    super.key,
    this.icon,
    required this.label,
    this.color,
    this.backgroundColor,
    this.onTap,
  });

  /// Factory for a running countdown chip.
  factory StatusChip.countdown({
    Key? key,
    required String remainingText,
    VoidCallback? onTap,
  }) {
    return StatusChip(
      key: key,
      icon: Icons.timer_outlined,
      label: remainingText,
      color: AppColors.accent,
      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
      onTap: onTap,
    );
  }

  /// Factory for a "Synced to device" badge.
  factory StatusChip.synced({Key? key, bool isSynced = true}) {
    return StatusChip(
      key: key,
      icon: isSynced ? Icons.check_circle_outline : Icons.sync,
      label: isSynced ? 'Synced to device' : 'Syncing...',
      color: isSynced ? AppColors.success : AppColors.accent,
      backgroundColor: (isSynced ? AppColors.success : AppColors.accent)
          .withValues(alpha: 0.15),
    );
  }

  /// Factory for an offline badge.
  factory StatusChip.offline({Key? key, VoidCallback? onTap}) {
    return StatusChip(
      key: key,
      icon: Icons.cloud_off_outlined,
      label: 'Offline',
      color: AppColors.offline,
      backgroundColor: AppColors.offline.withValues(alpha: 0.18),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = color ??
        (isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant);
    final effectiveBg = backgroundColor ??
        (isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA));

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(Radii.toggle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: Spacing.xs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.toggle),
        child: content,
      );
    }

    return content;
  }
}
