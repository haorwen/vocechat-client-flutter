import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';
import 'package:vocechat_client/shared/widgets/avo_animation.dart';
import 'package:vocechat_client/shared/widgets/avo_avatar.dart';
import 'package:vocechat_client/shared/widgets/avo_painter.dart';

Widget _host({
  AvoParams params = AvoParams.defaults,
  double level = 0,
  double scale = .62,
  bool interactive = false,
  bool tickerEnabled = true,
  ValueChanged<AvoLocalInteraction>? onInteraction,
  RemoteAvoInteraction? remoteInteraction,
}) {
  return MaterialApp(
    home: Center(
      child: TickerMode(
        enabled: tickerEnabled,
        child: SizedBox(
          width: 200,
          height: 160,
          child: AvoAvatar(
            params: params,
            level: level,
            scale: scale,
            interactive: interactive,
            onInteraction: onInteraction,
            remoteInteraction: remoteInteraction,
          ),
        ),
      ),
    ),
  );
}

AvoPainter _painter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.descendant(
    of: find.byType(AvoAvatar),
    matching: find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is AvoPainter,
    ),
  ));
  return paint.painter! as AvoPainter;
}

AvoAnimationState _animation(WidgetTester tester) => _painter(tester).animation;

Future<void> _pumpFrames(
  WidgetTester tester,
  int count, {
  Duration interval = const Duration(milliseconds: 16),
}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(interval);
  }
}

void main() {
  testWidgets('renders every native style inside an isolated clipped canvas',
      (tester) async {
    for (final style in AvoParams.allowedStyles) {
      await tester.pumpWidget(_host(
        params: AvoParams.defaults.copyWith(style: style),
        scale: .7,
      ));
      expect(_painter(tester).params.style, style);
      expect(_painter(tester).scale, .7);
      expect(tester.getSize(find.byType(AvoAvatar)), const Size(200, 160));
      expect(
        find.descendant(
          of: find.byType(AvoAvatar),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AvoAvatar),
          matching: find.byType(ClipRect),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('idle animation keeps advancing after 101 seconds',
      (tester) async {
    await tester.pumpWidget(_host());
    final animation = _animation(tester);
    final painter = _painter(tester);
    final before = animation.elapsed;

    await tester.pump(const Duration(seconds: 101));
    final afterLongFrame = animation.elapsed;
    expect(afterLongFrame, greaterThan(before));
    expect(afterLongFrame - before, closeTo(101, .000001));
    await tester.pump(const Duration(milliseconds: 16));

    expect(animation.elapsed, greaterThan(afterLongFrame));
    expect(_painter(tester), same(painter));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('voice level starts at zero and smooths on 120 Hz ticks',
      (tester) async {
    await tester.pumpWidget(_host(level: 1));
    final animation = _animation(tester);
    expect(animation.level, 0);

    await tester.pump(const Duration(microseconds: 8333));
    final firstLevel = animation.level;
    expect(firstLevel, greaterThan(0));
    expect(firstLevel, lessThan(1));
    await tester.pump(const Duration(microseconds: 8333));
    expect(animation.level, greaterThan(firstLevel));
    expect(animation.level, lessThan(1));
  });

  testWidgets('TickerMode pauses animation and resumes without a time jump',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 16));
    final animation = _animation(tester);
    await tester.pumpWidget(_host(tickerEnabled: false));
    final pausedAt = animation.elapsed;

    await tester.pump(const Duration(seconds: 101));
    expect(animation.elapsed, pausedAt);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_host());
    expect(animation.elapsed, pausedAt);
    await tester.pump(const Duration(milliseconds: 16));
    expect(animation.elapsed - pausedAt, closeTo(.016, .000001));
  });

  testWidgets('touch press pops once immediately and the pop returns to normal',
      (tester) async {
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: interactions.add,
    ));
    final animation = _animation(tester);
    expect(animation.popT, 99);

    final touch = await tester.startGesture(
      tester.getCenter(find.byType(AvoAvatar)),
    );
    expect(animation.popT, 0);
    expect(
      interactions.where((event) => event.type == AvoInteractionType.pop),
      hasLength(1),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final popT = animation.popT;
    await touch.up();
    expect(animation.popT, popT);
    expect(
      interactions.where((event) => event.type == AvoInteractionType.pop),
      hasLength(1),
    );
    await _pumpFrames(tester, 20, interval: const Duration(milliseconds: 100));
    expect(animation.popT, greaterThanOrEqualTo(1.9));
    expect(animation.particles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pressing Avo consumes the tap of its surrounding card',
      (tester) async {
    var cardTaps = 0;
    var pops = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: GestureDetector(
          onTap: () => cardTaps++,
          child: SizedBox(
            width: 200,
            height: 160,
            child: AvoAvatar(
              params: AvoParams.defaults,
              interactive: true,
              onInteraction: (event) {
                if (event.type == AvoInteractionType.pop) pops++;
              },
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(AvoAvatar));
    expect(pops, 1);
    expect(cardTaps, 0);
    final mouseRegion = tester.widget<MouseRegion>(find.descendant(
      of: find.byType(AvoAvatar),
      matching: find.byType(MouseRegion),
    ));
    expect(mouseRegion.cursor, SystemMouseCursors.click);
  });

  testWidgets('parameter rebuilds preserve animation and active reactions',
      (tester) async {
    await tester.pumpWidget(_host(interactive: true));
    await tester.tap(find.byType(AvoAvatar));
    await tester.pump(const Duration(milliseconds: 100));
    final animation = _animation(tester);
    final elapsed = animation.elapsed;
    final popT = animation.popT;
    final particles = List<AvoParticle>.of(animation.particles);
    expect(particles, hasLength(6));

    await tester.pumpWidget(_host(
      params: AvoParams.defaults.copyWith(style: 'ring', hue: 200),
      level: .8,
      interactive: true,
    ));
    expect(_animation(tester), same(animation));
    expect(animation.elapsed, elapsed);
    expect(animation.popT, popT);
    expect(animation.particles, orderedEquals(particles));
    expect(animation.level, 0);
    expect(_painter(tester).params.style, 'ring');
    await tester.pump(const Duration(milliseconds: 16));
    expect(animation.elapsed, greaterThan(elapsed));
    expect(animation.popT, greaterThan(popT));
    expect(animation.level, greaterThan(0));
  });

  testWidgets('remote pulses replay only when their event ids change',
      (tester) async {
    RemoteAvoInteraction pulse(String suffix, {int second = 0}) {
      return RemoteAvoInteraction(
        pop: AvoPulse(
          eventId: 'pop-$suffix',
          receivedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
        ),
        pet: AvoPulse(
          eventId: 'pet-$suffix',
          receivedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
        ),
      );
    }

    await tester.pumpWidget(_host(remoteInteraction: pulse('one')));
    final animation = _animation(tester);
    expect(animation.popT, 0);
    expect(animation.petGlow, 1);
    await tester.pump(const Duration(milliseconds: 100));
    final popT = animation.popT;
    final petGlow = animation.petGlow;
    expect(popT, greaterThan(0));
    expect(petGlow, lessThan(1));

    await tester.pumpWidget(_host(
      remoteInteraction: pulse('one', second: 1),
    ));
    expect(animation.popT, popT);
    expect(animation.petGlow, petGlow);
    await tester.pumpWidget(_host());
    await tester.pumpWidget(_host(remoteInteraction: pulse('one')));
    expect(animation.popT, popT);
    expect(animation.petGlow, petGlow);
    await tester.pumpWidget(_host(remoteInteraction: pulse('two')));
    expect(animation.popT, 0);
    expect(animation.petGlow, 1);
  });

  testWidgets('remote pointer clears when interaction becomes null',
      (tester) async {
    const pointer = AvoPointer(x: .4, y: -.2, speed: .2, inside: true);
    await tester.pumpWidget(_host(
      remoteInteraction: const RemoteAvoInteraction(pointer: pointer),
    ));
    final animation = _animation(tester);
    expect(animation.pointer?.x, .4);

    await tester.pumpWidget(_host());
    expect(animation.pointer, isNull);
  });

  testWidgets('remote pointer expires without unrelated rebuilds renewing TTL',
      (tester) async {
    const remote = RemoteAvoInteraction(
      pointer: AvoPointer(x: .4, y: -.2, speed: 0, inside: true),
    );
    await tester.pumpWidget(_host(remoteInteraction: remote));
    final animation = _animation(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(animation.pointer, isNotNull);

    await tester.pumpWidget(_host(
      params: AvoParams.defaults.copyWith(style: 'wave'),
      remoteInteraction: remote,
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(animation.pointer, isNull);
    await tester.pumpWidget(_host(remoteInteraction: remote));
    expect(animation.pointer, isNull);
  });

  testWidgets('a new stationary remote heartbeat extends pointer TTL',
      (tester) async {
    RemoteAvoInteraction remote(int seq) => RemoteAvoInteraction(
          pointer: AvoPointer(
            x: .4,
            y: -.2,
            speed: 0,
            inside: true,
            seq: seq,
          ),
        );
    await tester.pumpWidget(_host(remoteInteraction: remote(1)));
    final animation = _animation(tester);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(_host(remoteInteraction: remote(2)));
    await tester.pump(const Duration(milliseconds: 700));
    expect(animation.pointer, isNotNull);
    await tester.pump(const Duration(milliseconds: 100));
    expect(animation.pointer, isNull);
  });

  testWidgets('mouse pointer and hover work without an interaction callback',
      (tester) async {
    await tester.pumpWidget(_host(interactive: true));
    final animation = _animation(tester);
    final center = tester.getCenter(find.byType(AvoAvatar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(center + const Offset(40, -16));

    expect(animation.pointer, isNotNull);
    expect(animation.pointer!.x, closeTo(.4, .0001));
    expect(animation.pointer!.y, closeTo(-.2, .0001));
    await tester.pump(const Duration(milliseconds: 16));
    expect(animation.hover, greaterThan(0));
    await mouse.moveTo(const Offset(10, 10));
    expect(animation.pointer, isNull);
    await mouse.removePointer();
  });

  testWidgets('pointer speed uses consecutive input timestamps while throttled',
      (tester) async {
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: interactions.add,
    ));
    final center = tester.getCenter(find.byType(AvoAvatar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(center, timeStamp: const Duration(milliseconds: 100));
    await mouse.moveTo(
      center + const Offset(2, 0),
      timeStamp: const Duration(milliseconds: 120),
    );
    expect(_animation(tester).pointer!.speed, closeTo(.15625, .000001));
    await mouse.moveTo(
      center + const Offset(4, 0),
      timeStamp: const Duration(milliseconds: 140),
    );
    expect(_animation(tester).pointer!.speed, closeTo(.15625, .000001));
    expect(_animation(tester).pointer!.x, closeTo(.04, .000001));
    expect(
      interactions.where((event) => event.type == AvoInteractionType.pointer),
      hasLength(1),
    );
    await mouse.removePointer();
  });

  testWidgets('fast pointer movement sends no more than 20 updates per second',
      (tester) async {
    final sentAt = <Duration>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: (event) {
        if (event.type == AvoInteractionType.pointer) {
          sentAt.add(SchedulerBinding.instance.currentSystemFrameTimeStamp);
        }
      },
    ));
    final center = tester.getCenter(find.byType(AvoAvatar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(center);
    for (var move = 1; move < 100; move++) {
      await tester.pump(const Duration(milliseconds: 10));
      await mouse.moveTo(
        center + Offset(move.isEven ? 30 : -30, 0),
        timeStamp: Duration(milliseconds: move * 10),
      );
    }

    expect(sentAt.length, inInclusiveRange(18, 20));
    for (var index = 1; index < sentAt.length; index++) {
      expect(sentAt[index] - sentAt[index - 1],
          greaterThanOrEqualTo(const Duration(milliseconds: 50)));
    }
    expect(_animation(tester).pointer!.x, closeTo(-.3, .000001));
    await mouse.removePointer();
  });

  testWidgets('stationary pointer heartbeats keep position without old speed',
      (tester) async {
    final pointers = <AvoPointer>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: (event) {
        if (event.type == AvoInteractionType.pointer) {
          pointers.add(event.value!);
        }
      },
    ));
    final center = tester.getCenter(find.byType(AvoAvatar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(center + const Offset(30, -16));
    await tester.pump(const Duration(milliseconds: 50));
    final count = pointers.length;
    await tester.pump(const Duration(milliseconds: 249));
    expect(pointers, hasLength(count));
    await tester.pump(const Duration(milliseconds: 1));
    expect(pointers, hasLength(count + 1));
    expect(pointers.last.x, closeTo(.3, .000001));
    expect(pointers.last.y, closeTo(-.2, .000001));
    expect(pointers.last.speed, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(pointers, hasLength(count + 2));
    await mouse.removePointer();
  });

  testWidgets('rubbing outside the body never emits pet reactions',
      (tester) async {
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: interactions.add,
    ));
    final topLeft = tester.getTopLeft(find.byType(AvoAvatar));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    for (var move = 0; move < 60; move++) {
      await mouse.moveTo(
        topLeft + Offset(move.isEven ? 5 : 25, 5),
        timeStamp: Duration(milliseconds: move * 16),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_animation(tester).isRubbing, isFalse);
    expect(_animation(tester).petGlow, 0);
    expect(
      interactions.where((event) => event.type == AvoInteractionType.pet),
      isEmpty,
    );
    await mouse.removePointer();
  });

  testWidgets(
      'touch drag gradually pets and emits actual position at most 4 Hz',
      (tester) async {
    final pets = <AvoPet>[];
    final sentAt = <Duration>[];
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: (event) {
        interactions.add(event);
        if (event.type == AvoInteractionType.pet) {
          pets.add(event.petValue!);
          sentAt.add(SchedulerBinding.instance.currentSystemFrameTimeStamp);
        }
      },
    ));
    final center = tester.getCenter(find.byType(AvoAvatar));
    final touch = await tester.startGesture(center + const Offset(15, -8));
    for (var move = 1; move <= 60; move++) {
      await touch.moveTo(
        center + Offset(move.isEven ? 15 : -15, -8),
        timeStamp: Duration(milliseconds: move * 16),
      );
      await tester.pump(const Duration(milliseconds: 16));
      if (move == 1) expect(_animation(tester).petGlow, lessThan(1));
    }

    expect(pets.length, inInclusiveRange(1, 4));
    for (var index = 0; index < pets.length; index++) {
      expect(pets[index].x.abs(), closeTo(.15, .000001));
      expect(pets[index].y, closeTo(-.1, .000001));
      expect(pets[index].intensity, greaterThan(.3));
      expect(pets[index].intensity, lessThanOrEqualTo(1));
      if (index > 0) {
        expect(sentAt[index] - sentAt[index - 1],
            greaterThanOrEqualTo(const Duration(milliseconds: 250)));
      }
    }
    await touch.up();
    expect(_animation(tester).pointer, isNull);
    expect(
      interactions
          .where((event) => event.type == AvoInteractionType.pointerLeave),
      hasLength(1),
    );
    expect(
      interactions.where((event) => event.type == AvoInteractionType.pop),
      hasLength(1),
    );
  });

  testWidgets('touch drag leaving the widget clears the local pointer',
      (tester) async {
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(_host(
      interactive: true,
      onInteraction: interactions.add,
    ));
    final touch = await tester.startGesture(
      tester.getCenter(find.byType(AvoAvatar)),
    );
    expect(_animation(tester).pointer, isNotNull);
    await touch.moveTo(const Offset(10, 10));
    expect(_animation(tester).pointer, isNull);
    expect(
      interactions
          .where((event) => event.type == AvoInteractionType.pointerLeave),
      hasLength(1),
    );
    await touch.cancel();
  });

  testWidgets('noninteractive avatars let an underlying mouse region see hover',
      (tester) async {
    var hoverCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MouseRegion(
                onHover: (_) => hoverCount++,
                child: const ColoredBox(color: Colors.black),
              ),
              const AvoAvatar(params: AvoParams.defaults),
            ],
          ),
        ),
      ),
    ));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(tester.getCenter(find.byType(AvoAvatar)));
    expect(hoverCount, greaterThan(0));
    expect(_animation(tester).pointer, isNull);
    await mouse.removePointer();
  });
}
