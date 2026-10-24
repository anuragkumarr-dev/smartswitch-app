import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'member.dart';

/// Single-use, expiring Home invite representation (Blueprint §5).
@immutable
class HomeInvite {
  final String inviteId;
  final String homeId;
  final String homeName;
  final MemberRole role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isConsumed;
  final String? consumedByUserId;
  final String signature;

  const HomeInvite({
    required this.inviteId,
    required this.homeId,
    required this.homeName,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.isConsumed = false,
    this.consumedByUserId,
    required this.signature,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isConsumed && !isExpired;

  HomeInvite markConsumed(String userId) {
    return HomeInvite(
      inviteId: inviteId,
      homeId: homeId,
      homeName: homeName,
      role: role,
      createdAt: createdAt,
      expiresAt: expiresAt,
      isConsumed: true,
      consumedByUserId: userId,
      signature: signature,
    );
  }

  /// Encodes invite into a QR code payload:
  /// `SW_INVITE:<inviteId>:<homeId>:<role>:<expiresAtMs>:<signature>`
  String toQrPayload() {
    return 'SW_INVITE:$inviteId:$homeId:${role.name}:${expiresAt.millisecondsSinceEpoch}:$signature';
  }

  /// Formats invite as a deep link URL.
  String toDeepLink() {
    final payloadJson = jsonEncode(toJson());
    final encoded = base64UrlEncode(utf8.encode(payloadJson));
    return 'https://app.smartswitch.io/invite?code=$encoded';
  }

  Map<String, dynamic> toJson() {
    return {
      'inviteId': inviteId,
      'homeId': homeId,
      'homeName': homeName,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isConsumed': isConsumed,
      'consumedByUserId': consumedByUserId,
      'signature': signature,
    };
  }

  factory HomeInvite.fromJson(Map<String, dynamic> json) {
    return HomeInvite(
      inviteId: json['inviteId'] as String,
      homeId: json['homeId'] as String,
      homeName: json['homeName'] as String? ?? 'Home',
      role: MemberRole.fromString(json['role'] as String? ?? 'member'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isConsumed: json['isConsumed'] as bool? ?? false,
      consumedByUserId: json['consumedByUserId'] as String?,
      signature: json['signature'] as String? ?? '',
    );
  }

  /// Parses an invite from either a QR string or deep-link code.
  static HomeInvite? parse(String raw) {
    try {
      if (raw.startsWith('SW_INVITE:')) {
        final parts = raw.split(':');
        if (parts.length >= 6) {
          final inviteId = parts[1];
          final homeId = parts[2];
          final role = MemberRole.fromString(parts[3]);
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4]));
          final signature = parts[5];
          return HomeInvite(
            inviteId: inviteId,
            homeId: homeId,
            homeName: 'Home $homeId',
            role: role,
            createdAt: expiresAt.subtract(const Duration(hours: 24)),
            expiresAt: expiresAt,
            signature: signature,
          );
        }
      } else if (raw.contains('code=')) {
        final uri = Uri.parse(raw);
        final code = uri.queryParameters['code'];
        if (code != null) {
          final decoded = utf8.decode(base64Url.decode(code));
          return HomeInvite.fromJson(jsonDecode(decoded) as Map<String, dynamic>);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
