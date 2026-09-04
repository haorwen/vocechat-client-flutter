import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/sse_client.dart';
import '../../../core/utils/app_log.dart';
import '../../auth/application/auth_controller.dart';
import '../../channels/application/conversation_providers.dart';
import '../../channels/application/muted_chats_provider.dart';
import '../../channels/application/pinned_chats_provider.dart';
import '../../channels/domain/pin_chat_models.dart';
import '../../contacts/application/presence_provider.dart';
import '../../contacts/application/user_directory_provider.dart';
import '../data/message_cache.dart';
import '../domain/message_models.dart';
import '../../voice/application/incoming_call_provider.dart';
import 'burn_after_read_provider.dart';
import 'chat_controller.dart';
import 'reactions_provider.dart';
import 'read_index_provider.dart';

part 'message_dispatcher.g.dart';

/// Long-lived listener that routes every incoming SSE chat event to:
///   1. the conversations list (so previews update on the left),
///   2. the per-target ChatController (so the chat screen has the message
///      ready the moment it's opened, even if it had never been opened
///      before — and stays in sync while it's in the background), and
///   3. the presence / show-online-status providers (so DM avatars reflect
///      the actual online state, mirroring the web client's `useStreaming`
///      handler for `users_state` / `users_state_changed` /
///      `server_config_changed`).
///
/// Kept alive for the entire app lifetime so it does NOT depend on any
/// screen being mounted.
@Riverpod(keepAlive: true)
class MessageDispatcher extends _$MessageDispatcher {
  @override
  void build() {
    ref.listen(sseEventsProvider, (_, next) {
      next.whenData((event) {
        if (event is ChatEventChat) {
          final msg = event.message;

          // Reaction events arrive as chat messages with type=reaction.
          // Route them to the reactions provider; do NOT add them to chat
          // history (they're not displayable on their own — they mutate the
          // target message's reaction set).
          final detail = msg.detail;
          if (detail is ReactionMessageDetail) {
            _handleReaction(msg, detail);
            return;
          }

          // Persist EVERY incoming chat message to the cache the moment it
          // arrives — not when the user opens the chat screen. This is what
          // makes "open a chat for the first time and immediately see the
          // latest messages" work: the cache is the single source of truth
          // for [ChatController.build], so by the time the user navigates
          // in, the freshest messages are already on disk.
          //
          // Schedule before touching conversations so a build() that races
          // this microtask still observes the row.
          //
          // We also bump the SSE cursor here so a relaunch right after this
          // call doesn't replay messages we've already durably stored.
          final cacheAsync = ref.read(messageCacheProvider);
          final cache = cacheAsync.valueOrNull;
          if (cache != null) {
            // Fire-and-forget — appendOne handles its own errors.
            // Use the peer-resolved target, not the raw server-perspective
            // `msg.target` — for an incoming DM, `msg.target` is always
            // ourselves, so caching under it would file the message into a
            // "chat with self" row instead of the actual peer conversation.
            cache.appendOne(_conversationTargetFor(msg), msg);
            if (msg.mid > 0) cache.setCursor(msg.mid);
          }

          // Update the conversation list preview/timestamp.
          ref
              .read(conversationsProvider.notifier)
              .applyIncomingMessage(msg);

          // NOTE: We intentionally do NOT touch chatControllerProvider here.
          // Each ChatController.build() already does `ref.listen(
          // sseEventsProvider, ...)` for its target, so any mounted chat
          // screen receives the message directly from SSE. Forcing
          // `ref.read(chatControllerProvider(msg.target).notifier)` for
          // every incoming message would spawn a fresh controller for every
          // target that ever appeared in an SSE replay — on a cold start
          // with `after_mid` catch-up that replays hundreds of messages
          // across dozens of targets, this snowballs into hundreds of
          // concurrent provider builds, each awaiting messageCache + disk
          // reads, and saturates the microtask queue until the UI hangs.
          // Unbuilt controllers catch up via the cache write above the next
          // time the user opens the screen.
          return;
        }
        if (event is ChatEventServerConfigChanged) {
          final flag = event.data['show_user_online_status'];
          if (flag is bool) {
            ref.read(showOnlineStatusProvider.notifier).set(flag);
          }
          return;
        }
        if (event is ChatEventUserSettings) {
          _applyPinnedChatsSnapshot(event.data);
          _applyReadIndexSnapshot(event.data);
          _applyMuteSnapshot(event.data);
          _applyBurnAfterReadSnapshot(event.data);
          return;
        }
        if (event is ChatEventUserSettingsChanged) {
          _applyPinnedChatsDelta(event.data);
          _applyReadIndexDelta(event.data);
          _applyMuteDelta(event.data);
          _applyBurnAfterReadDelta(event.data);
          return;
        }
        if (event is ChatEventKick) {
          _handleKick(event.reason);
          return;
        }
        if (event is ChatEventUnknown && (event.type == 'user_changed' || event.type == 'user_updated' || event.type == 'avo_changed')) {
          final decoded = _decode(event.raw);
          if (decoded != null) {
            unawaited(ref.read(userDirectoryProvider.notifier).applyUserUpdate(decoded));
          }
          return;
        }
        if (event is ChatEventUserCalling) {
          ref.read(incomingCallProvider.notifier).set(
                fromUid: event.uid,
                toUid: event.target,
                calling: true,
              );
          return;
        }
        if (event is ChatEventUnknown) {
          switch (event.type) {
            case 'users_state':
              final decoded = _decode(event.raw);
              final users = decoded?['users'];
              if (users is List) {
                ref.read(presenceProvider.notifier).applySnapshot(
                      users
                          .whereType<Map>()
                          .map((m) => Map<String, dynamic>.from(m))
                          .toList(),
                    );
              }
              break;
            case 'users_state_changed':
              final decoded = _decode(event.raw);
              if (decoded == null) break;
              final uid = (decoded['uid'] as num?)?.toInt();
              if (uid == null) break;
              final online = decoded['online'] == true;
              ref.read(presenceProvider.notifier).applyChange(uid, online);
              break;
          }
        }
      });
    });
  }

  /// Initial `user_settings` snapshot: replace the pinned-chats list with
  /// whatever the server says. Mirrors the web reference's
  /// `upsertPinChats({ pins, override: true })`.
  void _applyPinnedChatsSnapshot(Map<String, dynamic> data) {
    final raw = data['pinned_chats'];
    if (raw is! List) return;
    final pins = raw
        .whereType<Map>()
        .map((m) => PinChat.fromJson(Map<String, dynamic>.from(m)))
        .whereType<PinChat>()
        .toList();
    ref.read(pinnedChatsProvider.notifier).setAll(pins);
  }

  /// Delta `user_settings_changed`: apply `add_pin_chats` / `remove_pin_chats`
  /// without touching the rest of the pinned list.
  void _applyPinnedChatsDelta(Map<String, dynamic> data) {
    final add = data['add_pin_chats'];
    if (add is List && add.isNotEmpty) {
      final pins = add
          .whereType<Map>()
          .map((m) => PinChat.fromJson(Map<String, dynamic>.from(m)))
          .whereType<PinChat>()
          .toList();
      if (pins.isNotEmpty) {
        ref.read(pinnedChatsProvider.notifier).upsertAll(pins);
      }
    }
    final remove = data['remove_pin_chats'];
    if (remove is List && remove.isNotEmpty) {
      final targets = remove
          .whereType<Map>()
          .map((m) => PinChatTarget.fromJson(Map<String, dynamic>.from(m)))
          .whereType<PinChatTarget>()
          .toList();
      if (targets.isNotEmpty) {
        ref.read(pinnedChatsProvider.notifier).removeAll(targets);
      }
    }
  }

  /// Read-index snapshot from `user_settings`: replace the markers wholesale.
  void _applyReadIndexSnapshot(Map<String, dynamic> data) {
    final users = _parseReadIndex(data['read_index_users'], 'uid');
    final groups = _parseReadIndex(data['read_index_groups'], 'gid');
    ref.read(readIndexProvider.notifier).applySnapshot(users, groups);
  }

  /// Read-index delta from `user_settings_changed` (e.g. another device marked
  /// a chat read): max-merge the markers forward.
  void _applyReadIndexDelta(Map<String, dynamic> data) {
    final users = _parseReadIndex(data['read_index_users'], 'uid');
    final groups = _parseReadIndex(data['read_index_groups'], 'gid');
    if (users.isEmpty && groups.isEmpty) return;
    ref.read(readIndexProvider.notifier).applyDelta(users, groups);
  }

  /// Parse a `[{<idKey>, mid}]` list into an `{id: mid}` map. Tolerates a
  /// missing/malformed list (returns empty).
  Map<int, int> _parseReadIndex(dynamic raw, String idKey) {
    if (raw is! List) return {};
    final out = <int, int>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final id = (e[idKey] as num?)?.toInt();
      final mid = (e['mid'] as num?)?.toInt();
      if (id != null && mid != null) out[id] = mid;
    }
    return out;
  }

  /// Burn-after-read snapshot from `user_settings`: replace wholesale.
  void _applyBurnAfterReadSnapshot(Map<String, dynamic> data) {
    final users = _parseBurnAfterReading(data['burn_after_reading_users'], 'uid');
    final groups = _parseBurnAfterReading(data['burn_after_reading_groups'], 'gid');
    ref.read(burnAfterReadProvider.notifier).applySnapshot(users, groups);
  }

  /// Burn-after-read delta from `user_settings_changed` (e.g. changed on
  /// another device): per-entry upsert/remove based on `expires_in`.
  void _applyBurnAfterReadDelta(Map<String, dynamic> data) {
    final users = _parseBurnAfterReading(data['burn_after_reading_users'], 'uid');
    final groups = _parseBurnAfterReading(data['burn_after_reading_groups'], 'gid');
    if (users.isEmpty && groups.isEmpty) return;
    ref.read(burnAfterReadProvider.notifier).applyDelta(users, groups);
  }

  /// Parse a `[{<idKey>, expires_in}]` list into an `{id: expiresIn}` map.
  Map<int, int> _parseBurnAfterReading(dynamic raw, String idKey) {
    if (raw is! List) return {};
    final out = <int, int>{};
    for (final e in raw) {
      if (e is! Map) continue;
      final id = (e[idKey] as num?)?.toInt();
      final expiresIn = (e['expires_in'] as num?)?.toInt();
      if (id != null && expiresIn != null) out[id] = expiresIn;
    }
    return out;
  }

  /// Mute snapshot from `user_settings`: `mute_users` / `mute_groups` are lists
  /// of `{uid|gid, expired_at?}`. Replace the local mute set wholesale.
  void _applyMuteSnapshot(Map<String, dynamic> data) {
    final users = _parseMuteIds(data['mute_users'], 'uid');
    final groups = _parseMuteIds(data['mute_groups'], 'gid');
    ref.read(mutedChatsProvider.notifier).applySnapshot(
          users: users.toSet(),
          groups: groups.toSet(),
        );
  }

  /// Mute delta from `user_settings_changed`: `add_mute_users` /
  /// `add_mute_groups` are `{uid|gid, expired_at?}` lists; `remove_mute_users`
  /// / `remove_mute_groups` are plain id lists.
  void _applyMuteDelta(Map<String, dynamic> data) {
    final addUsers = _parseMuteIds(data['add_mute_users'], 'uid');
    final addGroups = _parseMuteIds(data['add_mute_groups'], 'gid');
    final removeUsers = _parsePlainIds(data['remove_mute_users']);
    final removeGroups = _parsePlainIds(data['remove_mute_groups']);
    if (addUsers.isEmpty &&
        addGroups.isEmpty &&
        removeUsers.isEmpty &&
        removeGroups.isEmpty) {
      return;
    }
    ref.read(mutedChatsProvider.notifier).applyDelta(
          addUsers: addUsers,
          addGroups: addGroups,
          removeUsers: removeUsers,
          removeGroups: removeGroups,
        );
  }

  /// Parse a `[{<idKey>, expired_at?}]` list into a list of ids.
  List<int> _parseMuteIds(dynamic raw, String idKey) {
    if (raw is! List) return const [];
    final out = <int>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final id = (e[idKey] as num?)?.toInt();
      if (id != null) out.add(id);
    }
    return out;
  }

  /// Parse a plain `[<int>]` id list.
  List<int> _parsePlainIds(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<num>().map((n) => n.toInt()).toList();
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }

  /// Server-initiated kick. Mirrors the web reference's `case "kick"` block
  /// in `useStreaming.ts`: clear auth state so the router boots us back to
  /// the login screen, and surface the reason so the next screen can toast.
  ///
  /// Known reasons (from the Rust server source):
  ///   - `login_from_other_device` — same account signed in elsewhere
  ///   - `delete_user` — account deleted by admin
  ///   - other strings should still result in logout (fail-safe)
  void _handleKick(String? reason) {
    AppLog.w(LogTag.sse, () => '👢 SSE kick received: reason=$reason');
    ref.read(kickReasonProvider.notifier).set(reason);
    // Fire-and-forget logout: tokens get wiped, auth state flips to
    // unauthenticated, and the GoRouter redirect chain sends the user to
    // /login. The SSE provider will tear down on its own when auth flips.
    Future.microtask(() => ref.read(authControllerProvider.notifier).logout());
  }

  /// Dispatch a reaction-type chat message:
  ///   - `like` → toggle the emoji on the target message
  ///   - `delete` → remove the target message from chat + strip its reactions
  ///   - `edit` → patch the target message's content in chat
  void _handleReaction(ChatMessage msg, ReactionMessageDetail detail) {
    final inner = detail.detail;
    final type = inner['type'];
    // Resolve the *conversation-scoped* target for ChatController. In DMs,
    // `msg.target` is always the recipient, so when an edit/delete echo
    // arrives for the other end of the conversation we'd otherwise route to a
    // ChatController keyed on our own uid — which isn't the one the chat
    // screen is mounted against. Translate to the peer's uid when we are the
    // recipient. Group targets are already symmetric and don't need this.
    final chatTarget = _conversationTargetFor(msg);
    if (type == 'like') {
      final action = inner['action'];
      if (action is String && action.isNotEmpty) {
        ref.read(reactionsProvider.notifier).applyLike(
              reactionMid: msg.mid,
              targetMid: detail.mid,
              fromUid: msg.fromUid,
              emoji: action,
            );
      }
    } else if (type == 'delete') {
      ref.read(reactionsProvider.notifier).removeFor(detail.mid);
      ref
          .read(chatControllerProvider(chatTarget).notifier)
          .applyDeleteEcho(detail.mid);
      ref
          .read(conversationsProvider.notifier)
          .applyDeleteEcho(msg.target, detail.mid, fromUid: msg.fromUid);
    } else if (type == 'edit') {
      final content = inner['content'];
      final contentType = inner['content_type'];
      if (content is String && contentType is String) {
        ref
            .read(chatControllerProvider(chatTarget).notifier)
            .applyEditEcho(detail.mid, content, contentType);
        ref
            .read(conversationsProvider.notifier)
            .applyEditEcho(msg.target, detail.mid, content,
                fromUid: msg.fromUid);
      }
    }
  }

  /// Translate a server-perspective [ChatMessage.target] into the
  /// conversation-scoped target the chat screen mounts against. Group targets
  /// pass through unchanged; DM targets are flipped to the peer's uid when
  /// the recipient is ourselves (i.e. an incoming event), matching the same
  /// rule used by `ChatController.applyIncomingMessage` and the conversation
  /// list peer-resolution logic.
  MessageTarget _conversationTargetFor(ChatMessage msg) {
    return msg.target.map(
      user: (t) {
        final authState = ref.read(authControllerProvider).valueOrNull;
        final currentUid =
            authState is AuthStateAuthenticated ? authState.user.uid : null;
        final peerUid =
            currentUid != null && msg.fromUid != currentUid && t.uid == currentUid
                ? msg.fromUid
                : t.uid;
        return MessageTarget.user(uid: peerUid);
      },
      group: (t) => MessageTarget.group(gid: t.gid),
    );
  }
}

/// Last-seen kick reason from a server `kick` event. Login screen / banner
/// reads this to surface a toast ("kicked from another device" / "your
/// account has been deleted"). `null` when there is no pending reason.
/// Set back to `null` by the consumer after displaying.
@Riverpod(keepAlive: true)
class KickReason extends _$KickReason {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? reason) => state = reason;

  void clear() => state = null;
}
