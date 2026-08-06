import 'package:flutter/foundation.dart';

/// A language the app can teach or accept as a native tongue.
///
/// The catalogue is data-driven rather than an enum so new languages ship as
/// a content change — see [LanguageCatalog.all].
@immutable
class Language {
  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.canLearn = true,
    this.available = true,
    this.ttsLocale,
    this.sttLocale,
  });

  /// BCP-47 base code, e.g. `en`, `te`, `hi`, `ta`.
  final String code;

  /// English name, e.g. "Telugu".
  final String name;

  /// Endonym, e.g. "తెలుగు".
  final String nativeName;
  final String flag;

  /// False for languages offered only as a *native* language.
  final bool canLearn;

  /// False shows the entry as "Coming soon" — the pattern the reference
  /// onboarding uses for languages that are announced but not yet live.
  final bool available;

  /// Locale handed to the TTS engine, e.g. `en-US`, `hi-IN`.
  final String? ttsLocale;

  /// Locale handed to the speech recogniser.
  final String? sttLocale;

  String get displayName => nativeName == name ? name : '$nativeName ($name)';

  @override
  bool operator ==(Object other) =>
      other is Language && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// The shipping language set. Launch scope is English (target) with
/// Telugu / Hindi / Tamil / English as native languages.
abstract final class LanguageCatalog {
  static const english = Language(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    flag: '🇬🇧',
    ttsLocale: 'en-US',
    sttLocale: 'en_US',
  );

  static const telugu = Language(
    code: 'te',
    name: 'Telugu',
    nativeName: 'తెలుగు',
    flag: '🇮🇳',
    canLearn: false,
    ttsLocale: 'te-IN',
    sttLocale: 'te_IN',
  );

  static const hindi = Language(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
    canLearn: false,
    ttsLocale: 'hi-IN',
    sttLocale: 'hi_IN',
  );

  static const tamil = Language(
    code: 'ta',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    flag: '🇮🇳',
    canLearn: false,
    ttsLocale: 'ta-IN',
    sttLocale: 'ta_IN',
  );

  // Announced, not yet live — surfaced as "Coming soon" in onboarding.
  static const spanish = Language(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
    available: false,
    ttsLocale: 'es-ES',
  );

  static const french = Language(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
    flag: '🇫🇷',
    available: false,
    ttsLocale: 'fr-FR',
  );

  static const japanese = Language(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
    available: false,
    ttsLocale: 'ja-JP',
  );

  static const all = <Language>[
    english,
    telugu,
    hindi,
    tamil,
    spanish,
    french,
    japanese,
  ];

  /// Languages selectable as the user's native language.
  static List<Language> get nativeOptions =>
      all.where((l) => l.available).toList();

  /// Languages the user can currently learn.
  static List<Language> get learnable =>
      all.where((l) => l.canLearn && l.available).toList();

  /// Announced-but-unavailable languages, for the "Coming soon" screen.
  static List<Language> get upcoming =>
      all.where((l) => !l.available).toList();

  static Language byCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => english);
}
