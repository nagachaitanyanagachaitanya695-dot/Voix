import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/energy_orb.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/voix_button.dart';
import '../../data/models/conversation.dart';
import '../../data/services/realtime_voice_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';

/// A live, spoken conversation with the tutor.
///
/// Unlike the main conversation screen there is no send button and no typing:
/// the learner just talks, and the tutor talks back. Either can interrupt.
///
/// Kept as its own screen rather than a mode inside the existing conversation
/// flow — the two have almost nothing in common mechanically, and folding live
/// audio into a screen that already works would put the free path at risk for
/// no gain.
class LiveCallScreen extends ConsumerStatefulWidget {
  const LiveCallScreen({super.key, required this.scenario});

  final Scenario scenario;

  @override
  ConsumerState<LiveCallScreen> createState() => _LiveCallScreenState();
}

class _LiveCallScreenState extends ConsumerState<LiveCallScreen> {
  late final RealtimeVoiceService _voice;
  StreamSubscription<VoiceExchange>? _exchangeSub;

  final _exchanges = <VoiceExchange>[];
  DateTime? _startedAt;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(realtimeVoiceProvider);
    _exchangeSub = _voice.exchanges.listen((e) {
      if (mounted) setState(() => _exchanges.add(e));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    _exchangeSub?.cancel();
    // The provider is autoDispose and owns teardown, but the microphone must
    // be released the moment this screen goes away — not whenever the provider
    // happens to be collected.
    unawaited(_voice.stop());
    super.dispose();
  }

  Future<void> _connect() async {
    final user = ref.read(userControllerProvider);
    if (user == null) return;

    final started = await _voice.start(
      user: user,
      scenarioTitle: widget.scenario.title,
      deviceId: ref.read(deviceIdProvider),
    );
    if (started) {
      _startedAt = DateTime.now();
      Haptic.success();
    } else {
      Haptic.error();
    }
    if (mounted) setState(() {});
  }

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);

    final navigator = Navigator.of(context);
    await _voice.stop();

    // Credit the practice, but only for a call that actually happened —
    // a connection that failed after two seconds is not a lesson.
    final startedAt = _startedAt;
    if (startedAt != null && _exchanges.isNotEmpty) {
      final minutes = DateTime.now().difference(startedAt).inSeconds ~/ 60;
      await ref.read(userControllerProvider.notifier).registerPractice(
            PracticeOutcome(
              xpEarned: 20 + _exchanges.length * 5,
              minutes: minutes.clamp(1, 120),
              conversations: 1,
            ),
          );
    }

    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return PopScope(
      // Leaving must go through _end so the microphone is released and the
      // practice is credited; a bare back gesture would skip both.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_end());
      },
      child: Scaffold(
        body: AuroraBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
              child: Column(
                children: [
                  _header(c),
                  Expanded(
                    child: ValueListenableBuilder<VoiceCallState>(
                      valueListenable: _voice.state,
                      builder: (context, state, _) => state ==
                              VoiceCallState.failed
                          ? _failure(c)
                          : _live(c, state),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.lg, top: Gap.md),
                    child: VoixButton(
                      label: _ending ? 'Ending…' : 'End call',
                      icon: Icons.call_end_rounded,
                      variant: VoixButtonVariant.danger,
                      loading: _ending,
                      onPressed: _end,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(VoixColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      child: Row(
        children: [
          Pressable(
            onTap: _end,
            child: Padding(
              padding: const EdgeInsets.all(Gap.xxs),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: c.textSecondary),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.scenario.title,
                    style: context.text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Live conversation',
                    style: context.text.labelSmall
                        ?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          Text(widget.scenario.emoji, style: const TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  Widget _live(VoixColors c, VoiceCallState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _voice.amplitude,
          builder: (context, amplitude, _) => EnergyOrb(
            size: 200,
            // The orb belongs to whoever is talking: it tracks the learner's
            // voice while listening, and pulses on its own while the tutor
            // speaks, so who has the floor is obvious without reading anything.
            amplitude: state == VoiceCallState.speaking ? 0.65 : amplitude,
            energy: state == VoiceCallState.connecting ? 0.4 : 1.0,
            colors: switch (state) {
              VoiceCallState.speaking => const [
                  VoixPalette.violet,
                  VoixPalette.magenta,
                  VoixPalette.violet,
                ],
              _ => const [
                  VoixPalette.cyan,
                  VoixPalette.blue,
                  VoixPalette.violet,
                ],
            },
          ),
        ),
        Gap.h24,
        Text(
          switch (state) {
            VoiceCallState.connecting => 'Connecting…',
            VoiceCallState.listening => 'Listening — just start talking',
            VoiceCallState.thinking => 'Thinking…',
            VoiceCallState.speaking => 'Speaking',
            _ => '',
          },
          style: context.text.titleSmall?.copyWith(color: c.textSecondary),
        ),
        Gap.h20,
        Expanded(child: _transcript(c, state)),
      ],
    );
  }

  Widget _transcript(VoixColors c, VoiceCallState state) {
    return ValueListenableBuilder<String>(
      valueListenable: _voice.tutorTranscript,
      builder: (context, tutor, _) => ValueListenableBuilder<String>(
        valueListenable: _voice.learnerTranscript,
        builder: (context, learner, _) {
          // Only the turn in progress. A live call is meant to be listened to,
          // not read; the full transcript is on the results screen afterwards.
          final showing = state == VoiceCallState.speaking ? tutor : learner;
          final isTutor = state == VoiceCallState.speaking;

          return SingleChildScrollView(
            reverse: true,
            child: Column(
              children: [
                if (showing.isNotEmpty)
                  Text(
                    showing,
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(
                      height: 1.5,
                      color: isTutor ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                if (showing.isEmpty && _exchanges.isEmpty)
                  Text(
                    'Say hello to begin.',
                    style: context.text.bodyMedium
                        ?.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _failure(VoixColors c) {
    final (title, detail) = switch (_voice.error) {
      VoiceCallError.notConfigured => (
          'Live voice is not set up',
          'This build has no backend configured, so live conversation is '
              'unavailable. The normal practice mode still works.',
        ),
      VoiceCallError.microphoneDenied => (
          'Microphone permission needed',
          'Voix needs the microphone to hear you. You can turn it on in your '
              'phone\'s app settings.',
        ),
      VoiceCallError.budgetExceeded => (
          'That\'s your live practice for today',
          'You have used today\'s live voice sessions. They reset tomorrow — '
              'and the normal practice mode is still available now.',
        ),
      VoiceCallError.network => (
          'Could not connect',
          'Check your internet connection and try again.',
        ),
      _ => (
          'Something went wrong',
          'The call could not be started. Please try again.',
        ),
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_off_rounded, size: 44, color: c.textSecondary),
          Gap.h20,
          Text(title,
              style: context.text.titleMedium, textAlign: TextAlign.center),
          Gap.h8,
          Text(
            detail,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: c.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
