enum AvoInteractionType { pointer, pointerLeave, pop, pet }

class AvoPet {
  const AvoPet({required this.intensity, required this.x, required this.y});
  final double intensity;
  final double x;
  final double y;

  AvoPet normalized() => AvoPet(
        intensity: intensity.clamp(0.0, 1.0).toDouble(),
        x: x.clamp(-1.0, 1.0).toDouble(),
        y: y.clamp(-1.0, 1.0).toDouble(),
      );
}

class AvoPointer {
  const AvoPointer(
      {required this.x,
      required this.y,
      required this.speed,
      required this.inside,
      this.seq = 0});
  final double x;
  final double y;
  final double speed;
  final bool inside;
  final int seq;

  AvoPointer normalized({int? seq}) => AvoPointer(
        x: x.clamp(-1.0, 1.0).toDouble(),
        y: y.clamp(-1.0, 1.0).toDouble(),
        speed: speed.clamp(0.0, 1.0).toDouble(),
        inside: inside,
        seq: seq ?? this.seq,
      );
}

class AvoLocalInteraction {
  const AvoLocalInteraction.pointer(this.value)
      : type = AvoInteractionType.pointer,
        petValue = null;
  const AvoLocalInteraction.pointerLeave()
      : type = AvoInteractionType.pointerLeave,
        value = null,
        petValue = null;
  const AvoLocalInteraction.pop()
      : type = AvoInteractionType.pop,
        value = null,
        petValue = null;
  const AvoLocalInteraction.pet(this.petValue)
      : type = AvoInteractionType.pet,
        value = null;

  final AvoInteractionType type;
  final AvoPointer? value;
  final AvoPet? petValue;
}

/// A one-shot remote interaction pulse. The event id is the identity of the
/// event; [receivedAt] is only used by the painter to animate its decay.
class AvoPulse {
  const AvoPulse({required this.eventId, required this.receivedAt});

  final String eventId;
  final DateTime receivedAt;
}

class RemoteAvoInteraction {
  const RemoteAvoInteraction({this.pointer, this.pop, this.pet});
  final AvoPointer? pointer;
  final AvoPulse? pop;
  final AvoPulse? pet;
}
