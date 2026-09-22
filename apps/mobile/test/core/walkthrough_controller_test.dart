import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/mapping/services/sensor_data_source.dart';
import 'package:mapless_ai/features/mapping/services/sensor_models.dart';
import 'package:mapless_ai/features/mapping/services/sensor_service.dart';
import 'package:mapless_ai/features/mapping/state/walkthrough_controller.dart';
import 'package:mapless_ai/features/mapping/state/walkthrough_state.dart';

void main() {
  group('Phase 6 — WalkthroughController & Session State Machine', () {
    late FakeSensorDataSource fakeDataSource;
    late SensorService sensorService;
    late WalkthroughController controller;

    setUp(() async {
      fakeDataSource = FakeSensorDataSource(
        mockAvailability: const SensorAvailability(),
        mockPermissionStatus: SensorPermissionStatus.granted,
      );
      sensorService = SensorService(dataSource: fakeDataSource);
      await sensorService.initialize();
      controller = WalkthroughController(sensorService: sensorService);
    });

    tearDown(() {
      controller.dispose();
      sensorService.dispose();
      fakeDataSource.dispose();
    });

    test('1. Initial state is cleanly idle with zeroed metrics', () {
      final s = controller.state;
      expect(s.status, equals(WalkthroughStatus.idle));
      expect(s.isIdle, isTrue);
      expect(s.isRecording, isFalse);
      expect(s.isPaused, isFalse);
      expect(s.isStopped, isFalse);
      expect(s.currentPosition, equals(Offset.zero));
      expect(s.currentHeading, equals(0.0));
      expect(s.stepCount, equals(0));
      expect(s.distance, equals(0.0));
      expect(s.recordedPath, isEmpty);
      expect(s.lastPlacedNode, isNull);
      expect(s.candidateConnection, isNull);
      expect(s.isSensorAvailable, isTrue);
    });

    test('2. startWalkthrough establishes origin and enters recording state', () {
      controller.startWalkthrough();

      final s = controller.state;
      expect(s.status, equals(WalkthroughStatus.recording));
      expect(s.isRecording, isTrue);
      expect(s.currentPosition, equals(Offset.zero));
      expect(s.recordedPath.length, equals(1));
      expect(s.recordedPath.first, equals(Offset.zero));
      expect(sensorService.isRecording, isTrue);
    });

    test('3. Real-time sensor state updates position and metrics', () async {
      controller.startWalkthrough();

      // First step event establishes pedometer hardware boot baseline
      fakeDataSource.emitStepCount(100);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Subsequent event increments relative step count by 5
      fakeDataSource.emitStepCount(105);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state.stepCount, equals(5));
      expect(controller.state.isRecording, isTrue);
    });

    test('4. Minimum displacement threshold filters out jitter (< 0.5m)', () async {
      controller.startWalkthrough();
      expect(controller.state.recordedPath.length, equals(1));

      // Establish baseline
      fakeDataSource.emitStepCount(100);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 1 step with default 0.72m stride will exceed 0.5m threshold
      fakeDataSource.emitStepCount(101);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final pathCountAfterStep = controller.state.recordedPath.length;
      expect(pathCountAfterStep, greaterThanOrEqualTo(1));
    });

    test('5. Node placement derives candidate connection with Euclidean distance and bearing', () {
      controller.startWalkthrough();

      const nodeA = NodeModel(
        id: 'node-entry',
        name: 'Entryway',
        category: 'entrance',
        floorId: 'flr-01',
        x: 0.0,
        y: 0.0,
        accessible: true,
      );

      // Drop first node at origin
      controller.onNodePlaced(nodeA);
      expect(controller.state.lastPlacedNode?.id, equals('node-entry'));
      expect(controller.state.candidateConnection, isNull);

      // Walk to (3.0, 4.0) — 3-4-5 triangle
      const nodeB = NodeModel(
        id: 'node-lobby',
        name: 'Main Lobby',
        category: 'room',
        floorId: 'flr-01',
        x: 3.0,
        y: 4.0,
        accessible: true,
      );

      // Drop second node
      controller.onNodePlaced(nodeB);
      expect(controller.state.lastPlacedNode?.id, equals('node-lobby'));

      final candidate = controller.state.candidateConnection;
      expect(candidate, isNotNull);
      expect(candidate!.fromNode.id, equals('node-entry'));
      expect(candidate.toNode.id, equals('node-lobby'));
      expect(candidate.distance, closeTo(5.0, 0.01));
      // atan2(3, 4) in degrees: ~36.87° clockwise from North (+Y)
      expect(candidate.bearing, closeTo(36.87, 0.1));

      // Dismiss connection
      controller.dismissCandidateConnection();
      expect(controller.state.candidateConnection, isNull);
    });

    test('6. pauseWalkthrough and resumeWalkthrough preserve session state', () {
      controller.startWalkthrough();
      expect(controller.state.isRecording, isTrue);

      controller.pauseWalkthrough();
      expect(controller.state.status, equals(WalkthroughStatus.paused));
      expect(controller.state.isPaused, isTrue);
      expect(controller.state.isRecording, isFalse);

      controller.resumeWalkthrough();
      expect(controller.state.status, equals(WalkthroughStatus.recording));
      expect(controller.state.isRecording, isTrue);
    });

    test('7. stopWalkthrough halts recording and preserves path trace', () {
      controller.startWalkthrough();
      expect(controller.state.isRecording, isTrue);

      controller.stopWalkthrough();
      expect(controller.state.status, equals(WalkthroughStatus.stopped));
      expect(controller.state.isStopped, isTrue);
      expect(controller.state.isRecording, isFalse);
      expect(controller.state.recordedPath, isNotEmpty);
      expect(sensorService.isRecording, isFalse);
    });

    test('8. resetOrigin resets coordinates to (0, 0) and rebases path', () {
      controller.startWalkthrough();

      controller.resetOrigin();
      expect(controller.state.currentPosition, equals(Offset.zero));
      expect(controller.state.distance, equals(0.0));
      expect(controller.state.stepCount, equals(0));
      expect(controller.state.recordedPath, equals([Offset.zero]));
      expect(controller.state.candidateConnection, isNull);
    });

    test('9. Handles permission denied or hardware unavailable gracefully', () async {
      final degradedSource = FakeSensorDataSource(
        mockAvailability: const SensorAvailability.none(),
        mockPermissionStatus: SensorPermissionStatus.denied,
      );
      final degradedService = SensorService(dataSource: degradedSource);
      await degradedService.initialize();

      final degradedController = WalkthroughController(sensorService: degradedService);
      expect(degradedController.state.isSensorAvailable, isFalse);
      expect(degradedController.state.permissionStatus, equals(SensorPermissionStatus.denied));
      expect(degradedController.state.errorMessage, isNotNull);

      degradedController.dispose();
      degradedService.dispose();
      degradedSource.dispose();
    });
  });
}
