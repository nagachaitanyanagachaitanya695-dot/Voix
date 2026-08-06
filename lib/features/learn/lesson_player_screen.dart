import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/voix_button.dart';
import '../../data/models/lesson.dart';
import '../../providers/app_providers.dart';
import 'lesson_result_screen.dart';
import 'widgets/exercise_views.dart';

/// Runs a lesson end to end: one exercise per page, with an answer check and
/// an explanation before advancing.
class LessonPlayerScreen extends ConsumerStatefulWidget {
  const LessonPlayerScreen({super.key, required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends ConsumerState<LessonPlayerScreen> {
  final _pager = PageController();
  final _startedAt = DateTime.now();

  int _index = 0;
  int _correct = 0;

  /// Answer state for the current exercise, reset on each advance.
  Object? _answer;
  bool _checked = false;
  bool _wasCorrect = false;

  Exercise get _exercise => widget.lesson.exercises[_index];
  bool get _isLast => _index == widget.lesson.exercises.length - 1;

  /// Flashcards and speaking drills have no wrong answer — they advance
  /// directly instead of showing a check step.
  bool get _isSelfAssessed =>
      _exercise is FlashcardExercise || _exercise is SpeakExercise;

  bool get _canCheck => _isSelfAssessed || _answer != null;

  @override
  void dispose() {
    _pager.dispose();
    ref.read(speechServiceProvider).stopSpeaking();
    super.dispose();
  }

  void _check() {
    if (_isSelfAssessed) {
      _correct++;
      _advance();
      return;
    }

    final correct = _evaluate();
    setState(() {
      _checked = true;
      _wasCorrect = correct;
      if (correct) _correct++;
    });
    correct ? Haptic.success() : Haptic.error();
  }

  bool _evaluate() {
    final e = _exercise;
    return switch (e) {
      ChoiceExercise() => _answer == e.correctIndex,
      FillBlankExercise() => _answer == e.correctIndex,
      ListenExercise() => _answer == e.correctIndex,
      ArrangeExercise() => _answer is List<String> &&
          _listEquals(_answer! as List<String>, e.correctOrder),
      _ => true,
    };
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) return false;
    }
    return true;
  }

  void _advance() {
    if (_isLast) {
      _complete();
      return;
    }
    setState(() {
      _index++;
      _answer = null;
      _checked = false;
      _wasCorrect = false;
    });
    _pager.nextPage(duration: Motion.page, curve: Motion.emphasized);
  }

  void _complete() {
    final result = LessonResult(
      lessonId: widget.lesson.id,
      correct: _correct,
      total: widget.lesson.exercises.length,
      // Partial credit: a learner who gets most of it right still earns most
      // of the XP, which keeps a hard lesson from feeling like a waste.
      xpEarned: (widget.lesson.xpReward *
              (0.5 + 0.5 * (_correct / widget.lesson.exercises.length)))
          .round(),
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LessonResultScreen(
          lesson: widget.lesson,
          result: result,
        ),
      ),
    );
  }

  Future<void> _confirmQuit() async {
    if (_index == 0 && _answer == null) {
      Navigator.of(context).pop();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this lesson?'),
        content: const Text("Your progress in this lesson won't be saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = widget.lesson.exercises.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: AuroraBackground(
          animate: false,
          child: SafeArea(
            child: Column(
              children: [
                // ── Progress header ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.sm,
                    Gap.xs,
                    Gap.md,
                    Gap.xs,
                  ),
                  child: Row(
                    children: [
                      Pressable(
                        onTap: _confirmQuit,
                        scale: 0.9,
                        semanticLabel: 'Close lesson',
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.xs),
                          child: Icon(
                            Icons.close_rounded,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      Gap.w8,
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: (_index + (_checked ? 1 : 0)) / total,
                            ),
                            duration: Motion.slow,
                            curve: Motion.enter,
                            builder: (_, v, __) => LinearProgressIndicator(
                              value: v,
                              minHeight: 7,
                              backgroundColor: c.border,
                              valueColor: AlwaysStoppedAnimation(c.primary),
                            ),
                          ),
                        ),
                      ),
                      Gap.w12,
                      Text(
                        '${_index + 1}/$total',
                        style: context.text.labelMedium
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),

                // ── Exercise ──────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: total,
                    itemBuilder: (context, i) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.md,
                        Gap.page,
                        Gap.lg,
                      ),
                      child: ExerciseView(
                        key: ValueKey(widget.lesson.exercises[i].id),
                        exercise: widget.lesson.exercises[i],
                        answer: i == _index ? _answer : null,
                        locked: _checked,
                        onAnswer: (value) => setState(() => _answer = value),
                      ),
                    ),
                  ),
                ),

                // ── Feedback + action ─────────────────────────────
                _FooterBar(
                  checked: _checked,
                  correct: _wasCorrect,
                  explanation: _exercise.explanation,
                  canCheck: _canCheck,
                  isLast: _isLast,
                  selfAssessed: _isSelfAssessed,
                  onCheck: _check,
                  onContinue: _advance,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBar extends StatelessWidget {
  const _FooterBar({
    required this.checked,
    required this.correct,
    required this.explanation,
    required this.canCheck,
    required this.isLast,
    required this.selfAssessed,
    required this.onCheck,
    required this.onContinue,
  });

  final bool checked;
  final bool correct;
  final String? explanation;
  final bool canCheck;
  final bool isLast;
  final bool selfAssessed;
  final VoidCallback onCheck;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = correct ? c.success : c.danger;

    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.enter,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.lg),
      decoration: BoxDecoration(
        color: checked ? tint.withValues(alpha: 0.10) : Colors.transparent,
        border: Border(
          top: BorderSide(
            color: checked ? tint.withValues(alpha: 0.3) : Colors.transparent,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.enter,
            child: checked
                ? Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          correct
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: tint,
                          size: 22,
                        ),
                        Gap.w12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                correct ? 'Correct!' : 'Not quite',
                                style: context.text.titleSmall
                                    ?.copyWith(color: tint),
                              ),
                              if (explanation != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  explanation!,
                                  style: context.text.bodySmall
                                      ?.copyWith(height: 1.45),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          VoixButton(
            label: checked
                ? (isLast ? 'See Results' : 'Continue')
                : (selfAssessed
                    ? (isLast ? 'Finish' : 'Got it')
                    : 'Check Answer'),
            trailingIcon:
                checked || selfAssessed ? Icons.arrow_forward_rounded : null,
            onPressed: checked
                ? onContinue
                : (canCheck ? onCheck : null),
            gradient: checked && correct
                ? const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
