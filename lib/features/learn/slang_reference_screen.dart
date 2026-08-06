import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered.dart';
import '../../data/content/slang_catalog.dart';
import '../../providers/app_providers.dart';

/// Searchable Gen-Z reference: slang terms, chat shortforms, and what emoji
/// actually signal in use.
class SlangReferenceScreen extends ConsumerStatefulWidget {
  const SlangReferenceScreen({super.key});

  @override
  ConsumerState<SlangReferenceScreen> createState() =>
      _SlangReferenceScreenState();
}

class _SlangReferenceScreenState extends ConsumerState<SlangReferenceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  bool _matches(String a, String b) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return a.toLowerCase().contains(q) || b.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final terms = SlangCatalog.terms
        .where((t) => _matches(t.term, t.meaning))
        .toList();
    final shorts = SlangCatalog.shortforms.entries
        .where((e) => _matches(e.key, e.value))
        .toList();
    final emoji = SlangCatalog.emojiMeanings.entries
        .where((e) => _matches(e.key, e.value))
        .toList();

    return Scaffold(
      body: AuroraBackground(
        animate: false,
        colors: const [VoixPalette.violet, VoixPalette.magenta],
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.page, Gap.xs),
                child: Row(
                  children: [
                    Pressable(
                      onTap: () => Navigator.of(context).pop(),
                      scale: 0.9,
                      semanticLabel: 'Back',
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.xs),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    Gap.w4,
                    Expanded(
                      child: Text(
                        'Gen-Z Dictionary',
                        style: context.text.headlineSmall,
                      ),
                    ),
                    const Text('😎', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  style: context.text.bodyMedium?.copyWith(
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search slang, shortforms, emoji…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : Pressable(
                            onTap: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            scale: 0.85,
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: c.textTertiary,
                            ),
                          ),
                  ),
                ),
              ),

              Gap.h8,
              TabBar(
                controller: _tabs,
                indicatorColor: VoixPalette.magenta,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelColor: c.textPrimary,
                unselectedLabelColor: c.textTertiary,
                labelStyle: context.text.labelLarge?.copyWith(fontSize: 13.5),
                unselectedLabelStyle:
                    context.text.labelMedium?.copyWith(fontSize: 13.5),
                tabs: const [
                  Tab(text: 'Slang'),
                  Tab(text: 'Shortforms'),
                  Tab(text: 'Emoji'),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _List(
                      count: terms.length,
                      empty: 'No slang matches that.',
                      builder: (i) => _SlangRow(
                        emoji: terms[i].emoji,
                        term: terms[i].term,
                        meaning: terms[i].meaning,
                        example: terms[i].example,
                      ),
                    ),
                    _List(
                      count: shorts.length,
                      empty: 'No shortforms match that.',
                      builder: (i) => _SlangRow(
                        emoji: '💬',
                        term: shorts[i].key,
                        meaning: shorts[i].value,
                      ),
                    ),
                    _List(
                      count: emoji.length,
                      empty: 'No emoji match that.',
                      builder: (i) => _SlangRow(
                        emoji: emoji[i].key,
                        term: emoji[i].key,
                        meaning: emoji[i].value,
                        hideTermText: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.count,
    required this.builder,
    required this.empty,
  });

  final int count;
  final Widget Function(int) builder;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xxl),
          child: Text(empty, style: context.text.bodyMedium),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xxl),
      itemCount: count,
      separatorBuilder: (_, __) => Gap.h8,
      itemBuilder: (context, i) => FadeSlideIn(
        index: i.clamp(0, 8),
        offset: 14,
        child: builder(i),
      ),
    );
  }
}

class _SlangRow extends ConsumerWidget {
  const _SlangRow({
    required this.emoji,
    required this.term,
    required this.meaning,
    this.example,
    this.hideTermText = false,
  });

  final String emoji;
  final String term;
  final String meaning;
  final String? example;

  /// For the emoji tab, where the glyph *is* the term.
  final bool hideTermText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return GlassCard(
      padding: const EdgeInsets.all(Gap.sm + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: VoixPalette.magenta.withValues(alpha: 0.13),
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 19)),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hideTermText)
                  Text(term, style: context.text.titleSmall),
                if (!hideTermText) const SizedBox(height: 2),
                Text(
                  meaning,
                  style: context.text.bodySmall?.copyWith(
                    color: hideTermText ? c.textPrimary : c.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (example != null) ...[
                  Gap.h8,
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Gap.xs + 2,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: VoixPalette.magenta.withValues(alpha: 0.08),
                      borderRadius: Radii.rXs,
                    ),
                    child: Text(
                      '"$example"',
                      style: context.text.labelSmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!hideTermText)
            Pressable(
              onTap: () => ref.read(speechServiceProvider).speak(
                    example ?? term,
                  ),
              scale: 0.85,
              semanticLabel: 'Hear $term',
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: c.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
