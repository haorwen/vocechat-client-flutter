import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Records UI failures without storing exception strings (which can include
/// server URLs or credentials). Recovery is always an explicit user action.
class AppRecoveryController extends ChangeNotifier {
  bool _failed = false;
  bool _disposed = false;
  int _generation = 0;

  bool get failed => _failed;
  int get generation => _generation;

  void requestRecovery() {
    if (_failed || _disposed) return;
    _failed = true;
    // ErrorWidget.builder and rendering error callbacks run during a frame;
    // replacing their ancestors synchronously would cause another build error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && _failed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void retry() {
    if (_disposed) return;
    _failed = false;
    _generation++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Installs process-level reporting while preserving existing framework and
/// platform handlers. Ordinary asynchronous failures are logged, not treated
/// as a reason to tear down a working app or interrupt an active call.
class AppErrorReporting {
  AppErrorReporting.install(AppRecoveryController recovery) {
    _previousFlutterHandler = FlutterError.onError;
    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    _previousErrorBuilder = ErrorWidget.builder;

    _flutterHandler = (details) {
      (_previousFlutterHandler ?? FlutterError.presentError)(details);
      // Build failures use ErrorWidget.builder below. Rendering failures do
      // not, so handle them here; a debug overflow alone isn't a blank screen.
      if (details.library == 'rendering library' &&
          !details.silent &&
          !details.exceptionAsString().startsWith('A RenderFlex overflowed')) {
        recovery.requestRecovery();
      }
    };
    _platformHandler = (error, stack) {
      final previous = _previousPlatformHandler;
      if (previous != null && previous(error, stack)) return true;
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'application async',
      ));
      // The exception was reported above through the existing Flutter logger.
      return true;
    };
    _errorBuilder = (details) {
      recovery.requestRecovery();
      // This placeholder is replaced by the recovery page on the next frame.
      // Raw exception text must never appear in the user's interface.
      return ErrorWidget.withDetails(message: '');
    };
    FlutterError.onError = _flutterHandler;
    PlatformDispatcher.instance.onError = _platformHandler;
    ErrorWidget.builder = _errorBuilder;
  }

  late final FlutterExceptionHandler? _previousFlutterHandler;
  late final bool Function(Object, StackTrace)? _previousPlatformHandler;
  late final ErrorWidgetBuilder _previousErrorBuilder;
  late final FlutterExceptionHandler _flutterHandler;
  late final bool Function(Object, StackTrace) _platformHandler;
  late final ErrorWidgetBuilder _errorBuilder;

  void dispose() {
    if (identical(FlutterError.onError, _flutterHandler)) {
      FlutterError.onError = _previousFlutterHandler;
    }
    if (identical(PlatformDispatcher.instance.onError, _platformHandler)) {
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
    if (identical(ErrorWidget.builder, _errorBuilder)) {
      ErrorWidget.builder = _previousErrorBuilder;
    }
  }
}

/// Sits above ProviderScope/MaterialApp so even their build failures have a
/// usable fallback. Retrying replaces in-memory state and reruns bootstrap;
/// persistent accounts, tokens, settings and message caches are untouched.
class AppRecoveryHost extends StatelessWidget {
  const AppRecoveryHost({
    super.key,
    required this.controller,
    required this.builder,
  });

  final AppRecoveryController controller;
  final WidgetBuilder builder;

  /// Available to router/startup fallbacks without coupling them to app state.
  /// Tests or embedders that mount pages without the host can use a local retry.
  static AppRecoveryController? maybeOf(BuildContext context) =>
      context.findAncestorWidgetOfExactType<AppRecoveryHost>()?.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.failed) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: AppRecoveryPage(onRetry: controller.retry),
          );
        }
        return KeyedSubtree(
          key: ValueKey(controller.generation),
          child: Builder(builder: builder),
        );
      },
    );
  }
}

/// Also usable from GoRouter's errorBuilder and a missing router child.
class AppRecoveryPage extends StatelessWidget {
  const AppRecoveryPage({
    super.key,
    required this.onRetry,
    this.title,
    this.body,
  });

  final VoidCallback onRetry;
  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 48),
                  const SizedBox(height: 20),
                  Text(title ?? l.appRecoveryTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(body ?? l.appRecoveryBody, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l.actionRetry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
