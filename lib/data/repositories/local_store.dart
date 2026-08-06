import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences].
///
/// Everything the app persists — profile, activity history, conversation
/// history, theme choice — funnels through here so there is exactly one place
/// that knows the storage keys and the JSON encoding.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  // ── Keys ───────────────────────────────────────────────────────────────
  static const kProfile = 'voix.profile';
  static const kActivity = 'voix.activity';
  static const kSessions = 'voix.sessions';
  static const kThemeMode = 'voix.themeMode';
  static const kOnboarded = 'voix.onboarded';
  static const kSignedIn = 'voix.signedIn';
  static const kSavedPhrases = 'voix.savedPhrases';

  // ── Primitives ─────────────────────────────────────────────────────────
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Wipes every VOIX key. Used by sign-out and "delete account".
  Future<void> clearAll() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith('voix.'))) {
      await _prefs.remove(key);
    }
  }

  // ── JSON helpers ───────────────────────────────────────────────────────
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      // Corrupt entry (interrupted write, schema change) — drop it rather
      // than crashing on launch.
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<dynamic> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } on FormatException {
      _prefs.remove(key);
      return const [];
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));
}
