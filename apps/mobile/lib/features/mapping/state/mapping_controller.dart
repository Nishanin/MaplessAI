import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/building_model.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/floor_model.dart';
import '../../../core/models/node_model.dart';
import '../../../core/models/semantic_metadata_model.dart';
import '../../../core/utils/json_utils.dart';
import '../services/sensor_service.dart';

class MappingState {
  final bool isLoading;
  final BuildingModel? building;
  final FloorModel? currentFloor;
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final List<SemanticMetadataModel> metadata;
  final String? selectedNodeId;
  final String? visitorCurrentNodeId; // V1 Manual Visitor Location
  final bool isRecordingWalkthrough;
  final int recordedSteps;
  final String? errorMessage;

  const MappingState({
    this.isLoading = false,
    this.building,
    this.currentFloor,
    this.nodes = const [],
    this.edges = const [],
    this.metadata = const [],
    this.selectedNodeId,
    this.visitorCurrentNodeId,
    this.isRecordingWalkthrough = false,
    this.recordedSteps = 0,
    this.errorMessage,
  });

  MappingState copyWith({
    bool? isLoading,
    BuildingModel? building,
    FloorModel? currentFloor,
    List<NodeModel>? nodes,
    List<EdgeModel>? edges,
    List<SemanticMetadataModel>? metadata,
    String? selectedNodeId,
    String? visitorCurrentNodeId,
    bool? isRecordingWalkthrough,
    int? recordedSteps,
    String? errorMessage,
  }) {
    return MappingState(
      isLoading: isLoading ?? this.isLoading,
      building: building ?? this.building,
      currentFloor: currentFloor ?? this.currentFloor,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      metadata: metadata ?? this.metadata,
      selectedNodeId: selectedNodeId ?? this.selectedNodeId,
      visitorCurrentNodeId: visitorCurrentNodeId ?? this.visitorCurrentNodeId,
      isRecordingWalkthrough: isRecordingWalkthrough ?? this.isRecordingWalkthrough,
      recordedSteps: recordedSteps ?? this.recordedSteps,
      errorMessage: errorMessage,
    );
  }
}

class MappingController extends StateNotifier<MappingState> {
  final ISensorService _sensorService;

  MappingController({ISensorService? sensorService})
      : _sensorService = sensorService ?? SensorService(),
        super(const MappingState());

  Future<void> loadMockDataset() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dataset = await JsonUtils.loadMockDatasetFromAsset();
      state = state.copyWith(
        isLoading: false,
        building: dataset.building,
        currentFloor: dataset.floor,
        nodes: dataset.nodes,
        edges: dataset.edges,
        metadata: dataset.semanticMetadata,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void selectNode(String? nodeId) {
    state = state.copyWith(selectedNodeId: nodeId);
  }

  /// V1 Rule: Visitor manually selects their current mapped position
  void setVisitorLocation(String nodeId) {
    state = state.copyWith(visitorCurrentNodeId: nodeId);
  }

  void startWalkthrough() {
    _sensorService.startRecording();
    state = state.copyWith(isRecordingWalkthrough: true, recordedSteps: 0);
  }

  void stopWalkthrough() {
    _sensorService.stopRecording();
    state = state.copyWith(isRecordingWalkthrough: false);
  }
}

final mappingProvider = StateNotifierProvider<MappingController, MappingState>((ref) {
  return MappingController();
});
