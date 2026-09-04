import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../shared/models/avo_interaction.dart';

class AvoRealtimeClient {
  AvoRealtimeClient(
      {required this.baseUrl,
      required this.apiKey,
      this.apiKeyProvider,
      required this.roomType,
      required this.roomId,
      this.onEvent,
      this.onStatus});
  final String baseUrl;
  String apiKey;
  final Future<String?> Function()? apiKeyProvider;
  final String roomType;
  final int roomId;
  final void Function(Map<String, dynamic>)? onEvent;
  final void Function(bool connected)? onStatus;
  static const _maxBackoff = Duration(seconds: 30);
  static const _maxFrameBytes = 4096;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  Duration _backoff = const Duration(seconds: 1);
  bool _closed = false;
  int _lastSeq = 0;
  int _generation = 0;

  Future<void> connect() async {
    _closed = false;
    _reconnect?.cancel();
    final generation = ++_generation;
    await _open(generation);
  }

  Future<void> _open([int? requestedGeneration]) async {
    final generation = requestedGeneration ?? _generation;
    if (_closed || generation != _generation) return;
    try {
      final refreshedKey = await apiKeyProvider?.call();
      if (refreshedKey != null && refreshedKey.isNotEmpty) {
        apiKey = refreshedKey;
      }
    } catch (_) {
      // A transient token-store failure is handled like a connection failure.
      _scheduleReconnect(generation);
      return;
    }
    if (_closed || generation != _generation) return;
    final wsBase = baseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceFirst(RegExp(r'/+$'), '');
    final uri =
        Uri.parse('$wsBase/api/voice/avo/events_ws').replace(queryParameters: {
      'api-key': apiKey,
      'room_type': roomType,
      'room_id': '$roomId',
    });
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(const Duration(seconds: 15));
      if (_closed || generation != _generation) {
        await channel.sink.close();
        return;
      }
      _channel = channel;
      _backoff = const Duration(seconds: 1);
      onStatus?.call(true);
      _subscription = channel.stream.listen((raw) {
        if (generation != _generation || !identical(_channel, channel)) return;
        try {
          final bytes = raw is String
              ? utf8.encode(raw)
              : raw is List<int>
                  ? raw
                  : null;
          if (bytes == null || bytes.length > _maxFrameBytes) return;
          final decoded = jsonDecode(raw is String ? raw : utf8.decode(bytes));
          if (decoded is Map) onEvent?.call(Map<String, dynamic>.from(decoded));
        } catch (_) {
          // Unknown or malformed frames must not interrupt the call stream.
        }
      },
          onError: (_) => _scheduleReconnect(generation),
          onDone: () => _scheduleReconnect(generation));
    } catch (_) {
      _scheduleReconnect(generation);
    }
  }

  void _scheduleReconnect([int? generation]) {
    final activeGeneration = generation ?? _generation;
    if (_closed ||
        activeGeneration != _generation ||
        _reconnect?.isActive == true) {
      return;
    }
    onStatus?.call(false);
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    final delay = _backoff;
    _backoff = Duration(
        milliseconds: (_backoff.inMilliseconds * 2)
            .clamp(1000, _maxBackoff.inMilliseconds));
    _reconnect = Timer(delay, () => _open(activeGeneration));
  }

  /// Encodes a protocol frame separately from the socket, keeping the pet
  /// payload distinct from pointer speed/inside fields.
  static String encodeFrame(AvoLocalInteraction interaction,
      {required int seq, required String eventId, DateTime? sentAt}) {
    final pointer = interaction.value;
    final type = switch (interaction.type) {
      AvoInteractionType.pointer => 'pointer',
      AvoInteractionType.pointerLeave => 'pointer_leave',
      AvoInteractionType.pop => 'pop',
      AvoInteractionType.pet => 'pet',
    };
    final frame = <String, dynamic>{
      'v': 1,
      'type': type,
      'seq': seq,
      'sent_at': (sentAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
    if (type == 'pointer' && pointer != null) {
      frame.addAll({
        'x': pointer.x.clamp(-1, 1),
        'y': pointer.y.clamp(-1, 1),
        'speed': pointer.speed.clamp(0, 1),
        'inside': pointer.inside,
      });
    }
    if (type == 'pet') {
      final pet = interaction.petValue?.normalized();
      if (pet != null) {
        frame.addAll({'intensity': pet.intensity, 'x': pet.x, 'y': pet.y});
      }
    }
    if (type == 'pop' || type == 'pet') frame['event_id'] = eventId;
    return jsonEncode(frame);
  }

  void send(AvoLocalInteraction interaction,
      {required int seq, required String eventId}) {
    if (seq <= _lastSeq || seq < 0) return;
    final sink = _channel?.sink;
    if (sink == null) return;
    final encoded = utf8.encode(
      encodeFrame(interaction, seq: seq, eventId: eventId),
    );
    if (encoded.length > _maxFrameBytes) return;
    _lastSeq = seq;
    sink.add(encoded);
  }

  Future<void> close() async {
    _closed = true;
    ++_generation;
    _reconnect?.cancel();
    _subscription?.cancel();
    _subscription = null;
    onStatus?.call(false);
    final channel = _channel;
    if (channel != null) {
      send(const AvoLocalInteraction.pointerLeave(),
          seq: _lastSeq + 1, eventId: 'leave');
    }
    _channel = null;
    await channel?.sink.close();
  }
}
