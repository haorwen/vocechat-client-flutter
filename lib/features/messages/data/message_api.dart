import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/message_models.dart';

part 'message_api.g.dart';

// ---------------------------------------------------------------------------
// MessageApi
// ---------------------------------------------------------------------------

class MessageApi {
  MessageApi(this._dio);

  final Dio _dio;

  // ---- helpers -------------------------------------------------------

  /// Resolve the API path for sending to a target.
  /// Server contract: POST /api/{user|group}/{id}/send (NOT /api/message/...).
  static String _sendPath(MessageTarget target) {
    return target.map(
      user: (t) => '/api/user/${t.uid}/send',
      group: (t) => '/api/group/${t.gid}/send',
    );
  }

  // ---- send ----------------------------------------------------------

  Future<int> sendText(MessageTarget target, String text) async {
    final resp = await _dio.post(
      _sendPath(target),
      data: text,
      options: Options(contentType: 'text/plain'),
    );
    // Server returns raw i64 as JSON body (e.g. 602475), not {"mid": 602475}.
    return (resp.data as num).toInt();
  }

  Future<int> sendMarkdown(MessageTarget target, String md) async {
    final resp = await _dio.post(
      _sendPath(target),
      data: md,
      options: Options(contentType: 'text/markdown'),
    );
    // Server returns raw i64 as JSON body.
    return (resp.data as num).toInt();
  }

  /// Uploads [file] in a single chunk then sends a file message.
  Future<int> uploadFileAndSend(MessageTarget target, File file) async {
    final filename = file.uri.pathSegments.last;
    final contentType = _inferContentType(filename);

    // Step 1: prepare
    final prepareResp = await _dio.post(
      '/api/resource/file/prepare',
      data: {'content_type': contentType, 'filename': filename},
    );
    final fileId = prepareResp.data['file_id'] as String;

    // Step 2: upload chunk (single-chunk upload)
    // Server endpoint: POST /api/resource/file/upload (multipart)
    // Returns UploadFileResponse? { path, size, hash, image_properties }
    // When chunk_is_last=true it returns the response; otherwise null.
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file_id': fileId,
      'chunk_data': MultipartFile.fromBytes(bytes, filename: filename),
      'chunk_is_last': true,
    });
    final uploadResp = await _dio.post(
      '/api/resource/file/upload',
      data: formData,
    );
    // uploadResp.data is the UploadFileResponse object; path is at top level.
    final path = (uploadResp.data as Map<String, dynamic>)['path'] as String;

    // Step 3: send file message — content_type must be vocechat/file, body is JSON {"path": "..."}
    // Server returns raw i64 mid.
    final sendResp = await _dio.post(
      _sendPath(target),
      data: {'path': path},
      options: Options(contentType: 'vocechat/file'),
    );
    return (sendResp.data as num).toInt();
  }

  // ---- history -------------------------------------------------------

  Future<List<ChatMessage>> getHistory(
    MessageTarget target, {
    int? beforeMid,
    int limit = 30,
  }) async {
    final String path = target.map(
      user: (t) => '/api/user/${t.uid}/history',
      group: (t) => '/api/group/${t.gid}/history',
    );

    final Map<String, dynamic> queryParams = {'limit': limit};
    if (beforeMid != null) {
      queryParams['before'] = beforeMid;
    }

    final resp = await _dio.get(
      path,
      queryParameters: queryParams,
    );
    final list = resp.data as List<dynamic>;
    // Server returns oldest-first; the rest of the app (chat_controller,
    // conversation_providers, ListView with reverse:true) all assume
    // newest-first. Reverse once here so that contract is consistent.
    final parsed = list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return parsed.reversed.toList(growable: false);
  }

  // ---- edit / delete / react ----------------------------------------

  Future<int> editMessage(int mid, String text) async {
    final resp = await _dio.put(
      '/api/message/$mid/edit',
      data: text,
      options: Options(contentType: 'text/plain'),
    );
    // Server returns raw i64 (the new reaction mid).
    return (resp.data as num).toInt();
  }

  Future<int> deleteMessage(int mid) async {
    final resp = await _dio.delete('/api/message/$mid');
    // Server returns raw i64 (the new reaction mid).
    return (resp.data as num).toInt();
  }

  Future<int> reactMessage(int mid, String emoji) async {
    final resp = await _dio.put(
      '/api/message/$mid/like',
      data: {'action': emoji},
    );
    // Server returns raw i64 (the new reaction mid).
    return (resp.data as num).toInt();
  }

  // ---- util ----------------------------------------------------------

  static String _inferContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mp3': 'audio/mpeg',
      'pdf': 'application/pdf',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
MessageApi messageApi(Ref ref) {
  return MessageApi(ref.watch(dioProvider));
}
