import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/security/role_permissions.dart';
import 'package:smartswitch_app/data/invite/invite_service.dart';
import 'package:smartswitch_app/domain/models/models.dart';

void main() {
  group('Single-Use Expiring Invites (Blueprint §5 & docs/threat_model.md)', () {
    late FakeInviteService inviteService;

    setUp(() {
      inviteService = FakeInviteService();
    });

    test('Owner or Admin can generate an invite with a valid role and duration', () async {
      final invite = await inviteService.createInvite(
        homeId: 'h_main',
        homeName: 'Living Space',
        creatorRole: MemberRole.owner,
        invitedRole: MemberRole.member,
        validDuration: const Duration(hours: 12),
      );

      expect(invite.homeId, 'h_main');
      expect(invite.role, MemberRole.member);
      expect(invite.isConsumed, isFalse);
      expect(invite.isExpired, isFalse);
      expect(invite.toQrPayload(), startsWith('SW_INVITE:'));
      expect(invite.toDeepLink(), contains('code='));
    });

    test('Member or Guest cannot generate invites', () async {
      await expectLater(
        inviteService.createInvite(
          homeId: 'h_main',
          homeName: 'Living Space',
          creatorRole: MemberRole.member,
          invitedRole: MemberRole.guest,
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );

      await expectLater(
        inviteService.createInvite(
          homeId: 'h_main',
          homeName: 'Living Space',
          creatorRole: MemberRole.guest,
          invitedRole: MemberRole.guest,
        ),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Cannot generate an invite for Owner role', () async {
      await expectLater(
        inviteService.createInvite(
          homeId: 'h_main',
          homeName: 'Living Space',
          creatorRole: MemberRole.owner,
          invitedRole: MemberRole.owner,
        ),
        throwsA(isA<InviteException>()),
      );
    });

    test('Accepting a valid invite adds user and returns membership', () async {
      final invite = await inviteService.createInvite(
        homeId: 'h_main',
        homeName: 'Living Space',
        creatorRole: MemberRole.admin,
        invitedRole: MemberRole.guest,
      );

      final member = await inviteService.acceptInvite(
        rawInvite: invite.toQrPayload(),
        userId: 'usr_guest_99',
      );

      expect(member.userId, 'usr_guest_99');
      expect(member.homeId, 'h_main');
      expect(member.role, MemberRole.guest);

      // Verify invite is marked consumed in store
      final stored = await inviteService.getInvite(invite.inviteId);
      expect(stored?.isConsumed, isTrue);
      expect(stored?.consumedByUserId, 'usr_guest_99');
    });

    test('Re-using an invite is strictly blocked (single-use control)', () async {
      final invite = await inviteService.createInvite(
        homeId: 'h_main',
        homeName: 'Living Space',
        creatorRole: MemberRole.owner,
        invitedRole: MemberRole.member,
      );

      // First use succeeds
      await inviteService.acceptInvite(
        rawInvite: invite.toQrPayload(),
        userId: 'usr_alice',
      );

      // Second use by another user must throw InviteAlreadyUsedException
      await expectLater(
        inviteService.acceptInvite(
          rawInvite: invite.toQrPayload(),
          userId: 'usr_bob',
        ),
        throwsA(isA<InviteAlreadyUsedException>()),
      );
    });

    test('Expired invite is rejected', () async {
      final invite = await inviteService.createInvite(
        homeId: 'h_main',
        homeName: 'Living Space',
        creatorRole: MemberRole.owner,
        invitedRole: MemberRole.member,
        validDuration: const Duration(milliseconds: -100), // Already expired
      );

      await expectLater(
        inviteService.acceptInvite(
          rawInvite: invite.toQrPayload(),
          userId: 'usr_charlie',
        ),
        throwsA(isA<InviteExpiredException>()),
      );
    });

    test('Invite for wrong home is rejected', () async {
      final invite = await inviteService.createInvite(
        homeId: 'h_house_1',
        homeName: 'House 1',
        creatorRole: MemberRole.owner,
        invitedRole: MemberRole.member,
      );

      await expectLater(
        inviteService.acceptInvite(
          rawInvite: invite.toQrPayload(),
          userId: 'usr_dave',
          targetHomeId: 'h_house_2', // Mismatched home
        ),
        throwsA(isA<InviteInvalidHomeException>()),
      );
    });
  });
}
