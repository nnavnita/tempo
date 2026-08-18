import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/config/router/main_nav_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        Expanded(child: Container()),
        child,
      ],
    ),
  ),
);

void main() {
  testWidgets('renders exactly 4 destination labels, no 5th tab', (tester) async {
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      onCreatePressed: () {},
    )));

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Alerts'), findsNothing);
  });

  testWidgets('tapping a destination calls onDestinationSelected with its index',
      (tester) async {
    int? tapped;
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (i) => tapped = i,
      onCreatePressed: () {},
    )));

    await tester.tap(find.text('Friends'));
    expect(tapped, 2);

    await tester.tap(find.text('Profile'));
    expect(tapped, 3);
  });

  testWidgets('tapping the center button calls onCreatePressed, not onDestinationSelected',
      (tester) async {
    int? tapped;
    var createPressed = false;
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (i) => tapped = i,
      onCreatePressed: () => createPressed = true,
    )));

    await tester.tap(find.byKey(const Key('main-nav-bar-fab')));

    expect(createPressed, isTrue);
    expect(tapped, isNull);
  });

  testWidgets('selected index is reflected in a distinct active label style',
      (tester) async {
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 1,
      onDestinationSelected: (_) {},
      onCreatePressed: () {},
    )));

    final feedText = tester.widget<Text>(find.text('Feed'));
    final calendarText = tester.widget<Text>(find.text('Calendar'));
    expect(feedText.style?.fontWeight, FontWeight.w600);
    expect(calendarText.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('FAB renders above the top edge of the nav bar',
      (tester) async {
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      onCreatePressed: () {},
    )));

    // Find the FAB GestureDetector widget
    final fabFinder = find.byKey(const Key('main-nav-bar-fab'));
    final fabSize = tester.getSize(fabFinder);
    final fabTopLeft = tester.getTopLeft(fabFinder);

    // Find the Row that contains the nav destinations and FAB
    final rowFinder = find.descendant(
      of: find.byType(MainNavBar),
      matching: find.byType(Row),
    );
    final rowTopLeft = tester.getTopLeft(rowFinder);
    final rowSize = tester.getSize(rowFinder);

    // For a floating FAB, the top of the FAB should be above the top of the row
    final fabTop = fabTopLeft.dy;
    final rowTop = rowTopLeft.dy;

    expect(fabTop, lessThan(rowTop),
        reason: 'FAB should float above the nav bar row');
  });
}
