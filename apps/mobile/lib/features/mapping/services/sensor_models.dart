import 'dart:math' as math;
import 'sensor_config.dart';

/// 3D Vector Sensor Measurement with Timestamp
/// Owner: Nishant (Phase 4 — Sensor Models)
class SensorReading3D {
  final double x;
  final double y;
  final double z;
  final DateTime? timestamp;

  const SensorReading3D(this.x, this.y, this.z, [this.timestamp]);

  /// Helper factory for current timestamp
  factory SensorReading3D.now(double x, double y, double z) {
    return SensorReading3D(x, y, z, DateTime.now());
  }

  /// Calculates the Euclidean vector magnitude sqrt(x^2 + y^2 + z^2)
  double get magnitude => math.sqrt(x * x + y * y + z * z);

  /// True if all components are non-NaN and finite
  bool get isValid =>
      !x.isNaN && !x.isInfinite &&
      !y.isNaN && !y.isInfinite &&
      !z.isNaN && !z.isInfinite;

  /// Returns a sanitized reading where NaN/Infinity is replaced by 0.0
  SensorReading3D sanitized() {
    return SensorReading3D(
      (x.isNaN || x.isInfinite) ? 0.0 : x,
      (y.isNaN || y.isInfinite) ? 0.0 : y,
      (z.isNaN || z.isInfinite) ? 0.0 : z,
      timestamp,
    );
  }

  @override
  String toString() => 'SensorReading3D(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)})';
}

/// Explicit Sensor Permission State
enum SensorPermissionStatus {
  unknown,
  granted,
  denied,
  unavailable,
}

/// Hardware Sensor Availability Matrix
class SensorAvailability {
  final bool hasAccelerometer;
  final bool hasGyroscope;
  final bool hasMagnetometer;
  final bool hasPedometer;

  const SensorAvailability({
    this.hasAccelerometer = true,
    this.hasGyroscope = true,
    this.hasMagnetometer = true,
    this.hasPedometer = true,
  });

  const SensorAvailability.none()
      : hasAccelerometer = false,
        hasGyroscope = false,
        hasMagnetometer = false,
        hasPedometer = false;

  /// True if all 4 sensor streams are supported
  bool get isFull =>
      hasAccelerometer && hasGyroscope && hasMagnetometer && hasPedometer;

  /// True if minimum movement and orientation sensors (accelerometer + heading) are available
  bool get isMinimumViable =>
      hasAccelerometer && (hasMagnetometer || hasGyroscope);

  /// True if completely unavailable (unsupported device or hardware failure)
  bool get isNone =>
      !hasAccelerometer && !hasGyroscope && !hasMagnetometer && !hasPedometer;

  @override
  String toString() =>
      'SensorAvailability(accel: $hasAccelerometer, gyro: $hasGyroscope, mag: $hasMagnetometer, pedo: $hasPedometer)';
}

/// State of the sensor processing engine
enum SensorEngineStatus {
  idle,
  calibrating,
  running,
  paused,
  degraded,
  error,
}

/// Status of sensor calibration
enum SensorCalibrationState {
  uncalibrated,
  calibrating,
  calibrated,
}

/// Immutable Global Sensor State exposed through Riverpod
class SensorState {
  final bool isAvailable;
  final bool isRunning;
  final bool isPaused;
  final SensorPermissionStatus permissionStatus;
  final SensorAvailability availability;
  final SensorEngineStatus status;
  final SensorCalibrationState calibrationState;
  final int stepCount;
  final double distance;
  final double heading;
  final double x;
  final double y;
  final double headingOffset;
  final double stepLength;
  final DateTime? lastReadingTimestamp;
  final String? errorMessage;

  const SensorState({
    this.isAvailable = true,
    this.isRunning = false,
    this.isPaused = false,
    this.permissionStatus = SensorPermissionStatus.unknown,
    this.availability = const SensorAvailability(),
    this.status = SensorEngineStatus.idle,
    this.calibrationState = SensorCalibrationState.uncalibrated,
    this.stepCount = 0,
    this.distance = 0.0,
    this.heading = 0.0,
    this.x = 0.0,
    this.y = 0.0,
    this.headingOffset = 0.0,
    this.stepLength = SensorConfig.defaultStepLength,
    this.lastReadingTimestamp,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;

  /// Relative heading adjusted by calibration zero-reference
  double get calibratedHeading {
    final rel = (heading - headingOffset) % 360.0;
    return rel < 0 ? rel + 360.0 : rel;
  }

  SensorState copyWith({
    bool? isAvailable,
    bool? isRunning,
    bool? isPaused,
    SensorPermissionStatus? permissionStatus,
    SensorAvailability? availability,
    SensorEngineStatus? status,
    SensorCalibrationState? calibrationState,
    int? stepCount,
    double? distance,
    double? heading,
    double? x,
    double? y,
    double? headingOffset,
    double? stepLength,
    DateTime? lastReadingTimestamp,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SensorState(
      isAvailable: isAvailable ?? this.isAvailable,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      availability: availability ?? this.availability,
      status: status ?? this.status,
      calibrationState: calibrationState ?? this.calibrationState,
      stepCount: stepCount ?? this.stepCount,
      distance: distance ?? this.distance,
      heading: heading ?? this.heading,
      x: x ?? this.x,
      y: y ?? this.y,
      headingOffset: headingOffset ?? this.headingOffset,
      stepLength: stepLength ?? this.stepLength,
      lastReadingTimestamp: lastReadingTimestamp ?? this.lastReadingTimestamp,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
