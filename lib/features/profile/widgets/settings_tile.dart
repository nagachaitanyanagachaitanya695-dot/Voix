import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/context_ext.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';

/// A single row inside a settings group: icon, title, subtitle, and either a
/// chevron, a value, or a trailing control.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
    this.iconColor,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Right-aligned current value, e.g. "Male Voice".
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;

  /// Replaces the chevron — used for switches.
  final Widget? trailing;
  final Color? iconColor;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = destructive ? c.danger : (iconColor ?? c.primary);
    final titleColor = destructive ? c.danger : c.textPrimary;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall?.copyWith(color: titleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.text.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            Gap.w8,
            Flexible(
              child: Text(
                value!,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(
                  color: valueColor ?? c.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: Gap.xs),
              child: trailing!,
            )
          else if (showChevron && onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.textTertiary,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: '$title${subtitle == null ? '' : '. $subtitle'}',
      child: row,
    );
  }
}

/// Groups [tiles] into one card with hairline separators.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.tiles, this.title});

  final List<Widget> tiles;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: Gap.xxs, bottom: Gap.xs),
            child: Text(title!, style: context.text.titleLarge),
          ),
        ],
        GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm + 2,
            vertical: Gap.xxs,
          ),
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) Divider(color: c.border, height: 1),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero panel at the top of the settings sub-screens.
class SettingsHero extends StatelessWidget {
  const SettingsHero({
    super.key,
    required this.icon,
    required this.title,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Icon(icon, size: 27, color: color),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleLarge),
                Gap.h4,
                Text(
                  caption,
                  style: context.text.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard back-arrow header used by every settings sub-screen.
class SettingsAppBar extends StatelessWidget {
  const SettingsAppBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.page, Gap.md),
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
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Gap.w4,
          Expanded(
            child: Text(title, style: context.text.headlineSmall),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
