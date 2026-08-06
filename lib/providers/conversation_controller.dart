import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content/scenario_catalog.dart';
import '../data/models/conversation.dart';
import '../data/models/user_profile.dart';
import 'app_providers.dart';
import 'user_controller.dart';

/// Live state of the conversation screen.
@immutable
class ConversationState {
  const ConversationState({
    required this.scenario,
    required this.messages,
    required this.startedAt,
    this.tutorThinking = false,
    this.listening = false,
    this.summarising = false,
    this.summary,
    this.error,
  });

  final Scenario scenario;
  final List<ChatMessage> messages;
  final DateTime startedAt;

  /// The tutor is composing a reply.
  final bool tutorThinking;

  /// The mic is open.
  final bool listening;

  /// The end-of-session report is being generated.
  final bool summarising;
  final ConversationSummary? summary;
  final String? error;

  int get userTurns => messages.where((m) => m.speaker == Speaker.user).length;
  int get elapsedSeconds => DateTime.now().difference(startedAt).inSeconds;

  /// Two exchanges is the minimum that produces a report worth reading.
  bool get canFinish => userTurns >= 1;

  /// True when the learner may speak — the tutor is not mid-turn.
  bool get inputEnabled => !tutorThinking && !summarising;

  ConversationState copyWith({
    List<ChatMessage>? messages,
    bool? tutorThinking,
    bool? listening,
    bool? summarising,
    ConversationSummary? summary,
    String? error,
    bool clearError = false,
  }) =>
      ConversationState(
        scenario: scenario,
        messages: messages ?? this.messages,
        startedAt: startedAt,
        tutorThinking: tutorThinking ?? this.tutorThinking,
        listening: listening ?? this.listening,
        summarising: summarising ?? this.summarising,
        summary: summary ?? this.summary,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives one practice conversation from the opening line to the report.
///
/// Auto-disposed so leaving the screen tears the session down; anything worth
/// keeping is written to `sessionHistoryProvider` on finish.
class ConversationController extends AutoDisposeNotifier<ConversationState?> {
  @override
  ConversationState? build() => null;

  int _messageSeq = 0;
  String _id(String prefix) => '${prefix}_${_messageSeq++}';

  /// Opens a session and seeds it with the tutor's first line.
  void start(Scenario scenario) {
    _messageSeq = 0;
    state = ConversationState(
      scenario: scenario,
      startedAt: DateTime.now(),
      messages: [
        ChatMessage(
          id: _id('m'),
          speaker: Speaker.tutor,
          text: scenario.openingLine,
          at: DateTime.now(),
        ),
      ],
    );
  }

  void setListening(bool value) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(listening: value);
  }

  /// Submits a learner turn and requests the tutor's reply.
  Future<void> send(String text) async {
    final s = state;
    final user = ref.read(userControllerProvider);
    if (s == null || user == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty || s.tutorThinking) return;

    final userMessage = ChatMessage(
      id: _id('u'),
      speaker: Speaker.user,
      text: trimmed,
      at: DateTime.now(),
    );

    // Show the learner's turn and the typing indicator together, so the
    // screen never sits empty while the tutor composes.
    state = s.copyWith(
      messages: [...s.messages, userMessage],
      tutorThinking: true,
      listening: false,
      clearError: true,
    );

    try {
      final turn = await ref.read(aiTutorProvider).respond(
            scenario: s.scenario,
            history: s.messages,
            userMessage: trimmed,
            user: user,
          );

      final current = state;
      if (current == null) return; // Screen was closed mid-request.

      // Attach the corrections to the learner's own message so they render
      // beneath the bubble they belong to.
      final withCorrections = current.messages
          .map((m) => m.id == userMessage.id
              ? m.copyWith(corrections: turn.corrections)
              : m)
          .toList();

      state = current.copyWith(
        messages: [
          ...withCorrections,
          ChatMessage(
            id: _id('t'),
            speaker: Speaker.tutor,
            text: turn.reply,
            at: DateTime.now(),
          ),
        ],
        tutorThinking: false,
      );
    } catch (e) {
      debugPrint('ConversationController.send failed: $e');
      final current = state;
      if (current == null) return;
      state = current.copyWith(
        tutorThinking: false,
        error: 'Could not reach your tutor. Please try again.',
      );
    }
  }

  /// Generates the report. Returns the saved session, or null if there was
  /// nothing to summarise.
  Future<ConversationSession?> finish() async {
    final s = state;
    final user = ref.read(userControllerProvider);
    if (s == null || user == null) return null;

    state = s.copyWith(summarising: true);

    final summary = await ref.read(aiTutorProvider).summarise(
          scenario: s.scenario,
          history: s.messages,
          user: user,
        );

    final durationSeconds = DateTime.now().difference(s.startedAt).inSeconds;

    // XP rewards effort (turns taken) more than perfection, which is what
    // keeps a nervous learner coming back.
    final xp = 20 + s.userTurns * 8 + (summary.overallScore ~/ 10) * 3;

    final session = ConversationSession(
      id: 'sess_${s.startedAt.millisecondsSinceEpoch}',
      scenarioId: s.scenario.id,
      scenarioTitle: s.scenario.title,
      emoji: s.scenario.emoji,
      startedAt: s.startedAt,
      messages: s.messages,
      durationSeconds: durationSeconds,
      summary: summary,
      xpEarned: xp,
    );

    if (state != null) {
      state = state!.copyWith(summarising: false, summary: summary);
    }
    return session;
  }

  void reset() => state = null;
}

final conversationControllerProvider = AutoDisposeNotifierProvider<
    ConversationController, ConversationState?>(ConversationController.new);

/// Scenarios matching the learner's active mode.
///
/// Pro-only entries stay visible for free accounts — they act as the upgrade
/// prompt — but are tagged so the UI can lock them.
final availableScenariosProvider = Provider<List<Scenario>>((ref) {
  final mode = ref.watch(userControllerProvider)?.mode ?? LearningMode.standard;
  return ScenarioCatalog.forMode(mode == LearningMode.genZ ? 'genZ' : 'standard');
});
