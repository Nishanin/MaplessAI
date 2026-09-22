import 'package:flutter/material.dart';

/// Semantic color palette for MapLess AI
/// Owner: Nishant (Design System)
abstract final class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF0F52BA); // Sapphire Blue
  static const Color primaryDark = Color(0xFF082567);
  static const Color primaryLight = Color(0xFF3F7BE0);
  static const Color primarySubtle = Color(0xFFE8F0FE);

  static const Color secondary = Color(0xFF00A86B); // Jade Green
  static const Color secondaryDark = Color(0xFF00754A);
  static const Color secondaryLight = Color(0xFF33B988);
  static const Color secondarySubtle = Color(0xFFE6F6F0);

  static const Color accent = Color(0xFFFF6F00); // Amber Orange
  static const Color accentLight = Color(0xFFFF9E40);
  static const Color accentSubtle = Color(0xFFFFF3E0);

  // Surface & Neutral Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceContainerHighest = Color(0xFFE9EEF5);

  // Text Colors
  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color textMuted = Color(0xFF79747E);
  static const Color textOnPrimary = Colors.white;

  // Status & Feedback Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successSubtle = Color(0xFFEDF7ED);
  static const Color warning = Color(0xFFED6C02);
  static const Color warningSubtle = Color(0xFFFFF4E5);
  static const Color error = Color(0xFFD32F2F);
  static const Color errorSubtle = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF0288D1);
  static const Color infoSubtle = Color(0xFFE1F5FE);

  // Indoor Map Semantic Colors
  static const Color nodeDefault = Color(0xFF1976D2);
  static const Color nodeSelected = Color(0xFFD32F2F);
  static const Color nodeAccessible = Color(0xFF388E3C);
  static const Color nodeStairs = Color(0xFFE65100);
  static const Color nodeElevator = Color(0xFF7B1FA2);
  static const Color nodeExit = Color(0xFFC2185B);

  static const Color edgeDefault = Color(0xFF90CAF9);
  static const Color edgeActiveRoute = Color(0xFF2E7D32);
  static const Color edgeBlocked = Color(0xFFE53935);

  // Dividers & Borders
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderSubtle = Color(0xFFEEEEEE);
  static const Color divider = Color(0xFFE6E6E6);

  // Greyscale
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
}
