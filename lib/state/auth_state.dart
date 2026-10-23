import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AuthState {
  final String? userId;
  final String? token;
  final String? currentHomeId;
  final bool isAuthenticated;

  const AuthState({
    this.userId,
    this.token,
    this.currentHomeId,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    String? userId,
    String? token,
    String? currentHomeId,
    bool? isAuthenticated,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      currentHomeId: currentHomeId ?? this.currentHomeId,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          token == other.token &&
          currentHomeId == other.currentHomeId &&
          isAuthenticated == other.isAuthenticated;

  @override
  int get hashCode => Object.hash(userId, token, currentHomeId, isAuthenticated);

  @override
  String toString() =>
      'AuthState(user: $userId, authenticated: $isAuthenticated, home: $currentHomeId)';
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  void login({
    required String userId,
    required String token,
    String? defaultHomeId,
  }) {
    state = AuthState(
      userId: userId,
      token: token,
      currentHomeId: defaultHomeId,
      isAuthenticated: true,
    );
  }

  void selectHome(String homeId) {
    state = state.copyWith(currentHomeId: homeId);
  }

  void logout() {
    state = const AuthState();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
