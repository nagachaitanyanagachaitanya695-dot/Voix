import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../models/language.dart';
import '../models/user_profile.dart';
import '../models/word_insight.dart';
import 'word_forms.dart';

/// Answers "what does this word actually mean?".
///
/// Two sources, and the order matters. The on-device rules run first and
/// always: they are instant, free, and produce the forms a learner most often
/// wants. The tutor is then asked for the parts rules cannot give — meaning,
/// history, examples, the translation — and its answer is layered on top.
///
/// So the sheet fills in immediately and deepens a moment later, rather than
/// showing a spinner over an empty screen while a network call decides whether
/// the feature works at all. With no backend configured it simply stops after
/// the first step and says so.
class WordService {
  WordService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Kept short. This runs while a learner is staring at a sheet that has
  /// already shown them something useful; waiting a long time to add to it is
  /// worse than not adding to it.
  static const _timeout = Duration(seconds: 12);

  /// What the rules alone can say. Never fails, never waits.
  static WordInsight local(String word) {
    final w = word.trim();
    return WordInsight(word: w, forms: WordForms.of(w));
  }

  /// The full explanation, or the local one if the tutor cannot be reached.
  Future<WordInsight> lookUp(
    String word, {
    required UserProfile user,
    required String deviceId,
  }) async {
    final base = local(word);
    if (!BackendConfig.isConfigured) return base;

    final native = LanguageCatalog.byCode(user.nativeLanguageCode);
    try {
      final response = await _http
          .post(
            BackendConfig.wordUrl,
            headers: {
              'Content-Type': 'application/json',
              'x-voix-app-token': BackendConfig.appToken,
              'x-voix-device': deviceId,
            },
            body: jsonEncode({
              'word': word.trim(),
              'level': user.proficiency.name,
              'nativeLanguage': native.name,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('WordService: ${response.statusCode} ${response.body}');
        return base;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['content'];
      final parsed = content is String
          ? jsonDecode(content) as Map<String, dynamic>
          : content as Map<String, dynamic>;

      return base.mergedWith(WordInsight.fromJson(parsed));
    } on TimeoutException {
      return base;
    } catch (e) {
      // A malformed answer must degrade to the offline explanation, not to an
      // error: the learner asked a simple question and deserves the part of it
      // we can still answer.
      debugPrint('WordService: lookup failed ($e)');
      return base;
    }
  }

  void dispose() => _http.close();
}
