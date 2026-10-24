import 'dart:math';
import '../../core/security/role_permissions.dart';
import '../../domain/models/models.dart';

class InviteException implements Exception {
  final String message;
  const InviteException(this.message);
  @override
  String toString() => 'InviteException: $message';
}

class InviteExpiredException extends InviteException {
  const InviteExpiredException() : super('This invitation has expired.');
}

class InviteAlreadyUsedException extends InviteException {
  const InviteAlreadyUsedException() : super('This invitation has already been used.');
}

class InviteInvalidHomeException extends InviteException {
  const InviteInvalidHomeException() : super('Invitation is for a different home.');
}

class InviteNotFoundException extends InviteException {
  const InviteNotFoundException() : super('Invalid invitation code or QR code.');
}

/// Service managing the creation and redemption of single-use, expiring home invitations (Blueprint §5).
abstract interface class InviteService {
  Future<HomeInvite> createInvite({
    required String homeId,
    required String homeName,
    required MemberRole creatorRole,
    required MemberRole invitedRole,
    Duration validDuration = const Duration(hours: 24),
  });

  Future<Member> acceptInvite({
    required String rawInvite,
    required String userId,
    String? targetHomeId,
  });

  Future<HomeInvite?> getInvite(String inviteId);
}

/// Fake implementation of [InviteService] for tests and offline development.
class FakeInviteService implements InviteService {
  final Map<String, HomeInvite> _invites = {};

  @override
  Future<HomeInvite> createInvite({
    required String homeId,
    required String homeName,
    required MemberRole creatorRole,
    required MemberRole invitedRole,
    Duration validDuration = const Duration(hours: 24),
  }) async {
    // 1. Role permission enforcement: Only owner and admin can create invites
    RolePermissions.assertCan(creatorRole, RoleAction.inviteMember);

    // 2. Cannot invite someone to be Owner
    if (invitedRole == MemberRole.owner) {
      throw const InviteException('Cannot invite a user directly as Owner.');
    }

    final now = DateTime.now();
    final inviteId = 'inv_${now.millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final signature = 'sig_${Random().nextInt(999999)}';

    final invite = HomeInvite(
      inviteId: inviteId,
      homeId: homeId,
      homeName: homeName,
      role: invitedRole,
      createdAt: now,
      expiresAt: now.add(validDuration),
      signature: signature,
    );

    _invites[inviteId] = invite;
    return invite;
  }

  @override
  Future<Member> acceptInvite({
    required String rawInvite,
    required String userId,
    String? targetHomeId,
  }) async {
    final parsed = HomeInvite.parse(rawInvite);
    if (parsed == null) {
      throw const InviteNotFoundException();
    }

    final stored = _invites[parsed.inviteId] ?? parsed;

    // Check single-use
    if (stored.isConsumed) {
      throw const InviteAlreadyUsedException();
    }

    // Check expiry
    if (stored.isExpired) {
      throw const InviteExpiredException();
    }

    // Check home match if requested
    if (targetHomeId != null && targetHomeId != stored.homeId) {
      throw const InviteInvalidHomeException();
    }

    // Mark single-use consumed
    final consumed = stored.markConsumed(userId);
    _invites[stored.inviteId] = consumed;

    return Member(
      userId: userId,
      homeId: stored.homeId,
      role: stored.role,
    );
  }

  @override
  Future<HomeInvite?> getInvite(String inviteId) async {
    return _invites[inviteId];
  }
}
