import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_profile.dart';

/// Answers collected during onboarding, before an account exists.
///
/// Onboarding runs *ahead* of sign-in (matching the reference flow, where the
/// learner is asked about themselves first), so the responses are parked here
/// and applied to the profile the moment authentication succeeds.
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.name = '',
    this.occupation = Occupation.schoolStudent,
    this.goal = LearningGoal.speakConfidently,
    this.proficiency = Proficiency.beginner,
    this.nativeLanguageCode = 'te',
    this.tutorVoice = TutorVoice.male,
    this.dailyGoalMinutes = 5,
  });

  final String name;
  final Occupation occupation;
  final LearningGoal goal;
  final Proficiency proficiency;
  final String nativeLanguageCode;
  final TutorVoice tutorVoice;
  final int dailyGoalMinutes;

  OnboardingDraft copyWith({
    String? name,
    Occupation? occupation,
    LearningGoal? goal,
    Proficiency? proficiency,
    String? nativeLanguageCode,
    TutorVoice? tutorVoice,
    int? dailyGoalMinutes,
  }) =>
      OnboardingDraft(
        name: name ?? this.name,
        occupation: occupation ?? this.occupation,
        goal: goal ?? this.goal,
        proficiency: proficiency ?? this.proficiency,
        nativeLanguageCode: nativeLanguageCode ?? this.nativeLanguageCode,
        tutorVoice: tutorVoice ?? this.tutorVoice,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      );

  /// Folds the draft into a freshly created profile.
  UserProfile applyTo(UserProfile profile) => profile.copyWith(
        name: name.trim().isEmpty ? profile.name : name.trim(),
        occupation: occupation,
        goal: goal,
        proficiency: proficiency,
        nativeLanguageCode: nativeLanguageCode,
        tutorVoice: tutorVoice,
        dailyGoalMinutes: dailyGoalMinutes,
      );
}

class OnboardingDraftController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void update(OnboardingDraft Function(OnboardingDraft) edit) =>
      state = edit(state);
}

final onboardingDraftProvider =
    NotifierProvider<OnboardingDraftController, OnboardingDraft>(
  OnboardingDraftController.new,
);
