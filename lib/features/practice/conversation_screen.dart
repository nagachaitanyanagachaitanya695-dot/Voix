import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/mic_button.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/waveform.dart';
import '../../data/models/conversation.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/speech_service.dart';
import '../../providers/activity_controller.dart';
import '../../providers/app_providers.dart';
import '../../providers/conversation_controller.dart';
import '../../providers/session_controller.dart';
import '../../providers/user_controller.dart';
import 'conversation_summary_screen.dart';
import 'widgets/chat_bubble.dart';

/// The live practice conversation.
///
/// Voice is the primary input; typing is always available as a fallback so a
/// denied mic permission, a noisy room, or a missing recogniser never blocks
/// the core feature.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.scenario});

  final Scenario scenario;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scroll = ScrollController();
  final _textController = TextEditingController();

  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _typingMode = false;
  bool _speechChecked = false;
  bool _voiceReplies = true;

  SpeechService get _speech => ref.read(speechServiceProvider);

  @override
  void initState() {
    super.initState();
    // Deferred to the first frame: `start` mutates a provider, which cannot
    // happen during a build/initState pass.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(conversationControllerProvider.notifier).start(widget.scenario);

      final user = ref.read(userControllerProvider);
      await _speech.initTts(voice: user?.tutorVoice ?? TutorVoice.male);
      final available = await _speech.initSpeech();
      if (!mounted) return;
      setState(() {
        _speechChecked = true;
        _typingMode = !available;
      });

      if (_voiceReplies) {
        await _speech.speak(widget.scenario.openingLine);
      }
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    _textController.dispose();
    // The service is shared, so only the in-flight work is torn down here.
    _speech.cancelListening();
    _speech.stopSpeaking();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.slow,
        curve: Motion.enter,
      );
    });
  }

  // ── Input ──────────────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    final controller = ref.read(conversationControllerProvider.notifier);

    if (_speech.isListening) {
      final text = await _speech.stopListening();
      controller.setListening(false);
      if (text.trim().isNotEmpty) await _submit(text);
      return;
    }

    await _speech.stopSpeaking();
    final user = ref.read(userControllerProvider);
    final started = await _speech.startListening(
      localeId: user?.learningLanguageCode == 'en' ? 'en_US' : 'en_US',
      onResult: (text) async {
        // Auto-submit when the recogniser reports a final result, so the
        // learner does not have to tap stop after every sentence.
        if (!mounted) return;
        controller.setListening(false);
        if (text.trim().isNotEmpty) await _submit(text);
      },
    );

    if (!started) {
      if (!mounted) return;
      setState(() => _typingMode = true);
      _showSpeechUnavailable();
      return;
    }
    controller.setListening(true);
  }

  void _showSpeechUnavailable() {
    final reason = _speech.unavailableReason;
    final message = switch (reason) {
      SpeechUnavailableReason.permissionDenied =>
        'Microphone access is off. Enable it in Settings to speak — '
            'you can keep typing for now.',
      SpeechUnavailableReason.noRecogniser =>
        'No speech recogniser found on this device. Typing works fine.',
      _ => 'Voice input is unavailable right now. You can type instead.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _textController.clear();
    context.hideKeyboard();
    _scrollToEnd();

    await ref.read(conversationControllerProvider.notifier).send(trimmed);
    _scrollToEnd();

    final state = ref.read(conversationControllerProvider);
    final last = state?.messages.isNotEmpty == true ? state!.messages.last : null;
    if (_voiceReplies && last != null && last.speaker == Speaker.tutor) {
      await _speech.speak(last.text);
    }
  }

  // ── Finish ─────────────────────────────────────────────────────────────
  Future<void> _finish() async {
    final state = ref.read(conversationControllerProvider);
    if (state == null) return;

    if (!state.canFinish) {
      Navigator.of(context).pop();
      return;
    }

    await _speech.cancelListening();
    await _speech.stopSpeaking();
    Haptic.medium();

    final session =
        await ref.read(conversationControllerProvider.notifier).finish();
    if (session == null || !mounted) return;

    await ref.read(sessionHistoryProvider.notifier).save(session);

    final minutes = (session.durationSeconds / 60).ceil().clamp(1, 120);
    final reward =
        await ref.read(userControllerProvider.notifier).registerPractice(
              PracticeOutcome(
                xpEarned: session.xpEarned,
                minutes: minutes,
                conversations: 1,
                wordsLearned: session.summary?.vocabulary.length ?? 0,
              ),
            );
    await ref.read(activityControllerProvider.notifier).record(
          minutes: minutes,
          xp: session.xpEarned,
          conversations: 1,
        );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConversationSummaryScreen(
          session: session,
          reward: reward,
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final state = ref.read(conversationControllerProvider);
    if (state == null || state.userTurns == 0) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this conversation?'),
        content: const Text(
          "You'll get your feedback report and keep the XP you earned.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep talking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('End & review'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _finish();
      return false; // _finish handles navigation itself.
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(conversationControllerProvider);
    final listening = _speech.isListening;

    if (state == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Resolved before the await so no BuildContext is held across it.
        final navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) navigator.pop();
      },
      child: Scaffold(
        body: AuroraBackground(
          animate: false,
          child: SafeArea(
            child: Column(
              children: [
                _Header(
                  scenario: widget.scenario,
                  elapsed: _elapsed,
                  voiceReplies: _voiceReplies,
                  onToggleVoice: () async {
                    setState(() => _voiceReplies = !_voiceReplies);
                    if (!_voiceReplies) await _speech.stopSpeaking();
                  },
                  onClose: () async {
                    final navigator = Navigator.of(context);
                    if (await _confirmExit() && mounted) navigator.pop();
                  },
                  onFinish: state.canFinish ? _finish : null,
                ),

                // ── Transcript ────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.sm,
                      Gap.page,
                      Gap.md,
                    ),
                    itemCount: state.messages.length +
                        (state.tutorThinking ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= state.messages.length) {
                        return const TypingBubble();
                      }
                      return ChatBubble(message: state.messages[i]);
                    },
                  ),
                ),

                // ── Starter suggestions ───────────────────────────────
                if (state.userTurns == 0 &&
                    widget.scenario.suggestions.isNotEmpty &&
                    !state.tutorThinking)
                  _Suggestions(
                    suggestions: widget.scenario.suggestions,
                    onTap: _submit,
                  ),

                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                    child: Text(
                      state.error!,
                      style: context.text.bodySmall?.copyWith(color: c.danger),
                    ),
                  ),

                // ── Input ─────────────────────────────────────────────
                _InputBar(
                  typingMode: _typingMode,
                  controller: _textController,
                  listening: listening,
                  enabled: state.inputEnabled,
                  speechAvailable: _speechChecked && _speech.isAvailable,
                  transcript: _speech.transcript,
                  amplitude: _speech.amplitude,
                  onMic: _toggleMic,
                  onSubmit: _submit,
                  onToggleMode: () {
                    setState(() => _typingMode = !_typingMode);
                    if (_typingMode) _speech.cancelListening();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.scenario,
    required this.elapsed,
    required this.onClose,
    required this.voiceReplies,
    required this.onToggleVoice,
    this.onFinish,
  });

  final Scenario scenario;
  final Duration elapsed;
  final VoidCallback onClose;
  final bool voiceReplies;
  final VoidCallback onToggleVoice;
  final VoidCallback? onFinish;

  String get _time {
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, Gap.xs),
      child: Row(
        children: [
          Pressable(
            onTap: onClose,
            scale: 0.9,
            semanticLabel: 'Close conversation',
            child: Padding(
              padding: const EdgeInsets.all(Gap.xs),
              child: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
            ),
          ),
          Gap.w4,
          Text(scenario.emoji, style: const TextStyle(fontSize: 20)),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario.title,
                  style: context.text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: VoixPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Gap.w4,
                    Text(_time, style: context.text.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          Pressable(
            onTap: onToggleVoice,
            scale: 0.9,
            semanticLabel:
                voiceReplies ? 'Mute tutor voice' : 'Unmute tutor voice',
            child: Padding(
              padding: const EdgeInsets.all(Gap.xs),
              child: Icon(
                voiceReplies
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
                size: 21,
                color: voiceReplies ? c.primary : c.textTertiary,
              ),
            ),
          ),
          if (onFinish != null)
            Pressable(
              onTap: onFinish,
              scale: 0.94,
              semanticLabel: 'End conversation and see feedback',
              child: Container(
                margin: const EdgeInsets.only(left: Gap.xxs),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: c.isDark ? c.surfaceHigh : c.surface,
                  borderRadius: Radii.rPill,
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  'Finish',
                  style: context.text.labelMedium?.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Suggestions ────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.suggestions, required this.onTap});

  final List<String> suggestions;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.page),
        itemCount: suggestions.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: Gap.xs),
          child: Pressable(
            onTap: () => onTap(suggestions[i]),
            scale: 0.95,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm + 2),
              decoration: BoxDecoration(
                color: c.isDark ? c.surfaceHigh : c.surface,
                borderRadius: Radii.rPill,
                border: Border.all(color: c.border),
              ),
              child: Text(
                suggestions[i],
                style: context.text.labelMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.typingMode,
    required this.controller,
    required this.listening,
    required this.enabled,
    required this.speechAvailable,
    required this.transcript,
    required this.amplitude,
    required this.onMic,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final bool typingMode;
  final TextEditingController controller;
  final bool listening;
  final bool enabled;
  final bool speechAvailable;
  final ValueNotifier<String> transcript;
  final ValueNotifier<double> amplitude;
  final VoidCallback onMic;
  final ValueChanged<String> onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (typingMode) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          Gap.xs,
          Gap.page,
          Gap.sm + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          children: [
            if (speechAvailable) ...[
              Pressable(
                onTap: onToggleMode,
                scale: 0.9,
                semanticLabel: 'Switch to voice input',
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: c.isDark ? c.surfaceHigh : c.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.mic_rounded, size: 21, color: c.primary),
                ),
              ),
              Gap.w8,
            ],
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: context.text.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Type your reply…',
                ),
                onSubmitted: onSubmit,
              ),
            ),
            Gap.w8,
            Pressable(
              onTap: enabled ? () => onSubmit(controller.text) : null,
              scale: 0.9,
              semanticLabel: 'Send',
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: VoixGradients.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 21,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live transcript while the learner speaks.
          ValueListenableBuilder<String>(
            valueListenable: transcript,
            builder: (context, text, _) {
              if (!listening && text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: Gap.sm,
                  ),
                  child: Text(
                    text.isEmpty ? 'Listening…' : text,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: text.isEmpty ? c.textTertiary : c.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: amplitude,
            builder: (context, amp, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (listening)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: Waveform(amplitude: amp, height: 40, bars: 32),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 46,
                      child: Pressable(
                        onTap: onToggleMode,
                        scale: 0.9,
                        semanticLabel: 'Switch to typing',
                        child: Icon(
                          Icons.keyboard_alt_outlined,
                          size: 24,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                    Gap.w20,
                    MicButton(
                      onTap: onMic,
                      recording: listening,
                      enabled: enabled,
                      amplitude: amp,
                      size: 76,
                    ),
                    Gap.w20,
                    const SizedBox(width: 46),
                  ],
                ),
              ],
            ),
          ),
          Text(
            listening
                ? 'Listening — tap to send'
                : (enabled ? 'Tap to speak' : 'Your tutor is replying…'),
            style: context.text.labelSmall,
          ),
        ],
      ),
    );
  }
}
