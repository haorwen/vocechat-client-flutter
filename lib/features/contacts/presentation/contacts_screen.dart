import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/loading_capsule.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../application/contacts_provider.dart';
import '../application/presence_provider.dart';
import '../application/user_directory_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int? _selectedUid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      final l = AppL10n.of(context);
      final asyncContacts = ref.watch(contactsProvider);

      Widget listPanel = Container(
        width: isWide ? 268 : double.infinity,
        decoration: BoxDecoration(
          color: AppTokens.surface,
          border: isWide
              ? Border(
                  right: BorderSide(color: AppTokens.gray200, width: 1),
                )
              : null,
        ),
        child: Column(
          children: [
            _ContactsHeader(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: asyncContacts.when(
                loading: () => Center(
                  child: LoadingCapsule(label: l.contactsLoading),
                ),
                error: (e, _) =>
                    Center(child: Text(safeText(l.errorPrefix(e.toString())))),
                data: (allContacts) {
                  final q = _query.toLowerCase();
                  final filtered = q.isEmpty
                      ? allContacts
                      : allContacts
                          .where((c) =>
                              c.name.toLowerCase().contains(q) ||
                              c.email.toLowerCase().contains(q))
                          .toList();

                  // Heuristic: if email contains "bot" treat as bot section.
                  // Otherwise, contacts. Mirrors Figma's BOT / CONTACT split.
                  final bots = filtered
                      .where((c) =>
                          c.email.toLowerCase().contains('bot') ||
                          c.name.toLowerCase().contains('bot'))
                      .toList();
                  final contacts = filtered
                      .where((c) => !bots.contains(c))
                      .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        l.contactsEmpty,
                        style: TextStyle(
                            color: AppTokens.gray500, fontSize: 13),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    children: [
                      if (bots.isNotEmpty) ...[
                        _SectionLabel(l.contactsSectionBot(bots.length)),
                        ...bots.map((c) => _ContactTile(
                              contact: c,
                              isBot: true,
                              isSelected:
                                  isWide && _selectedUid == c.uid,
                              onTap: () => _onContactTap(
                                  context, c, isWide),
                            )),
                        const SizedBox(height: 4),
                      ],
                      if (contacts.isNotEmpty) ...[
                        _SectionLabel(l.contactsSectionContact(contacts.length)),
                        ...contacts.map((c) => _ContactTile(
                              contact: c,
                              isBot: false,
                              isSelected:
                                  isWide && _selectedUid == c.uid,
                              onTap: () => _onContactTap(
                                  context, c, isWide),
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );

      if (!isWide) {
        return listPanel;
      }

      // Wide: side-by-side panel with profile/empty placeholder.
      final selectedContact = asyncContacts.valueOrNull
          ?.where((c) => c.uid == _selectedUid)
          .firstOrNull;
      return Row(
        children: [
          listPanel,
          Expanded(
            child: selectedContact != null
                ? _ContactProfile(contact: selectedContact)
                : const _ContactsEmptyState(),
          ),
        ],
      );
    });
  }

  void _onContactTap(BuildContext context, ContactInfo c, bool isWide) {
    if (isWide) {
      setState(() => _selectedUid = c.uid);
    } else {
      context.push('/chat/u-${c.uid}');
    }
  }
}

// ---------------------------------------------------------------------------
// _ContactsHeader — pill search + add button.
// ---------------------------------------------------------------------------

class _ContactsHeader extends StatelessWidget {
  const _ContactsHeader({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border(
          bottom: BorderSide(color: AppTokens.gray200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x14000000),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTokens.gray700,
                ),
                decoration: InputDecoration(
                  hintText: l.contactsSearch,
                  hintStyle: TextStyle(
                    color: AppTokens.gray400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: AppTokens.gray400),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 0),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.person_add_alt_1,
                size: 22, color: AppTokens.gray500),
            onPressed: () {},
            tooltip: l.contactsAdd,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionLabel — uppercase BOT - 3 / CONTACT - 47 label rows.
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTokens.gray500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ContactTile — Figma "Contacts / Item" with 32px avatar.
// Bots show a robot indicator overlay; people show a green status dot.
// ---------------------------------------------------------------------------

class _ContactTile extends ConsumerWidget {
  const _ContactTile({
    required this.contact,
    required this.isBot,
    required this.isSelected,
    required this.onTap,
  });

  final ContactInfo contact;
  final bool isBot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = isSelected ? AppTokens.selected : Colors.transparent;

    // Resolve the avatar URL from the user directory + active server.
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    String? avatarUrl;
    final u = userDir[contact.uid];
    if (u != null && (u.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
      avatarUrl =
          '$baseUrl/api/resource/avatar?uid=${contact.uid}&t=${u.avatarUpdatedAt}';
    }

    final showStatus = ref.watch(showOnlineStatusProvider);
    final presence = ref.watch(presenceProvider);
    final isOnline = presence[contact.uid] ?? false;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: AppTokens.hover,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    VoceAvatar(
                      name: safeText(contact.name),
                      imageUrl: avatarUrl,
                      size: 32,
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: isBot
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTokens.gray100,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTokens.surface, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.smart_toy_outlined,
                                size: 8,
                                color: AppTokens.gray600,
                              ),
                            )
                          : showStatus
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? AppTokens.successDot
                                        : AppTokens.gray400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTokens.surface, width: 2),
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  safeText(contact.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTokens.gray600
                        : AppTokens.gray700,
                    height: 20 / 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ContactProfile — right-pane profile preview (mirrors Figma "Profile" card).
// ---------------------------------------------------------------------------

class _ContactProfile extends ConsumerWidget {
  const _ContactProfile({required this.contact});

  final ContactInfo contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    String? avatarUrl;
    final u = userDir[contact.uid];
    if (u != null && (u.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
      avatarUrl =
          '$baseUrl/api/resource/avatar?uid=${contact.uid}&t=${u.avatarUpdatedAt}';
    }

    return Container(
      color: AppTokens.surface,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoceAvatar(
              name: safeText(contact.name),
              imageUrl: avatarUrl,
              size: 80,
            ),
            const SizedBox(height: 12),
            Text(
              safeText(contact.name),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTokens.gray800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${safeText(contact.email).split('@').first}',
              style: TextStyle(
                fontSize: 14,
                color: AppTokens.gray400,
                height: 20 / 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProfileAction(
                  icon: Icons.chat_bubble_outline,
                  label: l.contactsMessage,
                  isPrimary: true,
                  onTap: () => context.push('/chat/u-${contact.uid}'),
                ),
                const SizedBox(width: 8),
                _ProfileAction(
                  icon: Icons.call_outlined,
                  label: l.contactsCall,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _ProfileAction(
                  icon: Icons.more_horiz,
                  label: l.actionMore,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 128,
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTokens.gray50 : AppTokens.gray100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppTokens.gray500),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTokens.gray500,
                height: 20 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsEmptyState extends StatelessWidget {
  const _ContactsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      color: AppTokens.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTokens.primary50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline,
                size: 30, color: AppTokens.primary500),
          ),
          const SizedBox(height: 16),
          Text(
            l.contactsSelectTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTokens.gray700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.contactsSelectSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTokens.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
