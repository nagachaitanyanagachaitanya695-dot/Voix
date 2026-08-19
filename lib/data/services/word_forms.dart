/// Derives a word's other forms without asking anyone.
///
/// This is the half of "explain this word" that needs no network, no key and
/// no backend: English inflection is rules plus a list of exceptions, and both
/// fit on the phone. A learner who taps "run" while offline still gets runs /
/// ran / run / running, which is very often the actual question — especially
/// for Telugu, Hindi and Tamil speakers, whose languages mark tense in ways
/// that make English's irregular verbs the hard part.
abstract final class WordForms {
  /// Verbs whose past and participle are not built by adding -ed.
  ///
  /// Ordered base: [past, past participle]. Only the verbs a learner meets
  /// early — a full list belongs in a dictionary, not in the app binary.
  static const _irregularVerbs = <String, List<String>>{
    'be': ['was', 'been'],
    'become': ['became', 'become'],
    'begin': ['began', 'begun'],
    'break': ['broke', 'broken'],
    'bring': ['brought', 'brought'],
    'buy': ['bought', 'bought'],
    'catch': ['caught', 'caught'],
    'choose': ['chose', 'chosen'],
    'come': ['came', 'come'],
    'do': ['did', 'done'],
    'drink': ['drank', 'drunk'],
    'drive': ['drove', 'driven'],
    'eat': ['ate', 'eaten'],
    'fall': ['fell', 'fallen'],
    'feel': ['felt', 'felt'],
    'find': ['found', 'found'],
    'forget': ['forgot', 'forgotten'],
    'get': ['got', 'got'],
    'give': ['gave', 'given'],
    'go': ['went', 'gone'],
    'have': ['had', 'had'],
    'hear': ['heard', 'heard'],
    'keep': ['kept', 'kept'],
    'know': ['knew', 'known'],
    'leave': ['left', 'left'],
    'lose': ['lost', 'lost'],
    'make': ['made', 'made'],
    'meet': ['met', 'met'],
    'pay': ['paid', 'paid'],
    'put': ['put', 'put'],
    'read': ['read', 'read'],
    'run': ['ran', 'run'],
    'say': ['said', 'said'],
    'see': ['saw', 'seen'],
    'sell': ['sold', 'sold'],
    'send': ['sent', 'sent'],
    'sing': ['sang', 'sung'],
    'sit': ['sat', 'sat'],
    'sleep': ['slept', 'slept'],
    'speak': ['spoke', 'spoken'],
    'spend': ['spent', 'spent'],
    'stand': ['stood', 'stood'],
    'take': ['took', 'taken'],
    'teach': ['taught', 'taught'],
    'tell': ['told', 'told'],
    'think': ['thought', 'thought'],
    'understand': ['understood', 'understood'],
    'wear': ['wore', 'worn'],
    'win': ['won', 'won'],
    'write': ['wrote', 'written'],
  };

  static const _irregularPlurals = <String, String>{
    'child': 'children',
    'foot': 'feet',
    'goose': 'geese',
    'man': 'men',
    'mouse': 'mice',
    'person': 'people',
    'tooth': 'teeth',
    'woman': 'women',
  };

  /// Nouns that are the same in the plural. Adding -s to these is one of the
  /// most common mistakes in Indian English, so the app must not make it.
  static const _unchangedPlurals = {
    'advice', 'baggage', 'equipment', 'fish', 'furniture', 'information',
    'luggage', 'money', 'news', 'research', 'sheep', 'software', 'staff',
    'traffic', 'work',
  };

  static const _vowels = {'a', 'e', 'i', 'o', 'u'};

  /// Words that take no endings at all.
  ///
  /// Without this the rules happily produce "the → thed", "of → ofs" and
  /// "to → toing": articles, prepositions, pronouns and modals all look like
  /// short regular verbs to a suffix rule. Printing those in a language app is
  /// worse than printing nothing, because a learner has no way to know they
  /// are not real words.
  static const _neverInflect = {
    'a', 'an', 'the',
    'and', 'or', 'but', 'so', 'because', 'if', 'than', 'though', 'while',
    'of', 'to', 'in', 'on', 'at', 'by', 'for', 'from', 'with', 'about',
    'into', 'onto', 'over', 'under', 'off', 'out', 'up', 'down', 'through',
    'i', 'you', 'he', 'she', 'it', 'we', 'they', 'me', 'him', 'her', 'us',
    'them', 'my', 'your', 'his', 'its', 'our', 'their', 'this', 'that',
    'these', 'those', 'who', 'whom', 'whose', 'which', 'what',
    'can', 'could', 'will', 'would', 'shall', 'should', 'may', 'might',
    'must', 'ought',
    'not', 'no', 'yes', 'very', 'too', 'also', 'just', 'only', 'even',
    'here', 'there', 'when', 'where', 'why', 'how', 'always', 'never',
  };

  /// Every form worth showing for [word], labelled for display.
  ///
  /// Returns an empty map for words with nothing to inflect, so a caller can
  /// simply hide the section rather than showing an empty one.
  static Map<String, String> of(String word) {
    final w = word.trim().toLowerCase();
    if (w.isEmpty || w.contains(' ')) return const {};
    if (_neverInflect.contains(w)) return const {};

    final out = <String, String>{};

    if (_irregularVerbs.containsKey(w)) {
      final forms = _irregularVerbs[w]!;
      out['He / she'] = thirdPerson(w);
      out['Past'] = forms[0];
      out['Have / has'] = forms[1];
      out['-ing'] = ing(w);
      return out;
    }

    // Regular verbs and nouns are not distinguishable without a dictionary, so
    // both readings are offered when both are plausible. Showing a learner
    // "walk → walked" and "walk → walks (more than one)" is honest; guessing
    // one and hiding the other is not.
    if (_looksLikeVerb(w)) {
      out['He / she'] = thirdPerson(w);
      out['Past'] = past(w);
      out['-ing'] = ing(w);
    }
    final p = plural(w);
    if (p != w) out['More than one'] = p;
    if (_unchangedPlurals.contains(w)) out['More than one'] = w;

    final comp = comparative(w);
    if (comp != null) {
      out['-er'] = comp;
      out['-est'] = superlative(w)!;
    }

    return out;
  }

  /// A crude but useful test. Anything ending in a suffix that only nouns and
  /// adjectives take is not offered verb forms; everything else is.
  static bool _looksLikeVerb(String w) {
    const notVerbEndings = ['ness', 'ment', 'tion', 'sion', 'ity', 'ous', 'ful',
      'less', 'able', 'ible', 'ive', 'al', 'ic'];
    return !notVerbEndings.any(w.endsWith);
  }

  static String thirdPerson(String verb) {
    final v = verb.toLowerCase();
    if (v == 'be') return 'is';
    if (v == 'have') return 'has';
    if (v == 'do') return 'does';
    if (v == 'go') return 'goes';
    if (_endsInSibilant(v)) return '${v}es';
    if (_endsConsonantY(v)) return '${v.substring(0, v.length - 1)}ies';
    return '${v}s';
  }

  static String past(String verb) {
    final v = verb.toLowerCase();
    if (_irregularVerbs.containsKey(v)) return _irregularVerbs[v]![0];
    if (v.endsWith('e')) return '${v}d';
    if (_endsConsonantY(v)) return '${v.substring(0, v.length - 1)}ied';
    if (_doublesFinalConsonant(v)) return '$v${v[v.length - 1]}ed';
    return '${v}ed';
  }

  static String ing(String verb) {
    final v = verb.toLowerCase();
    // "make" → "making", but "see" → "seeing" and "agree" → "agreeing".
    if (v.endsWith('ie')) return '${v.substring(0, v.length - 2)}ying';
    if (v.endsWith('e') && !v.endsWith('ee') && v.length > 2) {
      return '${v.substring(0, v.length - 1)}ing';
    }
    if (_doublesFinalConsonant(v)) return '$v${v[v.length - 1]}ing';
    return '${v}ing';
  }

  static String plural(String noun) {
    final n = noun.toLowerCase();
    if (_irregularPlurals.containsKey(n)) return _irregularPlurals[n]!;
    if (_unchangedPlurals.contains(n)) return n;
    if (_endsInSibilant(n)) return '${n}es';
    if (_endsConsonantY(n)) return '${n.substring(0, n.length - 1)}ies';
    // "knife" → "knives", but not "safe" → "saves".
    if (n.endsWith('fe')) return '${n.substring(0, n.length - 2)}ves';
    return '${n}s';
  }

  /// The -er form, or null when the word is too long to take one.
  ///
  /// English only lets short words inflect for comparison; "beautifuller" is
  /// the kind of mistake a rule without this check would teach.
  static String? comparative(String word) {
    final w = word.toLowerCase();
    if (!_isShortEnoughToCompare(w)) return null;
    if (w.endsWith('e')) return '${w}r';
    if (_endsConsonantY(w)) return '${w.substring(0, w.length - 1)}ier';
    if (_doublesFinalConsonant(w)) return '$w${w[w.length - 1]}er';
    return '${w}er';
  }

  static String? superlative(String word) {
    final w = word.toLowerCase();
    if (!_isShortEnoughToCompare(w)) return null;
    if (w.endsWith('e')) return '${w}st';
    if (_endsConsonantY(w)) return '${w.substring(0, w.length - 1)}iest';
    if (_doublesFinalConsonant(w)) return '$w${w[w.length - 1]}est';
    return '${w}est';
  }

  static bool _isShortEnoughToCompare(String w) {
    if (w.length < 3 || w.length > 6) return false;
    // One syllable, roughly: a single run of vowels.
    final groups = RegExp('[aeiou]+').allMatches(w).length;
    return groups <= 2;
  }

  static bool _endsInSibilant(String w) =>
      w.endsWith('s') ||
      w.endsWith('x') ||
      w.endsWith('z') ||
      w.endsWith('ch') ||
      w.endsWith('sh');

  static bool _endsConsonantY(String w) =>
      w.length > 1 && w.endsWith('y') && !_vowels.contains(w[w.length - 2]);

  /// consonant-vowel-consonant, which doubles: stop → stopped, sit → sitting.
  static bool _doublesFinalConsonant(String w) {
    if (w.length < 3) return false;
    final a = w[w.length - 3];
    final b = w[w.length - 2];
    final c = w[w.length - 1];
    if (_vowels.contains(c) || c == 'y' || c == 'w') return false;
    if (!_vowels.contains(b)) return false;
    if (_vowels.contains(a)) return false;
    return true;
  }
}
