import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/config/router/main_nav_bar.dart';

/// Mounts [MainNavBar] the way the real app does: as
/// `Scaffold.bottomNavigationBar`, with a real (sized) body. This matters
/// because `Scaffold` gives its `bottomNavigationBar` child unbounded-width
/// but full-screen-height-looking `maxHeight` constraints — a bug that a
/// `Column`-based test harness (the previous version of this file) never
/// exercised, letting a bar that filled the whole screen ship with green
/// tests.
Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Container(color: Colors.blue),
    bottomNavigationBar: child,
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

  testWidgets('FAB renders above the top edge of the nav bar surface',
      (tester) async {
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      onCreatePressed: () {},
    )));

    final fabFinder = find.byKey(const Key('main-nav-bar-fab'));
    final fabTopLeft = tester.getTopLeft(fabFinder);

    // The bar surface is the Material that paints the destination row's
    // background; its top edge is where the visible bottom band begins.
    final barFinder = find.descendant(
      of: find.byType(MainNavBar),
      matching: find.byType(Material),
    );
    final barTopLeft = tester.getTopLeft(barFinder);

    expect(fabTopLeft.dy, lessThan(barTopLeft.dy),
        reason: 'FAB should float above the nav bar surface');
  });

  testWidgets(
      'in a real Scaffold, the nav bar has a bounded height and the body keeps its size',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Container(key: const Key('body'), color: Colors.blue),
        bottomNavigationBar: MainNavBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          onCreatePressed: () {},
        ),
      ),
    ));

    final navBarSize = tester.getSize(find.byType(MainNavBar));
    final bodySize = tester.getSize(find.byKey(const Key('body')));

    // The bug this guards against: Expanded(child: Center(...)) inside the
    // FAB slot picks up the ambient (full-screen) maxHeight that
    // Scaffold.bottomNavigationBar imposes, so the bar's rendered height
    // becomes the entire screen height and the body collapses to zero.
    expect(navBarSize.height, lessThan(120),
        reason: 'nav bar must not consume the full screen height');
    expect(bodySize.height, greaterThan(0),
        reason: 'Scaffold body must retain non-zero height alongside the nav bar');
    expect(bodySize.height, greaterThan(400),
        reason: 'body should occupy the vast majority of the 600pt screen height');
  });

  testWidgets(
      'tapping the visual top-most point of the FAB circle fires onCreatePressed',
      (tester) async {
    int? tapped;
    var createPressed = false;
    await tester.pumpWidget(_wrap(MainNavBar(
      selectedIndex: 0,
      onDestinationSelected: (i) => tapped = i,
      onCreatePressed: () => createPressed = true,
    )));

    final fabFinder = find.byKey(const Key('main-nav-bar-fab'));
    final topLeft = tester.getTopLeft(fabFinder);
    final size = tester.getSize(fabFinder);

    // A couple of points below the exact top edge (the very edge of a
    // circle is outside the circle's hit region) but still well within the
    // visually "raised" upper portion of the FAB that Transform.translate
    // used to paint outside its hit-testable box.
    final nearTop = Offset(topLeft.dx + size.width / 2, topLeft.dy + 3);

    await tester.tapAt(nearTop);

    expect(createPressed, isTrue,
        reason: 'the full painted circle, including its topmost portion, must be tappable');
    expect(tapped, isNull);
  });
}
