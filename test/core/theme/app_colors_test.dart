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
