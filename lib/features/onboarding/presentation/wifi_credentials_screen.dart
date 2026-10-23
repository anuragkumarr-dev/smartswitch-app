import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Wi-Fi credentials input screen with 2.4 GHz requirement notice (Blueprint §2.2 & §4.5).
class WifiCredentialsScreen extends StatefulWidget {
  final Function(String ssid, String password) onConnect;

  const WifiCredentialsScreen({
    super.key,
    required this.onConnect,
  });

  @override
  State<WifiCredentialsScreen> createState() => _WifiCredentialsScreenState();
}

class _WifiCredentialsScreenState extends State<WifiCredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController(text: 'Home_WiFi_2.4G');
  final _passwordController = TextEditingController(text: 'secret123');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onConnect(_ssidController.text.trim(), _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect to Home Wi-Fi',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Enter the network credentials for your home router. The switch will use these to connect to the cloud and sync mesh time.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // 2.4 GHz Notice Banner (Blueprint §2.2 & §2.4)
                Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 22),
                      const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: Text(
                          '2.4 GHz Network Required: ESP32 switches require a standard 2.4 GHz Wi-Fi band. If your router uses combined 2.4/5 GHz, ensure 2.4 GHz is enabled.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: Spacing.lg),

                // Wi-Fi SSID
                TextFormField(
                  controller: _ssidController,
                  decoration: InputDecoration(
                    labelText: 'Wi-Fi Network Name (SSID)',
                    prefixIcon: const Icon(Icons.wifi_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a Wi-Fi name' : null,
                ),

                const SizedBox(height: Spacing.md),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Wi-Fi Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Please enter your Wi-Fi password' : null,
                ),

                const SizedBox(height: Spacing.xxl),

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
                    onPressed: _handleSubmit,
                    child: const Text('Provision Switch'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
