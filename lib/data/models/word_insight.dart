import 'package:flutter/foundation.dart';

/// One meaning of a word — a part of speech plus what it means in that role.
///
/// Kept separate rather than flattened into one definition because the whole
/// point of asking about a word is often that it has two lives: "book" the
/// thing and "book" the act of reserving, "left" the direction and "left" the
/// past of leave. A learner who is only shown the first has been told the
/// wrong thing half the time.
@immutable
class WordSense {
  const WordSense({
    required this.partOfSpeech,
    required this.definition,
    this.examples = const [],
  });

  final String partOfSpeech;
  final String definition;
  final List<String> examples;

  Map<String, dynamic> toJson() => {
        'partOfSpeech': partOfSpeech,
        'definition': definition,
        'examples': examples,
      };

  static WordSense fromJson(Map<String, dynamic> j) => WordSense(
        partOfSpeech: (j['partOfSpeech'] as String? ?? '').trim(),
        definition: (j['definition'] as String? ?? '').trim(),
        examples: (j['examples'] is List ? j['examples'] as List : const [])
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
}

/// Everything the app can tell a learner about one word.
@immutable
class WordInsight {
  const WordInsight({
    required this.word,
    this.senses = const [],
    this.forms = const {},
    this.pronunciation = '',
    this.origin = '',
    this.nativeMeaning = '',
    this.synonyms = const [],
    this.isComplete = false,
  });

  final String word;
  final List<WordSense> senses;

  /// Inflected forms, labelled: past, third person, plural, comparative…
  ///
  /// Available offline, because they follow rules rather than needing to be
  /// looked up. For a learner whose first language does not inflect this way,
  /// seeing go / goes / went / gone laid out is often the entire answer.
  final Map<String, String> forms;

  /// A plain-English respelling, e.g. "KOM-fer-tuh-bul". Not IPA: a learner
  /// who cannot read IPA is helped by neither.
  final String pronunciation;

  /// Where the word came from. The part people find memorable, and the part
  /// that makes an odd spelling finally make sense.
  final String origin;

  /// The meaning in the learner's own language.
  final String nativeMeaning;

  final List<String> synonyms;

  /// Whether this came from the tutor rather than the on-device rules.
  ///
  /// Offline, the app can still give forms and a pronunciation guess, but not
  /// meanings, history or examples. The screen says which it is showing rather
  /// than presenting a thin answer as the whole story.
  final bool isComplete;

  bool get hasSenses => senses.any((s) => s.definition.isNotEmpty);
  bool get hasForms => forms.isNotEmpty;

  WordInsight mergedWith(WordInsight other) => WordInsight(
        word: word,
        senses: other.hasSenses ? other.senses : senses,
        // Locally derived forms are kept unless the tutor supplied its own:
        // rules get "ran" right, and a model can mistype it.
        forms: {...other.forms, ...forms},
        pronunciation:
            other.pronunciation.isNotEmpty ? other.pronunciation : pronunciation,
        origin: other.origin.isNotEmpty ? other.origin : origin,
        nativeMeaning:
            other.nativeMeaning.isNotEmpty ? other.nativeMeaning : nativeMeaning,
        synonyms: other.synonyms.isNotEmpty ? other.synonyms : synonyms,
        isComplete: isComplete || other.isComplete,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'senses': senses.map((s) => s.toJson()).toList(),
        'forms': forms,
        'pronunciation': pronunciation,
        'origin': origin,
        'nativeMeaning': nativeMeaning,
        'synonyms': synonyms,
      };

  static WordInsight fromJson(Map<String, dynamic> j, {bool complete = true}) =>
      WordInsight(
        word: (j['word'] as String? ?? '').trim(),
        senses: (j['senses'] is List ? j['senses'] as List : const [])
            .whereType<Map<String, dynamic>>()
            .map(WordSense.fromJson)
            .where((s) => s.definition.isNotEmpty)
            .toList(),
        forms: {
          for (final e in (j['forms'] is Map ? j['forms'] as Map : const {}).entries)
            if (e.key is String && e.value is String && (e.value as String).isNotEmpty)
              e.key as String: e.value as String,
        },
        pronunciation: (j['pronunciation'] as String? ?? '').trim(),
        origin: (j['origin'] as String? ?? '').trim(),
        nativeMeaning: (j['nativeMeaning'] as String? ?? '').trim(),
        synonyms: (j['synonyms'] is List ? j['synonyms'] as List : const [])
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        isComplete: complete,
      );
}
