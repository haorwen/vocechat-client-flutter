import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Insert a new account or update an existing one (matched by [accountId]).
  Future<void> upsertAccount(AccountConfig account) async {
    final current = await future;
    final idx =
        current.accounts.indexWhere((a) => a.accountId == account.accountId);
    final updated = [...current.accounts];
    if (idx >= 0) {
      updated[idx] = account;
    } else {
      updated.add(account);
    }
    await _persist(updated, current.currentAccountId);
    state = AsyncData(current.copyWith(accounts: updated));
  }

  Future<void> removeAccount(String accountId) async {
    final current = await future;
    final updated =
        current.accounts.where((a) => a.accountId != accountId).toList();
    final newCurrentId =
        current.currentAccountId == accountId ? null : current.currentAccountId;
    await _persist(updated, newCurrentId);
    state = AsyncData(
        current.copyWith(accounts: updated, currentAccountId: newCurrentId));
  }

  Future<void> selectAccount(String accountId) async {
    final current = await future;
    await _persist(current.accounts, accountId);
    state = AsyncData(current.copyWith(currentAccountId: accountId));
  }

  /// Unset the current account pointer without removing its saved entry —
  /// used by logout(), which keeps the account in the switcher list for a
  /// quick re-login.
  Future<void> clearCurrentAccount() async {
    final current = await future;
    await _persist(current.accounts, null);
    state = AsyncData(current.copyWith(currentAccountId: null));
  }

  List<AccountConfig> get list => state.valueOrNull?.accounts ?? [];

  Future<void> _persist(
      List<AccountConfig> accounts, String? currentId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_kAccountsKey, raw);
    if (currentId != null) {
      await prefs.setString(_kCurrentAccountKey, currentId);
    } else {
      await prefs.remove(_kCurrentAccountKey);
    }
  }
}
