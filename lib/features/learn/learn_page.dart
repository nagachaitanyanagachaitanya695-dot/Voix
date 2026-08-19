import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import 'learn_screen.dart';
import 'word_sheet.dart';

/// Lessons, opened as a full page.
///
/// Lessons are not one of the four tabs in the design — they are reached from
/// the Practice grid and from Home. [LearnScreen] is written to sit inside the
/// shell, with no chrome of its own, so this supplies the backdrop and the way
/// back out.
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: Gap.sm, top: Gap.xs),
                  child: Pressable(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xs),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const _WordLookupField(),
              const Expanded(child: LearnScreen()),
            ],
          ),
        ),
      ),
    );
  }
}

/// "What does this word mean?" — the question a learner has most often, and
/// the one that otherwise sends them out of the app to a dictionary.
///
/// Sits above the lessons rather than inside them: the word someone is stuck
/// on is usually not from the lesson they are looking at.
class _WordLookupField extends StatefulWidget {
  const _WordLookupField();

  @override
  State<_WordLookupField> createState() => _WordLookupFieldState();
}

class _WordLookupFieldState extends State<_WordLookupField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ask() {
    final word = _controller.text.trim();
    if (word.isEmpty) return;
    // Cleared before opening, so coming back from the sheet does not leave the
    // last word sitting in the box looking like it is still being asked.
    _controller.clear();
    FocusScope.of(context).unfocus();
    showWordSheet(context, word);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, Gap.sm),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        onSubmitted: (_) => _ask(),
        decoration: InputDecoration(
          hintText: 'Any word you are stuck on',
          prefixIcon: Icon(Icons.search_rounded, color: c.textTertiary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _ask,
            tooltip: 'Explain it',
          ),
        ),
      ),
    );
  }
}
