import '../models/conversation.dart';

/// Gen-Z reference content: slang, emoji meanings, and register guidance.
///
/// Also used as the source pool when the tutor introduces new terms during a
/// Gen-Z mode conversation.
abstract final class SlangCatalog {
  static const terms = <SlangTerm>[
    SlangTerm(
      term: 'No cap',
      meaning: "I'm being serious / no lie",
      example: 'That movie was no cap amazing!',
      emoji: '🧢',
    ),
    SlangTerm(
      term: 'GOAT',
      meaning: 'Greatest Of All Time',
      example: "He's the GOAT of cricket!",
      emoji: '🐐',
    ),
    SlangTerm(
      term: 'It slaps',
      meaning: 'It is genuinely great (music, food)',
      example: 'This playlist slaps.',
      emoji: '🔥',
    ),
    SlangTerm(
      term: 'Lowkey',
      meaning: 'Slightly, secretly, a little bit',
      example: "I'm lowkey tired today.",
      emoji: '🤫',
    ),
    SlangTerm(
      term: 'Highkey',
      meaning: 'Openly, very much so',
      example: 'I highkey need a break.',
      emoji: '📣',
    ),
    SlangTerm(
      term: 'Mid',
      meaning: 'Mediocre, overrated',
      example: 'The sequel was kinda mid.',
      emoji: '😐',
    ),
    SlangTerm(
      term: 'Ate',
      meaning: 'Performed excellently',
      example: 'She ate that presentation.',
      emoji: '💅',
    ),
    SlangTerm(
      term: 'Rizz',
      meaning: 'Charm, the ability to talk to people',
      example: 'He has unmatched rizz.',
      emoji: '😏',
    ),
    SlangTerm(
      term: 'Bet',
      meaning: 'Okay / agreed / sure',
      example: '"Meet at 6?" "Bet."',
      emoji: '🤝',
    ),
    SlangTerm(
      term: 'Fit',
      meaning: 'Outfit',
      example: 'That fit is clean.',
      emoji: '👕',
    ),
    SlangTerm(
      term: 'Sus',
      meaning: 'Suspicious, questionable',
      example: 'That excuse sounds sus.',
      emoji: '🤨',
    ),
    SlangTerm(
      term: 'Vibe check',
      meaning: 'Assessing the mood of a person or place',
      example: 'Quick vibe check — is everyone okay?',
      emoji: '✨',
    ),
    SlangTerm(
      term: 'Salty',
      meaning: 'Bitter or upset about something',
      example: "He's still salty about losing.",
      emoji: '🧂',
    ),
    SlangTerm(
      term: 'Ghosting',
      meaning: 'Disappearing from a conversation with no explanation',
      example: 'She ghosted the group chat.',
      emoji: '👻',
    ),
    SlangTerm(
      term: 'Flex',
      meaning: 'To show off',
      example: 'Not to flex, but I finished early.',
      emoji: '💪',
    ),
  ];

  /// Chat and social shortforms, with a note on where each is acceptable.
  static const shortforms = <String, String>{
    'TBH': 'To be honest — casual only',
    'NGL': 'Not gonna lie — casual only',
    'IYKYK': 'If you know, you know — casual only',
    'FYI': 'For your information — fine at work',
    'ASAP': 'As soon as possible — fine at work',
    'EOD': 'End of day — common in work email',
    'IMO': 'In my opinion — mostly casual',
    'BRB': 'Be right back — casual only',
    'IRL': 'In real life — casual',
    'DM': 'Direct message — universal',
    'W': 'A win / something good',
    'L': 'A loss / something bad',
  };

  /// What emoji actually signal in Gen-Z usage, which is often not their
  /// literal meaning.
  static const emojiMeanings = <String, String>{
    '💀': 'Dying of laughter — not death',
    '😭': 'Overwhelmed, usually laughing',
    '🔥': 'Excellent, impressive',
    '👀': 'Interesting… / I noticed that',
    '🫠': 'Melting from stress or embarrassment',
    '✨': 'Adds emphasis or sarcasm around a phrase',
    '🧢': 'Calling out a lie ("cap")',
    '🙏': 'Please / thank you',
    '😩': 'Frustrated or dramatic',
    '💅': 'Unbothered confidence',
  };

  static List<SlangTerm> random(int count, {int seed = 0}) {
    final list = [...terms];
    // Deterministic rotation keeps the picks stable within a session while
    // still varying between conversations.
    final start = seed.abs() % list.length;
    return List.generate(
      count.clamp(0, list.length),
      (i) => list[(start + i) % list.length],
    );
  }
}
