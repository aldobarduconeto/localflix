import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

/// One backend per process. Legacy preferences are copied once, never cleared.
class PreferencesStore {
  static const migrationKey = 'localflix_async_preferences_migrated_v1';
  static Future<SharedPreferencesAsync>? _opening;

  static Future<SharedPreferencesAsync> open() => _opening ??= _initialize();

  /// Invalid cache data is safe to rebuild and must not block startup.
  static Future<Map<String, dynamic>> readMap(
    SharedPreferencesAsync prefs,
    String key,
  ) async {
    try {
      final decoded = jsonDecode(await prefs.getString(key) ?? '{}');
      if (decoded is Map<String, dynamic>) return decoded;
    } on TypeError {
      // Ignore preferences stored using an incompatible type.
    } on FormatException {
      // Ignore malformed JSON.
    }
    return {};
  }

  static Future<void> writeCache(
    SharedPreferencesAsync prefs,
    String key,
    Map<String, dynamic> cache,
  ) async {
    for (final key
        in cache.keys
            .take((cache.length - 1500).clamp(0, cache.length))
            .toList()) {
      cache.remove(key);
    }
    await prefs.setString(key, jsonEncode(cache));
  }

  static Future<SharedPreferencesAsync> _initialize() async {
    try {
      final prefs = SharedPreferencesAsync();
      if (!await prefs.containsKey(migrationKey)) {
        await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
          legacySharedPreferencesInstance:
              await SharedPreferences.getInstance(),
          sharedPreferencesAsyncOptions: const SharedPreferencesOptions(),
          migrationCompletedKey: migrationKey,
        );
      }
      return prefs;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }
}
