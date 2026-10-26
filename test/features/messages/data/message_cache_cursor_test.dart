import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

const _target = MessageTarget.group(gid: 42);
ChatMessage _message(int mid) => ChatMessage(
      mid: mid,
      fromUid: 2,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      target: _target,
      detail: const MessageDetail.normal(
          contentType: 'text/plain', content: 'incoming'),
    );

void main() {
  sqfliteFfiInit();
  late Database database;
  late MessageCache cache;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await database.execute('''
      CREATE TABLE messages (
        target_key TEXT NOT NULL, mid INTEGER NOT NULL,
        from_uid INTEGER NOT NULL, created_at INTEGER NOT NULL,
        payload TEXT NOT NULL, PRIMARY KEY(target_key, mid)
      )
    ''');
    await database.execute(
        'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    cache = MessageCache.forTesting(database);
  });
  tearDown(() => database.close());

  test('legacy send-driven cursors are ignored on upgrade', () async {
    await database.insert('meta', {'key': 'cursor', 'value': '900'});
    expect(await cache.getCursor(), isNull);
    await cache.appendOne(_target, _message(100), advanceCursor: true);
    expect(await cache.getCursor(), 100);
  });

  test('cursor updates are monotonic under concurrent writes', () async {
    await Future.wait([
      for (final mid in [300, 100, 250, 200]) cache.setCursor(mid)
    ]);
    expect(await cache.getCursor(), 300);
  });

  test('a failed message insert cannot advance the receive cursor', () async {
    await cache.appendOne(_target, _message(100), advanceCursor: true);
    await database.execute('''
      CREATE TRIGGER reject_message BEFORE INSERT ON messages
      WHEN NEW.mid = 101 BEGIN SELECT RAISE(ABORT, 'disk write failed'); END
    ''');
    await expectLater(
        cache.appendOne(_target, _message(101), advanceCursor: true),
        throwsA(isA<DatabaseException>()));
    expect(await cache.getCursor(), 100);
    expect((await cache.read(_target)).map((m) => m.mid), [100]);
    // Later rows can be retained without acknowledging the failed gap.
    await cache.appendOne(_target, _message(102));
    expect(await cache.getCursor(), 100);
  });
}
