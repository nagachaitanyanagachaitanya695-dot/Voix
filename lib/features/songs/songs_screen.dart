import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../data/models/song.dart';
import '../../data/services/song_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/songs_controller.dart';
import 'song_practice_screen.dart';

/// Songs the learner has brought in, and the way to bring in more.
///
/// Singing is not a gimmick here: it drills rhythm, connected speech and the
/// vowel sounds a Telugu, Hindi or Tamil speaker has to unlearn — and it does
/// it while someone is enjoying themselves rather than being tested.
class SongsScreen extends ConsumerStatefulWidget {
  const SongsScreen({super.key});

  @override
  ConsumerState<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends ConsumerState<SongsScreen> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    Haptic.tap();
    setState(() => _importing = true);

    final result = await ref
        .read(songServiceProvider)
        .importSong(deviceId: ref.read(deviceIdProvider));

    if (!mounted) return;
    setState(() => _importing = false);

    if (result.ok) {
      final song = result.song!;
      await ref.read(songsControllerProvider.notifier).add(song);
      if (!mounted) return;
      // Straight into practice: someone who just picked a song wants to sing
      // it, not to look at a list with one more row in it.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SongPracticeScreen(songId: song.id),
        ),
      );
      return;
    }

    if (result.error == SongImportError.cancelled) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (result.error) {
          SongImportError.tooLarge =>
            'That file is too big. Songs up to 20 MB work best.',
          SongImportError.unreadable =>
            'Could not open that file. Try a different one.',
          _ => 'Something went wrong bringing that song in.',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final songs = ref.watch(songsControllerProvider);
    final c = context.colors;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.sm),
                      child: Icon(Icons.arrow_back_rounded,
                          color: c.textSecondary),
                    ),
                  ),
                  Text(
                    'Sing',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: songs.isEmpty
                    ? _Empty(onImport: _import, importing: _importing)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Gap.page, Gap.sm, Gap.page, Gap.xxl),
                        itemCount: songs.length,
                        separatorBuilder: (_, __) => Gap.h12,
                        itemBuilder: (_, i) => FadeSlideIn(
                          index: i,
                          child: _SongRow(
                            song: songs[i],
                            onOpen: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    SongPracticeScreen(songId: songs[i].id),
                              ),
                            ),
                            onDelete: () => ref
                                .read(songsControllerProvider.notifier)
                                .remove(songs[i].id),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: songs.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _importing ? null : _import,
              icon: _importing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_rounded),
              label: Text(_importing ? 'Reading…' : 'Add a song'),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onImport, required this.importing});
  final VoidCallback onImport;
  final bool importing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded, size: 56, color: c.textTertiary),
            Gap.h20,
            Text(
              'Learn a song',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            Gap.h8,
            Text(
              'Pick a song from your phone. Voix works out the words and when '
              'each one is sung, then listens while you sing along.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 15, height: 1.5, color: c.textSecondary),
            ),
            Gap.h24,
            FilledButton.icon(
              onPressed: importing ? null : onImport,
              icon: const Icon(Icons.library_music_rounded),
              label: Text(importing ? 'Reading the song…' : 'Choose a song'),
            ),
            if (!BackendConfig.isConfigured) ...[
              Gap.h16,
              Text(
                'Without the tutor set up the words cannot be read '
                'automatically — you can still add a song and type the lyrics '
                'in yourself.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.song,
    required this.onOpen,
    required this.onDelete,
  });

  final Song song;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dismissible(
      key: ValueKey(song.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gap.lg),
        decoration: BoxDecoration(
          color: VoixPalette.danger.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) => onDelete(),
      child: Pressable(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VoixPalette.violet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: VoixPalette.violet),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    Text(
                      song.hasLyrics
                          ? '${song.lines.length} lines'
                          : 'No lyrics yet',
                      style: TextStyle(fontSize: 13, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              if (song.bestScore != null)
                Text(
                  '${song.bestScore}',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: VoixPalette.success,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
