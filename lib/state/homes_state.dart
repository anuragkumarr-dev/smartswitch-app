import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/security/role_permissions.dart';
import '../data/local_db/local_database.dart';
import '../domain/models/models.dart';

@immutable
class HomesState {
  final List<Home> homes;
  final String? activeHomeId;
  final bool isLoading;
  final String? errorMessage;

  const HomesState({
    this.homes = const [],
    this.activeHomeId,
    this.isLoading = false,
    this.errorMessage,
  });

  Home? get activeHome {
    if (activeHomeId == null) return homes.isNotEmpty ? homes.first : null;
    return homes.cast<Home?>().firstWhere(
          (h) => h?.homeId == activeHomeId,
          orElse: () => homes.isNotEmpty ? homes.first : null,
        );
  }

  HomesState copyWith({
    List<Home>? homes,
    String? activeHomeId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HomesState(
      homes: homes ?? this.homes,
      activeHomeId: activeHomeId ?? this.activeHomeId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomesState &&
          runtimeType == other.runtimeType &&
          listEquals(homes, other.homes) &&
          activeHomeId == other.activeHomeId &&
          isLoading == other.isLoading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(homes),
        activeHomeId,
        isLoading,
        errorMessage,
      );
}

class HomesNotifier extends Notifier<HomesState> {
  AppLocalDatabase? _localDb;

  void setDatabase(AppLocalDatabase db) {
    _localDb = db;
  }

  @override
  HomesState build() {
    return const HomesState();
  }

  Future<void> loadHomes({AppLocalDatabase? db}) async {
    final database = db ?? _localDb;
    if (database == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await database.getHomes();
      state = state.copyWith(
        homes: list,
        activeHomeId: state.activeHomeId ?? (list.isNotEmpty ? list.first.homeId : null),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addHome(Home home, {AppLocalDatabase? db}) async {
    final database = db ?? _localDb;
    final updatedList = List<Home>.from(state.homes)..add(home);
    state = state.copyWith(
      homes: updatedList,
      activeHomeId: state.activeHomeId ?? home.homeId,
    );
    if (database != null) {
      await database.saveHomes([home]);
    }
  }

  void setActiveHome(String homeId) {
    state = state.copyWith(activeHomeId: homeId);
  }

  /// Changes a member's role in the home. Enforces [RoleAction.changeRoles] (Owner only).
  void changeMemberRole(
    String homeId,
    String userId,
    MemberRole newRole, {
    MemberRole actorRole = MemberRole.owner,
  }) {
    RolePermissions.assertCan(actorRole, RoleAction.changeRoles);
  }

  /// Factory resets a home and unbinds its mesh. Enforces [RoleAction.factoryReset] (Owner only).
  Future<void> factoryResetHome(
    String homeId, {
    MemberRole actorRole = MemberRole.owner,
  }) async {
    RolePermissions.assertCan(actorRole, RoleAction.factoryReset);
    final updated = List<Home>.from(state.homes)..removeWhere((h) => h.homeId == homeId);
    state = state.copyWith(
      homes: updated,
      activeHomeId: updated.isNotEmpty ? updated.first.homeId : null,
    );
  }
}

final homesStateProvider = NotifierProvider<HomesNotifier, HomesState>(HomesNotifier.new);
