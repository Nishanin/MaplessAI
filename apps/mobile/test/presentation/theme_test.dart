import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/constants/app_colors.dart';
import 'package:mapless_ai/core/theme/app_theme.dart';
import 'package:mapless_ai/core/theme/app_typography.dart';

void main() {
  group('Theme Initialization & Material 3 Verification', () {
    test('AppTheme.lightTheme enables Material 3 and has valid ColorScheme', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.secondary, equals(AppColors.secondary));
      expect(theme.scaffoldBackgroundColor, equals(AppColors.background));
    });

    test('AppTheme configures consistent component styles', () {
      final theme = AppTheme.lightTheme;

      // Card Theme
      expect(theme.cardTheme.color, equals(AppColors.card));
      expect(theme.cardTheme.elevation, equals(1.0));

      // AppBar Theme
      expect(theme.appBarTheme.backgroundColor, equals(AppColors.surface));
      expect(theme.appBarTheme.centerTitle, isFalse);

      // Elevated Button Theme
      expect(theme.elevatedButtonTheme.style, isNotNull);

      // Text Theme
      expect(theme.textTheme.headlineLarge?.fontWeight, equals(FontWeight.w700));
      expect(theme.textTheme.labelLarge?.fontSize, equals(AppTypography.labelLarge.fontSize));
    });
  });
}
