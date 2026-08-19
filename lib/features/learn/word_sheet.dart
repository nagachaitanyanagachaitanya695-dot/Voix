import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/word_insight.dart';
import '../../data/services/word_service.dart';
import '../../providers/app_providers.dart';
import '../../providers/user_controller.dart';

/// Opens the word sheet for [word].
///
/// Reachable from anywhere a word appears, because the moment someone does not
/// know a word is the moment they stop reading — and making them leave the
/// sentence to find out is how they lose the thread.
Future<void> showWordSheet(BuildContext context, String word) {
  Haptic.tap();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WordSheet(word: word),
  );
}

class _WordSheet extends ConsumerStatefulWidget {
  const _WordSheet({required this.word});
  final String word;

  @override
  ConsumerState<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<_WordSheet> {
  /// Starts as what the on-device rules know, so the sheet has content in the
  /// first frame rather than a spinner over nothing.
  late WordInsight _insight = WordService.local(widget.word);
  bool _loading = BackendConfig.isConfigured;

  @override
  void initState() {
    super.initState();
    if (_loading) _deepen();
  }

  Future<void> _deepen() async {
    final user = ref.read(userControllerProvider);
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    final full = await ref.read(wordServiceProvider).lookUp(
          widget.word,
          user: user,
          deviceId: ref.read(deviceIdProvider),
        );
    if (!mounted) return;
    setState(() {
      _insight = full;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final speech = ref.read(speechServiceProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: c.border),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: Gap.lg),
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── The word itself ───────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _insight.word,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                      if (_insight.pronunciation.isNotEmpty)
                        Text(
                          _insight.pronunciation,
                          style: TextStyle(fontSize: 15, color: c.textSecondary),
                        ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {
                    Haptic.tap();
                    speech.speak(_insight.word);
                  },
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: 'Hear it',
                ),
              ],
            ),

            if (_insight.nativeMeaning.isNotEmpty) ...[
              Gap.h12,
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  _insight.nativeMeaning,
                  style: TextStyle(fontSize: 17, color: c.textPrimary),
                ),
              ),
            ],

            if (_loading) ...[
              Gap.h20,
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Gap.w12,
                  Text(
                    'Looking it up…',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ],
              ),
            ],

            // ── Meanings ──────────────────────────────────────────────
            if (_insight.hasSenses) ...[
              Gap.h24,
              _Heading('Meaning'),
              for (final sense in _insight.senses) ...[
                Gap.h12,
                _SenseCard(sense: sense),
              ],
            ],

            // ── Forms ─────────────────────────────────────────────────
            if (_insight.hasForms) ...[
              Gap.h24,
              _Heading('Other forms'),
              Gap.h12,
              Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    for (final e in _insight.forms.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.md,
                          vertical: Gap.sm,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 108,
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textTertiary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                e.value,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ── Where it came from ────────────────────────────────────
            if (_insight.origin.isNotEmpty) ...[
              Gap.h24,
              _Heading('Where it comes from'),
              Gap.h8,
              Text(
                _insight.origin,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: c.textSecondary,
                ),
              ),
            ],

            if (_insight.synonyms.isNotEmpty) ...[
              Gap.h24,
              _Heading('Similar words'),
              Gap.h8,
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final s in _insight.synonyms)
                    ActionChip(
                      label: Text(s),
                      // Tapping one looks it up in turn, so following a word
                      // into its neighbours never dead-ends.
                      onPressed: () {
                        Navigator.of(context).pop();
                        showWordSheet(context, s);
                      },
                    ),
                ],
              ),
            ],

            // ── What is missing, and why ──────────────────────────────
            if (!_loading && !_insight.isComplete) ...[
              Gap.h24,
              Container(
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  BackendConfig.isConfigured
                      ? 'Could not reach the tutor, so this is only what the '
                          'app can work out on its own.'
                      : 'Meanings, history and examples need the tutor to be '
                          'set up. The forms above are worked out on your '
                          'phone and always work.',
                  style: TextStyle(fontSize: 13, color: c.textTertiary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: context.colors.textTertiary,
        ),
      );
}

class _SenseCard extends StatelessWidget {
  const _SenseCard({required this.sense});
  final WordSense sense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sense.partOfSpeech.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: VoixPalette.violet.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sense.partOfSpeech,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VoixPalette.violet,
                ),
              ),
            ),
          Gap.h8,
          Text(
            sense.definition,
            style: TextStyle(fontSize: 16, height: 1.4, color: c.textPrimary),
          ),
          for (final example in sense.examples) ...[
            Gap.h8,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: c.textTertiary,
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    example,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
