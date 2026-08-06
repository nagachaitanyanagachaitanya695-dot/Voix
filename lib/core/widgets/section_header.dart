import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';
import '../utils/context_ext.dart';
import 'pressable.dart';

/// `Section title            Action ›` — the standard heading above every
/// content group on the home, progress, and learn screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
    this.leading,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, Gap.w8],
          Expanded(
            child: Text(
              title,
              style: context.text.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              onTap: onAction,
              scale: 0.94,
              semanticLabel: '$actionLabel, $title',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.xs,
                  vertical: Gap.xxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel!,
                      style: context.text.labelMedium?.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: c.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small numbered pill used to index the sections of the conversation summary
/// ("1 Grammar Corrections", "2 Vocabulary", …).
class NumberBadge extends StatelessWidget {
  const NumberBadge({
    super.key,
    required this.number,
    required this.color,
    this.size = 24,
  });

  final int number;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
