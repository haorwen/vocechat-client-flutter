import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/utils/safe_text.dart';
import '../../../features/messages/application/message_dispatcher.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredential();
  }

  Future<void> _loadRememberedCredential() async {
    final serverState = await ref.read(serverStoreProvider.future);
    final serverId = serverState.currentServerId;
    if (serverId == null) return;
    final remembered =
        await ref.read(secureTokenStoreProvider(serverId)).readRememberedCredential();
    if (remembered == null || !mounted) return;
    setState(() {
      _emailCtrl.text = remembered.email;
      _passwordCtrl.text = remembered.password;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _serverName {
    final state = ref.watch(serverStoreProvider).valueOrNull;
    if (state == null) return '';
    final current = state.servers
        .where((s) => s.id == state.currentServerId)
        .firstOrNull;
    return current?.name ?? current?.baseUrl ?? '';
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Ignore Enter-key submits while a login is already in flight.
    if (ref.read(authControllerProvider).isLoading) return;

    // Navigation + error surfacing happen in the ref.listen below — doing it
    // here as well produced duplicate snackbars / double context.go.
    await ref.read(authControllerProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          rememberMe: _rememberMe,
        );
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL10n.of(context).featureUnavailable),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppL10n.of(context);

    // Listen for auth state changes to navigate
    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        data: (state) {
          if (state is AuthStateAuthenticated && mounted) {
            context.go('/home');
          }
        },
        error: (e, _) {
          if (!mounted) return;
          final msg = _loginErrorMessage(context, e);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(safeText(msg))));
        },
      );
    });

    // Surface any pending kick reason from the SSE stream. Mirrors the web
    // reference: a `kick` event has just logged us out and we want the user
    // to know why before they re-enter credentials.
    final kickReason = ref.watch(kickReasonProvider);
    if (kickReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final l = AppL10n.of(context);
        final text = switch (kickReason) {
          'login_from_other_device' => l.authKickedFromOtherDevice,
          'delete_user' => l.authAccountDeleted,
          _ => l.authSessionEnded,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeText(text))));
        ref.read(kickReasonProvider.notifier).clear();
      });
    }

    final isLoading =
        ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Logo
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      size: 38,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l.loginWelcomeBack,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  safeText(_serverName),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: l.loginEmail,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
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
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? l.tooltipShowPassword
                          : l.tooltipHidePassword,
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _signIn(),
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          l.loginRememberMe,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showUnavailable,
                      child: Text(l.loginForgotPassword),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: l.loginSignIn,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _signIn,
                ),
                const SizedBox(height: 16),
                _TertiaryRow(
                  actions: [
                    _TertiaryAction(
                      icon: Icons.auto_awesome_outlined,
                      label: l.loginMagicLink,
                      onTap: _showUnavailable,
                    ),
                    _TertiaryAction(
                      icon: Icons.fingerprint,
                      label: l.loginPasskey,
                      onTap: _showUnavailable,
                    ),
                    _TertiaryAction(
                      icon: Icons.dns_outlined,
                      label: l.loginSwitchServer,
                      onTap: () => context.go('/server-picker'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.loginNoAccount,
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(l.loginSignUp),
                    ),
                  ],
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a login failure to a specific, localized reason instead of a raw
/// exception string. Status codes follow the server's `LoginApiResponse`
/// (`vocechat-server/src/api/token.rs`); status 0 is what `dio_client.dart`
/// assigns to network/timeout/TLS failures that never reached the server.
String _loginErrorMessage(BuildContext context, Object error) {
  final l = AppL10n.of(context);
  if (error is DioException && error.error is ApiException) {
    final status = (error.error as ApiException).status;
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

class _TertiaryAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TertiaryAction(
      {required this.icon, required this.label, required this.onTap});
}

class _TertiaryRow extends StatelessWidget {
  final List<_TertiaryAction> actions;
  const _TertiaryRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: actions
          .map((a) => TextButton.icon(
                onPressed: a.onTap,
                icon: Icon(a.icon, size: 16),
                label: Text(a.label),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ))
          .toList(),
    );
  }
}
