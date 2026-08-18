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
