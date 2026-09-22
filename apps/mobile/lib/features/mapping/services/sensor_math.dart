import 'dart:math' as math;
import 'sensor_config.dart';
import 'sensor_models.dart';

/// Pure Mathematical, Geometric, and Filtering Functions for the Sensor Engine
/// Owner: Nishant (Phase 4 — Mathematical Sensor Fusion & Dead Reckoning)
abstract final class SensorMath {
  /// Normalizes any heading angle (in degrees) to the interval [0.0, 360.0).
  ///
  /// Examples:
  /// - 0.0 -> 0.0
  /// - 360.0 -> 0.0
  /// - 450.0 -> 90.0
  /// - -90.0 -> 270.0
  /// - -360.0 -> 0.0
  static double normalizeHeading(double degrees) {
    if (degrees.isNaN || degrees.isInfinite) {
      return 0.0;
    }
    double normalized = degrees % 360.0;
    if (normalized < 0.0) {
      normalized += 360.0;
    }
    // Protect against exact 360.0 due to floating point precision
    return normalized >= 360.0 ? 0.0 : normalized;
  }

  /// Calculates relative coordinate displacement (dx, dy) in meters from a step.
  ///
  /// Coordinate System Convention:
  /// - Initial position: (x=0, y=0)
  /// - +X = East, -X = West
  /// - +Y = North, -Y = South
  /// - Heading theta is measured in degrees clockwise from North [0, 360):
  ///   - North (0°):   dx = 0,               dy = +distance
  ///   - East  (90°):  dx = +distance,       dy = 0
  ///   - South (180°): dx = 0,               dy = -distance
  ///   - West  (270°): dx = -distance,       dy = 0
  ///   - Arbitrary:    dx = distance * sin(θ), dy = distance * cos(θ)
  ///
  /// NOTE: This coordinate system is local, relative, and creator-assisted.
  /// It does NOT claim survey-grade GPS accuracy or absolute world coordinates.
  static ({double dx, double dy}) calculateDisplacement({
    required double distance,
    required double headingDegrees,
  }) {
    if (distance <= 0 || distance.isNaN || distance.isInfinite) {
      return (dx: 0.0, dy: 0.0);
    }

    final theta = normalizeHeading(headingDegrees);
    final rad = theta * (math.pi / 180.0);

    double dx = distance * math.sin(rad);
    double dy = distance * math.cos(rad);

    // Suppress tiny floating-point artifacts (< 1e-10) for pure cardinal headings
    if (dx.abs() < 1e-10) dx = 0.0;
    if (dy.abs() < 1e-10) dy = 0.0;

    return (dx: dx, dy: dy);
  }

  /// Low-pass single pole filter for smoothing noisy sensor vectors
  /// formula: output = output_prev + alpha * (input - output_prev)
  static SensorReading3D lowPassFilter({
    required SensorReading3D current,
    required SensorReading3D previous,
    double alpha = SensorConfig.lowPassFilterFactor,
  }) {
    final sanitized = current.sanitized();
    final clampedX = sanitized.x.clamp(-SensorConfig.maxLinearAcceleration, SensorConfig.maxLinearAcceleration);
    final clampedY = sanitized.y.clamp(-SensorConfig.maxLinearAcceleration, SensorConfig.maxLinearAcceleration);
    final clampedZ = sanitized.z.clamp(-SensorConfig.maxLinearAcceleration, SensorConfig.maxLinearAcceleration);

    final filteredX = previous.x + alpha * (clampedX - previous.x);
    final filteredY = previous.y + alpha * (clampedY - previous.y);
    final filteredZ = previous.z + alpha * (clampedZ - previous.z);

    return SensorReading3D(filteredX, filteredY, filteredZ, current.timestamp);
  }

  /// Calculates magnetic azimuth from raw magnetometer readings, with optional tilt-compensation
  /// using accelerometer gravity vector.
  ///
  /// Returns heading in degrees [0.0, 360.0) clockwise from Magnetic North.
  static double calculateAzimuth({
    required SensorReading3D mag,
    SensorReading3D? accel,
  }) {
    if (!mag.isValid || (mag.x == 0.0 && mag.y == 0.0)) {
      return 0.0;
    }

    // Tilt compensation if gravity vector is available and valid
    if (accel != null && accel.isValid && accel.magnitude > 1.0) {
      final ax = accel.x / accel.magnitude;
      final ay = accel.y / accel.magnitude;
      final az = accel.z / accel.magnitude;

      final pitch = math.asin((-ay).clamp(-1.0, 1.0));
      final roll = math.atan2(-ax, az);

      final cosPitch = math.cos(pitch);
      final sinPitch = math.sin(pitch);
      final cosRoll = math.cos(roll);
      final sinRoll = math.sin(roll);

      final bx = mag.x * cosPitch + mag.y * sinRoll * sinPitch + mag.z * cosRoll * sinPitch;
      final by = mag.y * cosRoll - mag.z * sinRoll;

      if (bx != 0.0 || by != 0.0) {
        final rad = math.atan2(-bx, by);
        return normalizeHeading(rad * (180.0 / math.pi));
      }
    }

    // 2D horizontal plane fallback
    final rad = math.atan2(-mag.x, mag.y);
    return normalizeHeading(rad * (180.0 / math.pi));
  }

  /// Complementary heading fusion:
  /// Combines gyro yaw rate integration over dt with tilt-compensated magnetic heading.
  ///
  /// Handles 360° circular discontinuity wrapping seamlessly.
  static double fuseHeading({
    required double previousHeading,
    required double gyroYawRateRadSec,
    required double magneticHeading,
    required double dtSeconds,
    double alpha = SensorConfig.headingComplementaryAlpha,
  }) {
    if (gyroYawRateRadSec.isNaN || gyroYawRateRadSec.isInfinite) {
      return normalizeHeading(magneticHeading);
    }
    if (magneticHeading.isNaN || magneticHeading.isInfinite) {
      final delta = gyroYawRateRadSec * dtSeconds * (180.0 / math.pi);
      return normalizeHeading(previousHeading + delta);
    }

    // Step 1: Gyro integration
    final gyroDeltaDeg = gyroYawRateRadSec * dtSeconds * (180.0 / math.pi);
    final gyroHeading = normalizeHeading(previousHeading + gyroDeltaDeg);

    // Step 2: Calculate shortest angular difference between magnetic and gyro headings (-180° to +180°)
    final diff = ((magneticHeading - gyroHeading + 540.0) % 360.0) - 180.0;

    // Step 3: Blend using complementary filter weight
    final fused = gyroHeading + (1.0 - alpha) * diff;
    return normalizeHeading(fused);
  }

  /// Calculates the shortest angular difference between two angles in degrees (-180° to +180°)
  static double shortestAngleDifference(double angleA, double angleB) {
    final diff = ((angleA - angleB + 540.0) % 360.0) - 180.0;
    return diff;
  }
}
