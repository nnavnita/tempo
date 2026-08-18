// test/core/widgets/notification_bell_action_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tempo/core/widgets/notification_bell_action.dart';
import 'package:tempo/providers/notifications_provider.dart';

Widget _wrap(Widget child, {required int count}) {
  return ProviderScope(
    overrides: [notificationCountProvider.overrideWithValue(count)],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, __) => child),
          GoRoute(
            path: '/notifications',
            builder: (_, __) => const Text('Notifications Screen'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('shows no badge dot when count is 0', (tester) async {
    await tester.pumpWidget(_wrap(
      Scaffold(appBar: AppBar(actions: const [NotificationBellAction()])),
      count: 0,
    ));

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.byKey(const Key('notification-bell-badge')), findsNothing);
  });

  testWidgets('shows badge dot when count is greater than 0', (tester) async {
    await tester.pumpWidget(_wrap(
      Scaffold(appBar: AppBar(actions: const [NotificationBellAction()])),
      count: 3,
    ));

    expect(find.byKey(const Key('notification-bell-badge')), findsOneWidget);
  });

  testWidgets('tapping the bell navigates to /notifications', (tester) async {
    await tester.pumpWidget(_wrap(
      Scaffold(appBar: AppBar(actions: const [NotificationBellAction()])),
      count: 0,
    ));

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Notifications Screen'), findsOneWidget);
  });
}
