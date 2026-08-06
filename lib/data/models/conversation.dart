import 'package:flutter/foundation.dart';

/// Who produced a turn in the conversation.
enum Speaker { user, tutor }

/// One turn of dialogue.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.speaker,
    required this.text,
    required this.at,
    this.corrections = const [],
    this.isPending = false,
  });

  final String id;
  final Speaker speaker;
  final String text;
  final DateTime at;

  /// Inline fixes attached to a *user* turn, surfaced as a tappable chip
  /// under the bubble.
  final List<Correction> corrections;

  /// True while the tutor's reply is still being generated.
  final bool isPending;

  ChatMessage copyWith({
    String? text,
    List<Correction>? corrections,
    bool? isPending,
  }) =>
      ChatMessage(
        id: id,
        speaker: speaker,
        text: text ?? this.text,
        at: at,
        corrections: corrections ?? this.corrections,
        isPending: isPending ?? this.isPending,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'speaker': speaker.name,
        'text': text,
        'at': at.toIso8601String(),
        'corrections': corrections.map((c) => c.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        speaker: j['speaker'] == 'user' ? Speaker.user : Speaker.tutor,
        text: j['text'] as String,
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
        corrections: (j['corrections'] as List?)
                ?.map((e) => Correction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

enum CorrectionType {
  grammar('Grammar'),
  vocabulary('Vocabulary'),
  pronunciation('Pronunciation'),
  phrasing('Phrasing');

  const CorrectionType(this.label);
  final String label;
}

/// A single "you said → better way to say it" pair with a reason.
@immutable
class Correction {
  const Correction({
    required this.original,
    required this.corrected,
    required this.explanation,
    this.type = CorrectionType.grammar,
  });

  final String original;
  final String corrected;
  final String explanation;
  final CorrectionType type;

  Map<String, dynamic> toJson() => {
        'original': original,
        'corrected': corrected,
        'explanation': explanation,
        'type': type.name,
      };

  factory Correction.fromJson(Map<String, dynamic> j) => Correction(
        original: j['original'] as String? ?? '',
        corrected: j['corrected'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        type: CorrectionType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => CorrectionType.grammar,
        ),
      );
}

/// A vocabulary upgrade: a plain word and the stronger alternative.
@immutable
class VocabUpgrade {
  const VocabUpgrade({
    required this.simple,
    required this.better,
    this.meaning = '',
    this.example = '',
  });

  final String simple;
  final String better;
  final String meaning;
  final String example;

  Map<String, dynamic> toJson() => {
        'simple': simple,
        'better': better,
        'meaning': meaning,
        'example': example,
      };

  factory VocabUpgrade.fromJson(Map<String, dynamic> j) => VocabUpgrade(
        simple: j['simple'] as String? ?? '',
        better: j['better'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        example: j['example'] as String? ?? '',
      );
}

/// A Gen-Z slang term with meaning and usage.
@immutable
class SlangTerm {
  const SlangTerm({
    required this.term,
    required this.meaning,
    required this.example,
    this.emoji = '😎',
  });

  final String term;
  final String meaning;
  final String example;
  final String emoji;

  Map<String, dynamic> toJson() => {
        'term': term,
        'meaning': meaning,
        'example': example,
        'emoji': emoji,
      };

  factory SlangTerm.fromJson(Map<String, dynamic> j) => SlangTerm(
        term: j['term'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        example: j['example'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '😎',
      );
}

/// A roleplay setting the learner can practise in.
@immutable
class Scenario {
  const Scenario({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.openingLine,
    this.mode = 'standard',
    this.proOnly = false,
    this.suggestions = const [],
  });

  final String id;
  final String title;
  final String description;
  final String emoji;

  /// The tutor's first line — what starts the conversation.
  final String openingLine;

  /// `standard` or `genZ`; filters the picker by the active mode.
  final String mode;
  final bool proOnly;

  /// Starter replies offered to the learner if they freeze.
  final List<String> suggestions;
}

/// The post-conversation report shown on the AI Speaking Coach screen.
@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.corrections,
    required this.vocabulary,
    required this.phrases,
    required this.slang,
    required this.fluencyScore,
    required this.pronunciationScore,
    required this.confidenceScore,
    this.encouragement = '',
  });

  final List<Correction> corrections;
  final List<VocabUpgrade> vocabulary;
  final List<String> phrases;
  final List<SlangTerm> slang;

  /// All 0–100.
  final int fluencyScore;
  final int pronunciationScore;
  final int confidenceScore;

  /// A warm closing line from the tutor.
  final String encouragement;

  int get overallScore =>
      ((fluencyScore + pronunciationScore + confidenceScore) / 3).round();

  Map<String, dynamic> toJson() => {
        'corrections': corrections.map((c) => c.toJson()).toList(),
        'vocabulary': vocabulary.map((v) => v.toJson()).toList(),
        'phrases': phrases,
        'slang': slang.map((s) => s.toJson()).toList(),
        'fluencyScore': fluencyScore,
        'pronunciationScore': pronunciationScore,
        'confidenceScore': confidenceScore,
        'encouragement': encouragement,
      };

  factory ConversationSummary.fromJson(Map<String, dynamic> j) =>
      ConversationSummary(
        corrections: (j['corrections'] as List?)
                ?.map((e) => Correction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        vocabulary: (j['vocabulary'] as List?)
                ?.map((e) => VocabUpgrade.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        phrases: (j['phrases'] as List?)?.cast<String>() ?? const [],
        slang: (j['slang'] as List?)
                ?.map((e) => SlangTerm.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        fluencyScore: (j['fluencyScore'] as num?)?.toInt() ?? 0,
        pronunciationScore: (j['pronunciationScore'] as num?)?.toInt() ?? 0,
        confidenceScore: (j['confidenceScore'] as num?)?.toInt() ?? 0,
        encouragement: j['encouragement'] as String? ?? '',
      );
}

/// A finished (or in-progress) practice conversation.
@immutable
class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.scenarioId,
    required this.scenarioTitle,
    required this.emoji,
    required this.startedAt,
    required this.messages,
    this.durationSeconds = 0,
    this.summary,
    this.xpEarned = 0,
  });

  final String id;
  final String scenarioId;
  final String scenarioTitle;
  final String emoji;
  final DateTime startedAt;
  final List<ChatMessage> messages;
  final int durationSeconds;
  final ConversationSummary? summary;
  final int xpEarned;

  int get userTurns => messages.where((m) => m.speaker == Speaker.user).length;

  ConversationSession copyWith({
    List<ChatMessage>? messages,
    int? durationSeconds,
    ConversationSummary? summary,
    int? xpEarned,
  }) =>
      ConversationSession(
        id: id,
        scenarioId: scenarioId,
        scenarioTitle: scenarioTitle,
        emoji: emoji,
        startedAt: startedAt,
        messages: messages ?? this.messages,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        summary: summary ?? this.summary,
        xpEarned: xpEarned ?? this.xpEarned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scenarioId': scenarioId,
        'scenarioTitle': scenarioTitle,
        'emoji': emoji,
        'startedAt': startedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        'durationSeconds': durationSeconds,
        'summary': summary?.toJson(),
        'xpEarned': xpEarned,
      };

  factory ConversationSession.fromJson(Map<String, dynamic> j) =>
      ConversationSession(
        id: j['id'] as String,
        scenarioId: j['scenarioId'] as String? ?? '',
        scenarioTitle: j['scenarioTitle'] as String? ?? 'Conversation',
        emoji: j['emoji'] as String? ?? '💬',
        startedAt:
            DateTime.tryParse(j['startedAt'] as String? ?? '') ?? DateTime.now(),
        messages: (j['messages'] as List?)
                ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        summary: j['summary'] == null
            ? null
            : ConversationSummary.fromJson(
                j['summary'] as Map<String, dynamic>),
        xpEarned: (j['xpEarned'] as num?)?.toInt() ?? 0,
      );
}
