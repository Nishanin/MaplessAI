import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/models/semantic_metadata_model.dart';
import 'package:mapless_ai/features/mapping/domain/map_draft_model.dart';
import 'package:mapless_ai/features/mapping/domain/map_validation_service.dart';

void main() {
  group('MapValidationService Topological Contract Tests', () {
    const validBuilding = BuildingModel(
      id: 'bld-test-01',
      name: 'Test Engineering Hall',
      address: 'Campus Quad',
      category: 'academic',
      latitude: 12.8406,
      longitude: 80.1534,
    );

    const validFloor = FloorModel(
      id: 'flr-test-01',
      buildingId: 'bld-test-01',
      floorNumber: 1,
      name: 'Ground Level',
      elevation: 0.0,
    );

    NodeModel makeNode({
      required String id,
      required String name,
      String category = 'room',
      String floorId = 'flr-test-01',
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

    test('Valid graph passes validation with 0 errors', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Entrance', category: 'entrance', x: 0.0, y: 0.0),
        makeNode(id: 'n2', name: 'Corridor A', category: 'corridor', x: 10.0, y: 0.0),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 10.0, bearing: 90.0),
      ];

      final draft = MapDraft(
        id: 'draft-01',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.errorCount, equals(0));
    });

    test('Graph with empty building or floor ID fails validation', () {
      const invalidBuilding = BuildingModel(
        id: '',
        name: 'No ID Building',
        address: '',
        category: '',
        latitude: 0,
        longitude: 0,
      );

      final draft = MapDraft(
        id: 'draft-bad-building',
        building: invalidBuilding,
        floor: validFloor,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('Building ID')), isTrue);
    });

    test('Duplicate node IDs trigger validation errors', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Node 1', x: 0, y: 0),
        makeNode(id: 'n1', name: 'Node 1 Duplicate', x: 5, y: 5),
      ];

      final draft = MapDraft(
        id: 'draft-dup-nodes',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('Duplicate node ID')), isTrue);
    });

    test('Non-finite coordinates (NaN / Infinity) fail validation', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Invalid Coord Node', x: double.nan, y: 10.0),
      ];

      final draft = MapDraft(
        id: 'draft-nan-coords',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('finite coordinates')), isTrue);
    });

    test('Unsupported node category triggers validation error', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Alien Room', category: 'intergalactic_portal'),
      ];

      final draft = MapDraft(
        id: 'draft-bad-cat',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('Invalid node category')), isTrue);
    });

    test('Edge pointing to nonexistent node fails validation', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Start Node'),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n_missing', distance: 5.0),
      ];

      final draft = MapDraft(
        id: 'draft-missing-endpoint',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('non-existent')), isTrue);
    });

    test('Self-loop edge (startNodeId == endNodeId) fails validation', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Self Loop Node'),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n1', distance: 0.0),
      ];

      final draft = MapDraft(
        id: 'draft-self-loop',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.toLowerCase().contains('self-loop')), isTrue);
    });

    test('Negative edge distance fails validation', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'A', x: 0, y: 0),
        makeNode(id: 'n2', name: 'B', x: 5, y: 0),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: -15.0),
      ];

      final draft = MapDraft(
        id: 'draft-negative-dist',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('invalid distance')), isTrue);
    });

    test('Blocked edge produces a warning, but not an error', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Node 1', category: 'corridor', x: 0, y: 0),
        makeNode(id: 'n2', name: 'Node 2', category: 'corridor', x: 10, y: 0),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 10.0, blocked: true),
      ];

      final draft = MapDraft(
        id: 'draft-blocked-edge',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isTrue); // warnings do not block validity
      expect(result.warnings.any((w) => w.message.contains('marked as BLOCKED')), isTrue);
      expect(result.warningCount, greaterThan(0));
    });

    test('Isolated disconnected node produces a warning', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Connected A', x: 0, y: 0),
        makeNode(id: 'n2', name: 'Connected B', x: 5, y: 0),
        makeNode(id: 'n3', name: 'Isolated C', x: 20, y: 20),
      ];

      final edges = <EdgeModel>[
        makeEdge(id: 'e1', startNodeId: 'n1', endNodeId: 'n2', distance: 5.0),
      ];

      final draft = MapDraft(
        id: 'draft-isolated-node',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        edges: edges,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isTrue);
      expect(result.warnings.any((w) => w.message.contains('isolated')), isTrue);
    });

    test('Semantic metadata referencing non-existent entity triggers error', () {
      final nodes = <NodeModel>[
        makeNode(id: 'n1', name: 'Real Node'),
      ];

      final metadata = <SemanticMetadataModel>[
        const SemanticMetadataModel(
          entityId: 'n_ghost',
          entityType: 'node',
          tags: ['lab'],
        ),
      ];

      final draft = MapDraft(
        id: 'draft-orphan-metadata',
        building: validBuilding,
        floor: validFloor,
        nodes: nodes,
        metadata: metadata,
        lastUpdated: DateTime.now(),
      );

      final result = MapValidationService.validateDraft(draft);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.message.contains('does not exist in the graph')), isTrue);
    });
  });
}
