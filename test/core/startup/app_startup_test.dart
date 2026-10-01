import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/startup/app_startup.dart';

void main() {
  testWidgets(
      'hung optional startup tasks leave UI usable and late FCM recovers',
      (tester) async {
    final firebase = Completer<bool>();
    final videoCache = Completer<void>();
    final failures = <String>[];
    var audioInitialized = false;
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appStartupTasksProvider.overrideWithValue(AppStartupTasks(
          initializeFirebase: () => firebase.future,
          initializeVideoBackend: () => throw StateError('No video backend'),
          initializeAudioBackend: () => audioInitialized = true,
          trimAudioCache: () async {},
          initializeVideoCache: () => videoCache.future,
        )),
        startupTaskTimeoutProvider
            .overrideWithValue(const Duration(milliseconds: 100)),
        startupErrorReporterProvider.overrideWithValue(
          (task, error, stack) => failures.add(task),
        ),
      ],
      child: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        ref.watch(appStartupProvider);
        return const MaterialApp(home: Scaffold(body: Text('App is usable')));
      }),
    ));
    await tester.pump();

    expect(find.text('App is usable'), findsOneWidget);
    expect(audioInitialized, isTrue);
    expect(container.read(firebaseInitializedProvider), isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(container.read(appStartupProvider).hasValue, isTrue);
    expect(failures,
        unorderedEquals(['video playback', 'Firebase', 'video cache']));
    expect(find.text('App is usable'), findsOneWidget);

    firebase.complete(true);
    videoCache.complete();
    await tester.pump();
    expect(container.read(firebaseInitializedProvider), isTrue);
    expect(find.text('App is usable'), findsOneWidget);
  });

  testWidgets('late initialization cannot write to a disposed provider scope',
      (tester) async {
    final firebase = Completer<bool>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appStartupTasksProvider.overrideWithValue(AppStartupTasks(
          initializeFirebase: () => firebase.future,
          initializeVideoBackend: () {},
          initializeAudioBackend: () {},
          trimAudioCache: () async {},
          initializeVideoCache: () async {},
        )),
      ],
      child: Consumer(builder: (_, ref, __) {
        ref.watch(appStartupProvider);
        return const SizedBox();
      }),
    ));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    firebase.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
