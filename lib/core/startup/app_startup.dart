import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../../firebase_options.dart';
import '../storage/media_cache.dart';
import '../storage/video_stream_cache.dart';

/// FCM watches this so an initialization that finishes after its timeout still
/// activates notification listeners. An optional service never gates the UI.
final firebaseInitializedProvider = StateProvider<bool>((ref) => false);

final startupTaskTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 8),
);

typedef StartupErrorReporter = void Function(
  String task,
  Object error,
  StackTrace stack,
);

final startupErrorReporterProvider = Provider<StartupErrorReporter>((ref) {
  return (task, error, stack) => FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'application startup',
        context: ErrorDescription('while initializing $task'),
      ));
});

/// Separate operations keep a failed plugin from preventing unrelated startup
/// work, and let tests exercise a hung platform channel without native plugins.
class AppStartupTasks {
  const AppStartupTasks({
    required this.initializeFirebase,
    required this.initializeVideoBackend,
    required this.initializeAudioBackend,
    required this.trimAudioCache,
    required this.initializeVideoCache,
  });

  final Future<bool> Function() initializeFirebase;
  final FutureOr<void> Function() initializeVideoBackend;
  final FutureOr<void> Function() initializeAudioBackend;
  final Future<void> Function() trimAudioCache;
  final Future<void> Function() initializeVideoCache;
}

final appStartupTasksProvider = Provider<AppStartupTasks>((ref) {
  return AppStartupTasks(
    initializeFirebase: _initializeFirebase,
    // fvp adds a software-decoding fallback on Android and supplies the
    // video_player backend on Windows/Linux.
    initializeVideoBackend: _registerVideoBackend,
    initializeAudioBackend: () {
      if (!kIsWeb && !_audioBackendRegistered) {
        JustAudioMediaKit.ensureInitialized();
        _audioBackendRegistered = true;
      }
    },
    trimAudioCache: () async {
      if (!kIsWeb) await MediaCache.trimAudioCache();
    },
    initializeVideoCache: () async {
      if (!kIsWeb) await VideoStreamCache.initialize();
    },
  );
});

bool _videoBackendRegistered = false;
bool _audioBackendRegistered = false;

void _registerVideoBackend() {
  // A manual UI recovery creates a new ProviderScope, but players from the
  // old scope can still be disposing. Never swap their process-wide backend.
  if (_videoBackendRegistered) return;
  fvp.registerWith(options: {
    'platforms': ['windows', 'linux', 'android']
  });
  _videoBackendRegistered = true;
}

/// Firebase, cache maintenance, and the optional video proxy start after the
/// first painted frame. They used to be awaited before runApp, leaving only
/// the native launch background if any platform call never completed.
final appStartupProvider = FutureProvider<void>((ref) async {
  final tasks = ref.read(appStartupTasksProvider);
  final timeout = ref.read(startupTaskTimeoutProvider);
  final report = ref.read(startupErrorReporterProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);

  Future<void> attempt(String task, FutureOr<void> Function() operation) async {
    try {
      await Future<void>.sync(operation).timeout(timeout);
    } catch (error, stack) {
      report(task, error, stack);
    }
  }

  // Registration is synchronous and must precede any media widgets. Swapping
  // a backend after a player was constructed would strand that player's ID.
  final backends = [
    attempt('video playback', tasks.initializeVideoBackend),
    attempt('audio playback', tasks.initializeAudioBackend),
  ];
  await WidgetsBinding.instance.endOfFrame;
  if (disposed) return;

  await Future.wait([
    ...backends,
    attempt('Firebase', () async {
      final ready = await tasks.initializeFirebase();
      // This lives in the original operation, not its timed-out wrapper. A
      // slow successful native response must still make FCM available.
      if (!disposed && ready) {
        ref.read(firebaseInitializedProvider.notifier).state = true;
      }
    }),
    attempt('audio cache maintenance', tasks.trimAudioCache),
    attempt('video cache', tasks.initializeVideoCache),
  ]);
});

Future<bool>? _firebaseInitialization;

Future<bool> _initializeFirebase() {
  // A timed-out native initialization may still be running when the user
  // retries the interface. Reuse it instead of racing a second initializeApp.
  final active = _firebaseInitialization;
  if (active != null) return active;
  final attempt = _initializeFirebaseOnce();
  _firebaseInitialization = attempt;
  return attempt.whenComplete(() {
    if (identical(_firebaseInitialization, attempt)) {
      _firebaseInitialization = null;
    }
  });
}

Future<bool> _initializeFirebaseOnce() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return false;
  }
  if (Firebase.apps.isNotEmpty) return true;

  try {
    // Reuse native google-services/plist configuration. Supplying placeholder
    // Dart options first can race native setup and cause duplicate-app errors.
    await Firebase.initializeApp();
  } catch (_) {
    if (Firebase.apps.isNotEmpty) return true;
    final options = DefaultFirebaseOptions.currentPlatform;
    const placeholder = 'REPLACE_ME';
    final usable = [
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ].every((value) => value.isNotEmpty && value != placeholder);
    if (!usable) rethrow;
    await Firebase.initializeApp(options: options);
  }
  return Firebase.apps.isNotEmpty;
}
