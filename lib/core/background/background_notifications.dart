import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/channels/application/muted_chats_provider.dart';
import '../../features/channels/application/conversation_providers.dart';
import '../../features/contacts/application/user_directory_provider.dart';
import '../../features/messages/data/message_cache.dart';
import '../../features/messages/domain/message_models.dart';
import '../storage/account_store.dart';
import '../utils/app_log.dart';
import '../utils/safe_text.dart';
import 'background_lifecycle.dart';
import 'background_preferences.dart';

/// Pure eligibility policy, shared by delivery and tests. Reaction echoes and
/// expired/self messages must never produce a new-message notification.
bool shouldNotifyBackgroundMessage(
  ChatMessage message, {
  required bool enabled,
  required bool backgrounded,
  required int selfUid,
  required MutedChatsState muted,
  required int now,
  bool mentionsOnly = false,
}) {
  if (!enabled ||
      !backgrounded ||
      message.mid <= 0 ||
      message.fromUid == selfUid ||
      message.detail is ReactionMessageDetail ||
      message.isExpiredAt(now)) {
    return false;
  }
  final properties = message.detail.map(
      normal: (d) => d.properties,
      reply: (d) => d.properties,
      reaction: (_) => null);
  final mentions = properties?['mentions'];
  final mentioned = mentions is List && mentions.contains(selfUid);
  return message.target.map(
    user: (_) => !muted.isUserMuted(message.fromUid),
    group: (target) =>
        (mentioned || !muted.isGroupMuted(target.gid)) &&
        (!mentionsOnly || mentioned),
  );
}

// One disposal guard per dispatcher lifetime, rather than one callback per message.
final _notificationDeliveryAliveProvider = Provider<bool Function()>((ref) {
  var alive = true;
  ref.onDispose(() => alive = false);
  return () => alive;
});

String? _notificationName(String? value) {
  final name = safeText(value).trim();
  return name.isEmpty ? null : name;
}

/// Resolve existing data only: notification delivery must not start directory
/// network refreshes or build a controller for each conversation in a replay.
Future<({String title, String? sender})> _notificationNames(
    Ref ref, ChatMessage message) async {
  final groupId =
      message.target.maybeMap(group: (t) => t.gid, orElse: () => null);
  String? sender;
  String? group;
  if (ref.exists(userDirectoryProvider)) {
    final users = ref.read(userDirectoryProvider);
    // AsyncValue may retain the previous account's data during a rebuild.
    if (!users.isLoading) {
      sender = _notificationName(users.valueOrNull?[message.fromUid]?.name);
    }
  }
  if (groupId != null && ref.exists(groupDirectoryProvider)) {
    final groups = ref.read(groupDirectoryProvider);
    if (!groups.isLoading) {
      group = _notificationName(groups.valueOrNull?[groupId]?.name);
    }
  }
  if (ref.exists(conversationsProvider)) {
    final conversations = ref.read(conversationsProvider);
    if (!conversations.isLoading) {
      for (final item
          in conversations.valueOrNull ?? const <ConversationItem>[]) {
        if (item.key == UserConversationKey(message.fromUid)) {
          sender ??= _notificationName(item.name);
        }
        if (groupId != null && item.key == GroupConversationKey(groupId)) {
          group ??= _notificationName(item.name);
        }
      }
    }
  }
  if (sender == null || (groupId != null && group == null)) {
    // Capture the account-scoped cache before yielding; no later lookup may
    // resolve a different account's cache if the user switches while awaiting.
    final cacheFuture = ref.read(messageCacheProvider.future);
    try {
      final cache = await cacheFuture;
      if (sender == null) {
        final users = await cache.readUserDirectory();
        for (final user in users ?? const <Map<String, dynamic>>[]) {
          if (user['uid'] == message.fromUid) {
            sender = _notificationName(user['name'] as String?);
          }
        }
      }
      if (groupId != null && group == null) {
        final groups = await cache.readGroupDirectory();
        for (final item in groups ?? const <Map<String, dynamic>>[]) {
          if (item['gid'] == groupId) {
            group = _notificationName(item['name'] as String?);
          }
        }
      }
    } catch (error) {
      AppLog.d(
          LogTag.general, () => 'Notification name cache unavailable: $error');
    }
  }
  return (
    title: groupId == null
        ? sender ?? '#${message.fromUid}'
        : group ?? '#$groupId',
    sender: sender
  );
}

/// Called before the dispatcher persists the event; no additional connection,
/// attachment download, user-directory fetch, or per-chat controller is needed.
void deliverBackgroundNotification(Ref ref, ChatMessage message) {
  if (!isAndroidBackgroundSupported) return;
  final auth = ref.read(authControllerProvider).valueOrNull;
  if (auth is! AuthStateAuthenticated) return;
  final status = ref.read(backgroundPreferencesProvider).valueOrNull;
  // Foreground and intentionally filtered messages consume the SAME receipt,
  // so a replay cannot alert after the user has already seen it.
  if (message.mid <= 0 ||
      message.fromUid == auth.user.uid ||
      message.detail is ReactionMessageDetail) {
    return;
  }
  final backgrounded = ref.read(androidBackgroundedProvider);
  final eligible = shouldNotifyBackgroundMessage(message,
      enabled: status?.pushEnabled ?? true,
      backgrounded: true,
      mentionsOnly: status?.mentionsOnly == true,
      selfUid: auth.user.uid,
      muted: ref.read(mutedChatsProvider),
      now: DateTime.now().millisecondsSinceEpoch);
  // With keep-alive disabled, an eligible background message belongs to FCM.
  if (backgrounded && eligible && status?.enabled != true) return;
  final properties = message.detail.map(
      normal: (d) => d.properties,
      reply: (d) => d.properties,
      reaction: (_) => null);
  final mentions = properties?['mentions'];
  final session = ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
  if (session == null) return;
  final target = message.target
      .map(user: (_) => 'u-${message.fromUid}', group: (t) => 'g-${t.gid}');
  // Hide attachment URLs/metadata in the system shade; no media is loaded.
  final content = message.displayContentType.startsWith('text/') &&
          (message.displayContentType == 'text/plain' ||
              message.displayContentType == 'text/markdown')
      ? message.displayContent
      : '📎';
  final alive = ref.read(_notificationDeliveryAliveProvider);
  Future<void> send() async {
    // Silent receipts need no directory/cache work; persist promptly so a
    // replay cannot alert after a foreground message was already seen.
    final names = backgrounded && eligible
        ? await _notificationNames(ref, message)
        : (title: 'VoceChat', sender: null);
    if (!alive() ||
        ref.read(accountStoreProvider).valueOrNull?.currentAccountId !=
            session ||
        ref.read(authControllerProvider).valueOrNull
            is! AuthStateAuthenticated) {
      return;
    }
    final body = message.target is MessageTargetGroup
        ? '${names.sender ?? '#${message.fromUid}'}: $content'
        : content;
    await backgroundChannel.invokeMethod('notify', {
      'session': session,
      'mid': message.mid,
      'target': target,
      'createdAt': message.createdAt,
      'expiresAt': message.expiresAt,
      'present': backgrounded && status?.enabled == true,
      'eligible': eligible,
      'mentioned': mentions is List && mentions.contains(auth.user.uid),
      'title': names.title,
      'body': body.length > 240 ? '${body.substring(0, 240)}…' : body,
    });
  }

  unawaited(send().catchError((Object error) {
    AppLog.w(
        LogTag.general, () => 'Background notification unavailable: $error');
  }));
}
