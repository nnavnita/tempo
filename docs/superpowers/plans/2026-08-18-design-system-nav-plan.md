# Design System + Navigation/IA Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Tempo a "warm & social" terracotta/sage visual identity with dark mode, and replace the 5-tab bottom nav with a 4-tab nav bar that has a raised center FAB for event creation and a bell+badge for alerts in each tab's app bar.

**Architecture:** Pure design-token changes (`AppColors`, `AppTheme.darkTheme`) feed a `ThemeData` pair wired into `MaterialApp.router` via `themeMode: ThemeMode.system`. Two new standalone widgets — `MainNavBar` (dumb, no provider deps) and `NotificationBellAction` (thin Riverpod wrapper around the existing `notificationCountProvider`) — replace the stock `NavigationBar` and get dropped into each of the 4 tab screens' existing `AppBar.actions`. Nothing about routing, screen layouts, or data providers changes — this is Flutter, so the same code runs on iOS, Android, and web without platform branches.

**Tech Stack:** Flutter (Material 3), flutter_riverpod ^2.5.1, go_router ^14.2.7.

## Global Constraints

- Terracotta primary: light `#C9603D` / dark `#D97A54`. Sage secondary: light `#6B8E5A` / dark `#7BA366`.
- Light background `#F6F2EC`, light surface `#FFFFFF`. Dark background `#121212` (true dark, not warm-brown), dark surface `#1E1E1E`.
- Single system sans font family everywhere — no new font family is introduced by this plan.
- Existing shape language stays: 0 elevation, 16px card radius, 12px button radius, hairline borders (per `lib/core/theme/app_theme.dart`, unchanged by this plan except color values).
- Bottom nav has exactly 4 destinations (Calendar, Feed, Friends, Profile) plus one non-destination raised center FAB slot for Create Event — never a 5th `NavigationDestination`.
- Alerts is never a bottom-nav destination; it is a bell icon + unread-dot badge in the top app bar, present on all 4 tab screens.
- No Firebase-dependent widget is pumped directly in a test — override the specific `Provider`/`StreamProvider` it reads instead (see Task 4 for the pattern). This mirrors the existing `test/widget_test.dart` comment ("Integration tests requiring Firebase are run separately") — there is no Firebase test harness in this codebase, so plan around it rather than adding one.

---

### Task 1: Terracotta/sage design tokens in `AppColors`

**Files:**
- Modify: `lib/core/theme/app_colors.dart`
- Test: `test/core/theme/app_colors_test.dart`

**Interfaces:**
- Produces: `AppColors.primary`, `AppColors.secondary`, `AppColors.background`, `AppColors.surface`, `AppColors.onSurface`, `AppColors.onSurfaceVariant` (existing names, new values) — consumed by Task 2. `AppColors.dark` (new nested class) with the same field names plus `busySlot`, `privateEvent`, `friendsEvent`, `publicEvent`, `visibilityPrivateBg`, `visibilityFriendsBg`, `visibilityEveryoneBg`, `error`, `warning` — consumed by Task 2.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/core/theme/app_colors.dart';

void main() {
  test('light tokens use the terracotta/sage palette', () {
    expect(AppColors.primary, const Color(0xFFC9603D));
    expect(AppColors.secondary, const Color(0xFF6B8E5A));
    expect(AppColors.background, const Color(0xFFF6F2EC));
    expect(AppColors.surface, const Color(0xFFFFFFFF));
  });

  test('dark tokens exist and differ from light tokens', () {
    expect(AppColors.dark.primary, const Color(0xFFD97A54));
    expect(AppColors.dark.secondary, const Color(0xFF7BA366));
    expect(AppColors.dark.background, const Color(0xFF121212));
    expect(AppColors.dark.surface, const Color(0xFF1E1E1E));
    expect(AppColors.dark.primary, isNot(AppColors.primary));
    expect(AppColors.dark.background, isNot(AppColors.background));
  });

  test('dark semantic/event/chip tokens are defined', () {
    expect(AppColors.dark.busySlot, const Color(0xFF3A3A3A));
    expect(AppColors.dark.privateEvent, const Color(0xFFB0B0B0));
    expect(AppColors.dark.friendsEvent, const Color(0xFF26A69A));
    expect(AppColors.dark.publicEvent, const Color(0xFF66BB6A));
    expect(AppColors.dark.visibilityPrivateBg, const Color(0xFF2C2C2C));
    expect(AppColors.dark.visibilityFriendsBg, const Color(0xFF1E2A3A));
    expect(AppColors.dark.visibilityEveryoneBg, const Color(0xFF1B2E1F));
    expect(AppColors.dark.error, const Color(0xFFEF5350));
    expect(AppColors.dark.warning, const Color(0xFFFBBC04));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: FAIL — `AppColors.dark` doesn't exist yet, and light token values don't match (old teal `0xFF00897B` primary, old grey `0xFFF8F9FA` background).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFC9603D);
  static const Color primaryDark = Color(0xFFA84E31);
  static const Color secondary = Color(0xFF6B8E5A);
  static const Color error = Color(0xFFEA4335);
  static const Color warning = Color(0xFFFBBC04);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF6F2EC);
  static const Color onSurface = Color(0xFF2B2823);
  static const Color onSurfaceVariant = Color(0xFF8C8577);

  static const Color busySlot = Color(0xFFDADCE0);
  static const Color privateEvent = Color(0xFF9AA0A6);
  static const Color friendsEvent = Color(0xFF00897B);
  static const Color publicEvent = Color(0xFF34A853);

  // Visibility chip colors
  static const Color visibilityPrivateBg = Color(0xFFF1F3F4);
  static const Color visibilityFriendsBg = Color(0xFFE8F0FE);
  static const Color visibilityEveryoneBg = Color(0xFFE6F4EA);

  static const _AppColorsDark dark = _AppColorsDark();
}

/// Dark-mode counterparts of [AppColors]. Access via `AppColors.dark.*`.
class _AppColorsDark {
  const _AppColorsDark();

  Color get primary => const Color(0xFFD97A54);
  Color get primaryDark => const Color(0xFFB8623F);
  Color get secondary => const Color(0xFF7BA366);
  Color get error => const Color(0xFFEF5350);
  Color get warning => const Color(0xFFFBBC04);

  Color get surface => const Color(0xFF1E1E1E);
  Color get background => const Color(0xFF121212);
  Color get onSurface => const Color(0xFFF0EDE8);
  Color get onSurfaceVariant => const Color(0xFF9C968D);

  Color get busySlot => const Color(0xFF3A3A3A);
  Color get privateEvent => const Color(0xFFB0B0B0);
  Color get friendsEvent => const Color(0xFF26A69A);
  Color get publicEvent => const Color(0xFF66BB6A);

  Color get visibilityPrivateBg => const Color(0xFF2C2C2C);
  Color get visibilityFriendsBg => const Color(0xFF1E2A3A);
  Color get visibilityEveryoneBg => const Color(0xFF1B2E1F);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_colors_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart test/core/theme/app_colors_test.dart
git commit -m "feat: switch AppColors to terracotta/sage palette, add dark tokens"
```

---

### Task 2: `AppTheme.darkTheme`

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppColors.dark.*` from Task 1 (exact getter names as implemented there).
- Produces: `AppTheme.darkTheme` (a `ThemeData` getter, mirroring the existing `AppTheme.lightTheme`) — consumed by Task 3.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/core/theme/app_colors.dart';
import 'package:tempo/core/theme/app_theme.dart';

void main() {
  group('AppTheme.darkTheme', () {
    final theme = AppTheme.darkTheme;

    test('uses dark brightness and dark scaffold background', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.dark.background);
    });

    test('app bar uses dark background and onSurface foreground', () {
      expect(theme.appBarTheme.backgroundColor, AppColors.dark.background);
      expect(theme.appBarTheme.foregroundColor, AppColors.dark.onSurface);
      expect(theme.appBarTheme.elevation, 0);
    });

    test('cards use dark surface with no elevation', () {
      expect(theme.cardTheme.color, AppColors.dark.surface);
      expect(theme.cardTheme.elevation, 0);
    });

    test('elevated buttons use dark primary', () {
      expect(theme.elevatedButtonTheme.style?.backgroundColor
          ?.resolve(<WidgetState>{}), AppColors.dark.primary);
    });

    test('navigation bar uses dark surface and dark primary indicator', () {
      expect(theme.navigationBarTheme.backgroundColor, AppColors.dark.surface);
    });

    test('floating action button uses dark primary', () {
      expect(theme.floatingActionButtonTheme.backgroundColor,
          AppColors.dark.primary);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — `AppTheme.darkTheme` doesn't exist (compile error).

- [ ] **Step 3: Write the implementation**

Add a `darkTheme` getter to `lib/core/theme/app_theme.dart`, mirroring `lightTheme`'s structure field-for-field with `AppColors.dark.*` substituted for `AppColors.*`:

```dart
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.dark.primary,
        brightness: Brightness.dark,
        surface: AppColors.dark.surface,
      ),
      scaffoldBackgroundColor: AppColors.dark.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.dark.background,
        foregroundColor: AppColors.dark.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.dark.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.dark.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dark.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.dark.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: AppColors.dark.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.dark.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.dark.primary.withOpacity(0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.dark.primary : AppColors.dark.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(
            color: active ? AppColors.dark.primary : AppColors.dark.onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.dark.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "feat: add AppTheme.darkTheme mirroring lightTheme with dark tokens"
```

---

### Task 3: Wire dark theme into `MaterialApp.router`

**Files:**
- Modify: `lib/main.dart`
- Test: `test/main_test.dart`

**Interfaces:**
- Consumes: `AppTheme.lightTheme`, `AppTheme.darkTheme` (Task 2); `routerProvider` (existing, from `lib/config/router/app_router.dart`).

- [ ] **Step 1: Write the failing test**

```dart
// test/main_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tempo/config/router/app_router.dart';
import 'package:tempo/core/theme/app_theme.dart';
import 'package:tempo/main.dart';

void main() {
  testWidgets('TempoApp wires light theme, dark theme, and system theme mode',
      (tester) async {
    final fakeRouter = GoRouter(
      initialLocation: '/fake',
      routes: [
        GoRoute(path: '/fake', builder: (_, __) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [routerProvider.overrideWithValue(fakeRouter)],
        child: const TempoApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, AppTheme.lightTheme);
    expect(app.darkTheme, AppTheme.darkTheme);
    expect(app.themeMode, ThemeMode.system);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/main_test.dart`
Expected: FAIL — `app.darkTheme` is `null` and `app.themeMode` is the default (`ThemeMode.system` is actually the `MaterialApp` default, so the real failure is `app.theme` not matching if run before Task 1/2 land, or — once those are done — `darkTheme` being `null` since `main.dart` doesn't set it yet).

- [ ] **Step 3: Write the implementation**

```dart
// lib/main.dart
    return MaterialApp.router(
      title: 'Tempo',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/main_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/main_test.dart
git commit -m "feat: enable system-driven dark mode in MaterialApp.router"
```

---

### Task 4: `NotificationBellAction` widget

**Files:**
- Create: `lib/core/widgets/notification_bell_action.dart`
- Test: `test/core/widgets/notification_bell_action_test.dart`

**Interfaces:**
- Consumes: `notificationCountProvider` (existing `Provider<int>` from `lib/providers/notifications_provider.dart`).
- Produces: `NotificationBellAction` (a `ConsumerWidget`, no constructor params beyond `key`) — consumed by Task 6, dropped into each tab screen's `AppBar.actions`. Tapping it calls `context.push(RouteConstants.notifications)`.

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/notification_bell_action_test.dart`
Expected: FAIL — `lib/core/widgets/notification_bell_action.dart` doesn't exist (import error).

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/widgets/notification_bell_action.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/widgets/notification_bell_action_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/notification_bell_action.dart test/core/widgets/notification_bell_action_test.dart
git commit -m "feat: add NotificationBellAction (bell+badge) to replace Alerts tab"
```

---

### Task 5: `MainNavBar` widget (4 destinations + center FAB slot)

**Files:**
- Create: `lib/config/router/main_nav_bar.dart`
- Test: `test/config/router/main_nav_bar_test.dart`

**Interfaces:**
- Produces: `MainNavBar` (a `StatelessWidget`) — consumed by Task 6.
  ```dart
  class MainNavBar extends StatelessWidget {
    const MainNavBar({
      super.key,
      required this.selectedIndex,       // 0=Calendar, 1=Feed, 2=Friends, 3=Profile
      required this.onDestinationSelected, // void Function(int)
      required this.onCreatePressed,       // VoidCallback
    });
  }
  ```
  No provider dependencies — plain callbacks in, so it's testable without Riverpod/GoRouter/Firebase.

- [ ] **Step 1: Write the failing test**

```dart
// test/config/router/main_nav_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/config/router/main_nav_bar.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/router/main_nav_bar_test.dart`
Expected: FAIL — `lib/config/router/main_nav_bar.dart` doesn't exist (import error).

- [ ] **Step 3: Write the implementation**

```dart
// lib/config/router/main_nav_bar.dart
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
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GestureDetector(
                  key: const Key('main-nav-bar-fab'),
                  onTap: onCreatePressed,
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(top: -30),
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/router/main_nav_bar_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/main_nav_bar.dart test/config/router/main_nav_bar_test.dart
git commit -m "feat: add MainNavBar with 4 destinations and raised center FAB"
```

---

### Task 6: Wire `MainNavBar` + `NotificationBellAction` into the app, remove the old 5th tab and per-screen FAB

**Files:**
- Modify: `lib/config/router/app_router.dart:108-179` (the `_MainShell` widget)
- Modify: `lib/features/calendar/screens/calendar_screen.dart:50-60,223-226` (add bell action, remove `floatingActionButton`)
- Modify: `lib/features/feed/screens/friends_feed_screen.dart:19` (add bell action)
- Modify: `lib/features/friends/screens/friends_list_screen.dart:19-24` (add bell action)
- Modify: `lib/features/profile/screens/profile_screen.dart:16` (add bell action)

**Interfaces:**
- Consumes: `MainNavBar` (Task 5), `NotificationBellAction` (Task 4).

This task has no new automated test: it wires already-tested widgets (`MainNavBar`, `NotificationBellAction`) into screens whose own `build()` methods read Firebase-backed providers (`eventsByDayProvider`, friend/feed streams, etc.), and this codebase has no Firebase test harness (see Global Constraints). Correctness here is verified by `flutter analyze`, the full existing test suite staying green, and the manual QA pass in Step 5.

- [ ] **Step 1: Replace the `NavigationBar` in `_MainShell` with `MainNavBar`**

In `lib/config/router/app_router.dart`, replace the `_currentIndex` method and the `bottomNavigationBar` section:

```dart
  int _currentIndex(String location) {
    if (location.startsWith('/friends')) return 2;
    if (location.startsWith('/feed')) return 1;
    if (location.startsWith('/profile')) return 3;
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
              context.go(RouteConstants.calendar);
            case 1:
              context.go(RouteConstants.feed);
            case 2:
              context.go(RouteConstants.friends);
            case 3:
              context.go(RouteConstants.profile);
          }
        },
        onCreatePressed: () => context.push(RouteConstants.createEvent),
      ),
    );
  }
```

Remove the now-unused `NavigationBar`/`NavigationDestination` widget tree and the `Container`/`BoxDecoration` border wrapper (the border now lives inside `MainNavBar`). Add the import:

```dart
import 'main_nav_bar.dart';
```

- [ ] **Step 2: Remove the per-screen FAB from `CalendarScreen`**

In `lib/features/calendar/screens/calendar_screen.dart`, delete the `floatingActionButton: FloatingActionButton(...)` block (around line 223) — Create Event is now reached from the shared `MainNavBar` center button, available on every tab, not just Calendar.

- [ ] **Step 3: Add `NotificationBellAction` to each tab screen's `AppBar.actions`**

`lib/features/calendar/screens/calendar_screen.dart` — append to the existing `actions` list (alongside the month-jump button):

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_month_outlined),
            tooltip: 'Jump to month',
            onPressed: _showMonthYearPicker,
          ),
          const NotificationBellAction(),
        ],
```

`lib/features/feed/screens/friends_feed_screen.dart`:

```dart
      appBar: AppBar(
        title: const Text('Feed'),
        actions: const [NotificationBellAction()],
      ),
```

`lib/features/friends/screens/friends_list_screen.dart` — append to the existing `actions` list (alongside search and requests-inbox buttons):

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push(RouteConstants.userSearch),
          ),
          IconButton(
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(RouteConstants.friendRequests),
          ),
          const NotificationBellAction(),
        ],
```

`lib/features/profile/screens/profile_screen.dart`:

```dart
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NotificationBellAction()],
      ),
```

Add the import to each modified file:

```dart
import '../../../core/widgets/notification_bell_action.dart';
```

- [ ] **Step 4: Run the full test suite and static analysis**

Run: `flutter analyze`
Expected: No new errors or warnings introduced by this task.

Run: `flutter test`
Expected: All tests pass (Tasks 1-5's tests plus the pre-existing `test/widget_test.dart` placeholder).

- [ ] **Step 5: Manual verification**

Run: `flutter run` (any of iOS simulator, Android emulator, or `-d chrome` for web — this plan makes no platform-specific changes, so one platform is enough to catch layout bugs common to all three).

Check, on each of the 4 tabs:
- Bottom bar shows exactly Calendar, Feed, Friends, Profile — no Alerts tab.
- The bell icon in the app bar is present and tapping it opens the notifications screen.
- The center raised button in the nav bar is fully visible (not clipped at the top) and tapping it opens Create Event.
- Toggle the OS-level dark mode setting and confirm the app switches theme live: terracotta/sage accents remain legible, backgrounds go to near-black, card borders and dividers are visible against the dark surface.

- [ ] **Step 6: Commit**

```bash
git add lib/config/router/app_router.dart lib/features/calendar/screens/calendar_screen.dart lib/features/feed/screens/friends_feed_screen.dart lib/features/friends/screens/friends_list_screen.dart lib/features/profile/screens/profile_screen.dart
git commit -m "feat: wire MainNavBar and NotificationBellAction into the app shell"
```
