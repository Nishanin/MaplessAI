import '../../../core/models/building_model.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/floor_model.dart';
import '../../../core/models/node_model.dart';
import '../../../core/models/semantic_metadata_model.dart';

/// Explicit lifecycle states for indoor map authoring
/// Owner: Nishant (Phase 3 — Creator Workflow)
enum MapLifecycleState {
  draft,
  validated,
  published,
  failed,
}

/// Domain model representing an in-progress or completed indoor map draft
class MapDraft {
  final String id;
  final BuildingModel building;
  final FloorModel floor;
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final List<SemanticMetadataModel> metadata;
  final MapLifecycleState lifecycleState;
  final DateTime lastUpdated;
  final bool isMockStored;
  final String? failureReason;

  const MapDraft({
    required this.id,
    required this.building,
    required this.floor,
    this.nodes = const [],
    this.edges = const [],
    this.metadata = const [],
    this.lifecycleState = MapLifecycleState.draft,
    required this.lastUpdated,
    this.isMockStored = true,
    this.failureReason,
  });

  bool get isDraft => lifecycleState == MapLifecycleState.draft;
  bool get isValidated => lifecycleState == MapLifecycleState.validated;
  bool get isPublished => lifecycleState == MapLifecycleState.published;
  bool get isFailed => lifecycleState == MapLifecycleState.failed;

  MapDraft copyWith({
    String? id,
    BuildingModel? building,
    FloorModel? floor,
    List<NodeModel>? nodes,
    List<EdgeModel>? edges,
    List<SemanticMetadataModel>? metadata,
    MapLifecycleState? lifecycleState,
    DateTime? lastUpdated,
    bool? isMockStored,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return MapDraft(
      id: id ?? this.id,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      metadata: metadata ?? this.metadata,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isMockStored: isMockStored ?? this.isMockStored,
      failureReason: clearFailureReason ? null : (failureReason ?? this.failureReason),
    );
  }
}
