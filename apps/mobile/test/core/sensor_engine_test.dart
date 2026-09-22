import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/features/mapping/services/sensor_config.dart';
import 'package:mapless_ai/features/mapping/services/sensor_data_source.dart';
import 'package:mapless_ai/features/mapping/services/sensor_math.dart';
import 'package:mapless_ai/features/mapping/services/sensor_models.dart';
import 'package:mapless_ai/features/mapping/services/sensor_provider.dart';
import 'package:mapless_ai/features/mapping/services/sensor_service.dart';

void main() {
  group('1. Sensor Models & Domain Objects', () {
    test('SensorReading3D calculates Euclidean magnitude and validates values', () {
      const reading = SensorReading3D(3.0, 4.0, 12.0);
      expect(reading.magnitude, closeTo(13.0, 1e-9));
      expect(reading.isValid, isTrue);

      const nanReading = SensorReading3D(double.nan, 4.0, 12.0);
      expect(nanReading.isValid, isFalse);
      final sanitized = nanReading.sanitized();
      expect(sanitized.isValid, isTrue);
      expect(sanitized.x, equals(0.0));
      expect(sanitized.y, equals(4.0));
      expect(sanitized.z, equals(12.0));

      const infReading = SensorReading3D(3.0, double.infinity, 12.0);
      expect(infReading.isValid, isFalse);
      expect(infReading.sanitized().y, equals(0.0));

      expect(reading.toString(), contains('SensorReading3D'));
    });

    test('SensorAvailability flags assess full, minimum viable, and none states', () {
      const full = SensorAvailability();
      expect(full.isFull, isTrue);
      expect(full.isMinimumViable, isTrue);
      expect(full.isNone, isFalse);

      const none = SensorAvailability.none();
      expect(none.isFull, isFalse);
      expect(none.isMinimumViable, isFalse);
      expect(none.isNone, isTrue);

      const noPedometer = SensorAvailability(
        hasAccelerometer: true,
        hasGyroscope: true,
        hasMagnetometer: true,
        hasPedometer: false,
      );
      expect(noPedometer.isFull, isFalse);
      expect(noPedometer.isMinimumViable, isTrue);
      expect(noPedometer.isNone, isFalse);

      const accelOnly = SensorAvailability(
        hasAccelerometer: true,
        hasGyroscope: false,
        hasMagnetometer: false,
        hasPedometer: false,
      );
      expect(accelOnly.isMinimumViable, isFalse);
    });

    test('SensorState defaults and copyWith preserve immutability and handle errors', () {
      const state = SensorState();
      expect(state.isAvailable, isTrue);
      expect(state.isRunning, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.stepCount, equals(0));
      expect(state.distance, equals(0.0));
      expect(state.heading, equals(0.0));
      expect(state.x, equals(0.0));
      expect(state.y, equals(0.0));
      expect(state.stepLength, equals(SensorConfig.defaultStepLength));
      expect(state.hasError, isFalse);

      final withError = state.copyWith(errorMessage: 'Sensor malfunction');
      expect(withError.hasError, isTrue);
      expect(withError.errorMessage, equals('Sensor malfunction'));

      final cleared = withError.copyWith(clearError: true);
      expect(cleared.hasError, isFalse);
      expect(cleared.errorMessage, isNull);
    });

    test('SensorState calibratedHeading normalizes relative heading around offset', () {
      // Raw heading 120°, offset 90° -> 30°
      const state1 = SensorState(heading: 120.0, headingOffset: 90.0);
      expect(state1.calibratedHeading, closeTo(30.0, 1e-9));

      // Raw heading 30°, offset 90° -> -60° wrapped to 300°
      const state2 = SensorState(heading: 30.0, headingOffset: 90.0);
      expect(state2.calibratedHeading, closeTo(300.0, 1e-9));

      // Exact match -> 0°
      const state3 = SensorState(heading: 180.0, headingOffset: 180.0);
      expect(state3.calibratedHeading, closeTo(0.0, 1e-9));
    });
  });

  group('2. SensorMath Geometric & Signal Processing Engine', () {
    test('normalizeHeading wraps angles properly to [0.0, 360.0)', () {
      expect(SensorMath.normalizeHeading(0.0), equals(0.0));
      expect(SensorMath.normalizeHeading(360.0), equals(0.0));
      expect(SensorMath.normalizeHeading(720.0), equals(0.0));
      expect(SensorMath.normalizeHeading(450.0), equals(90.0));
      expect(SensorMath.normalizeHeading(-90.0), equals(270.0));
      expect(SensorMath.normalizeHeading(-360.0), equals(0.0));
      expect(SensorMath.normalizeHeading(-450.0), equals(270.0));
      expect(SensorMath.normalizeHeading(double.nan), equals(0.0));
      expect(SensorMath.normalizeHeading(double.infinity), equals(0.0));
    });

    test('calculateDisplacement maps cardinal directions accurately', () {
      const step = 1.0;

      // North (0°): dx = 0, dy = +1
      final north = SensorMath.calculateDisplacement(distance: step, headingDegrees: 0.0);
      expect(north.dx, closeTo(0.0, 1e-9));
      expect(north.dy, closeTo(1.0, 1e-9));

      // East (90°): dx = +1, dy = 0
      final east = SensorMath.calculateDisplacement(distance: step, headingDegrees: 90.0);
      expect(east.dx, closeTo(1.0, 1e-9));
      expect(east.dy, closeTo(0.0, 1e-9));

      // South (180°): dx = 0, dy = -1
      final south = SensorMath.calculateDisplacement(distance: step, headingDegrees: 180.0);
      expect(south.dx, closeTo(0.0, 1e-9));
      expect(south.dy, closeTo(-1.0, 1e-9));

      // West (270°): dx = -1, dy = 0
      final west = SensorMath.calculateDisplacement(distance: step, headingDegrees: 270.0);
      expect(west.dx, closeTo(-1.0, 1e-9));
      expect(west.dy, closeTo(0.0, 1e-9));
    });

    test('calculateDisplacement maps diagonal directions accurately', () {
      const step = 10.0;
      final expectedComponent = step * math.sin(math.pi / 4.0); // 10 * sin(45°) ≈ 7.071

      // North-East (45°): +dx, +dy
      final ne = SensorMath.calculateDisplacement(distance: step, headingDegrees: 45.0);
      expect(ne.dx, closeTo(expectedComponent, 1e-3));
      expect(ne.dy, closeTo(expectedComponent, 1e-3));

      // South-East (135°): +dx, -dy
      final se = SensorMath.calculateDisplacement(distance: step, headingDegrees: 135.0);
      expect(se.dx, closeTo(expectedComponent, 1e-3));
      expect(se.dy, closeTo(-expectedComponent, 1e-3));

      // South-West (225°): -dx, -dy
      final sw = SensorMath.calculateDisplacement(distance: step, headingDegrees: 225.0);
      expect(sw.dx, closeTo(-expectedComponent, 1e-3));
      expect(sw.dy, closeTo(-expectedComponent, 1e-3));

      // North-West (315°): -dx, +dy
      final nw = SensorMath.calculateDisplacement(distance: step, headingDegrees: 315.0);
      expect(nw.dx, closeTo(-expectedComponent, 1e-3));
      expect(nw.dy, closeTo(expectedComponent, 1e-3));
    });

    test('calculateDisplacement rejects zero, negative, and invalid distance', () {
      final zero = SensorMath.calculateDisplacement(distance: 0.0, headingDegrees: 45.0);
      expect(zero.dx, equals(0.0));
      expect(zero.dy, equals(0.0));

      final neg = SensorMath.calculateDisplacement(distance: -5.0, headingDegrees: 45.0);
      expect(neg.dx, equals(0.0));
      expect(neg.dy, equals(0.0));

      final nanDist = SensorMath.calculateDisplacement(distance: double.nan, headingDegrees: 45.0);
      expect(nanDist.dx, equals(0.0));
      expect(nanDist.dy, equals(0.0));
    });

    test('lowPassFilter smooths vectors and clamps extreme acceleration spikes', () {
      const prev = SensorReading3D(0.0, 0.0, 9.8);
      // Spike beyond maxLinearAcceleration (35 m/s^2)
      const spike = SensorReading3D(100.0, 0.0, 9.8);

      final filtered = SensorMath.lowPassFilter(
        current: spike,
        previous: prev,
        alpha: 0.2,
      );

      // Spike should have been clamped to 35.0 m/s^2 before low-pass blending:
      // output = 0.0 + 0.2 * (35.0 - 0.0) = 7.0
      expect(filtered.x, closeTo(7.0, 1e-5));
      expect(filtered.y, equals(0.0));
      expect(filtered.z, equals(9.8));
    });

    test('calculateAzimuth computes correct heading for planar magnetic readings', () {
      // Flat device pointing North: Earth B-field along +Y
      const northMag = SensorReading3D(0.0, 25.0, -40.0);
      expect(SensorMath.calculateAzimuth(mag: northMag), closeTo(0.0, 1e-3));

      // Flat device pointing East: Earth B-field along -X
      const eastMag = SensorReading3D(-25.0, 0.0, -40.0);
      expect(SensorMath.calculateAzimuth(mag: eastMag), closeTo(90.0, 1e-3));

      // Flat device pointing South: Earth B-field along -Y
      const southMag = SensorReading3D(0.0, -25.0, -40.0);
      expect(SensorMath.calculateAzimuth(mag: southMag), closeTo(180.0, 1e-3));

      // Flat device pointing West: Earth B-field along +X
      const westMag = SensorReading3D(25.0, 0.0, -40.0);
      expect(SensorMath.calculateAzimuth(mag: westMag), closeTo(270.0, 1e-3));
    });

    test('calculateAzimuth supports 3D tilt-compensation with gravity vector', () {
      // Device pitched or held at an angle, gravity vector present
      const gravity = SensorReading3D(0.0, 0.0, 9.8);
      const northMag = SensorReading3D(0.0, 25.0, -40.0);

      final heading = SensorMath.calculateAzimuth(mag: northMag, accel: gravity);
      expect(heading, closeTo(0.0, 1e-3));
    });

    test('fuseHeading smoothly blends gyro integration and magnetic compass', () {
      // Initial heading 0°, gyro yaw rate 0.1 rad/s (~5.73 deg/s) for 1 second, mag heading 6°
      final fused = SensorMath.fuseHeading(
        previousHeading: 0.0,
        gyroYawRateRadSec: 0.1,
        magneticHeading: 6.0,
        dtSeconds: 1.0,
        alpha: 0.9,
      );

      // Gyro estimate: 0 + 0.1 * (180/pi) ≈ 5.7296°
      // Fused = 5.7296 + (1 - 0.9) * (6.0 - 5.7296) ≈ 5.7566°
      expect(fused, closeTo(5.756, 0.05));
    });

    test('fuseHeading handles 360° boundary wraparound seamlessly', () {
      // Previous heading 359°, gyro turns +2° (wraps to 1°), mag reads 1°
      final fused = SensorMath.fuseHeading(
        previousHeading: 359.0,
        gyroYawRateRadSec: (2.0 * math.pi) / 180.0, // 2 deg in rad
        magneticHeading: 1.0,
        dtSeconds: 1.0,
        alpha: 0.95,
      );

      expect(fused, closeTo(1.0, 0.1));
    });

    test('shortestAngleDifference handles direct and wrap-around angles', () {
      expect(SensorMath.shortestAngleDifference(90.0, 45.0), closeTo(45.0, 1e-9));
      expect(SensorMath.shortestAngleDifference(45.0, 90.0), closeTo(-45.0, 1e-9));
      // Across 0° boundary: 10° - 350° = +20°
      expect(SensorMath.shortestAngleDifference(10.0, 350.0), closeTo(20.0, 1e-9));
      // 350° - 10° = -20°
      expect(SensorMath.shortestAngleDifference(350.0, 10.0), closeTo(-20.0, 1e-9));
    });
  });

  group('3. SensorService Lifecycle & Idempotency', () {
    late FakeSensorDataSource fakeSource;
    late SensorService service;

    setUp(() {
      fakeSource = FakeSensorDataSource();
      service = SensorService(dataSource: fakeSource);
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state has default values and idle status', () {
      expect(service.state.isRunning, isFalse);
      expect(service.state.isPaused, isFalse);
      expect(service.state.status, equals(SensorEngineStatus.idle));
      expect(service.isRecording, isFalse);
    });

    test('initialize queries hardware availability and permissions', () async {
      await service.initialize();
      expect(service.state.isAvailable, isTrue);
      expect(service.state.permissionStatus, equals(SensorPermissionStatus.granted));
      expect(service.state.status, equals(SensorEngineStatus.idle));
    });

    test('start transitions to running and is idempotent on repeated calls', () {
      service.start();
      expect(service.state.isRunning, isTrue);
      expect(service.state.isPaused, isFalse);
      expect(service.state.status, equals(SensorEngineStatus.running));
      expect(service.isRecording, isTrue);

      // Repeated call must not crash or duplicate listeners
      service.start();
      expect(service.state.isRunning, isTrue);
    });

    test('pause and resume control dead reckoning integration', () {
      service.start();
      service.pause();
      expect(service.state.isPaused, isTrue);
      expect(service.state.status, equals(SensorEngineStatus.paused));
      expect(service.isRecording, isFalse);

      service.resume();
      expect(service.state.isPaused, isFalse);
      expect(service.state.status, equals(SensorEngineStatus.running));
      expect(service.isRecording, isTrue);
    });

    test('stop terminates streams and is idempotent on repeated calls', () {
      service.start();
      service.stop();
      expect(service.state.isRunning, isFalse);
      expect(service.state.isPaused, isFalse);
      expect(service.state.status, equals(SensorEngineStatus.idle));
      expect(service.isRecording, isFalse);

      // Repeated stop must not throw
      expect(() => service.stop(), returnsNormally);
    });

    test('reset restores coordinates, steps, and distance to zero baseline', () {
      service.start();
      // Simulate baseline and 2 steps
      fakeSource.emitStepCount(0);
      fakeSource.emitStepCount(2);

      expect(service.state.stepCount, equals(2));
      expect(service.state.distance, greaterThan(0));

      service.reset();
      expect(service.state.stepCount, equals(0));
      expect(service.state.distance, equals(0.0));
      expect(service.state.x, equals(0.0));
      expect(service.state.y, equals(0.0));
    });

    test('legacy compatibility methods startRecording and stopRecording delegate safely', () {
      service.startRecording();
      expect(service.isRecording, isTrue);

      service.stopRecording();
      expect(service.isRecording, isFalse);
    });
  });

  group('4. Step Detection, Distance & Dead Reckoning', () {
    late FakeSensorDataSource fakeSource;
    late SensorService service;

    setUp(() {
      fakeSource = FakeSensorDataSource();
      service = SensorService(dataSource: fakeSource);
      service.start();
    });

    tearDown(() {
      service.dispose();
    });

    test('hardware pedometer baseline and step accumulation', () {
      // Initial hardware counter value establishes baseline
      fakeSource.emitStepCount(100);
      expect(service.state.stepCount, equals(0));

      // Step 1
      fakeSource.emitStepCount(101);
      expect(service.state.stepCount, equals(1));
      expect(service.state.distance, closeTo(SensorConfig.defaultStepLength, 1e-9));

      // 4 more steps in one batch
      fakeSource.emitStepCount(105);
      expect(service.state.stepCount, equals(5));
      expect(service.state.distance, closeTo(5 * SensorConfig.defaultStepLength, 1e-9));
    });

    test('steps are ignored while paused', () {
      fakeSource.emitStepCount(100);
      service.pause();

      fakeSource.emitStepCount(105);
      expect(service.state.stepCount, equals(0));

      service.resume();
      fakeSource.emitStepCount(106);
      expect(service.state.stepCount, equals(6));
    });

    test('configurable step length clamps within bounds and recalculates distance', () {
      fakeSource.emitStepCount(0);
      fakeSource.emitStepCount(4); // 4 steps

      service.setStepLength(0.80);
      expect(service.state.stepLength, equals(0.80));
      expect(service.state.distance, closeTo(4 * 0.80, 1e-9));

      // Clamping minimum
      service.setStepLength(0.10);
      expect(service.state.stepLength, equals(SensorConfig.minStepLength));

      // Clamping maximum
      service.setStepLength(5.0);
      expect(service.state.stepLength, equals(SensorConfig.maxStepLength));
    });

    test('dead reckoning updates local coordinates according to heading', () {
      // Set heading North (0°) by emitting magnetometer reading pointing North
      fakeSource.emitMagnetometer(0.0, 25.0, -40.0);
      expect(service.state.heading, closeTo(0.0, 1e-3));

      fakeSource.emitStepCount(0); // Baseline offset
      fakeSource.emitStepCount(1); // 1 step North (0°)

      expect(service.state.x, closeTo(0.0, 1e-9));
      expect(service.state.y, closeTo(SensorConfig.defaultStepLength, 1e-9));

      // Turn East (90°)
      fakeSource.emitMagnetometer(-25.0, 0.0, -40.0);
      expect(service.state.heading, closeTo(90.0, 1e-3));

      fakeSource.emitStepCount(2); // 1 step East (90°)
      expect(service.state.x, closeTo(SensorConfig.defaultStepLength, 1e-9));
      expect(service.state.y, closeTo(SensorConfig.defaultStepLength, 1e-9));

      // Turn South (180°)
      fakeSource.emitMagnetometer(0.0, -25.0, -40.0);
      expect(service.state.heading, closeTo(180.0, 1e-3));

      fakeSource.emitStepCount(3); // 1 step South (180°)
      expect(service.state.x, closeTo(SensorConfig.defaultStepLength, 1e-9));
      expect(service.state.y, closeTo(0.0, 1e-9));

      // Turn West (270°)
      fakeSource.emitMagnetometer(25.0, 0.0, -40.0);
      expect(service.state.heading, closeTo(270.0, 1e-3));

      fakeSource.emitStepCount(4); // 1 step West (270°)
      expect(service.state.x, closeTo(0.0, 1e-9));
      expect(service.state.y, closeTo(0.0, 1e-9));
    });

    test('fallback accelerometer step detection works when pedometer is unavailable', () async {
      // Re-initialize with no pedometer
      final noPedometerSource = FakeSensorDataSource(
        mockAvailability: const SensorAvailability(
          hasAccelerometer: true,
          hasGyroscope: true,
          hasMagnetometer: true,
          hasPedometer: false,
        ),
      );
      final fallbackService = SensorService(dataSource: noPedometerSource);
      await fallbackService.initialize();
      fallbackService.start();

      // Heading North (0°)
      noPedometerSource.emitMagnetometer(0.0, 25.0, -40.0);

      // 1. Quiescent baseline (~1g = 9.8 m/s^2)
      noPedometerSource.emitAccelerometer(0.0, 0.0, 9.8, DateTime.now());
      expect(fallbackService.state.stepCount, equals(0));

      // 2. High-impact acceleration spike above threshold (13.0 m/s^2)
      final t1 = DateTime.now().add(const Duration(milliseconds: 300));
      noPedometerSource.emitAccelerometer(0.0, 0.0, 13.0, t1);
      expect(fallbackService.state.stepCount, equals(1));

      // 3. Same peak continues without re-arming: should not double-count
      noPedometerSource.emitAccelerometer(0.0, 0.0, 13.2, t1.add(const Duration(milliseconds: 20)));
      expect(fallbackService.state.stepCount, equals(1));

      // 4. Return to resting (< 10.2 m/s^2) re-arms the detector
      noPedometerSource.emitAccelerometer(0.0, 0.0, 9.8, t1.add(const Duration(milliseconds: 100)));

      // 5. Next step after minimum interval
      final t2 = t1.add(const Duration(milliseconds: 350));
      noPedometerSource.emitAccelerometer(0.0, 0.0, 14.0, t2);
      expect(fallbackService.state.stepCount, equals(2));

      fallbackService.dispose();
    });
  });

  group('5. Calibration & Relative Heading Alignment', () {
    late FakeSensorDataSource fakeSource;
    late SensorService service;

    setUp(() {
      fakeSource = FakeSensorDataSource();
      service = SensorService(dataSource: fakeSource);
      service.start();
    });

    tearDown(() {
      service.dispose();
    });

    test('calibrate captures raw heading as zero-reference baseline', () {
      // Device facing East (90° raw)
      fakeSource.emitMagnetometer(-25.0, 0.0, -40.0);
      expect(service.state.heading, closeTo(90.0, 1e-3));
      expect(service.state.calibratedHeading, closeTo(90.0, 1e-3));

      // User calibrates facing down this corridor
      service.calibrate();
      expect(service.state.headingOffset, closeTo(90.0, 1e-3));
      expect(service.state.calibrationState, equals(SensorCalibrationState.calibrated));
      expect(service.state.calibratedHeading, closeTo(0.0, 1e-3)); // Corridor forward is now 0°!

      // Walking down the corridor advances along local +Y (forward) instead of +X
      fakeSource.emitStepCount(0);
      fakeSource.emitStepCount(1);

      expect(service.state.x, closeTo(0.0, 1e-9));
      expect(service.state.y, closeTo(SensorConfig.defaultStepLength, 1e-9));
    });
  });

  group('6. Hardware Failures, Permissions & Graceful Degradation', () {
    test('missing sensor hardware marks engine as degraded with manual authoring notice', () async {
      final noneSource = FakeSensorDataSource(
        mockAvailability: const SensorAvailability.none(),
      );
      final service = SensorService(dataSource: noneSource);
      await service.initialize();

      expect(service.state.isAvailable, isFalse);
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.errorMessage, contains('Manual authoring is active'));

      service.dispose();
    });

    test('permission denied marks engine as error with manual authoring notice', () async {
      final deniedSource = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.denied,
      );
      final service = SensorService(dataSource: deniedSource);
      await service.initialize();

      expect(service.state.permissionStatus, equals(SensorPermissionStatus.denied));
      expect(service.state.status, equals(SensorEngineStatus.error));
      expect(service.state.errorMessage, contains('permission denied'));

      service.dispose();
    });

    test('stream errors degrade safely without terminating app or crashing', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);
      service.start();

      fakeSource.emitAccelerometerError('Hardware disconnected');
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.errorMessage, contains('Accelerometer stream error'));

      service.dispose();
    });
  });

  group('7. Riverpod Provider Integration', () {
    test('sensorStateProvider propagates state and notifier actions correctly', () {
      final fakeSource = FakeSensorDataSource();
      final testService = SensorService(dataSource: fakeSource);

      final container = ProviderContainer(
        overrides: [
          sensorServiceProvider.overrideWithValue(testService),
        ],
      );

      final initial = container.read(sensorStateProvider);
      expect(initial.isRunning, isFalse);

      // Start via notifier
      container.read(sensorStateProvider.notifier).start();
      expect(container.read(sensorStateProvider).isRunning, isTrue);

      // Step count via data source updates provider state
      fakeSource.emitStepCount(0);
      fakeSource.emitStepCount(1);
      expect(container.read(sensorStateProvider).stepCount, equals(1));

      // Pause and resume via notifier
      container.read(sensorStateProvider.notifier).pause();
      expect(container.read(sensorStateProvider).isPaused, isTrue);

      container.read(sensorStateProvider.notifier).resume();
      expect(container.read(sensorStateProvider).isPaused, isFalse);

      // Reset via notifier
      container.read(sensorStateProvider.notifier).reset();
      expect(container.read(sensorStateProvider).stepCount, equals(0));

      container.dispose();
      testService.dispose();
    });
  });

  group('8. Sensor Lifecycle Robustness & Safe Platform Cancellation', () {
    test('rapid start-stop-start-stop sequence executes safely and idempotently', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);

      service.start();
      expect(service.state.isRunning, isTrue);
      service.stop();
      expect(service.state.isRunning, isFalse);

      service.start();
      expect(service.state.isRunning, isTrue);
      service.stop();
      expect(service.state.isRunning, isFalse);

      service.dispose();
    });

    test('repeated start calls are idempotent and maintain exactly one listener', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);

      service.start();
      service.start();
      service.start();
      expect(service.state.isRunning, isTrue);

      // Baseline + 1 step
      fakeSource.emitStepCount(0);
      fakeSource.emitStepCount(1);

      // If duplicate listeners existed, step count would be incremented multiple times
      expect(service.state.stepCount, equals(1));

      service.dispose();
    });

    test('repeated stop calls are safe and never throw or duplicate cancellation', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);

      service.start();
      service.stop();
      expect(service.state.isRunning, isFalse);

      // Repeated calls must return normally without error
      expect(() => service.stop(), returnsNormally);
      expect(() => service.stop(), returnsNormally);
      expect(service.state.isRunning, isFalse);

      service.dispose();
    });

    test('pause-resume-pause-resume-stop cycle does not duplicate streams', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);

      service.start();
      fakeSource.emitStepCount(0);

      service.pause();
      expect(service.state.isPaused, isTrue);

      // Step while paused must be ignored
      fakeSource.emitStepCount(1);
      expect(service.state.stepCount, equals(0));

      service.resume();
      expect(service.state.isPaused, isFalse);

      // Step after resume should count
      fakeSource.emitStepCount(2);
      expect(service.state.stepCount, equals(2));

      service.pause();
      expect(service.state.isPaused, isTrue);
      service.resume();
      expect(service.state.isPaused, isFalse);

      service.stop();
      expect(service.state.isRunning, isFalse);

      service.dispose();
    });

    test('dispose is safe to call after stop and is idempotent', () {
      final fakeSource = FakeSensorDataSource();
      final service = SensorService(dataSource: fakeSource);

      service.start();
      service.stop();

      expect(() => service.dispose(), returnsNormally);
      // Repeated dispose must not throw "Cannot close a closed StreamController"
      expect(() => service.dispose(), returnsNormally);
    });

    test('safe cancellation handles platform exception gracefully when native stream was already unhooked', () async {
      final throwingSource = _ThrowingCancelSensorDataSource(
        PlatformException(code: 'error', message: 'No active stream to cancel'),
      );
      final service = SensorService(dataSource: throwingSource);

      service.start();
      expect(service.state.isRunning, isTrue);

      // Stop must NOT crash or emit unhandled asynchronous error
      expect(() => service.stop(), returnsNormally);
      expect(service.state.isRunning, isFalse);

      service.dispose();
    });

    test('safe cancellation preserves and handles unexpected real platform errors', () async {
      final throwingSource = _ThrowingCancelSensorDataSource(
        PlatformException(code: 'hardware_failure', message: 'Sensor bus disconnected'),
      );
      final service = SensorService(dataSource: throwingSource);

      service.start();
      expect(service.state.isRunning, isTrue);

      service.stop();
      // Allow async safe cancellation to report error
      await Future<void>.delayed(Duration.zero);

      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.errorMessage, contains('Sensor bus disconnected'));

      service.dispose();
    });
  });

  group('9. Android Activity Recognition Runtime Permission & Step Baseline Verification', () {
    test('permission granted allows normal running status and step stream subscription', () async {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.granted,
      );
      final service = SensorService(dataSource: source);

      service.start();
      expect(service.state.isRunning, isTrue);
      expect(service.state.status, equals(SensorEngineStatus.running));
      expect(service.state.permissionStatus, equals(SensorPermissionStatus.granted));
      expect(service.state.errorMessage, isNull);

      // Baseline + 5 steps
      source.emitStepCount(100);
      source.emitStepCount(105);
      expect(service.state.stepCount, equals(5));
      expect(service.state.distance, closeTo(5 * SensorConfig.defaultStepLength, 1e-9));

      service.dispose();
    });

    test('permission denied degrades engine and does not subscribe blindly to step stream', () async {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.denied,
      );
      final service = SensorService(dataSource: source);

      service.start();
      expect(service.state.isRunning, isTrue);
      // Must NOT falsely report running when step permission is denied
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.permissionStatus, equals(SensorPermissionStatus.denied));
      expect(
        service.state.errorMessage,
        contains('Physical activity recognition permission is required'),
      );

      // Hardware steps emitted while denied must NOT increment step count
      source.emitStepCount(100);
      source.emitStepCount(105);
      expect(service.state.stepCount, equals(0));
      expect(service.state.distance, equals(0.0));

      // Compass and heading still work
      source.emitMagnetometer(0.0, 25.0, -40.0);
      expect(service.state.heading, isNotNull);

      service.dispose();
    });

    test('permission unavailable degrades gracefully without crashing', () async {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.unavailable,
      );
      final service = SensorService(dataSource: source);

      expect(() => service.start(), returnsNormally);
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.permissionStatus, equals(SensorPermissionStatus.unavailable));

      service.dispose();
    });

    test('step stream only starts after permission is granted through requestPermissions', () async {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.denied,
        mockRequestPermissionResult: SensorPermissionStatus.granted,
      );
      final service = SensorService(dataSource: source);

      service.start();
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      source.emitStepCount(100);
      expect(service.state.stepCount, equals(0)); // Not subscribed yet

      // Grant permission
      final reqResult = await service.requestPermissions();
      expect(reqResult, equals(SensorPermissionStatus.granted));
      expect(service.state.status, equals(SensorEngineStatus.running));
      expect(service.state.permissionStatus, equals(SensorPermissionStatus.granted));

      // Steps now count
      source.emitStepCount(100);
      source.emitStepCount(103);
      expect(service.state.stepCount, equals(3));

      service.dispose();
    });

    test('repeated start does not duplicate subscription when permission is granted', () {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.granted,
      );
      final service = SensorService(dataSource: source);

      service.start();
      service.start();
      service.start();

      source.emitStepCount(1000);
      source.emitStepCount(1001);

      // Only 1 step increment even after 3 start() calls
      expect(service.state.stepCount, equals(1));

      service.dispose();
    });

    test('baseline calculation converts cumulative hardware steps to relative walkthrough steps', () {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.granted,
      );
      final service = SensorService(dataSource: source);
      service.start();

      // Android lifetime sensor has recorded 1240 steps previously
      source.emitStepCount(1240);
      expect(service.state.stepCount, equals(0)); // Walkthrough starts at 0

      // User walks 10 steps -> sensor reaches 1250
      source.emitStepCount(1250);
      expect(service.state.stepCount, equals(10)); // Relative steps = 10, NOT 1250!
      expect(service.state.distance, closeTo(10 * SensorConfig.defaultStepLength, 1e-9));

      // 5 more steps -> sensor reaches 1255
      source.emitStepCount(1255);
      expect(service.state.stepCount, equals(15));
      expect(service.state.distance, closeTo(15 * SensorConfig.defaultStepLength, 1e-9));

      service.dispose();
    });

    test('manual fallback remains functional when sensor permission is denied', () {
      final source = FakeSensorDataSource(
        mockPermissionStatus: SensorPermissionStatus.denied,
      );
      final service = SensorService(dataSource: source);
      service.start();

      // Sensor is degraded
      expect(service.state.status, equals(SensorEngineStatus.degraded));
      expect(service.state.stepCount, equals(0));

      // Step length adjustment and reset work without crashing
      service.setStepLength(0.8);
      expect(service.state.stepLength, equals(0.8));

      service.reset();
      expect(service.state.x, equals(0.0));
      expect(service.state.y, equals(0.0));

      service.dispose();
    });
  });
}

class _ThrowingCancelSensorDataSource extends FakeSensorDataSource {
  final Object errorOnCancel;

  _ThrowingCancelSensorDataSource(this.errorOnCancel);

  @override
  Stream<int> get stepCount => _ThrowingCancelStream<int>(errorOnCancel);
}

class _ThrowingCancelStream<T> extends Stream<T> {
  final Object errorOnCancel;
  _ThrowingCancelStream(this.errorOnCancel);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _ThrowingCancelSubscription<T>(errorOnCancel);
  }
}

class _ThrowingCancelSubscription<T> implements StreamSubscription<T> {
  final Object errorOnCancel;
  _ThrowingCancelSubscription(this.errorOnCancel);

  @override
  Future<void> cancel() {
    return Future<void>.error(errorOnCancel);
  }

  @override
  void onData(void Function(T data)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;
}
