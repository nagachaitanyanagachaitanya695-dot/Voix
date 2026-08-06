import 'package:flutter/material.dart';

import '../../core/theme/app_gradients.dart';

/// Top-level grouping used by the Learn tab's filter row.
enum LessonCategory {
  vocabulary('Vocabulary', Icons.menu_book_rounded, VoixGradients.brandSoft),
  grammar('Grammar', Icons.rule_rounded, VoixGradients.violetMagenta),
  speaking('Speaking', Icons.record_voice_over_rounded, VoixGradients.brand),
  listening('Listening', Icons.headphones_rounded, VoixGradients.mint),
  reading('Reading', Icons.article_rounded, VoixGradients.brandSoft),
  writing('Writing', Icons.edit_note_rounded, VoixGradients.violetMagenta),
  phrases('Phrases', Icons.forum_rounded, VoixGradients.brand),
  slang('Gen-Z Slang', Icons.emoji_emotions_rounded, VoixGradients.violetMagenta),
  roleplay('Roleplay', Icons.theater_comedy_rounded, VoixGradients.flame);

  const LessonCategory(this.label, this.icon, this.gradient);
  final String label;
  final IconData icon;
  final Gradient gradient;
}

enum LessonDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Hard');

  const LessonDifficulty(this.label);
  final String label;
}

/// A single interactive step inside a lesson.
sealed class Exercise {
  const Exercise({required this.id, this.explanation});
  final String id;

  /// Shown after the learner answers — the "why", not just the "what".
  final String? explanation;
}

/// Pick one of several options.
class ChoiceExercise extends Exercise {
  const ChoiceExercise({
    required super.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    super.explanation,
    this.question,
  });

  /// The sentence or word under test.
  final String prompt;

  /// Optional instruction line above the prompt.
  final String? question;
  final List<String> options;
  final int correctIndex;
}

/// Complete the sentence by choosing the missing word.
class FillBlankExercise extends Exercise {
  const FillBlankExercise({
    required super.id,
    required this.sentence,
    required this.options,
    required this.correctIndex,
    super.explanation,
  });

  /// Contains `___` where the blank goes.
  final String sentence;
  final List<String> options;
  final int correctIndex;
}

/// Tap words in order to rebuild a scrambled sentence.
class ArrangeExercise extends Exercise {
  const ArrangeExercise({
    required super.id,
    required this.words,
    required this.correctOrder,
    super.explanation,
    this.hint,
  });

  /// Word tiles, presented shuffled.
  final List<String> words;

  /// The target sentence as an ordered word list.
  final List<String> correctOrder;
  final String? hint;
}

/// Say the phrase out loud; scored by the speech recogniser.
class SpeakExercise extends Exercise {
  const SpeakExercise({
    required super.id,
    required this.phrase,
    super.explanation,
    this.phonetic,
    this.tip,
  });

  final String phrase;
  final String? phonetic;
  final String? tip;
}

/// Hear a phrase, then choose what was said.
class ListenExercise extends Exercise {
  const ListenExercise({
    required super.id,
    required this.phrase,
    required this.options,
    required this.correctIndex,
    super.explanation,
  });

  /// Spoken aloud by the TTS engine.
  final String phrase;
  final List<String> options;
  final int correctIndex;
}

/// A flip card — term on the front, meaning and example on the back.
class FlashcardExercise extends Exercise {
  const FlashcardExercise({
    required super.id,
    required this.front,
    required this.back,
    this.example,
    super.explanation,
  });

  final String front;
  final String back;
  final String? example;
}

/// A lesson: a titled set of exercises worth a fixed XP reward.
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.difficulty,
    required this.exercises,
    this.xpReward = 50,
    this.estimatedMinutes = 5,
    this.emoji = '📘',
    this.proOnly = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final LessonCategory category;
  final LessonDifficulty difficulty;
  final List<Exercise> exercises;
  final int xpReward;
  final int estimatedMinutes;
  final String emoji;
  final bool proOnly;

  int get exerciseCount => exercises.length;
}

/// The outcome of a completed lesson run.
@immutable
class LessonResult {
  const LessonResult({
    required this.lessonId,
    required this.correct,
    required this.total,
    required this.xpEarned,
    required this.durationSeconds,
  });

  final String lessonId;
  final int correct;
  final int total;
  final int xpEarned;
  final int durationSeconds;

  double get accuracy => total == 0 ? 0 : correct / total;
  bool get passed => accuracy >= 0.6;
}
