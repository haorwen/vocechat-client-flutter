import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks which conversations are currently muted.
///
/// The server broadcasts mute state via `user_settings` (snapshot with
/// `mute_users` / `mute_groups`) and `user_settings_changed` (delta with
/// `add_mute_users` / `add_mute_groups` / `remove_mute_users` /
/// `remove_mute_groups`). This provider is the local source of truth,
/// mirroring the web reference's `footprint.muteChannels` /
/// `footprint.muteUsers`.
class MutedChatsState {
  const MutedChatsState({
    this.mutedUsers = const {},
    this.mutedGroups = const {},
  });

  final Set<int> mutedUsers;
  final Set<int> mutedGroups;

  bool isUserMuted(int uid) => mutedUsers.contains(uid);
  bool isGroupMuted(int gid) => mutedGroups.contains(gid);
}

class MutedChatsNotifier extends StateNotifier<MutedChatsState> {
  MutedChatsNotifier() : super(const MutedChatsState());

  /// Replace the full mute set (from `user_settings` snapshot).
  void applySnapshot({
    Set<int> users = const {},
    Set<int> groups = const {},
  }) {
    state = MutedChatsState(mutedUsers: users, mutedGroups: groups);
  }

  /// Apply a delta (from `user_settings_changed`).
  void applyDelta({
    List<int> addUsers = const [],
    List<int> addGroups = const [],
    List<int> removeUsers = const [],
    List<int> removeGroups = const [],
  }) {
    final users = {...state.mutedUsers}
      ..addAll(addUsers)
      ..removeAll(removeUsers);
    final groups = {...state.mutedGroups}
      ..addAll(addGroups)
      ..removeAll(removeGroups);
    state = MutedChatsState(mutedUsers: users, mutedGroups: groups);
  }

  /// Optimistic local toggle.
  void muteUser(int uid) {
    state = MutedChatsState(
      mutedUsers: {...state.mutedUsers, uid},
      mutedGroups: state.mutedGroups,
    );
  }

  void unmuteUser(int uid) {
    state = MutedChatsState(
      mutedUsers: {...state.mutedUsers}..remove(uid),
      mutedGroups: state.mutedGroups,
    );
  }

  void muteGroup(int gid) {
    state = MutedChatsState(
      mutedUsers: state.mutedUsers,
      mutedGroups: {...state.mutedGroups, gid},
    );
  }

  void unmuteGroup(int gid) {
    state = MutedChatsState(
      mutedUsers: state.mutedUsers,
      mutedGroups: {...state.mutedGroups}..remove(gid),
    );
  }

  bool isUserMuted(int uid) => state.mutedUsers.contains(uid);
  bool isGroupMuted(int gid) => state.mutedGroups.contains(gid);
}

final mutedChatsProvider =
    StateNotifierProvider<MutedChatsNotifier, MutedChatsState>(
  (ref) => MutedChatsNotifier(),
);
