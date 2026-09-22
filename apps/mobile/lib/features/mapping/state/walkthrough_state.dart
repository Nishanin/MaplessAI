import 'dart:ui';
import '../../../core/models/node_model.dart';
import '../services/sensor_models.dart';

/// Status of the creator mapping walkthrough session
enum WalkthroughStatus {
  idle,
  recording,
  paused,
  stopped,
}

/// Suggested topological connection between consecutively placed nodes
class CandidateConnection {
  final NodeModel fromNode;
  final NodeModel toNode;
  final double distance;
  final double bearing;

  const CandidateConnection({
    required this.fromNode,
    required this.toNode,
    required this.distance,
    required this.bearing,
  });
}

/// State representation for a sensor-assisted creator walkthrough session
/// Owner: Nishant (Phase 6 — Sensor-Assisted Map Creation)
class WalkthroughState {
  final WalkthroughStatus status;
  final Offset currentPosition;
  final double currentHeading;
  final int stepCount;
  final double distance;
  final List<Offset> recordedPath;
  final NodeModel? lastPlacedNode;
  final CandidateConnection? candidateConnection;
  final bool isSensorAvailable;
  final SensorPermissionStatus permissionStatus;
  final String? errorMessage;

  const WalkthroughState({
    this.status = WalkthroughStatus.idle,
    this.currentPosition = Offset.zero,
    this.currentHeading = 0.0,
    this.stepCount = 0,
    this.distance = 0.0,
    this.recordedPath = const [],
    this.lastPlacedNode,
    this.candidateConnection,
    this.isSensorAvailable = true,
    this.permissionStatus = SensorPermissionStatus.granted,
    this.errorMessage,
  });

  bool get isRecording => status == WalkthroughStatus.recording;
  bool get isPaused => status == WalkthroughStatus.paused;
  bool get isStopped => status == WalkthroughStatus.stopped;
  bool get isIdle => status == WalkthroughStatus.idle;
  bool get hasPath => recordedPath.isNotEmpty;

  WalkthroughState copyWith({
    WalkthroughStatus? status,
    Offset? currentPosition,
    double? currentHeading,
    int? stepCount,
    double? distance,
    List<Offset>? recordedPath,
    NodeModel? lastPlacedNode,
    bool clearLastPlacedNode = false,
    CandidateConnection? candidateConnection,
    bool clearCandidateConnection = false,
    bool? isSensorAvailable,
    SensorPermissionStatus? permissionStatus,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalkthroughState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      currentHeading: currentHeading ?? this.currentHeading,
      stepCount: stepCount ?? this.stepCount,
      distance: distance ?? this.distance,
      recordedPath: recordedPath ?? this.recordedPath,
      lastPlacedNode: clearLastPlacedNode ? null : (lastPlacedNode ?? this.lastPlacedNode),
      candidateConnection: clearCandidateConnection
          ? null
          : (candidateConnection ?? this.candidateConnection),
      isSensorAvailable: isSensorAvailable ?? this.isSensorAvailable,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
