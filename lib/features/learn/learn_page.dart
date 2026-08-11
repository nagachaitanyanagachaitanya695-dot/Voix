import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/widgets/aurora_background.dart';
import '../../core/widgets/pressable.dart';
import 'learn_screen.dart';

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
              const Expanded(child: LearnScreen()),
            ],
          ),
        ),
      ),
    );
  }
}
