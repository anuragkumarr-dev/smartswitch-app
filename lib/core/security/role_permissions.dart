import '../../domain/models/member.dart';

/// Actions that require role-based access control (Blueprint §5).
enum RoleAction {
  addDevice,
  removeDevice,
  editSchedules,
  inviteMember,
  changeRoles,
  reElectRoot,
  factoryReset,
  toggleSwitch,
  viewDiagnostics,
}

/// Typed exception thrown when a user's role lacks permission for an action.
class UnauthorizedRoleException implements Exception {
  final RoleAction action;
  final MemberRole role;
  final String message;

  UnauthorizedRoleException({
    required this.action,
    required this.role,
    String? message,
  }) : message = message ??
            'Role ${role.displayName} is not authorized to perform ${action.name}.';

  @override
  String toString() => 'UnauthorizedRoleException: $message';
}

/// Centralized role authorization matrix for SmartSwitch.
/// Enforces permissions in the state layer and drives UI action visibility.
class RolePermissions {
  /// Returns whether a given [role] is permitted to execute [action].
  static bool can(MemberRole role, RoleAction action) {
    switch (action) {
      case RoleAction.toggleSwitch:
      case RoleAction.viewDiagnostics:
        // All members, including guests, can control switches and view diagnostics
        return true;

      case RoleAction.editSchedules:
        // Owner, Admin, and Member can edit schedules (Guest cannot)
        return role == MemberRole.owner ||
            role == MemberRole.admin ||
            role == MemberRole.member;

      case RoleAction.addDevice:
      case RoleAction.removeDevice:
      case RoleAction.inviteMember:
      case RoleAction.reElectRoot:
        // Only Owner and Admin can manage devices, invites, and mesh root
        return role == MemberRole.owner || role == MemberRole.admin;

      case RoleAction.changeRoles:
      case RoleAction.factoryReset:
        // Exclusive to the Home Owner
        return role == MemberRole.owner;
    }
  }

  /// Asserts that [role] can execute [action], throwing [UnauthorizedRoleException] if not.
  static void assertCan(MemberRole role, RoleAction action) {
    if (!can(role, action)) {
      throw UnauthorizedRoleException(action: action, role: role);
    }
  }
}
