import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/storage/account_store.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/server_url_validator.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/invite_link_api.dart';
import '../domain/invite_link.dart';

class ServerPickerScreen extends ConsumerStatefulWidget {
  const ServerPickerScreen({super.key});

  @override
  ConsumerState<ServerPickerScreen> createState() =>
      _ServerPickerScreenState();
}

class _ServerPickerScreenState extends ConsumerState<ServerPickerScreen> {
  String? _selectedId;
  bool _switching = false;

  Future<void> _continueWithSelected(
      List<ServerConfig> servers, String? currentServerId) async {
    final id = _selectedId ??
        (servers.any((s) => s.id == currentServerId)
            ? currentServerId
            : (servers.isNotEmpty ? servers.first.id : null));
    if (id == null) return;
    final config = servers.firstWhere((s) => s.id == id);
    setState(() => _switching = true);
    final notifier = ref.read(serverStoreProvider.notifier);
    await notifier.selectServer(config.id);
    // This flow always lands on /login regardless of any saved account on
    // the target server (the account-switcher screen is the path for
    // resuming a saved session without re-entering credentials) — clear the
    // current-account pointer so AuthController's bootstrap doesn't try to
    // resolve a stale account tied to the *previous* server and bounce
    // serverStore back to it.
    await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
    // Wait for auth controller to re-bootstrap with new server
    await ref.read(authControllerProvider.future);
    if (mounted) context.go('/login');
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddServerSheet(
        onSaved: (config) async {
          final notifier = ref.read(serverStoreProvider.notifier);
          await notifier.addServer(config);
          await notifier.selectServer(config.id);
          await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
          // Wait for auth controller to re-bootstrap with new server
          await ref.read(authControllerProvider.future);
          if (mounted) context.go('/login');
        },
      ),
    );
  }

  void _showInviteLinkSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InviteLinkSheet(
        onResolved: (serverBaseUrl, magicToken) async {
          final name = Uri.tryParse(serverBaseUrl)?.host ?? serverBaseUrl;
          final config = ServerConfig(
            id: '${Uri.parse(serverBaseUrl).host.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
            baseUrl: serverBaseUrl,
            name: name,
          );
          final notifier = ref.read(serverStoreProvider.notifier);
          await notifier.addServer(config);
          await notifier.selectServer(config.id);
          await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
          // Wait for auth controller to re-bootstrap with new server
          await ref.read(authControllerProvider.future);
          if (mounted) context.go('/register', extra: magicToken);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final serverState = ref.watch(serverStoreProvider);

    return serverState.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text(safeText(l.errorPrefix(e.toString()))))),
      data: (state) {
        final servers = state.servers;
        final selectedIndex = _selectedId != null
            ? servers.indexWhere((s) => s.id == _selectedId)
            : servers.indexWhere((s) => s.id == state.currentServerId);
        final effectiveIndex = selectedIndex == -1 ? 0 : selectedIndex;

        return Scaffold(
          appBar: AppBar(
            title: Text(l.serverPickerTitle),
            centerTitle: false,
          ),
          body: servers.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EmptyStateView(
                          icon: Icons.dns_outlined,
                          title: l.serverPickerEmptyTitle,
                          subtitle: l.serverPickerEmptySubtitle,
                        ),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: l.serverPickerAddFirst,
                          onPressed: _showAddSheet,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _showInviteLinkSheet,
                          icon: const Icon(Icons.link, size: 18),
                          label: Text(l.serverPickerUseInviteLink),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RadioGroup<int>(
                  groupValue: effectiveIndex,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedId = servers[v].id);
                    }
                  },
                  child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: servers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final server = servers[i];
                    final selected = effectiveIndex == i;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Material(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              setState(() => _selectedId = server.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      theme.colorScheme.primary,
                                  child: Text(
                                    safeText(server.name.isNotEmpty
                                        ? server.name[0].toUpperCase()
                                        : 'V'),
                                    style: TextStyle(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        safeText(server.name),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: selected
                                              ? theme.colorScheme
                                                  .onPrimaryContainer
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        safeText(server.baseUrl),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: selected
                                              ? theme.colorScheme
                                                  .onPrimaryContainer
                                                  .withAlpha(180)
                                              : theme.colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<int>(value: i),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add),
            label: Text(l.serverPickerAdd),
          ),
          bottomNavigationBar: servers.isEmpty
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrimaryButton(
                        label: l.serverPickerContinue,
                        isLoading: _switching,
                        onPressed: _switching
                            ? null
                            : () => _continueWithSelected(
                                servers, state.currentServerId),
                      ),
                      TextButton.icon(
                        onPressed: _showInviteLinkSheet,
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(l.serverPickerUseInviteLink),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _AddServerSheet extends ConsumerStatefulWidget {
  final Future<void> Function(ServerConfig) onSaved;
  const _AddServerSheet({required this.onSaved});

  @override
  ConsumerState<_AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends ConsumerState<_AddServerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController(text: 'https://');
  bool _testing = false;
  bool _tested = false;
  bool _saving = false;
  bool _showHttpLocalhostWarning = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(_onUrlChanged);
  }

  void _onUrlChanged() {
    final uri = Uri.tryParse(_urlCtrl.text.trim());
    final isHttpLocalhost = uri != null &&
        uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
    if (isHttpLocalhost != _showHttpLocalhostWarning) {
      setState(() => _showHttpLocalhostWarning = isHttpLocalhost);
    }
  }

  Future<void> _testConnection() async {
    final l = AppL10n.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _testing = true);
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      final testDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      await testDio.get('$url/api/admin/system/organization');
      if (!mounted) return;
      setState(() {
        _testing = false;
        _tested = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.serverTestSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _tested = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.serverTestFailed)),
      );
    }
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    final name = Uri.tryParse(url)?.host ?? url;
    final config = ServerConfig(
      id: '${Uri.parse(url).host.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
      baseUrl: url,
      name: name,
    );
    setState(() => _saving = true);
    try {
      await widget.onSaved(config);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(safeText(l.errorPrefix(e.toString())))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(l.serverAddTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: l.serverUrl,
                hintText: l.serverUrlHint,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
              validator: (v) => validateServerUrl(v, l),
            ),
            if (_showHttpLocalhostWarning) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.serverUrlHttpNotAllowed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_tested
                      ? Icons.check_circle_outline
                      : Icons.wifi),
              label: Text(safeText(_testing ? l.serverTesting : l.serverTestConnection)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.serverSave,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteLinkSheet extends ConsumerStatefulWidget {
  final Future<void> Function(String serverBaseUrl, String magicToken)
      onResolved;
  const _InviteLinkSheet({required this.onResolved});

  @override
  ConsumerState<_InviteLinkSheet> createState() => _InviteLinkSheetState();
}

class _InviteLinkSheetState extends ConsumerState<_InviteLinkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _linkCtrl = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    setState(() => _linkCtrl.text = text);
  }

  Future<void> _submit() async {
    final l = AppL10n.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsed = parseInviteLink(_linkCtrl.text);
    if (parsed is! InviteLinkParseValid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.inviteLinkInvalid)));
      return;
    }

    setState(() => _checking = true);
    try {
      final valid = await InviteLinkApi(parsed.serverBaseUrl)
          .checkMagicToken(parsed.magicToken);
      if (!valid) {
        if (!mounted) return;
        setState(() => _checking = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.inviteLinkExpired)));
        return;
      }
      await widget.onResolved(parsed.serverBaseUrl, parsed.magicToken);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.inviteLinkCheckFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(l.inviteLinkSheetTitle,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _linkCtrl,
              decoration: InputDecoration(
                labelText: l.inviteLinkHint,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l.inviteLinkRequired : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _checking ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 18),
              label: Text(l.inviteLinkPasteFromClipboard),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: l.inviteLinkContinue,
              isLoading: _checking,
              onPressed: _checking ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
