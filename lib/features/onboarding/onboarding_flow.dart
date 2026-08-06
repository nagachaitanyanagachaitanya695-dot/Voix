import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/energy_orb.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_widgets.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../core/widgets/voix_button.dart';
import '../../core/widgets/voix_logo.dart';
import '../../data/models/language.dart';
import '../../data/models/user_profile.dart';
import '../../providers/app_providers.dart';
import '../auth/auth_screen.dart';
import 'onboarding_draft.dart';
import 'widgets/option_tile.dart';

/// The eleven-step questionnaire that personalises the tutor.
///
/// Runs before sign-in so the learner sees value before being asked for an
/// account; answers live in [onboardingDraftProvider] until then.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pager = PageController();
  final _nameController = TextEditingController();
  int _page = 0;

  static const _lastPage = 9;

  @override
  void dispose() {
    _pager.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    Haptic.light();
    if (_page >= _lastPage) {
      _finish();
      return;
    }
    _pager.nextPage(duration: Motion.page, curve: Motion.emphasized);
  }

  void _back() {
    if (_page == 0) return;
    Haptic.tap();
    _pager.previousPage(duration: Motion.page, curve: Motion.emphasized);
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  /// The continue button is disabled until the current step has an answer.
  bool get _canAdvance {
    if (_page == 1) return _nameController.text.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);

    return Scaffold(
      body: AuroraBackground(
        intensity: 1.15,
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                page: _page,
                total: _lastPage,
                onBack: _back,
                onSkip: _page == 0 ? null : _finish,
              ),
              Expanded(
                child: PageView(
                  controller: _pager,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _WelcomeStep(onStart: _next),
                    _NameStep(
                      controller: _nameController,
                      onChanged: (v) {
                        notifier.update((d) => d.copyWith(name: v));
                        setState(() {}); // Re-evaluates _canAdvance.
                      },
                      onSubmit: _canAdvance ? _next : null,
                    ),
                    _OccupationStep(
                      value: draft.occupation,
                      onChanged: (v) =>
                          notifier.update((d) => d.copyWith(occupation: v)),
                    ),
                    _GoalStep(
                      value: draft.goal,
                      onChanged: (v) =>
                          notifier.update((d) => d.copyWith(goal: v)),
                    ),
                    _LevelStep(
                      value: draft.proficiency,
                      onChanged: (v) =>
                          notifier.update((d) => d.copyWith(proficiency: v)),
                    ),
                    _NativeLanguageStep(
                      value: draft.nativeLanguageCode,
                      onChanged: (v) => notifier
                          .update((d) => d.copyWith(nativeLanguageCode: v)),
                    ),
                    const _ComingSoonStep(),
                    _VoiceStep(
                      value: draft.tutorVoice,
                      onChanged: (v) =>
                          notifier.update((d) => d.copyWith(tutorVoice: v)),
                    ),
                    _DailyGoalStep(
                      value: draft.dailyGoalMinutes,
                      onChanged: (v) => notifier
                          .update((d) => d.copyWith(dailyGoalMinutes: v)),
                    ),
                    _AllSetStep(draft: draft),
                  ],
                ),
              ),
              if (_page > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    Gap.lg,
                  ),
                  child: VoixButton(
                    label: _page == _lastPage ? 'Start Practice' : 'Continue',
                    trailingIcon: Icons.arrow_forward_rounded,
                    onPressed: _canAdvance ? _next : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chrome ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.page,
    required this.total,
    required this.onBack,
    this.onSkip,
  });

  final int page;
  final int total;
  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (page == 0) return const SizedBox(height: Gap.md);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
      child: Row(
        children: [
          Pressable(
            onTap: onBack,
            scale: 0.9,
            semanticLabel: 'Go back',
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 19, color: c.textPrimary),
            ),
          ),
          Gap.w12,
          // Segmented progress: one bar per remaining step, filled as you go.
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final done = i < page;
                return Expanded(
                  child: AnimatedContainer(
                    duration: Motion.base,
                    curve: Motion.enter,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: done ? VoixGradients.brandSoft : null,
                      color: done ? null : c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          Gap.w12,
          SizedBox(
            width: 38,
            child: onSkip == null
                ? null
                : Pressable(
                    onTap: onSkip,
                    scale: 0.9,
                    child: Text(
                      'Skip',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall
                          ?.copyWith(color: c.textTertiary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Shared layout for every question step: title, optional subtitle, content.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Gap.h16,
        FadeSlideIn(
          child: Text(
            title,
            style: context.text.displaySmall?.copyWith(height: 1.22),
          ),
        ),
        if (subtitle != null) ...[
          Gap.h8,
          FadeSlideIn(
            index: 1,
            child: Text(
              subtitle!,
              style: context.text.bodyMedium,
            ),
          ),
        ],
        Gap.h24,
        Expanded(child: child),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: content,
    );
  }
}

// ── Steps ──────────────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final orb = (context.screenW * 0.62).clamp(180.0, 280.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        children: [
          const Spacer(flex: 2),
          FadeSlideIn(
            offset: 0,
            child: SizedBox(
              height: orb,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  EnergyOrb(size: orb, energy: 0.85, amplitude: 0.35),
                  VoixLogo(size: orb * 0.42),
                ],
              ),
            ),
          ),
          const Spacer(),
          FadeSlideIn(
            index: 2,
            child: Text(
              'Your Personal\nAI Language Tutor',
              textAlign: TextAlign.center,
              style: context.text.displayMedium?.copyWith(height: 1.14),
            ),
          ),
          Gap.h16,
          FadeSlideIn(
            index: 3,
            child: Text(
              'Practise real conversations, get instant corrections,\n'
              'and speak with confidence.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
          const Spacer(flex: 2),
          FadeSlideIn(
            index: 4,
            child: VoixButton(
              label: 'Get Started',
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: onStart,
            ),
          ),
          Gap.h32,
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({
    required this.controller,
    required this.onChanged,
    this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "What's your name?",
      subtitle: "Let's get to know you better.",
      child: Column(
        children: [
          FadeSlideIn(
            index: 2,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit?.call(),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: context.text.titleMedium,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
          Gap.h32,
          FadeSlideIn(
            index: 3,
            child: SizedBox(
              height: 130,
              child: EnergyOrb(
                size: 130,
                energy: 0.7,
                amplitude: 0.25,
                showRings: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OccupationStep extends StatelessWidget {
  const _OccupationStep({required this.value, required this.onChanged});
  final Occupation value;
  final ValueChanged<Occupation> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'What are you\ncurrently doing?',
      subtitle: 'This helps us personalise your learning.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          for (var i = 0; i < Occupation.values.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: OptionTile(
                label: Occupation.values[i].label,
                emoji: Occupation.values[i].emoji,
                selected: value == Occupation.values[i],
                onTap: () => onChanged(Occupation.values[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.value, required this.onChanged});
  final LearningGoal value;
  final ValueChanged<LearningGoal> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Why do you want\nto learn English?',
      subtitle: 'Choose your main goal.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          for (var i = 0; i < LearningGoal.values.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: OptionTile(
                label: LearningGoal.values[i].label,
                emoji: LearningGoal.values[i].emoji,
                selected: value == LearningGoal.values[i],
                onTap: () => onChanged(LearningGoal.values[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({required this.value, required this.onChanged});
  final Proficiency value;
  final ValueChanged<Proficiency> onChanged;

  static const _accents = [
    VoixPalette.success,
    VoixPalette.blue,
    VoixPalette.violet,
  ];
  static const _icons = [
    Icons.eco_rounded,
    Icons.trending_up_rounded,
    Icons.auto_awesome_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "What's your\nEnglish level?",
      subtitle: 'Choose the option that describes you best.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          for (var i = 0; i < Proficiency.values.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: OptionTile(
                label: Proficiency.values[i].label,
                description: Proficiency.values[i].description,
                icon: _icons[i],
                accent: _accents[i],
                selected: value == Proficiency.values[i],
                onTap: () => onChanged(Proficiency.values[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _NativeLanguageStep extends StatelessWidget {
  const _NativeLanguageStep({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = LanguageCatalog.nativeOptions;
    return _StepScaffold(
      title: 'Choose your\nnative language',
      subtitle: 'So we can explain things in a language you know.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          for (var i = 0; i < options.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: OptionTile(
                label: options[i].displayName,
                emoji: options[i].flag,
                selected: value == options[i].code,
                onTap: () => onChanged(options[i].code),
              ),
            ),
        ],
      ),
    );
  }
}

class _ComingSoonStep extends StatelessWidget {
  const _ComingSoonStep();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeSlideIn(
            offset: 0,
            child: SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  EnergyOrb(
                    size: 190,
                    energy: 0.7,
                    amplitude: 0.2,
                    colors: const [VoixPalette.violet, VoixPalette.magenta],
                  ),
                  const Text('🌍', style: TextStyle(fontSize: 56)),
                ],
              ),
            ),
          ),
          Gap.h32,
          FadeSlideIn(
            index: 2,
            child: Text(
              'More Languages\nComing Soon',
              textAlign: TextAlign.center,
              style: context.text.displaySmall?.copyWith(height: 1.2),
            ),
          ),
          Gap.h12,
          FadeSlideIn(
            index: 3,
            child: Text(
              "We're building Spanish, French and Japanese next.\n"
              'English is ready for you today.',
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
          Gap.h24,
          FadeSlideIn(
            index: 4,
            child: Wrap(
              spacing: Gap.xs,
              runSpacing: Gap.xs,
              alignment: WrapAlignment.center,
              children: [
                for (final l in LanguageCatalog.upcoming)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: Radii.rPill,
                      border: Border.all(color: c.border),
                    ),
                    child: Text(
                      '${l.flag}  ${l.name}',
                      style: context.text.labelMedium
                          ?.copyWith(color: c.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceStep extends StatelessWidget {
  const _VoiceStep({required this.value, required this.onChanged});
  final TutorVoice value;
  final ValueChanged<TutorVoice> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Choose your\nAI tutor voice',
      subtitle: 'You can change this later in Settings.',
      child: Column(
        children: [
          FadeSlideIn(
            index: 2,
            child: Row(
              children: [
                Expanded(
                  child: ChoiceCard(
                    title: 'Male Voice',
                    icon: Icons.mic_rounded,
                    selected: value == TutorVoice.male,
                    onTap: () => onChanged(TutorVoice.male),
                    height: 120,
                  ),
                ),
                Gap.w12,
                Expanded(
                  child: ChoiceCard(
                    title: 'Female Voice',
                    icon: Icons.mic_none_rounded,
                    accent: VoixPalette.violet,
                    selected: value == TutorVoice.female,
                    onTap: () => onChanged(TutorVoice.female),
                    height: 120,
                  ),
                ),
              ],
            ),
          ),
          Gap.h32,
          FadeSlideIn(
            index: 3,
            child: SizedBox(
              height: 140,
              child: EnergyOrb(
                size: 140,
                energy: 0.75,
                amplitude: 0.4,
                colors: value == TutorVoice.male
                    ? const [VoixPalette.cyan, VoixPalette.blue]
                    : const [VoixPalette.violet, VoixPalette.magenta],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyGoalStep extends StatelessWidget {
  const _DailyGoalStep({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [
    (5, 'Just getting started', '🌱'),
    (10, 'Steady progress', '🎯'),
    (15, 'Strong pace', '🚀'),
    (20, 'Fully committed', '🔥'),
  ];

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Set your daily\npractice goal',
      subtitle: 'Consistency is the key to fluency.',
      child: ListView(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        children: [
          for (var i = 0; i < _options.length; i++)
            FadeSlideIn(
              index: i + 2,
              child: OptionTile(
                label: '${_options[i].$1} minutes',
                description: _options[i].$2,
                emoji: _options[i].$3,
                selected: value == _options[i].$1,
                onTap: () => onChanged(_options[i].$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllSetStep extends ConsumerWidget {
  const _AllSetStep({required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final native = LanguageCatalog.byCode(draft.nativeLanguageCode);

    final rows = <(IconData, String, String)>[
      (Icons.person_outline_rounded, 'Name', draft.name.trim().isEmpty ? 'Learner' : draft.name.trim()),
      (Icons.bar_chart_rounded, 'Level', draft.proficiency.label),
      (Icons.flag_outlined, 'Goal', '${draft.dailyGoalMinutes} min / day'),
      (Icons.mic_none_rounded, 'AI Voice', draft.tutorVoice.label),
      (Icons.language_rounded, 'Language', native.displayName),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        children: [
          Gap.h16,
          FadeSlideIn(
            offset: 0,
            child: SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  EnergyOrb(
                    size: 160,
                    energy: 0.9,
                    amplitude: 0.5,
                    colors: const [
                      VoixPalette.gold,
                      VoixPalette.streak,
                      VoixPalette.magenta,
                    ],
                  ),
                  const Text('🏆', style: TextStyle(fontSize: 54)),
                ],
              ),
            ),
          ),
          Gap.h24,
          FadeSlideIn(
            index: 2,
            child: GradientText(
              "You're All Set!",
              style: context.text.displaySmall,
              gradient: VoixGradients.gold,
            ),
          ),
          Gap.h8,
          FadeSlideIn(
            index: 3,
            child: Text(
              "Let's start your English learning journey together.",
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
          ),
          Gap.h24,
          FadeSlideIn(
            index: 4,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.xs,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) Divider(color: c.border, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                      child: Row(
                        children: [
                          Icon(rows[i].$1, size: 18, color: c.textTertiary),
                          Gap.w12,
                          Text(
                            rows[i].$2,
                            style: context.text.bodyMedium,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              rows[i].$3,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Gap.h24,
        ],
      ),
    );
  }
}
