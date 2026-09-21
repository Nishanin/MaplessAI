import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/building_model.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/floor_model.dart';
import '../../../core/models/node_model.dart';
import '../../../core/models/semantic_metadata_model.dart';
import '../../../core/state/spatial_state.dart';
import '../domain/creator_mapping_repository.dart';
import '../domain/map_draft_model.dart';
import '../domain/map_validation_service.dart';
import '../services/mock_creator_mapping_repository.dart';

/// Status of asynchronous creator operations
enum CreatorOperationStatus {
  idle,
  loading,
  success,
  error,
}

/// Creator Mapping UI State
/// Owner: Nishant (Phase 3 — Creator State Management)
class CreatorState {
  final CreatorOperationStatus operationStatus;
  final MapDraft? activeDraft;
  final List<MapDraft> savedDrafts;
  final List<MapDraft> publishedMaps;
  final NodeModel? selectedNode;
  final EdgeModel? selectedEdge;
  final NodeModel? connectSourceNode;
  final ValidationResult? validationResult;
  final String? errorMessage;
  final String? successMessage;

  const CreatorState({
    this.operationStatus = CreatorOperationStatus.idle,
    this.activeDraft,
    this.savedDrafts = const [],
    this.publishedMaps = const [],
    this.selectedNode,
    this.selectedEdge,
    this.connectSourceNode,
    this.validationResult,
    this.errorMessage,
    this.successMessage,
  });

  bool get isLoading => operationStatus == CreatorOperationStatus.loading;
  bool get hasActiveDraft => activeDraft != null;
  bool get isReadyToPublish =>
      activeDraft != null &&
      activeDraft!.nodes.isNotEmpty &&
      validationResult != null &&
      validationResult!.isValid;

  CreatorState copyWith({
    CreatorOperationStatus? operationStatus,
    MapDraft? activeDraft,
    bool clearActiveDraft = false,
    List<MapDraft>? savedDrafts,
    List<MapDraft>? publishedMaps,
    NodeModel? selectedNode,
    bool clearSelectedNode = false,
    EdgeModel? selectedEdge,
    bool clearSelectedEdge = false,
    NodeModel? connectSourceNode,
    bool clearConnectSourceNode = false,
    ValidationResult? validationResult,
    bool clearValidationResult = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return CreatorState(
      operationStatus: operationStatus ?? this.operationStatus,
      activeDraft: clearActiveDraft ? null : (activeDraft ?? this.activeDraft),
      savedDrafts: savedDrafts ?? this.savedDrafts,
      publishedMaps: publishedMaps ?? this.publishedMaps,
      selectedNode: clearSelectedNode ? null : (selectedNode ?? this.selectedNode),
      selectedEdge: clearSelectedEdge ? null : (selectedEdge ?? this.selectedEdge),
      connectSourceNode:
          clearConnectSourceNode ? null : (connectSourceNode ?? this.connectSourceNode),
      validationResult:
          clearValidationResult ? null : (validationResult ?? this.validationResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Controller managing Creator Mapping workflow and state machine
class CreatorController extends StateNotifier<CreatorState> {
  final ICreatorMappingRepository _repository;
  final Ref? _ref;

  CreatorController({
    ICreatorMappingRepository? repository,
    Ref? ref,
  })  : _repository = repository ?? MockCreatorMappingRepository(),
        _ref = ref,
        super(const CreatorState()) {
    loadProjects();
  }

  /// Exposes current state for synchronous reading and unit testing
  CreatorState get currentState => state;

  /// Loads drafts and published maps from repository
  Future<void> loadProjects() async {
    state = state.copyWith(operationStatus: CreatorOperationStatus.loading);
    try {
      final drafts = await _repository.getDrafts();
      final published = await _repository.getPublishedMaps();
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.idle,
        savedDrafts: drafts,
        publishedMaps: published,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Failed to load creator projects: $e',
      );
    }
  }

  /// Starts a new mapping session for a building and floor
  void startNewSession({
    required BuildingModel building,
    required FloorModel floor,
  }) {
    final draftId = 'draft-${DateTime.now().millisecondsSinceEpoch}';
    final draft = MapDraft(
      id: draftId,
      building: building,
      floor: floor,
      nodes: const [],
      edges: const [],
      metadata: const [],
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
      isMockStored: true,
    );

    state = state.copyWith(
      activeDraft: draft,
      clearSelectedNode: true,
      clearSelectedEdge: true,
      clearConnectSourceNode: true,
      clearValidationResult: true,
      clearError: true,
    );
  }

  /// Resumes an existing draft
  void resumeDraft(MapDraft draft) {
    state = state.copyWith(
      activeDraft: draft,
      clearSelectedNode: true,
      clearSelectedEdge: true,
      clearConnectSourceNode: true,
      clearValidationResult: true,
      clearError: true,
    );
  }

  /// Creates a new building and registers it with the global spatial catalog
  BuildingModel? createBuilding({
    required String name,
    required String id,
    required String address,
    required String category,
    required double latitude,
    required double longitude,
    String? description,
  }) {
    if (name.trim().isEmpty || id.trim().isEmpty) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Building name and identifier are required.',
      );
      return null;
    }

    final newBuilding = BuildingModel(
      id: id.trim(),
      name: name.trim(),
      address: address.trim().isEmpty ? 'Campus Ground' : address.trim(),
      category: category.trim().isEmpty ? 'academic' : category.trim(),
      latitude: latitude,
      longitude: longitude,
      metadata: {
        if (description != null && description.isNotEmpty) 'description': description.trim(),
        'createdBy': 'Creator',
      },
    );

    // Sync with spatialStateProvider if Ref is provided
    if (_ref != null) {
      final spatialNotifier = _ref.read(spatialStateProvider.notifier);
      spatialNotifier.selectBuilding(newBuilding);
    }

    state = state.copyWith(
      operationStatus: CreatorOperationStatus.success,
      successMessage: 'Building "${newBuilding.name}" created successfully.',
      clearError: true,
    );
    return newBuilding;
  }

  /// Creates a new floor for the active building
  FloorModel? createFloor({
    required String buildingId,
    required String name,
    required int floorNumber,
    double elevation = 0.0,
    Map<String, dynamic> metadata = const {},
  }) {
    if (name.trim().isEmpty) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Floor name is required.',
      );
      return null;
    }

    final floorId = 'flr-$buildingId-$floorNumber';
    final newFloor = FloorModel(
      id: floorId,
      buildingId: buildingId,
      floorNumber: floorNumber,
      name: name.trim(),
      elevation: elevation,
      metadata: metadata,
    );

    // Sync with spatialStateProvider if Ref is provided
    if (_ref != null) {
      final spatialNotifier = _ref.read(spatialStateProvider.notifier);
      spatialNotifier.selectFloor(newFloor);
    }

    state = state.copyWith(
      operationStatus: CreatorOperationStatus.success,
      successMessage: 'Floor "${newFloor.name}" created successfully.',
      clearError: true,
    );
    return newFloor;
  }

  /// Adds a manually placed node to the active draft
  void addNode(NodeModel node) {
    if (state.activeDraft == null) return;

    final updatedNodes = List<NodeModel>.from(state.activeDraft!.nodes)..add(node);
    final updatedDraft = state.activeDraft!.copyWith(
      nodes: updatedNodes,
      lifecycleState: MapLifecycleState.draft, // Reset to draft when modified
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      selectedNode: node,
      clearValidationResult: true,
      clearError: true,
    );
  }

  /// Edits an existing node
  void updateNode(NodeModel updatedNode) {
    if (state.activeDraft == null) return;

    final updatedNodes = state.activeDraft!.nodes.map((n) {
      return n.id == updatedNode.id ? updatedNode : n;
    }).toList();

    final updatedDraft = state.activeDraft!.copyWith(
      nodes: updatedNodes,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      selectedNode: updatedNode,
      clearValidationResult: true,
    );
  }

  /// Deletes a node and safely removes all connected edges
  void deleteNode(String nodeId) {
    if (state.activeDraft == null) return;

    final updatedNodes = state.activeDraft!.nodes.where((n) => n.id != nodeId).toList();
    // Safely remove all edges referencing this node
    final updatedEdges = state.activeDraft!.edges
        .where((e) => e.startNodeId != nodeId && e.endNodeId != nodeId)
        .toList();
    // Remove any attached metadata
    final updatedMeta = state.activeDraft!.metadata
        .where((m) => m.entityId != nodeId)
        .toList();

    final updatedDraft = state.activeDraft!.copyWith(
      nodes: updatedNodes,
      edges: updatedEdges,
      metadata: updatedMeta,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      clearSelectedNode: state.selectedNode?.id == nodeId,
      clearConnectSourceNode: state.connectSourceNode?.id == nodeId,
      clearValidationResult: true,
    );
  }

  /// Adds an edge connecting two nodes
  bool connectNodes(EdgeModel edge) {
    if (state.activeDraft == null) return false;

    // Self-loop prevention
    if (edge.startNodeId == edge.endNodeId) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Cannot connect a node to itself.',
      );
      return false;
    }

    // Duplicate check
    final exists = state.activeDraft!.edges.any(
      (e) => e.startNodeId == edge.startNodeId && e.endNodeId == edge.endNodeId,
    );
    if (exists) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'An edge already connects these two nodes in this direction.',
      );
      return false;
    }

    final updatedEdges = List<EdgeModel>.from(state.activeDraft!.edges)..add(edge);
    final updatedDraft = state.activeDraft!.copyWith(
      edges: updatedEdges,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      selectedEdge: edge,
      clearConnectSourceNode: true,
      clearValidationResult: true,
      clearError: true,
    );
    return true;
  }

  /// Updates an edge
  void updateEdge(EdgeModel updatedEdge) {
    if (state.activeDraft == null) return;

    final updatedEdges = state.activeDraft!.edges.map((e) {
      return e.id == updatedEdge.id ? updatedEdge : e;
    }).toList();

    final updatedDraft = state.activeDraft!.copyWith(
      edges: updatedEdges,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      selectedEdge: updatedEdge,
      clearValidationResult: true,
    );
  }

  /// Toggles blocked state of an edge
  void toggleEdgeBlocked(String edgeId) {
    if (state.activeDraft == null) return;

    final updatedEdges = state.activeDraft!.edges.map((e) {
      if (e.id == edgeId) {
        return e.copyWith(blocked: !e.blocked);
      }
      return e;
    }).toList();

    final updatedDraft = state.activeDraft!.copyWith(
      edges: updatedEdges,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    final updatedSelectedEdge = state.selectedEdge?.id == edgeId
        ? state.selectedEdge!.copyWith(blocked: !state.selectedEdge!.blocked)
        : state.selectedEdge;

    state = state.copyWith(
      activeDraft: updatedDraft,
      selectedEdge: updatedSelectedEdge,
      clearValidationResult: true,
    );
  }

  /// Deletes an edge
  void deleteEdge(String edgeId) {
    if (state.activeDraft == null) return;

    final updatedEdges = state.activeDraft!.edges.where((e) => e.id != edgeId).toList();
    final updatedDraft = state.activeDraft!.copyWith(
      edges: updatedEdges,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      clearSelectedEdge: state.selectedEdge?.id == edgeId,
      clearValidationResult: true,
    );
  }

  /// Sets candidate source node for connection
  void setConnectSourceNode(NodeModel? node) {
    state = state.copyWith(
      connectSourceNode: node,
      clearConnectSourceNode: node == null,
    );
  }

  /// Adds or updates semantic metadata
  void addOrUpdateMetadata(SemanticMetadataModel metadata) {
    if (state.activeDraft == null) return;

    final existingIndex = state.activeDraft!.metadata
        .indexWhere((m) => m.entityId == metadata.entityId);

    final updatedList = List<SemanticMetadataModel>.from(state.activeDraft!.metadata);
    if (existingIndex >= 0) {
      updatedList[existingIndex] = metadata;
    } else {
      updatedList.add(metadata);
    }

    final updatedDraft = state.activeDraft!.copyWith(
      metadata: updatedList,
      lastUpdated: DateTime.now(),
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      clearValidationResult: true,
    );
  }

  /// Select node in editor
  void selectNode(NodeModel? node) {
    state = state.copyWith(
      selectedNode: node,
      clearSelectedNode: node == null,
      clearSelectedEdge: true,
    );
  }

  /// Select edge in editor
  void selectEdge(EdgeModel? edge) {
    state = state.copyWith(
      selectedEdge: edge,
      clearSelectedEdge: edge == null,
      clearSelectedNode: true,
    );
  }

  /// Validates the active draft map
  ValidationResult validateCurrentDraft() {
    if (state.activeDraft == null) {
      const res = ValidationResult(
        isValid: false,
        issues: [ValidationIssue(message: 'No active draft to validate.', isError: true)],
      );
      state = state.copyWith(validationResult: res);
      return res;
    }

    final result = MapValidationService.validateDraft(state.activeDraft!);
    final updatedDraft = state.activeDraft!.copyWith(
      lifecycleState: result.isValid ? MapLifecycleState.validated : MapLifecycleState.draft,
    );

    state = state.copyWith(
      activeDraft: updatedDraft,
      validationResult: result,
      clearError: result.isValid,
      errorMessage: result.isValid ? null : 'Map graph contains validation errors.',
    );
    return result;
  }

  /// Saves current draft to repository
  Future<bool> saveCurrentDraft() async {
    if (state.activeDraft == null) return false;

    state = state.copyWith(operationStatus: CreatorOperationStatus.loading);
    try {
      final saved = await _repository.saveDraft(state.activeDraft!);
      final updatedDrafts = await _repository.getDrafts();
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.success,
        activeDraft: saved,
        savedDrafts: updatedDrafts,
        successMessage: 'Draft "${saved.building.name} - ${saved.floor.name}" saved locally.',
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Failed to save draft: $e',
      );
      return false;
    }
  }

  /// Deletes a draft
  Future<void> deleteDraftById(String draftId) async {
    state = state.copyWith(operationStatus: CreatorOperationStatus.loading);
    try {
      await _repository.deleteDraft(draftId);
      final updatedDrafts = await _repository.getDrafts();
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.success,
        savedDrafts: updatedDrafts,
        clearActiveDraft: state.activeDraft?.id == draftId,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: 'Failed to delete draft: $e',
      );
    }
  }

  /// Submits the active draft for publishing
  Future<PublishResult> publishCurrentDraft({bool simulateFailure = false}) async {
    if (state.activeDraft == null) {
      const err = 'Cannot publish: No active map draft selected.';
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: err,
      );
      return PublishResult.failure(
        draft: MapDraft(
          id: 'invalid',
          building: const BuildingModel(id: '', name: '', address: '', category: '', latitude: 0, longitude: 0),
          floor: const FloorModel(id: '', buildingId: '', floorNumber: 0, name: ''),
          lastUpdated: DateTime.now(),
        ),
        isMock: true,
        error: err,
      );
    }

    // Step 1: Must validate before publishing
    final validation = validateCurrentDraft();
    if (!validation.isValid) {
      const err = 'Cannot publish an invalid map. Please resolve all validation errors first.';
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        errorMessage: err,
      );
      return PublishResult.failure(
        draft: state.activeDraft!,
        isMock: true,
        error: err,
      );
    }

    // Step 2: Publish request
    state = state.copyWith(operationStatus: CreatorOperationStatus.loading, clearError: true);

    final result = await _repository.publishMap(
      state.activeDraft!,
      simulateFailure: simulateFailure,
    );

    if (result.isSuccess) {
      final updatedDrafts = await _repository.getDrafts();
      final updatedPublished = await _repository.getPublishedMaps();

      state = state.copyWith(
        operationStatus: CreatorOperationStatus.success,
        activeDraft: result.draft,
        savedDrafts: updatedDrafts,
        publishedMaps: updatedPublished,
        successMessage: result.message,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        operationStatus: CreatorOperationStatus.error,
        activeDraft: result.draft,
        errorMessage: result.error,
      );
    }

    return result;
  }

  /// Clears transient messages
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

/// Global provider for Creator Mapping Controller
final creatorProvider = StateNotifierProvider<CreatorController, CreatorState>((ref) {
  return CreatorController(ref: ref);
});
