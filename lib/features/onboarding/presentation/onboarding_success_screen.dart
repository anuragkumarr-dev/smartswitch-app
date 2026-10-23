import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Onboarding success screen with naming and room selection (Blueprint §2.2 & §4.5).
class OnboardingSuccessScreen extends StatefulWidget {
  final String deviceId;
  final Function(String name, String roomId) onComplete;

  const OnboardingSuccessScreen({
    super.key,
    required this.deviceId,
    required this.onComplete,
  });

  @override
  State<OnboardingSuccessScreen> createState() => _OnboardingSuccessScreenState();
}

class _OnboardingSuccessScreenState extends State<OnboardingSuccessScreen> {
  final _nameController = TextEditingController(text: 'Hallway Switch');
  String _selectedRoomId = 'r_living';
  bool _testToggleState = false;

  final _rooms = const [
    {'id': 'r_living', 'name': 'Living Room'},
    {'id': 'r_bed', 'name': 'Bedroom'},
    {'id': 'r_kitchen', 'name': 'Kitchen'},
    {'id': 'r_balcony', 'name': 'Balcony'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Complete')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: Spacing.md),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 50, color: AppColors.success),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Center(
                child: Text(
                  'Switch Added Successfully!',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: Spacing.xl),

              // Switch Name Input
              Text('Name your switch', style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.xs),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                ),
              ),

              const SizedBox(height: Spacing.lg),

              // Room Selection Chips
              Text('Assign to a Room', style: theme.textTheme.titleMedium),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: 8,
                children: _rooms.map((room) {
                  final isSelected = _selectedRoomId == room['id'];
                  return ChoiceChip(
                    label: Text(room['name']!),
                    selected: isSelected,
                    selectedColor: AppColors.accent,
                    onSelected: (_) => setState(() => _selectedRoomId = room['id']!),
                  );
                }).toList(),
              ),

              const SizedBox(height: Spacing.xl),

              // Test Toggle Card (Blueprint §2.2 Step 12)
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Relay Toggle',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          _testToggleState ? 'Relay is ON' : 'Relay is OFF',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _testToggleState,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) {
                        AppHaptics.light();
                        setState(() => _testToggleState = val);
                      },
                    ),
                  ],
                ),
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
                  onPressed: () {
                    final name = _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : 'Smart Switch';
                    widget.onComplete(name, _selectedRoomId);
                  },
                  child: const Text('Complete Setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
