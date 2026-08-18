import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Bottom nav bar: 4 tab destinations plus a raised center button for
/// Create Event. Deliberately not a Material [NavigationBar] — that
/// widget only supports a flat row of [NavigationDestination]s, and
/// can't host a non-selectable raised center slot.
///
/// Layout notes (see design-system-nav final review for the bugs this
/// avoids): the widget is given an explicit total height via an outer
/// [SizedBox] rather than relying on `Expanded`/`Center`, because
/// `Scaffold.bottomNavigationBar` hands its child unbounded-looking but
/// actually full-screen-height `maxHeight` constraints — a flex
/// `Expanded(child: Center(...))` inside a `Row` would happily expand to
/// fill that, collapsing the rest of the screen. The raised FAB is placed
/// with [Positioned] inside a [Stack] that sits fully within those fixed
/// bounds — never [Transform.translate]d outside its layout box — so the
/// whole painted circle remains within the hit-testable region.
class MainNavBar extends StatelessWidget {
  const MainNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCreatePressed,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCreatePressed;

  static const _destinations = [
    (icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Calendar'),
    (icon: Icons.explore_outlined, activeIcon: Icons.explore, label: 'Feed'),
    (icon: Icons.people_outline, activeIcon: Icons.people, label: 'Friends'),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
  ];

  /// Height of the opaque bar band (background + top border), excluding
  /// any bottom safe-area inset. Matches the original (pre-FAB) bar height.
  static const double _barHeight = 62.0;

  /// Diameter of the raised center FAB.
  static const double _fabDiameter = 48.0;

  /// How far the FAB's vertical center sits above the bar's top edge.
  /// Chosen so the FAB's own top edge lands exactly at the top of the
  /// widget's total layout bounds (no overflow, no clipping).
  static const double _fabRaise = _fabDiameter / 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.dark.surface : AppColors.surface;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final primary = isDark ? AppColors.dark.primary : AppColors.primary;
    final inactive = isDark ? AppColors.dark.onSurfaceVariant : AppColors.onSurfaceVariant;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // First two destinations sit left of the FAB, last two sit right of it.
    final left = _destinations.sublist(0, 2);
    final right = _destinations.sublist(2, 4);

    Widget destinationItem(int index, ({IconData icon, IconData activeIcon, String label}) d) {
      final active = index == selectedIndex;
      return Expanded(
        child: Semantics(
          selected: active,
          button: true,
          label: d.label,
          child: InkWell(
            onTap: () => onDestinationSelected(index),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(active ? d.activeIcon : d.icon, size: 22, color: active ? primary : inactive),
                    const SizedBox(height: 4),
                    Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? primary : inactive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final totalHeight = _barHeight + _fabRaise + bottomInset;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // The bar surface: opaque background + top border, occupying only
          // the bottom band (plus safe-area inset). Wrapped in Material so
          // destination InkWells splash on the correct surface instead of
          // whatever Material ancestor happens to be behind this opaque
          // background (normally the Scaffold's, invisible under it).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _barHeight + bottomInset,
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Material(
                color: barColor,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      for (var i = 0; i < left.length; i++) destinationItem(i, left[i]),
                      // Empty spacer matching the FAB slot's flex share; the
                      // FAB itself is rendered separately below so its full
                      // circle stays within this widget's layout bounds.
                      const Expanded(child: SizedBox.shrink()),
                      for (var i = 0; i < right.length; i++) destinationItem(i + 2, right[i]),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The raised FAB. Positioned (not Transform.translate'd) so its
          // full painted circle sits inside the Stack's bounds and is fully
          // hit-testable everywhere it's visible.
          Positioned(
            left: 0,
            right: 0,
            bottom: _barHeight + bottomInset - _fabRaise,
            height: _fabDiameter,
            child: Center(
              child: Semantics(
                button: true,
                label: 'Create event',
                child: GestureDetector(
                  key: const Key('main-nav-bar-fab'),
                  onTap: onCreatePressed,
                  child: ExcludeSemantics(
                    child: Container(
                      width: _fabDiameter,
                      height: _fabDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
