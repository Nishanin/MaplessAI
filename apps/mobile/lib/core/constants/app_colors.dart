import 'package:flutter/material.dart';

/// Semantic color palette for MapLess AI
abstract final class AppColors {
  static const Color primary = Color(0xFF0F52BA); // Sapphire Blue
  static const Color primaryDark = Color(0xFF082567);
  static const Color secondary = Color(0xFF00A86B); // Jade Green
  static const Color accent = Color(0xFFFF6F00); // Amber Orange

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;
  static const Color card = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF1C1B1F);
  static const Color textSecondary = Color(0xFF49454F);
  static const Color textMuted = Color(0xFF79747E);

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

  static const Color border = Color(0xFFE0E0E0);
}
