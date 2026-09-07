import 'dart:math';

/// Spatial calculation utilities for indoor mapping
abstract final class GeoUtils {
  /// Calculates Euclidean distance between two local Cartesian points (meters)
  static double euclideanDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  /// Calculates bearing in degrees from point 1 to point 2 (0 = North, 90 = East)
  static double calculateBearing(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final radians = atan2(dx, dy); // dy is North, dx is East
    var degrees = radians * (180 / pi);
    if (degrees < 0) {
      degrees += 360.0;
    }
    return (degrees * 10).round() / 10.0;
  }

  /// Estimates walking time in seconds assuming typical average walking speed (~1.2 m/s)
  static double estimateWalkingTime(double distanceMeters, {double speedMps = 1.2}) {
    if (distanceMeters <= 0) return 0.0;
    return (distanceMeters / speedMps * 10).round() / 10.0;
  }
}
