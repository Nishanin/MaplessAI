import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/node_model.dart';
import '../services/sensor_models.dart';
import '../services/sensor_provider.dart';
import '../services/sensor_service.dart';
import 'walkthrough_state.dart';

/// Minimum distance in meters before a new point is appended to the walked path trace.
/// This prevents excessive point density, coordinate jitter, and canvas rendering lag.
const double kMinPathDisplacementMeters = 0.5;

/// Controller managing creator mapping walkthrough sessions and live PDR ingestion
/// Owner: Nishant (Phase 6 — Sensor-Assisted Map Creation)
class WalkthroughController extends StateNotifier<WalkthroughState> {
  final ISensorService _sensorService;
  StreamSubscription<SensorState>? _sensorSub;

  WalkthroughController({
    required ISensorService sensorService,
  })  : _sensorService = sensorService,
        super(WalkthroughState(
          isSensorAvailable: sensorService.state.isAvailable,
          permissionStatus: sensorService.state.permissionStatus,
          errorMessage: sensorService.state.errorMessage,
        )) {
    _sensorSub = _sensorService.stateStream.listen(_handleSensorState);
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _sensorSub = null;
    super.dispose();
  }

  /// Handles real-time telemetry from Phase 4 SensorEngine
  void _handleSensorState(SensorState s) {
    if (!mounted) return;

    final newPos = Offset(s.x, s.y);
    List<Offset> updatedPath = state.recordedPath;

    if (state.isRecording) {
      if (updatedPath.isEmpty) {
        updatedPath = [newPos];
      } else {
        final lastPoint = updatedPath.last;
        final displacement = (newPos - lastPoint).distance;
        if (displacement >= kMinPathDisplacementMeters) {
          updatedPath = List<Offset>.from(updatedPath)..add(newPos);
        }
      }
    }

    state = state.copyWith(
      currentPosition: newPos,
      currentHeading: s.heading,
      stepCount: s.stepCount,
      distance: s.distance,
      recordedPath: updatedPath,
      isSensorAvailable: s.isAvailable,
      permissionStatus: s.permissionStatus,
      errorMessage: s.errorMessage,
      clearError: s.errorMessage == null,
    );
  }

  /// Starts a new walkthrough session, establishing (0, 0) as mapping origin
  void startWalkthrough() {
    _sensorService.reset();
    _sensorService.calibrate();
    _sensorService.start();

    state = state.copyWith(
      status: WalkthroughStatus.recording,
      currentPosition: Offset.zero,
      currentHeading: 0.0,
      stepCount: 0,
      distance: 0.0,
      recordedPath: const [Offset.zero],
      clearLastPlacedNode: true,
      clearCandidateConnection: true,
      clearError: true,
    );
  }

  /// Pauses motion integration without discarding current coordinates or path
  void pauseWalkthrough() {
    if (!state.isRecording) return;
    _sensorService.pause();
    state = state.copyWith(status: WalkthroughStatus.paused);
  }

  /// Resumes motion integration from the current coordinates
  void resumeWalkthrough() {
    if (!state.isPaused) return;
    _sensorService.resume();
    state = state.copyWith(status: WalkthroughStatus.recording);
  }

  /// Stops walkthrough recording and preserves final path trace for authoring
  void stopWalkthrough() {
    _sensorService.stop();
    state = state.copyWith(status: WalkthroughStatus.stopped);
  }

  /// Safely resets mapping coordinates to (0, 0) and rebases path trace
  void resetOrigin() {
    _sensorService.reset();
    state = state.copyWith(
      currentPosition: Offset.zero,
      stepCount: 0,
      distance: 0.0,
      recordedPath: const [Offset.zero],
      clearCandidateConnection: true,
    );
  }

  /// Registers a node created at the creator's current position and derives
  /// candidate connection if a prior node exists in this session.
  void onNodePlaced(NodeModel node) {
    CandidateConnection? connection;
    final previous = state.lastPlacedNode;

    if (previous != null && previous.id != node.id) {
      final dx = node.x - previous.x;
      final dy = node.y - previous.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      // Compass bearing in degrees clockwise from North (+Y)
      var rad = math.atan2(dx, dy);
      var deg = rad * (180.0 / math.pi);
      if (deg < 0) deg += 360.0;

      connection = CandidateConnection(
        fromNode: previous,
        toNode: node,
        distance: dist,
        bearing: deg,
      );
    }

    state = state.copyWith(
      lastPlacedNode: node,
      candidateConnection: connection,
      clearCandidateConnection: connection == null,
    );
  }

  /// Dismisses candidate connection prompt
  void dismissCandidateConnection() {
    state = state.copyWith(clearCandidateConnection: true);
  }
}

/// Global StateNotifierProvider for walkthrough session management
final walkthroughProvider = StateNotifierProvider<WalkthroughController, WalkthroughState>((ref) {
  final sensorService = ref.watch(sensorServiceProvider);
  return WalkthroughController(sensorService: sensorService);
});
