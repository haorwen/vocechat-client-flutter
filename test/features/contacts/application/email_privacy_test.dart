import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/privacy/email_privacy_provider.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/features/contacts/application/contacts_provider.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';

import '../../../support/email_privacy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'loaded contacts, auth and persisted account clear even if refresh fails',
      () async {
    final s = Fixture();
    await s.start();
    expect(
        s.contacts.firstWhere((u) => u.uid == 7).email, 'helper@example.com');
    s.fail = true;
    await s.config(true);
    expect(s.contacts.map((u) => u.email), everyElement(isEmpty));
    expect(s.email, isNull);
    expect(s.saved.email, isNull);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs
        .getStringList('voce_accounts')!
        .map((v) => jsonDecode(v) as Map)
        .toList();
    expect(saved.first['email'], isNull);
    expect(saved.last['email'], other.email);
    await s.snapshot(extra: [
      {'uid': 42, 'name': 'Group member', 'email': null}
    ]);
    expect(s.contacts.map((u) => u.uid).toSet(), {1, 7});
    expect(s.tokens.clears, 0);
    expect((await s.remembered.readRememberedCredential())?.email,
        'login-input@example.com');
    expect((await s.remembered.readRememberedCredential())?.password,
        'remembered-password');
  });

  test('old HTTP replies cannot restore emails after hide and unhide',
      () async {
    final s = Fixture();
    await s.start();
    final usersGate = s.gate('/api/user');
    final meGate = s.gate('/api/user/me');
    final oldUsers = s.container.read(contactsProvider.notifier).refresh();
    final oldMe = s.auth.refreshUser();
    await flush();
    s.fail = true;
    await s.config(true);
    usersGate.complete();
    meGate.complete();
    await Future.wait([oldUsers, oldMe]);
    await flush();
    expect(s.contacts.map((u) => u.email), everyElement(isEmpty));
    expect(s.email, isNull);
    expect(s.saved.email, isNull);
    s.fail = false;
    await s.config(false);
    expect(
        s.contacts.firstWhere((u) => u.uid == 7).email, 'helper@example.com');
    expect(s.email, self.email);
    expect(s.saved.email, self.email);
  });

  test('late hidden responses cannot erase refreshed visible profiles',
      () async {
    final s = Fixture();
    await s.start();
    await s.config(true);
    final usersGate = s.gate('/api/user');
    final meGate = s.gate('/api/user/me');
    final oldUsers = s.container.read(contactsProvider.notifier).refresh();
    final oldMe = s.auth.refreshUser();
    await flush();
    await s.config(false);
    usersGate.complete();
    meGate.complete();
    await Future.wait([oldUsers, oldMe]);
    expect(
        s.contacts.firstWhere((u) => u.uid == 7).email, 'helper@example.com');
    expect(s.email, self.email);
    expect(s.saved.email, self.email);
  });

  test('partial config preserves hiding; reconnect restores without user logs',
      () async {
    final s = Fixture();
    await s.start();
    await s.config(true);
    for (final data in [
      {'show_user_online_status': true},
      {'hide_user_email': null}
    ]) {
      s.events.add(ChatEvent.serverConfigChanged(data: data));
      await flush();
      expect(s.container.read(emailPrivacyProvider).redact, isTrue);
    }
    // Configuration is repeated on reconnect even when no users_log exists.
    s.events.add(const ChatEvent.connectionOpened());
    await s.config(false);
    expect(s.email, self.email);
    expect(
        s.contacts.firstWhere((u) => u.uid == 7).email, 'helper@example.com');
    await s.config(true);
    // An older backend's initial config has no field; no persisted policy leaks.
    s.hidden = false;
    s.events.add(const ChatEvent.connectionOpened());
    s.events.add(const ChatEvent.serverConfigChanged(data: {}));
    await flush();
    expect(s.container.read(emailPrivacyProvider).hideUserEmail, isFalse);
    expect(s.email, self.email);
  });

  test(
      'administrator keeps access and demotion purges caches and stale requests',
      () async {
    final s = Fixture();
    await s.start(isAdmin: true);
    await s.config(true);
    expect(s.email, self.email);
    expect(
        s.contacts.firstWhere((u) => u.uid == 7).email, 'helper@example.com');
    final gate = s.gate('/api/user/me');
    final old = s.auth.refreshUser();
    await flush();
    s.admin = false;
    await s.snapshot();
    gate.complete();
    await old;
    await flush();
    expect(s.email, isNull);
    expect(s.saved.email, isNull);
    expect(s.saved.isAdmin, isFalse);
    expect(s.contacts.map((u) => u.email), everyElement(isEmpty));
    // A partial role log also triggers the existing role synchronization path.
    s.admin = true;
    await s.auth.refreshUser();
    await flush();
    expect(s.email, self.email);
    s.admin = false;
    s.events.add(ChatEvent.unknown(
        type: 'users_log',
        raw: jsonEncode({
          'logs': [
            {'uid': 1, 'action': 'update', 'is_admin': false, 'email': null}
          ]
        })));
    await flush();
    expect(s.email, isNull);
    expect(s.saved.isAdmin, isFalse);
  });

  test('first login already hidden accepts null and preserves identity',
      () async {
    final s = Fixture();
    await s.start(initiallyHidden: true);
    await s.config(true);
    expect(s.email, isNull);
    expect(s.saved.uid, 1);
    expect(s.saved.name, 'Self');
    expect(s.contacts.map((u) => u.email), everyElement(isEmpty));
    expect(s.contacts.firstWhere((u) => u.uid == 7).bot, isTrue);
  });

  test('in-flight validation cannot sign out or overwrite a switched account',
      () async {
    final s = Fixture();
    await s.start();
    await s.config(true);
    final gate = s.gate('/api/user/me');
    final oldValidation = s.auth.bootstrap();
    await flush();
    s.uid = 2;
    s.hidden = false;
    await s.auth.switchAccount(other.accountId);
    gate.complete();
    await oldValidation;
    await flush();
    expect(s.email, other.email);
    expect(s.saved.email, isNull);
    expect(s.container.read(accountStoreProvider).requireValue.currentAccountId,
        other.accountId);
  });

  for (final sameServer in [true, false]) {
    test('account switch isolates late responses (same server=$sameServer)',
        () async {
      final s = Fixture();
      await s.start();
      await s.config(true);
      final gate = s.gate('/api/user/me');
      final usersGate = s.gate('/api/user');
      final oldMe = s.auth.refreshUser();
      final oldUsers = s.container.read(contactsProvider.notifier).refresh();
      await flush();
      final target = sameServer
          ? other.copyWith(accountId: 'server::2', serverId: 'server')
          : other;
      await s.container
          .read(accountStoreProvider.notifier)
          .upsertAccount(target);
      s.uid = 2;
      s.hidden = false;
      await s.auth.switchAccount(target.accountId);
      await flush();
      gate.complete();
      usersGate.complete();
      await Future.wait([oldMe, oldUsers]);
      await flush();
      expect(s.container.read(emailPrivacyProvider).hideUserEmail, isFalse);
      expect(s.email, other.email);
      expect(
          s.container.read(accountStoreProvider).requireValue.currentAccountId,
          target.accountId);
      expect(s.saved.email, isNull);
      expect(s.contacts.any((u) => u.uid == 1), isFalse);
      expect(s.tokens.clears, 0);
    });
  }
}
