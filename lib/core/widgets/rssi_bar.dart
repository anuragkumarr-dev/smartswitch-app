import 'package:flutter/material.dart';
import '../theme.dart';

/// Renders a 4-bar RSSI signal strength indicator with semantic labeling (Blueprint §4.4).
class RssiBar extends StatelessWidget {
  final int rssi; // in dBm, e.g. -58
  final bool isOnline;
  final double height;
  final double width;

  const RssiBar({
    super.key,
    required this.rssi,
    this.isOnline = true,
    this.height = 16,
    this.width = 24,
  });

  @override
  Widget build(BuildContext context) {
    final int activeBars;
    final Color barColor;
    final String label;

    if (!isOnline) {
      activeBars = 0;
      barColor = AppColors.rssiOffline;
      label = 'Signal offline';
    } else if (rssi > -60) {
      activeBars = 4;
      barColor = AppColors.rssiStrong;
      label = 'Signal strong, $rssi dBm';
    } else if (rssi >= -70) {
      activeBars = 3;
      barColor = AppColors.rssiStrong;
      label = 'Signal good, $rssi dBm';
    } else if (rssi >= -75) {
      activeBars = 2;
      barColor = AppColors.rssiFair;
      label = 'Signal fair, $rssi dBm';
    } else {
      activeBars = 1;
      barColor = AppColors.rssiWeak;
      label = 'Signal weak, $rssi dBm';
    }

    return Semantics(
      label: label,
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (index) {
            final barHeight = (height * 0.35) + (height * 0.65 * (index / 3));
            final isActive = index < activeBars;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final inactiveColor = isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder;

            return Container(
              width: (width - (3 * 2)) / 4,
              height: barHeight,
              decoration: BoxDecoration(
                color: isActive ? barColor : inactiveColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
