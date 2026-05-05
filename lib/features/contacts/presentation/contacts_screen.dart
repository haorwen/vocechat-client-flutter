import 'package:flutter/material.dart';
import '../../../shared/widgets/voce_avatar.dart';

// TODO(wire): replace with riverpod controller
class _Contact {
  final String id;
  final String name;
  final String email;
  final String? imageUrl;

  const _Contact(
      {required this.id,
      required this.name,
      required this.email,
      this.imageUrl});
}

const _sampleContacts = [
  _Contact(id: 'u1', name: 'Alice Nguyen', email: 'alice@company.com'),
  _Contact(id: 'u2', name: 'Bob Chen', email: 'bob@company.com'),
  _Contact(id: 'u3', name: 'Carol Smith', email: 'carol@company.com'),
  _Contact(id: 'u4', name: 'David Park', email: 'david@company.com'),
  _Contact(id: 'u5', name: 'Eva Martinez', email: 'eva@company.com'),
  _Contact(id: 'u6', name: 'Frank Wilson', email: 'frank@company.com'),
  _Contact(id: 'u7', name: 'Grace Liu', email: 'grace@company.com'),
  _Contact(id: 'u8', name: 'Hank Brown', email: 'hank@company.com'),
  _Contact(id: 'u9', name: 'Iris Johnson', email: 'iris@company.com'),
  _Contact(id: 'u10', name: 'James Davis', email: 'james@company.com'),
  _Contact(id: 'u11', name: 'Karen Miller', email: 'karen@company.com'),
  _Contact(id: 'u12', name: 'Liam Taylor', email: 'liam@company.com'),
];

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // TODO(wire): replace with riverpod controller
  final _searchCtrl = SearchController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_Contact> get _filtered {
    if (_query.isEmpty) return _sampleContacts;
    final q = _query.toLowerCase();
    return _sampleContacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList();
  }

  Map<String, List<_Contact>> get _grouped {
    final contacts = _filtered;
    final map = <String, List<_Contact>>{};
    for (final c in contacts) {
      final letter = c.name[0].toUpperCase();
      (map[letter] ??= []).add(c);
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _grouped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchAnchor(
              searchController: _searchCtrl,
              builder: (context, ctrl) => SearchBar(
                controller: ctrl,
                hintText: 'Search contacts…',
                leading: const Icon(Icons.search, size: 20),
                onTap: () => ctrl.openView(),
                onChanged: (v) {
                  setState(() => _query = v);
                },
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12)),
              ),
              suggestionsBuilder: (context, ctrl) {
                final q = ctrl.text.toLowerCase();
                final suggestions = _sampleContacts
                    .where((c) =>
                        c.name.toLowerCase().contains(q) ||
                        c.email.toLowerCase().contains(q))
                    .toList();
                return suggestions.map((c) => ListTile(
                      leading: VoceAvatar(name: c.name, size: 36),
                      title: Text(c.name),
                      subtitle: Text(c.email),
                      onTap: () {
                        ctrl.closeView(c.name);
                        setState(() => _query = c.name);
                      },
                    ));
              },
            ),
          ),
        ),
      ),
      body: grouped.isEmpty
          ? Center(
              child: Text(
                'No contacts found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  ...entry.value.map(
                    (c) => ListTile(
                      leading: VoceAvatar(name: c.name, size: 42),
                      title: Text(c.name,
                          style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        c.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(
                          Icons.chevron_right_outlined, size: 18),
                      onTap: () {},
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Add contact',
        child: const Icon(Icons.person_add_outlined),
      ),
    );
  }
}
