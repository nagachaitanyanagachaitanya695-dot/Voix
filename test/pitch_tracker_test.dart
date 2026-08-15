import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/services/pitch_tracker.dart';

/// Everything the singing coach says rests on this being right. A pitch
/// detector that is confidently wrong tells a learner they are flat when they
/// are not, which is worse than saying nothing at all.
void main() {
  const rate = 16000;

  /// A tone of [hz], optionally with harmonics so it resembles a voice rather
  /// than a test signal.
  Uint8List tone(
    double hz, {
    int ms = 100,
    double amplitude = 0.5,
    bool harmonics = false,
    double noise = 0,
  }) {
    final count = rate * ms ~/ 1000;
    final bytes = Uint8List(count * 2);
    final view = ByteData.sublistView(bytes);
    final rng = math.Random(7);
    for (var i = 0; i < count; i++) {
      final t = i / rate;
      var v = math.sin(2 * math.pi * hz * t);
      if (harmonics) {
        // A sung vowel carries most of its energy above the fundamental, which
        // is exactly the case a naive detector gets wrong by an octave.
        v = 0.5 * v +
            0.9 * math.sin(2 * math.pi * hz * 2 * t) +
            0.6 * math.sin(2 * math.pi * hz * 3 * t);
        v /= 2.0;
      }
      if (noise > 0) v += noise * (rng.nextDouble() * 2 - 1);
      view.setInt16(
        i * 2,
        (v * amplitude * 32767).clamp(-32768, 32767).round(),
        Endian.little,
      );
    }
    return bytes;
  }

  Matcher closeToHz(double hz) => closeTo(hz, hz * 0.03);

  group('detect', () {
    test('finds a pure tone across the sung range', () {
      for (final hz in [98.0, 220.0, 440.0, 880.0]) {
        expect(
          PitchTracker.detect(tone(hz), sampleRate: rate),
          closeToHz(hz),
          reason: '$hz Hz',
        );
      }
    });

    test('finds the fundamental of a voice-like tone, not a harmonic', () {
      // The classic failure: locking onto the loudest partial and reporting
      // the note an octave up.
      final hz = PitchTracker.detect(
        tone(196, harmonics: true),
        sampleRate: rate,
      );
      expect(hz, closeToHz(196));
    });

    test('survives a noisy room', () {
      expect(
        PitchTracker.detect(tone(261.6, noise: 0.08), sampleRate: rate),
        closeToHz(261.6),
      );
    });

    test('reports nothing for silence', () {
      expect(PitchTracker.detect(Uint8List(3200), sampleRate: rate), isNull);
    });

    test('reports nothing for noise alone', () {
      // Hiss has no period. A detector that returns a number here produces a
      // meter that dances while nobody is singing.
      final rng = math.Random(3);
      final bytes = Uint8List(3200);
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i < 1600; i++) {
        view.setInt16(i * 2, (rng.nextDouble() * 20000 - 10000).round(),
            Endian.little);
      }
      expect(PitchTracker.detect(bytes, sampleRate: rate), isNull);
    });

    test('reports nothing for a chunk too short to hold a period', () {
      expect(PitchTracker.detect(Uint8List(8), sampleRate: rate), isNull);
    });

    test('resolves better than a semitone up high', () {
      // Without interpolation the lag grid at 880 Hz steps by more than a
      // semitone, which would flag a correct note as out of tune.
      final a = PitchTracker.detect(tone(880), sampleRate: rate)!;
      final b = PitchTracker.detect(tone(932.3), sampleRate: rate)!;
      expect(PitchTracker.semitonesBetween(a, b), closeTo(1.0, 0.25));
    });
  });

  group('semitonesBetween', () {
    test('an octave is twelve semitones', () {
      expect(PitchTracker.semitonesBetween(220, 440), closeTo(12, 0.001));
      expect(PitchTracker.semitonesBetween(440, 220), closeTo(-12, 0.001));
    });

    test('a fifth is seven', () {
      expect(PitchTracker.semitonesBetween(440, 659.25), closeTo(7, 0.01));
    });
  });

  group('inTune', () {
    test('accepts the same note', () {
      expect(PitchTracker.inTune(440, 440), isTrue);
    });

    test('accepts the note sung an octave lower', () {
      // A man singing along to a woman's recording is singing it right, and
      // being marked wrong for it would make the feature useless to half its
      // users.
      expect(PitchTracker.inTune(220, 440), isTrue);
      expect(PitchTracker.inTune(880, 220), isTrue);
    });

    test('rejects a neighbouring note', () {
      expect(PitchTracker.inTune(466.16, 440), isFalse); // one semitone sharp
    });

    test('accepts being slightly under a quarter tone out', () {
      expect(PitchTracker.inTune(445, 440), isTrue); // ~0.2 semitones
    });

    test('rejects a pitch that was never found', () {
      expect(PitchTracker.inTune(0, 440), isFalse);
    });
  });
}
