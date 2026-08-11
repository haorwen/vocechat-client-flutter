import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/media_cache.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/voce_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/account_switcher_sheet.dart';
import '../../channels/application/conversation_providers.dart';
import '../../messages/data/message_cache.dart';
import '../application/app_info_provider.dart';
import '../data/user_api.dart';

void _showFeatureUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppL10n.of(context).featureUnavailable),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ---------------------------------------------------------------------------
// SettingsScreen — port of vocechat-web's settings page.
// Left rail: 212px-wide neutral-100 column with grouped nav (General / About)
// and a "Logout" danger link at the bottom. Right pane: white surface with
// a bold title and a stack of 512px-wide cards.
// ---------------------------------------------------------------------------

enum _SettingsNav {
  myAccount('general'),
  notifications('general'),
  appearance('general'),
  storage('general'),
  about('about');

  const _SettingsNav(this.group);
  final String group;

  String title(AppL10n l) => switch (this) {
        _SettingsNav.myAccount => l.settingsMyAccount,
        _SettingsNav.notifications => l.settingsNotifications,
        _SettingsNav.appearance => l.settingsAppearance,
        _SettingsNav.storage => l.settingsStorage,
        _SettingsNav.about => l.settingsAbout,
      };
}

String _groupLabel(AppL10n l, String key) => switch (key) {
      'general' => l.settingsGroupGeneral,
      'about' => l.settingsGroupAbout,
      _ => key,
    };

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

  Future<void> _confirmLogout() async {
    final l = AppL10n.of(context);
    final ok = await showVoceConfirm(
      context: context,
      title: l.settingsLogoutConfirmTitle,
      body: l.settingsLogoutConfirmContent,
      confirmLabel: l.settingsLogout,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok == true) await _logout();
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
              onSwitchAccount: () => showAccountSwitcherSheet(context),
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
    final l = AppL10n.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    String? avatarUrl;
    if (user is AuthStateAuthenticated) {
      final baseUrl = serverState?.servers
              .where((s) => s.id == serverState.currentServerId)
              .firstOrNull
              ?.baseUrl ??
          '';
      final avatarUpdatedAt = user.user.avatarUpdatedAt;
      if ((avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
        avatarUrl =
            '$baseUrl/api/resource/avatar?uid=${user.user.uid}&t=$avatarUpdatedAt';
      }
    }
    return Container(
      color: AppTokens.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (user is AuthStateAuthenticated)
            ListTile(
              leading: VoceAvatar(
                name: safeText(user.user.name),
                imageUrl: avatarUrl,
                size: 44,
              ),
              title: Text(
                safeText(user.user.name),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTokens.gray800,
                ),
              ),
              subtitle: Text('#${user.user.uid}'),
              onTap: () {
                setState(() => _nav = _SettingsNav.myAccount);
                showDialog<void>(
                  context: context,
                  builder: (ctx) => Dialog.fullscreen(
                    backgroundColor: AppTokens.surface,
                    child: Scaffold(
                      backgroundColor: AppTokens.surface,
                      appBar: AppBar(
                        title: Text(_SettingsNav.myAccount.title(l)),
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
          const Divider(height: 1),
          for (final group in _groups()) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(
                _groupLabel(l, group).toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.gray400,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            // My Account is already surfaced as the avatar/name header row
            // above — don't list it a second time.
            for (final n in _SettingsNav.values.where((x) =>
                x.group == group && x != _SettingsNav.myAccount))
              ListTile(
                title: Text(n.title(l)),
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
                          title: Text(n.title(l)),
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
          ExpansionTile(
            title: Text(l.settingsSwitchAccount),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: EdgeInsets.zero,
            // Inline (not a modal sheet) so the checkmark's move to the new
            // current account stays visible right after switching, instead
            // of switching being confirmed only by the sheet disappearing.
            children: const [AccountSwitcherList()],
          ),
          ListTile(
            title: Text(
              l.settingsLogout,
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
    final l = AppL10n.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final String userName =
        user is AuthStateAuthenticated ? user.user.name : '…';
    final String userEmail = user is AuthStateAuthenticated
        ? (user.user.email ?? '')
        : '';
    final int userUid =
        user is AuthStateAuthenticated ? user.user.uid : 0;
    final int? avatarUpdatedAt =
        user is AuthStateAuthenticated ? user.user.avatarUpdatedAt : null;

    Widget content;
    switch (_nav) {
      case _SettingsNav.myAccount:
        content = _MyAccountPane(
          name: userName,
          email: userEmail,
          uid: userUid,
          avatarUpdatedAt: avatarUpdatedAt,
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
        final localeSel =
            ref.watch(localeNotifierProvider.notifier).selection;
        // Also watch the underlying Locale? state so the radio updates when
        // the persisted preference loads asynchronously on first launch.
        ref.watch(localeNotifierProvider);
        content = _AppearancePane(
          themeMode: mode,
          onThemeChanged: (m) => ref
              .read(themeModeNotifierProvider.notifier)
              .setMode(m),
          locale: localeSel,
          onLocaleChanged: (loc) => ref
              .read(localeNotifierProvider.notifier)
              .setLocale(loc),
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
              _nav.title(l),
              style: TextStyle(
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
    required this.onSwitchAccount,
    required this.onLogout,
  });

  final _SettingsNav current;
  final ValueChanged<_SettingsNav> onSelect;
  final VoidCallback onSwitchAccount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              child: Text(
                l.settingsTitle,
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
                  _groupLabel(l, entry.key),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.gray400,
                  ),
                ),
              ),
              for (final n in entry.value)
                _RailItem(
                  title: n.title(l),
                  isSelected: n == current,
                  onTap: () => onSelect(n),
                ),
              const SizedBox(height: 28),
            ],
            const SizedBox(height: 4),
            InkWell(
              onTap: onSwitchAccount,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  l.settingsSwitchAccount,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  l.settingsLogout,
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
              style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
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
    final fg = AppTokens.gray700;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(8),
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

class _MyAccountPane extends ConsumerStatefulWidget {
  const _MyAccountPane({
    required this.name,
    required this.email,
    required this.uid,
    required this.avatarUpdatedAt,
  });

  final String name;
  final String email;
  final int uid;
  final int? avatarUpdatedAt;

  @override
  ConsumerState<_MyAccountPane> createState() => _MyAccountPaneState();
}

class _MyAccountPaneState extends ConsumerState<_MyAccountPane> {
  bool _uploadingAvatar = false;

  /// Mirrors `_friendlyError` in channel_settings_screen.dart: unwrap the
  /// shared Dio client's `ApiException` (set by the auth interceptor for any
  /// non-2xx response) into its human-readable message.
  String _friendlyError(Object e) {
    if (e is DioException) {
      final inner = e.error;
      if (inner is ApiException) return inner.message;
      return e.message ?? AppL10n.of(context).errorRequestFailed;
    }
    return e.toString();
  }

  void _showError(Object e) {
    if (!mounted) return;
    final l = AppL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(safeText(l.errorPrefix(_friendlyError(e))))),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_uploadingAvatar) return;
    final l = AppL10n.of(context);
    setState(() => _uploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref.read(userApiProvider).uploadAvatar(bytes);
      await ref.read(authControllerProvider.notifier).refreshUser();
      _showSuccess(l.avatarUpdated);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editName() async {
    final l = AppL10n.of(context);
    final controller = TextEditingController(text: widget.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.accountEditNameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l.accountNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppL10n.of(ctx).actionCancel),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isEmpty) return;
              Navigator.of(ctx).pop(trimmed);
            },
            child: Text(AppL10n.of(ctx).chatEditSave),
          ),
        ],
      ),
    );
    if (newName == null || newName == widget.name) return;

    try {
      await ref.read(userApiProvider).updateInfo(name: newName);
      await ref.read(authControllerProvider.notifier).refreshUser();
      _showSuccess(l.accountNameUpdated);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _changePassword() async {
    final l = AppL10n.of(context);
    final formKey = GlobalKey<FormState>();
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.accountChangePasswordTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldCtrl,
                obscureText: true,
                autofocus: true,
                decoration:
                    InputDecoration(labelText: l.accountCurrentPasswordLabel),
                validator: (v) =>
                    (v == null || v.isEmpty) ? l.loginPasswordRequired : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l.accountNewPasswordLabel),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.loginPasswordRequired;
                  if (v.length < 6) return l.loginPasswordTooShort;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: l.registerConfirmPassword),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return l.registerConfirmRequired;
                  }
                  if (v != newCtrl.text) return l.registerConfirmMismatch;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(l.chatEditSave),
          ),
        ],
      ),
    );
    if (result != true) return;

    try {
      await ref.read(userApiProvider).changePassword(
            oldPassword: oldCtrl.text,
            newPassword: newCtrl.text,
          );
      _showSuccess(l.accountPasswordChanged);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    String? avatarUrl;
    if ((widget.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
      avatarUrl =
          '$baseUrl/api/resource/avatar?uid=${widget.uid}&t=${widget.avatarUpdatedAt}';
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                InkWell(
                  onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                  customBorder: const CircleBorder(),
                  child: Stack(
                    children: [
                      VoceAvatar(
                        name: safeText(widget.name),
                        imageUrl: avatarUrl,
                        size: 80,
                      ),
                      if (_uploadingAvatar)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTokens.primary500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTokens.gray100, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.gray800,
                    ),
                    children: [
                      TextSpan(text: safeText(widget.name)),
                      TextSpan(
                        text: '  #${widget.uid}',
                        style: TextStyle(
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
            label: l.accountEmail,
            value: safeText(widget.email).isEmpty ? '—' : safeText(widget.email),
          ),
          _LabeledRow(
            label: l.accountUsername,
            value: '${safeText(widget.name)}  #${widget.uid}',
            trailing: _SecondaryButton(
                label: l.actionEdit, onTap: _editName),
          ),
          _LabeledRow(
            label: l.accountPassword,
            value: l.accountPasswordMasked,
            trailing: _SecondaryButton(
                label: l.actionEdit, onTap: _changePassword),
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
    final l = AppL10n.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SwitchTile(
            title: l.notificationsPush,
            subtitle: l.notificationsPushSubtitle,
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
          const _CardDivider(),
          _SwitchTile(
            title: l.notificationsSound,
            subtitle: l.notificationsSoundSubtitle,
            value: soundEnabled,
            onChanged: notificationsEnabled ? onSoundChanged : null,
          ),
          const _CardDivider(),
          _SwitchTile(
            title: l.notificationsMentionsOnly,
            subtitle: l.notificationsMentionsOnlySubtitle,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
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
            activeTrackColor: AppTokens.primary500,
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
// _AppearancePane — theme selector + language selector.
// ---------------------------------------------------------------------------

class _AppearancePane extends StatelessWidget {
  const _AppearancePane({
    required this.themeMode,
    required this.onThemeChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final AppLocale locale;
  final ValueChanged<AppLocale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.appearanceTheme,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _OptionTile(
                icon: Icons.light_mode_outlined,
                label: l.appearanceLight,
                isSelected: themeMode == ThemeMode.light,
                onTap: () => onThemeChanged(ThemeMode.light),
              ),
              _OptionTile(
                icon: Icons.brightness_auto_outlined,
                label: l.appearanceSystem,
                isSelected: themeMode == ThemeMode.system,
                onTap: () => onThemeChanged(ThemeMode.system),
              ),
              _OptionTile(
                icon: Icons.dark_mode_outlined,
                label: l.appearanceDark,
                isSelected: themeMode == ThemeMode.dark,
                onTap: () => onThemeChanged(ThemeMode.dark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.appearanceLanguage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.gray500,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _OptionTile(
                icon: Icons.language_outlined,
                label: l.languageSystem,
                isSelected: locale == AppLocale.system,
                onTap: () => onLocaleChanged(AppLocale.system),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageEnglish,
                isSelected: locale == AppLocale.english,
                onTap: () => onLocaleChanged(AppLocale.english),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageChinese,
                isSelected: locale == AppLocale.chinese,
                onTap: () => onLocaleChanged(AppLocale.chinese),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageJapanese,
                isSelected: locale == AppLocale.japanese,
                onTap: () => onLocaleChanged(AppLocale.japanese),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageKorean,
                isSelected: locale == AppLocale.korean,
                onTap: () => onLocaleChanged(AppLocale.korean),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageSpanish,
                isSelected: locale == AppLocale.spanish,
                onTap: () => onLocaleChanged(AppLocale.spanish),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageFrench,
                isSelected: locale == AppLocale.french,
                onTap: () => onLocaleChanged(AppLocale.french),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languageRussian,
                isSelected: locale == AppLocale.russian,
                onTap: () => onLocaleChanged(AppLocale.russian),
              ),
              _OptionTile(
                icon: Icons.translate_outlined,
                label: l.languagePortuguese,
                isSelected: locale == AppLocale.portuguese,
                onTap: () => onLocaleChanged(AppLocale.portuguese),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
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
                  Icon(Icons.check,
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

class _StoragePane extends ConsumerStatefulWidget {
  const _StoragePane();

  @override
  ConsumerState<_StoragePane> createState() => _StoragePaneState();
}

class _StoragePaneState extends ConsumerState<_StoragePane> {
  bool _clearing = false;

  Future<void> _clearCache() async {
    if (_clearing) return;
    final l = AppL10n.of(context);
    final confirmed = await showVoceConfirm(
      context: context,
      title: l.storageClearCacheConfirmTitle,
      body: l.storageClearCacheConfirmBody,
      confirmLabel: l.storageClearCacheConfirm,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (confirmed != true) return;

    setState(() => _clearing = true);
    try {
      // SQLite message + directory snapshot cache.
      final cache = await ref.read(messageCacheProvider.future);
      await cache.clearAll();
      // Decoded images plus persistent image/video/streamed-audio files.
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await MediaCache.clear();
      // Rebuild the conversation list from the now-empty cache; it falls back
      // to a network refresh (see Conversations.build no-cache path).
      ref.invalidate(conversationsProvider);
      // Recompute the storage readout from the now-empty caches.
      ref.invalidate(cacheUsageBytesProvider);
    } finally {
      if (mounted) {
        setState(() => _clearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).storageCacheCleared)),
        );
      }
    }
  }

  /// Human-readable byte count (B / KB / MB / GB), one decimal place above KB.
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final usageAsync = ref.watch(cacheUsageBytesProvider);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledRow(
            label: l.storageUsage,
            value: usageAsync.maybeWhen(
              data: _formatBytes,
              orElse: () => '…',
            ),
          ),
          _LabeledRow(
            label: l.storageAutoDownload,
            value: l.storageWifiOnly,
            trailing: _SecondaryButton(
                label: l.actionChange,
                onTap: () => _showFeatureUnavailable(context)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SecondaryButton(
              label: l.storageClearCache,
              icon: Icons.delete_sweep_outlined,
              onTap: _clearing ? () {} : _clearCache,
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

class _AboutPane extends ConsumerWidget {
  const _AboutPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final infoAsync = ref.watch(appPackageInfoProvider);
    final version = infoAsync.maybeWhen(
      data: (info) => info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})',
      orElse: () => '-',
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabeledRow(label: l.aboutAppVersion, value: version),
          _LabeledRow(
            label: l.aboutWebsite,
            value: 'voce.chat',
            trailing: _SecondaryButton(
              label: l.actionOpen,
              icon: Icons.open_in_new_outlined,
              onTap: () =>
                  launchUrl(Uri.parse('https://voce.chat')),
            ),
          ),
          _LabeledRow(
            label: l.aboutReportBug,
            value: l.aboutReportBugSubtitle,
            trailing: _SecondaryButton(
              label: l.actionContact,
              onTap: () => launchUrl(Uri.parse(
                  'https://github.com/Privoce/vocechat-web/issues')),
            ),
          ),
        ],
      ),
    );
  }
}
