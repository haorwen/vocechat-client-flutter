import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_log.dart';
import '../../contacts/application/user_directory_provider.dart';

part 'chat_tools_provider.g.dart';

// ---------------------------------------------------------------------------
// chat tools: pin/unpin + favorites
// ---------------------------------------------------------------------------

/// Favorite archive — opaque server id grouping one or more original messages.
class FavoriteSummary {
  const FavoriteSummary({
    required this.id,
    required this.createdAt,
    required this.messages,
  });

  final String id;
  final int createdAt;
  final List<FavoriteMessage> messages;

  factory FavoriteSummary.fromJson(Map<String, dynamic> j) => FavoriteSummary(
        id: j['id'] as String? ?? '',
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        messages: (j['messages'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(FavoriteMessage.fromJson)
                .toList() ??
            const [],
      );
}

class FavoriteMessage {
  const FavoriteMessage({
    required this.fromMid,
    required this.fromUid,
    required this.createdAt,
    required this.contentType,
    required this.content,
  });

  final int fromMid;
  final int fromUid;
  final int createdAt;
  final String contentType;
  final String content;

  factory FavoriteMessage.fromJson(Map<String, dynamic> j) => FavoriteMessage(
        fromMid: (j['from_mid'] as num?)?.toInt() ?? 0,
        fromUid: (j['from_uid'] as num?)?.toInt() ?? 0,
        createdAt: (j['created_at'] as num?)?.toInt() ?? 0,
        contentType: j['content_type'] as String? ?? 'text/plain',
        content: j['content'] as String? ?? '',
      );
}

@Riverpod(keepAlive: true)
class Favorites extends _$Favorites {
  @override
  Future<List<FavoriteSummary>> build() {
    return _fetch();
  }

  Future<List<FavoriteSummary>> _fetch() async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/favorite');
      final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
      final ids = list
          .map((j) => j['id'] as String?)
          .whereType<String>()
          .toList(growable: false);
      final archives = await Future.wait(ids.map(_fetchArchive));
      return archives.whereType<FavoriteSummary>().toList(growable: false);
    } on DioException catch (e) {
      AppLog.w(LogTag.chat, () => '[favorites] fetch failed: ${e.message}');
      return state.valueOrNull ?? const [];
    }
  }

  Future<FavoriteSummary?> _fetchArchive(String id) async {
    final dio = ref.read(dioProvider);
    try {
      final resp = await dio.get('/api/favorite/$id');
      final body = resp.data as Map<String, dynamic>;
      return FavoriteSummary.fromJson({...body, 'id': id});
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
      final current = state.valueOrNull ?? const <FavoriteSummary>[];
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
