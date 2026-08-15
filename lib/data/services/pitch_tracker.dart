import 'dart:math' as math;
import 'dart:typed_data';

/// Finds the note being sung in a chunk of microphone audio.
///
/// This is what separates teaching someone to *sing* from showing them the
/// words: without it the app can only check that the right syllables came out,
/// not whether they were on the right note or in time.
///
/// The method is normalised autocorrelation. A voiced sound repeats at its
/// fundamental period, so the signal correlated against a delayed copy of
/// itself peaks at that period. Compared with an FFT this is easy to reason
/// about, needs no windowing decisions, and at these buffer sizes is cheap
/// enough to run on every microphone chunk without touching the frame budget.
abstract final class PitchTracker {
  /// The sung range, generously bounded. Anything outside is noise, not a
  /// voice, and admitting it produces a meter that jumps around on silence.
  static const minHz = 70.0; // below a low male voice
  static const maxHz = 1100.0; // above a high female voice

  /// How periodic the signal must look before its pitch is believed.
  ///
  /// Speech and singing are strongly periodic; room noise, consonants and
  /// breaths are not. Reporting a pitch for those is worse than reporting
  /// nothing, because the learner sees a confident wrong answer.
  static const _minClarity = 0.72;

  /// Below this the microphone is effectively silent.
  static const _minRms = 0.012;

  /// Returns the fundamental frequency in Hz, or null if nothing was sung.
  ///
  /// [pcm16] is little-endian mono 16-bit, as the recorder streams it.
  static double? detect(Uint8List pcm16, {required int sampleRate}) {
    final samples = _toFloat(pcm16);
    if (samples.length < 2) return null;

    // Silence and noise are rejected before any correlation work.
    var energy = 0.0;
    for (final s in samples) {
      energy += s * s;
    }
    final rms = math.sqrt(energy / samples.length);
    if (rms < _minRms) return null;

    final minLag = (sampleRate / maxHz).floor();
    final maxLag = math.min((sampleRate / minHz).ceil(), samples.length ~/ 2);
    if (maxLag <= minLag) return null;

    // Normalising by both windows keeps each score a similarity in 0..1
    // rather than something that simply shrinks as the lag grows.
    final scores = Float64List(maxLag + 2);
    var strongest = 0.0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      var sum = 0.0;
      var normA = 0.0;
      var normB = 0.0;
      final n = samples.length - lag;
      for (var i = 0; i < n; i++) {
        final a = samples[i];
        final b = samples[i + lag];
        sum += a * b;
        normA += a * a;
        normB += b * b;
      }
      if (normA <= 0 || normB <= 0) continue;
      final score = sum / math.sqrt(normA * normB);
      scores[lag] = score;
      if (score > strongest) strongest = score;
    }

    if (strongest < _minClarity) return null;

    // Take the *first* strong peak, not the strongest one.
    //
    // A signal that repeats every T also repeats every 2T and 3T, and those
    // longer lags score just as highly — often a hair higher. Picking the
    // global maximum therefore reports a note an octave or a twelfth too low,
    // which is what this did before: 220 Hz came back as 73. The lowest lag
    // that is within [_peakTolerance] of the best score is the fundamental.
    final floor = strongest * _peakTolerance;
    var chosen = -1;
    for (var lag = minLag + 1; lag < maxLag; lag++) {
      final here = scores[lag];
      if (here >= floor && here > scores[lag - 1] && here >= scores[lag + 1]) {
        chosen = lag;
        break;
      }
    }
    if (chosen < 0) return null;

    // Parabolic interpolation across the peak. Without it the reported pitch
    // can only land on frequencies the lag grid allows, which at the top of
    // the range is a step of well over a semitone — enough to tell someone
    // they are flat when they are not.
    final prev = scores[chosen - 1];
    final here = scores[chosen];
    final next = scores[chosen + 1];
    final denom = 2 * (2 * here - prev - next);
    final shift = denom == 0 ? 0.0 : ((next - prev) / denom).clamp(-0.5, 0.5);

    final hz = sampleRate / (chosen + shift);
    return (hz >= minHz && hz <= maxHz) ? hz : null;
  }

  /// How close to the best score a peak must be to be accepted as the
  /// fundamental. Loose enough that the true period wins over its own
  /// multiples, tight enough that a harmonic at half the period does not.
  static const _peakTolerance = 0.88;

  static Float64List _toFloat(Uint8List pcm16) {
    final count = pcm16.length ~/ 2;
    final view = ByteData.sublistView(pcm16);
    final out = Float64List(count);
    for (var i = 0; i < count; i++) {
      out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  /// Semitones from [from] to [to]. Positive means [to] is higher.
  ///
  /// Comparison happens in semitones, never in Hz: pitch is heard
  /// logarithmically, so being 20 Hz out matters enormously down low and is
  /// inaudible up high. A learner singing an octave below the recording is
  /// singing it correctly, which is why [inTune] folds octaves away.
  static double semitonesBetween(double from, double to) =>
      12 * (math.log(to / from) / math.ln2);

  /// Whether two pitches are the same note, ignoring which octave.
  ///
  /// [toleranceSemitones] defaults to a quarter tone either way — the point at
  /// which a listener starts to hear a note as out of tune.
  static bool inTune(
    double sung,
    double target, {
    double toleranceSemitones = 0.5,
  }) {
    if (sung <= 0 || target <= 0) return false;
    var diff = semitonesBetween(target, sung) % 12;
    if (diff < 0) diff += 12;
    // Fold to the nearest octave: 11.7 semitones sharp is 0.3 flat.
    final off = math.min(diff, 12 - diff);
    return off <= toleranceSemitones;
  }
}
