/// Centralized Configuration Parameters for the Smartphone Sensor Engine
/// Owner: Nishant (Phase 4 — Sensor Configuration & Thresholds)
abstract final class SensorConfig {
  /// Default assumed human step length in meters (standard pedestrian stride: ~0.75m).
  /// Used for relative distance estimation (distance = stepCount * stepLength).
  /// NOTE: This is an approximation for creator-assisted mapping and is NOT survey-grade.
  static const double defaultStepLength = 0.75;

  /// Minimum allowable configurable step length (meters).
  static const double minStepLength = 0.30;

  /// Maximum allowable configurable step length (meters).
  static const double maxStepLength = 1.50;

  /// Complementary filter weight (alpha) for heading fusion.
  /// 0.95 gives 95% trust to gyro yaw integration and 5% to tilt-compensated magnetometer azimuth.
  static const double headingComplementaryAlpha = 0.95;

  /// Low-pass filter smoothing factor (alpha) for raw accelerometer and magnetometer streams.
  static const double lowPassFilterFactor = 0.20;

  /// Spike rejection threshold for linear acceleration in m/s^2.
  /// Acceleration magnitudes exceeding this threshold are clamped/discarded as physical drops or impacts.
  static const double maxLinearAcceleration = 35.0;

  /// Spike rejection threshold for angular velocity in rad/s (~573 deg/s).
  static const double maxAngularVelocity = 12.0;

  /// Fallback accelerometer step peak detection threshold in m/s^2.
  /// Earth gravity is ~9.8 m/s^2. A human walking step produces an acceleration peak typically > 11.5 m/s^2.
  static const double fallbackStepPeakThreshold = 11.5;

  /// Minimum time interval in milliseconds between consecutive detected steps in fallback mode.
  /// Standard walking cadence is ~1.5 to 2.5 steps/sec; anything < 250ms is rejected as bounce/jitter.
  static const int minStepIntervalMs = 250;

  /// Moving average smoothing window size for heading readings.
  static const int headingSmoothingWindowSize = 5;

  /// Zero-offset alignment tolerance in degrees.
  static const double headingToleranceDegrees = 0.5;
}
