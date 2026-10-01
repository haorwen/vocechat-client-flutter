import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/recovery/app_recovery.dart';

Future<void> withRecovery(
  Future<void> Function(
    AppRecoveryController recovery,
    List<FlutterErrorDetails> reported,
  ) body,
) async {
  final recovery = AppRecoveryController();
  final reported = <FlutterErrorDetails>[];
  final originalHandler = FlutterError.onError;
  FlutterError.onError = reported.add;
  final reporting = AppErrorReporting.install(recovery);
  try {
    await body(recovery, reported);
  } finally {
    reporting.dispose();
    FlutterError.onError = originalHandler;
    recovery.dispose();
  }
}

void main() {
  testWidgets('a build failure shows recovery and retry rebuilds the app',
      (tester) async {
    await withRecovery((recovery, reported) async {
      var shouldFail = true;
      await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) => Builder(builder: (_) {
          if (shouldFail) throw StateError('private-token-must-not-be-visible');
          return const MaterialApp(home: Scaffold(body: Text('Chat is ready')));
        }),
      ));
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(find.text('Unable to display this page'), findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Chat is ready'), findsOneWidget);
      expect(find.byType(AppRecoveryPage), findsNothing);
    });
  });

  testWidgets('async errors keep a working app mounted and preserve reporting',
      (tester) async {
    await withRecovery((recovery, reported) async {
      var builds = 0;
      await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) {
          builds++;
          return const MaterialApp(home: Scaffold(body: Text('Active call')));
        },
      ));
      final handled = PlatformDispatcher.instance.onError!(
        StateError('Background request failed'),
        StackTrace.current,
      );
      await tester.pump();

      expect(handled, isTrue);
      expect(reported, hasLength(1));
      expect(recovery.failed, isFalse);
      expect(builds, 1);
      expect(find.text('Active call'), findsOneWidget);
    });
  });

  testWidgets('fatal rendering failures have recovery instead of an empty page',
      (tester) async {
    await withRecovery((recovery, reported) async {
      await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) => const MaterialApp(home: SizedBox()),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError('RenderBox was not laid out'),
        library: 'rendering library',
        context: ErrorDescription('during layout'),
      ));
      await tester.pumpAndSettle();

      expect(reported, hasLength(1));
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  testWidgets('a debug overflow does not tear down the app', (tester) async {
    await withRecovery((recovery, reported) async {
      await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) => const MaterialApp(home: Text('Still usable')),
      ));
      FlutterError.reportError(FlutterErrorDetails(
        exception: FlutterError('A RenderFlex overflowed by 2 pixels'),
        library: 'rendering library',
      ));
      await tester.pump();

      expect(reported, hasLength(1));
      expect(recovery.failed, isFalse);
      expect(find.text('Still usable'), findsOneWidget);
    });
  });

  testWidgets('a broken render tree is replaced by a tappable recovery page',
      (tester) async {
    await withRecovery((recovery, reported) async {
      var useBrokenLayout = true;
      await tester.pumpWidget(AppRecoveryHost(
        controller: recovery,
        builder: (_) => MaterialApp(
          home: Scaffold(
            body: useBrokenLayout
                // A real RenderFlex failure: Expanded cannot consume an
                // unbounded height inside a vertical scroll view.
                ? const SingleChildScrollView(
                    child: Column(
                      children: [Expanded(child: Text('Broken page'))],
                    ),
                  )
                : const Text('Recovered chat'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        reported.any((error) => error
            .exceptionAsString()
            .contains('incoming height constraints are unbounded')),
        isTrue,
      );
      expect(find.text('Unable to display this page'), findsOneWidget);
      expect(find.text('Broken page'), findsNothing);
      useBrokenLayout = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Recovered chat'), findsOneWidget);
      expect(recovery.failed, isFalse);
    });
  });
}
