import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // Ignore Enter-key submits while a registration is already in flight.
    if (ref.read(authControllerProvider).isLoading) return;

    // Navigation + error surfacing happen in the ref.listen in build —
    // doing it here as well produced duplicate snackbars / double context.go.
    await ref.read(authControllerProvider.notifier).register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
  }

  Future<void> _sendMagicLink() async {
    final l = AppL10n.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.registerEmailFirst)),
      );
      return;
    }
    // Magic-link registration is not implemented on this server version —
    // say so instead of faking a success message.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.featureUnavailable)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppL10n.of(context);

    // Listen for auth state changes
    ref.listen(authControllerProvider, (_, next) {
      next.whenOrNull(
        data: (state) {
          if (state is AuthStateAuthenticated && mounted) {
            context.go('/home');
          }
        },
        error: (e, _) {
          if (!mounted) return;
          final msg = e is DioException && e.error is ApiException
              ? (e.error as ApiException).message
              : e.toString();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(safeText(msg))));
        },
      );
    });

    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: Text(l.registerTitle),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.registerHeader,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.registerSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.registerName,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.registerNameRequired;
                    }
                    if (v.trim().length < 2) {
                      return l.registerNameTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
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
                      return l.registerEmailRequired;
                    }
                    final regex =
                        RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                    if (!regex.hasMatch(v.trim())) {
                      return l.registerEmailInvalid;
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
                      tooltip: _obscurePass
                          ? l.tooltipShowPassword
                          : l.tooltipHidePassword,
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l.registerPasswordRequired;
                    }
                    if (v.length < 6) {
                      return l.registerPasswordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: InputDecoration(
                    labelText: l.registerConfirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(12)),
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? l.tooltipShowPassword
                          : l.tooltipHidePassword,
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(
                          () => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _createAccount(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return l.registerConfirmRequired;
                    }
                    if (v != _passwordCtrl.text) {
                      return l.registerConfirmMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: l.registerCreate,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _createAccount,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _sendMagicLink,
                  icon: const Icon(Icons.auto_awesome_outlined,
                      size: 18),
                  label:
                      Text(l.registerMagicLink),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.registerHaveAccount,
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(l.loginSignIn),
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
