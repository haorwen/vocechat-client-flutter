import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_log.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../domain/message_models.dart';

part 'chat_tools_provider.g.dart';

// ---------------------------------------------------------------------------
// chat tools: pin/unpin + favorites
// ---------------------------------------------------------------------------

/// Favorite archive — one saved bundle of messages.
///
/// The index endpoint (`GET /api/favorite`) only returns `{id, created_at}`;
/// the bundle itself (`GET /api/favorite/:id`) is the same `Archive` shape
/// used by forwarded messages: denormalized `users` + `messages` where
/// `from_user` is an INDEX into `users`, not a uid.
class FavoriteArchive {
  const FavoriteArchive({
    required this.id,
    required this.createdAt,
    required this.archive,
  });

  final String id;
  final int createdAt;
  final Archive archive;
}

@Riverpod(keepAlive: true)
class Favorites extends _$Favorites {
  @override
  Future<List<FavoriteArchive>> build() {
    return _fetch();
  }

  Future<List<FavoriteArchive>> _fetch() async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/favorite');
      final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
      final favs = await Future.wait(list.map((j) async {
        final id = j['id'] as String? ?? '';
        if (id.isEmpty) return null;
        final archive = await _fetchArchive(id);
        if (archive == null) return null;
        return FavoriteArchive(
          id: id,
          createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
          archive: archive,
        );
      }));
      final result = favs.whereType<FavoriteArchive>().toList()
        // Newest first (the index endpoint returns oldest-first).
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[favorites] fetch failed: ${e.message}');
      return state.valueOrNull ?? const [];
    }
  }

  Future<Archive?> _fetchArchive(String id) async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/favorite/$id');
      return Archive.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLog.w(LogTag.chat,
          () => '[favorites] archive $id fetch failed: ${e.message}');
      return null;
    }
  }

  Future<void> refresh() async {
    state = AsyncData(await _fetch());
  }

  Future<bool> add(List<int> mids) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.post('/api/favorite', data: {'mid_list': mids});
      await refresh();
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[favorites] add failed: ${e.message}');
      return false;
    }
  }

  Future<bool> remove(String id) async {
    final dio = ref.read(dioProvider);
    try {
      await dio.delete('/api/favorite/$id');
      final current = state.valueOrNull ?? const <FavoriteArchive>[];
      state = AsyncData(current.where((f) => f.id != id).toList());
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[favorites] remove failed: ${e.message}');
      return false;
    }
  }
}

// ---------------------------------------------------------------------------
// pin / unpin mutations
// ---------------------------------------------------------------------------

class ChatTools {
  ChatTools(this._ref);
  final Ref _ref;

  Future<bool> pin({required int gid, required int mid}) async {
    final dio = _ref.read(dioProvider);
    try {
      await dio.post('/api/group/$gid/pin', data: {'mid': mid});
      await _ref.read(groupDirectoryProvider.notifier).refresh();
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[pin] failed: ${e.message}');
      return false;
    }
  }

  Future<bool> unpin({required int gid, required int mid}) async {
    final dio = _ref.read(dioProvider);
    try {
      await dio.post('/api/group/$gid/unpin', data: {'mid': mid});
      await _ref.read(groupDirectoryProvider.notifier).refresh();
      return true;
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[unpin] failed: ${e.message}');
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ChatTools chatTools(Ref ref) => ChatTools(ref);
