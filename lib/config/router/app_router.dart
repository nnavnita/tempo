import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ProviderRef;
import 'package:go_router/go_router.dart';
import '../../core/constants/route_constants.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/capture/screens/capture_screen.dart';
import '../../features/plan/screens/plan_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/triage/screens/triage_screen.dart';
import '../../providers/auth_provider.dart';
import 'main_nav_bar.dart';

final routerProvider = Provider<GoRouter>((ref) {
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
      if (isSignedIn && onLogin) return RouteConstants.plan;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteConstants.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _MainShell(state: state, child: child),
        routes: [
          GoRoute(
            path: RouteConstants.plan,
            builder: (context, state) => const PlanScreen(),
          ),
          GoRoute(
            path: RouteConstants.horizon,
            builder: (context, state) => const HorizonScreen(),
          ),
          GoRoute(
            path: RouteConstants.triage,
            builder: (context, state) => const TriageScreen(),
          ),
          GoRoute(
            path: RouteConstants.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Outside the shell so capture covers the nav bar — it is a modal
      // task, not a tab.
      GoRoute(
        path: RouteConstants.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
    ],
  );
});

/// Notifies the router whenever auth state changes.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

/// Bottom navigation shell wrapping the main tab screens.
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child, required this.state});

  final Widget child;
  final GoRouterState state;

  int _currentIndex(String location) {
    if (location.startsWith(RouteConstants.horizon)) return 1;
    if (location.startsWith(RouteConstants.triage)) return 2;
    if (location.startsWith(RouteConstants.profile)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = state.matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: MainNavBar(
        selectedIndex: _currentIndex(location),
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go(RouteConstants.plan);
            case 1:
              context.go(RouteConstants.horizon);
            case 2:
              context.go(RouteConstants.triage);
            case 3:
              context.go(RouteConstants.profile);
          }
        },
        onCreatePressed: () => context.push(RouteConstants.capture),
      ),
    );
  }
}
