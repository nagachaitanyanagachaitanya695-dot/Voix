import '../models/lesson.dart';

/// The shipped lesson content.
///
/// Content lives in Dart rather than JSON so it is type-checked at build time
/// and available offline with no first-run fetch. `LessonRepository` reads
/// through this list and can be swapped for a remote source later without any
/// change to the UI layer.
abstract final class LessonCatalog {
  static const all = <Lesson>[
    // ── Grammar ────────────────────────────────────────────────────────
    Lesson(
      id: 'g_present_simple',
      title: 'Present Simple Basics',
      subtitle: 'He goes, she does, it works',
      category: LessonCategory.grammar,
      difficulty: LessonDifficulty.easy,
      emoji: '📐',
      xpReward: 50,
      estimatedMinutes: 5,
      exercises: [
        ChoiceExercise(
          id: 'g1a',
          question: 'Choose the correct sentence',
          prompt: 'Which one is right?',
          options: [
            'He go to school every day.',
            'He goes to school every day.',
            'He going to school every day.',
          ],
          correctIndex: 1,
          explanation:
              'With he / she / it in the simple present, add -s to the verb: '
              'he goes, she works, it rains.',
        ),
        FillBlankExercise(
          id: 'g1b',
          sentence: 'She ___ coffee every morning.',
          options: ['drink', 'drinks', 'drinking'],
          correctIndex: 1,
          explanation: '"She" takes the -s form: she drinks.',
        ),
        FillBlankExercise(
          id: 'g1c',
          sentence: 'They ___ football on Sundays.',
          options: ['plays', 'play', 'playing'],
          correctIndex: 1,
          explanation:
              'Plural subjects (they, we, you) use the base verb: they play.',
        ),
        ArrangeExercise(
          id: 'g1d',
          words: ['every', 'day', 'my', 'brother', 'studies'],
          correctOrder: ['my', 'brother', 'studies', 'every', 'day'],
          hint: 'Start with the person.',
          explanation:
              'English word order is subject → verb → time: '
              'My brother studies every day.',
        ),
        SpeakExercise(
          id: 'g1e',
          phrase: 'He goes to school every day.',
          tip: 'Say the -s clearly at the end of "goes".',
        ),
      ],
    ),

    Lesson(
      id: 'g_past_tense',
      title: 'Talking About Yesterday',
      subtitle: 'Regular and irregular past verbs',
      category: LessonCategory.grammar,
      difficulty: LessonDifficulty.medium,
      emoji: '⏪',
      xpReward: 60,
      estimatedMinutes: 6,
      exercises: [
        ChoiceExercise(
          id: 'g2a',
          prompt: 'I ___ to the market yesterday.',
          options: ['go', 'went', 'gone'],
          correctIndex: 1,
          explanation:
              '"Go" is irregular — its simple past is "went", not "goed". '
              '"Gone" needs a helper verb: I have gone.',
        ),
        FillBlankExercise(
          id: 'g2b',
          sentence: 'We ___ a great film last night.',
          options: ['watch', 'watched', 'watching'],
          correctIndex: 1,
          explanation: 'Regular verbs add -ed for the past: watch → watched.',
        ),
        ChoiceExercise(
          id: 'g2c',
          prompt: 'Which sentence is correct?',
          options: [
            'Did you went there?',
            'Did you go there?',
            'Did you gone there?',
          ],
          correctIndex: 1,
          explanation:
              'After "did", always use the base verb — "did" already carries '
              'the past tense.',
        ),
        ArrangeExercise(
          id: 'g2d',
          words: ['I', 'last', 'week', 'met', 'her'],
          correctOrder: ['I', 'met', 'her', 'last', 'week'],
          explanation: 'Subject → verb → object → time.',
        ),
      ],
    ),

    Lesson(
      id: 'g_articles',
      title: 'A, An & The',
      subtitle: 'The small words that trip everyone up',
      category: LessonCategory.grammar,
      difficulty: LessonDifficulty.medium,
      emoji: '🔤',
      xpReward: 55,
      estimatedMinutes: 5,
      exercises: [
        FillBlankExercise(
          id: 'g3a',
          sentence: 'I saw ___ elephant at the zoo.',
          options: ['a', 'an', 'the'],
          correctIndex: 1,
          explanation:
              'Use "an" before a vowel *sound*: an elephant, an hour, '
              'but a university (it sounds like "yoo").',
        ),
        FillBlankExercise(
          id: 'g3b',
          sentence: 'She is ___ best player in our team.',
          options: ['a', 'an', 'the'],
          correctIndex: 2,
          explanation:
              'Superlatives (best, tallest, first) always take "the".',
        ),
        ChoiceExercise(
          id: 'g3c',
          prompt: 'Which sentence is correct?',
          options: [
            'I am going to the home.',
            'I am going to home.',
            'I am going home.',
          ],
          correctIndex: 2,
          explanation: '"Home" takes no article after a verb of motion.',
        ),
      ],
    ),

    // ── Vocabulary ─────────────────────────────────────────────────────
    Lesson(
      id: 'v_stronger_words',
      title: 'Say It Stronger',
      subtitle: 'Upgrade good, big and happy',
      category: LessonCategory.vocabulary,
      difficulty: LessonDifficulty.easy,
      emoji: '💎',
      xpReward: 50,
      estimatedMinutes: 4,
      exercises: [
        FlashcardExercise(
          id: 'v1a',
          front: 'Excellent',
          back: 'Much better than "good"',
          example: 'Your pronunciation was excellent today.',
        ),
        FlashcardExercise(
          id: 'v1b',
          front: 'Huge',
          back: 'Much bigger than "big"',
          example: 'That was a huge improvement.',
        ),
        FlashcardExercise(
          id: 'v1c',
          front: 'Delighted',
          back: 'Much happier than "happy"',
          example: 'I was delighted to hear your news.',
        ),
        FlashcardExercise(
          id: 'v1d',
          front: 'Crucial',
          back: 'More important than "important"',
          example: 'Practising daily is crucial.',
        ),
        ChoiceExercise(
          id: 'v1e',
          prompt: 'The food was really ___ — I want to come back!',
          options: ['good', 'excellent', 'okay'],
          correctIndex: 1,
          explanation:
              '"Excellent" carries the enthusiasm the second half of the '
              'sentence promises.',
        ),
      ],
    ),

    Lesson(
      id: 'v_daily_objects',
      title: 'Around the House',
      subtitle: 'Everyday objects you will actually use',
      category: LessonCategory.vocabulary,
      difficulty: LessonDifficulty.easy,
      emoji: '🏠',
      xpReward: 45,
      estimatedMinutes: 4,
      exercises: [
        FlashcardExercise(
          id: 'v2a',
          front: 'Cupboard',
          back: 'A cabinet with shelves for storing things',
          example: 'The plates are in the cupboard.',
        ),
        FlashcardExercise(
          id: 'v2b',
          front: 'Tap',
          back: 'The thing water comes out of (US: faucet)',
          example: 'Please turn off the tap.',
        ),
        FlashcardExercise(
          id: 'v2c',
          front: 'Balcony',
          back: 'A small outdoor platform off a room',
          example: 'We had tea on the balcony.',
        ),
        ChoiceExercise(
          id: 'v2d',
          prompt: 'Where do you keep your clothes?',
          options: ['In the wardrobe', 'In the tap', 'In the balcony'],
          correctIndex: 0,
          explanation: 'A wardrobe is the cupboard made for clothes.',
        ),
      ],
    ),

    // ── Phrases ────────────────────────────────────────────────────────
    Lesson(
      id: 'p_conversation_repair',
      title: 'When You Do Not Understand',
      subtitle: 'Phrases that keep a conversation alive',
      category: LessonCategory.phrases,
      difficulty: LessonDifficulty.easy,
      emoji: '💬',
      xpReward: 55,
      estimatedMinutes: 5,
      exercises: [
        FlashcardExercise(
          id: 'p1a',
          front: 'Could you repeat that, please?',
          back: 'Ask politely for something to be said again',
          example: 'Sorry, could you repeat that, please?',
        ),
        FlashcardExercise(
          id: 'p1b',
          front: 'What do you mean?',
          back: 'Ask for clarification',
          example: 'What do you mean by "later"?',
        ),
        FlashcardExercise(
          id: 'p1c',
          front: 'That makes sense!',
          back: 'Show you understood',
          example: 'Ah, that makes sense now. Thank you!',
        ),
        SpeakExercise(
          id: 'p1d',
          phrase: 'Could you repeat that, please?',
          tip: 'Let your voice rise at the end — it makes it sound polite.',
        ),
        SpeakExercise(
          id: 'p1e',
          phrase: "I'm not sure about that.",
          tip: 'Link "not" and "sure" smoothly: "I\'m not-sure".',
        ),
      ],
    ),

    Lesson(
      id: 'p_small_talk',
      title: 'Small Talk Starters',
      subtitle: 'Break the ice with anyone',
      category: LessonCategory.phrases,
      difficulty: LessonDifficulty.medium,
      emoji: '☕',
      xpReward: 60,
      estimatedMinutes: 5,
      exercises: [
        FlashcardExercise(
          id: 'p2a',
          front: 'How has your week been?',
          back: 'A warmer alternative to "how are you"',
          example: 'Hey! How has your week been?',
        ),
        FlashcardExercise(
          id: 'p2b',
          front: 'What do you do for fun?',
          back: 'Opens up hobbies without sounding like an interview',
          example: 'So what do you do for fun outside work?',
        ),
        ChoiceExercise(
          id: 'p2c',
          prompt: 'Someone says "How are you?" — what is the most natural reply?',
          options: [
            'I am fine. And you?',
            "Good, thanks — how about you?",
            'I am in a good condition.',
          ],
          correctIndex: 1,
          explanation:
              'Native speakers keep it short and bounce the question back. '
              '"I am fine" is correct but sounds a little formal.',
        ),
        SpeakExercise(
          id: 'p2d',
          phrase: 'Good, thanks — how about you?',
          tip: 'Keep it light and quick. Do not over-pronounce "thanks".',
        ),
      ],
    ),

    // ── Listening ──────────────────────────────────────────────────────
    Lesson(
      id: 'l_numbers_times',
      title: 'Catching Numbers & Times',
      subtitle: 'Hear the difference between 15 and 50',
      category: LessonCategory.listening,
      difficulty: LessonDifficulty.medium,
      emoji: '🎧',
      xpReward: 60,
      estimatedMinutes: 5,
      exercises: [
        ListenExercise(
          id: 'l1a',
          phrase: 'The meeting starts at fifteen past three.',
          options: [
            'The meeting starts at fifty past three.',
            'The meeting starts at fifteen past three.',
            'The meeting starts at five past three.',
          ],
          correctIndex: 1,
          explanation:
              'In "fifteen" the stress falls on the *second* syllable; in '
              '"fifty" it falls on the first.',
        ),
        ListenExercise(
          id: 'l1b',
          phrase: 'It costs thirty rupees, not thirteen.',
          options: [
            'It costs thirty rupees, not thirteen.',
            'It costs thirteen rupees, not thirty.',
            'It costs three rupees, not thirteen.',
          ],
          correctIndex: 0,
          explanation: 'Listen for the -teen ending — it is longer and stressed.',
        ),
        ListenExercise(
          id: 'l1c',
          phrase: 'Can we meet at half past seven?',
          options: [
            'Can we meet at half past eleven?',
            'Can we meet at half past seven?',
            'Can we meet at a quarter past seven?',
          ],
          correctIndex: 1,
          explanation: '"Half past seven" means 7:30.',
        ),
      ],
    ),

    // ── Speaking ───────────────────────────────────────────────────────
    Lesson(
      id: 's_th_sounds',
      title: 'Mastering the TH Sound',
      subtitle: 'Think, this, three, that',
      category: LessonCategory.speaking,
      difficulty: LessonDifficulty.medium,
      emoji: '👅',
      xpReward: 65,
      estimatedMinutes: 6,
      exercises: [
        SpeakExercise(
          id: 's1a',
          phrase: 'Think about this thing.',
          phonetic: '/θɪŋk əˈbaʊt ðɪs θɪŋ/',
          tip: 'Put your tongue lightly between your teeth. Not "tink" or "sink".',
        ),
        SpeakExercise(
          id: 's1b',
          phrase: 'Three brothers and their mother.',
          phonetic: '/θriː ˈbrʌðəz ænd ðeə ˈmʌðə/',
          tip: '"Three" is soft (no voice); "their" buzzes (voiced).',
        ),
        SpeakExercise(
          id: 's1c',
          phrase: 'That is the third time.',
          tip: 'Slow down on "third" — it has both the TH and the R.',
        ),
        ChoiceExercise(
          id: 's1d',
          prompt: 'Which word uses the *voiced* TH (the buzzing one)?',
          options: ['Think', 'Thanks', 'This'],
          correctIndex: 2,
          explanation:
              'Put a finger on your throat: "this", "that", "them" vibrate. '
              '"Think" and "thanks" do not.',
        ),
      ],
    ),

    // ── Reading ────────────────────────────────────────────────────────
    Lesson(
      id: 'r_short_message',
      title: 'Reading a Short Message',
      subtitle: 'Understand tone, not just words',
      category: LessonCategory.reading,
      difficulty: LessonDifficulty.easy,
      emoji: '📄',
      xpReward: 50,
      estimatedMinutes: 4,
      exercises: [
        ChoiceExercise(
          id: 'r1a',
          question: 'Read the message',
          prompt:
              '"Hey, no worries at all — take your time. Let me know once '
              'you are free."\n\nHow does the sender feel?',
          options: ['Annoyed', 'Relaxed and patient', 'In a hurry'],
          correctIndex: 1,
          explanation:
              '"No worries at all" and "take your time" both signal patience.',
        ),
        ChoiceExercise(
          id: 'r1b',
          prompt:
              '"Please send it by EOD."\n\nWhat does EOD mean?',
          options: ['End of day', 'Every other day', 'Extra order details'],
          correctIndex: 0,
          explanation:
              'EOD = end of day, common in work emails. Similar: ASAP, FYI, EOW.',
        ),
      ],
    ),

    // ── Writing ────────────────────────────────────────────────────────
    Lesson(
      id: 'w_polite_email',
      title: 'Writing a Polite Request',
      subtitle: 'Get a yes without sounding demanding',
      category: LessonCategory.writing,
      difficulty: LessonDifficulty.medium,
      emoji: '✍️',
      xpReward: 60,
      estimatedMinutes: 5,
      exercises: [
        ChoiceExercise(
          id: 'w1a',
          prompt: 'Which opening is most polite in an email to a manager?',
          options: [
            'I want leave tomorrow.',
            'Would it be possible to take tomorrow off?',
            'Give me leave tomorrow.',
          ],
          correctIndex: 1,
          explanation:
              '"Would it be possible to…" softens a request. Direct commands '
              'sound rude in written English even when you do not mean them to.',
        ),
        ArrangeExercise(
          id: 'w1b',
          words: ['you', 'could', 'help', 'me', 'with', 'this?'],
          correctOrder: ['could', 'you', 'help', 'me', 'with', 'this?'],
          explanation:
              'Questions invert the subject and the modal: Could you…?',
        ),
        ChoiceExercise(
          id: 'w1c',
          prompt: 'How should you close a semi-formal email?',
          options: ['Bye bye', 'Best regards', 'Yours lovingly'],
          correctIndex: 1,
          explanation:
              '"Best regards" or "Kind regards" work for almost any '
              'professional email.',
        ),
      ],
    ),

    // ── Gen-Z slang ────────────────────────────────────────────────────
    Lesson(
      id: 'z_core_slang',
      title: 'Gen-Z Starter Pack',
      subtitle: 'No cap, this one slaps',
      category: LessonCategory.slang,
      difficulty: LessonDifficulty.easy,
      emoji: '😎',
      xpReward: 55,
      estimatedMinutes: 4,
      exercises: [
        FlashcardExercise(
          id: 'z1a',
          front: 'No cap',
          back: "I'm being serious / no lie",
          example: 'That movie was no cap amazing!',
        ),
        FlashcardExercise(
          id: 'z1b',
          front: 'GOAT',
          back: 'Greatest Of All Time',
          example: "He's the GOAT of cricket!",
        ),
        FlashcardExercise(
          id: 'z1c',
          front: 'It slaps',
          back: 'It is really good (usually music or food)',
          example: 'This song absolutely slaps.',
        ),
        FlashcardExercise(
          id: 'z1d',
          front: 'Lowkey',
          back: 'Slightly / secretly',
          example: "I'm lowkey nervous about the exam.",
        ),
        ChoiceExercise(
          id: 'z1e',
          prompt: 'Your friend says "that fit is fire". What do they mean?',
          options: [
            'Your clothes look great',
            'Your clothes are burning',
            'You should leave',
          ],
          correctIndex: 0,
          explanation: '"Fit" = outfit, "fire" = excellent.',
        ),
      ],
    ),

    Lesson(
      id: 'z_texting',
      title: 'Texting & Shortforms',
      subtitle: 'IYKYK, TBH, NGL',
      category: LessonCategory.slang,
      difficulty: LessonDifficulty.easy,
      emoji: '📱',
      xpReward: 50,
      estimatedMinutes: 4,
      exercises: [
        FlashcardExercise(
          id: 'z2a',
          front: 'TBH',
          back: 'To be honest',
          example: 'TBH I liked the first one better.',
        ),
        FlashcardExercise(
          id: 'z2b',
          front: 'NGL',
          back: 'Not gonna lie',
          example: 'NGL that was harder than I expected.',
        ),
        FlashcardExercise(
          id: 'z2c',
          front: 'IYKYK',
          back: 'If you know, you know',
          example: 'The 3am study sessions… iykyk.',
        ),
        ChoiceExercise(
          id: 'z2d',
          prompt: 'Which of these is fine to use in a job email?',
          options: ['NGL', 'FYI', 'IYKYK'],
          correctIndex: 1,
          explanation:
              'FYI ("for your information") crossed into professional use '
              'long ago. The others stay in casual chat.',
        ),
      ],
    ),

    // ── Roleplay ───────────────────────────────────────────────────────
    Lesson(
      id: 'rp_interview',
      title: 'Interview Answers That Land',
      subtitle: 'Tell me about yourself',
      category: LessonCategory.roleplay,
      difficulty: LessonDifficulty.hard,
      emoji: '💼',
      xpReward: 80,
      estimatedMinutes: 8,
      proOnly: true,
      exercises: [
        ChoiceExercise(
          id: 'rp1a',
          prompt: '"Tell me about yourself." What should you lead with?',
          options: [
            'Your full family background',
            'A one-line summary of who you are professionally',
            'Your salary expectation',
          ],
          correctIndex: 1,
          explanation:
              'Open with present role → relevant strength → why this job. '
              'Around 60–90 seconds total.',
        ),
        SpeakExercise(
          id: 'rp1b',
          phrase:
              "I'm a final-year student who loves building things that people "
              "actually use.",
          tip: 'Pause slightly after "student" — it makes you sound composed.',
        ),
        ChoiceExercise(
          id: 'rp1c',
          prompt: 'What is your greatest weakness?',
          options: [
            'I am a perfectionist.',
            'I used to struggle with public speaking, so I joined a club and now present weekly.',
            'I have no weaknesses.',
          ],
          correctIndex: 1,
          explanation:
              'Name a real weakness, then show what you did about it. The '
              '"perfectionist" answer is so common it reads as evasive.',
        ),
        SpeakExercise(
          id: 'rp1d',
          phrase: 'Thank you for your time — I really enjoyed our conversation.',
          tip: 'Warm and steady. Do not rush the closing line.',
        ),
      ],
    ),
  ];

  static List<Lesson> byCategory(LessonCategory c) =>
      all.where((l) => l.category == c).toList();

  static Lesson? byId(String id) {
    for (final l in all) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// The lesson surfaced as "today's pick" — rotates daily so the home card
  /// changes without any server involvement.
  static Lesson daily(DateTime now, {Set<String> completed = const {}}) {
    final pool = all.where((l) => !completed.contains(l.id)).toList();
    final source = pool.isEmpty ? all : pool;
    final dayIndex = now.difference(DateTime(2024, 1, 1)).inDays;
    return source[dayIndex.abs() % source.length];
  }
}
