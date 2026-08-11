import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../utils/context_ext.dart';
import 'pressable.dart';

/// The ☰ button that sits to the left of a screen title in the design.
///
/// It opens Settings. The design shows the glyph but not what it opens, and a
/// menu button that does nothing is worse than no menu button — Settings is
/// the only destination on those screens that is not already a tab or a tile.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open settings',
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: Padding(
          // Padding rather than a fixed box, so the tap target stays a
          // comfortable size while the glyph keeps its optical alignment with
          // the title beside it.
          padding: const EdgeInsets.only(right: Gap.sm, top: Gap.xxs),
          child: Icon(
            Icons.menu_rounded,
            size: 24,
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
