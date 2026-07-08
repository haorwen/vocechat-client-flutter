import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_log.dart';
import '../data/message_api.dart';

part 'burn_after_read_provider.g.dart';

/// Per-conversation "auto-delete after N seconds" settings, keyed by peer uid
/// (DMs) and gid (channels). `expiresIn <= 0` (absent from the map) means
/// off. Mirrors the web client's `footprint.autoDeleteMsgUsers` /
/// `autoDeleteMsgChannels`.
///
/// Sources, in order of authority:
///   - SSE `user_settings` snapshot (`applySnapshot`, authoritative replace)
///   - SSE `user_settings_changed` delta (`applyDelta`, entry-level
///     upsert/remove — NOT a max-merge like read-index, since this is a plain
///     user setting rather than a monotonic marker)
///   - local optimistic update when the user saves the setting (`setUser`/
///     `setGroup`)
///
/// Kept alive for the whole app lifetime, matching `ReadIndex`/`MutedChats`.
class BurnAfterReadState {
  const BurnAfterReadState({this.users = const {}, this.groups = const {}});

  /// peer uid -> expires_in seconds (only present when > 0)
  final Map<int, int> users;

  /// gid -> expires_in seconds (only present when > 0)
  final Map<int, int> groups;

  int userExpiresIn(int uid) => users[uid] ?? 0;
  int groupExpiresIn(int gid) => groups[gid] ?? 0;

  BurnAfterReadState copyWith({Map<int, int>? users, Map<int, int>? groups}) =>
      BurnAfterReadState(
        users: users ?? this.users,
        groups: groups ?? this.groups,
      );
}

@Riverpod(keepAlive: true)
class BurnAfterRead extends _$BurnAfterRead {
  @override
  BurnAfterReadState build() => const BurnAfterReadState();

  /// Authoritative snapshot from `user_settings`: replace wholesale.
  void applySnapshot(Map<int, int> users, Map<int, int> groups) {
    state = BurnAfterReadState(users: users, groups: groups);
  }

  /// Delta from `user_settings_changed`: `expiresIn > 0` upserts, `<= 0`
  /// (or absent) removes the entry.
  void applyDelta(Map<int, int> users, Map<int, int> groups) {
    if (users.isEmpty && groups.isEmpty) return;
    final mergedUsers = Map<int, int>.from(state.users);
    users.forEach((k, v) {
      if (v > 0) {
        mergedUsers[k] = v;
      } else {
        mergedUsers.remove(k);
      }
    });
    final mergedGroups = Map<int, int>.from(state.groups);
    groups.forEach((k, v) {
      if (v > 0) {
        mergedGroups[k] = v;
      } else {
        mergedGroups.remove(k);
      }
    });
    state = BurnAfterReadState(users: mergedUsers, groups: mergedGroups);
  }

  /// Save a DM's setting. Optimistically updates local state, then persists
  /// via POST /api/user/burn-after-reading. Returns true on success.
  Future<bool> setUser(int uid, int expiresIn) async {
    final api = ref.read(messageApiProvider);
    try {
      await api.updateBurnAfterReading(users: [(uid: uid, expiresIn: expiresIn)]);
      final next = Map<int, int>.from(state.users);
      if (expiresIn > 0) {
        next[uid] = expiresIn;
      } else {
        next.remove(uid);
      }
      state = state.copyWith(users: next);
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat,
          () => '[burnAfterRead] setUser($uid) failed: ${e.message}');
      return false;
    }
  }

  /// Save a channel's setting. Same shape as [setUser].
  Future<bool> setGroup(int gid, int expiresIn) async {
    final api = ref.read(messageApiProvider);
    try {
      await api
          .updateBurnAfterReading(groups: [(gid: gid, expiresIn: expiresIn)]);
      final next = Map<int, int>.from(state.groups);
      if (expiresIn > 0) {
        next[gid] = expiresIn;
      } else {
        next.remove(gid);
      }
      state = state.copyWith(groups: next);
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat,
          () => '[burnAfterRead] setGroup($gid) failed: ${e.message}');
      return false;
    }
  }
}
