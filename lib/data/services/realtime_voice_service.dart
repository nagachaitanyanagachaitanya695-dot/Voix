import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/backend_config.dart';
import '../models/user_profile.dart';

/// Where a live voice call is in its lifecycle.
enum VoiceCallState {
  idle,
  connecting,
  /// Connected, microphone open, waiting for the learner to speak.
  listening,
  /// The learner has stopped; the tutor is composing a reply.
  thinking,
  /// The tutor is talking.
  speaking,
  failed,
}

/// Why a call could not start, phrased for the learner rather than the log.
enum VoiceCallError {
  none,
  notConfigured,
  microphoneDenied,
  budgetExceeded,
  network,
  unknown,
}

/// One completed exchange, emitted when the tutor finishes a turn.
@immutable
class VoiceExchange {
  const VoiceExchange({required this.learner, required this.tutor});
  final String learner;
  final String tutor;
}

/// Live speech-to-speech conversation with the tutor.
///
/// The learner speaks, the tutor answers out loud, and either can interrupt —
/// no press-to-talk, no waiting for a transcript. Audio streams both ways over
/// a WebSocket to OpenAI's Realtime API.
///
/// **This costs real money per minute of audio, in both directions.** It is
/// opt-in for that reason, and the backend enforces a daily cap per device. The
/// free path — the phone's own recogniser plus [SpeechService] — remains the
/// default and works with no backend at all.
///
/// The app never holds an API key. It asks the backend for a credential that
/// expires in about a minute and connects with that; see `backend/README.md`.
class RealtimeVoiceService {
  RealtimeVoiceService({
    AudioRecorder? recorder,
    http.Client? httpClient,
  })  : _recorder = recorder ?? AudioRecorder(),
        _http = httpClient ?? http.Client();

  final AudioRecorder _recorder;
  final http.Client _http;

  /// 24 kHz mono PCM16 — what the Realtime API expects in both directions.
  /// Changing this silently produces chipmunk audio rather than an error.
  static const _sampleRate = 24000;

  final state = ValueNotifier(VoiceCallState.idle);

  /// What the learner is saying, updated as they speak.
  final learnerTranscript = ValueNotifier('');

  /// What the tutor is saying, updated as it speaks.
  final tutorTranscript = ValueNotifier('');

  /// 0–1 microphone loudness, for the animated orb.
  final amplitude = ValueNotifier(0.0);

  VoiceCallError _error = VoiceCallError.none;
  VoiceCallError get error => _error;

  /// Emits once per completed exchange, so the transcript and the
  /// end-of-session report can be built from real turns.
  Stream<VoiceExchange> get exchanges => _exchanges.stream;
  final _exchanges = StreamController<VoiceExchange>.broadcast();

  WebSocketChannel? _socket;
  StreamSubscription<Uint8List>? _mic;
  StreamSubscription<dynamic>? _events;
  bool _pcmReady = false;

  /// Set when the learner talks over the tutor, cleared when the next response
  /// begins. See [_suppressPlayback].
  bool _interrupted = false;

  // Accumulates the in-progress turn so a completed exchange can be emitted.
  final _learnerBuffer = StringBuffer();
  final _tutorBuffer = StringBuffer();

  bool get isActive =>
      state.value != VoiceCallState.idle && state.value != VoiceCallState.failed;

  /// Opens a live call. Returns false and sets [error] if it could not start.
  Future<bool> start({
    required UserProfile user,
    required String scenarioTitle,
    required String deviceId,
  }) async {
    if (isActive) return true;
    _error = VoiceCallError.none;

    if (!BackendConfig.isConfigured) {
      _fail(VoiceCallError.notConfigured);
      return false;
    }

    state.value = VoiceCallState.connecting;

    if (!await _recorder.hasPermission()) {
      _fail(VoiceCallError.microphoneDenied);
      return false;
    }

    final token = await _mintToken(
      user: user,
      scenarioTitle: scenarioTitle,
      deviceId: deviceId,
    );
    if (token == null) return false;

    try {
      await _connect(token.token, token.model);
      await _startAudio();
      state.value = VoiceCallState.listening;
      return true;
    } catch (e) {
      debugPrint('RealtimeVoiceService: start failed ($e)');
      await stop();
      _fail(VoiceCallError.network);
      return false;
    }
  }

  /// Ends the call and releases the microphone and speaker.
  ///
  /// Safe to call at any point, including twice — the screen calls it from
  /// dispose, and an in-flight failure may already have torn things down.
  Future<void> stop() async {
    await _mic?.cancel();
    _mic = null;

    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (e) {
      debugPrint('RealtimeVoiceService: recorder stop failed ($e)');
    }

    await _events?.cancel();
    _events = null;

    try {
      await _socket?.sink.close();
    } catch (e) {
      debugPrint('RealtimeVoiceService: socket close failed ($e)');
    }
    _socket = null;

    if (_pcmReady) {
      try {
        await FlutterPcmSound.release();
      } catch (e) {
        debugPrint('RealtimeVoiceService: pcm release failed ($e)');
      }
      _pcmReady = false;
    }

    amplitude.value = 0;
    if (state.value != VoiceCallState.failed) state.value = VoiceCallState.idle;
  }

  void dispose() {
    unawaited(stop());
    _exchanges.close();
    state.dispose();
    learnerTranscript.dispose();
    tutorTranscript.dispose();
    amplitude.dispose();
    _http.close();
  }

  // ── Setup ──────────────────────────────────────────────────────────────

  Future<({String token, String model})?> _mintToken({
    required UserProfile user,
    required String scenarioTitle,
    required String deviceId,
  }) async {
    try {
      final response = await _http
          .post(
            BackendConfig.sessionUrl,
            headers: {
              'Content-Type': 'application/json',
              'x-voix-app-token': BackendConfig.appToken,
              'x-voix-device': deviceId,
            },
            body: jsonEncode({
              'userId': user.id,
              'level': user.proficiency.name,
              'nativeLanguage': user.nativeLanguageCode,
              'scenario': scenarioTitle,
              'mode': user.mode.name,
              'voice': user.tutorVoice.name,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 429) {
        _fail(VoiceCallError.budgetExceeded);
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('RealtimeVoiceService: session ${response.statusCode} '
            '${response.body}');
        _fail(VoiceCallError.network);
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final model = data['model'] as String?;
      if (token == null || token.isEmpty || model == null || model.isEmpty) {
        _fail(VoiceCallError.unknown);
        return null;
      }
      return (token: token, model: model);
    } on TimeoutException {
      _fail(VoiceCallError.network);
      return null;
    } catch (e) {
      debugPrint('RealtimeVoiceService: token request failed ($e)');
      _fail(VoiceCallError.network);
      return null;
    }
  }

  Future<void> _connect(String token, String model) async {
    _socket = WebSocketChannel.connect(
      Uri.parse('wss://api.openai.com/v1/realtime?model=$model'),
      // The ephemeral credential travels as a subprotocol rather than a header,
      // because the WebSocket handshake has no place for an Authorization
      // header in most client stacks.
      protocols: ['realtime', 'openai-insecure-api-key.$token'],
    );
    await _socket!.ready.timeout(const Duration(seconds: 15));

    _events = _socket!.stream.listen(
      _onEvent,
      onError: (Object e) {
        debugPrint('RealtimeVoiceService: socket error ($e)');
        _fail(VoiceCallError.network);
        unawaited(stop());
      },
      onDone: () {
        if (isActive) unawaited(stop());
      },
    );
  }

  Future<void> _startAudio() async {
    await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: 1);
    _pcmReady = true;

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        // Without echo cancellation the microphone picks up the tutor's own
        // voice from the speaker, the server treats that as the learner
        // talking, and the call collapses into the tutor interrupting itself.
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
    );

    _mic = stream.listen(
      (chunk) {
        amplitude.value = _loudness(chunk);
        final socket = _socket;
        if (socket == null) return;
        socket.sink.add(
          jsonEncode({
            'type': 'input_audio_buffer.append',
            'audio': base64Encode(chunk),
          }),
        );
      },
      onError: (Object e) {
        debugPrint('RealtimeVoiceService: mic error ($e)');
        _fail(VoiceCallError.unknown);
        unawaited(stop());
      },
    );
  }

  // ── Events ─────────────────────────────────────────────────────────────

  void _onEvent(dynamic raw) {
    if (raw is! String) return;
    final Map<String, dynamic> event;
    try {
      event = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final type = event['type'] as String? ?? '';

    // Event names have moved between API revisions (`response.audio.delta`
    // became `response.output_audio.delta`). Matching on the suffix keeps this
    // working across both rather than going silent after an upgrade.
    switch (type) {
      case 'session.created':
      case 'session.updated':
        return;

      // ── The tutor's voice ────────────────────────────────────────────
      case 'response.output_audio.delta':
      case 'response.audio.delta':
        if (_interrupted) return;
        _play(event['delta'] as String?);
        if (state.value != VoiceCallState.speaking) {
          state.value = VoiceCallState.speaking;
        }
        return;

      case 'response.created':
        _interrupted = false;
        return;

      // ── The tutor's words ────────────────────────────────────────────
      case 'response.output_audio_transcript.delta':
      case 'response.audio_transcript.delta':
        final delta = event['delta'] as String? ?? '';
        _tutorBuffer.write(delta);
        tutorTranscript.value = _tutorBuffer.toString();
        return;

      // ── The learner's words ──────────────────────────────────────────
      case 'conversation.item.input_audio_transcription.delta':
        _learnerBuffer.write(event['delta'] as String? ?? '');
        learnerTranscript.value = _learnerBuffer.toString();
        return;

      case 'conversation.item.input_audio_transcription.completed':
        final full = event['transcript'] as String?;
        if (full != null && full.isNotEmpty) {
          _learnerBuffer
            ..clear()
            ..write(full);
          learnerTranscript.value = full;
        }
        return;

      // ── Turn boundaries ──────────────────────────────────────────────
      case 'input_audio_buffer.speech_started':
        // The learner cut in, so stop adding to the tutor's audio — otherwise
        // it keeps talking over them for another second or two.
        _suppressPlayback();
        state.value = VoiceCallState.listening;
        return;

      case 'input_audio_buffer.speech_stopped':
        state.value = VoiceCallState.thinking;
        return;

      case 'response.done':
        _emitExchange();
        state.value = VoiceCallState.listening;
        return;

      case 'error':
        final message =
            (event['error'] as Map<String, dynamic>?)?['message'] as String?;
        debugPrint('RealtimeVoiceService: server error — $message');
        _fail(VoiceCallError.unknown);
        unawaited(stop());
        return;

      default:
        return;
    }
  }

  void _emitExchange() {
    final learner = _learnerBuffer.toString().trim();
    final tutor = _tutorBuffer.toString().trim();
    if (tutor.isNotEmpty) {
      _exchanges.add(VoiceExchange(learner: learner, tutor: tutor));
    }
    _learnerBuffer.clear();
    _tutorBuffer.clear();
  }

  void _play(String? base64Audio) {
    if (base64Audio == null || base64Audio.isEmpty || !_pcmReady) return;
    try {
      final bytes = base64Decode(base64Audio);
      // The payload is already little-endian PCM16, so this is a view over the
      // same memory rather than a per-sample conversion.
      unawaited(
        FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(bytes))),
      );
    } catch (e) {
      debugPrint('RealtimeVoiceService: playback failed ($e)');
    }
  }

  /// Stops feeding the speaker for the turn the learner just cut into.
  ///
  /// The plugin has no way to drop audio already queued, so the last fraction
  /// of a second still plays out. Since deltas are fed as they arrive rather
  /// than buffered up front, that tail is short — short enough to read as a
  /// person trailing off when interrupted, which is what we want anyway.
  void _suppressPlayback() => _interrupted = true;

  void _fail(VoiceCallError reason) {
    _error = reason;
    state.value = VoiceCallState.failed;
  }

  /// Rough RMS loudness of a PCM16 chunk, normalised to 0–1 for the orb.
  @visibleForTesting
  static double loudnessOf(Uint8List pcm16) => _loudness(pcm16);

  static double _loudness(Uint8List pcm16) {
    if (pcm16.length < 2) return 0;
    final samples = ByteData.sublistView(pcm16);
    var sum = 0.0;
    final count = pcm16.length ~/ 2;
    // Every 8th sample is plenty for a visual meter and keeps this off the
    // frame budget on a long call.
    for (var i = 0; i < count; i += 8) {
      final s = samples.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final considered = (count / 8).ceil();
    if (considered <= 0) return 0;
    final rms = math.sqrt(sum / considered);
    // Speech sits well below full scale, so scale up before clamping or the
    // orb barely moves.
    return (rms * 3.2).clamp(0.0, 1.0);
  }
}
