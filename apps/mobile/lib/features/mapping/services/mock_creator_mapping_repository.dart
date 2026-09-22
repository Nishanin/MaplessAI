import '../../../core/models/building_model.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/floor_model.dart';
import '../../../core/models/node_model.dart';
import '../../../core/models/semantic_metadata_model.dart';
import '../domain/creator_mapping_repository.dart';
import '../domain/map_draft_model.dart';

/// In-memory Mock Repository for Creator Mapping
/// Owner: Nishant (Phase 3 — Creator Persistence Layer)
///
/// NOTE: This repository uses local in-memory storage for UI development & testing.
/// It explicitly reports its mock status and does NOT fabricate live production API responses.
class MockCreatorMappingRepository implements ICreatorMappingRepository {
  final Map<String, MapDraft> _drafts = {};
  final Map<String, MapDraft> _publishedMaps = {};
  final Duration operationDelay;

  MockCreatorMappingRepository({
    bool seedInitialData = true,
    this.operationDelay = Duration.zero,
  }) {
    if (seedInitialData) {
      _seedDefaultProjects();
    }
  }

  Future<void> _maybeDelay() async {
    if (operationDelay > Duration.zero) {
      await Future.delayed(operationDelay);
    }
  }

  void _seedDefaultProjects() {
    const building = BuildingModel(
      id: 'bld-vit-cc-01',
      name: 'Academic Block 1 (AB-1)',
      address: 'Vandalur-Kelambakkam Road, Chennai',
      category: 'academic',
      latitude: 12.8406,
      longitude: 80.1534,
    );

    const floor = FloorModel(
      id: 'flr-vit-ab1-01',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 1,
      name: 'Ground Floor (Floor 1)',
      elevation: 0.0,
    );

    final defaultNodes = [
      const NodeModel(
        id: 'node-entrance-01',
        name: 'Main Entrance',
        category: 'entrance',
        floorId: 'flr-vit-ab1-01',
        x: 10.0,
        y: 20.0,
        accessible: true,
      ),
      const NodeModel(
        id: 'node-corridor-01',
        name: 'Corridor Junction A',
        category: 'corridor',
        floorId: 'flr-vit-ab1-01',
        x: 25.0,
        y: 20.0,
        accessible: true,
      ),
      const NodeModel(
        id: 'node-lab-101',
        name: 'Robotics Lab 101',
        category: 'room',
        floorId: 'flr-vit-ab1-01',
        x: 70.0,
        y: 20.0,
        accessible: true,
      ),
    ];

    final defaultEdges = [
      const EdgeModel(
        id: 'edge-01-02',
        startNodeId: 'node-entrance-01',
        endNodeId: 'node-corridor-01',
        distance: 15.0,
        bearing: 90.0,
        accessible: true,
        blocked: false,
      ),
      const EdgeModel(
        id: 'edge-02-03',
        startNodeId: 'node-corridor-01',
        endNodeId: 'node-lab-101',
        distance: 45.0,
        bearing: 90.0,
        accessible: true,
        blocked: false,
      ),
    ];

    const defaultMetadata = [
      SemanticMetadataModel(
        entityId: 'node-lab-101',
        entityType: 'node',
        tags: ['robotics', 'ai', 'research'],
        aliases: ['Robotics Lab', 'Advanced Systems Lab'],
        department: 'School of Computer Science',
        capacity: 35,
      ),
    ];

    // Seeded Draft Map
    final draft = MapDraft(
      id: 'draft-ab1-01',
      building: building,
      floor: floor,
      nodes: defaultNodes,
      edges: defaultEdges,
      metadata: defaultMetadata,
      lifecycleState: MapLifecycleState.draft,
      lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      isMockStored: true,
    );
    _drafts[draft.id] = draft;

    // Seeded Published Map
    final published = MapDraft(
      id: 'published-ab1-v1',
      building: building,
      floor: floor,
      nodes: defaultNodes,
      edges: defaultEdges,
      metadata: defaultMetadata,
      lifecycleState: MapLifecycleState.published,
      lastUpdated: DateTime.now().subtract(const Duration(days: 1)),
      isMockStored: true,
    );
    _publishedMaps[published.id] = published;
  }

  @override
  Future<List<MapDraft>> getDrafts() async {
    await _maybeDelay();
    return _drafts.values.toList();
  }

  @override
  Future<List<MapDraft>> getPublishedMaps() async {
    await _maybeDelay();
    return _publishedMaps.values.toList();
  }

  @override
  Future<MapDraft?> getDraftById(String draftId) async {
    await _maybeDelay();
    return _drafts[draftId] ?? _publishedMaps[draftId];
  }

  @override
  Future<MapDraft> saveDraft(MapDraft draft) async {
    await _maybeDelay();
    final updated = draft.copyWith(
      lastUpdated: DateTime.now(),
      isMockStored: true,
    );
    _drafts[updated.id] = updated;
    return updated;
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    await _maybeDelay();
    _drafts.remove(draftId);
  }

  @override
  Future<PublishResult> publishMap(MapDraft draft, {bool simulateFailure = false}) async {
    await _maybeDelay();

    if (simulateFailure) {
      final failedDraft = draft.copyWith(
        lifecycleState: MapLifecycleState.failed,
        failureReason: 'Remote spatial backend service unavailable (Connection Refused).',
      );
      _drafts[draft.id] = failedDraft;
      return PublishResult.failure(
        draft: failedDraft,
        isMock: true,
        error: 'Remote spatial backend service unavailable (Connection Refused).',
      );
    }

    // Success in mock in-memory persistence
    final publishedDraft = draft.copyWith(
      lifecycleState: MapLifecycleState.published,
      lastUpdated: DateTime.now(),
      clearFailureReason: true,
      isMockStored: true,
    );

    _publishedMaps[publishedDraft.id] = publishedDraft;
    _drafts.remove(publishedDraft.id);

    return PublishResult.success(
      draft: publishedDraft,
      isMock: true,
      message: 'Map successfully stored in local mock repository (Mock In-Memory Persistence — backend endpoint not connected).',
    );
  }
}
