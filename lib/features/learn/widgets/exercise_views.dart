import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/mic_button.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/staggered.dart';
import '../../../data/models/lesson.dart';
import '../../../providers/app_providers.dart';

/// Dispatches to the right view for [exercise].
///
/// Every variant reports its answer through [onAnswer]; the player owns
/// checking so the views stay presentational.
class ExerciseView extends StatelessWidget {
  const ExerciseView({
    super.key,
    required this.exercise,
    required this.onAnswer,
    this.answer,
    this.locked = false,
  });

  final Exercise exercise;
  final ValueChanged<Object?> onAnswer;
  final Object? answer;

  /// True once the answer has been checked — inputs stop responding.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return switch (exercise) {
      ChoiceExercise(:final question, :final prompt, :final options, :final correctIndex) =>
        _ChoiceView(
          instruction: question ?? 'Choose the correct answer',
          prompt: prompt,
          options: options,
          correctIndex: correctIndex,
          selected: answer as int?,
          locked: locked,
          onSelect: onAnswer,
        ),
      FillBlankExercise(:final sentence, :final options, :final correctIndex) =>
        _FillBlankView(
          sentence: sentence,
          options: options,
          correctIndex: correctIndex,
          selected: answer as int?,
          locked: locked,
          onSelect: onAnswer,
        ),
      ListenExercise(:final phrase, :final options, :final correctIndex) =>
        _ListenView(
          phrase: phrase,
          options: options,
          correctIndex: correctIndex,
          selected: answer as int?,
          locked: locked,
          onSelect: onAnswer,
        ),
      ArrangeExercise(:final words, :final correctOrder, :final hint) =>
        _ArrangeView(
          words: words,
          correctOrder: correctOrder,
          hint: hint,
          locked: locked,
          onChanged: onAnswer,
        ),
      SpeakExercise(:final phrase, :final phonetic, :final tip) => _SpeakView(
          phrase: phrase,
          phonetic: phonetic,
          tip: tip,
        ),
      FlashcardExercise(:final front, :final back, :final example) =>
        _FlashcardView(front: front, back: back, example: example),
    };
  }
}

// ── Shared pieces ──────────────────────────────────────────────────────────

class _Instruction extends StatelessWidget {
  const _Instruction(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: context.colors.textTertiary,
      ),
    );
  }
}

/// A tappable answer option that turns green or red once checked.
class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.locked,
    required this.isCorrect,
    this.index,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool locked;
  final bool isCorrect;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // After checking: the right answer always turns green; a wrong pick turns
    // red. Untouched options stay neutral.
    final Color tint;
    if (locked && isCorrect) {
      tint = c.success;
    } else if (locked && selected) {
      tint = c.danger;
    } else if (selected) {
      tint = c.primary;
    } else {
      tint = c.border;
    }

    final active = selected || (locked && isCorrect);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Pressable(
        enabled: !locked,
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm + 2,
          ),
          decoration: BoxDecoration(
            color: active
                ? Color.alphaBlend(
                    tint.withValues(alpha: c.isDark ? 0.16 : 0.09),
                    c.surface,
                  )
                : c.surface,
            borderRadius: Radii.rMd,
            border: Border.all(
              color: active ? tint : c.border,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (index != null) ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? tint : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? tint : c.borderStrong,
                    ),
                  ),
                  child: Text(
                    String.fromCharCode(65 + index!),
                    style: context.text.labelSmall?.copyWith(
                      color: active ? Colors.white : c.textTertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Gap.w12,
              ],
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyLarge?.copyWith(
                    fontSize: 15,
                    color: c.textPrimary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (locked && isCorrect)
                Icon(Icons.check_circle_rounded, size: 19, color: c.success)
              else if (locked && selected)
                Icon(Icons.cancel_rounded, size: 19, color: c.danger),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Multiple choice ────────────────────────────────────────────────────────

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({
    required this.instruction,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.onSelect,
    required this.locked,
    this.selected,
  });

  final String instruction;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final ValueChanged<Object?> onSelect;
  final bool locked;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(child: _Instruction(instruction)),
        Gap.h12,
        FadeSlideIn(
          index: 1,
          child: Text(
            prompt,
            style: context.text.headlineSmall?.copyWith(height: 1.4),
          ),
        ),
        Gap.h24,
        for (var i = 0; i < options.length; i++)
          FadeSlideIn(
            index: i + 2,
            child: _OptionButton(
              label: options[i],
              index: i,
              selected: selected == i,
              locked: locked,
              isCorrect: i == correctIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

// ── Fill in the blank ──────────────────────────────────────────────────────

class _FillBlankView extends StatelessWidget {
  const _FillBlankView({
    required this.sentence,
    required this.options,
    required this.correctIndex,
    required this.onSelect,
    required this.locked,
    this.selected,
  });

  final String sentence;
  final List<String> options;
  final int correctIndex;
  final ValueChanged<Object?> onSelect;
  final bool locked;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The blank is filled in live as the learner picks, so they read the whole
    // sentence rather than mentally substituting.
    final filled = selected == null
        ? sentence
        : sentence.replaceFirst('___', options[selected!]);
    final parts = filled.split('___');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(child: _Instruction('Complete the sentence')),
        Gap.h16,
        FadeSlideIn(
          index: 1,
          child: GlassCard(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: parts.first),
                  if (parts.length > 1) ...[
                    TextSpan(
                      text: '______',
                      style: TextStyle(
                        color: c.textTertiary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(text: parts.last),
                  ],
                ],
              ),
              style: context.text.headlineSmall?.copyWith(
                height: 1.5,
                color: c.textPrimary,
              ),
            ),
          ),
        ),
        Gap.h24,
        for (var i = 0; i < options.length; i++)
          FadeSlideIn(
            index: i + 2,
            child: _OptionButton(
              label: options[i],
              selected: selected == i,
              locked: locked,
              isCorrect: i == correctIndex,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

// ── Listening ──────────────────────────────────────────────────────────────

class _ListenView extends ConsumerStatefulWidget {
  const _ListenView({
    required this.phrase,
    required this.options,
    required this.correctIndex,
    required this.onSelect,
    required this.locked,
    this.selected,
  });

  final String phrase;
  final List<String> options;
  final int correctIndex;
  final ValueChanged<Object?> onSelect;
  final bool locked;
  final int? selected;

  @override
  ConsumerState<_ListenView> createState() => _ListenViewState();
}

class _ListenViewState extends ConsumerState<_ListenView> {
  bool _played = false;

  @override
  void initState() {
    super.initState();
    // Play once automatically — the exercise is meaningless until heard.
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play({double rate = 1.0}) async {
    setState(() => _played = true);
    await ref.read(speechServiceProvider).speak(widget.phrase);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(child: _Instruction('What did you hear?')),
        Gap.h24,
        FadeSlideIn(
          index: 1,
          child: Center(
            child: Column(
              children: [
                Pressable(
                  onTap: _play,
                  scale: 0.92,
                  semanticLabel: 'Play audio',
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: VoixGradients.brandSoft,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c.primary.withValues(alpha: 0.42),
                          blurRadius: 28,
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Icon(
                      _played
                          ? Icons.replay_rounded
                          : Icons.volume_up_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                Gap.h12,
                Text(
                  _played ? 'Tap to hear it again' : 'Tap to listen',
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
        ),
        Gap.h32,
        for (var i = 0; i < widget.options.length; i++)
          FadeSlideIn(
            index: i + 2,
            child: _OptionButton(
              label: widget.options[i],
              selected: widget.selected == i,
              locked: widget.locked,
              isCorrect: i == widget.correctIndex,
              onTap: () => widget.onSelect(i),
            ),
          ),
      ],
    );
  }
}

// ── Word arrangement ───────────────────────────────────────────────────────

class _ArrangeView extends StatefulWidget {
  const _ArrangeView({
    required this.words,
    required this.correctOrder,
    required this.onChanged,
    required this.locked,
    this.hint,
  });

  final List<String> words;
  final List<String> correctOrder;
  final ValueChanged<Object?> onChanged;
  final bool locked;
  final String? hint;

  @override
  State<_ArrangeView> createState() => _ArrangeViewState();
}

class _ArrangeViewState extends State<_ArrangeView> {
  late List<String> _bank;
  final List<String> _chosen = [];

  @override
  void initState() {
    super.initState();
    // Shuffled deterministically per exercise so the scramble is stable across
    // rebuilds but still not the answer order.
    _bank = [...widget.words]..shuffle(
        math.Random(widget.correctOrder.join().hashCode),
      );
    // Guard against a shuffle that happens to produce the answer.
    if (_listEquals(_bank, widget.correctOrder) && _bank.length > 1) {
      final first = _bank.removeAt(0);
      _bank.add(first);
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _pick(int index) {
    if (widget.locked) return;
    Haptic.tap();
    setState(() {
      _chosen.add(_bank.removeAt(index));
    });
    widget.onChanged(_chosen.isEmpty ? null : List<String>.from(_chosen));
  }

  void _unpick(int index) {
    if (widget.locked) return;
    Haptic.tap();
    setState(() {
      _bank.add(_chosen.removeAt(index));
    });
    widget.onChanged(_chosen.isEmpty ? null : List<String>.from(_chosen));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget tile(String word, VoidCallback onTap, {required bool filled}) {
      return Pressable(
        enabled: !widget.locked,
        onTap: onTap,
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm + 2,
            vertical: Gap.xs + 2,
          ),
          decoration: BoxDecoration(
            color: filled ? c.primary.withValues(alpha: 0.14) : c.surface,
            borderRadius: Radii.rSm,
            border: Border.all(color: filled ? c.primary : c.border),
          ),
          child: Text(
            word,
            style: context.text.bodyLarge?.copyWith(
              fontSize: 15,
              color: c.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(child: _Instruction('Build the sentence')),
        if (widget.hint != null) ...[
          Gap.h8,
          FadeSlideIn(
            index: 1,
            child: Text(widget.hint!, style: context.text.bodySmall),
          ),
        ],
        Gap.h16,

        // Answer tray
        FadeSlideIn(
          index: 2,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(Gap.sm),
            decoration: BoxDecoration(
              color: c.isDark ? c.bgAlt : c.bgAlt,
              borderRadius: Radii.rMd,
              border: Border.all(
                color: c.border,
                style: BorderStyle.solid,
              ),
            ),
            child: _chosen.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
                      child: Text(
                        'Tap the words below',
                        style: context.text.bodySmall
                            ?.copyWith(color: c.textTertiary),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: Gap.xs,
                    runSpacing: Gap.xs,
                    children: [
                      for (var i = 0; i < _chosen.length; i++)
                        tile(_chosen[i], () => _unpick(i), filled: true),
                    ],
                  ),
          ),
        ),

        Gap.h24,

        // Word bank
        FadeSlideIn(
          index: 3,
          child: Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              for (var i = 0; i < _bank.length; i++)
                tile(_bank[i], () => _pick(i), filled: false),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Speaking ───────────────────────────────────────────────────────────────

class _SpeakView extends ConsumerStatefulWidget {
  const _SpeakView({required this.phrase, this.phonetic, this.tip});

  final String phrase;
  final String? phonetic;
  final String? tip;

  @override
  ConsumerState<_SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends ConsumerState<_SpeakView> {
  bool _listening = false;
  String _heard = '';
  int? _match;

  @override
  void dispose() {
    ref.read(speechServiceProvider).cancelListening();
    super.dispose();
  }

  Future<void> _toggle() async {
    final speech = ref.read(speechServiceProvider);

    if (_listening) {
      final text = await speech.stopListening();
      setState(() {
        _listening = false;
        _heard = text;
        _match = _score(text, widget.phrase);
      });
      return;
    }

    await speech.stopSpeaking();
    final started = await speech.startListening(
      pauseFor: const Duration(seconds: 3),
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _heard = text;
          _match = _score(text, widget.phrase);
        });
      },
    );

    if (!started) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input is unavailable — you can still continue.',
            ),
          ),
        );
      return;
    }
    setState(() {
      _listening = true;
      _heard = '';
      _match = null;
    });
  }

  /// Word-overlap score between what was said and the target phrase.
  ///
  /// A real pronunciation model would score phonemes; with an on-device
  /// recogniser, word recall is the honest proxy — and it still catches the
  /// mistakes a learner makes on a drill like this.
  static int _score(String heard, String target) {
    String normalise(String s) =>
        s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), '').trim();

    final heardWords = normalise(heard).split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final targetWords = normalise(target).split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (targetWords.isEmpty || heardWords.isEmpty) return 0;

    final remaining = [...heardWords];
    var hits = 0;
    for (final word in targetWords) {
      if (remaining.remove(word)) hits++;
    }
    return ((hits / targetWords.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final speech = ref.read(speechServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(child: _Instruction('Say it out loud')),
        Gap.h16,
        FadeSlideIn(
          index: 1,
          child: GlassCard(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.phrase,
                        style: context.text.headlineSmall
                            ?.copyWith(height: 1.4),
                      ),
                    ),
                    Gap.w8,
                    Pressable(
                      onTap: () => speech.speak(widget.phrase),
                      scale: 0.88,
                      semanticLabel: 'Hear the phrase',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.volume_up_rounded,
                          size: 20,
                          color: c.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.phonetic != null) ...[
                  Gap.h8,
                  Text(
                    widget.phonetic!,
                    style: context.text.bodySmall
                        ?.copyWith(color: c.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (widget.tip != null) ...[
          Gap.h12,
          FadeSlideIn(
            index: 2,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: c.warning,
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    widget.tip!,
                    style: context.text.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],

        Gap.h32,

        FadeSlideIn(
          index: 3,
          child: Center(
            child: ValueListenableBuilder<double>(
              valueListenable: speech.amplitude,
              builder: (context, amp, _) => MicButton(
                onTap: _toggle,
                recording: _listening,
                amplitude: amp,
                size: 76,
              ),
            ),
          ),
        ),
        Gap.h8,
        Center(
          child: Text(
            _listening ? 'Listening — tap to stop' : 'Tap and say the phrase',
            style: context.text.labelSmall,
          ),
        ),

        if (_match != null) ...[
          Gap.h20,
          _MatchResult(score: _match!, heard: _heard),
        ],
      ],
    );
  }
}

class _MatchResult extends StatelessWidget {
  const _MatchResult({required this.score, required this.heard});
  final int score;
  final String heard;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = score >= 80
        ? c.success
        : (score >= 50 ? c.warning : c.danger);
    final verdict = score >= 80
        ? 'Excellent!'
        : (score >= 50 ? 'Close — try once more' : 'Give it another go');

    return GlassCard(
      borderColor: tint.withValues(alpha: 0.4),
      fill: Color.alphaBlend(
        tint.withValues(alpha: c.isDark ? 0.10 : 0.06),
        c.surface,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '$score%',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: tint,
              ),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(verdict, style: context.text.titleSmall),
                if (heard.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'We heard: "$heard"',
                    style: context.text.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Flashcard ──────────────────────────────────────────────────────────────

class _FlashcardView extends ConsumerStatefulWidget {
  const _FlashcardView({
    required this.front,
    required this.back,
    this.example,
  });

  final String front;
  final String back;
  final String? example;

  @override
  ConsumerState<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends ConsumerState<_FlashcardView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    Haptic.light();
    _flip.isCompleted || _flip.velocity > 0
        ? _flip.reverse()
        : _flip.forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FadeSlideIn(child: _Instruction('Tap the card to flip')),
        Gap.h24,
        FadeSlideIn(
          index: 1,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, _) {
                final angle = _flip.value * math.pi;
                final showBack = _flip.value > 0.5;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: Transform(
                    // Un-mirror the back face.
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateY(showBack ? math.pi : 0),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 230),
                      padding: const EdgeInsets.all(Gap.xl),
                      decoration: BoxDecoration(
                        gradient: showBack
                            ? null
                            : VoixGradients.brandSoft,
                        color: showBack ? c.surface : null,
                        borderRadius: Radii.rXl,
                        border: showBack
                            ? Border.all(color: c.border)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: showBack
                                ? c.shadow
                                : VoixPalette.blue.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                            spreadRadius: -8,
                          ),
                        ],
                      ),
                      child: Center(
                        child: showBack
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.back,
                                    textAlign: TextAlign.center,
                                    style: context.text.titleLarge
                                        ?.copyWith(height: 1.4),
                                  ),
                                  if (widget.example != null) ...[
                                    Gap.h16,
                                    Container(
                                      padding: const EdgeInsets.all(Gap.sm + 2),
                                      decoration: BoxDecoration(
                                        color: c.primary
                                            .withValues(alpha: 0.09),
                                        borderRadius: Radii.rSm,
                                      ),
                                      child: Text(
                                        '"${widget.example}"',
                                        textAlign: TextAlign.center,
                                        style: context.text.bodySmall
                                            ?.copyWith(height: 1.45),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.front,
                                    textAlign: TextAlign.center,
                                    style: context.text.displaySmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                  Gap.h12,
                                  Text(
                                    'Tap to reveal',
                                    style: context.text.labelSmall?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Gap.h16,
        Center(
          child: Pressable(
            onTap: () => ref.read(speechServiceProvider).speak(
                  widget.example ?? widget.front,
                ),
            scale: 0.94,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volume_up_rounded, size: 17, color: c.primary),
                Gap.w4,
                Text(
                  'Hear it',
                  style: context.text.labelMedium?.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
