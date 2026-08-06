import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/user_profile.dart';

/// Why speech input is unavailable, so the UI can say something useful
/// instead of silently doing nothing.
enum SpeechUnavailableReason { none, permissionDenied, noRecogniser, error }

/// Wraps speech-to-text and text-to-speech behind one small surface.
///
/// Every platform call is guarded: on an emulator without a recogniser, or
/// when the learner declines the mic permission, the service reports
/// unavailable and the conversation screen falls back to typed input rather
/// than the feature becoming unreachable.
class SpeechService {
  SpeechService();

  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  SpeechUnavailableReason _reason = SpeechUnavailableReason.none;

  bool get isAvailable => _sttReady;
  SpeechUnavailableReason get unavailableReason => _reason;
  bool get isListening => _stt.isListening;

  /// Live partial transcript while listening.
  final ValueNotifier<String> transcript = ValueNotifier('');

  /// Smoothed 0→1 input level, consumed by the orb and the waveform.
  final ValueNotifier<double> amplitude = ValueNotifier(0);

  /// True while the tutor's voice is playing.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  Completer<void>? _speechDone;

  // ── Setup ──────────────────────────────────────────────────────────────
  Future<bool> initSpeech() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          _reason = e.errorMsg.contains('permission')
              ? SpeechUnavailableReason.permissionDenied
              : SpeechUnavailableReason.error;
          amplitude.value = 0;
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            amplitude.value = 0;
          }
        },
      );
      if (!_sttReady) _reason = SpeechUnavailableReason.noRecogniser;
    } catch (e) {
      debugPrint('SpeechService.initSpeech failed: $e');
      _sttReady = false;
      _reason = SpeechUnavailableReason.error;
    }
    return _sttReady;
  }

  Future<void> initTts({
    TutorVoice voice = TutorVoice.male,
    String locale = 'en-US',
  }) async {
    try {
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.46); // Slower than default — this is a tutor.
      await _tts.setVolume(1.0);
      // Pitch is the only cross-platform lever that reliably differentiates a
      // masculine from a feminine voice without shipping voice packs.
      await _tts.setPitch(voice == TutorVoice.male ? 0.92 : 1.14);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() {
        speaking.value = false;
        _speechDone?.complete();
        _speechDone = null;
      });
      _tts.setCancelHandler(() {
        speaking.value = false;
        _speechDone?.complete();
        _speechDone = null;
      });
      _tts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
        speaking.value = false;
        _speechDone?.complete();
        _speechDone = null;
      });
      _ttsReady = true;
    } catch (e) {
      debugPrint('SpeechService.initTts failed: $e');
      _ttsReady = false;
    }
  }

  // ── Listening ──────────────────────────────────────────────────────────
  Future<bool> startListening({
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 45),
    Duration pauseFor = const Duration(seconds: 4),
    void Function(String finalText)? onResult,
  }) async {
    if (!await initSpeech()) return false;
    if (_stt.isListening) return true;

    // The tutor must not talk over the learner.
    await stopSpeaking();
    transcript.value = '';

    try {
      await _stt.listen(
        onSoundLevelChange: (level) {
          // Android reports roughly -2..10 dB here; normalise to 0..1.
          amplitude.value = ((level + 2) / 12).clamp(0.0, 1.0);
        },
        onResult: (result) {
          transcript.value = result.recognizedWords;
          if (result.finalResult) {
            amplitude.value = 0;
            onResult?.call(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('SpeechService.startListening failed: $e');
      _reason = SpeechUnavailableReason.error;
      return false;
    }
  }

  Future<String> stopListening() async {
    final text = transcript.value;
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('SpeechService.stopListening failed: $e');
    }
    amplitude.value = 0;
    return text;
  }

  Future<void> cancelListening() async {
    try {
      await _stt.cancel();
    } catch (_) {
      // Cancelling a recogniser that is already stopped is not an error.
    }
    transcript.value = '';
    amplitude.value = 0;
  }

  // ── Speaking ───────────────────────────────────────────────────────────
  /// Speaks [text] and completes when playback finishes (or immediately if
  /// TTS is unavailable, so callers never hang).
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_ttsReady) await initTts();
    if (!_ttsReady) return;

    await stopSpeaking();
    _speechDone = Completer<void>();
    try {
      // Strip the parenthetical slang asides — they read well but sound
      // clumsy when spoken aloud.
      final spoken = text.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      await _tts.speak(spoken.isEmpty ? text : spoken);
      await _speechDone?.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('SpeechService.speak failed: $e');
      speaking.value = false;
      _speechDone = null;
    }
  }

  Future<void> stopSpeaking() async {
    if (!_ttsReady) return;
    try {
      await _tts.stop();
    } catch (_) {
      // Stopping idle TTS is a no-op on most platforms but throws on some.
    }
    speaking.value = false;
    _speechDone?.complete();
    _speechDone = null;
  }

  void dispose() {
    cancelListening();
    stopSpeaking();
    transcript.dispose();
    amplitude.dispose();
    speaking.dispose();
  }
}
