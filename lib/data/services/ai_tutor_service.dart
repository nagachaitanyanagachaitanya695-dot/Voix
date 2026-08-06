import 'dart:math';

import '../content/slang_catalog.dart';
import '../models/conversation.dart';
import '../models/user_profile.dart';
import 'grammar_engine.dart';

/// What the tutor produces for one learner turn.
class TutorTurn {
  const TutorTurn({
    required this.reply,
    this.corrections = const [],
    this.introducedSlang,
  });

  final String reply;

  /// Fixes for the learner's message that produced this reply.
  final List<Correction> corrections;

  /// Set when the tutor deliberately teaches a new slang term (Gen-Z mode).
  final SlangTerm? introducedSlang;
}

/// The contract the conversation screen talks to.
///
/// Kept behind an interface so a hosted LLM can replace the on-device
/// implementation without touching the UI. Note that a production LLM
/// integration must go through *your own* backend — shipping a provider API
/// key inside the APK exposes it to anyone who unzips the app.
abstract interface class AiTutorService {
  Future<TutorTurn> respond({
    required Scenario scenario,
    required List<ChatMessage> history,
    required String userMessage,
    required UserProfile user,
  });

  Future<ConversationSummary> summarise({
    required Scenario scenario,
    required List<ChatMessage> history,
    required UserProfile user,
  });
}

/// On-device tutor.
///
/// Combines [GrammarEngine] for correction with a scenario-aware dialogue
/// planner. It is deliberately deterministic given the same inputs, which
/// makes the conversation flow testable and keeps the app fully functional
/// offline — the stated requirement for lesson caching applies just as much
/// to the feature learners open first.
class LocalAiTutorService implements AiTutorService {
  LocalAiTutorService({Random? random}) : _random = random ?? Random();

  final Random _random;

  // Response latency is simulated so the typing indicator and the
  // "thinking" state are exercised exactly as they will be with a network
  // backend behind the same interface.
  static const _thinkTime = Duration(milliseconds: 850);

  @override
  Future<TutorTurn> respond({
    required Scenario scenario,
    required List<ChatMessage> history,
    required String userMessage,
    required UserProfile user,
  }) async {
    await Future<void>.delayed(_thinkTime);

    final corrections = GrammarEngine.analyse(userMessage);
    final turnIndex = history.where((m) => m.speaker == Speaker.user).length;
    final genZ = user.mode == LearningMode.genZ;

    final buffer = StringBuffer();

    // 1. React to what was actually said, so the reply never reads as canned.
    buffer.write(_acknowledge(userMessage, genZ: genZ));

    // 2. Deliver the correction conversationally rather than as a red mark.
    if (corrections.isNotEmpty && _shouldCoachInline(turnIndex)) {
      final c = corrections.first;
      buffer.write(
        genZ
            ? ' quick tip — "${c.corrected}" sounds more natural btw.'
            : ' One small thing: try saying "${c.corrected}".',
      );
    }

    // 3. Keep the conversation moving with a scenario-appropriate question.
    buffer.write(' ${_followUp(scenario, userMessage, turnIndex, genZ: genZ)}');

    SlangTerm? slang;
    if (genZ && turnIndex > 0 && turnIndex % 2 == 0) {
      slang = SlangCatalog.random(1, seed: turnIndex + scenario.id.length).first;
      buffer.write(
        ' (btw "${slang.term}" = ${slang.meaning.toLowerCase()} — '
        'try using it!)',
      );
    }

    return TutorTurn(
      reply: buffer.toString().trim(),
      corrections: corrections,
      introducedSlang: slang,
    );
  }

  /// Correcting every single turn is discouraging; the tutor stays quiet on
  /// the opening turn and then coaches on most, but not all, of the rest.
  bool _shouldCoachInline(int turnIndex) => turnIndex > 0 && turnIndex % 3 != 2;

  // ── Reaction ───────────────────────────────────────────────────────────
  static const _positive = [
    'great', 'good', 'love', 'like', 'happy', 'nice', 'awesome', 'fun',
    'excited', 'enjoy', 'best', 'amazing', 'yes', 'sure', 'fine', 'well',
  ];
  static const _negative = [
    'tired', 'bad', 'sad', 'hard', 'difficult', 'problem', 'worried',
    'nervous', 'stress', 'boring', 'no', 'cannot', "can't", 'sorry',
  ];

  String _acknowledge(String text, {required bool genZ}) {
    final lower = text.toLowerCase();
    final isQuestion = lower.contains('?') ||
        RegExp(r'^\s*(what|why|how|when|where|who|can|could|do|does|is|are)\b')
            .hasMatch(lower);

    if (isQuestion) {
      return genZ ? 'ooh good question.' : "That's a good question.";
    }

    final positives = _positive.where(lower.contains).length;
    final negatives = _negative.where(lower.contains).length;

    if (negatives > positives) {
      return genZ
          ? _pick(['ugh that\'s rough.', 'fr that sounds tough.', 'oof, valid.'])
          : _pick([
              "I'm sorry to hear that.",
              'That does sound difficult.',
              'I understand — that is not easy.',
            ]);
    }
    if (positives > 0) {
      return genZ
          ? _pick(['lets goo!', 'okay that\'s so real.', 'love that fr.'])
          : _pick([
              "That's wonderful!",
              'Nice — I like that.',
              'That sounds great!',
            ]);
    }

    // Short answers get a nudge for more; longer ones get acknowledgement.
    final words = text.trim().split(RegExp(r'\s+')).length;
    if (words <= 3) {
      return genZ ? 'okay okay.' : 'I see.';
    }
    return genZ
        ? _pick(['ok i hear you.', 'yeah makes sense.'])
        : _pick(['Thanks for sharing that.', 'Got it.', 'That makes sense.']);
  }

  // ── Follow-up planning ─────────────────────────────────────────────────
  /// Per-scenario question banks. The tutor walks these in order, which gives
  /// each roleplay a believable arc instead of random questions.
  static const _followUps = <String, List<String>>{
    'restaurant': [
      'Are you ready to order, or would you like a few more minutes?',
      'Would you like that spicy or mild?',
      'Can I get you anything else — a dessert, maybe?',
      'How was everything today?',
      'Would you like the bill together or separately?',
    ],
    'interview': [
      'What made you interested in this role?',
      'Can you tell me about a challenge you faced and how you handled it?',
      'What would you say is your biggest strength?',
      'Where do you see yourself in a few years?',
      'Do you have any questions for me?',
    ],
    'weekend': [
      'Who did you go with?',
      'What was the best part of it?',
      'Did anything unexpected happen?',
      'Would you do it again next weekend?',
      'What are you planning for the coming weekend?',
    ],
    'shopping': [
      'What size do you usually take?',
      'Would you like to try it on?',
      'Do you prefer the blue one or the black one?',
      'Will you be paying by card or cash?',
      'Would you like a bag for that?',
    ],
    'doctor': [
      'How long have you been feeling this way?',
      'Does anything make it better or worse?',
      'Have you taken any medicine for it?',
      'Are you sleeping and eating normally?',
      'Do you have any allergies I should know about?',
    ],
    'airport': [
      'Do you have any bags to check in?',
      'Would you prefer a window or an aisle seat?',
      'Did you pack your bags yourself?',
      'Do you know which gate you need?',
      'Is there anything fragile in your luggage?',
    ],
    'presentation': [
      'Could you tell us the main goal of your project?',
      'What problem does it solve?',
      'How did you approach the research?',
      'What results did you get?',
      'What would you do differently next time?',
    ],
    'free_chat': [
      'What have you been up to lately?',
      'Tell me more about that — what happened next?',
      'How did that make you feel?',
      'What do you enjoy doing when you have free time?',
      'Is there something you would like to get better at?',
    ],
    'gz_group_chat': [
      'wait so what did you think of the ending??',
      'ok but who was your fav character',
      'are you watching anything else rn',
      'should we do a watch party this weekend',
      'ok rate it out of 10, be honest',
    ],
    'gz_hype': [
      'ok but what shoes are you wearing with it',
      'where did you even get that',
      'are you going somewhere or just vibing',
      'should I match with you or nah',
      'send a pic when you\'re ready fr',
    ],
    'gz_gaming': [
      'what happened on that last push tho',
      'you wanna switch characters this round?',
      'are you on mic or typing',
      'how long have you been playing today',
      'ok last game and then sleep, deal?',
    ],
    'gz_social': [
      'ok what\'s the vibe of the pics — funny or aesthetic',
      'how many are you posting',
      'should I use a song or nah',
      'do captions even matter anymore lol',
      'ok pick one: emoji only or full sentence',
    ],
    'gz_formal_switch': [
      'nice! ok next one: "this meeting couldve been an email"',
      'ok try: "im lowkey confused about the brief"',
      'now: "the client is being kinda sus about the budget"',
      'last one: "ngl i need more time on this"',
      'you got it — which one felt hardest?',
    ],
  };

  static const _generic = [
    'What do you think about that?',
    'Can you tell me a bit more?',
    'How would you describe it in your own words?',
    'What happened after that?',
    'Why do you think that is?',
  ];

  String _followUp(
    Scenario scenario,
    String userMessage,
    int turnIndex, {
    required bool genZ,
  }) {
    // If the learner asked something, answer the shape of their question
    // before steering back to the scenario.
    final lower = userMessage.toLowerCase();
    if (lower.contains('recommend') || lower.contains('suggest')) {
      return scenario.id == 'restaurant'
          ? 'The butter chicken is very popular — would you like to try it?'
          : 'I would start with whatever feels most comfortable for you. '
              'What sounds good?';
    }
    if (lower.trim() == 'i dont know' ||
        lower.trim() == "i don't know" ||
        lower.contains('no idea')) {
      return genZ
          ? 'all good, take your time. just say whatever comes to mind'
          : "That's completely fine. Take your time — even a short answer "
              'is good practice.';
    }

    final bank = _followUps[scenario.id] ?? _generic;
    return bank[turnIndex % bank.length];
  }

  String _pick(List<String> options) => options[_random.nextInt(options.length)];

  // ── Summary ────────────────────────────────────────────────────────────
  @override
  Future<ConversationSummary> summarise({
    required Scenario scenario,
    required List<ChatMessage> history,
    required UserProfile user,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final userTurns =
        history.where((m) => m.speaker == Speaker.user).toList(growable: false);
    final allCorrections = <Correction>[];
    for (final t in userTurns) {
      allCorrections.addAll(t.corrections);
    }

    // Deduplicate: the same explanation repeated across turns is one lesson,
    // not three.
    final seen = <String>{};
    final corrections = <Correction>[];
    for (final c in allCorrections) {
      if (seen.add(c.explanation)) corrections.add(c);
    }

    final words = userTurns
        .expand((m) => m.text.toLowerCase().split(RegExp("[^a-z']+")))
        .where((w) => w.length > 2)
        .toList();
    final uniqueWords = words.toSet();

    final vocabulary = _vocabularyUpgrades(words);
    final phrases = _phrasesFor(scenario);
    final slang = user.mode == LearningMode.genZ
        ? SlangCatalog.random(2, seed: scenario.id.length + userTurns.length)
        : const <SlangTerm>[];

    // ── Scoring ────────────────────────────────────────────────────────
    // Each score isolates one dimension so the feedback is actionable rather
    // than a single opaque grade.
    final turnCount = userTurns.length;
    final avgWords = turnCount == 0 ? 0.0 : words.length / turnCount;
    final errorRate = turnCount == 0 ? 0.0 : corrections.length / turnCount;
    final variety = words.isEmpty ? 0.0 : uniqueWords.length / words.length;

    // Fluency: how much the learner actually produced, penalised by errors.
    final fluency = _clampScore(
      52 + (avgWords * 3.2) - (errorRate * 22) + (turnCount * 1.5),
    );
    // Pronunciation: proxied by transcript cleanliness. With a real speech
    // backend this would come from the recogniser's per-word confidence.
    final pronunciation = _clampScore(
      64 + (variety * 26) - (errorRate * 12) + (turnCount * 0.8),
    );
    // Confidence: sustained, longer turns without stalling.
    final confidence = _clampScore(
      50 + (turnCount * 3.4) + (avgWords * 1.9) - (errorRate * 8),
    );

    return ConversationSummary(
      corrections: corrections,
      vocabulary: vocabulary,
      phrases: phrases,
      slang: slang,
      fluencyScore: fluency,
      pronunciationScore: pronunciation,
      confidenceScore: confidence,
      encouragement: _encouragement(
        turnCount: turnCount,
        errors: corrections.length,
        name: user.name,
      ),
    );
  }

  static int _clampScore(double v) => v.clamp(35, 99).round();

  /// Words worth upgrading, matched against what the learner actually said.
  static const _upgrades = <String, VocabUpgrade>{
    'good': VocabUpgrade(
      simple: 'Good',
      better: 'Excellent',
      meaning: 'Of very high quality',
      example: 'The service was excellent.',
    ),
    'big': VocabUpgrade(
      simple: 'Big',
      better: 'Huge',
      meaning: 'Extremely large',
      example: 'That was a huge improvement.',
    ),
    'happy': VocabUpgrade(
      simple: 'Happy',
      better: 'Delighted',
      meaning: 'Very pleased',
      example: 'I was delighted to hear it.',
    ),
    'important': VocabUpgrade(
      simple: 'Important',
      better: 'Crucial',
      meaning: 'Absolutely necessary',
      example: 'Daily practice is crucial.',
    ),
    'problem': VocabUpgrade(
      simple: 'Problem',
      better: 'Issue',
      meaning: 'A matter that needs attention',
      example: 'We ran into a small issue.',
    ),
    'bad': VocabUpgrade(
      simple: 'Bad',
      better: 'Poor',
      meaning: 'Below an acceptable standard',
      example: 'The signal was quite poor.',
    ),
    'nice': VocabUpgrade(
      simple: 'Nice',
      better: 'Lovely',
      meaning: 'Very pleasant',
      example: 'That was a lovely evening.',
    ),
    'very': VocabUpgrade(
      simple: 'Very',
      better: 'Extremely',
      meaning: 'To a great degree',
      example: 'It was extremely helpful.',
    ),
    'said': VocabUpgrade(
      simple: 'Said',
      better: 'Mentioned',
      meaning: 'Referred to briefly',
      example: 'She mentioned it yesterday.',
    ),
    'tired': VocabUpgrade(
      simple: 'Tired',
      better: 'Exhausted',
      meaning: 'Extremely tired',
      example: 'I was exhausted after the trip.',
    ),
  };

  List<VocabUpgrade> _vocabularyUpgrades(List<String> words) {
    final used = <VocabUpgrade>[];
    for (final w in words) {
      final up = _upgrades[w];
      if (up != null && !used.any((u) => u.simple == up.simple)) {
        used.add(up);
      }
      if (used.length >= 5) break;
    }
    // Always give the learner something to take away, even from a short chat.
    if (used.length < 3) {
      for (final up in _upgrades.values) {
        if (!used.any((u) => u.simple == up.simple)) used.add(up);
        if (used.length >= 3) break;
      }
    }
    return used;
  }

  static const _phraseBank = <String, List<String>>{
    'restaurant': [
      'Could I see the menu, please?',
      'What would you recommend?',
      "I'll have the same, please.",
      'Could we get the bill, please?',
    ],
    'interview': [
      'Thank you for the opportunity.',
      'Let me give you an example.',
      "That's a great question.",
      'I would love to learn more about the team.',
    ],
    'doctor': [
      "I've been feeling unwell since Monday.",
      'It hurts when I move.',
      'Is there anything I should avoid?',
      'How often should I take this?',
    ],
  };

  static const _defaultPhrases = [
    'Could you repeat that, please?',
    'What do you mean?',
    "I'm not sure about that.",
    'That makes sense!',
  ];

  List<String> _phrasesFor(Scenario scenario) =>
      _phraseBank[scenario.id] ?? _defaultPhrases;

  String _encouragement({
    required int turnCount,
    required int errors,
    required String name,
  }) {
    final first = name.trim().split(' ').first;
    if (turnCount == 0) {
      return 'Every conversation counts, $first. Try again whenever you like!';
    }
    if (errors == 0) {
      return 'Flawless run, $first — not a single correction needed. '
          'Try a harder scenario next!';
    }
    if (errors <= 2) {
      return 'Really strong work, $first. Just a couple of small fixes and '
          'you sounded completely natural.';
    }
    return 'Good effort, $first! You kept the conversation going, and that '
        'matters more than being perfect. Review the notes and go again.';
  }
}
