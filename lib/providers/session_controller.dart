import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/conversation.dart';
import '../data/repositories/local_store.dart';
import 'app_providers.dart';

/// Persisted history of finished conversations, newest first.
///
/// Feeds "Recent Conversations" on Progress and the summary screen when a
/// past session is reopened.
class SessionHistoryController extends Notifier<List<ConversationSession>> {
  static const _maxStored = 50;

  @override
  List<ConversationSession> build() {
    final raw = ref.read(localStoreProvider).getJsonList(LocalStore.kSessions);
    final sessions = <ConversationSession>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        sessions.add(ConversationSession.fromJson(entry));
      }
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<void> save(ConversationSession session) async {
    final next = [
      session,
      ...state.where((s) => s.id != session.id),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final trimmed =
        next.length > _maxStored ? next.sublist(0, _maxStored) : next;
    state = trimmed;
    await ref.read(localStoreProvider).setJsonList(
          LocalStore.kSessions,
          trimmed.map((s) => s.toJson()).toList(),
        );
  }

  ConversationSession? byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(localStoreProvider).remove(LocalStore.kSessions);
  }
}

final sessionHistoryProvider =
    NotifierProvider<SessionHistoryController, List<ConversationSession>>(
  SessionHistoryController.new,
);

/// The most recent session that carries a summary — the one "Conversation
/// Summary" opens from the practice screen.
final latestSummarisedSessionProvider =
    Provider<ConversationSession?>((ref) {
  final sessions = ref.watch(sessionHistoryProvider);
  for (final s in sessions) {
    if (s.summary != null) return s;
  }
  return null;
});

/// Phrases the learner has starred from summaries and lessons.
class SavedPhrasesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final raw =
        ref.read(localStoreProvider).getJsonList(LocalStore.kSavedPhrases);
    return raw.whereType<String>().toSet();
  }

  Future<void> toggle(String phrase) async {
    final next = {...state};
    if (!next.remove(phrase)) next.add(phrase);
    state = next;
    await ref
        .read(localStoreProvider)
        .setJsonList(LocalStore.kSavedPhrases, next.toList());
  }

  bool contains(String phrase) => state.contains(phrase);
}

final savedPhrasesProvider =
    NotifierProvider<SavedPhrasesController, Set<String>>(
  SavedPhrasesController.new,
);
