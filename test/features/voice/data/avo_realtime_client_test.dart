import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/voice/data/avo_realtime_client.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';

void main() {
  test('encodes pointer fields and clamps their protocol ranges', () {
    final frame = jsonDecode(AvoRealtimeClient.encodeFrame(
      const AvoLocalInteraction.pointer(
        AvoPointer(x: 4, y: -4, speed: 3, inside: true),
      ),
      seq: 7,
      eventId: 'ignored-for-pointer',
      sentAt: DateTime.fromMillisecondsSinceEpoch(1234),
    )) as Map<String, dynamic>;

    expect(frame, {
      'v': 1,
      'type': 'pointer',
      'seq': 7,
      'sent_at': 1234,
      'x': 1.0,
      'y': -1.0,
      'speed': 1.0,
      'inside': true,
    });
    expect(frame.containsKey('event_id'), isFalse);
  });

  test('encodes pet with intensity and position, never pointer fields', () {
    final frame = jsonDecode(AvoRealtimeClient.encodeFrame(
      const AvoLocalInteraction.pet(AvoPet(intensity: 2, x: 3, y: -3)),
      seq: 8,
      eventId: 'pet-8',
      sentAt: DateTime.fromMillisecondsSinceEpoch(5678),
    )) as Map<String, dynamic>;

    expect(frame['type'], 'pet');
    expect(frame['intensity'], 1.0);
    expect(frame['x'], 1.0);
    expect(frame['y'], -1.0);
    expect(frame['event_id'], 'pet-8');
    expect(frame.containsKey('speed'), isFalse);
    expect(frame.containsKey('inside'), isFalse);
  });

  test('pop includes an event identity for remote deduplication', () {
    final frame = jsonDecode(AvoRealtimeClient.encodeFrame(
      const AvoLocalInteraction.pop(),
      seq: 9,
      eventId: 'pop-9',
      sentAt: DateTime.fromMillisecondsSinceEpoch(1),
    )) as Map<String, dynamic>;

    expect(frame['type'], 'pop');
    expect(frame['event_id'], 'pop-9');
  });
}
