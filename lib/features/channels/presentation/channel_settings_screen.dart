import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/server_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/safe_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/voce_avatar.dart';
import '../../../shared/widgets/voce_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../application/muted_chats_provider.dart';
import '../data/group_api.dart';
import '../data/session_actions_api.dart';

/// Channel (group) settings screen — avatar/name/description editing,
/// members list with add/remove, invite-link generation, mute toggle, leave
/// and delete channel. Mirrors the web reference's `settingChannel` route
/// (Overview + ManageMembers panes) collapsed into a single scroll screen.
class ChannelSettingsScreen extends ConsumerStatefulWidget {
  const ChannelSettingsScreen({super.key, required this.gid});

  final int gid;

  @override
  ConsumerState<ChannelSettingsScreen> createState() =>
      _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState
    extends ConsumerState<ChannelSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _dirty = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _inviteLink;
  bool _generatingLink = false;

  int? _initializedForGid;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _initFromGroup(GroupSummary group) {
    if (_initializedForGid == group.gid) return;
    _initializedForGid = group.gid;
    _nameCtrl.text = group.name;
    // description isn't in GroupSummary; kept as a local-only editable field.
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final inner = e.error;
      if (inner is ApiException) return inner.message;
      return e.message ?? AppL10n.of(context).errorRequestFailed;
    }
    return e.toString();
  }

  Future<void> _saveOverview(int gid) async {
    setState(() => _saving = true);
    try {
      await ref.read(groupApiProvider).updateChannel(
            gid,
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
          );
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.of(context).channelUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar(int gid) async {
    setState(() => _uploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await ref.read(groupApiProvider).uploadAvatar(gid, bytes);
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.of(context).avatarUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeType(int gid, bool isPublic) async {
    try {
      await ref.read(groupApiProvider).changeType(gid: gid, isPublic: isPublic);
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppL10n.of(context).channelVisibilityChanged)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  Future<void> _toggleMute(int gid) async {
    final muteNotifier = ref.read(mutedChatsProvider.notifier);
    final isMuted = muteNotifier.isGroupMuted(gid);
    try {
      final api = ref.read(sessionActionsApiProvider);
      if (isMuted) {
        await api.unmuteGroup(gid);
        muteNotifier.unmuteGroup(gid);
      } else {
        await api.muteGroup(gid);
        muteNotifier.muteGroup(gid);
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  Future<void> _generateInviteLink(int gid, bool isPublic) async {
    setState(() => _generatingLink = true);
    try {
      final api = ref.read(groupApiProvider);
      final link = isPublic
          ? await api.createInviteLink(gid: gid)
          : await api.createPrivateInviteLink(gid: gid);
      if (mounted) setState(() => _inviteLink = link);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    } finally {
      if (mounted) setState(() => _generatingLink = false);
    }
  }

  Future<void> _copyInviteLink() async {
    if (_inviteLink == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).inviteLinkCopied)));
    }
  }

  Future<void> _addMember(int gid, int uid) async {
    try {
      await ref.read(groupApiProvider).addMembers(gid, [uid]);
      await ref.read(groupDirectoryProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  Future<void> _removeMember(int gid, int uid) async {
    try {
      await ref.read(groupApiProvider).removeMembers(gid, [uid]);
      await ref.read(groupDirectoryProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  Future<void> _confirmLeave(int gid) async {
    final l = AppL10n.of(context);
    final ok = await showVoceConfirm(
      context: context,
      title: l.chatListLeave,
      body: l.channelLeaveConfirmBody,
      confirmLabel: l.actionLeave,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(sessionActionsApiProvider).leaveGroup(gid);
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  Future<void> _confirmDelete(int gid) async {
    final l = AppL10n.of(context);
    final ok = await showVoceConfirm(
      context: context,
      title: l.channelDeleteTitle,
      body: l.channelDeleteConfirmBody,
      confirmLabel: l.chatActionDelete,
      cancelLabel: l.actionCancel,
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(groupApiProvider).deleteChannel(gid);
      await ref.read(groupDirectoryProvider.notifier).refresh();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(safeText(_friendlyError(e)))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final gid = widget.gid;
    final groupDir = ref.watch(groupDirectoryProvider).valueOrNull ?? const {};
    final group = groupDir[gid];
    final userDir = ref.watch(userDirectoryProvider).valueOrNull ?? const {};
    final authState = ref.watch(authControllerProvider).valueOrNull;
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.uid : -1;
    final isAdmin =
        authState is AuthStateAuthenticated ? authState.user.isAdmin : false;
    final serverState = ref.watch(serverStoreProvider).valueOrNull;
    final baseUrl = serverState?.servers
            .where((s) => s.id == serverState.currentServerId)
            .firstOrNull
            ?.baseUrl ??
        '';
    final isMuted = ref.watch(mutedChatsProvider).isGroupMuted(gid);

    if (group == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.channelSettingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _initFromGroup(group);

    final canManage = isAdmin || group.owner == currentUid;
    final canLeave = !group.isPublic;

    String? avatarUrl;
    if ((group.avatarUpdatedAt ?? 0) > 0 && baseUrl.isNotEmpty) {
      avatarUrl =
          '$baseUrl/api/resource/group_avatar?gid=$gid&t=${group.avatarUpdatedAt}';
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.channelSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Stack(
                  children: [
                    VoceAvatar(
                        name: safeText(group.name),
                        imageUrl: avatarUrl,
                        size: 80),
                    if (canManage)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _uploadingAvatar
                              ? null
                              : () => _pickAndUploadAvatar(gid),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTokens.primary500,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppTokens.surface, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SectionHeader(title: l.channelOverview),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _nameCtrl,
                  enabled: canManage,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: InputDecoration(labelText: l.channelNameLabel),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  enabled: canManage,
                  maxLines: 3,
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: InputDecoration(
                      labelText: l.channelDescriptionLabel),
                ),
                if (canManage) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(l.channelPublicLabel,
                            style: TextStyle(color: AppTokens.gray700)),
                      ),
                      Switch.adaptive(
                        value: group.isPublic,
                        onChanged: isAdmin
                            ? (v) => _changeType(gid, v)
                            : null,
                      ),
                    ],
                  ),
                ],
                if (_dirty && canManage) ...[
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: l.channelSaveChanges,
                    isLoading: _saving,
                    onPressed: () => _saveOverview(gid),
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(title: l.chatToolMembers),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final uid in group.isPublic
                    ? userDir.keys.toList(growable: false)
                    : group.members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: VoceAvatar(
                        name: safeText(userDir[uid]?.name ?? '?'), size: 36),
                    title: Text(safeText(
                        userDir[uid]?.name ?? l.chatUserFallback(uid))),
                    subtitle: uid == group.owner
                        ? Text(l.memberRoleOwner)
                        : null,
                    trailing: (!group.isPublic &&
                            canManage &&
                            uid != group.owner &&
                            uid != currentUid)
                        ? IconButton(
                            icon: Icon(Icons.person_remove_outlined,
                                size: 18, color: AppTokens.error),
                            onPressed: () => _removeMember(gid, uid),
                          )
                        : null,
                  ),
                if (!group.isPublic && canManage)
                  _AddMemberRow(
                    gid: gid,
                    existingMembers: group.members,
                    userDir: userDir,
                    onAdd: (uid) => _addMember(gid, uid),
                  ),
              ],
            ),
          ),
          if (canManage) ...[
            SectionHeader(title: l.channelInviteLinkSection),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_inviteLink != null)
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(_inviteLink!,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 13, color: AppTokens.gray600)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: _copyInviteLink,
                        ),
                      ],
                    ),
                  PrimaryButton(
                    label: l.channelGenerateInviteLink,
                    isLoading: _generatingLink,
                    onPressed: () =>
                        _generateInviteLink(gid, group.isPublic),
                  ),
                ],
              ),
            ),
          ],
          SectionHeader(title: l.settingsNotifications),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.channelMuteLabel,
                      style: TextStyle(color: AppTokens.gray700)),
                ),
                Switch.adaptive(
                  value: isMuted,
                  onChanged: (_) => _toggleMute(gid),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (canLeave)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.logout, color: AppTokens.error),
                    title: Text(l.chatListLeave,
                        style: TextStyle(color: AppTokens.error)),
                    onTap: () => _confirmLeave(gid),
                  ),
                if (canManage)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.delete_outline, color: AppTokens.error),
                    title: Text(l.channelDeleteTitle,
                        style: TextStyle(color: AppTokens.error)),
                    onTap: () => _confirmDelete(gid),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Small inline "add member" row — dropdown-style picker filtered to users
/// not already in the channel.
class _AddMemberRow extends StatelessWidget {
  const _AddMemberRow({
    required this.gid,
    required this.existingMembers,
    required this.userDir,
    required this.onAdd,
  });

  final int gid;
  final List<int> existingMembers;
  final Map<int, UserSummary> userDir;
  final ValueChanged<int> onAdd;

  @override
  Widget build(BuildContext context) {
    final candidates = userDir.values
        .where((u) => !existingMembers.contains(u.uid))
        .toList();
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration:
                  InputDecoration(labelText: AppL10n.of(context).channelAddMember),
              items: [
                for (final u in candidates)
                  DropdownMenuItem(value: u.uid, child: Text(safeText(u.name))),
              ],
              onChanged: (uid) {
                if (uid != null) onAdd(uid);
              },
            ),
          ),
        ],
      ),
    );
  }
}
