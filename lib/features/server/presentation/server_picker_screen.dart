import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/primary_button.dart';

class ServerPickerScreen extends ConsumerStatefulWidget {
  const ServerPickerScreen({super.key});

  @override
  ConsumerState<ServerPickerScreen> createState() =>
      _ServerPickerScreenState();
}

class _ServerPickerScreenState extends ConsumerState<ServerPickerScreen> {
  String? _selectedId;

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
          VoceDioClient.setBaseUrl(config.baseUrl);
          if (mounted) context.go('/login');
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
              ? EmptyStateView(
                  icon: Icons.dns_outlined,
                  title: l.serverPickerEmptyTitle,
                  subtitle: l.serverPickerEmptySubtitle,
                  actionLabel: l.serverPickerAddFirst,
                  onAction: _showAddSheet,
                )
              : ListView.separated(
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
                                    style: const TextStyle(
                                        color: Colors.white,
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
                                Radio<int>(
                                  value: i,
                                  groupValue: effectiveIndex,
                                  onChanged: (v) => setState(
                                      () => _selectedId = servers[v!].id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddSheet,
            icon: const Icon(Icons.add),
            label: Text(l.serverPickerAdd),
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
  final _aliasCtrl = TextEditingController();
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
      setState(() {
        _testing = false;
        _tested = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.serverTestSuccess)),
        );
      }
    } catch (_) {
      setState(() {
        _testing = false;
        _tested = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.serverTestFailed)),
        );
      }
    }
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
    final alias = _aliasCtrl.text.trim();
    final name =
        alias.isNotEmpty ? alias : Uri.tryParse(url)?.host ?? url;
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
    return Padding(
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
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l.serverUrlRequired;
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) {
                  return l.serverUrlMustHttps;
                }
                final host = uri.host.toLowerCase();
                final isLocalhost =
                    host == 'localhost' || host == '127.0.0.1';
                if (uri.scheme == 'http' && !isLocalhost) {
                  return l.serverUrlHttpNotAllowed;
                }
                if (uri.scheme != 'https' && uri.scheme != 'http') {
                  return l.serverUrlMustHttps;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _aliasCtrl,
              decoration: InputDecoration(
                labelText: l.serverAlias,
                hintText: l.serverAliasHint,
                prefixIcon: const Icon(Icons.label_outline),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
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
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
