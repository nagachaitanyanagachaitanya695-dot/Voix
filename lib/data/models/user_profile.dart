import 'package:flutter/foundation.dart';

/// Which conversational register the tutor should use.
enum LearningMode {
  standard('Standard', 'Learn everyday English', '💬'),
  genZ('Gen-Z', 'Learn Gen-Z slang & shortforms', '😎');

  const LearningMode(this.label, this.description, this.emoji);
  final String label;
  final String description;
  final String emoji;
}

/// Self-declared starting ability, used to pick lesson difficulty and to set
/// the tutor's vocabulary ceiling.
enum Proficiency {
  beginner('Beginner', 'I know basic words'),
  intermediate('Intermediate', 'I can make simple conversations'),
  advanced('Advanced', 'I can speak fluently');

  const Proficiency(this.label, this.description);
  final String label;
  final String description;
}

/// What the learner does day to day — shapes roleplay scenario suggestions.
enum Occupation {
  schoolStudent('School Student', '🎒'),
  collegeStudent('College Student', '🎓'),
  working('Working Professional', '💼'),
  other('Other', '✨');

  const Occupation(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// The learner's primary motivation, shown back to them in onboarding and
/// used to order the lesson catalogue.
enum LearningGoal {
  speakConfidently('Speak Confidently', '🗣️'),
  career('Career Opportunities', '📈'),
  studyAbroad('Study Abroad', '🌍'),
  exam('Exam Preparation', '📝'),
  other('Other', '✨');

  const LearningGoal(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum TutorVoice {
  male('Male Voice', 'en-US-male'),
  female('Female Voice', 'en-US-female');

  const TutorVoice(this.label, this.id);
  final String label;
  final String id;
}

/// The complete learner record. Immutable; every mutation goes through
/// [copyWith] inside `UserController` so state changes stay traceable.
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
    this.isGuest = false,
    this.isPro = false,
    this.xp = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.dailyGoalMinutes = 10,
    this.minutesToday = 0,
    this.nativeLanguageCode = 'te',
    this.learningLanguageCode = 'en',
    this.proficiency = Proficiency.beginner,
    this.occupation = Occupation.schoolStudent,
    this.goal = LearningGoal.speakConfidently,
    this.tutorVoice = TutorVoice.male,
    this.mode = LearningMode.standard,
    this.totalConversations = 0,
    this.totalMinutes = 0,
    this.wordsLearned = 0,
    this.completedLessonIds = const <String>{},
    this.unlockedAchievementIds = const <String>{},
    this.lastActiveDate,
    this.reminderHour = 19,
    this.reminderMinute = 0,
    this.remindersEnabled = true,
    this.goalUpdatesEnabled = true,
    this.streakAlertsEnabled = true,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
  });

  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final bool isGuest;
  final bool isPro;

  final int xp;
  final int currentStreak;
  final int longestStreak;
  final int dailyGoalMinutes;
  final int minutesToday;

  final String nativeLanguageCode;
  final String learningLanguageCode;
  final Proficiency proficiency;
  final Occupation occupation;
  final LearningGoal goal;
  final TutorVoice tutorVoice;
  final LearningMode mode;

  final int totalConversations;
  final int totalMinutes;
  final int wordsLearned;
  final Set<String> completedLessonIds;
  final Set<String> unlockedAchievementIds;

  /// Midnight-normalised date of the last completed practice, used by the
  /// streak rules in `UserController.registerPractice`.
  final DateTime? lastActiveDate;

  final int reminderHour;
  final int reminderMinute;

  /// The daily practice nudge, delivered at [reminderHour]:[reminderMinute].
  final bool remindersEnabled;

  /// An afternoon check-in on the daily-minutes goal.
  final bool goalUpdatesEnabled;

  /// A late-evening warning when a streak is about to lapse.
  final bool streakAlertsEnabled;

  final bool soundEnabled;
  final bool hapticsEnabled;

  // ── Derived level maths ────────────────────────────────────────────────
  // The first few levels are cheap so a new learner sees progress on day one,
  // then the cost settles at a flat 250 XP per level.
  //
  // The numbers are pinned to the design: 1,250 XP must read as Level 8 with
  // 250 XP to Level 9. That falls out of costs of 50, 100, 150, 200, then 250
  // from level 5 onward — cumulative 0, 50, 150, 300, 500, 750, 1000, 1250,
  // 1500. Change these and the screens stop matching the design.
  static const _flatCost = 250;
  static const _rampStep = 50;

  /// Total XP required to *reach* [level]. Level 1 starts at 0.
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    // Below the point where the ramp reaches the flat cost, this is the sum of
    // an arithmetic series; above it, that sum plus a flat run.
    const rampLevels = _flatCost ~/ _rampStep; // 5
    final n = level - 1;
    if (n <= rampLevels) {
      return _rampStep * n * (n + 1) ~/ 2;
    }
    const rampTotal = _rampStep * rampLevels * (rampLevels + 1) ~/ 2;
    return rampTotal + _flatCost * (n - rampLevels);
  }

  int get level {
    var l = 1;
    while (xp >= xpForLevel(l + 1)) {
      l++;
      if (l > 200) break; // hard stop; guards against overflow
    }
    return l;
  }

  int get xpAtCurrentLevel => xp - xpForLevel(level);
  int get xpNeededForNextLevel => xpForLevel(level + 1) - xpForLevel(level);
  int get xpToNextLevel => xpForLevel(level + 1) - xp;

  double get levelProgress {
    final need = xpNeededForNextLevel;
    return need == 0 ? 0 : (xpAtCurrentLevel / need).clamp(0.0, 1.0);
  }

  /// Human-readable rank shown next to the level badge.
  String get levelTitle {
    // Level 8 must read "Fluent Speaker" — it is what the design shows beside
    // 1,250 XP.
    final l = level;
    if (l >= 16) return 'Native-Like';
    if (l >= 12) return 'Master';
    if (l >= 8) return 'Fluent Speaker';
    if (l >= 6) return 'Advanced';
    if (l >= 4) return 'Intermediate';
    if (l >= 2) return 'Elementary';
    return 'Beginner';
  }

  double get goalProgress => dailyGoalMinutes == 0
      ? 0
      : (minutesToday / dailyGoalMinutes).clamp(0.0, 1.0);

  bool get goalMetToday => minutesToday >= dailyGoalMinutes;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'V';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    bool? isGuest,
    bool? isPro,
    int? xp,
    int? currentStreak,
    int? longestStreak,
    int? dailyGoalMinutes,
    int? minutesToday,
    String? nativeLanguageCode,
    String? learningLanguageCode,
    Proficiency? proficiency,
    Occupation? occupation,
    LearningGoal? goal,
    TutorVoice? tutorVoice,
    LearningMode? mode,
    int? totalConversations,
    int? totalMinutes,
    int? wordsLearned,
    Set<String>? completedLessonIds,
    Set<String>? unlockedAchievementIds,
    DateTime? lastActiveDate,
    int? reminderHour,
    int? reminderMinute,
    bool? remindersEnabled,
    bool? goalUpdatesEnabled,
    bool? streakAlertsEnabled,
    bool? soundEnabled,
    bool? hapticsEnabled,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isGuest: isGuest ?? this.isGuest,
      isPro: isPro ?? this.isPro,
      xp: xp ?? this.xp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      minutesToday: minutesToday ?? this.minutesToday,
      nativeLanguageCode: nativeLanguageCode ?? this.nativeLanguageCode,
      learningLanguageCode: learningLanguageCode ?? this.learningLanguageCode,
      proficiency: proficiency ?? this.proficiency,
      occupation: occupation ?? this.occupation,
      goal: goal ?? this.goal,
      tutorVoice: tutorVoice ?? this.tutorVoice,
      mode: mode ?? this.mode,
      totalConversations: totalConversations ?? this.totalConversations,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      unlockedAchievementIds:
          unlockedAchievementIds ?? this.unlockedAchievementIds,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      goalUpdatesEnabled: goalUpdatesEnabled ?? this.goalUpdatesEnabled,
      streakAlertsEnabled: streakAlertsEnabled ?? this.streakAlertsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'isPro': isPro,
        'xp': xp,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'dailyGoalMinutes': dailyGoalMinutes,
        'minutesToday': minutesToday,
        'nativeLanguageCode': nativeLanguageCode,
        'learningLanguageCode': learningLanguageCode,
        'proficiency': proficiency.name,
        'occupation': occupation.name,
        'goal': goal.name,
        'tutorVoice': tutorVoice.name,
        'mode': mode.name,
        'totalConversations': totalConversations,
        'totalMinutes': totalMinutes,
        'wordsLearned': wordsLearned,
        'completedLessonIds': completedLessonIds.toList(),
        'unlockedAchievementIds': unlockedAchievementIds.toList(),
        'lastActiveDate': lastActiveDate?.toIso8601String(),
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'remindersEnabled': remindersEnabled,
        'goalUpdatesEnabled': goalUpdatesEnabled,
        'streakAlertsEnabled': streakAlertsEnabled,
        'soundEnabled': soundEnabled,
        'hapticsEnabled': hapticsEnabled,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      if (raw is! String) return fallback;
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    return UserProfile(
      id: j['id'] as String? ?? 'local',
      name: j['name'] as String? ?? 'Learner',
      email: j['email'] as String?,
      photoUrl: j['photoUrl'] as String?,
      isGuest: j['isGuest'] as bool? ?? false,
      isPro: j['isPro'] as bool? ?? false,
      xp: (j['xp'] as num?)?.toInt() ?? 0,
      currentStreak: (j['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (j['longestStreak'] as num?)?.toInt() ?? 0,
      dailyGoalMinutes: (j['dailyGoalMinutes'] as num?)?.toInt() ?? 10,
      minutesToday: (j['minutesToday'] as num?)?.toInt() ?? 0,
      nativeLanguageCode: j['nativeLanguageCode'] as String? ?? 'te',
      learningLanguageCode: j['learningLanguageCode'] as String? ?? 'en',
      proficiency:
          pick(Proficiency.values, j['proficiency'], Proficiency.beginner),
      occupation:
          pick(Occupation.values, j['occupation'], Occupation.schoolStudent),
      goal: pick(LearningGoal.values, j['goal'], LearningGoal.speakConfidently),
      tutorVoice: pick(TutorVoice.values, j['tutorVoice'], TutorVoice.male),
      mode: pick(LearningMode.values, j['mode'], LearningMode.standard),
      totalConversations: (j['totalConversations'] as num?)?.toInt() ?? 0,
      totalMinutes: (j['totalMinutes'] as num?)?.toInt() ?? 0,
      wordsLearned: (j['wordsLearned'] as num?)?.toInt() ?? 0,
      completedLessonIds:
          (j['completedLessonIds'] as List?)?.cast<String>().toSet() ??
              const <String>{},
      unlockedAchievementIds:
          (j['unlockedAchievementIds'] as List?)?.cast<String>().toSet() ??
              const <String>{},
      lastActiveDate: j['lastActiveDate'] == null
          ? null
          : DateTime.tryParse(j['lastActiveDate'] as String),
      reminderHour: (j['reminderHour'] as num?)?.toInt() ?? 19,
      reminderMinute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
      remindersEnabled: j['remindersEnabled'] as bool? ?? true,
      goalUpdatesEnabled: j['goalUpdatesEnabled'] as bool? ?? true,
      streakAlertsEnabled: j['streakAlertsEnabled'] as bool? ?? true,
      soundEnabled: j['soundEnabled'] as bool? ?? true,
      hapticsEnabled: j['hapticsEnabled'] as bool? ?? true,
    );
  }

  /// A fresh profile for a newly signed-in or guest learner.
  factory UserProfile.initial({
    required String id,
    required String name,
    String? email,
    bool isGuest = false,
  }) =>
      UserProfile(id: id, name: name, email: email, isGuest: isGuest);
}
