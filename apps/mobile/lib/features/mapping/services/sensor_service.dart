import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sensor_config.dart';
import 'sensor_data_source.dart';
import 'sensor_math.dart';
import 'sensor_models.dart';

/// Legacy compatibility alias for SensorReading
typedef SensorReading = SensorReading3D;

/// Smartphone Sensor Service Interface
/// Owner: Nishant (Sensors & Creator Mapping Workflow)
///
/// Sensors are used strictly for creator-assisted relative map construction
/// (step detection, relative heading tracking, local X/Y coordinate estimation).
abstract class ISensorService {
  // Streams
  Stream<SensorState> get stateStream;
  Stream<int> get stepCountStream;
  Stream<double> get compassHeadingStream;
  Stream<SensorReading3D> get accelerometerStream;
  Stream<SensorReading3D> get gyroscopeStream;

  // State inspection
  SensorState get state;
  bool get isRecording;

  // Lifecycle
  Future<void> initialize({ISensorDataSource? dataSource});
  void start();
  void pause();
  void resume();
  void stop();
  void reset();
  void calibrate();
  void setStepLength(double length);
  Future<SensorPermissionStatus> requestPermissions();

  // Backward compatibility methods
  void startRecording();
  void stopRecording();
  void dispose();
}

/// Primary Implementation of the Smartphone Sensor Engine
class SensorService implements ISensorService {
  ISensorDataSource _dataSource;
  SensorState _state = const SensorState();

  // Active subscriptions
  StreamSubscription<SensorReading3D>? _accelSub;
  StreamSubscription<SensorReading3D>? _gyroSub;
  StreamSubscription<SensorReading3D>? _magSub;
  StreamSubscription<int>? _stepSub;

  // Internal stream controllers
  final _stateController = StreamController<SensorState>.broadcast(sync: true);
  final _stepController = StreamController<int>.broadcast(sync: true);
  final _headingController = StreamController<double>.broadcast(sync: true);
  final _accelController = StreamController<SensorReading3D>.broadcast(sync: true);
  final _gyroController = StreamController<SensorReading3D>.broadcast(sync: true);

  // Mathematical filtering and dead reckoning tracking variables
  SensorReading3D _filteredAccel = const SensorReading3D(0, 0, 9.8);
  SensorReading3D _lastMag = const SensorReading3D(0, 25, 0);
  DateTime? _lastGyroTimestamp;
  int? _initialHardwareStepOffset;
  DateTime _lastFallbackStepTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _fallbackPedometerArmed = true;

  SensorService({ISensorDataSource? dataSource})
      : _dataSource = dataSource ?? RealSensorDataSource() {
    if (_dataSource is FakeSensorDataSource) {
      final fake = _dataSource as FakeSensorDataSource;
      _state = _state.copyWith(permissionStatus: fake.mockPermissionStatus);
    }
  }

  @override
  Stream<SensorState> get stateStream => _stateController.stream;

  @override
  Stream<int> get stepCountStream => _stepController.stream;

  @override
  Stream<double> get compassHeadingStream => _headingController.stream;

  @override
  Stream<SensorReading3D> get accelerometerStream => _accelController.stream;

  @override
  Stream<SensorReading3D> get gyroscopeStream => _gyroController.stream;

  @override
  SensorState get state => _state;

  @override
  bool get isRecording => _state.isRunning && !_state.isPaused;

  /// Initializes the engine, checks sensor availability and queries permissions
  @override
  Future<void> initialize({ISensorDataSource? dataSource}) async {
    if (dataSource != null) {
      _cancelSubscriptions();
      _dataSource.dispose();
      _dataSource = dataSource;
      if (_dataSource is FakeSensorDataSource) {
        final fake = _dataSource as FakeSensorDataSource;
        _state = _state.copyWith(permissionStatus: fake.mockPermissionStatus);
      }
    }

    try {
      final availability = await _dataSource.checkAvailability();
      final permission = await _dataSource.checkPermissions();

      _state = _state.copyWith(
        isAvailable: !availability.isNone,
        availability: availability,
        permissionStatus: permission,
        status: availability.isNone
            ? SensorEngineStatus.degraded
            : (permission == SensorPermissionStatus.denied
                ? SensorEngineStatus.error
                : SensorEngineStatus.idle),
        errorMessage: permission == SensorPermissionStatus.denied
            ? 'Physical activity sensor permission denied. Manual authoring is active.'
            : (availability.isNone
                ? 'Motion sensors unavailable on this hardware. Manual authoring is active.'
                : null),
      );
      _emitState();
    } catch (e) {
      _state = _state.copyWith(
        status: SensorEngineStatus.degraded,
        errorMessage: 'Failed to query sensor hardware: $e. Manual authoring is active.',
      );
      _emitState();
    }
  }

  /// Requests Activity Recognition permission at runtime
  @override
  Future<SensorPermissionStatus> requestPermissions() async {
    final status = await _dataSource.requestPermissions();
    final isGranted = status == SensorPermissionStatus.granted;
    _state = _state.copyWith(
      permissionStatus: status,
      status: isGranted
          ? (_state.isRunning ? SensorEngineStatus.running : SensorEngineStatus.idle)
          : SensorEngineStatus.degraded,
      errorMessage: isGranted
          ? null
          : 'Physical activity recognition permission is required for automatic step counting. Manual coordinate authoring remains available.',
      clearError: isGranted,
    );
    _emitState();

    if (isGranted && _state.isRunning && _stepSub == null) {
      debugPrint('[MAPLESS][STEP] Subscribing to stepCountStream');
      _stepSub = _dataSource.stepCount.listen(
        _handleHardwareStepCount,
        onError: (error) => _handleStreamError('Pedometer', error),
      );
    }
    return status;
  }

  /// Starts sensor streams and relative coordinate dead reckoning
  /// Safe to call repeatedly (idempotent; no duplicate listeners created).
  @override
  void start() {
    if (_state.isRunning) {
      if (_stepSub != null || _state.permissionStatus == SensorPermissionStatus.denied) {
        return; // Already running with active subscription (or already handled permission denial for this run)
      }
    }

    _cancelSubscriptions();

    final hasPermission = _state.permissionStatus == SensorPermissionStatus.granted;

    _state = _state.copyWith(
      isRunning: true,
      isPaused: false,
      status: hasPermission ? SensorEngineStatus.running : SensorEngineStatus.degraded,
      errorMessage: hasPermission
          ? null
          : (_state.permissionStatus == SensorPermissionStatus.denied
              ? 'Physical activity recognition permission is required for automatic step counting. Manual coordinate authoring remains available.'
              : null),
      clearError: hasPermission,
    );
    _emitState();

    // 1. Accelerometer Subscription
    _accelSub ??= _dataSource.accelerometer.listen(
      _handleAccelerometer,
      onError: (error) => _handleStreamError('Accelerometer', error),
    );

    // 2. Gyroscope Subscription
    _gyroSub ??= _dataSource.gyroscope.listen(
      _handleGyroscope,
      onError: (error) => _handleStreamError('Gyroscope', error),
    );

    // 3. Magnetometer Subscription
    _magSub ??= _dataSource.magnetometer.listen(
      _handleMagnetometer,
      onError: (error) => _handleStreamError('Magnetometer', error),
    );

    // 4. Hardware Pedometer Subscription
    if (hasPermission) {
      debugPrint('[MAPLESS][STEP] Subscribing to stepCountStream');
      _stepSub ??= _dataSource.stepCount.listen(
        _handleHardwareStepCount,
        onError: (error) => _handleStreamError('Pedometer', error),
      );
    } else {
      _checkAndRequestStepPermission();
    }
  }

  Future<void> _checkAndRequestStepPermission() async {
    var permission = await _dataSource.checkPermissions();
    if (permission != SensorPermissionStatus.granted) {
      permission = await _dataSource.requestPermissions();
    }

    if (!_state.isRunning) return;

    final isGranted = permission == SensorPermissionStatus.granted;
    _state = _state.copyWith(
      permissionStatus: permission,
      status: isGranted ? SensorEngineStatus.running : SensorEngineStatus.degraded,
      errorMessage: isGranted
          ? null
          : 'Physical activity recognition permission is required for automatic step counting. Manual coordinate authoring remains available.',
      clearError: isGranted,
    );
    _emitState();

    if (isGranted && _stepSub == null) {
      debugPrint('[MAPLESS][STEP] Subscribing to stepCountStream');
      _stepSub = _dataSource.stepCount.listen(
        _handleHardwareStepCount,
        onError: (error) => _handleStreamError('Pedometer', error),
      );
    }
  }

  /// Pauses motion integration without discarding current coordinates
  @override
  void pause() {
    if (!_state.isRunning || _state.isPaused) return;

    _state = _state.copyWith(
      isPaused: true,
      status: SensorEngineStatus.paused,
    );
    _emitState();
  }

  /// Resumes motion integration
  @override
  void resume() {
    if (!_state.isRunning || !_state.isPaused) return;

    _state = _state.copyWith(
      isPaused: false,
      status: SensorEngineStatus.running,
    );
    _emitState();
  }

  /// Stops streams and cleans up hardware subscriptions
  /// Safe to call repeatedly without error.
  @override
  void stop() {
    _cancelSubscriptions();

    _state = _state.copyWith(
      isRunning: false,
      isPaused: false,
      status: _state.hasError ? SensorEngineStatus.degraded : SensorEngineStatus.idle,
    );
    _emitState();
  }

  /// Resets relative position (x=0, y=0), step count, and distance to zero
  @override
  void reset() {
    _initialHardwareStepOffset = null;
    _state = _state.copyWith(
      stepCount: 0,
      distance: 0.0,
      x: 0.0,
      y: 0.0,
      clearError: true,
    );
    _emitState();
  }

  /// Calibrates the engine by zeroing the current heading as forward baseline (0°)
  @override
  void calibrate() {
    final currentRawHeading = _state.heading;
    _state = _state.copyWith(
      headingOffset: currentRawHeading,
      calibrationState: SensorCalibrationState.calibrated,
    );
    _emitState();
  }

  /// Updates the assumed step length in meters
  @override
  void setStepLength(double length) {
    final clamped = length.clamp(SensorConfig.minStepLength, SensorConfig.maxStepLength);
    final newDistance = _state.stepCount * clamped;
    _state = _state.copyWith(
      stepLength: clamped,
      distance: newDistance,
    );
    _emitState();
  }

  // --- Legacy Compatibility Implementations ---
  @override
  void startRecording() => start();

  @override
  void stopRecording() => stop();

  @override
  void dispose() {
    stop();
    _dataSource.dispose();
    if (!_stateController.isClosed) _stateController.close();
    if (!_stepController.isClosed) _stepController.close();
    if (!_headingController.isClosed) _headingController.close();
    if (!_accelController.isClosed) _accelController.close();
    if (!_gyroController.isClosed) _gyroController.close();
  }

  // --- Internal Sensor Processing ---

  void _cancelSubscriptions() {
    final accel = _accelSub;
    final gyro = _gyroSub;
    final mag = _magSub;
    final step = _stepSub;

    // Immediately clear stored references to prevent duplicate cancellation or race conditions
    _accelSub = null;
    _gyroSub = null;
    _magSub = null;
    _stepSub = null;

    _safeCancelSubscription(accel, 'Accelerometer');
    _safeCancelSubscription(gyro, 'Gyroscope');
    _safeCancelSubscription(mag, 'Magnetometer');
    _safeCancelSubscription(step, 'Pedometer');
  }

  void _safeCancelSubscription(StreamSubscription? sub, String name) {
    if (sub == null) return;
    try {
      final cancelFuture = sub.cancel();
      cancelFuture.catchError((error) {
        if (error is PlatformException &&
            error.message != null &&
            error.message!.contains('No active stream to cancel')) {
          return;
        }
        _handleStreamError(name, error);
      });
    } on PlatformException catch (e) {
      if (e.message != null && e.message!.contains('No active stream to cancel')) {
        return;
      }
      _handleStreamError(name, e);
    } catch (e) {
      _handleStreamError(name, e);
    }
  }

  void _handleAccelerometer(SensorReading3D event) {
    if (!event.isValid) return;

    // Filter noisy acceleration
    _filteredAccel = SensorMath.lowPassFilter(
      current: event,
      previous: _filteredAccel,
    );

    if (!_accelController.isClosed) {
      _accelController.add(_filteredAccel);
    }

    // Fallback step detection if pedometer is unavailable
    if (!_state.availability.hasPedometer && _state.isRunning && !_state.isPaused) {
      _checkFallbackAccelerometerStep(event);
    }
  }

  void _handleGyroscope(SensorReading3D event) {
    if (!event.isValid) return;

    final now = event.timestamp ?? DateTime.now();
    if (_lastGyroTimestamp != null && _state.isRunning) {
      final dt = now.difference(_lastGyroTimestamp!).inMicroseconds / 1000000.0;
      if (dt > 0.0 && dt < 1.0) {
        // Gyro Z is yaw rate (around vertical axis)
        final yawRate = event.z.clamp(-SensorConfig.maxAngularVelocity, SensorConfig.maxAngularVelocity);
        final magHeading = SensorMath.calculateAzimuth(
          mag: _lastMag,
          accel: _filteredAccel,
        );

        final fused = SensorMath.fuseHeading(
          previousHeading: _state.heading,
          gyroYawRateRadSec: yawRate,
          magneticHeading: magHeading,
          dtSeconds: dt,
        );

        _updateHeading(fused);
      }
    }
    _lastGyroTimestamp = now;

    if (!_gyroController.isClosed) {
      _gyroController.add(event);
    }
  }

  void _handleMagnetometer(SensorReading3D event) {
    if (!event.isValid) return;
    _lastMag = event;

    // If gyroscope is unavailable, update heading directly from tilt-compensated magnetometer
    if (!_state.availability.hasGyroscope || _lastGyroTimestamp == null) {
      final azimuth = SensorMath.calculateAzimuth(
        mag: event,
        accel: _filteredAccel,
      );
      _updateHeading(azimuth);
    }
  }

  void _handleHardwareStepCount(int hardwareSteps) {
    if (!_state.isRunning || _state.isPaused) return;

    if (_initialHardwareStepOffset == null) {
      _initialHardwareStepOffset = hardwareSteps;
      debugPrint('[MAPLESS][STEP] StepCount event: raw=$hardwareSteps');
      debugPrint('[MAPLESS][STEP] Baseline=$_initialHardwareStepOffset');
      debugPrint('[MAPLESS][STEP] Relative steps=0');
      return;
    }

    final relativeSteps = hardwareSteps - _initialHardwareStepOffset!;
    debugPrint('[MAPLESS][STEP] StepCount event: raw=$hardwareSteps');
    debugPrint('[MAPLESS][STEP] Baseline=$_initialHardwareStepOffset');
    debugPrint('[MAPLESS][STEP] Relative steps=$relativeSteps');

    if (relativeSteps > _state.stepCount) {
      final stepIncrement = relativeSteps - _state.stepCount;
      for (int i = 0; i < stepIncrement; i++) {
        _onStepDetected();
      }
    }
  }

  /// Controlled accelerometer peak-detection fallback when hardware pedometer is missing
  void _checkFallbackAccelerometerStep(SensorReading3D event) {
    final magnitude = event.magnitude;
    final now = event.timestamp ?? DateTime.now();

    if (magnitude > SensorConfig.fallbackStepPeakThreshold) {
      if (_fallbackPedometerArmed) {
        final elapsed = now.difference(_lastFallbackStepTime).inMilliseconds;
        if (elapsed >= SensorConfig.minStepIntervalMs) {
          _lastFallbackStepTime = now;
          _fallbackPedometerArmed = false;
          _onStepDetected();
        }
      }
    } else if (magnitude < 10.2) {
      // Re-arm trigger once acceleration returns close to 1g
      _fallbackPedometerArmed = true;
    }
  }

  /// Executes dead reckoning integration for each detected step
  void _onStepDetected() {
    final effectiveHeading = _state.calibratedHeading;
    final displacement = SensorMath.calculateDisplacement(
      distance: _state.stepLength,
      headingDegrees: effectiveHeading,
    );

    final newStepCount = _state.stepCount + 1;
    final newDistance = newStepCount * _state.stepLength;
    final newX = _state.x + displacement.dx;
    final newY = _state.y + displacement.dy;

    _state = _state.copyWith(
      stepCount: newStepCount,
      distance: newDistance,
      x: newX,
      y: newY,
      lastReadingTimestamp: DateTime.now(),
    );

    if (!_stepController.isClosed) {
      _stepController.add(newStepCount);
    }
    _emitState();
  }

  void _updateHeading(double newHeading) {
    _state = _state.copyWith(
      heading: newHeading,
      lastReadingTimestamp: DateTime.now(),
    );

    if (!_headingController.isClosed) {
      _headingController.add(newHeading);
    }
    _emitState();
  }

  void _handleStreamError(String sensorName, Object error) {
    _state = _state.copyWith(
      status: SensorEngineStatus.degraded,
      errorMessage: '$sensorName stream error: $error. Falling back to manual creator mode.',
    );
    _emitState();
  }

  void _emitState() {
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
