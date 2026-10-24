import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/account_store.dart';
import '../storage/server_store.dart';

part 'email_privacy_provider.g.dart';

/// A request may publish profile data only in the scope and revision in which
/// it started. Neither persisted roles nor a previous session grant access.
class EmailPrivacyState {
  EmailPrivacyState({
    required this.accountId,
    required this.serverId,
    this.hideUserEmail = false,
    this.verifiedAdmin = false,
    Object? session,
  }) : session = session ?? Object();

  final String? accountId;
  final String? serverId;
  final bool hideUserEmail;
  final bool verifiedAdmin;
  final Object session;
  final Object revision = Object();

  bool get redact => hideUserEmail && !verifiedAdmin;

  EmailPrivacyState update({bool? hideUserEmail, bool? verifiedAdmin}) =>
      EmailPrivacyState(
        accountId: accountId,
        serverId: serverId,
        session: session,
        hideUserEmail: hideUserEmail ?? this.hideUserEmail,
        verifiedAdmin: verifiedAdmin ?? this.verifiedAdmin,
      );
}

@Riverpod(keepAlive: true)
class EmailPrivacy extends _$EmailPrivacy {
  @override
  EmailPrivacyState build() => EmailPrivacyState(
        accountId: ref.watch(accountStoreProvider.select(
          (value) => value.valueOrNull?.currentAccountId,
        )),
        serverId: ref.watch(serverStoreProvider.select(
          (value) => value.valueOrNull?.currentServerId,
        )),
      );

  /// Only an initial configuration from an old server defaults to false.
  /// Missing/null values in live partial updates preserve the current policy.
  bool applyConfig(Map<String, dynamic> config, {bool initial = false}) {
    final flag = config['hide_user_email'];
    if (flag is! bool && !initial) return false;
    state = state.update(
      hideUserEmail: flag is bool ? flag : false,
      // Recheck privilege after a policy change/reconnect. A cached admin
      // role must not override a freshly redacted server response.
      verifiedAdmin: false,
    );
    return true;
  }

  void verifyRole(bool isAdmin) {
    if (state.verifiedAdmin != isAdmin) {
      state = state.update(verifiedAdmin: isAdmin);
    }
  }
}
