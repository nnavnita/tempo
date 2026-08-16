import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ProviderRef;
import 'package:go_router/go_router.dart';
import '../../core/constants/route_constants.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/events/screens/create_event_screen.dart';
import '../../features/events/screens/edit_event_screen.dart';
import '../../features/events/screens/event_detail_screen.dart';
import '../../features/feed/screens/friends_feed_screen.dart';
import '../../features/friends/screens/friend_requests_screen.dart';
import '../../features/friends/screens/friends_list_screen.dart';
import '../../features/friends/screens/user_search_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to auth state for redirect
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // Wait for Firebase to restore the cached session before redirecting.
      if (authState.isLoading) return null;

      final isSignedIn = authState.valueOrNull != null;
      final onLogin = state.matchedLocation == RouteConstants.login;

      if (!isSignedIn && !onLogin) return RouteConstants.login;
      if (isSignedIn && onLogin) return RouteConstants.calendar;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _MainShell(child: child, state: state),
        routes: [
          GoRoute(
            path: RouteConstants.calendar,
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: RouteConstants.feed,
            builder: (context, state) => const FriendsFeedScreen(),
          ),
          GoRoute(
            path: RouteConstants.friends,
            builder: (context, state) => const FriendsListScreen(),
            routes: [
              GoRoute(
                path: 'requests',
                builder: (context, state) => const FriendRequestsScreen(),
              ),
              GoRoute(
                path: 'search',
                builder: (context, state) => const UserSearchScreen(),
              ),
            ],
          ),
          GoRoute(
            path: RouteConstants.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: RouteConstants.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: RouteConstants.createEvent,
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/event/:eventId',
        builder: (context, state) {
          final eventId = state.pathParameters['eventId']!;
          return EventDetailScreen(eventId: eventId);
        },
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return EditEventScreen(eventId: eventId);
            },
          ),
        ],
      ),
    ],
  );
});

/// Notifies the router whenever auth state changes.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

/// Bottom navigation shell wrapping the main tab screens.
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child, required this.state});

  final Widget child;
  final GoRouterState state;

  int _currentIndex(String location) {
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/feed')) return 1;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = state.matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex(location),
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                context.go(RouteConstants.calendar);
              case 1:
                context.go(RouteConstants.feed);
              case 2:
                context.go(RouteConstants.friends);
              case 3:
                context.go(RouteConstants.notifications);
              case 4:
                context.go(RouteConstants.profile);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Friends',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
