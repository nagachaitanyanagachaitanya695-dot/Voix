import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One word of a song, with the moment it is sung.
@immutable
class LyricWord {
  const LyricWord({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;

  int get durationMs => math.max(0, endMs - startMs);

  Map<String, dynamic> toJson() => {'t': text, 's': startMs, 'e': endMs};

  static LyricWord fromJson(Map<String, dynamic> j) => LyricWord(
        text: j['t'] as String? ?? '',
        startMs: (j['s'] as num?)?.toInt() ?? 0,
        endMs: (j['e'] as num?)?.toInt() ?? 0,
      );
}

/// A line of lyrics — the unit a learner actually practises.
///
/// Singing along to a whole song is not practice; repeating one line until it
/// sits right is. Every drill in the app works on one of these.
@immutable
class LyricLine {
  const LyricLine(this.words);

  final List<LyricWord> words;

  String get text => words.map((w) => w.text).join(' ');
  int get startMs => words.isEmpty ? 0 : words.first.startMs;
  int get endMs => words.isEmpty ? 0 : words.last.endMs;
  int get durationMs => math.max(0, endMs - startMs);

  bool containsMs(int ms) => ms >= startMs && ms < endMs;

  Map<String, dynamic> toJson() => {'w': words.map((w) => w.toJson()).toList()};

  static LyricLine fromJson(Map<String, dynamic> j) => LyricLine(
        ((j['w'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LyricWord.fromJson)
            .toList(),
      );

  /// Groups timed words into lines the way a lyric sheet would.
  ///
  /// Transcription returns a flat run of words; a singer needs phrases. Two
  /// things end a line, and both matter:
  ///
  ///  * **A gap.** Singing pauses at the end of a phrase, so a rest longer
  ///    than [gapMs] is almost always a line break. This is what makes the
  ///    lines match how the song is actually sung rather than how it reads.
  ///  * **Length.** A line that runs past [maxWords] is unreadable on a phone
  ///    while it scrolls past, however continuous the singing was.
  ///
  /// Sentence-ending punctuation also breaks, since transcription usually
  /// marks it and it costs nothing to honour.
  static List<LyricLine> group(
    List<LyricWord> words, {
    int gapMs = 700,
    int maxWords = 9,
  }) {
    if (words.isEmpty) return const [];

    final lines = <LyricLine>[];
    var current = <LyricWord>[];

    for (var i = 0; i < words.length; i++) {
      current.add(words[i]);

      final isLast = i == words.length - 1;
      if (isLast) break;

      final gap = words[i + 1].startMs - words[i].endMs;
      final endsSentence = RegExp(r'[.!?]$').hasMatch(words[i].text);

      if (gap >= gapMs || endsSentence || current.length >= maxWords) {
        lines.add(LyricLine(current));
        current = <LyricWord>[];
      }
    }

    if (current.isNotEmpty) lines.add(LyricLine(current));
    return lines;
  }
}

/// A song imported for practice.
///
/// The audio itself stays where the learner picked it — only the path is
/// stored. Copying every song into the app's own storage would double the
/// space a music library takes for no benefit.
@immutable
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.filePath,
    required this.lines,
    this.artist = '',
    this.durationMs = 0,
    this.bestScore,
    this.practiseCount = 0,
  });

  final String id;
  final String title;
  final String artist;
  final String filePath;
  final int durationMs;
  final List<LyricLine> lines;

  /// Best overall score so far, 0–100. Null until the song has been sung.
  final int? bestScore;
  final int practiseCount;

  bool get hasLyrics => lines.isNotEmpty;
  int get wordCount => lines.fold(0, (n, l) => n + l.words.length);

  /// The line being sung at [ms], or null between lines.
  LyricLine? lineAt(int ms) {
    for (final line in lines) {
      if (line.containsMs(ms)) return line;
    }
    return null;
  }

  /// The line to highlight at [ms].
  ///
  /// Unlike [lineAt] this never returns null once the song has started: during
  /// the gap between two lines it keeps the previous one lit, because a
  /// highlight that blinks out between every phrase reads as a bug.
  int indexAt(int ms) {
    if (lines.isEmpty) return -1;
    if (ms < lines.first.startMs) return -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (ms >= lines[i].startMs) return i;
    }
    return -1;
  }

  Song copyWith({int? bestScore, int? practiseCount, String? title}) => Song(
        id: id,
        title: title ?? this.title,
        artist: artist,
        filePath: filePath,
        durationMs: durationMs,
        lines: lines,
        bestScore: bestScore ?? this.bestScore,
        practiseCount: practiseCount ?? this.practiseCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'filePath': filePath,
        'durationMs': durationMs,
        'lines': lines.map((l) => l.toJson()).toList(),
        'bestScore': bestScore,
        'practiseCount': practiseCount,
      };

  static Song fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? 'Untitled',
        artist: j['artist'] as String? ?? '',
        filePath: j['filePath'] as String? ?? '',
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        lines: ((j['lines'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LyricLine.fromJson)
            .toList(),
        bestScore: (j['bestScore'] as num?)?.toInt(),
        practiseCount: (j['practiseCount'] as num?)?.toInt() ?? 0,
      );
}
