import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Master switch for cold-start `[BOOT n]` diagnostic prints.
///
/// Flip to `false` to silence every `bootLog(...)` call in one go.
/// Used to hunt down "loading freezes" — leave on until the offending
/// step is identified, then turn off.
const bool kBootDiagnostics = false;

/// Print a `[BOOT n]` line gated by [kBootDiagnostics]. The compiler
/// tree-shakes the body when the constant is `false`, so disabling it
/// has zero runtime cost.
void bootLog(String msg) {
  if (!kBootDiagnostics) return;
  // ignore: avoid_print
  print('[BOOT] $msg');
}

/// Centralized logging.
///
/// Defaults to silent for routine traffic so `flutter run` isn't drowned by
/// per-request / per-SSE-event chatter. Flip individual tags on at runtime
/// (or via [enableAll]) when you actually want to see them.
///
/// Usage:
///   AppLog.d(LogTag.auth, () => 'bootstrap serverId=$id');
///   AppLog.w(LogTag.network, () => 'retrying after $err');
///   AppLog.e(LogTag.chat, () => 'send failed', error: e, stackTrace: st);
///
/// Toggling at runtime (e.g. from a debug screen or breakpoint):
///   AppLog.enable(LogTag.auth);
///   AppLog.minLevel = Level.debug;
class LogTag {
  const LogTag._(this.name);
  final String name;

  static const auth = LogTag._('auth');
  static const token = LogTag._('token');
  static const network = LogTag._('network');
  static const chat = LogTag._('chat');
  static const sse = LogTag._('sse');
  static const general = LogTag._('general');

  static const all = <LogTag>[auth, token, network, chat, sse, general];
}

class AppLog {
  AppLog._();

  /// Below this level nothing is logged at all (regardless of tag).
  /// Defaults to [Level.warning] — info/debug calls are suppressed.
  static Level minLevel = kDebugMode ? Level.warning : Level.error;

  /// Per-tag debug/info opt-in. warn/error always print (subject to [minLevel]).
  /// Empty by default → no info/debug output anywhere.
  static final Set<String> _enabled = <String>{};

  static final Logger _logger = Logger(
    printer: SimplePrinter(printTime: false, colors: false),
  );

  static void enable(LogTag tag) => _enabled.add(tag.name);
  static void disable(LogTag tag) => _enabled.remove(tag.name);
  static void enableAll() => _enabled.addAll(LogTag.all.map((t) => t.name));
  static void disableAll() => _enabled.clear();
  static bool isEnabled(LogTag tag) => _enabled.contains(tag.name);

  static void d(LogTag tag, Object Function() msg) {
    if (minLevel.index > Level.debug.index) return;
    if (!_enabled.contains(tag.name)) return;
    _logger.d('[${tag.name}] ${msg()}');
  }

  static void i(LogTag tag, Object Function() msg) {
    if (minLevel.index > Level.info.index) return;
    if (!_enabled.contains(tag.name)) return;
    _logger.i('[${tag.name}] ${msg()}');
  }

  static void w(
    LogTag tag,
    Object Function() msg, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (minLevel.index > Level.warning.index) return;
    _logger.w('[${tag.name}] ${msg()}', error: error, stackTrace: stackTrace);
  }

  static void e(
    LogTag tag,
    Object Function() msg, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (minLevel.index > Level.error.index) return;
    _logger.e('[${tag.name}] ${msg()}', error: error, stackTrace: stackTrace);
  }
}
