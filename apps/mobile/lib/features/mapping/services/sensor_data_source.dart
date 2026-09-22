import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'sensor_models.dart';

/// Abstract Sensor Data Source contract
/// Owner: Nishant (Phase 4 — Sensor Data Abstraction)
abstract class ISensorDataSource {
  Stream<SensorReading3D> get accelerometer;
  Stream<SensorReading3D> get gyroscope;
  Stream<SensorReading3D> get magnetometer;
  Stream<int> get stepCount;

  Future<SensorAvailability> checkAvailability();
  Future<SensorPermissionStatus> checkPermissions();
  Future<SensorPermissionStatus> requestPermissions();

  void dispose();
}

/// Real Physical Hardware Data Source backed by sensors_plus and pedometer packages
class RealSensorDataSource implements ISensorDataSource {
  Stream<SensorReading3D>? _accelStream;
  Stream<SensorReading3D>? _gyroStream;
  Stream<SensorReading3D>? _magStream;
  Stream<int>? _stepStream;

  @override
  Stream<SensorReading3D> get accelerometer {
    _accelStream ??= accelerometerEventStream().map((event) {
      return SensorReading3D(event.x, event.y, event.z, DateTime.now());
    }).handleError((_) => const SensorReading3D(0, 0, 0));
    return _accelStream!;
  }

  @override
  Stream<SensorReading3D> get gyroscope {
    _gyroStream ??= gyroscopeEventStream().map((event) {
      return SensorReading3D(event.x, event.y, event.z, DateTime.now());
    }).handleError((_) => const SensorReading3D(0, 0, 0));
    return _gyroStream!;
  }

  @override
  Stream<SensorReading3D> get magnetometer {
    _magStream ??= magnetometerEventStream().map((event) {
      return SensorReading3D(event.x, event.y, event.z, DateTime.now());
    }).handleError((_) => const SensorReading3D(0, 0, 0));
    return _magStream!;
  }

  @override
  Stream<int> get stepCount {
    _stepStream ??= Pedometer.stepCountStream.map((event) {
      return event.steps;
    }).handleError((_) => 0);
    return _stepStream!;
  }

  @override
  Future<SensorAvailability> checkAvailability() async {
    // In production Flutter, availability is evaluated by stream listening or platform detection.
    // Default to optimistic availability, which degrades gracefully upon error.
    return const SensorAvailability(
      hasAccelerometer: true,
      hasGyroscope: true,
      hasMagnetometer: true,
      hasPedometer: true,
    );
  }

  @override
  Future<SensorPermissionStatus> checkPermissions() async {
    try {
      final status = await Permission.activityRecognition.status;
      debugPrint('[MAPLESS][PERMISSION] Activity Recognition status: $status');
      if (status.isGranted) {
        return SensorPermissionStatus.granted;
      } else if (status.isDenied || status.isPermanentlyDenied) {
        return SensorPermissionStatus.denied;
      } else if (status.isRestricted) {
        return SensorPermissionStatus.unavailable;
      }
      return SensorPermissionStatus.unknown;
    } catch (e) {
      debugPrint('[MAPLESS][PERMISSION] Activity Recognition status check error: $e');
      return SensorPermissionStatus.unavailable;
    }
  }

  @override
  Future<SensorPermissionStatus> requestPermissions() async {
    try {
      debugPrint('[MAPLESS][PERMISSION] Requesting Activity Recognition...');
      final status = await Permission.activityRecognition.request();
      debugPrint('[MAPLESS][PERMISSION] Result: $status');
      if (status.isGranted) {
        return SensorPermissionStatus.granted;
      } else if (status.isDenied || status.isPermanentlyDenied) {
        return SensorPermissionStatus.denied;
      } else if (status.isRestricted) {
        return SensorPermissionStatus.unavailable;
      }
      return SensorPermissionStatus.unknown;
    } catch (e) {
      debugPrint('[MAPLESS][PERMISSION] Activity Recognition request error: $e');
      return SensorPermissionStatus.unavailable;
    }
  }

  @override
  void dispose() {
    _accelStream = null;
    _gyroStream = null;
    _magStream = null;
    _stepStream = null;
  }
}

/// Deterministic Fake Sensor Data Source for Hardware-Free Unit & Integration Testing
class FakeSensorDataSource implements ISensorDataSource {
  final _accelController = StreamController<SensorReading3D>.broadcast(sync: true);
  final _gyroController = StreamController<SensorReading3D>.broadcast(sync: true);
  final _magController = StreamController<SensorReading3D>.broadcast(sync: true);
  final _stepController = StreamController<int>.broadcast(sync: true);

  SensorAvailability mockAvailability;
  SensorPermissionStatus mockPermissionStatus;
  SensorPermissionStatus? mockRequestPermissionResult;

  int _currentStepCount = 0;

  FakeSensorDataSource({
    this.mockAvailability = const SensorAvailability(),
    this.mockPermissionStatus = SensorPermissionStatus.granted,
    this.mockRequestPermissionResult,
  });

  @override
  Stream<SensorReading3D> get accelerometer => _accelController.stream;

  @override
  Stream<SensorReading3D> get gyroscope => _gyroController.stream;

  @override
  Stream<SensorReading3D> get magnetometer => _magController.stream;

  @override
  Stream<int> get stepCount => _stepController.stream;

  /// Emits a deterministic accelerometer measurement
  void emitAccelerometer(double x, double y, double z, [DateTime? timestamp]) {
    if (!_accelController.isClosed) {
      _accelController.add(SensorReading3D(x, y, z, timestamp ?? DateTime.now()));
    }
  }

  /// Emits a deterministic gyroscope measurement (rad/s)
  void emitGyroscope(double x, double y, double z, [DateTime? timestamp]) {
    if (!_gyroController.isClosed) {
      _gyroController.add(SensorReading3D(x, y, z, timestamp ?? DateTime.now()));
    }
  }

  /// Emits a deterministic magnetometer measurement (microteslas)
  void emitMagnetometer(double x, double y, double z, [DateTime? timestamp]) {
    if (!_magController.isClosed) {
      _magController.add(SensorReading3D(x, y, z, timestamp ?? DateTime.now()));
    }
  }

  /// Emits a deterministic step count
  void emitStepCount(int steps) {
    _currentStepCount = steps;
    if (!_stepController.isClosed) {
      _stepController.add(steps);
    }
  }

  /// Simulates a single pedestrian step
  void emitStep() {
    emitStepCount(_currentStepCount + 1);
  }

  /// Emits an error on the accelerometer stream
  void emitAccelerometerError(Object error) {
    if (!_accelController.isClosed) {
      _accelController.addError(error);
    }
  }

  @override
  Future<SensorAvailability> checkAvailability() async => mockAvailability;

  @override
  Future<SensorPermissionStatus> checkPermissions() async {
    debugPrint('[MAPLESS][PERMISSION] Activity Recognition status: $mockPermissionStatus');
    return mockPermissionStatus;
  }

  @override
  Future<SensorPermissionStatus> requestPermissions() async {
    debugPrint('[MAPLESS][PERMISSION] Requesting Activity Recognition...');
    final result = mockRequestPermissionResult ?? mockPermissionStatus;
    mockPermissionStatus = result;
    debugPrint('[MAPLESS][PERMISSION] Result: $result');
    return result;
  }

  @override
  void dispose() {
    if (!_accelController.isClosed) _accelController.close();
    if (!_gyroController.isClosed) _gyroController.close();
    if (!_magController.isClosed) _magController.close();
    if (!_stepController.isClosed) _stepController.close();
  }
}
