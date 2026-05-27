import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../core/utils/app_log.dart';
import '../domain/message_models.dart';

part 'message_cache.g.dart';

/// SQLite-backed cache of recent messages per conversation, plus a global
/// high-water `mid` so reconnects/relaunches only fetch the delta from SSE.
///
/// Also caches lightweight directory snapshots (conversations list, users,
/// groups) under the `meta` table so cold starts can paint instantly while
/// network refresh and SSE catch up in the background.
///
/// Schema:
///   messages(target_key TEXT, mid INTEGER, from_uid INTEGER, created_at INTEGER,
///            payload TEXT, PRIMARY KEY(target_key, mid))
///   meta(key TEXT PRIMARY KEY, value TEXT)
class MessageCache {
  MessageCache._(this._db);

  final Database _db;

  static const int _maxPerConversation = 500;
  static const String _kCursorMetaKey = 'cursor';
  static const String _kConversationsKey = 'conversations';
  static const String _kUserDirectoryKey = 'user_directory';
  static const String _kGroupDirectoryKey = 'group_directory';
  static const String _kPinnedChatsKey = 'pinned_chats';

  /// In-memory write coalescing per target.
  final Map<String, Timer> _flushTimers = {};
  final Map<String, List<ChatMessage>> _pendingWrites = {};
  static const Duration _flushDelay = Duration(milliseconds: 400);

  /// Per-target counter of `appendOne` writes since the last trim. Used to
  /// amortize the trim DELETE over many inserts: trimming costs an index
  /// scan, so doing it every write would dominate SSE-burst throughput.
  final Map<String, int> _appendSinceTrim = {};
  static const int _trimEvery = 50;

  static String _keyFor(MessageTarget target) {
    return target.map(
      user: (t) => 'u-${t.uid}',
      group: (t) => 'g-${t.gid}',
    );
  }

  /// Read recent messages for [target], newest first, up to [limit].
  Future<List<ChatMessage>> read(MessageTarget target,
      {int limit = _maxPerConversation}) async {
    final key = _keyFor(target);
    final rows = await _db.query(
      'messages',
      columns: ['payload'],
      where: 'target_key = ?',
      whereArgs: [key],
      orderBy: 'mid DESC',
      limit: limit,
    );
    if (rows.isEmpty) return const [];
    final out = <ChatMessage>[];
    for (final row in rows) {
      try {
        final raw = row['payload'] as String;
        final map = jsonDecode(raw) as Map<String, dynamic>;
        out.add(ChatMessage.fromJson(map));
      } catch (_) {
        // Skip corrupt rows.
      }
    }
    return out;
  }

  /// Highest mid ever observed across any conversation.
  Future<int?> getCursor() async {
    final rows = await _db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_kCursorMetaKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final v = int.tryParse(rows.first['value'] as String);
    return (v == null || v == 0) ? null : v;
  }

  Future<void> setCursor(int mid) async {
    if (mid <= 0) return;
    final current = await getCursor() ?? 0;
    if (mid <= current) return;
    await _db.rawInsert(
      'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)',
      [_kCursorMetaKey, mid.toString()],
    );
  }

  // -------------------------------------------------------------------------
  // Generic JSON-blob meta accessors — used to persist lightweight directory
  // snapshots (conversations, users, groups) so cold starts paint instantly.
  // -------------------------------------------------------------------------

  Future<String?> _readMeta(String key) async {
    final rows = await _db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _writeMeta(String key, String value) async {
    await _db.rawInsert(
      'INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)',
      [key, value],
    );
  }

  // JSON encode/decode helpers — dispatch to a background isolate via
  // `compute` so a big conversation/directory blob never blocks the UI
  // thread on cold start or on SSE-driven writes.
  //
  // The threshold (`_kIsolateThreshold`) skips the isolate for tiny inputs:
  // spawning an isolate has a fixed cost (~1–2ms on a phone), so for very
  // small blobs it's faster to just decode inline.
  static const int _kIsolateThreshold = 2048;

  static Future<List<Map<String, dynamic>>?> _decodeListInIsolate(
      String raw) async {
    try {
      final list = raw.length < _kIsolateThreshold
          ? _decodeList(raw)
          : await compute(_decodeList, raw);
      return list;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _encodeInIsolate(
      List<Map<String, dynamic>> items) async {
    // Quick-path the empty/very-small case inline.
    if (items.length < 8) {
      return jsonEncode(items);
    }
    return compute(_encodeList, items);
  }

  Future<List<Map<String, dynamic>>?> readConversations() async {
    final raw = await _readMeta(_kConversationsKey);
    if (raw == null || raw.isEmpty) return null;
    // Decode off the UI isolate — these blobs can be 100+KB on busy
    // workspaces and parsing them at first-paint time used to block the
    // chat list from rendering on low-end phones.
    return _decodeListInIsolate(raw);
  }

  Future<void> writeConversations(List<Map<String, dynamic>> items) async {
    try {
      final encoded = await _encodeInIsolate(items);
      await _writeMeta(_kConversationsKey, encoded);
    } catch (_) {
      // ignore — cache is best-effort
    }
  }

  Future<List<Map<String, dynamic>>?> readUserDirectory() async {
    final raw = await _readMeta(_kUserDirectoryKey);
    if (raw == null || raw.isEmpty) return null;
    return _decodeListInIsolate(raw);
  }

  Future<void> writeUserDirectory(List<Map<String, dynamic>> users) async {
    try {
      final encoded = await _encodeInIsolate(users);
      await _writeMeta(_kUserDirectoryKey, encoded);
    } catch (_) {
      // ignore
    }
  }

  Future<List<Map<String, dynamic>>?> readGroupDirectory() async {
    final raw = await _readMeta(_kGroupDirectoryKey);
    if (raw == null || raw.isEmpty) return null;
    return _decodeListInIsolate(raw);
  }

  Future<void> writeGroupDirectory(List<Map<String, dynamic>> groups) async {
    try {
      final encoded = await _encodeInIsolate(groups);
      await _writeMeta(_kGroupDirectoryKey, encoded);
    } catch (_) {
      // ignore
    }
  }

  Future<List<Map<String, dynamic>>?> readPinnedChats() async {
    final raw = await _readMeta(_kPinnedChatsKey);
    if (raw == null || raw.isEmpty) return null;
    return _decodeListInIsolate(raw);
  }

  Future<void> writePinnedChats(List<Map<String, dynamic>> pins) async {
    try {
      final encoded = await _encodeInIsolate(pins);
      await _writeMeta(_kPinnedChatsKey, encoded);
    } catch (_) {
      // ignore
    }
  }

  /// Schedule a coalesced write of the given snapshot for [target].
  /// We only persist the head [_maxPerConversation] (newest first).
  void scheduleWrite(MessageTarget target, List<ChatMessage> messages) {
    final key = _keyFor(target);
    _pendingWrites[key] = messages;
    _flushTimers[key]?.cancel();
    _flushTimers[key] = Timer(_flushDelay, () => _flush(key, target));
  }

  /// Append a single message immediately (no debounce). Used by the SSE
  /// dispatcher: every incoming chat event is durably persisted as soon as
  /// it arrives, so a chat screen opened later — even cold-start, even on
  /// a target the user has never visited before — can paint the freshest
  /// messages straight from disk without waiting on a history fetch.
  ///
  /// Skips placeholder rows (negative mids) and reaction sidecars; both
  /// would corrupt the cache surface that [ChatController] reads back.
  ///
  /// The `PRIMARY KEY(target_key, mid)` constraint with `ConflictAlgorithm.
  /// replace` makes this an UPSERT — duplicate SSE echoes and `after_mid`
  /// replay are absorbed without producing extra rows.
  Future<void> appendOne(MessageTarget target, ChatMessage msg) async {
    if (msg.mid <= 0) return;
    if (msg.detail is ReactionMessageDetail) return;
    final key = _keyFor(target);
    try {
      await _db.insert(
        'messages',
        {
          'target_key': key,
          'mid': msg.mid,
          'from_uid': msg.fromUid,
          'created_at': msg.createdAt,
          'payload': jsonEncode(msg.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Amortized trim: only run the DELETE every [_trimEvery] inserts per
      // target. A single target can otherwise grow unbounded under SSE
      // burst load.
      final n = (_appendSinceTrim[key] ?? 0) + 1;
      if (n >= _trimEvery) {
        _appendSinceTrim[key] = 0;
        await _trimTarget(key);
      } else {
        _appendSinceTrim[key] = n;
      }
    } catch (e) {
      AppLog.w(LogTag.chat, () => '⚠️ cache.appendOne failed: $e');
    }
  }

  /// Delete rows for [key] beyond the most-recent [_maxPerConversation] mids.
  /// Idempotent; cheap as a no-op when already trimmed.
  Future<void> _trimTarget(String key) async {
    try {
      await _db.rawDelete(
        '''
        DELETE FROM messages
        WHERE target_key = ?
          AND mid NOT IN (
            SELECT mid FROM messages
            WHERE target_key = ?
            ORDER BY mid DESC
            LIMIT ?
          )
        ''',
        [key, key, _maxPerConversation],
      );
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _flush(String key, MessageTarget target) async {
    _flushTimers.remove(key);
    final snapshot = _pendingWrites.remove(key);
    if (snapshot == null) return;

    final trimmed = snapshot.length > _maxPerConversation
        ? snapshot.sublist(0, _maxPerConversation)
        : snapshot;

    // Replace-then-trim approach: upsert all, then delete anything outside
    // the most recent _maxPerConversation by mid.
    final batch = _db.batch();
    for (final m in trimmed) {
      batch.insert(
        'messages',
        {
          'target_key': key,
          'mid': m.mid,
          'from_uid': m.fromUid,
          'created_at': m.createdAt,
          'payload': jsonEncode(m.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);

    // Trim oldest beyond the cap (only when we have stable real mids).
    await _db.rawDelete(
      '''
      DELETE FROM messages
      WHERE target_key = ?
        AND mid NOT IN (
          SELECT mid FROM messages
          WHERE target_key = ?
          ORDER BY mid DESC
          LIMIT ?
        )
      ''',
      [key, key, _maxPerConversation],
    );
  }

  /// Best-effort flush of every pending write — call on app pause.
  Future<void> flushAll() async {
    final keys = _flushTimers.keys.toList();
    for (final k in keys) {
      _flushTimers[k]?.cancel();
    }
    _flushTimers.clear();
    final snapshots = Map.of(_pendingWrites);
    _pendingWrites.clear();

    for (final entry in snapshots.entries) {
      final key = entry.key;
      // Reverse-engineer target from key string.
      final target = _parseKey(key);
      if (target == null) continue;
      _pendingWrites[key] = entry.value;
      await _flush(key, target);
    }
  }

  static MessageTarget? _parseKey(String key) {
    if (key.startsWith('u-')) {
      final uid = int.tryParse(key.substring(2));
      if (uid != null) return MessageTarget.user(uid: uid);
    } else if (key.startsWith('g-')) {
      final gid = int.tryParse(key.substring(2));
      if (gid != null) return MessageTarget.group(gid: gid);
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Database initialization
// ---------------------------------------------------------------------------

Future<Database> _openDb() async {
  bootLog('10 _openDb: enter');
  // sqflite uses platform-native sqlite on Android/iOS/macOS, but Linux/
  // Windows need the FFI implementation explicitly.
  if (!kIsWeb &&
      (Platform.isLinux || Platform.isWindows)) {
    bootLog('11 _openDb: sqfliteFfiInit');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  bootLog('12 _openDb: getApplicationDocumentsDirectory');
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}${Platform.pathSeparator}voce_messages.db';
  bootLog('13 _openDb: openDatabase path=$dbPath');
  final db = await openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      bootLog('14 _openDb.onCreate: creating tables');
      await db.execute('''
        CREATE TABLE messages (
          target_key TEXT NOT NULL,
          mid        INTEGER NOT NULL,
          from_uid   INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          payload    TEXT NOT NULL,
          PRIMARY KEY(target_key, mid)
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_messages_target_mid
        ON messages(target_key, mid DESC)
      ''');
      await db.execute('''
        CREATE TABLE meta (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      bootLog('15 _openDb.onCreate: tables created');
    },
  );
  bootLog('16 _openDb: openDatabase done');
  return db;
}

@Riverpod(keepAlive: true)
Future<MessageCache> messageCache(Ref ref) async {
  bootLog('9 messageCacheProvider.build: enter');
  final db = await _openDb();
  bootLog('17 messageCacheProvider.build: db ready');
  return MessageCache._(db);
}

// ---------------------------------------------------------------------------
// Top-level isolate entry points (must be top-level for `compute`).
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _decodeList(String raw) {
  final list = jsonDecode(raw) as List<dynamic>;
  return list.cast<Map<String, dynamic>>();
}

String _encodeList(List<Map<String, dynamic>> items) {
  return jsonEncode(items);
}
