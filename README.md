# Voix

**Your personal AI language tutor.** Voix teaches you to speak confidently by
having real conversations with an AI tutor that corrects your grammar,
upgrades your vocabulary, and explains *why* — not just *what*.

Built with Flutter + Riverpod. Dark and light themes, 60 FPS hand-rolled
animations, and full offline capability.

---

## Getting started

```bash
flutter pub get
flutter run
```

That's it — no backend, no API keys, no config files. The app runs end to end
on a fresh clone.

Requires Flutter 3.35+ (Dart 3.5+).

```bash
flutter analyze   # 0 issues
flutter test      # 52 tests
```

---

## What's in the box

| Area | State |
|---|---|
| Splash, onboarding (11 steps), auth | Complete |
| Home, Learn, Practice, Progress, Profile | Complete |
| AI conversation + coaching report | Complete, on-device |
| 14 lessons / 6 exercise types | Complete |
| 13 roleplay scenarios (Standard + Gen-Z) | Complete |
| XP, levels, streaks, 12 achievements | Complete |
| Settings, notifications, privacy, help | Complete |
| Speech-to-text / text-to-speech | Complete (device engines) |
| Google / Apple sign-in | Needs Firebase — see `docs/FIREBASE_SETUP.md` |
| Push notification *delivery* | Needs a plugin — see `docs/BACKEND.md` |
| Play Billing for Pro | Not wired — see `docs/BACKEND.md` |

---

## Architecture

```
lib/
  core/
    theme/      Design tokens: colour, type, spacing, motion, gradients
    utils/      Context extensions, haptics
    widgets/    The shared kit — buttons, cards, charts, orb, logo, waveform
  data/
    models/     Immutable domain types with JSON round-trips
    content/    Lessons, scenarios, slang — typed Dart, not JSON
    services/   Grammar engine, AI tutor, speech
    repositories/ Storage + auth behind interfaces
  providers/    Riverpod controllers (user, activity, sessions, conversation)
  features/     One folder per screen area
```

**Dependency rule:** `features` → `providers` → `data` → `core`. Nothing points
back up. Every screen reads state through Riverpod; no screen constructs a
repository directly.

**Swappable seams.** `AuthRepository` and `AiTutorService` are interfaces with
a single wiring point each in `lib/providers/app_providers.dart`. Replacing the
local implementation with Firebase or a hosted LLM is a one-line override — no
UI change.

---

## Three things worth knowing

### 1. Grammar correction runs on-device

`lib/data/services/grammar_engine.dart` is a rule engine covering the mistakes
learners actually make: subject–verb agreement (with irregular and -ies/-es
forms), tense after *did*, articles by vowel *sound*, uncountable nouns, double
negatives, double comparatives, and a set of common Indian-English idioms
(*discuss about*, *out of station*, *revert back*, *a doubt*).

Running locally is what makes real-time correction viable — there's no round
trip between finishing a sentence and seeing the fix. Rules are ordered
most-specific-first and each span is corrected at most once, so overlapping
rules can't produce contradictory advice. When several rules fire, each
contributes its own explanation but they share one fully-corrected sentence.

It's tested against both directions: it must catch `"Did you went there?"`
*and* leave `"I doubt it will rain"` alone.

### 2. The visuals are vectors, not assets

The splash orb, the VOIX mark, the waveform, every chart, and the level badge
are `CustomPainter`s. The app ships no raster art beyond the launcher icon, so
it stays crisp at every density and the mark can animate its own stroke.

The aurora backdrop deliberately avoids `BackdropFilter`: it paints three
oversized radial blooms into one layer. Stacked blur filters are the usual
reason a dark gradient UI drops frames on mid-range Android.

### 3. Voice degrades, never blocks

`SpeechService` guards every platform call. No recogniser, denied permission,
or a plain emulator all resolve to the same outcome: the conversation screen
switches to typed input and says why. The core feature is never unreachable.

---

## Design system

Everything derives from `lib/core/theme/`. Colours are a `ThemeExtension`, so
widgets read `context.colors.textSecondary` and get the right value for the
active brightness without branching.

- **Brand ramp** cyan `#22D8F0` → blue `#3B7BFF` → violet `#8B5CF6` — the
  splash orb cooling into the wordmark glow.
- **Type** Plus Jakarta Sans for UI, Manrope for figures (XP, streaks, scores).
  Bundled as static instances generated from the variable fonts.
- **Motion** 160/260/420ms. Short on purpose. `Pressable` replaces the Material
  ripple app-wide with a scale press, so every tappable surface responds the
  same way.

---

## Accessibility

- OS text scaling honoured up to 1.3×, clamped so fixed-height chrome survives.
- Semantic labels on icon buttons, charts, achievements, and score rings.
- Haptics respect the user's setting through a single `Haptic.enabled` gate.
- Cards size to a *minimum* height, so larger text grows the layout instead of
  clipping it.

---

## Tests

```
test/grammar_engine_test.dart   22  correction rules, both directions
test/user_progress_test.dart    22  level curve, streaks, achievements, JSON
test/app_smoke_test.dart         8  every screen builds; nav and filters work
```

The widget tests use a tall surface and repeated pumps rather than
`pumpAndSettle` — the aurora and orb animate forever by design, so the tree
never quiesces.

---

## Licence

Fonts: Plus Jakarta Sans and Manrope, SIL Open Font License 1.1.
