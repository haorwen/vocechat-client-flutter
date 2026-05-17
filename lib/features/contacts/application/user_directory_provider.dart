import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../messages/data/message_cache.dart';

part 'user_directory_provider.g.dart';

// ---------------------------------------------------------------------------
// UserSummary — minimal user info for display in chat bubbles
// ---------------------------------------------------------------------------

class UserSummary {
  const UserSummary({
    required this.uid,
    required this.name,
    this.avatarUpdatedAt,
  });

  final int uid;
  final String name;
  final int? avatarUpdatedAt;

  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
        uid: (j['uid'] as num).toInt(),
        name: j['name'] as String? ?? 'Unknown',
        avatarUpdatedAt: (j['avatar_updated_at'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        if (avatarUpdatedAt != null) 'avatar_updated_at': avatarUpdatedAt,
      };
}

// ---------------------------------------------------------------------------
// GroupSummary — minimal group info for display in AppBar
// ---------------------------------------------------------------------------

class PinnedMessageSummary {
  const PinnedMessageSummary({
    required this.mid,
    required this.content,
    required this.contentType,
    required this.createdBy,
    required this.createdAt,
  });

  final int mid;
  final String content;
  final String contentType;
  final int createdBy;
  final int createdAt;

  factory PinnedMessageSummary.fromJson(Map<String, dynamic> j) =>
      PinnedMessageSummary(
        mid: (j['mid'] as num).toInt(),
        content: j['content'] as String? ?? '',
        contentType: j['content_type'] as String? ?? 'text/plain',
        createdBy: (j['created_by'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'content': content,
        'content_type': contentType,
        'created_by': createdBy,
        'created_at': createdAt,
      };
}

class GroupSummary {
  const GroupSummary({
    required this.gid,
    required this.name,
    this.avatarUpdatedAt,
    this.owner = 0,
    this.isPublic = false,
    this.members = const [],
    this.pinnedMessages = const [],
  });

  final int gid;
  final String name;
  final int? avatarUpdatedAt;
  final int owner;
  final bool isPublic;
  final List<int> members;
  final List<PinnedMessageSummary> pinnedMessages;

  GroupSummary copyWith({
    List<PinnedMessageSummary>? pinnedMessages,
    List<int>? members,
  }) =>
      GroupSummary(
        gid: gid,
        name: name,
        avatarUpdatedAt: avatarUpdatedAt,
        owner: owner,
        isPublic: isPublic,
        members: members ?? this.members,
        pinnedMessages: pinnedMessages ?? this.pinnedMessages,
      );

  factory GroupSummary.fromJson(Map<String, dynamic> j) => GroupSummary(
        gid: (j['gid'] as num).toInt(),
        name: j['name'] as String? ?? 'Group',
        avatarUpdatedAt: (j['avatar_updated_at'] as num?)?.toInt(),
        owner: (j['owner'] as num?)?.toInt() ?? 0,
        isPublic: j['is_public'] as bool? ?? false,
        members: (j['members'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            const [],
        pinnedMessages: (j['pinned_messages'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(PinnedMessageSummary.fromJson)
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'gid': gid,
        'name': name,
        if (avatarUpdatedAt != null) 'avatar_updated_at': avatarUpdatedAt,
        'owner': owner,
        'is_public': isPublic,
        'members': members,
        'pinned_messages':
            pinnedMessages.map((p) => p.toJson()).toList(growable: false),
      };
}

// ---------------------------------------------------------------------------
// userDirectoryProvider — keepAlive map of uid -> UserSummary
//
// Cold-start sequence: emit the cached map immediately, then refresh from
// network in the background. Network errors leave the cached snapshot.
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class UserDirectory extends _$UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async {
    final cache = await ref.watch(messageCacheProvider.future);

    final cached = await cache.readUserDirectory();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(() => _refresh(cache));
      return {
        for (final j in cached)
          (j['uid'] as num).toInt(): UserSummary.fromJson(j),
      };
    }

    return _fetch(cache);
  }

  Future<Map<int, UserSummary>> _fetch(MessageCache cache) async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/user');
      final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
      final map = {
        for (final u in list) (u['uid'] as num).toInt(): UserSummary.fromJson(u)
      };
      // Persist as a flat list of JSON maps for round-trip fidelity.
      cache.writeUserDirectory(map.values.map((u) => u.toJson()).toList());
      return map;
    } on DioException {
      return state.valueOrNull ?? const {};
    }
  }

  Future<void> _refresh(MessageCache cache) async {
    final fresh = await _fetch(cache);
    if (fresh.isEmpty) return;
    state = AsyncData(fresh);
  }
}

// ---------------------------------------------------------------------------
// groupDirectoryProvider — keepAlive map of gid -> GroupSummary
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class GroupDirectory extends _$GroupDirectory {
  @override
  Future<Map<int, GroupSummary>> build() async {
    final cache = await ref.watch(messageCacheProvider.future);

    final cached = await cache.readGroupDirectory();
    if (cached != null && cached.isNotEmpty) {
      Future.microtask(() => _refresh(cache));
      return {
        for (final j in cached)
          (j['gid'] as num).toInt(): GroupSummary.fromJson(j),
      };
    }

    return _fetch(cache);
  }

  Future<Map<int, GroupSummary>> _fetch(MessageCache cache) async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/group');
      final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
      final map = {
        for (final g in list)
          (g['gid'] as num).toInt(): GroupSummary.fromJson(g)
      };
      cache.writeGroupDirectory(map.values.map((g) => g.toJson()).toList());
      return map;
    } on DioException {
      return state.valueOrNull ?? const {};
    }
  }

  Future<void> _refresh(MessageCache cache) async {
    final fresh = await _fetch(cache);
    if (fresh.isEmpty) return;
    state = AsyncData(fresh);
  }

  Future<void> refresh() async {
    final cache = await ref.read(messageCacheProvider.future);
    await _refresh(cache);
  }

  void applyPinned(int gid, List<PinnedMessageSummary> pinned) {
    final current = state.valueOrNull;
    if (current == null) return;
    final group = current[gid];
    if (group == null) return;
    state = AsyncData({
      ...current,
      gid: group.copyWith(pinnedMessages: pinned),
    });
  }
}
