import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/services/word_forms.dart';

/// These forms are shown to someone learning the language, so a wrong one
/// teaches a mistake. They are also the part of "explain this word" that works
/// with no backend, no key and no network — which for most of this app's users
/// is most of the time.
void main() {
  group('third person', () {
    test('adds -s, -es and -ies by the sound of the ending', () {
      expect(WordForms.thirdPerson('walk'), 'walks');
      expect(WordForms.thirdPerson('watch'), 'watches');
      expect(WordForms.thirdPerson('miss'), 'misses');
      expect(WordForms.thirdPerson('fix'), 'fixes');
      expect(WordForms.thirdPerson('study'), 'studies');
    });

    test('keeps -s after a vowel + y', () {
      // "plaies" is the mistake the -ies rule makes without this check.
      expect(WordForms.thirdPerson('play'), 'plays');
      expect(WordForms.thirdPerson('buy'), 'buys');
    });

    test('knows the four that are simply irregular', () {
      expect(WordForms.thirdPerson('be'), 'is');
      expect(WordForms.thirdPerson('have'), 'has');
      expect(WordForms.thirdPerson('do'), 'does');
      expect(WordForms.thirdPerson('go'), 'goes');
    });
  });

  group('past', () {
    test('handles regular endings', () {
      expect(WordForms.past('walk'), 'walked');
      expect(WordForms.past('like'), 'liked');
      expect(WordForms.past('study'), 'studied');
      expect(WordForms.past('play'), 'played');
    });

    test('doubles a final consonant after a single vowel', () {
      expect(WordForms.past('stop'), 'stopped');
      expect(WordForms.past('plan'), 'planned');
    });

    test('does not double after two vowels or before -y/-w', () {
      expect(WordForms.past('rain'), 'rained');
      expect(WordForms.past('show'), 'showed');
    });

    test('uses the irregular form where there is one', () {
      expect(WordForms.past('go'), 'went');
      expect(WordForms.past('buy'), 'bought');
      expect(WordForms.past('put'), 'put');
      expect(WordForms.past('run'), 'ran');
    });
  });

  group('-ing', () {
    test('drops a silent e but keeps a double one', () {
      expect(WordForms.ing('make'), 'making');
      expect(WordForms.ing('see'), 'seeing');
      expect(WordForms.ing('agree'), 'agreeing');
    });

    test('turns -ie into -ying', () {
      expect(WordForms.ing('lie'), 'lying');
      expect(WordForms.ing('die'), 'dying');
    });

    test('doubles where the past does', () {
      expect(WordForms.ing('sit'), 'sitting');
      expect(WordForms.ing('run'), 'running');
    });
  });

  group('plural', () {
    test('adds -s, -es and -ies', () {
      expect(WordForms.plural('book'), 'books');
      expect(WordForms.plural('box'), 'boxes');
      expect(WordForms.plural('city'), 'cities');
      expect(WordForms.plural('knife'), 'knives');
    });

    test('knows the irregulars', () {
      expect(WordForms.plural('child'), 'children');
      expect(WordForms.plural('person'), 'people');
      expect(WordForms.plural('foot'), 'feet');
    });

    test('leaves uncountable nouns alone', () {
      // "informations" and "advices" are among the most common mistakes this
      // app's users make. It must never print them.
      for (final w in ['information', 'advice', 'luggage', 'furniture', 'news']) {
        expect(WordForms.plural(w), w, reason: w);
      }
    });
  });

  group('comparison', () {
    test('inflects short words', () {
      expect(WordForms.comparative('big'), 'bigger');
      expect(WordForms.superlative('big'), 'biggest');
      expect(WordForms.comparative('happy'), 'happier');
      expect(WordForms.comparative('nice'), 'nicer');
    });

    test('refuses long ones', () {
      // "beautifuller" is what a rule without a length check produces.
      expect(WordForms.comparative('beautiful'), isNull);
      expect(WordForms.superlative('interesting'), isNull);
    });
  });

  _closedClass();

  group('of', () {
    test('lays out an irregular verb in full', () {
      final forms = WordForms.of('go');
      expect(forms['He / she'], 'goes');
      expect(forms['Past'], 'went');
      expect(forms['Have / has'], 'gone');
      expect(forms['-ing'], 'going');
    });

    test('offers both readings when a word could be either', () {
      // "walk" is a verb and a noun, and the app cannot tell which was meant.
      final forms = WordForms.of('walk');
      expect(forms['Past'], 'walked');
      expect(forms['More than one'], 'walks');
    });

    test('does not offer verb forms for an obvious noun ending', () {
      expect(WordForms.of('happiness').containsKey('Past'), isFalse);
      expect(WordForms.of('information')['More than one'], 'information');
    });

    test('returns nothing for a phrase or empty input', () {
      expect(WordForms.of(''), isEmpty);
      expect(WordForms.of('give up'), isEmpty);
    });

    test('is case-insensitive', () {
      expect(WordForms.of('GO')['Past'], 'went');
    });
  });
}

/// Split out because it is a correctness problem rather than a rule: the
/// suffix rules cannot tell a preposition from a short verb, and a learner
/// cannot tell an invented form from a real one.
void _closedClass() {
  group('words that never inflect', () {
    test('articles, prepositions and modals get no forms', () {
      for (final w in ['the', 'a', 'of', 'to', 'and', 'can', 'my', 'this']) {
        expect(WordForms.of(w), isEmpty, reason: w);
      }
    });

    test('the rules would otherwise invent them', () {
      // Documents exactly what the stop-list is preventing.
      expect(WordForms.past('the'), 'thed');
      expect(WordForms.ing('to'), 'toing');
    });
  });
}
