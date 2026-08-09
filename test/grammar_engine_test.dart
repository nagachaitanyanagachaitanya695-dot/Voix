import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/models/conversation.dart';
import 'package:voix/data/services/grammar_engine.dart';

void main() {
  group('GrammarEngine subject-verb agreement', () {
    test('adds -s for third person singular', () {
      final result = GrammarEngine.analyse('He go to school every day');
      expect(result, isNotEmpty);
      expect(result.first.corrected, contains('goes'));
    });

    test('handles irregular third person forms', () {
      expect(
        GrammarEngine.analyse('She have a car').first.corrected,
        contains('has'),
      );
      expect(
        GrammarEngine.analyse('It do work').first.corrected,
        contains('does'),
      );
    });

    test('applies -ies to consonant + y verbs', () {
      expect(
        GrammarEngine.analyse('He study every night').first.corrected,
        contains('studies'),
      );
    });

    test('applies -es to sibilant endings', () {
      expect(
        GrammarEngine.analyse('She watch television').first.corrected,
        contains('watches'),
      );
    });

    test('fixes plural subjects taking is', () {
      expect(
        GrammarEngine.analyse('They is coming').first.corrected,
        contains('are'),
      );
    });

    test('leaves correct sentences alone', () {
      expect(GrammarEngine.analyse('He goes to school every day.'), isEmpty);
      expect(GrammarEngine.analyse('They are coming tomorrow.'), isEmpty);
      expect(GrammarEngine.isClean('I have two brothers.'), isTrue);
    });
  });

  group('GrammarEngine tense', () {
    test('reverts past verb after did', () {
      final result = GrammarEngine.analyse('Did you went there?');
      expect(result.first.corrected, contains('go'));
      expect(result.first.corrected, isNot(contains('went')));
    });

    test('undoes doubled consonant when reverting -ed', () {
      final result = GrammarEngine.analyse('I didn\'t stopped');
      expect(result.first.corrected.toLowerCase(), contains('stop'));
    });

    test('corrects have went to have gone', () {
      expect(
        GrammarEngine.analyse('I have went there').first.corrected,
        contains('gone'),
      );
    });

    test('swaps since for for with a duration', () {
      expect(
        GrammarEngine.analyse('I have lived here since 3 years')
            .first
            .corrected
            .toLowerCase(),
        contains('for 3 years'),
      );
    });
  });

  group('GrammarEngine articles and countability', () {
    test('a before a vowel sound becomes an', () {
      expect(
        GrammarEngine.analyse('I saw a elephant').first.corrected,
        contains('an elephant'),
      );
    });

    test('an before a consonant sound becomes a', () {
      expect(
        GrammarEngine.analyse('She joined an university').first.corrected,
        contains('a university'),
      );
    });

    test('depluralises uncountable nouns', () {
      expect(
        GrammarEngine.analyse('I need more informations').first.corrected,
        contains('information'),
      );
      expect(
        GrammarEngine.analyse('Many peoples came').first.corrected,
        contains('people'),
      );
    });
  });

  group('GrammarEngine phrasing', () {
    test('removes redundant about after discuss', () {
      final result = GrammarEngine.analyse('Let us discuss about the plan');
      expect(result.first.corrected, isNot(contains('discuss about')));
      expect(result.first.type, CorrectionType.phrasing);
    });

    test('fixes I am agree', () {
      expect(
        GrammarEngine.analyse('I am agree with you').first.corrected,
        contains('I agree'),
      );
    });

    test('resolves double negatives', () {
      expect(
        GrammarEngine.analyse("I don't know nothing").first.corrected,
        contains('anything'),
      );
    });

    test('drops more before a comparative', () {
      expect(
        GrammarEngine.analyse('This is more better').first.corrected,
        isNot(contains('more better')),
      );
    });

    test('splits adverbial "everyday" but keeps the adjective', () {
      // The exact sentence from the reference design.
      final result = GrammarEngine.analyse('He go to school everyday.');
      expect(result.first.corrected, 'He goes to school every day.');
      // Adjective use is correct and must survive untouched.
      expect(GrammarEngine.analyse('I want to learn everyday English'), isEmpty);
      expect(GrammarEngine.analyse('This is everyday life.'), isEmpty);
    });

    test('flags "a doubt" but not the verb "doubt"', () {
      expect(
        GrammarEngine.analyse('I have a doubt').first.corrected,
        contains('question'),
      );
      // "I doubt it" is correct English and must not be rewritten.
      expect(GrammarEngine.analyse('I doubt it will rain'), isEmpty);
    });
  });

  group('GrammarEngine output shape', () {
    test('empty input yields no corrections', () {
      expect(GrammarEngine.analyse(''), isEmpty);
      expect(GrammarEngine.analyse('   '), isEmpty);
    });

    test('capitalises and punctuates both sentences', () {
      final result = GrammarEngine.analyse('he go home');
      expect(result.first.original, startsWith('H'));
      expect(result.first.corrected, endsWith('.'));
    });

    test('multiple errors compose into one corrected sentence', () {
      // Two distinct faults: subject-verb agreement, and the article.
      final result = GrammarEngine.analyse('She have a apple');
      expect(result.length, greaterThan(1));
      // Each entry carries its own explanation…
      expect(result.map((c) => c.explanation).toSet().length, greaterThan(1));
      // …but they all share one fully-corrected sentence.
      final sentences = result.map((c) => c.corrected).toSet();
      expect(sentences.length, 1);
      expect(sentences.first, contains('has'));
      expect(sentences.first, contains('an apple'));
    });

    test('preserves leading capitalisation of the matched span', () {
      final result = GrammarEngine.analyse('They is here');
      expect(result.first.corrected, startsWith('They are'));
    });
  });
}
