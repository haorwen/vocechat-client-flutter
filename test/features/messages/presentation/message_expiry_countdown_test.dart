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

void main() {
  testWidgets('counts down from the absolute deadline and hides at expiry',
      (tester) async {
    var now = DateTime(2026, 9, 9);
    final deadline = now.add(const Duration(seconds: 65));
    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: deadline.millisecondsSinceEpoch,
      currentTime: () => now,
    )));

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.text('01:05'), findsOneWidget);
    expect(find.byTooltip('Automatically deleted 5 minutes after being sent'),
        findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01:04'), findsOneWidget);

    // A late tick catches up to wall time instead of decrementing just once.
    now = now.add(const Duration(seconds: 63, milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    now = deadline;
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.text('00:00'), findsNothing);
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
    expect(find.text('05:00'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('05:00'), findsOneWidget);

    await tester.pumpWidget(_app(MessageExpiryCountdown(
      durationSeconds: 300,
      expiresAt: now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      currentTime: currentTime,
    )));
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('04:59'), findsOneWidget);

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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);

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
    expect(find.text('168:00:00'), findsOneWidget);
    expect(find.byTooltip('发送后 1 周 自动删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
