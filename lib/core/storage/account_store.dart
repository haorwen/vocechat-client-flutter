import 'dart:async';
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preference_write.dart';

part 'account_store.freezed.dart';
part 'account_store.g.dart';

// ---------------------------------------------------------------------------
// AccountConfig — one logged-in identity: a (serverId, uid) pair.
// ---------------------------------------------------------------------------
//
// The same server can host multiple locally-saved accounts (e.g. a work and
// a personal user on the same VoceChat instance). [ServerConfig] alone can't
// tell them apart — it identifies a *server*, not a *user* on that server.
// [accountId] is the composite key (`$serverId::$uid`) that does; it's what
// [SecureTokenStore] and [MessageCache] key their per-identity data on.

@freezed
class AccountConfig with _$AccountConfig {
  const factory AccountConfig({
    required String accountId,
    required String serverId,
    required int uid,
    required String name,
    String? email,
    @Default(false) bool isAdmin,
    int? avatarUpdatedAt,
  }) = _AccountConfig;

  factory AccountConfig.fromJson(Map<String, dynamic> json) =>
      _$AccountConfigFromJson(json);
}

// ---------------------------------------------------------------------------
// AccountState
// ---------------------------------------------------------------------------

@freezed
class AccountState with _$AccountState {
  const factory AccountState({
    @Default([]) List<AccountConfig> accounts,
    String? currentAccountId,
  }) = _AccountState;
}

// ---------------------------------------------------------------------------
// AccountStoreNotifier
// ---------------------------------------------------------------------------

const _kAccountsKey = 'voce_accounts';
const _kCurrentAccountKey = 'voce_current_account';

@riverpod
class AccountStore extends _$AccountStore {
  @override
  Future<AccountState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kAccountsKey) ?? [];
    final accounts = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return AccountConfig.fromJson(map);
    }).toList();
    final currentId = prefs.getString(_kCurrentAccountKey);
    return AccountState(accounts: accounts, currentAccountId: currentId);
  }

  static String makeId(String serverId, int uid) => '$serverId::$uid';

  Future<void> _writes = Future.value();
  final _hiddenEmails = <String>{};

  AccountState _protectEmails(AccountState value) => value.copyWith(accounts: [
        for (final account in value.accounts)
          _hiddenEmails.contains(account.accountId)
              ? account.copyWith(email: null)
              : account,
      ]);

  /// Redact memory synchronously; every queued write also observes this
  /// constraint. Login credentials live in SecureTokenStore and are untouched.
  Future<void> setDisplayEmailHidden(String accountId, bool hidden) {
    if (!hidden) {
      _hiddenEmails.remove(accountId);
      return Future.value();
    }
    _hiddenEmails.add(accountId);
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(_protectEmails(current));
    return _update((current) => current);
  }

  // Serialize read/modify/write operations: a profile refresh must not restore
  // an older accounts list after a privacy purge or account selection.
  Future<void> _update(AccountState Function(AccountState) change) {
    final result = _writes.then((_) async {
      await future;
      final next = _protectEmails(change(state.requireValue));
      await _persist(next.accounts, next.currentAccountId);
      state = AsyncData(_protectEmails(next));
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Insert a new account or update an existing one (matched by accountId).
  Future<void> upsertAccount(AccountConfig account) => _update((current) {
        final updated = [...current.accounts];
        final idx = updated.indexWhere((a) => a.accountId == account.accountId);
        if (idx >= 0) {
          updated[idx] = account;
        } else {
          updated.add(account);
        }
        return current.copyWith(accounts: updated);
      });

  /// Evaluate the guard/transform at commit time, after earlier disk writes.
  /// This cannot recreate an account removed while a request was in flight.
  Future<void> updateAccount(
    String accountId,
    AccountConfig Function(AccountConfig) update,
  ) =>
      _update((current) => current.copyWith(accounts: [
            for (final account in current.accounts)
              account.accountId == accountId ? update(account) : account,
          ]));

  Future<void> removeAccount(String accountId) =>
      _update((current) => current.copyWith(
            accounts: current.accounts
                .where((a) => a.accountId != accountId)
                .toList(),
            currentAccountId: current.currentAccountId == accountId
                ? null
                : current.currentAccountId,
          ));

  Future<void> selectAccount(String accountId) =>
      _update((current) => current.copyWith(currentAccountId: accountId));

  /// Keep the saved display profile for the account switcher on logout.
  Future<void> clearCurrentAccount() =>
      _update((current) => current.copyWith(currentAccountId: null));

  Future<List<AccountConfig>> removeAccountsForServer(String serverId) async {
    var removed = <AccountConfig>[];
    await _update((current) {
      removed = current.accounts.where((a) => a.serverId == serverId).toList();
      final ids = removed.map((a) => a.accountId).toSet();
      return current.copyWith(
        accounts:
            current.accounts.where((a) => a.serverId != serverId).toList(),
        currentAccountId: ids.contains(current.currentAccountId)
            ? null
            : current.currentAccountId,
      );
    });
    return removed;
  }

  List<AccountConfig> get list => state.valueOrNull?.accounts ?? [];

  Future<void> _persist(List<AccountConfig> accounts, String? currentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await requirePreferenceWrite(
        prefs, prefs.setStringList(_kAccountsKey, raw));
    if (currentId != null) {
      await requirePreferenceWrite(
          prefs, prefs.setString(_kCurrentAccountKey, currentId));
    } else {
      await requirePreferenceWrite(prefs, prefs.remove(_kCurrentAccountKey));
    }
  }
}
