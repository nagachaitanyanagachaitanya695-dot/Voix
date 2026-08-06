# Backend integrations

What is deliberately not wired in this build, and how to finish each piece.
Every item below is behind an interface or a single call site — none require
restructuring.

---

## 1. Hosted LLM tutor

`LocalAiTutorService` produces the conversation and the coaching report fully
on-device. It is deterministic, works offline, and is what makes correction
feel instant. For richer open-ended dialogue, add a hosted model **behind your
own backend**.

> **Never put a provider API key in the app.** An APK is a zip file; anyone can
> extract a string constant from it. Route calls through a server you control
> that holds the key and enforces per-user rate limits.

Implement the existing interface:

```dart
class RemoteAiTutorService implements AiTutorService {
  RemoteAiTutorService(this._client, {required this.baseUrl});

  final http.Client _client;
  final String baseUrl;   // your backend, not the model provider

  @override
  Future<TutorTurn> respond({
    required Scenario scenario,
    required List<ChatMessage> history,
    required String userMessage,
    required UserProfile user,
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$baseUrl/tutor/respond'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'scenarioId': scenario.id,
              'mode': user.mode.name,
              'proficiency': user.proficiency.name,
              'nativeLanguage': user.nativeLanguageCode,
              'history': history.map((m) => m.toJson()).toList(),
              'message': userMessage,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return _fallback(scenario, history, userMessage, user);

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return TutorTurn(
        reply: json['reply'] as String,
        corrections: [
          // Merge the model's corrections on top of the local engine's, so a
          // timeout still leaves the learner with real feedback.
          ...GrammarEngine.analyse(userMessage),
          ...(json['corrections'] as List? ?? [])
              .map((e) => Correction.fromJson(e as Map<String, dynamic>)),
        ],
      );
    } catch (_) {
      return _fallback(scenario, history, userMessage, user);
    }
  }

  Future<TutorTurn> _fallback(...) =>
      LocalAiTutorService().respond(...);   // never leave the learner stuck
}
```

Wire it in `lib/providers/app_providers.dart`:

```dart
final aiTutorProvider = Provider<AiTutorService>(
  (ref) => RemoteAiTutorService(http.Client(), baseUrl: const String.fromEnvironment('VOIX_API')),
);
```

Keep the local service as the fallback path. A language app that stops working
on a bad connection stops being used.

### Suggested server prompt shape

The system prompt should carry: the scenario's role and opening, the learner's
proficiency (to cap vocabulary), their native language (to explain in it), and
the active mode (`standard` vs `genZ`). Ask for structured JSON —
`{reply, corrections[], vocabulary[], slang[]}` — rather than parsing prose.

---

## 2. Local notifications

The reminder preferences (`remindersEnabled`, `reminderHour`,
`reminderMinute`) are already persisted on `UserProfile` and editable in
Settings → Notifications. Only *delivery* is missing.

```bash
flutter pub add flutter_local_notifications timezone
```

Schedule a daily repeat whenever the preference changes:

```dart
await plugin.zonedSchedule(
  0,
  'Time to practise 🎙️',
  'Keep your ${user.currentStreak}-day streak alive.',
  _nextInstanceOf(user.reminderHour, user.reminderMinute),
  const NotificationDetails(
    android: AndroidNotificationDetails(
      'practice_reminders', 'Practice reminders',
      importance: Importance.high,
    ),
  ),
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
);
```

`POST_NOTIFICATIONS` is already declared in the manifest; request it at runtime
on Android 13+. Use `inexact` scheduling — exact alarms need a special-use
permission that Play will question for a habit reminder.

---

## 3. Play Billing for Pro

`UserProfile.isPro` gates Pro scenarios and lessons throughout the app; the
upgrade sheet in Profile is the single purchase entry point.

```bash
flutter pub add in_app_purchase
```

Create the product in Play Console, then on a successful purchase:

```dart
await ref.read(userControllerProvider.notifier)
    .update((u) => u.copyWith(isPro: true));
```

**Verify receipts server-side** before granting entitlement, and restore
purchases on launch — a client-only `isPro` flag is trivially bypassed and will
also be wrong after a reinstall.

---

## 4. Crash reporting and analytics

Nothing is instrumented. When you add it, the events worth tracking are the
ones that predict retention: conversation completed, lesson completed, streak
extended, streak broken, and the onboarding step where people drop out.

Ask for consent before enabling collection, and expose the toggle under
Settings → Privacy alongside the existing controls.
