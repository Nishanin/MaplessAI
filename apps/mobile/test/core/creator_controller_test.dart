import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/models/semantic_metadata_model.dart';
import 'package:mapless_ai/features/mapping/domain/map_draft_model.dart';
import 'package:mapless_ai/features/mapping/services/mock_creator_mapping_repository.dart';
import 'package:mapless_ai/features/mapping/state/creator_controller.dart';

void main() {
  group('CreatorController State Machine & Persistence Tests', () {
    late MockCreatorMappingRepository repository;
    late ProviderContainer container;
    late CreatorController controller;

    const testBuilding = BuildingModel(
      id: 'bld-vit-cc-01',
      name: 'Academic Block 1',
      address: 'Chennai Campus',
      category: 'academic',
      latitude: 12.8406,
      longitude: 80.1534,
    );

    const testFloor = FloorModel(
      id: 'flr-vit-ab1-01',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 1,
      name: 'Ground Floor',
      elevation: 0.0,
    );

    NodeModel makeNode({
      required String id,
      required String name,
      String category = 'room',
      String floorId = 'flr-vit-ab1-01',
      double x = 0.0,
      double y = 0.0,
      bool accessible = true,
    }) =>
        NodeModel(
          id: id,
          name: name,
          category: category,
          floorId: floorId,
          x: x,
          y: y,
          accessible: accessible,
        );

    EdgeModel makeEdge({
      required String id,
      required String startNodeId,
      required String endNodeId,
      double distance = 10.0,
      double bearing = 0.0,
      bool accessible = true,
      bool blocked = false,
    }) =>
        EdgeModel(
          id: id,
          startNodeId: startNodeId,
          endNodeId: endNodeId,
          distance: distance,
          bearing: bearing,
          accessible: accessible,
          blocked: blocked,
        );

    setUp(() async {
      repository = MockCreatorMappingRepository(seedInitialData: true);
      container = ProviderContainer();
      controller = CreatorController(
        repository: repository,
        ref: null,
      );
      await controller.loadProjects();
    });

    tearDown(() {
      container.dispose();
    });

    test('Loads seeded projects from repository on initialization', () {
      final state = controller.currentState;
      expect(state.savedDrafts, isNotEmpty);
      expect(state.publishedMaps, isNotEmpty);
      expect(state.savedDrafts.first.building.name, contains('Academic Block 1'));
    });

    test('startNewSession initializes a fresh active draft in draft lifecycle state', () {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final state = controller.currentState;
      expect(state.activeDraft, isNotNull);
      expect(state.activeDraft!.building.id, equals(testBuilding.id));
      expect(state.activeDraft!.floor.id, equals(testFloor.id));
      expect(state.activeDraft!.lifecycleState, equals(MapLifecycleState.draft));
      expect(state.activeDraft!.nodes, isEmpty);
      expect(state.activeDraft!.edges, isEmpty);
      expect(state.activeDraft!.isMockStored, isTrue);
    });

    test('createBuilding and createFloor create valid domain entities and update spatial state', () {
      final building = controller.createBuilding(
        name: 'Delta Technology Center',
        id: 'bld-dtc-01',
        address: 'Tech Park Avenue',
        category: 'research',
        latitude: 12.85,
        longitude: 80.16,
        description: 'Advanced AI Labs',
      );

      expect(building, isNotNull);
      expect(building!.name, equals('Delta Technology Center'));
      expect(building.category, equals('research'));

      final floor = controller.createFloor(
        buildingId: building.id,
        name: 'Mezzanine Level',
        floorNumber: 2,
        elevation: 4.5,
      );

      expect(floor, isNotNull);
      expect(floor!.id, equals('flr-bld-dtc-01-2'));
      expect(floor.elevation, equals(4.5));
    });

    test('Adding and updating location nodes updates active draft', () {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final node1 = makeNode(
        id: 'node-lab-01',
        name: 'Robotics Lab',
        x: 10.0,
        y: 20.0,
      );

      controller.addNode(node1);
      expect(controller.currentState.activeDraft!.nodes.length, equals(1));
      expect(controller.currentState.activeDraft!.nodes.first.name, equals('Robotics Lab'));

      // Update node
      final updatedNode1 = node1.copyWith(name: 'Advanced Robotics Lab');
      controller.updateNode(updatedNode1);
      expect(controller.currentState.activeDraft!.nodes.first.name, equals('Advanced Robotics Lab'));
    });

    test('Deleting a node automatically cascades and removes connected edges and metadata', () {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final n1 = makeNode(id: 'n1', name: 'N1', x: 0, y: 0);
      final n2 = makeNode(id: 'n2', name: 'N2', x: 10, y: 0);
      final n3 = makeNode(id: 'n3', name: 'N3', x: 20, y: 0);

      controller.addNode(n1);
      controller.addNode(n2);
      controller.addNode(n3);

      final e1 = makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 10);
      final e2 = makeEdge(id: 'e2', startNodeId: 'n2', endNodeId: 'n3', distance: 10);

      controller.connectNodes(e1);
      controller.connectNodes(e2);

      const meta = SemanticMetadataModel(entityId: 'n2', entityType: 'node', tags: ['hub']);
      controller.addOrUpdateMetadata(meta);

      expect(controller.currentState.activeDraft!.nodes.length, equals(3));
      expect(controller.currentState.activeDraft!.edges.length, equals(2));
      expect(controller.currentState.activeDraft!.metadata.length, equals(1));

      // Delete n2: Should purge e1 (endNode=n2), e2 (startNode=n2), and meta for n2
      controller.deleteNode('n2');

      final draft = controller.currentState.activeDraft!;
      expect(draft.nodes.length, equals(2));
      expect(draft.nodes.any((n) => n.id == 'n2'), isFalse);
      expect(draft.edges, isEmpty);
      expect(draft.metadata, isEmpty);
    });

    test('Connecting nodes creates edge and toggling blocked state updates edge', () {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final n1 = makeNode(id: 'n1', name: 'Point A', category: 'corridor', x: 0, y: 0);
      final n2 = makeNode(id: 'n2', name: 'Point B', category: 'corridor', x: 0, y: 15);

      controller.addNode(n1);
      controller.addNode(n2);

      final edge = makeEdge(id: 'edge-ab', startNodeId: 'n1', endNodeId: 'n2', distance: 15.0, blocked: false);
      controller.connectNodes(edge);

      expect(controller.currentState.activeDraft!.edges.length, equals(1));
      expect(controller.currentState.activeDraft!.edges.first.blocked, isFalse);

      // Toggle blocked
      controller.toggleEdgeBlocked('edge-ab');
      expect(controller.currentState.activeDraft!.edges.first.blocked, isTrue);

      // Toggle back
      controller.toggleEdgeBlocked('edge-ab');
      expect(controller.currentState.activeDraft!.edges.first.blocked, isFalse);
    });

    test('validateCurrentDraft validates graph and updates lifecycleState to validated', () {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final n1 = makeNode(id: 'n1', name: 'Room 101', x: 0, y: 0);
      final n2 = makeNode(id: 'n2', name: 'Room 102', x: 10, y: 0);
      final edge = makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 10);

      controller.addNode(n1);
      controller.addNode(n2);
      controller.connectNodes(edge);

      final result = controller.validateCurrentDraft();
      expect(result.isValid, isTrue);
      expect(controller.currentState.activeDraft!.lifecycleState, equals(MapLifecycleState.validated));
      expect(controller.currentState.isReadyToPublish, isTrue);
    });

    test('Saving draft updates repository and returns true', () async {
      controller.startNewSession(building: testBuilding, floor: testFloor);
      final n1 = makeNode(id: 'n1', name: 'Room 101', x: 0, y: 0);
      controller.addNode(n1);

      final saved = await controller.saveCurrentDraft();
      expect(saved, isTrue);
      expect(controller.currentState.savedDrafts.any((d) => d.id == controller.currentState.activeDraft!.id), isTrue);
    });

    test('Publishing a valid draft updates state to published with explicit mock disclosure', () async {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final n1 = makeNode(id: 'n1', name: 'A', x: 0, y: 0);
      final n2 = makeNode(id: 'n2', name: 'B', x: 5, y: 0);
      final edge = makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 5);

      controller.addNode(n1);
      controller.addNode(n2);
      controller.connectNodes(edge);

      final result = await controller.publishCurrentDraft();

      expect(result.isSuccess, isTrue);
      expect(result.isMock, isTrue); // Explicit mock persistence disclosure!
      expect(controller.currentState.activeDraft!.lifecycleState, equals(MapLifecycleState.published));
      expect(controller.currentState.publishedMaps.any((p) => p.id == result.draft.id), isTrue);
    });

    test('Publishing with simulated failure transitions to failed state and reports error', () async {
      controller.startNewSession(building: testBuilding, floor: testFloor);

      final n1 = makeNode(id: 'n1', name: 'A', x: 0, y: 0);
      final n2 = makeNode(id: 'n2', name: 'B', x: 5, y: 0);
      final edge = makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 5);

      controller.addNode(n1);
      controller.addNode(n2);
      controller.connectNodes(edge);

      final result = await controller.publishCurrentDraft(simulateFailure: true);

      expect(result.isSuccess, isFalse);
      expect(result.isMock, isTrue);
      expect(result.error, contains('Remote spatial backend service unavailable'));
      expect(controller.currentState.activeDraft!.lifecycleState, equals(MapLifecycleState.failed));
      expect(controller.currentState.errorMessage, isNotNull);
    });

    test('Publishing an invalid graph is rejected with clear error', () async {
      controller.startNewSession(building: testBuilding, floor: testFloor);
      // Empty nodes = invalid

      final result = await controller.publishCurrentDraft();
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Cannot publish an invalid map'));
    });
  });
}
