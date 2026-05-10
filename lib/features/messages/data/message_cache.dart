import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  /// In-memory write coalescing per target.
  final Map<String, Timer> _flushTimers = {};
  final Map<String, List<ChatMessage>> _pendingWrites = {};
  static const Duration _flushDelay = Duration(milliseconds: 400);

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

  Future<List<Map<String, dynamic>>?> readConversations() async {
    final raw = await _readMeta(_kConversationsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeConversations(List<Map<String, dynamic>> items) async {
    try {
      await _writeMeta(_kConversationsKey, jsonEncode(items));
    } catch (_) {
      // ignore — cache is best-effort
    }
  }

  Future<List<Map<String, dynamic>>?> readUserDirectory() async {
    final raw = await _readMeta(_kUserDirectoryKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeUserDirectory(List<Map<String, dynamic>> users) async {
    try {
      await _writeMeta(_kUserDirectoryKey, jsonEncode(users));
    } catch (_) {
      // ignore
    }
  }

  Future<List<Map<String, dynamic>>?> readGroupDirectory() async {
    final raw = await _readMeta(_kGroupDirectoryKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeGroupDirectory(List<Map<String, dynamic>> groups) async {
    try {
      await _writeMeta(_kGroupDirectoryKey, jsonEncode(groups));
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
  // sqflite uses platform-native sqlite on Android/iOS/macOS, but Linux/
  // Windows need the FFI implementation explicitly.
  if (!kIsWeb &&
      (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final dir = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}${Platform.pathSeparator}voce_messages.db';
  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
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
    },
  );
}

@Riverpod(keepAlive: true)
Future<MessageCache> messageCache(Ref ref) async {
  final db = await _openDb();
  return MessageCache._(db);
}
