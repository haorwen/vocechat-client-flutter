import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/presentation/message_expiry_countdown.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    );

const _description = 'Automatically deleted 5 minutes after being sent';

Finder _countdown(String time, {String description = _description}) =>
    find.text('$time\n$description', findRichText: true);

Future<void> _showCountdown(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.schedule_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('hover reveals a live countdown without changing message layout',
      (tester) async {
    var now = DateTime(2026, 10, 26);
    await tester.pumpWidget(_app(Center(
      child: MessageExpiryCountdown(
        durationSeconds: 300,
        expiresAt: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
        currentTime: () => now,
      ),
    )));
    final indicator = find.byType(MessageExpiryCountdown);
    final initialRect = tester.getRect(indicator);
    expect(_countdown('05:00'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(indicator));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_countdown('05:00'), findsOneWidget);

    // Keep the tooltip open while the countdown updates.
    now = now.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    expect(_countdown('04:56'), findsOneWidget);
    expect(tester.getRect(indicator), initialRect);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_countdown('04:56'), findsNothing);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mouse click reveals countdown before the hover delay',
      (tester) async {
    await tester.pumpWidget(_app(const Center(
      child: MessageExpiryCountdown(durationSeconds: 300, expiresAt: null),
    )));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.down(tester.getCenter(find.byIcon(Icons.schedule_outlined)));
    await mouse.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(_countdown('05:00'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('touch tap reveals countdown and tapping outside dismisses it',
      (tester) async {
    await tester.pumpWidget(_app(const Center(
      child: MessageExpiryCountdown(durationSeconds: 300, expiresAt: null),
    )));
    expect(_countdown('05:00'), findsNothing);
    await _showCountdown(tester);
    expect(_countdown('05:00'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_countdown('05:00'), findsNothing);
  });

  testWidgets('counts down from the absolute deadline and hides at expiry',
      (tester) async {
    var now = DateTime(2026, 9, 9);
    final deadline = now.add(const Duration(seconds: 65));
    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: deadline.millisecondsSinceEpoch,
      currentTime: () => now,
    )));

    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    expect(_countdown('01:05'), findsNothing);
    expect(find.byTooltip('01:05\n$_description'), findsOneWidget);
    await _showCountdown(tester);
    expect(_countdown('01:05'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(_countdown('01:04'), findsOneWidget);

    // A late tick catches up to wall time instead of decrementing just once.
    now = now.add(const Duration(seconds: 63, milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(_countdown('00:01'), findsOneWidget);

    now = deadline;
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.schedule_outlined), findsNothing);
    expect(_countdown('00:00'), findsNothing);
  });

  testWidgets('pending messages start counting only after server confirmation',
      (tester) async {
    var now = DateTime(2026, 9, 9);
    DateTime currentTime() => now;
    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: null,
      currentTime: currentTime,
    )));
    await _showCountdown(tester);
    expect(_countdown('05:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await _showCountdown(tester);
    expect(_countdown('05:00'), findsOneWidget);

    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      currentTime: currentTime,
    )));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(_countdown('04:59'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('resuming the app immediately updates a suspended countdown',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var now = DateTime(2026, 9, 9);
    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      currentTime: () => now,
    )));

    await _showCountdown(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_countdown('03:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('long lifetimes keep hours and localized tooltip',
      (tester) async {
    await tester.pumpWidget(_app(
      const MessageExpiryCountdown(
        durationSeconds: 604800,
        expiresAt: null,
      ),
      locale: const Locale('zh'),
    ));
    expect(_countdown('168:00:00', description: '发送后 1 周 自动删除'), findsNothing);
    await _showCountdown(tester);
    expect(
        _countdown('168:00:00', description: '发送后 1 周 自动删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
