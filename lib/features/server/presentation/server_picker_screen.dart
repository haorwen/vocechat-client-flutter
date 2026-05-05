import 'package:flutter/material.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/primary_button.dart';

// TODO(wire): replace with riverpod controller
class _ServerEntry {
  final String name;
  final String url;
  final String? logoUrl;
  _ServerEntry({required this.name, required this.url, this.logoUrl});
}

class ServerPickerScreen extends StatefulWidget {
  const ServerPickerScreen({super.key});

  @override
  State<ServerPickerScreen> createState() => _ServerPickerScreenState();
}

class _ServerPickerScreenState extends State<ServerPickerScreen> {
  // TODO(wire): replace with riverpod controller
  final _servers = ValueNotifier<List<_ServerEntry>>([]);
  int _selectedIndex = 0;

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddServerSheet(
        onSaved: (entry) {
          setState(() {
            _servers.value = [..._servers.value, entry];
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Server'),
        centerTitle: false,
      ),
      body: ValueListenableBuilder<List<_ServerEntry>>(
        valueListenable: _servers,
        builder: (context, servers, _) {
          if (servers.isEmpty) {
            return EmptyStateView(
              icon: Icons.dns_outlined,
              title: 'Connect to a VoceChat server',
              subtitle: 'Add a server to get started chatting with your team.',
              actionLabel: 'Add your first server',
              onAction: _showAddSheet,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: servers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final server = servers[i];
              final selected = _selectedIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Material(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedIndex = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              server.name.isNotEmpty
                                  ? server.name[0].toUpperCase()
                                  : 'V',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  server.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? theme.colorScheme.onPrimaryContainer
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  server.url,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: selected
                                        ? theme.colorScheme.onPrimaryContainer
                                            .withAlpha(180)
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Radio<int>(
                            value: i,
                            groupValue: _selectedIndex,
                            onChanged: (v) =>
                                setState(() => _selectedIndex = v!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
    );
  }
}

class _AddServerSheet extends StatefulWidget {
  final void Function(_ServerEntry) onSaved;
  const _AddServerSheet({required this.onSaved});

  @override
  State<_AddServerSheet> createState() => _AddServerSheetState();
}

class _AddServerSheetState extends State<_AddServerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _urlCtrl = TextEditingController(text: 'https://');
  final _aliasCtrl = TextEditingController();
  bool _testing = false;
  bool _tested = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _aliasCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _testing = true);
    // TODO(wire): replace with real network check
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _testing = false;
      _tested = true;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection successful (stub)')),
      );
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final url = _urlCtrl.text.trim();
    final alias = _aliasCtrl.text.trim();
    final name = alias.isNotEmpty ? alias : Uri.tryParse(url)?.host ?? url;
    widget.onSaved(_ServerEntry(name: name, url: url));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text('Add Server',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://chat.example.com',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'URL is required';
                final uri = Uri.tryParse(v.trim());
                if (uri == null ||
                    !uri.hasScheme ||
                    (!uri.scheme.startsWith('https') &&
                        !uri.scheme.startsWith('http'))) {
                  return 'Must start with https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _aliasCtrl,
              decoration: const InputDecoration(
                labelText: 'Alias (optional)',
                hintText: 'My Work Server',
                prefixIcon: Icon(Icons.label_outline),
                border: OutlineInputBorder(
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
                  : Icon(_tested ? Icons.check_circle_outline : Icons.wifi),
              label: Text(_testing ? 'Testing…' : 'Test connection'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(label: 'Save & Continue', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
