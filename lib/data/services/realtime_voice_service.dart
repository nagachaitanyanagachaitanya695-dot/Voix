import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/backend_config.dart';
import '../models/language.dart';
import '../models/user_profile.dart';

/// Which service is carrying the call.
///
/// The backend decides and tells the app, so the provider can be swapped by
/// changing a secret rather than shipping a new APK. The two speak entirely
/// different WebSocket protocols; everything above this file is unaffected.
enum LiveProvider {
  /// ElevenLabs Agents. Turn-taking, transcription and the voice belong to the
  /// agent, configured in the ElevenLabs dashboard.
  elevenLabs,

  /// OpenAI Realtime. The teaching prompt is sent by our backend at mint time.
  openAi,
}

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

  /// The server does not consider this account a subscriber. Reachable even
  /// though the UI gates on `isPro`, because the server is the real authority
  /// — an expired subscription, or an edited APK, both land here.
  notSubscribed,

  budgetExceeded,
  network,
  unknown,
}

/// What the backend handed back for one call.
///
/// Parsed defensively: a backend that has been redeployed with a different
/// provider, or an older one that predates the `provider` field, must not
/// crash the call — it should either work or fail cleanly.
@immutable
class LiveSession {
  const LiveSession({
    required this.provider,
    required this.sampleRate,
    this.token,
    this.model,
    this.url,
  });

  final LiveProvider provider;
  final int sampleRate;
  final String? token;
  final String? model;
  final String? url;

  /// Returns null if the response cannot start a call.
  static LiveSession? parse(Map<String, dynamic> data) {
    final url = data['url'] as String?;
    final token = data['token'] as String?;
    final model = data['model'] as String?;

    // A backend deployed before this field existed only ever spoke OpenAI, and
    // said so by sending a token and a model.
    final provider = switch (data['provider'] as String?) {
      'elevenlabs' => LiveProvider.elevenLabs,
      'openai' => LiveProvider.openAi,
      _ => url != null ? LiveProvider.elevenLabs : LiveProvider.openAi,
    };

    final rate = (data['sampleRate'] as num?)?.toInt() ??
        (provider == LiveProvider.elevenLabs ? 16000 : 24000);

    switch (provider) {
      case LiveProvider.elevenLabs:
        if (url == null || url.isEmpty) return null;
      case LiveProvider.openAi:
        if (token == null || token.isEmpty) return null;
        if (model == null || model.isEmpty) return null;
    }

    return LiveSession(
      provider: provider,
      sampleRate: rate,
      token: token,
      model: model,
      url: url,
    );
  }
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
    @visibleForTesting LiveProvider? provider,
  })  : _injectedRecorder = recorder,
        _http = httpClient ?? http.Client(),
        _provider = provider ?? LiveProvider.openAi;

  /// Reads a `/v1/session` response. Exposed because getting this wrong shows
  /// up as a call that connects and then transcribes nothing.
  @visibleForTesting
  static LiveSession? parseSession(Map<String, dynamic> data) =>
      LiveSession.parse(data);

  final AudioRecorder? _injectedRecorder;
  AudioRecorder? _ownRecorder;

  /// Built on first use, not in the constructor: constructing an
  /// [AudioRecorder] opens a platform channel, so an eager one would reach for
  /// the microphone plugin merely because the screen was built.
  AudioRecorder get _recorder =>
      _injectedRecorder ?? (_ownRecorder ??= AudioRecorder());

  /// Whether the microphone was ever actually opened. Guards teardown so
  /// [stop] does not make platform calls for a call that never began.
  bool _audioStarted = false;

  final http.Client _http;

  /// Mono PCM16 rate for both directions, told to us by the backend because it
  /// differs per provider (24 kHz for OpenAI, 16 kHz for the ElevenLabs
  /// agent). Getting this wrong does not raise an error — it produces
  /// chipmunk audio — so it is never guessed.
  int _sampleRate = 24000;

  LiveProvider _provider;

  /// Which service carried the last call. Exposed for diagnostics only; no UI
  /// depends on it, because the learner should not have to care.
  LiveProvider get provider => _provider;

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

  /// Fires once the tutor's audio has stopped arriving.
  ///
  /// OpenAI marks the end of a turn with `response.done`. The ElevenLabs agent
  /// has no equivalent event — audio simply stops — so the only way to know it
  /// has finished speaking is that no chunk has arrived for a moment.
  Timer? _speechTail;
  static const _speechTailGap = Duration(milliseconds: 900);

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

    final session = await _openSession(
      user: user,
      scenarioTitle: scenarioTitle,
      deviceId: deviceId,
    );
    if (session == null) return false;

    _provider = session.provider;
    _sampleRate = session.sampleRate;

    try {
      await _connect(session);
      // The agent needs to know who it is talking to before any audio arrives,
      // so this goes first — the very next frame on the socket is microphone
      // data.
      if (session.provider == LiveProvider.elevenLabs) {
        _sendAgentInitiation(user: user, scenarioTitle: scenarioTitle);
      }
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
    _speechTail?.cancel();
    _speechTail = null;

    await _mic?.cancel();
    _mic = null;

    if (_audioStarted) {
      _audioStarted = false;
      try {
        if (await _recorder.isRecording()) await _recorder.stop();
      } catch (e) {
        debugPrint('RealtimeVoiceService: recorder stop failed ($e)');
      }
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

    // stop() runs past several await points, and dispose() starts it without
    // waiting. By the time control returns here the notifiers may already be
    // gone, and writing to a disposed one throws.
    if (_disposed) return;
    amplitude.value = 0;
    if (state.value != VoiceCallState.failed) state.value = VoiceCallState.idle;
  }

  /// Ends the exchange stream so a listener collecting it can complete.
  @visibleForTesting
  Future<void> closeExchanges() =>
      _exchanges.isClosed ? Future.value() : _exchanges.close();

  bool _disposed = false;

  void dispose() {
    // Set before stopping, so the teardown running behind us knows not to
    // touch the notifiers this method is about to dispose.
    _disposed = true;
    unawaited(stop());
    if (!_exchanges.isClosed) unawaited(_exchanges.close());
    state.dispose();
    learnerTranscript.dispose();
    tutorTranscript.dispose();
    amplitude.dispose();
    _http.close();
  }

  // ── Setup ──────────────────────────────────────────────────────────────

  Future<LiveSession?> _openSession({
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

      if (response.statusCode == 402) {
        _fail(VoiceCallError.notSubscribed);
        return null;
      }
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
      final session = LiveSession.parse(data);
      if (session == null) {
        debugPrint('RealtimeVoiceService: unusable session ${response.body}');
        _fail(VoiceCallError.unknown);
        return null;
      }
      return session;
    } on TimeoutException {
      _fail(VoiceCallError.network);
      return null;
    } catch (e) {
      debugPrint('RealtimeVoiceService: token request failed ($e)');
      _fail(VoiceCallError.network);
      return null;
    }
  }

  Future<void> _connect(LiveSession session) async {
    _socket = switch (session.provider) {
      // The signed URL carries its own authorisation in the query string, so
      // there is nothing to add to the handshake.
      LiveProvider.elevenLabs => WebSocketChannel.connect(Uri.parse(session.url!)),

      // OpenAI's ephemeral credential travels as a subprotocol rather than a
      // header, because the WebSocket handshake has no place for an
      // Authorization header in most client stacks.
      LiveProvider.openAi => WebSocketChannel.connect(
          Uri.parse('wss://api.openai.com/v1/realtime?model=${session.model}'),
          protocols: ['realtime', 'openai-insecure-api-key.${session.token}'],
        ),
    };
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

  /// Tells the ElevenLabs agent who this learner is.
  ///
  /// The teaching prompt lives on the agent and refers to `{{level}}`,
  /// `{{native_language}}` and `{{scenario}}`; these fill them in. One agent
  /// therefore serves every learner — the alternative, an agent per learner,
  /// would be unmanageable and would put the prompt out of reach of anyone
  /// wanting to improve it.
  void _sendAgentInitiation({
    required UserProfile user,
    required String scenarioTitle,
  }) {
    final native = LanguageCatalog.byCode(user.nativeLanguageCode);
    _socket?.sink.add(
      jsonEncode({
        'type': 'conversation_initiation_client_data',
        'dynamic_variables': {
          'level': user.proficiency.name,
          // The readable name, not the code: a prompt reading "their first
          // language is te" teaches the model nothing.
          'native_language': native.name,
          'scenario': scenarioTitle,
        },
      }),
    );
  }

  Future<void> _startAudio() async {
    await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: 1);
    _pcmReady = true;
    _audioStarted = true;

    final stream = await _recorder.startStream(
      RecordConfig(
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
        final audio = base64Encode(chunk);
        socket.sink.add(
          jsonEncode(switch (_provider) {
            LiveProvider.elevenLabs => {'user_audio_chunk': audio},
            LiveProvider.openAi => {
                'type': 'input_audio_buffer.append',
                'audio': audio,
              },
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

    switch (_provider) {
      case LiveProvider.elevenLabs:
        _onAgentEvent(event);
      case LiveProvider.openAi:
        _onRealtimeEvent(event);
    }
  }

  /// ElevenLabs Agents protocol.
  ///
  /// Coarser than OpenAI's: the agent reports a whole turn at a time rather
  /// than streaming deltas of it, and it does not announce when it has
  /// finished speaking — see [_speechTail].
  @visibleForTesting
  void handleAgentEvent(Map<String, dynamic> event) => _onAgentEvent(event);

  void _onAgentEvent(Map<String, dynamic> event) {
    Map<String, dynamic>? payload(String key) =>
        event[key] as Map<String, dynamic>?;

    switch (event['type'] as String? ?? '') {
      case 'conversation_initiation_metadata':
        return;

      // The agent's voice. Each chunk restarts the tail timer, so the call
      // returns to listening a beat after the last one arrives.
      case 'audio':
        if (_interrupted) return;
        _play(payload('audio_event')?['audio_base_64'] as String?);
        state.value = VoiceCallState.speaking;
        _speechTail?.cancel();
        _speechTail = Timer(_speechTailGap, () {
          if (state.value == VoiceCallState.speaking) {
            state.value = VoiceCallState.listening;
          }
        });
        return;

      // A whole turn of the learner's speech, already finalised.
      case 'user_transcript':
        final text =
            payload('user_transcription_event')?['user_transcript'] as String?;
        if (text == null || text.isEmpty) return;
        _learnerBuffer
          ..clear()
          ..write(text);
        learnerTranscript.value = text;
        state.value = VoiceCallState.thinking;
        return;

      // A whole turn of the tutor's, arriving before its audio does.
      case 'agent_response':
        final text = payload('agent_response_event')?['agent_response'] as String?;
        if (text == null || text.isEmpty) return;
        _interrupted = false;
        _tutorBuffer
          ..clear()
          ..write(text);
        tutorTranscript.value = text;
        _emitExchange();
        return;

      // The agent revising what it had said, after the learner cut in — the
      // corrected text is what actually reached them, so it replaces the
      // exchange we already recorded.
      case 'agent_response_correction':
        final text = payload('agent_response_correction_event')?['corrected_agent_response']
            as String?;
        if (text == null || text.isEmpty) return;
        tutorTranscript.value = text;
        return;

      case 'interruption':
        _suppressPlayback();
        state.value = VoiceCallState.listening;
        return;

      // A keepalive. Failing to answer it drops the call after a minute or so.
      case 'ping':
        final id = payload('ping_event')?['event_id'];
        _socket?.sink.add(jsonEncode({'type': 'pong', 'event_id': id}));
        return;

      default:
        return;
    }
  }

  void _onRealtimeEvent(Map<String, dynamic> event) {
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
