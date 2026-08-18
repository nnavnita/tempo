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
