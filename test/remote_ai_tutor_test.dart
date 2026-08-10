import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:voix/data/content/scenario_catalog.dart';
import 'package:voix/data/models/conversation.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/services/remote_ai_tutor_service.dart';

/// A language model will eventually return the wrong shape — a score as a
/// string, a null where an object was promised, prose instead of JSON. None of
/// that may reach the learner as a crash, so these tests feed the parser the
/// bad cases on purpose.
void main() {
  const user = UserProfile(id: 'u1', name: 'Hrithik');
  final scenario = ScenarioCatalog.byId('restaurant');

  RemoteAiTutorService serviceReturning(String body, {int status = 200}) {
    return RemoteAiTutorService(
      deviceId: 'test-device',
      endpoint: Uri.parse('https://test.invalid/v1/chat'),
      httpClient: MockClient((_) async => http.Response(body, status)),
    );
  }

  group('score coercion', () {
    test('accepts the shapes a model actually produces', () {
      expect(RemoteAiTutorService.score(82), 82);
      expect(RemoteAiTutorService.score(82.6), 83);
      expect(RemoteAiTutorService.score('75'), 75);
      expect(RemoteAiTutorService.score(' 75 '), 75);
      expect(RemoteAiTutorService.score('75.4'), 75);
    });

    test('clamps out-of-range values instead of trusting them', () {
      // A score above 100 would overflow the progress rings on the results
      // screen; a negative one would render as an empty ring and read as a
      // punishment.
      expect(RemoteAiTutorService.score(140), 100);
      expect(RemoteAiTutorService.score(-20), 0);
    });

    test('falls back to a neutral score for nonsense', () {
      expect(RemoteAiTutorService.score(null), 70);
      expect(RemoteAiTutorService.score('very good'), 70);
      expect(RemoteAiTutorService.score({'a': 1}), 70);
    });
  });

  group('respond', () {
    test('parses a well-formed reply', () async {
      final service = serviceReturning(
        jsonEncode({
          'content': jsonEncode({
            'reply': 'Of course! What would you like to drink?',
            'corrections': [
              {
                'original': 'I want eat pizza',
                'corrected': 'I want to eat pizza',
                'explanation': 'After "want", use "to" before the verb.',
                'type': 'grammar',
              }
            ],
            'slang': null,
          }),
        }),
      );

      final turn = await service.respond(
        scenario: scenario,
        history: const [],
        userMessage: 'I want eat pizza',
        user: user,
      );

      expect(turn.reply, 'Of course! What would you like to drink?');
      expect(turn.corrections, hasLength(1));
      expect(turn.corrections.first.corrected, 'I want to eat pizza');
      expect(turn.corrections.first.type, CorrectionType.grammar);
      expect(turn.introducedSlang, isNull);
    });

    test('drops a correction that changes nothing', () async {
      // Models sometimes "correct" a sentence to itself. Showing that to a
      // learner implies they made a mistake they did not make.
      final service = serviceReturning(
        jsonEncode({
          'content': jsonEncode({
            'reply': 'Nice!',
            'corrections': [
              {
                'original': 'I like coffee',
                'corrected': 'I like coffee',
                'explanation': 'Looks good.',
              }
            ],
          }),
        }),
      );

      final turn = await service.respond(
        scenario: scenario,
        history: const [],
        userMessage: 'I like coffee',
        user: user,
      );
      expect(turn.corrections, isEmpty);
    });

    test('falls back to the local tutor when the backend errors', () async {
      final service = serviceReturning('{"error":"boom"}', status: 502);

      final turn = await service.respond(
        scenario: scenario,
        history: const [],
        userMessage: 'Hello',
        user: user,
      );

      // Still a real reply — the learner never sees the failure.
      expect(turn.reply, isNotEmpty);
      expect(service.usingFallback, isTrue);
    });

    test('falls back when the model returns prose instead of JSON', () async {
      final service = serviceReturning(
        jsonEncode({'content': 'Sure! What would you like to order?'}),
      );

      final turn = await service.respond(
        scenario: scenario,
        history: const [],
        userMessage: 'Hello',
        user: user,
      );
      expect(turn.reply, isNotEmpty);
      expect(service.usingFallback, isTrue);
    });

    test('falls back when the JSON is valid but has no reply', () async {
      final service = serviceReturning(
        jsonEncode({
          'content': jsonEncode({'corrections': []}),
        }),
      );

      final turn = await service.respond(
        scenario: scenario,
        history: const [],
        userMessage: 'Hello',
        user: user,
      );
      expect(turn.reply, isNotEmpty);
    });
  });

  group('summarise', () {
    test('parses a full report', () async {
      final service = serviceReturning(
        jsonEncode({
          'content': jsonEncode({
            'corrections': [
              {
                'original': 'He go',
                'corrected': 'He goes',
                'explanation': 'Third person takes -s.',
                'type': 'grammar',
              }
            ],
            'vocabulary': [
              {'simple': 'good', 'better': 'excellent', 'meaning': 'very good'}
            ],
            'phrases': ['Could you repeat that?', '', '  '],
            'slang': [
              {'term': 'no cap', 'meaning': 'no lie', 'example': 'That was fun, no cap.'}
            ],
            'fluencyScore': '88',
            'pronunciationScore': 84.2,
            'confidenceScore': 200,
            'encouragement': 'Really strong today.',
          }),
        }),
      );

      final summary = await service.summarise(
        scenario: scenario,
        history: const [],
        user: user,
      );

      expect(summary.corrections, hasLength(1));
      expect(summary.vocabulary.first.better, 'excellent');
      // Blank entries are dropped rather than rendered as empty rows.
      expect(summary.phrases, ['Could you repeat that?']);
      expect(summary.slang.first.term, 'no cap');
      expect(summary.fluencyScore, 88);
      expect(summary.pronunciationScore, 84);
      expect(summary.confidenceScore, 100);
      expect(summary.encouragement, 'Really strong today.');
    });

    test('survives every field being the wrong type', () async {
      final service = serviceReturning(
        jsonEncode({
          'content': jsonEncode({
            'corrections': 'oops',
            'vocabulary': {'not': 'a list'},
            'phrases': null,
            'slang': 42,
            'fluencyScore': null,
            'encouragement': null,
          }),
        }),
      );

      final summary = await service.summarise(
        scenario: scenario,
        history: const [],
        user: user,
      );

      expect(summary.corrections, isEmpty);
      expect(summary.vocabulary, isEmpty);
      expect(summary.phrases, isEmpty);
      expect(summary.slang, isEmpty);
      expect(summary.fluencyScore, 70);
      expect(summary.encouragement, isNotEmpty);
    });

    test('falls back to the local report when the backend is unreachable',
        () async {
      final service = RemoteAiTutorService(
        deviceId: 'test-device',
        endpoint: Uri.parse('https://test.invalid/v1/chat'),
        httpClient: MockClient((_) async => throw const SocketishFailure()),
      );

      final summary = await service.summarise(
        scenario: scenario,
        history: const [],
        user: user,
      );

      // A real, scored report rather than an exception on the results screen.
      expect(summary.fluencyScore, greaterThan(0));
      expect(service.usingFallback, isTrue);
    });
  });
}

/// Stands in for a connection failure without depending on dart:io.
class SocketishFailure implements Exception {
  const SocketishFailure();
}
