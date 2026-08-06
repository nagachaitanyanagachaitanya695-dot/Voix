import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/staggered.dart';
import 'settings_screen.dart';
import 'widgets/settings_tile.dart';

/// Help centre: expandable FAQs plus support entry points.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const _faqs = <(String, String)>[
    (
      'Does Voix work without internet?',
      'Yes. Lessons, the Gen-Z dictionary and the grammar coach all run '
          'on your device. Speech recognition uses your phone\'s built-in '
          'recogniser, which may need a connection on some devices.',
    ),
    (
      'The microphone is not working.',
      'Check that Voix has microphone permission in your device settings. '
          'If your phone has no speech recogniser installed, you can still '
          'type your replies — every conversation feature works either way.',
    ),
    (
      'How is my score calculated?',
      'Fluency reflects how much you said and how steadily you kept going. '
          'Pronunciation is based on how cleanly your speech was recognised. '
          'Confidence rewards longer turns without long pauses.',
    ),
    (
      'How do streaks work?',
      'Finish any lesson or conversation to count the day. Practise the very '
          'next day to extend the streak; miss two days in a row and it '
          'resets to one.',
    ),
    (
      'What is Gen-Z mode?',
      'A second register where the tutor speaks casually — slang, shortforms '
          'and internet language — and teaches you when to use it and when '
          'to switch back to formal English.',
    ),
    (
      'Will I lose my progress if I log out?',
      'Progress is stored on this device, so logging back in on the same '
          'phone restores it. Connect an account to sync across devices.',
    ),
  ];

  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SettingsBody(
      title: 'Help & Support',
      children: [
        const FadeSlideIn(
          child: SettingsHero(
            icon: Icons.headset_mic_rounded,
            title: "We're Here to Help",
            caption: 'Get support and answers to your questions.',
            color: VoixPalette.blue,
          ),
        ),
        Gap.h24,

        FadeSlideIn(
          index: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.xxs, bottom: Gap.xs),
              child: Text(
                'Frequently Asked',
                style: context.text.titleLarge,
              ),
            ),
          ),
        ),
        for (var i = 0; i < _faqs.length; i++)
          FadeSlideIn(
            index: (i + 2).clamp(0, 8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Gap.xs),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm + 2,
                  vertical: Gap.xs,
                ),
                onTap: () => setState(() {
                  _expanded.contains(i)
                      ? _expanded.remove(i)
                      : _expanded.add(i);
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 17,
                            color: c.primary,
                          ),
                          Gap.w12,
                          Expanded(
                            child: Text(
                              _faqs[i].$1,
                              style: context.text.titleSmall,
                            ),
                          ),
                          Icon(
                            _expanded.contains(i)
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: c.textTertiary,
                          ),
                        ],
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: Motion.base,
                      sizeCurve: Motion.enter,
                      crossFadeState: _expanded.contains(i)
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(29, 0, 0, Gap.sm),
                        child: Text(
                          _faqs[i].$2,
                          style: context.text.bodySmall?.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Gap.h20,

        FadeSlideIn(
          index: 8,
          child: SettingsGroup(
            title: 'Get Help',
            tiles: [
              SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'Contact Support',
                subtitle: 'Get help from our support team',
                onTap: () => showNotWiredUp(context, 'Support messaging'),
              ),
              SettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Report an Issue',
                subtitle: "Let us know if something isn't working",
                iconColor: VoixPalette.magenta,
                onTap: () => showNotWiredUp(context, 'Issue reporting'),
              ),
              SettingsTile(
                icon: Icons.star_outline_rounded,
                title: 'Rate Voix',
                subtitle: 'Leave a review on the Play Store',
                iconColor: VoixPalette.gold,
                onTap: () => showNotWiredUp(context, 'Store review'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
