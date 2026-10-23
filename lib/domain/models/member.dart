import 'package:flutter/foundation.dart';

/// Role access levels within a Home (Blueprint §1 & §5).
enum MemberRole {
  owner,
  admin,
  member,
  guest;

  String get displayName {
    switch (this) {
      case MemberRole.owner:
        return 'Owner';
      case MemberRole.admin:
        return 'Admin';
      case MemberRole.member:
        return 'Member';
      case MemberRole.guest:
        return 'Guest';
    }
  }

  static MemberRole fromString(String val) {
    switch (val.toLowerCase()) {
      case 'owner':
        return MemberRole.owner;
      case 'admin':
        return MemberRole.admin;
      case 'guest':
        return MemberRole.guest;
      case 'member':
      default:
        return MemberRole.member;
    }
  }
}

/// Member of a Home (Blueprint §1 & §5).
@immutable
class Member {
  final String userId;
  final String homeId;
  final MemberRole role;
  final String? emailOrPhone;
  final String? displayName;

  const Member({
    required this.userId,
    required this.homeId,
    required this.role,
    this.emailOrPhone,
    this.displayName,
  });

  Member copyWith({
    String? userId,
    String? homeId,
    MemberRole? role,
    String? emailOrPhone,
    String? displayName,
  }) {
    return Member(
      userId: userId ?? this.userId,
      homeId: homeId ?? this.homeId,
      role: role ?? this.role,
      emailOrPhone: emailOrPhone ?? this.emailOrPhone,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'homeId': homeId,
      'role': role.name,
      'emailOrPhone': emailOrPhone,
      'displayName': displayName,
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      userId: json['userId'] as String,
      homeId: json['homeId'] as String,
      role: MemberRole.fromString(json['role'] as String? ?? 'member'),
      emailOrPhone: json['emailOrPhone'] as String?,
      displayName: json['displayName'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          homeId == other.homeId &&
          role == other.role &&
          emailOrPhone == other.emailOrPhone &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(userId, homeId, role, emailOrPhone, displayName);

  @override
  String toString() => 'Member(userId: $userId, role: ${role.name})';
}
