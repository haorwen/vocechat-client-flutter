import 'package:shared_preferences/shared_preferences.dart';

class PreferenceWriteException implements Exception {
  const PreferenceWriteException();

  @override
  String toString() => 'Unable to persist account settings';
}

/// SharedPreferences updates its Dart cache before the native commit. A false
/// result must not become an apparently successful login backed only by memory.
Future<void> requirePreferenceWrite(
  SharedPreferences preferences,
  Future<bool> write,
) async {
  try {
    if (!await write) throw const PreferenceWriteException();
  } catch (error, stack) {
    try {
      await preferences.reload();
    } catch (_) {
      // Keep the original persistence error if reloading also fails.
    }
    Error.throwWithStackTrace(error, stack);
  }
}
