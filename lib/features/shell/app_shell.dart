import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/utils/context_ext.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/aurora_background.dart';
import '../home/home_screen.dart';
import '../practice/practice_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';

/// Index of each root tab. Exposed so other screens can deep-link
/// (`AppShell.jumpTo(context, ShellTab.practice)`).
enum ShellTab { home, practice, progress, profile }

/// Root container: four tabs behind one persistent nav bar.
///
/// Pages are kept alive in an [IndexedStack] so scroll position, chart
/// selections and in-progress lesson state survive tab switches — moving
/// between tabs should feel like turning your head, not reloading.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTab = ShellTab.home});

  final ShellTab initialTab;

  /// Switches the enclosing shell to [tab] from anywhere below it.
  static void jumpTo(BuildContext context, ShellTab tab) {
    context.findAncestorStateOfType<_AppShellState>()?.select(tab.index);
  }

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index = widget.initialTab.index;

  void select(int index) {
    if (index == _index) return;
    Haptic.tap();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        // The backdrop drifts only on the two calmest tabs; elsewhere the
        // content is dense enough that the motion is invisible and the
        // per-frame repaint is wasted.
        animate: _index == ShellTab.home.index ||
            _index == ShellTab.practice.index,
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            PracticeScreen(),
            ProgressScreen(),
            ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: _VoixNavBar(
        index: _index,
        onSelect: select,
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Identifies the nav bar's outer padding so a test can assert it clears the
/// system gesture inset — the geometry is otherwise hard to pin down, because
/// the IndexedStack lays out every tab's content behind the visible one.
@visibleForTesting
const navBarPaddingKey = Key('voix.navbar.padding');

/// The largest bottom inset worth honouring. Three-button navigation is 48dp
/// and a gesture pill less; anything beyond this is a device reporting
/// nonsense, not a bar that needs clearing.
@visibleForTesting
const double maxSystemInset = 64;
const double _maxSystemInset = maxSystemInset;

class _VoixNavBar extends StatelessWidget {
  const _VoixNavBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  // Four tabs, matching the design. Lessons are not a tab: they are reached
  // from the Practice grid and from Home, and pushed as a full page.
  static const _items = [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.mic_none_rounded, Icons.mic_rounded, 'Practice'),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Progress'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      key: navBarPaddingKey,
      // The scaffold sets extendBody, so this bar is drawn over the system
      // gesture area rather than above it. The inset has to be added in full:
      // a fixed token was leaving the bottom of every icon and label sitting
      // underneath the gesture pill.
      //
      // Clamped, though. This padding sits below the bar, so whatever the
      // system reports is exactly how far up the screen the bar floats — and a
      // device that reports a nonsense inset puts the whole navigation in the
      // middle of the page. No Android navigation area is anywhere near 64dp,
      // so a larger figure is wrong by definition and is not worth honouring.
      padding: EdgeInsets.fromLTRB(
        Gap.sm,
        0,
        Gap.sm,
        math.min(context.safeArea.bottom, _maxSystemInset) + Gap.sm,
      ),
      child: Container(
        // A floor, not a fixed height: the labels grow with the system text
        // size, and a hard 66 clipped them at large accessibility scales.
        constraints: const BoxConstraints(minHeight: 66),
        decoration: BoxDecoration(
          color: c.isDark
              ? c.surface.withValues(alpha: 0.94)
              : c.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(Radii.xl),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavButton(
                  item: _items[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Selected tab inverts: a light pill with dark content, matching the
    // reference. In light mode it flips to the brand colour so contrast holds.
    final pillColor = c.isDark ? Colors.white : c.primary;
    final activeContent = c.isDark ? c.primary : Colors.white;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: Motion.base,
            curve: Motion.enter,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? Gap.sm : Gap.xs,
              vertical: Gap.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? pillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 22,
                  color: selected ? activeContent : c.textTertiary,
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 10,
                    height: 1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? activeContent : c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
