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

  /// Resolve the API path segment for a target.
  static String _targetPath(MessageTarget target) {
    return target.map(
      user: (t) => 'user/${t.uid}',
      group: (t) => 'group/${t.gid}',
    );
  }

  // ---- send ----------------------------------------------------------

  Future<int> sendText(MessageTarget target, String text) async {
    final resp = await _dio.post(
      '/api/message/${_targetPath(target)}/send',
      data: text,
      options: Options(contentType: 'text/plain'),
    );
    return (resp.data['mid'] as num).toInt();
  }

  Future<int> sendMarkdown(MessageTarget target, String md) async {
    final resp = await _dio.post(
      '/api/message/${_targetPath(target)}/send',
      data: md,
      options: Options(contentType: 'text/markdown'),
    );
    return (resp.data['mid'] as num).toInt();
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
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file_id': fileId,
      'chunk_data': MultipartFile.fromBytes(bytes, filename: filename),
      'chunk_is_last': 'true',
    });
    final uploadResp = await _dio.post(
      '/api/resource/file',
      data: formData,
    );
    final path = uploadResp.data['path'] as String;

    // Step 3: send message with the uploaded path
    final sendResp = await _dio.post(
      '/api/message/${_targetPath(target)}/send',
      data: {'path': path},
    );
    return (sendResp.data['mid'] as num).toInt();
  }

  // ---- history -------------------------------------------------------

  Future<List<ChatMessage>> getHistory(
    MessageTarget target, {
    int? beforeMid,
    int limit = 30,
  }) async {
    final offset = beforeMid ?? 0;
    final String path = target.map(
      user: (t) => '/api/user/${t.uid}/history',
      group: (t) => '/api/group/${t.gid}/history',
    );

    final resp = await _dio.get(
      path,
      queryParameters: {
        'offset': offset,
        'limit': limit,
      },
    );
    final list = resp.data as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---- edit / delete / react ----------------------------------------

  Future<int> editMessage(int mid, String text) async {
    final resp = await _dio.put(
      '/api/message/$mid/edit',
      data: text,
      options: Options(contentType: 'text/plain'),
    );
    return (resp.data['mid'] as num).toInt();
  }

  Future<int> deleteMessage(int mid) async {
    final resp = await _dio.delete('/api/message/$mid');
    return (resp.data['mid'] as num).toInt();
  }

  Future<int> reactMessage(int mid, String emoji) async {
    final resp = await _dio.put(
      '/api/message/$mid/like',
      data: {'action': emoji},
    );
    return (resp.data['mid'] as num).toInt();
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
