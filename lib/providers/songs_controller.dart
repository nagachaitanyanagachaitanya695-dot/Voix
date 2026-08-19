import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/song.dart';
import '../data/repositories/local_store.dart';
import 'app_providers.dart';

/// The learner's imported songs, newest first.
///
/// Persisted immediately on every change: importing a song costs a
/// transcription, and losing that because the app was killed would be paying
/// twice for the same thing.
class SongsController extends Notifier<List<Song>> {
  @override
  List<Song> build() {
    final raw = ref.read(localStoreProvider).getJsonList(LocalStore.kSongs);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  Future<void> add(Song song) async {
    state = [song, ...state.where((s) => s.id != song.id)];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _save();
  }

  /// Replaces a song, keeping its position in the list.
  Future<void> update(Song song) async {
    state = [
      for (final s in state) if (s.id == song.id) song else s,
    ];
    await _save();
  }

  /// Records a finished run. Only an improvement moves the best score, so a
  /// bad take cannot erase a good one.
  Future<void> recordScore(String id, int score) async {
    final song = state.where((s) => s.id == id).singleOrNull;
    if (song == null) return;
    await update(
      song.copyWith(
        bestScore: song.bestScore == null || score > song.bestScore!
            ? score
            : song.bestScore,
        practiseCount: song.practiseCount + 1,
      ),
    );
  }

  Future<void> _save() => ref.read(localStoreProvider).setString(
        LocalStore.kSongs,
        jsonEncode(state.map((s) => s.toJson()).toList()),
      );
}

final songsControllerProvider =
    NotifierProvider<SongsController, List<Song>>(SongsController.new);
