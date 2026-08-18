import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_constants.dart';
import '../../providers/notifications_provider.dart';
import '../theme/app_colors.dart';

/// Bell icon with an unread-count badge dot, dropped into each tab
/// screen's [AppBar.actions]. Replaces the "Alerts" bottom-nav tab.
class NotificationBellAction extends ConsumerWidget {
  const NotificationBellAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: 'Alerts',
      onPressed: () => context.push(RouteConstants.notifications),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (count > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                key: const Key('notification-bell-badge'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.dark.primary : AppColors.primary,
                  border: Border.all(
                    color: isDark ? AppColors.dark.background : AppColors.background,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
