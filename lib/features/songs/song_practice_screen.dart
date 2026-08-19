import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import '../../data/models/song.dart';
import '../../data/services/pitch_tracker.dart';
import '../../providers/songs_controller.dart';
import '../learn/word_sheet.dart';

/// Sing along, with the line you are on lit up and the app listening.
///
/// The song plays, the current line is highlighted, and while it does the
/// microphone is read for pitch. At the end the learner is told how much of it
/// they were actually in tune for — which is the only feedback that makes
/// singing practice rather than playback.
class SongPracticeScreen extends ConsumerStatefulWidget {
  const SongPracticeScreen({super.key, required this.songId});

  final String songId;

  @override
  ConsumerState<SongPracticeScreen> createState() =>
      _SongPracticeScreenState();
}

class _SongPracticeScreenState extends ConsumerState<SongPracticeScreen> {
  final _player = AudioPlayer();
  final _recorder = AudioRecorder();
  final _scroll = ScrollController();

  StreamSubscription<Duration>? _position;
  StreamSubscription<PlayerState>? _playerState;
  StreamSubscription<List<int>>? _mic;

  /// 16 kHz is plenty for a voice and a quarter of the data of 48.
  static const _micRate = 16000;

  int _positionMs = 0;
  int _lineIndex = -1;
  bool _ready = false;
  bool _listening = false;
  String? _error;

  /// How many microphone chunks carried a pitch at all, and how many of those
  /// were on the note. Singing quality is the ratio; singing *at all* is the
  /// first number, and a learner who never opened their mouth should not be
  /// told they were perfectly in tune.
  int _voicedChunks = 0;
  int _inTuneChunks = 0;

  /// The last note heard, for the meter.
  double? _currentHz;

  /// The pitch of the recording at this moment, learned from the learner's own
  /// first pass. Null until there is one.
  final _reference = <int, double>{};

  Song? get _song =>
      ref.read(songsControllerProvider).where((s) => s.id == widget.songId).singleOrNull;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final song = _song;
    if (song == null) return;
    try {
      await _player.setFilePath(song.filePath);
      _position = _player.positionStream.listen((p) {
        if (!mounted) return;
        final ms = p.inMilliseconds;
        final index = song.indexAt(ms);
        if (index != _lineIndex) {
          setState(() {
            _positionMs = ms;
            _lineIndex = index;
          });
          _scrollTo(index);
        } else if ((ms - _positionMs).abs() > 200) {
          setState(() => _positionMs = ms);
        }
      });
      _playerState = _player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed) _finish();
      });
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'That audio file could not be played.');
      }
    }
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients || index < 0) return;
    // Keeps the sung line a third of the way down rather than at the very top,
    // so the next lines are visible before they arrive — you cannot sing a
    // line you are reading for the first time.
    const lineHeight = 64.0;
    final target = (index * lineHeight) - (_scroll.position.viewportDimension / 3);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: Motion.base,
      curve: Motion.enter,
    );
  }

  Future<void> _togglePlay() async {
    Haptic.tap();
    if (_player.playing) {
      await _player.pause();
      await _stopListening();
    } else {
      await _startListening();
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (_listening) return;
    if (!await _recorder.hasPermission()) return;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _micRate,
        numChannels: 1,
        // Without this the microphone hears the song itself and scores the
        // recording rather than the singer.
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _listening = true;
    _mic = stream.listen((chunk) {
      final hz = PitchTracker.detect(chunk, sampleRate: _micRate);
      if (hz == null) return;

      _voicedChunks++;
      final bucket = _positionMs ~/ 250;
      final target = _reference[bucket];
      if (target == null) {
        // Nothing to compare against yet, so this pass teaches the app what
        // the tune is. The learner's first run through a song is a rehearsal
        // either way.
        _reference[bucket] = hz;
      } else if (PitchTracker.inTune(hz, target)) {
        _inTuneChunks++;
      }

      if (mounted) setState(() => _currentHz = hz);
    });
  }

  Future<void> _stopListening() async {
    await _mic?.cancel();
    _mic = null;
    if (_listening) {
      try {
        if (await _recorder.isRecording()) await _recorder.stop();
      } catch (_) {
        // Nothing useful to do: the call is ending either way.
      }
      _listening = false;
    }
    if (mounted) setState(() => _currentHz = null);
  }

  Future<void> _finish() async {
    await _stopListening();
    if (!mounted) return;

    final score = _score();
    await ref.read(songsControllerProvider.notifier).recordScore(
          widget.songId,
          score,
        );
    if (!mounted) return;
    unawaited(showDialog<void>(
      context: context,
      builder: (_) => _ResultDialog(score: score, sang: _voicedChunks > 20),
    ));
  }

  /// 0–100, and honest about silence.
  int _score() {
    if (_voicedChunks < 20) return 0;
    // The first pass has nothing to compare against, so it can only be scored
    // on having sung at all.
    if (_inTuneChunks == 0 && _reference.length == _voicedChunks) return 50;
    return ((_inTuneChunks / _voicedChunks) * 100).round().clamp(0, 100);
  }

  @override
  void dispose() {
    unawaited(_position?.cancel());
    unawaited(_playerState?.cancel());
    unawaited(_stopListening());
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    final c = context.colors;
    if (song == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      body: AuroraBackground(
        animate: false,
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
                  Expanded(
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Gap.w12,
                ],
              ),

              if (_error != null)
                Expanded(child: Center(child: Text(_error!)))
              else if (!song.hasLyrics)
                Expanded(child: _NoLyrics(song: song))
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: Gap.page, vertical: Gap.lg),
                    itemCount: song.lines.length,
                    itemBuilder: (_, i) => _LyricRow(
                      line: song.lines[i],
                      active: i == _lineIndex,
                      // Any word can be tapped for its meaning: half of what
                      // makes a song worth learning is the words in it.
                      onWord: (w) => showWordSheet(context, w),
                    ),
                  ),
                ),

              _Controls(
                ready: _ready,
                playing: _player.playing,
                listening: _listening,
                hz: _currentHz,
                onToggle: _ready ? _togglePlay : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.active,
    required this.onWord,
  });

  final LyricLine line;
  final bool active;
  final ValueChanged<String> onWord;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: AnimatedDefaultTextStyle(
        duration: Motion.base,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: active ? 24 : 19,
          height: 1.35,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active ? c.textPrimary : c.textTertiary,
        ),
        child: Wrap(
          spacing: 6,
          children: [
            for (final word in line.words)
              GestureDetector(
                onTap: () => onWord(word.text),
                child: Text(word.text),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoLyrics extends StatelessWidget {
  const _NoLyrics({required this.song});
  final Song song;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 48, color: c.textTertiary),
            Gap.h16,
            Text(
              'No words for this one yet',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
            Gap.h8,
            Text(
              'The tutor could not read the lyrics from this file. You can '
              'still play it and sing along — the app will listen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.ready,
    required this.playing,
    required this.listening,
    required this.hz,
    required this.onToggle,
  });

  final bool ready;
  final bool playing;
  final bool listening;
  final double? hz;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.fromLTRB(
          Gap.page, Gap.md, Gap.page, context.safeArea.bottom + Gap.md),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  listening ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 18,
                  color: listening ? VoixPalette.success : c.textTertiary,
                ),
                Gap.w8,
                Text(
                  hz != null
                      ? 'Hearing you'
                      : listening
                          ? 'Sing along'
                          : 'Press play',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onToggle,
            icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(
              !ready
                  ? 'Loading…'
                  : playing
                      ? 'Pause'
                      : 'Play',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.score, required this.sang});
  final int score;
  final bool sang;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(sang ? 'Nicely done' : 'Nothing heard'),
      content: Text(
        sang
            ? 'You were on the note $score% of the time you were singing. '
                'Sing it again and Voix will compare you with your last run.'
            : 'The microphone did not pick up any singing. Check that Voix is '
                'allowed to use it, and try somewhere quieter.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
