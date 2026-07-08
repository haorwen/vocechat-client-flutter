import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../data/group_api.dart';

/// Opens the create-channel dialog/sheet. On success, refreshes the group
/// directory and navigates to the new channel.
Future<void> showCreateChannelDialog(BuildContext context) async {
  final isWide = MediaQuery.sizeOf(context).width >= 700;
  if (isWide) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const Dialog(
        child: SizedBox(
          width: 480,
          child: _CreateChannelForm(),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: _CreateChannelForm(),
      ),
    );
  }
}

class _CreateChannelForm extends ConsumerStatefulWidget {
  const _CreateChannelForm();

  @override
  ConsumerState<_CreateChannelForm> createState() =>
      _CreateChannelFormState();
}

class _CreateChannelFormState extends ConsumerState<_CreateChannelForm> {
  final _nameCtrl = TextEditingController();
  bool _isPublic = false;
  bool _submitting = false;
  String? _error;
  final Set<int> _selectedMembers = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppL10n.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.createChannelNameRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(groupApiProvider);
      final gid = await api.createChannel(
        name: name,
        isPublic: _isPublic,
        members: _isPublic ? const [] : _selectedMembers.toList(),
      );
      // Refresh the group directory so the new channel appears immediately.
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go('/home/chat/g-$gid');
    } catch (e) {
      String msg = l.createChannelFailed;
      if (e is DioException) {
        final inner = e.error;
        if (inner is ApiException) msg = inner.message;
      }
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final isAdmin =
        authState is AuthStateAuthenticated ? authState.user.isAdmin : false;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  l.createChannelTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textHeading,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: AppTokens.gray500),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l.createChannelNameLabel,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.channelPublicLabel,
                    style: TextStyle(fontSize: 14, color: AppTokens.gray700),
                  ),
                ),
                Switch.adaptive(
                  value: _isPublic,
                  onChanged: isAdmin
                      ? (v) => setState(() => _isPublic = v)
                      : null,
                ),
              ],
            ),
            if (!isAdmin)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.createChannelPublicAdminOnly,
                  style: TextStyle(fontSize: 12, color: AppTokens.gray400),
                ),
              ),
            if (!_isPublic) ...[
              const SizedBox(height: 8),
              Text(
                l.chatToolMembers,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.gray500,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Scrollbar(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final u in userDir.values)
                        if (u.uid != currentUid)
                          CheckboxListTile(
                            dense: true,
                            value: _selectedMembers.contains(u.uid),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedMembers.add(u.uid);
                              } else {
                                _selectedMembers.remove(u.uid);
                              }
                            }),
                            secondary: VoceAvatar(name: safeText(u.name), size: 32),
                            title: Text(safeText(u.name)),
                          ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AppTokens.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: l.createChannelSubmit,
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
