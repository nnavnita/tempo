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
