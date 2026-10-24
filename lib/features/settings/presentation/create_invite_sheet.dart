import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../data/invite/invite_service.dart';
import '../../../domain/models/models.dart';

/// Modal bottom sheet allowing Home Owners and Admins to create expiring single-use invites (Blueprint §5).
class CreateInviteSheet extends StatefulWidget {
  final String homeId;
  final String homeName;
  final MemberRole creatorRole;
  final InviteService inviteService;

  const CreateInviteSheet({
    super.key,
    required this.homeId,
    required this.homeName,
    required this.creatorRole,
    required this.inviteService,
  });

  @override
  State<CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends State<CreateInviteSheet> {
  MemberRole _selectedRole = MemberRole.member;
  int _selectedDurationDays = 1;
  HomeInvite? _createdInvite;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generateInvite() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invite = await widget.inviteService.createInvite(
        homeId: widget.homeId,
        homeName: widget.homeName,
        creatorRole: widget.creatorRole,
        invitedRole: _selectedRole,
        validDuration: Duration(days: _selectedDurationDays),
      );

      setState(() {
        _createdInvite = invite;
        _isLoading = false;
      });
      AppHaptics.light();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: Spacing.screenMargin,
        right: Spacing.screenMargin,
        top: Spacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invite to ${widget.homeName}',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Invites are single-use and automatically expire.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),

          if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: Spacing.md),
          ],

          if (_createdInvite == null) ...[
            // 1. Role selection
            Text('Assign Role:', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              children: [
                if (widget.creatorRole == MemberRole.owner)
                  ChoiceChip(
                    label: const Text('Admin'),
                    selected: _selectedRole == MemberRole.admin,
                    onSelected: (_) => setState(() => _selectedRole = MemberRole.admin),
                  ),
                ChoiceChip(
                  label: const Text('Member'),
                  selected: _selectedRole == MemberRole.member,
                  onSelected: (_) => setState(() => _selectedRole = MemberRole.member),
                ),
                ChoiceChip(
                  label: const Text('Guest'),
                  selected: _selectedRole == MemberRole.guest,
                  onSelected: (_) => setState(() => _selectedRole = MemberRole.guest),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),

            // 2. Expiry duration
            Text('Expires in:', style: theme.textTheme.titleSmall),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              children: [1, 3, 7].map((days) {
                return ChoiceChip(
                  label: Text('$days day${days > 1 ? "s" : ""}'),
                  selected: _selectedDurationDays == days,
                  onSelected: (_) => setState(() => _selectedDurationDays = days),
                );
              }).toList(),
            ),
            const SizedBox(height: Spacing.xl),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.button)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_rounded),
                label: const Text('Generate Invite'),
                onPressed: _isLoading ? null : _generateInvite,
              ),
            ),
          ] else ...[
            // Generated invite details
            Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Invite Created (${_createdInvite!.role.displayName})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Expires: ${_createdInvite!.expiresAt.toLocal()}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Divider(height: Spacing.lg),

                  const Text('QR Code Payload:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(
                    _createdInvite!.toQrPayload(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy Invite Link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _createdInvite!.toDeepLink()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied to clipboard')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
