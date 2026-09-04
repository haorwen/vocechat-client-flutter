import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/storage/account_store.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/storage/server_store.dart';
import '../../messages/domain/message_models.dart';
import '../data/avo_realtime_client.dart';
import '../../../shared/models/avo_interaction.dart';
part 'avo_interaction_controller.g.dart';

@Riverpod(keepAlive: true)
class AvoInteractionController extends _$AvoInteractionController {
  AvoRealtimeClient? _client;
  final _pointerExpiry = <int, Timer>{};
  MessageTarget? _room;
  int _seq = 0;
  DateTime? _lastPointer;
  DateTime? _lastPet;
  final _seenEventIds = <String>{};
  final _lastSeqByUid = <int, int>{};
  int _roomGeneration = 0;

  @override
  Map<int, RemoteAvoInteraction> build() {
    ref.onDispose(() {
      unawaited(_client?.close());
      for (final timer in _pointerExpiry.values) {
        timer.cancel();
      }
      _pointerExpiry.clear();
    });
    return const {};
  }

  Future<void> joinRoom(MessageTarget room) async {
    if (_room == room && _client != null) return;
    await leaveRoom();
    final generation = _roomGeneration;
    final server = ref.read(serverStoreProvider).valueOrNull;
    final current = server?.servers
        .where((s) => s.id == server.currentServerId)
        .firstOrNull;
    final account =
        ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
    if (current == null || account == null) return;
    final tokenStore = ref.read(secureTokenStoreProvider(account));
    final token = await tokenStore.readTokens();
    if (token == null || generation != _roomGeneration) return;
    final roomType = room.map(user: (_) => 'dm', group: (_) => 'group');
    final roomId = room.map(user: (v) => v.uid, group: (v) => v.gid);
    final client = AvoRealtimeClient(
      baseUrl: current.baseUrl,
      apiKey: token.accessToken,
      apiKeyProvider: () async => (await tokenStore.readTokens())?.accessToken,
      roomType: roomType,
      roomId: roomId,
      onEvent: (event) => _handleEvent(event, generation),
    );
    if (generation != _roomGeneration) {
      await client.close();
      return;
    }
    _room = room;
    _client = client;
    await client.connect();
    if (generation != _roomGeneration && identical(_client, client)) {
      _client = null;
      await client.close();
    }
  }

  Future<void> leaveRoom() async {
    _roomGeneration++;
    for (final timer in _pointerExpiry.values) {
      timer.cancel();
    }
    _pointerExpiry.clear();
    final old = _client;
    _client = null;
    _room = null;
    state = const {};
    _lastSeqByUid.clear();
    _seenEventIds.clear();
    _seq = 0;
    _lastPointer = null;
    _lastPet = null;
    if (old != null) await old.close();
  }

  void sendLocal(AvoLocalInteraction interaction) {
    final client = _client;
    if (client == null) return;
    final now = DateTime.now();
    if (interaction.type == AvoInteractionType.pointer) {
      if (_lastPointer != null &&
          now.difference(_lastPointer!) < const Duration(milliseconds: 50)) {
        return;
      }
      _lastPointer = now;
    } else if (interaction.type == AvoInteractionType.pet) {
      if (_lastPet != null &&
          now.difference(_lastPet!) < const Duration(milliseconds: 250)) {
        return;
      }
      _lastPet = now;
    }
    _seq++;
    client.send(interaction,
        seq: _seq,
        eventId: '${now.microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}');
  }

  void _handleEvent(Map<String, dynamic> event, int generation) {
    if (generation != _roomGeneration) return;
    if (event['type'] != 'avo_interaction') return;
    final uid = (event['from_uid'] as num?)?.toInt();
    final kind = event['event']?.toString();
    if (uid == null || kind == null) return;
    final seq = (event['seq'] as num?)?.toInt() ?? 0;
    if (seq > 0) {
      if (seq <= (_lastSeqByUid[uid] ?? 0)) return;
      _lastSeqByUid[uid] = seq;
    }
    if (kind == 'pointer' || kind == 'pointer_leave') {
      if (kind == 'pointer_leave') {
        _update(
            uid, (old) => RemoteAvoInteraction(pop: old?.pop, pet: old?.pet));
      } else {
        final pointer = AvoPointer(
          x: (event['x'] as num?)?.toDouble() ?? 0,
          y: (event['y'] as num?)?.toDouble() ?? 0,
          speed: (event['speed'] as num?)?.toDouble() ?? 0,
          inside: event['inside'] == true,
          seq: seq,
        ).normalized(seq: seq);
        _update(
            uid,
            (old) => RemoteAvoInteraction(
                pointer: pointer, pop: old?.pop, pet: old?.pet));
        _pointerExpiry[uid]?.cancel();
        _pointerExpiry[uid] = Timer(const Duration(milliseconds: 800), () {
          final current = state[uid];
          if (current?.pointer?.seq == seq) {
            _update(uid,
                (old) => RemoteAvoInteraction(pop: old?.pop, pet: old?.pet));
          }
          _pointerExpiry.remove(uid);
        });
      }
      return;
    }
    if (kind != 'pop' && kind != 'pet') return;
    final eventId = event['event_id']?.toString();
    if (eventId == null || !_seenEventIds.add(eventId)) return;
    if (_seenEventIds.length > 256) {
      _seenEventIds.remove(_seenEventIds.first);
    }
    final pulse = AvoPulse(eventId: eventId, receivedAt: DateTime.now());
    _update(
        uid,
        (old) => RemoteAvoInteraction(
              pointer: old?.pointer,
              pop: kind == 'pop' ? pulse : old?.pop,
              pet: kind == 'pet' ? pulse : old?.pet,
            ));
  }

  void _update(
      int uid, RemoteAvoInteraction Function(RemoteAvoInteraction?) make) {
    state = {...state, uid: make(state[uid])};
  }
}

@riverpod
RemoteAvoInteraction? avoInteractionForUid(Ref ref, int uid) => ref.watch(
      avoInteractionControllerProvider.select(
        (interactions) => interactions[uid],
      ),
    );
