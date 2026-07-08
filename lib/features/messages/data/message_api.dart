import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../domain/message_models.dart';

part 'message_api.g.dart';

/// Result of [MessageApi.uploadBytesAndSend]: the server message id plus the
/// stored file path, so the caller can upgrade its optimistic row to the
/// real `{"path": ...}` content without waiting for the SSE echo.
class SendFileResult {
  const SendFileResult({required this.mid, required this.path});

  final int mid;
  final String path;
}

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

  /// [mentions] (group chats only, per web's `enableMention` gating) is sent
  /// as `properties.mentions` via the same `X-Properties` base64-JSON header
  /// mechanism already used by `uploadBytesAndSend` — confirmed accepted on
  /// this endpoint server-side (group.rs:1012 / user.rs:1401 both read
  /// X-Properties on /send, not just file uploads).
  Future<int> sendText(
    MessageTarget target,
    String text, {
    List<int>? mentions,
  }) async {
    final resp = await _dio.post(
      _sendPath(target),
      data: text,
      options: Options(
        contentType: 'text/plain',
        headers: _propertiesHeader(mentions),
      ),
    );
    // Server returns raw i64 as JSON body (e.g. 602475), not {"mid": 602475}.
    return (resp.data as num).toInt();
  }

  Future<int> sendMarkdown(
    MessageTarget target,
    String md, {
    List<int>? mentions,
  }) async {
    final resp = await _dio.post(
      _sendPath(target),
      data: md,
      options: Options(
        contentType: 'text/markdown',
        headers: _propertiesHeader(mentions),
      ),
    );
    // Server returns raw i64 as JSON body.
    return (resp.data as num).toInt();
  }

  /// Builds the `X-Properties` header map carrying `{"mentions": [...]}` when
  /// [mentions] is non-empty, or null (no header) otherwise.
  static Map<String, dynamic>? _propertiesHeader(List<int>? mentions) {
    if (mentions == null || mentions.isEmpty) return null;
    return {
      'X-Properties': base64Encode(utf8.encode(jsonEncode({'mentions': mentions}))),
    };
  }

  /// Uploads [file] in a single chunk then sends a file message.
  Future<SendFileResult> uploadFileAndSend(
    MessageTarget target,
    File file, {
    int? width,
    int? height,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytesAndSend(
      target,
      bytes: bytes,
      filename: file.uri.pathSegments.last,
      width: width,
      height: height,
    );
  }

  /// Uploads raw [bytes] (e.g. from the clipboard, which has no file path) in a
  /// single chunk, then sends a `vocechat/file` message referencing the stored
  /// path.
  ///
  /// Flow mirrors the web reference: prepare → upload(single chunk) → send. The
  /// `X-Properties` header carries name/content_type/size/width/height so the
  /// server-side property map (and the SSE echo) is complete and images render
  /// at the right aspect ratio immediately.
  Future<SendFileResult> uploadBytesAndSend(
    MessageTarget target, {
    required Uint8List bytes,
    required String filename,
    String? contentType,
    int? width,
    int? height,
    int? localId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final resolvedType =
        contentType ?? _inferContentType(filename, bytes: bytes);

    // Step 1: prepare
    // Server contract: POST /api/resource/file/prepare returns the file_id as a
    // BARE JSON string (Json<String>), e.g. "550e8400-...". It is NOT an object
    // like {"file_id": "..."}. Read it directly; tolerate a map shape defensively.
    final prepareResp = await _dio.post(
      '/api/resource/file/prepare',
      data: {'content_type': resolvedType, 'filename': filename},
    );
    final prepareData = prepareResp.data;
    final fileId = prepareData is String
        ? prepareData
        : (prepareData is Map ? prepareData['file_id'] as String : null);
    if (fileId == null || fileId.isEmpty) {
      throw StateError('prepare upload returned no file_id: $prepareData');
    }

    // Step 2: upload chunk (single-chunk upload)
    // Server endpoint: POST /api/resource/file/upload (multipart)
    // Returns Json<Option<UploadFileResponse>> { path, size, hash,
    // image_properties } — null until the last chunk. We send the whole file as
    // one chunk with chunk_is_last="true" (string, matching the web client).
    final formData = FormData.fromMap({
      'file_id': fileId,
      'chunk_data': MultipartFile.fromBytes(bytes, filename: filename),
      'chunk_is_last': 'true',
    });
    final uploadResp = await _dio.post(
      '/api/resource/file/upload',
      data: formData,
      onSendProgress: onSendProgress,
    );
    // On the last chunk the body is the UploadFileResponse object; path is at
    // top level. Guard against a null/empty body (would mean the server didn't
    // finalize the upload).
    final uploadData = uploadResp.data;
    if (uploadData is! Map) {
      throw StateError('upload did not return a file path: $uploadData');
    }
    final path = uploadData['path'] as String;
    // Prefer the server-detected image dimensions when present.
    final imgProps = uploadData['image_properties'] as Map?;
    final outW = (imgProps?['width'] as num?)?.toInt() ?? width;
    final outH = (imgProps?['height'] as num?)?.toInt() ?? height;

    // Step 3: send file message — content_type must be vocechat/file. The
    // server parses the body as JSON (Json<FileInfo>), so the body must be a
    // JSON string `{"path":"..."}` — mirror the web client's
    // `JSON.stringify(content)`. Passing a raw Map with a non-JSON content type
    // would make Dio's default transformer emit Dart map toString (invalid
    // JSON) and the server would reject it. X-Properties carries metadata
    // (base64 JSON). Server returns raw i64 mid.
    final properties = <String, dynamic>{
      'name': filename,
      'content_type': resolvedType,
      'size': bytes.length,
      if (outW != null) 'width': outW,
      if (outH != null) 'height': outH,
      // Echoed back by the server via X-Properties so the SSE echo carries our
      // sender-generated dedup key — _findOptimisticMatch matches on this to
      // upgrade the optimistic row in place instead of duplicating it.
      if (localId != null) 'local_id': localId,
    };
    final sendResp = await _dio.post(
      _sendPath(target),
      data: jsonEncode({'path': path}),
      options: Options(
        contentType: 'vocechat/file',
        headers: {
          'X-Properties': base64Encode(utf8.encode(jsonEncode(properties))),
        },
      ),
    );
    return SendFileResult(mid: (sendResp.data as num).toInt(), path: path);
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

  Future<int> editMessageMarkdown(int mid, String md) async {
    final resp = await _dio.put(
      '/api/message/$mid/edit',
      data: md,
      options: Options(contentType: 'text/markdown'),
    );
    return (resp.data as num).toInt();
  }

  Future<int> deleteMessage(int mid) async {
    final resp = await _dio.delete('/api/message/$mid');
    // Server returns raw i64 (the new reaction mid).
    return (resp.data as num).toInt();
  }

  /// Post a reply to the message identified by [targetMid]. Server returns the
  /// new reply message's mid.
  Future<int> replyMessage(
    int targetMid,
    String text, {
    bool markdown = false,
    List<int>? mentions,
  }) async {
    final resp = await _dio.post(
      '/api/message/$targetMid/reply',
      data: text,
      options: Options(
        contentType: markdown ? 'text/markdown' : 'text/plain',
        headers: _propertiesHeader(mentions),
      ),
    );
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

  // ---- forward (archive) ----------------------------------------------

  /// Bundles [mids] into a new server-side archive. Server contract:
  /// POST /api/resource/archive, body {"mid_list": [...]}, response is a bare
  /// JSON string path like "2026/7/8/<uuid>" (Json<String>, not wrapped).
  /// Mirrors web's `createArchive` (src/app/services/message.ts).
  Future<String> createArchive(List<int> mids) async {
    final resp = await _dio.post(
      '/api/resource/archive',
      data: {'mid_list': mids},
    );
    final data = resp.data;
    final path = data is String ? data : (data is Map ? data['id'] as String? : null);
    if (path == null || path.isEmpty) {
      throw StateError('createArchive returned no path: $data');
    }
    return path;
  }

  /// Sends a forwarded-message reference to [target]. Server contract: the
  /// archive id is sent as the raw body string (not JSON-wrapped) with
  /// content-type `vocechat/archive` — mirrors web's
  /// `sendUserMsg({type:"archive", id, content: archive_id})` where `content`
  /// is used directly as the request body.
  Future<int> sendArchive(MessageTarget target, String archiveId) async {
    final resp = await _dio.post(
      _sendPath(target),
      data: archiveId,
      options: Options(contentType: 'vocechat/archive'),
    );
    return (resp.data as num).toInt();
  }

  /// Fetches the archive index for a forwarded-message card. Server contract:
  /// GET /api/resource/archive?file_path=<path> -> Json<Archive>.
  Future<Archive> getArchive(String filePath) async {
    final resp = await _dio.get(
      '/api/resource/archive',
      queryParameters: {'file_path': filePath},
    );
    return Archive.fromJson(resp.data as Map<String, dynamic>);
  }

  // ---- read index ----------------------------------------------------

  /// Report how far the user has read in one or more conversations.
  /// Server contract: POST /api/user/read-index with
  /// `{"users":[{"uid","mid"}], "groups":[{"gid","mid"}]}`. The server only
  /// moves a marker forward, so re-sending a stale mid is harmless.
  Future<void> readMessage({
    List<({int uid, int mid})>? users,
    List<({int gid, int mid})>? groups,
  }) async {
    final body = <String, dynamic>{
      if (users != null && users.isNotEmpty)
        'users': [
          for (final u in users) {'uid': u.uid, 'mid': u.mid},
        ],
      if (groups != null && groups.isNotEmpty)
        'groups': [
          for (final g in groups) {'gid': g.gid, 'mid': g.mid},
        ],
    };
    if (body.isEmpty) return;
    await _dio.post('/api/user/read-index', data: body);
  }

  // ---- burn-after-read (auto-delete) ---------------------------------

  /// Update the auto-delete ("burn after reading") setting for one or more
  /// DM peers / channels. Server contract: POST /api/user/burn-after-reading
  /// with `{"users":[{"uid","expires_in"}], "groups":[{"gid","expires_in"}]}`.
  /// `expiresIn` is seconds; `0` disables (server deletes the row), `>0`
  /// enables/updates. Verified against vocechat-server's
  /// `update_burn_after_reading` handler (api/user.rs) and web's
  /// `useUpdateAutoDeleteMsgMutation` (app/services/user.ts).
  Future<void> updateBurnAfterReading({
    List<({int uid, int expiresIn})>? users,
    List<({int gid, int expiresIn})>? groups,
  }) async {
    final body = <String, dynamic>{
      if (users != null && users.isNotEmpty)
        'users': [
          for (final u in users) {'uid': u.uid, 'expires_in': u.expiresIn},
        ],
      if (groups != null && groups.isNotEmpty)
        'groups': [
          for (final g in groups) {'gid': g.gid, 'expires_in': g.expiresIn},
        ],
    };
    if (body.isEmpty) return;
    await _dio.post('/api/user/burn-after-reading', data: body);
  }

  // ---- util ----------------------------------------------------------

  /// Public wrapper so callers (controller / UI staging) can resolve a MIME
  /// type for a picked/pasted file before constructing the optimistic message.
  static String inferContentType(String filename, {Uint8List? bytes}) =>
      _inferContentType(filename, bytes: bytes);

  static String _inferContentType(String filename, {Uint8List? bytes}) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
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
    final byExt = map[ext];
    if (byExt != null) return byExt;

    // Clipboard images often arrive with no extension — sniff magic numbers.
    final sniffed = bytes == null ? null : _sniffImageType(bytes);
    return sniffed ?? 'application/octet-stream';
  }

  /// Detect common image types from their leading bytes. Returns null when the
  /// bytes don't match a known signature.
  static String? _sniffImageType(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (b.length >= 6 &&
        b[0] == 0x47 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x38) {
      return 'image/gif';
    }
    // WEBP: "RIFF"...."WEBP"
    if (b.length >= 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

@riverpod
MessageApi messageApi(Ref ref) {
  return MessageApi(ref.watch(dioProvider));
}
