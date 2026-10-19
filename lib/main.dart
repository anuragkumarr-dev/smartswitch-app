import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SmartSwitchApp(),
    ),
  );
}

class SmartSwitchApp extends StatelessWidget {
  const SmartSwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSwitch',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const PlaceholderHomeScreen(),
    );
  }
}

/// Temporary placeholder — will be replaced by the real home screen in Phase 4.
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SmartSwitch',
          style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: colorScheme.primary,
              semanticLabel: 'SmartSwitch logo placeholder',
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Welcome to SmartSwitch',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Phase 0 — Foundation ready.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
