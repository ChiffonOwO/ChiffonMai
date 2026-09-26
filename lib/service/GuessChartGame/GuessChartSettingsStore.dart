import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

/// Persistence used by the single-player guess-song settings.
///
/// The legacy [SharedPreferences] API calls `commit()` for every write on
/// Android. The app keeps the (large) song cache in the same preferences file,
/// so saving several settings can synchronously rewrite that whole XML file on
/// the platform thread. Android's async API uses the same file and keys, but
/// writes with `apply()` instead.
class GuessChartSettingsStore {
  static const String _androidKeyPrefix = 'flutter.';
  static const String _androidFileName = 'FlutterSharedPreferences';

  SharedPreferencesAsync? _androidPreferences;

  bool get _useAsyncAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  SharedPreferencesAsync get _androidPrefs {
    return _androidPreferences ??= SharedPreferencesAsync(
      options: const SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions:
            AndroidSharedPreferencesStoreOptions(
          fileName: _androidFileName,
        ),
      ),
    );
  }

  String _androidKey(String key) => '$_androidKeyPrefix$key';

  Future<Map<String, Object?>> read(Set<String> keys) async {
    if (_useAsyncAndroid) {
      try {
        final values = await _androidPrefs.getAll(
          allowList: keys.map(_androidKey).toSet(),
        );
        return {
          for (final entry in values.entries)
            if (entry.key.startsWith(_androidKeyPrefix))
              entry.key.substring(_androidKeyPrefix.length): entry.value,
        };
      } on StateError {
        // Flutter tests and a briefly unregistered plugin have no async
        // platform instance. Keep the legacy path as a compatibility fallback.
      }
    }

    return _readLegacy(keys);
  }

  Future<Map<String, Object?>> _readLegacy(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final key in keys)
        if (prefs.get(key) != null) key: prefs.get(key),
    };
  }

  Future<void> write(Map<String, Object> values) async {
    if (_useAsyncAndroid) {
      try {
        // `apply()` returns as soon as the in-memory preference value is
        // updated; dispatch all changed keys together so the dialog does not
        // wait for a sequence of platform-channel round trips.
        await Future.wait(
          values.entries.map((entry) => _writeAndroid(entry.key, entry.value)),
        );
        return;
      } on StateError {
        // Flutter tests and a briefly unregistered plugin have no async
        // platform instance. Keep the legacy path as a compatibility fallback.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      await _writeLegacy(prefs, entry.key, entry.value);
    }
  }

  Future<void> _writeLegacy(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else {
      throw ArgumentError.value(value, key, 'Unsupported preference value');
    }
  }

  Future<void> _writeAndroid(String key, Object value) {
    final platformKey = _androidKey(key);
    if (value is List<String>) {
      return _androidPrefs.setStringList(platformKey, value);
    }
    if (value is int) {
      return _androidPrefs.setInt(platformKey, value);
    }
    if (value is double) {
      return _androidPrefs.setDouble(platformKey, value);
    }
    if (value is String) {
      return _androidPrefs.setString(platformKey, value);
    }
    throw ArgumentError.value(value, key, 'Unsupported preference value');
  }
}
