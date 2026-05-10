import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/safe_text.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';

// ---------------------------------------------------------------------------
// SettingsScreen — port of vocechat-web's settings page.
// Left rail: 212px-wide neutral-100 column with grouped nav (General / About)
// and a "Logout" danger link at the bottom. Right pane: white surface with
// a bold title and a stack of 512px-wide cards.
// ---------------------------------------------------------------------------

enum _SettingsNav {
  myAccount('My Account', 'general'),
  notifications('Notifications', 'general'),
  appearance('Appearance', 'general'),
  storage('Storage & Data', 'general'),
  about('About', 'about');

  const _SettingsNav(this.title, this.group);
  final String title;
  final String group;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SettingsNav _nav = _SettingsNav.myAccount;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _mentionOnlyMode = false;

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/server-picker');
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You will need to sign in again to access this server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppTokens.error),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      if (!isWide) {
        return _buildNarrow(context);
      }
      return Container(
        color: AppTokens.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsRail(
              current: _nav,
              onSelect: (n) => setState(() => _nav = n),
              onLogout: _confirmLogout,
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNarrow(BuildContext context) {
    return Container(
      color: AppTokens.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final group in _groups()) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                group.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.gray400,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            for (final n in _SettingsNav.values.where((x) => x.group == group))
              ListTile(
                title: Text(n.title),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  setState(() => _nav = n);
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => Dialog.fullscreen(
                      backgroundColor: AppTokens.surface,
                      child: Scaffold(
                        backgroundColor: AppTokens.surface,
                        appBar: AppBar(
                          title: Text(n.title),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildBody(showHeader: false),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
          const Divider(height: 32),
          ListTile(
            title: const Text(
              'Log out',
              style: TextStyle(
                color: AppTokens.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }

  List<String> _groups() {
    final seen = <String>{};
    final out = <String>[];
    for (final n in _SettingsNav.values) {
      if (seen.add(n.group)) out.add(n.group);
    }
    return out;
  }

  Widget _buildBody({bool showHeader = true}) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final String userName =
        user is AuthStateAuthenticated ? user.user.name : '…';
    final String userEmail = user is AuthStateAuthenticated
        ? (user.user.email ?? '')
        : '';
    final int userUid =
        user is AuthStateAuthenticated ? user.user.uid : 0;

    Widget content;
    switch (_nav) {
      case _SettingsNav.myAccount:
        content = _MyAccountPane(
          name: userName,
          email: userEmail,
          uid: userUid,
        );
      case _SettingsNav.notifications:
        content = _NotificationsPane(
          notificationsEnabled: _notificationsEnabled,
          soundEnabled: _soundEnabled,
          mentionOnlyMode: _mentionOnlyMode,
          onNotificationsChanged: (v) =>
              setState(() => _notificationsEnabled = v),
          onSoundChanged: (v) => setState(() => _soundEnabled = v),
          onMentionOnlyChanged: (v) =>
              setState(() => _mentionOnlyMode = v),
        );
      case _SettingsNav.appearance:
        final mode = ref.watch(themeModeNotifierProvider);
        content = _AppearancePane(
          themeMode: mode,
          onChanged: (m) => ref
              .read(themeModeNotifierProvider.notifier)
              .setMode(m),
        );
      case _SettingsNav.storage:
        content = const _StoragePane();
      case _SettingsNav.about:
        content = const _AboutPane();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              _nav.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTokens.gray700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
          content,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsRail — left 212px column with grouped nav and danger zone.
// Mirrors vocechat-web's StyledSettingContainer left rail.
// ---------------------------------------------------------------------------

class _SettingsRail extends StatelessWidget {
  const _SettingsRail({
    required this.current,
    required this.onSelect,
    required this.onLogout,
  });

  final _SettingsNav current;
  final ValueChanged<_SettingsNav> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<_SettingsNav>>{};
    for (final n in _SettingsNav.values) {
      (groups[n.group] ??= []).add(n);
    }

    return Container(
      width: 212,
      color: AppTokens.gray100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 0, 0, 32),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.gray800,
                ),
              ),
            ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.gray400,
                  ),
                ),
              ),
              for (final n in entry.value)
                _RailItem(
                  title: n.title,
                  isSelected: n == current,
                  onTap: () => onSelect(n),
                ),
              const SizedBox(height: 28),
            ],
            const SizedBox(height: 4),
            InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppTokens.gray200 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          hoverColor: AppTokens.gray200,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTokens.gray600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Card — rounded-2xl gray-100 card, 512px wide on desktop, used as the
// container for stacked detail rows. Mirrors web's `bg-gray-100 rounded-2xl
// p-6 w-[512px]`.
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 512),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTokens.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LabeledRow — uppercase tiny label on top of value text, with optional
// trailing button (used by My Account fields).
// ---------------------------------------------------------------------------

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTokens.gray700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SecondaryButton — small white "Edit" button used in account rows.
// ---------------------------------------------------------------------------

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const fg = AppTokens.gray700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTokens.gray300, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MyAccountPane — avatar at top, name, then email / username / password rows
// each with an "Edit" affordance. Matches web/src/routes/setting/MyAccount.tsx.
// ---------------------------------------------------------------------------

class _MyAccountPane extends StatelessWidget {
  const _MyAccountPane({
    required this.name,
    required this.email,
    required this.uid,
  });

  final String name;
  final String email;
  final int uid;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                VoceAvatar(name: safeText(name), size: 80),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.gray800,
                    ),
                    children: [
                      TextSpan(text: safeText(name)),
                      TextSpan(
                        text: '  #$uid',
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          color: AppTokens.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          _LabeledRow(
            label: 'Email',
            value: safeText(email).isEmpty ? '—' : safeText(email),
          ),
          _LabeledRow(
            label: 'Username',
            value: '${safeText(name)}  #$uid',
            trailing: _SecondaryButton(label: 'Edit', onTap: () {}),
          ),
          _LabeledRow(
            label: 'Password',
            value: '*********',
            trailing: _SecondaryButton(label: 'Edit', onTap: () {}),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NotificationsPane — three switches in a single card.
// ---------------------------------------------------------------------------

class _NotificationsPane extends StatelessWidget {
  const _NotificationsPane({
    required this.notificationsEnabled,
    required this.soundEnabled,
    required this.mentionOnlyMode,
    required this.onNotificationsChanged,
    required this.onSoundChanged,
    required this.onMentionOnlyChanged,
  });

  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool mentionOnlyMode;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onSoundChanged;
  final ValueChanged<bool> onMentionOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitchTile(
            title: 'Push notifications',
            subtitle: 'Get notified about new messages and mentions.',
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
          const _CardDivider(),
          _SwitchTile(
            title: 'Notification sounds',
            subtitle: 'Play a chime on incoming messages.',
            value: soundEnabled,
            onChanged: notificationsEnabled ? onSoundChanged : null,
          ),
          const _CardDivider(),
          _SwitchTile(
            title: 'Mentions only',
            subtitle: 'Only notify for @mentions.',
            value: mentionOnlyMode,
            onChanged:
                notificationsEnabled ? onMentionOnlyChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTokens.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTokens.primary500,
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppTokens.gray200,
    );
  }
}

// ---------------------------------------------------------------------------
// _AppearancePane — theme selector (light/system/dark) as radio rows.
// ---------------------------------------------------------------------------

class _AppearancePane extends StatelessWidget {
  const _AppearancePane({
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'THEME',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTokens.gray500,
                letterSpacing: 0.6,
              ),
            ),
          ),
          _ThemeOption(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            isSelected: themeMode == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          _ThemeOption(
            icon: Icons.brightness_auto_outlined,
            label: 'System default',
            isSelected: themeMode == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          _ThemeOption(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            isSelected: themeMode == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected ? AppTokens.primary50 : AppTokens.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? AppTokens.primary400
                    : AppTokens.gray200,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppTokens.primary500
                      : AppTokens.gray500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTokens.primary500
                          : AppTokens.gray700,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check,
                      size: 16, color: AppTokens.primary500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StoragePane — storage usage / auto-download / clear cache.
// ---------------------------------------------------------------------------

class _StoragePane extends StatelessWidget {
  const _StoragePane();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledRow(
            label: 'Storage usage',
            value: '42 MB',
          ),
          _LabeledRow(
            label: 'Auto-download media',
            value: 'Wi-Fi only',
            trailing: _SecondaryButton(label: 'Change', onTap: () {}),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SecondaryButton(
              label: 'Clear cache',
              icon: Icons.delete_sweep_outlined,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AboutPane — version / website / bug report.
// ---------------------------------------------------------------------------

class _AboutPane extends StatelessWidget {
  const _AboutPane();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledRow(label: 'App version', value: '1.0.0'),
          _LabeledRow(
            label: 'Website',
            value: 'voce.chat',
            trailing: _SecondaryButton(
              label: 'Open',
              icon: Icons.open_in_new_outlined,
              onTap: () {},
            ),
          ),
          _LabeledRow(
            label: 'Report a bug',
            value: 'Help us improve VoceChat.',
            trailing: _SecondaryButton(
              label: 'Contact',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}
