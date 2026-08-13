import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voix/data/services/realtime_voice_service.dart';

/// The two live-call providers speak completely different WebSocket protocols,
/// and a mistake in either is close to invisible: the call connects, the
/// microphone light comes on, and nothing is ever transcribed. These tests pin
/// the parts that decide whether the call works at all.
void main() {
  // The service builds an AudioRecorder eagerly, which reaches for a platform
  // channel the moment it is constructed.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('session negotiation', () {
    test('an ElevenLabs session carries a signed URL and 16 kHz', () {
      final s = RealtimeVoiceService.parseSession({
        'provider': 'elevenlabs',
        'url': 'wss://api.elevenlabs.io/v1/convai/conversation?token=abc',
        'sampleRate': 16000,
      });

      expect(s, isNotNull);
      expect(s!.provider, LiveProvider.elevenLabs);
      expect(s.sampleRate, 16000);
      expect(s.url, contains('elevenlabs'));
    });

    test('an OpenAI session carries a token, a model and 24 kHz', () {
      final s = RealtimeVoiceService.parseSession({
        'provider': 'openai',
        'token': 'ek_123',
        'model': 'gpt-realtime',
        'sampleRate': 24000,
      });

      expect(s!.provider, LiveProvider.openAi);
      expect(s.sampleRate, 24000);
      expect(s.token, 'ek_123');
    });

    test('a backend older than the provider field is still understood', () {
      // It only ever spoke OpenAI, and said so by sending a token and a model.
      final s = RealtimeVoiceService.parseSession({
        'token': 'ek_123',
        'model': 'gpt-realtime',
      });

      expect(s!.provider, LiveProvider.openAi);
      // The rate has to be inferred too, and inferring it wrongly is chipmunk
      // audio rather than an error, which is why it is worth a test.
      expect(s.sampleRate, 24000);
    });

    test('a session missing the field its provider needs is rejected', () {
      // Rejected rather than half-started: connecting to a null URL throws
      // somewhere far from the cause.
      expect(
        RealtimeVoiceService.parseSession({'provider': 'elevenlabs'}),
        isNull,
      );
      expect(
        RealtimeVoiceService.parseSession({
          'provider': 'openai',
          'token': 'ek_123',
        }),
        isNull,
        reason: 'a token without a model cannot open a socket',
      );
    });
  });

  group('ElevenLabs agent events', () {
    late RealtimeVoiceService service;

    setUp(() => service = RealtimeVoiceService(provider: LiveProvider.elevenLabs));
    tearDown(() => service.dispose());

    test('a learner turn becomes the transcript and the tutor starts thinking',
        () {
      service.handleAgentEvent({
        'type': 'user_transcript',
        'user_transcription_event': {'user_transcript': 'I go to market'},
      });

      expect(service.learnerTranscript.value, 'I go to market');
      expect(service.state.value, VoiceCallState.thinking);
    });

    test('a tutor turn is recorded as a completed exchange', () async {
      final exchanges = service.exchanges.toList();

      service
        ..handleAgentEvent({
          'type': 'user_transcript',
          'user_transcription_event': {'user_transcript': 'I go to market'},
        })
        ..handleAgentEvent({
          'type': 'agent_response',
          'agent_response_event': {
            'agent_response': 'I went to the market. What did you buy?',
          },
        });

      await service.closeExchanges();
      final recorded = await exchanges;

      expect(recorded, hasLength(1));
      expect(recorded.single.learner, 'I go to market');
      expect(recorded.single.tutor, startsWith('I went to the market'));
    });

    test('a correction replaces the tutor text without a second exchange',
        () async {
      final exchanges = service.exchanges.toList();

      service
        ..handleAgentEvent({
          'type': 'agent_response',
          'agent_response_event': {'agent_response': 'Tell me about your day'},
        })
        ..handleAgentEvent({
          'type': 'agent_response_correction',
          'agent_response_correction_event': {
            'corrected_agent_response': 'Tell me about—',
          },
        });

      await service.closeExchanges();

      expect(service.tutorTranscript.value, 'Tell me about—');
      expect(
        await exchanges,
        hasLength(1),
        reason: 'the correction revises the turn, it is not a new one',
      );
    });

    test('an interruption stops the tutor and hands the turn back', () {
      service
        ..handleAgentEvent({
          'type': 'audio',
          'audio_event': {'audio_base_64': ''},
        })
        ..handleAgentEvent({
          'type': 'interruption',
          'interruption_event': {'event_id': 3},
        });

      expect(service.state.value, VoiceCallState.listening);
    });

    test('an unknown event is ignored rather than failing the call', () {
      // ElevenLabs adds event types over time; an app that treats an unfamiliar
      // one as an error would drop calls the day they ship a feature.
      service.handleAgentEvent({'type': 'vad_score', 'vad_score_event': {}});
      expect(service.state.value, VoiceCallState.idle);
    });
  });

  group('loudness', () {
    test('silence does not move the orb', () {
      expect(RealtimeVoiceService.loudnessOf(Uint8List(320)), 0);
    });

    test('a loud chunk pins it', () {
      final loud = Uint8List(320);
      final view = ByteData.sublistView(loud);
      for (var i = 0; i < 160; i++) {
        view.setInt16(i * 2, i.isEven ? 20000 : -20000, Endian.little);
      }
      expect(RealtimeVoiceService.loudnessOf(loud), greaterThan(0.9));
    });
  });
}
