import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/account_store.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/voce_dialog.dart';
import '../application/auth_controller.dart';

/// Bottom sheet listing every locally-saved [AccountConfig], mirroring the
/// old client's `ChatsDrawer` account switcher: tap to switch (no re-login
/// needed while the stored session is still valid), a trailing action to
/// remove a saved account, and an "Add account" row that signs in a second
/// identity on the current server without disturbing the active session.
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends ConsumerStatefulWidget {
  const _AccountSwitcherSheet();

  @override
  ConsumerState<_AccountSwitcherSheet> createState() =>
      _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<_AccountSwitcherSheet> {
  String? _switchingId;

  Future<void> _switchTo(AccountConfig account, String? currentAccountId) async {
    if (account.accountId == currentAccountId || _switchingId != null) return;
    final l = AppL10n.of(context);
    setState(() => _switchingId = account.accountId);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .switchAccount(account.accountId);
      final authState = ref.read(authControllerProvider).valueOrNull;
      if (authState is! AuthStateAuthenticated) {
        // Stored session is no longer valid — surface it and let the app's
        // normal auth-redirect send the user to /login for this account.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.accountSwitcherSwitchFailed)),
          );
        }
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _switchingId = null);
    }
  }

  Future<void> _removeAccount(AccountConfig account) async {
    final l = AppL10n.of(context);
    final ok = await showVoceConfirm(
      context: context,
      title: l.accountSwitcherRemoveConfirmTitle,
      body: l.accountSwitcherRemoveConfirmBody,
      confirmLabel: l.accountSwitcherRemove,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).removeAccount(account.accountId);
  }

  void _addAccount() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _AddAccountScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final accountState = ref.watch(accountStoreProvider).valueOrNull;
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final accounts = accountState?.accounts ?? const <AccountConfig>[];
    final currentAccountId = accountState?.currentAccountId;

    String serverNameFor(String serverId) {
      final server =
          serverState?.servers.where((s) => s.id == serverId).firstOrNull;
      return server?.name ?? server?.baseUrl ?? serverId;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                l.accountSwitcherTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.gray800,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final account = accounts[i];
                  final isCurrent = account.accountId == currentAccountId;
                  final isSwitching = _switchingId == account.accountId;
                  final serverBaseUrl = serverState?.servers
                      .where((s) => s.id == account.serverId)
                      .firstOrNull
                      ?.baseUrl;
                  final avatarUrl =
                      (account.avatarUpdatedAt ?? 0) > 0 &&
                              serverBaseUrl != null &&
                              serverBaseUrl.isNotEmpty
                          ? '$serverBaseUrl/api/resource/avatar?uid=${account.uid}&t=${account.avatarUpdatedAt}'
                          : null;
                  return ListTile(
                    onTap: _switchingId == null
                        ? () => _switchTo(account, currentAccountId)
                        : null,
                    leading: VoceAvatar(
                      name: account.name,
                      imageUrl: avatarUrl,
                      size: 40,
                    ),
                    title: Text(
                      safeText(account.name),
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      safeText(serverNameFor(account.serverId)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isSwitching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isCurrent
                            ? Icon(Icons.check_circle,
                                color: AppTokens.primary500)
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                tooltip: l.accountSwitcherRemove,
                                onPressed: () => _removeAccount(account),
                              ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTokens.gray200,
                child: Icon(Icons.add, color: AppTokens.gray700),
              ),
              title: Text(l.accountSwitcherAddAccount),
              onTap: _addAccount,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AddAccountScreen — sign in a second identity on the current server.
// ---------------------------------------------------------------------------
//
// Pushed imperatively (not through GoRouter), so the router's "authenticated
// → block /login" redirect never sees it: the currently active account stays
// signed in and fully functional underneath this modal until the new login
// succeeds, at which point `AuthController.login()` makes the new account the
// active one and this screen pops itself.

class _AddAccountScreen extends ConsumerStatefulWidget {
  const _AddAccountScreen();

  @override
  ConsumerState<_AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<_AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
      final state = ref.read(authControllerProvider).valueOrNull;
      if (state is AuthStateAuthenticated && mounted) {
        Navigator.of(context).pop();
      } else {
        final err = ref.read(authControllerProvider).error;
        setState(() => _error =
            err != null ? _loginErrorMessage(err) : AppL10n.of(context).errorRequestFailed);
      }
    } catch (e) {
      setState(() => _error = _loginErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _loginErrorMessage(Object error) {
    if (error is DioException && error.error is ApiException) {
      final status = (error.error as ApiException).status;
      final l = AppL10n.of(context);
      return switch (status) {
        401 || 404 => l.loginErrorInvalidCredentials,
        423 => l.loginErrorAccountFrozen,
        410 => l.loginErrorNotInvited,
        403 => l.loginErrorMethodNotSupported,
        0 => l.loginErrorCannotReachServer,
        _ => (error.error as ApiException).message,
      };
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final currentServer = serverState?.servers
        .where((s) => s.id == serverState.currentServerId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.accountSwitcherAddAccount),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentServer != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      safeText(currentServer.name),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTokens.gray500),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      safeText(_error!),
                      style: TextStyle(color: AppTokens.error),
                    ),
                  ),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: l.loginEmail,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.loginEmailRequired;
                    }
                    final emailRegex =
                        RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return l.loginEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: l.loginPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l.loginPasswordRequired;
                    }
                    if (v.length < 6) {
                      return l.loginPasswordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l.loginSignIn),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
