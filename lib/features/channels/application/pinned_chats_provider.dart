import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../messages/data/message_cache.dart';
import '../domain/pin_chat_models.dart';

part 'pinned_chats_provider.g.dart';

// ---------------------------------------------------------------------------
// PinnedChats notifier
// ---------------------------------------------------------------------------
//
// Owns the list of `PinChat` for the logged-in user. Mirrors the web client's
// `footprint.pinChats` slice:
//
//   * `setAll`    — replaces the list (used by the `user_settings` snapshot
//                   that arrives right after connecting).
//   * `upsertAll` — adds/refreshes pins (used by `user_settings_changed`'s
//                   `add_pin_chats`). De-duplicates by target; the latest
//                   `updated_at` wins so the head of the pinned section moves
//                   to top when the user re-pins.
//   * `removeAll` — drops pins (used by `remove_pin_chats`).
//
// State is persisted to the `meta` table in MessageCache so cold-start paints
// pinned chats at the top without waiting for the SSE `user_settings` event.

@Riverpod(keepAlive: true)
class PinnedChats extends _$PinnedChats {
  MessageCache? _cache;

  @override
  Future<List<PinChat>> build() async {
    final cache = await ref.watch(messageCacheProvider.future);
    _cache = cache;
    final raw = await cache.readPinnedChats();
    if (raw == null || raw.isEmpty) return const [];
    final pins = raw
        .map(PinChat.fromJson)
        .whereType<PinChat>()
        .toList();
    return _sorted(pins);
  }

  /// Replace the entire pin list. Called for the `pinned_chats` field of the
  /// initial `user_settings` SSE envelope.
  void setAll(List<PinChat> pins) {
    state = AsyncData(_sorted(pins));
    _persist();
  }

  /// Add or refresh the given pins. Existing entries with the same target are
  /// replaced (so a re-pin bumps `updated_at`).
  void upsertAll(List<PinChat> pins) {
    if (pins.isEmpty) return;
    final current = state.valueOrNull ?? const <PinChat>[];
    final byTarget = <PinChatTarget, PinChat>{
      for (final p in current) p.target: p,
    };
    for (final p in pins) {
      byTarget[p.target] = p;
    }
    state = AsyncData(_sorted(byTarget.values.toList()));
    _persist();
  }

  /// Drop pins whose target matches any in [targets].
  void removeAll(List<PinChatTarget> targets) {
    if (targets.isEmpty) return;
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    final drop = targets.toSet();
    final next = current.where((p) => !drop.contains(p.target)).toList();
    if (next.length == current.length) return;
    state = AsyncData(next);
    _persist();
  }

  /// True if the given conversation key is currently pinned. Cheap O(n) — the
  /// pinned set is expected to stay small (single digits).
  bool isPinned(PinChatTarget target) {
    final list = state.valueOrNull;
    if (list == null) return false;
    for (final p in list) {
      if (p.target == target) return true;
    }
    return false;
  }

  Timer? _persistTimer;
  static const _persistDebounce = Duration(milliseconds: 250);

  void _persist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      _persistTimer = null;
      final cache = _cache;
      final value = state.valueOrNull;
      if (cache == null || value == null) return;
      cache.writePinnedChats(value.map((p) => p.toJson()).toList());
    });
  }

  /// Sort by `updated_at` desc — newest-pinned first, matching the web
  /// reference where `add_pin_chats` prepends.
  static List<PinChat> _sorted(List<PinChat> pins) {
    final out = List<PinChat>.from(pins);
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }
}
