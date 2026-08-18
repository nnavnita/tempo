import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Bottom nav bar: 4 tab destinations plus a raised center button for
/// Create Event. Deliberately not a Material [NavigationBar] — that
/// widget only supports a flat row of [NavigationDestination]s, and
/// can't host a non-selectable raised center slot.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? AppColors.dark.surface : AppColors.surface;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    final primary = isDark ? AppColors.dark.primary : AppColors.primary;
    final inactive = isDark ? AppColors.dark.onSurfaceVariant : AppColors.onSurfaceVariant;

    // First two destinations sit left of the FAB, last two sit right of it.
    final left = _destinations.sublist(0, 2);
    final right = _destinations.sublist(2, 4);

    Widget destinationItem(int index, ({IconData icon, IconData activeIcon, String label}) d) {
      final active = index == selectedIndex;
      return Expanded(
        child: InkWell(
          onTap: () => onDestinationSelected(index),
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
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < left.length; i++) destinationItem(i, left[i]),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: GestureDetector(
                  key: const Key('main-nav-bar-fab'),
                  onTap: onCreatePressed,
                  child: Container(
                    width: 48,
                    height: 48,
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
          for (var i = 0; i < right.length; i++) destinationItem(i + 2, right[i]),
        ],
      ),
    );
  }
}
