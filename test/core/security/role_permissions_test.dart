import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartswitch_app/core/security/role_permissions.dart';
import 'package:smartswitch_app/domain/models/models.dart';
import 'package:smartswitch_app/state/devices_state.dart';
import 'package:smartswitch_app/state/homes_state.dart';

void main() {
  group('Role Permissions Matrix (Blueprint §5 & docs/threat_model.md)', () {
    test('Owner has unrestricted access to all actions', () {
      for (final action in RoleAction.values) {
        expect(
          RolePermissions.can(MemberRole.owner, action),
          isTrue,
          reason: 'Owner must be able to perform ${action.name}',
        );
        expect(() => RolePermissions.assertCan(MemberRole.owner, action), returnsNormally);
      }
    });

    test('Admin permissions: devices, schedules, invites, mesh re-election; but cannot change roles or factory reset', () {
      expect(RolePermissions.can(MemberRole.admin, RoleAction.toggleSwitch), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.viewDiagnostics), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.addDevice), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.removeDevice), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.editSchedules), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.inviteMember), isTrue);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.reElectRoot), isTrue);

      // Blocked actions for Admin (Owner only)
      expect(RolePermissions.can(MemberRole.admin, RoleAction.changeRoles), isFalse);
      expect(RolePermissions.can(MemberRole.admin, RoleAction.factoryReset), isFalse);

      expect(
        () => RolePermissions.assertCan(MemberRole.admin, RoleAction.changeRoles),
        throwsA(isA<UnauthorizedRoleException>()),
      );
      expect(
        () => RolePermissions.assertCan(MemberRole.admin, RoleAction.factoryReset),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Member permissions: toggle switch, diagnostics, edit schedules; blocked from management', () {
      expect(RolePermissions.can(MemberRole.member, RoleAction.toggleSwitch), isTrue);
      expect(RolePermissions.can(MemberRole.member, RoleAction.viewDiagnostics), isTrue);
      expect(RolePermissions.can(MemberRole.member, RoleAction.editSchedules), isTrue);

      // Blocked management actions
      expect(RolePermissions.can(MemberRole.member, RoleAction.addDevice), isFalse);
      expect(RolePermissions.can(MemberRole.member, RoleAction.removeDevice), isFalse);
      expect(RolePermissions.can(MemberRole.member, RoleAction.inviteMember), isFalse);
      expect(RolePermissions.can(MemberRole.member, RoleAction.reElectRoot), isFalse);
      expect(RolePermissions.can(MemberRole.member, RoleAction.changeRoles), isFalse);
      expect(RolePermissions.can(MemberRole.member, RoleAction.factoryReset), isFalse);

      expect(
        () => RolePermissions.assertCan(MemberRole.member, RoleAction.addDevice),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Guest permissions: can only toggle switch and view diagnostics', () {
      expect(RolePermissions.can(MemberRole.guest, RoleAction.toggleSwitch), isTrue);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.viewDiagnostics), isTrue);

      // Blocked actions
      expect(RolePermissions.can(MemberRole.guest, RoleAction.editSchedules), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.addDevice), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.removeDevice), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.inviteMember), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.reElectRoot), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.changeRoles), isFalse);
      expect(RolePermissions.can(MemberRole.guest, RoleAction.factoryReset), isFalse);

      expect(
        () => RolePermissions.assertCan(MemberRole.guest, RoleAction.editSchedules),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });
  });

  group('State Layer Role Enforcement (DevicesNotifier & HomesNotifier)', () {
    late ProviderContainer container;
    late DevicesNotifier devicesNotifier;
    late HomesNotifier homesNotifier;

    final testDevice = Device(
      deviceId: 'dev_test_rbac',
      homeId: 'h_1',
      roomId: 'r_1',
      name: 'RBAC Switch',
      product: 'SW1-1G',
      gangsCount: 1,
      gatewayId: 'gw_1',
      gangs: const [Gang(gangId: 'gang1', name: 'Bulb', isOn: false)],
      shadow: const Shadow(ver: 1, online: true),
    );

    final testSchedule = Schedule(
      scheduleId: 'sch_1',
      deviceId: 'dev_test_rbac',
      gangId: 'gang1',
      hour: 8,
      minute: 0,
      repeatDays: const [1, 2, 3, 4, 5],
      action: ScheduleAction.turnOn,
    );

    setUp(() {
      container = ProviderContainer();
      devicesNotifier = container.read(devicesStateProvider.notifier);
      homesNotifier = container.read(homesStateProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('Guest cannot add device or edit schedule in state layer', () {
      expect(
        () => devicesNotifier.addDevice(testDevice, userRole: MemberRole.guest),
        throwsA(isA<UnauthorizedRoleException>()),
      );
      expect(
        () => devicesNotifier.updateSchedule('dev_test_rbac', testSchedule, userRole: MemberRole.guest),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Member can edit schedule but cannot add or remove device', () {
      expect(
        () => devicesNotifier.updateSchedule('dev_test_rbac', testSchedule, userRole: MemberRole.member),
        returnsNormally,
      );
      expect(
        () => devicesNotifier.addDevice(testDevice, userRole: MemberRole.member),
        throwsA(isA<UnauthorizedRoleException>()),
      );
      expect(
        () => devicesNotifier.removeDevice('dev_test_rbac', userRole: MemberRole.member),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Admin can add and remove device, but cannot factory reset home', () {
      expect(
        () => devicesNotifier.addDevice(testDevice, userRole: MemberRole.admin),
        returnsNormally,
      );
      expect(
        () => devicesNotifier.removeDevice('dev_test_rbac', userRole: MemberRole.admin),
        returnsNormally,
      );
      expect(
        () => homesNotifier.factoryResetHome('h_1', actorRole: MemberRole.admin),
        throwsA(isA<UnauthorizedRoleException>()),
      );
    });

    test('Owner can perform all operations in state layer', () async {
      expect(
        () => devicesNotifier.addDevice(testDevice, userRole: MemberRole.owner),
        returnsNormally,
      );
      expect(
        () => homesNotifier.changeMemberRole('h_1', 'u_2', MemberRole.admin, actorRole: MemberRole.owner),
        returnsNormally,
      );
      await expectLater(
        homesNotifier.factoryResetHome('h_1', actorRole: MemberRole.owner),
        completes,
      );
    });
  });
}
