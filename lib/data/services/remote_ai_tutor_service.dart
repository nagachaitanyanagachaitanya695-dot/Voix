import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../models/conversation.dart';
import '../models/user_profile.dart';
import 'ai_tutor_service.dart';

/// The tutor, backed by a real language model.
///
/// Unlike [LocalAiTutorService] this one genuinely understands what the
/// learner said: it answers off-topic questions, translates on request, and
/// explains a mistake in the learner's own language.
///
/// It calls **your backend**, never OpenAI directly — the API key lives on the
/// server, because anything compiled into an APK can be extracted from it. See
/// `backend/README.md`.
///
/// Every failure falls back to [_fallback]. A learner on a train with no signal
/// still gets a conversation; it is just the scripted one. That matters more
/// than it sounds: the alternative is an error dialog in the middle of the
/// feature the whole app is built around.
class RemoteAiTutorService implements AiTutorService {
  RemoteAiTutorService({
    AiTutorService? fallback,
    http.Client? httpClient,
    Uri? endpoint,
    required this.deviceId,
  })  : _fallback = fallback ?? LocalAiTutorService(),
        _http = httpClient ?? http.Client(),
        _endpoint = endpoint;

  final AiTutorService _fallback;
  final http.Client _http;

  /// Overrides [BackendConfig.chatUrl]. Injected by tests so the parsing here
  /// can be exercised against a stub without a deployed backend.
  final Uri? _endpoint;

  /// Identifies the device to the backend's daily spending cap.
  final String deviceId;

  Uri? get _chatUrl {
    if (_endpoint != null) return _endpoint;
    return BackendConfig.isConfigured ? BackendConfig.chatUrl : null;
  }

  static const _timeout = Duration(seconds: 20);

  /// True when the last call fell back to the on-device tutor, so the UI can
  /// say "offline mode" rather than quietly getting dumber.
  bool get usingFallback => _usingFallback;
  bool _usingFallback = false;

  @override
  Future<TutorTurn> respond({
    required Scenario scenario,
    required List<ChatMessage> history,
    required String userMessage,
    required UserProfile user,
  }) async {
    final json = await _ask(
      user: user,
      scenario: scenario,
      messages: [
        ..._transcript(history),
        {'role': 'user', 'content': userMessage},
      ],
      task: _replyTask,
    );

    if (json == null) {
      return _fallback.respond(
        scenario: scenario,
        history: history,
        userMessage: userMessage,
        user: user,
      );
    }

    final reply = (json['reply'] as String?)?.trim();
    if (reply == null || reply.isEmpty) {
      // A well-formed response with no reply in it is still a failure.
      return _fallback.respond(
        scenario: scenario,
        history: history,
        userMessage: userMessage,
        user: user,
      );
    }

    return TutorTurn(
      reply: reply,
      corrections: _corrections(json['corrections'], userMessage),
      introducedSlang: _slang(json['slang']),
    );
  }

  @override
  Future<ConversationSummary> summarise({
    required Scenario scenario,
    required List<ChatMessage> history,
    required UserProfile user,
  }) async {
    final json = await _ask(
      user: user,
      scenario: scenario,
      messages: _transcript(history),
      task: _summaryTask,
    );

    if (json == null) {
      return _fallback.summarise(
        scenario: scenario,
        history: history,
        user: user,
      );
    }

    // Scores are the part a model is most likely to return as a string, out of
    // range, or not at all — so each one is coerced and clamped rather than
    // cast. A malformed score must not take down the results screen the
    // learner has been working towards.
    return ConversationSummary(
      corrections: _corrections(json['corrections'], ''),
      vocabulary: _vocabulary(json['vocabulary']),
      phrases: _strings(json['phrases']),
      slang: _slangList(json['slang']),
      fluencyScore: _score(json['fluencyScore']),
      pronunciationScore: _score(json['pronunciationScore']),
      confidenceScore: _score(json['confidenceScore']),
      encouragement: (json['encouragement'] as String?)?.trim() ??
          'Good work today — every conversation makes the next one easier.',
    );
  }

  void dispose() => _http.close();

  // ── Transport ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _ask({
    required UserProfile user,
    required Scenario scenario,
    required List<Map<String, String>> messages,
    required String task,
  }) async {
    final url = _chatUrl;
    if (url == null) {
      _usingFallback = true;
      return null;
    }

    try {
      final response = await _http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-voix-app-token': BackendConfig.appToken,
              'x-voix-device': deviceId,
            },
            body: jsonEncode({
              'level': user.proficiency.name,
              'nativeLanguage': user.nativeLanguageCode,
              'scenario': scenario.title,
              'mode': user.mode.name,
              'messages': [
                ...messages,
                {'role': 'system', 'content': task},
              ],
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('RemoteAiTutorService: ${response.statusCode} '
            '${response.body}');
        _usingFallback = true;
        return null;
      }

      final envelope = jsonDecode(response.body) as Map<String, dynamic>;
      final content = envelope['content'] as String? ?? '';
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        _usingFallback = true;
        return null;
      }
      _usingFallback = false;
      return decoded;
    } catch (e) {
      // Includes the timeout, no connectivity, and a model that returned
      // something that is not JSON despite being asked for JSON.
      debugPrint('RemoteAiTutorService: falling back ($e)');
      _usingFallback = true;
      return null;
    }
  }

  List<Map<String, String>> _transcript(List<ChatMessage> history) => [
        // Only the recent turns: the backend caps this again, but sending a
        // whole hour of conversation on every reply is money spent on tokens
        // the tutor does not need.
        for (final m in history.length > 16
            ? history.sublist(history.length - 16)
            : history)
          {
            'role': m.speaker == Speaker.user ? 'user' : 'assistant',
            'content': m.text,
          },
      ];

  static const _replyTask = '''
Reply as the tutor. Return ONLY a JSON object of this shape:
{
  "reply": "your spoken reply, 1-3 short sentences, ending with a question",
  "corrections": [
    {"original": "what they said", "corrected": "the fixed version",
     "explanation": "one short sentence a learner would understand",
     "type": "grammar|vocabulary|phrasing|pronunciation"}
  ],
  "slang": {"term": "", "meaning": "", "example": ""}
}
"corrections" must be [] when the learner made no mistake worth correcting.
"slang" must be null unless you deliberately taught a slang term this turn.''';

  static const _summaryTask = '''
The conversation is over. Review it and return ONLY a JSON object:
{
  "corrections": [{"original": "", "corrected": "", "explanation": "", "type": "grammar"}],
  "vocabulary": [{"simple": "the plain word they used", "better": "a stronger one",
                  "meaning": "", "example": ""}],
  "phrases": ["a useful phrase from this conversation"],
  "slang": [{"term": "", "meaning": "", "example": ""}],
  "fluencyScore": 0-100,
  "pronunciationScore": 0-100,
  "confidenceScore": 0-100,
  "encouragement": "two warm sentences naming something they actually did well"
}
Score honestly but kindly: these are learners, and a low score ends streaks.
Base pronunciationScore only on what the transcript reveals; if you cannot
tell, score it near fluencyScore.''';

  // ── Parsing ────────────────────────────────────────────────────────────
  // Everything below assumes the model may return the wrong shape, because it
  // sometimes will. Nothing here throws.

  static List<Correction> _corrections(Object? raw, String fallbackOriginal) {
    if (raw is! List) return const [];
    final out = <Correction>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final corrected = (item['corrected'] as String?)?.trim();
      if (corrected == null || corrected.isEmpty) continue;
      final original =
          (item['original'] as String?)?.trim().isNotEmpty ?? false
              ? (item['original'] as String).trim()
              : fallbackOriginal;
      if (original.isEmpty || original == corrected) continue;
      out.add(
        Correction(
          original: original,
          corrected: corrected,
          explanation: (item['explanation'] as String?)?.trim() ?? '',
          type: _correctionType(item['type']),
        ),
      );
    }
    return out;
  }

  static CorrectionType _correctionType(Object? raw) {
    if (raw is! String) return CorrectionType.grammar;
    for (final t in CorrectionType.values) {
      if (t.name.toLowerCase() == raw.toLowerCase()) return t;
    }
    return CorrectionType.grammar;
  }

  static SlangTerm? _slang(Object? raw) {
    if (raw is! Map) return null;
    final term = (raw['term'] as String?)?.trim();
    final meaning = (raw['meaning'] as String?)?.trim();
    if (term == null || term.isEmpty || meaning == null || meaning.isEmpty) {
      return null;
    }
    return SlangTerm(
      term: term,
      meaning: meaning,
      example: (raw['example'] as String?)?.trim() ?? '',
    );
  }

  static List<SlangTerm> _slangList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (_slang(item) case final s?) s,
    ];
  }

  static List<VocabUpgrade> _vocabulary(Object? raw) {
    if (raw is! List) return const [];
    final out = <VocabUpgrade>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final simple = (item['simple'] as String?)?.trim();
      final better = (item['better'] as String?)?.trim();
      if (simple == null || simple.isEmpty) continue;
      if (better == null || better.isEmpty) continue;
      out.add(
        VocabUpgrade(
          simple: simple,
          better: better,
          meaning: (item['meaning'] as String?)?.trim() ?? '',
          example: (item['example'] as String?)?.trim() ?? '',
        ),
      );
    }
    return out;
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  /// Coerces whatever the model produced into a sane 0–100.
  @visibleForTesting
  static int score(Object? raw) => _score(raw);

  static int _score(Object? raw) {
    final value = switch (raw) {
      final int i => i,
      final double d => d.round(),
      final String s => int.tryParse(s.trim()) ??
          double.tryParse(s.trim())?.round() ??
          70,
      _ => 70,
    };
    return value.clamp(0, 100);
  }
}
