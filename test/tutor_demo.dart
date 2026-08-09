@Tags(['demo'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/content/scenario_catalog.dart';
import 'package:voix/data/models/conversation.dart';
import 'package:voix/data/models/user_profile.dart';
import 'package:voix/data/services/ai_tutor_service.dart';

/// Prints what the tutor actually replies to arbitrary input, so its real
/// capabilities and limits are visible rather than assumed.
void main() {
  test('what the tutor does with unexpected input', () async {
    final tutor = LocalAiTutorService();
    const user = UserProfile(id: 'd', name: 'Hrithik');
    final scenario = ScenarioCatalog.byId('restaurant');

    final inputs = [
      'I want to order a pizza please',            // on-topic
      'He go to school everyday',                  // grammar error
      'What is the capital of France?',            // off-topic question
      'Translate "good morning" into Telugu',      // translation request
      'నాకు ఇంగ్లీష్ నేర్చుకోవాలి',                      // Telugu input
      'asdkjh qwe zxcv',                           // nonsense
    ];

    var history = <ChatMessage>[];
    for (final input in inputs) {
      final turn = await tutor.respond(
        scenario: scenario,
        history: history,
        userMessage: input,
        user: user,
      );
      // ignore: avoid_print
      print('\nYOU   : $input');
      // ignore: avoid_print
      print('TUTOR : ${turn.reply}');
      if (turn.corrections.isNotEmpty) {
        // ignore: avoid_print
        print('FIX   : ${turn.corrections.first.corrected}');
      }
      history = [
        ...history,
        ChatMessage(
          id: '${history.length}',
          speaker: Speaker.user,
          text: input,
          at: DateTime.now(),
        ),
        ChatMessage(
          id: 't${history.length}',
          speaker: Speaker.tutor,
          text: turn.reply,
          at: DateTime.now(),
        ),
      ];
    }
  });
}
