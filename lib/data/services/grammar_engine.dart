import '../models/conversation.dart';

/// A single detectable mistake pattern.
class _Rule {
  const _Rule(
    this.pattern,
    this.explanation, {
    required this.replace,
    this.type = CorrectionType.grammar,
  });

  final RegExp pattern;
  final String explanation;

  /// Builds the corrected text from a match.
  final String Function(Match m) replace;
  final CorrectionType type;
}

/// Rule-based detector for the mistakes learners actually make.
///
/// This runs fully on-device, which is what makes real-time correction viable
/// during a live conversation — there is no round trip between the learner
/// finishing a sentence and the fix appearing. When a server-side LLM is
/// configured (see `AiTutorService`), its richer corrections are merged on top
/// of these; the engine remains the offline floor.
///
/// Rules are ordered most-specific first, and each span of text is corrected
/// at most once so overlapping rules cannot produce contradictory advice.
abstract final class GrammarEngine {
  /// Irregular third-person singular forms. Anything not listed falls through
  /// to the regular -s / -es / -ies logic in [_thirdPerson].
  static const _irregularThirdPerson = <String, String>{
    'go': 'goes',
    'do': 'does',
    'have': 'has',
    'be': 'is',
    'say': 'says',
  };

  static String _thirdPerson(String verb) {
    final v = verb.toLowerCase();
    if (_irregularThirdPerson.containsKey(v)) return _irregularThirdPerson[v]!;
    if (v.endsWith('y') &&
        v.length > 1 &&
        !'aeiou'.contains(v[v.length - 2])) {
      return '${v.substring(0, v.length - 1)}ies';
    }
    if (v.endsWith('s') ||
        v.endsWith('x') ||
        v.endsWith('z') ||
        v.endsWith('ch') ||
        v.endsWith('sh') ||
        v.endsWith('o')) {
      return '${v}es';
    }
    return '${v}s';
  }

  static final List<_Rule> _rules = [
    // ── Subject–verb agreement ───────────────────────────────────────────
    _Rule(
      RegExp(
        r'\b(he|she|it)\s+(go|do|have|make|take|say|come|get|know|want|'
        r'like|need|work|play|study|watch|live|speak|eat|read|write|run|'
        r'talk|walk|help|look|feel|think)\b',
        caseSensitive: false,
      ),
      'With he / she / it in the simple present, the verb takes -s.',
      replace: (m) => '${m[1]} ${_thirdPerson(m[2]!)}',
    ),
    _Rule(
      RegExp(r'\b(he|she|it)\s+(are|were)\b', caseSensitive: false),
      'Use "is" (or "was") with he, she and it.',
      replace: (m) =>
          '${m[1]} ${m[2]!.toLowerCase() == 'are' ? 'is' : 'was'}',
    ),
    _Rule(
      RegExp(r'\b(they|we|you)\s+(is|was)\b', caseSensitive: false),
      'Plural subjects take "are" (or "were").',
      replace: (m) =>
          '${m[1]} ${m[2]!.toLowerCase() == 'is' ? 'are' : 'were'}',
    ),
    _Rule(
      RegExp(r'\bI\s+(is|are|am\s+be)\b'),
      'The correct form is "I am".',
      replace: (m) => 'I am',
    ),

    // ── Tense ────────────────────────────────────────────────────────────
    // The subject is optional because both "didn't went" and the far more
    // common question form "did you went" have to be caught.
    _Rule(
      RegExp(
        r"\b(did|didn't|did\s+not)\s+(?:(i|you|he|she|it|we|they)\s+)?"
        r'(\w+ed|went|came|saw|ate|took|got|made|'
        r'gave|knew|thought|told|felt|found)\b',
        caseSensitive: false,
      ),
      '"Did" already marks the past, so the next verb stays in its base form.',
      replace: (m) {
        final subject = m[2] == null ? '' : '${m[2]} ';
        return '${m[1]} $subject${_baseForm(m[3]!)}';
      },
    ),
    _Rule(
      RegExp(r'\b(have|has)\s+went\b', caseSensitive: false),
      'The past participle of "go" is "gone": I have gone.',
      replace: (m) => '${m[1]} gone',
    ),
    _Rule(
      RegExp(r'\bsince\s+(\d+|a few|many|some)\s+(year|month|week|day|hour)s?\b',
          caseSensitive: false),
      'Use "for" with a length of time and "since" with a starting point: '
      'for two years, since 2022.',
      replace: (m) => 'for ${m[1]} ${m[2]}s',
    ),

    // ── Articles ─────────────────────────────────────────────────────────
    _Rule(
      RegExp(
        r'\ba\s+(apple|hour|elephant|umbrella|orange|egg|idea|honest|answer|'
        r'engineer|exam|email|interview|opportunity)\b',
        caseSensitive: false,
      ),
      'Use "an" before a vowel sound.',
      replace: (m) => 'an ${m[1]}',
      type: CorrectionType.grammar,
    ),
    _Rule(
      RegExp(r'\ban\s+(university|user|European|one|uniform)\b',
          caseSensitive: false),
      'Use "a" when the next word starts with a consonant *sound* — '
      '"university" begins with a "yoo" sound.',
      replace: (m) => 'a ${m[1]}',
    ),

    // ── Countability ─────────────────────────────────────────────────────
    _Rule(
      RegExp(r'\b(informations|advices|equipments|furnitures|luggages|'
          r'homeworks|softwares|feedbacks)\b', caseSensitive: false),
      'This is an uncountable noun in English — it has no plural form.',
      replace: (m) => m[1]!.substring(0, m[1]!.length - 1),
    ),
    _Rule(
      RegExp(r'\bpeoples\b', caseSensitive: false),
      '"People" is already plural.',
      replace: (m) => 'people',
    ),

    // ── Comparatives ─────────────────────────────────────────────────────
    _Rule(
      RegExp(r'\bmore\s+(better|easier|faster|bigger|higher|worse|nicer)\b',
          caseSensitive: false),
      'Do not use "more" with a word that is already comparative.',
      replace: (m) => m[1]!,
    ),
    _Rule(
      RegExp(r'\bmost\s+(easiest|best|fastest|biggest|worst)\b',
          caseSensitive: false),
      'Do not use "most" with a word that is already superlative.',
      replace: (m) => m[1]!,
    ),

    // ── Prepositions & fixed expressions ─────────────────────────────────
    _Rule(
      RegExp(r'\bdiscuss\s+about\b', caseSensitive: false),
      '"Discuss" already means "talk about" — drop the "about".',
      replace: (m) => 'discuss',
      type: CorrectionType.phrasing,
    ),
    _Rule(
      RegExp(r'\bI\s+am\s+agree\b', caseSensitive: false),
      '"Agree" is a verb on its own: I agree.',
      replace: (m) => 'I agree',
    ),
    _Rule(
      RegExp(r'\breturn\s+back\b|\brevert\s+back\b|\brepeat\s+again\b',
          caseSensitive: false),
      'The "back" / "again" is already contained in the verb.',
      replace: (m) => m[0]!.split(RegExp(r'\s+')).first,
      type: CorrectionType.phrasing,
    ),
    _Rule(
      RegExp(r'\bcousin\s+(brother|sister)\b', caseSensitive: false),
      'In English, "cousin" works for any gender on its own.',
      replace: (m) => 'cousin',
      type: CorrectionType.vocabulary,
    ),
    _Rule(
      RegExp(r'\bout\s+of\s+station\b', caseSensitive: false),
      'Native speakers say "out of town".',
      replace: (m) => 'out of town',
      type: CorrectionType.vocabulary,
    ),
    _Rule(
      RegExp(r'\bdo\s+the\s+needful\b', caseSensitive: false),
      'Say specifically what you need — e.g. "please take a look".',
      replace: (m) => 'take care of it',
      type: CorrectionType.phrasing,
    ),
    _Rule(
      RegExp(r'\bwhat\s+is\s+your\s+good\s+name\b', caseSensitive: false),
      'Just "What\'s your name?" — adding "good" sounds unusual in English.',
      replace: (m) => "what's your name",
      type: CorrectionType.phrasing,
    ),
    _Rule(
      RegExp(r'\bI\s+am\s+having\s+(a|an|two|three|some)?\s*'
          r'(brothers?|sisters?|cars?|house|phone|questions?|idea)\b',
          caseSensitive: false),
      'For things you own or relationships, use "I have" — not "I am having". '
      '"Having" is for actions, like having lunch.',
      replace: (m) => 'I have ${m[1] ?? 'a'} ${m[2]}',
    ),
    // Scoped tightly: "I have a doubt" is the pattern to fix, while
    // "I doubt it" is perfectly correct English and must not be flagged.
    _Rule(
      RegExp(r'\b(a|any|one|my|some)\s+doubts?\b', caseSensitive: false),
      'For a question in class or a meeting, English uses "question". '
      '"Doubt" means you do not believe something.',
      replace: (m) => '${m[1]} question',
      type: CorrectionType.vocabulary,
    ),

    // ── Adverb form ──────────────────────────────────────────────────────
    _Rule(
      RegExp(r'\b(go|goes|went|come|comes|study|studies|work|works|'
          r'practise|practice)\s+everyday\b', caseSensitive: false),
      '"Everyday" (one word) is an adjective. For "each day", use two words: '
      'every day.',
      replace: (m) => '${m[1]} every day',
    ),

    // ── Double negative ──────────────────────────────────────────────────
    _Rule(
      RegExp(r"\b(don't|doesn't|didn't|can't|won't)\s+(\w+\s+)?"
          r'(nothing|nobody|nowhere|no one)\b', caseSensitive: false),
      'English uses one negative per clause — "anything" instead of "nothing" '
      'after a negative verb.',
      replace: (m) {
        const swap = {
          'nothing': 'anything',
          'nobody': 'anybody',
          'nowhere': 'anywhere',
          'no one': 'anyone',
        };
        return '${m[1]} ${m[2] ?? ''}${swap[m[3]!.toLowerCase()]}';
      },
    ),
  ];

  static String _baseForm(String verb) {
    const irregular = {
      'went': 'go',
      'came': 'come',
      'saw': 'see',
      'ate': 'eat',
      'took': 'take',
      'got': 'get',
      'made': 'make',
      'gave': 'give',
      'knew': 'know',
      'thought': 'think',
      'told': 'tell',
      'felt': 'feel',
      'found': 'find',
    };
    final v = verb.toLowerCase();
    if (irregular.containsKey(v)) return irregular[v]!;
    if (v.endsWith('ied')) return '${v.substring(0, v.length - 3)}y';
    if (v.endsWith('ed')) {
      final stem = v.substring(0, v.length - 2);
      // "stopped" → "stop": undo the doubled final consonant.
      if (stem.length > 2 &&
          stem[stem.length - 1] == stem[stem.length - 2] &&
          !'aeiou'.contains(stem[stem.length - 1])) {
        return stem.substring(0, stem.length - 1);
      }
      return stem;
    }
    return v;
  }

  /// Returns every correction found in [text], with the corrected sentence
  /// built cumulatively so multiple fixes compose into one clean rewrite.
  static List<Correction> analyse(String text) {
    if (text.trim().isEmpty) return const [];

    // Each hit contributes its own explanation, but they all share the single
    // fully-corrected sentence assembled once every rule has run.
    final hits = <({String explanation, CorrectionType type})>[];
    final claimed = <_Span>[];
    var corrected = text;

    for (final rule in _rules) {
      // Match against the *original* text so rule offsets stay meaningful,
      // then apply the change to the running corrected string.
      for (final m in rule.pattern.allMatches(text)) {
        final span = _Span(m.start, m.end);
        if (claimed.any((c) => c.overlaps(span))) continue;

        final original = m[0]!;
        final fixed = _matchCase(original, rule.replace(m));
        if (fixed.toLowerCase() == original.toLowerCase()) continue;

        claimed.add(span);
        corrected = corrected.replaceFirst(original, fixed);
        hits.add((explanation: rule.explanation, type: rule.type));
      }
    }

    if (hits.isEmpty) return const [];

    final before = _capitalise(text.trim());
    final after = _capitalise(corrected.trim());
    return [
      for (final h in hits)
        Correction(
          original: before,
          corrected: after,
          explanation: h.explanation,
          type: h.type,
        ),
    ];
  }

  /// True when [text] contains no detectable mistakes.
  static bool isClean(String text) => analyse(text).isEmpty;

  /// Preserves the original capitalisation pattern of the first character.
  static String _matchCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    final firstIsUpper = original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase();
    if (!firstIsUpper) return replacement;
    return replacement[0].toUpperCase() + replacement.substring(1);
  }

  static String _capitalise(String s) {
    if (s.isEmpty) return s;
    var out = s[0].toUpperCase() + s.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(out)) out = '$out.';
    return out;
  }
}

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;
  bool overlaps(_Span o) => start < o.end && o.start < end;
}
