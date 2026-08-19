import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/models/song.dart';
import 'package:voix/data/services/song_service.dart';

/// Lyrics are useless unless they line up with the singing, and a line that
/// highlights at the wrong moment is worse than no highlight at all.
void main() {
  LyricWord w(String text, int start, int end) =>
      LyricWord(text: text, startMs: start, endMs: end);

  group('grouping words into lines', () {
    test('breaks where the singing pauses', () {
      final lines = LyricLine.group([
        w('never', 0, 300),
        w('gonna', 300, 600),
        w('give', 600, 900),
        w('you', 900, 1100),
        w('up', 1100, 1400),
        // A rest: the end of the phrase.
        w('never', 2400, 2700),
        w('gonna', 2700, 3000),
        w('let', 3000, 3200),
        w('you', 3200, 3400),
        w('down', 3400, 3800),
      ]);

      expect(lines, hasLength(2));
      expect(lines.first.text, 'never gonna give you up');
      expect(lines.last.text, 'never gonna let you down');
    });

    test('caps a line even when the singing never stops', () {
      // Rapping, or a held phrase: without a cap this is one line running off
      // the side of the phone.
      final words = [
        for (var i = 0; i < 25; i++) w('word$i', i * 200, i * 200 + 180),
      ];
      final lines = LyricLine.group(words, maxWords: 9);

      expect(lines.length, greaterThan(2));
      for (final line in lines) {
        expect(line.words.length, lessThanOrEqualTo(9));
      }
    });

    test('breaks after a full stop', () {
      final lines = LyricLine.group([
        w('hello.', 0, 400),
        w('goodbye', 500, 900),
      ], gapMs: 700);
      expect(lines, hasLength(2));
    });

    test('loses no words', () {
      final words = [
        for (var i = 0; i < 40; i++) w('w$i', i * 300, i * 300 + 250),
      ];
      final total = LyricLine.group(words)
          .fold<int>(0, (n, l) => n + l.words.length);
      expect(total, 40, reason: 'a dropped word is a lyric the learner cannot see');
    });

    test('handles an empty transcription', () {
      expect(LyricLine.group(const []), isEmpty);
    });
  });

  group('which line is lit', () {
    final song = Song(
      id: 's1',
      title: 'Test',
      filePath: '/tmp/x.mp3',
      lines: LyricLine.group([
        w('one', 1000, 1400),
        w('two', 3000, 3400),
        w('three', 6000, 6400),
      ], gapMs: 700),
    );

    test('nothing before the first word', () {
      expect(song.indexAt(0), -1);
      expect(song.indexAt(999), -1);
    });

    test('holds the current line through the gap after it', () {
      // Between phrases there is no line being sung, but blanking the
      // highlight every time reads as a flicker rather than a rest.
      expect(song.indexAt(1200), 0);
      expect(song.indexAt(2000), 0);
      expect(song.indexAt(3100), 1);
      expect(song.indexAt(5000), 1);
    });

    test('stays on the last line past the end', () {
      expect(song.indexAt(600000), song.lines.length - 1);
    });
  });

  group('titles from filenames', () {
    test('strips the extension, track number and downloader noise', () {
      expect(SongService.titleFrom('03 - Shape of You.mp3'), 'Shape of You');
      expect(
        SongService.titleFrom('Perfect_(Official_Audio).m4a'),
        'Perfect',
      );
      expect(
        SongService.titleFrom('Let It Be (Official Video) HD.mp3'),
        'Let It Be',
      );
    });

    test('leaves an ordinary name alone', () {
      expect(SongService.titleFrom('Yesterday.mp3'), 'Yesterday');
    });

    test('never returns an empty title', () {
      // A blank row in the list looks like a bug.
      expect(SongService.titleFrom('.mp3'), 'Untitled song');
      expect(SongService.titleFrom('(official audio).mp3'), 'Untitled song');
    });
  });

  group('persistence', () {
    test('a song survives a round trip', () {
      final song = Song(
        id: 's1',
        title: 'Test',
        filePath: '/music/test.mp3',
        durationMs: 210000,
        bestScore: 72,
        practiseCount: 3,
        lines: LyricLine.group([w('hello', 0, 400), w('world', 400, 900)]),
      );

      final back = Song.fromJson(song.toJson());
      expect(back.title, song.title);
      expect(back.filePath, song.filePath);
      expect(back.bestScore, 72);
      expect(back.practiseCount, 3);
      expect(back.lines.single.text, 'hello world');
      expect(back.lines.single.startMs, 0);
      expect(back.lines.single.endMs, 900);
    });

    test('a corrupt entry does not throw', () {
      // Storage can be interrupted mid-write; the library must still open.
      final back = Song.fromJson({'id': 's1', 'lines': 'not a list'});
      expect(back.lines, isEmpty);
      expect(back.title, 'Untitled');
    });
  });
}
