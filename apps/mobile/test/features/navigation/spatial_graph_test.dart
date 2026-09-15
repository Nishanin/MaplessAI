import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';

void main() {
  // Helper to construct sample test nodes
  NodeModel createNode(String id, {String? name, double x = 0.0, double y = 0.0, bool accessible = true}) {
    return NodeModel(
      id: id,
      name: name ?? 'Node $id',
      category: 'corridor',
      floorId: 'floor-1',
      x: x,
      y: y,
      accessible: accessible,
    );
  }

  // Helper to construct sample test edges
  EdgeModel createEdge(
    String id,
    String startNodeId,
    String endNodeId, {
    double distance = 10.0,
    double bearing = 90.0,
    bool accessible = true,
    bool blocked = false,
  }) {
    return EdgeModel(
      id: id,
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      distance: distance,
      bearing: bearing,
      accessible: accessible,
      blocked: blocked,
    );
  }

  group('SpatialGraph Domain Abstraction & Validation Tests', () {
    // 1. Empty graph
    test('1. Empty graph reports zero counts and empty validation error', () {
      final graph = SpatialGraph();
      expect(graph.isEmpty, isTrue);
      expect(graph.isNotEmpty, isFalse);
      expect(graph.nodeCount, equals(0));
      expect(graph.edgeCount, equals(0));
      expect(graph.allNodes, isEmpty);
      expect(graph.allEdges, isEmpty);
      expect(graph.getNode('n1'), isNull);
      expect(graph.getEdge('e1'), isNull);
      expect(graph.hasNode('n1'), isFalse);
      expect(graph.hasEdge('e1'), isFalse);
      expect(graph.getOutgoingEdges('n1'), isEmpty);
      expect(graph.getConnectedComponentCount(), equals(0));

      final validation = graph.validate();
      expect(validation.isValid, isFalse);
      expect(validation.errors, contains(contains('contains 0 nodes')));
      expect(() => graph.validateOrThrow(), throwsA(isA<GraphException>()));
    });

    // 2. Add one node
    test('2. Add one node increments count and enables lookup', () {
      final graph = SpatialGraph();
      final node = createNode('n1', name: 'Lobby', x: 5.0, y: 10.0);
      graph.addNode(node);

      expect(graph.nodeCount, equals(1));
      expect(graph.isEmpty, isFalse);
      expect(graph.hasNode('n1'), isTrue);
      expect(graph.getNode('n1'), equals(node));
      expect(graph.allNodes, equals([node]));
      expect(graph.getConnectedComponentCount(), equals(1));

      final validation = graph.validate();
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
    });

    // 3. Add multiple nodes
    test('3. Add multiple nodes preserves all nodes deterministically', () {
      final graph = SpatialGraph();
      final n1 = createNode('n1');
      final n2 = createNode('n2');
      final n3 = createNode('n3');
      graph.addNodes([n1, n2, n3]);

      expect(graph.nodeCount, equals(3));
      expect(graph.hasNode('n1'), isTrue);
      expect(graph.hasNode('n2'), isTrue);
      expect(graph.hasNode('n3'), isTrue);
      expect(graph.allNodes, equals([n1, n2, n3]));
    });

    // 4. Duplicate node ID
    test('4. Duplicate node ID throws GraphException with DUPLICATE_NODE_ID code', () {
      final graph = SpatialGraph();
      graph.addNode(createNode('n1', name: 'First'));

      expect(
        () => graph.addNode(createNode('n1', name: 'Second')),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('DUPLICATE_NODE_ID'))
              .having((e) => e.message, 'message', contains('Duplicate node ID')),
        ),
      );
      expect(graph.nodeCount, equals(1));
    });

    // 5. Add one edge
    test('5. Add one edge updates edge count and outgoing adjacency', () {
      final graph = SpatialGraph();
      graph.addNode(createNode('n1'));
      graph.addNode(createNode('n2'));

      final edge = createEdge('e1', 'n1', 'n2', distance: 12.5);
      graph.addEdge(edge);

      expect(graph.edgeCount, equals(1));
      expect(graph.hasEdge('e1'), isTrue);
      expect(graph.hasEdge('e2'), isFalse);
      expect(graph.getEdge('e1'), equals(edge));
      expect(graph.hasEdgeBetween('n1', 'n2'), isTrue);
      expect(graph.hasEdgeBetween('n2', 'n1'), isFalse);
      expect(graph.getOutgoingEdges('n1'), equals([edge]));
      expect(graph.getNeighbors('n1'), equals([edge]));
      expect(graph.getOutgoingEdges('n2'), isEmpty);
      expect(graph.allEdges, equals([edge]));
    });

    // 6. Add multiple edges
    test('6. Add multiple edges associates each with correct origin node', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2'), createNode('n3')]);

      final e1 = createEdge('e1', 'n1', 'n2');
      final e2 = createEdge('e2', 'n1', 'n3');
      final e3 = createEdge('e3', 'n2', 'n3');
      graph.addEdges([e1, e2, e3]);

      expect(graph.edgeCount, equals(3));
      expect(graph.getOutgoingEdges('n1'), equals([e1, e2]));
      expect(graph.getOutgoingEdges('n2'), equals([e3]));
      expect(graph.getOutgoingEdges('n3'), isEmpty);
    });

    // 7. Duplicate edge ID
    test('7. Duplicate edge ID throws GraphException with DUPLICATE_EDGE_ID code', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2'), createNode('n3')]);
      graph.addEdge(createEdge('e1', 'n1', 'n2'));

      expect(
        () => graph.addEdge(createEdge('e1', 'n2', 'n3')),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('DUPLICATE_EDGE_ID'))
              .having((e) => e.message, 'message', contains('Duplicate edge ID')),
        ),
      );
      expect(graph.edgeCount, equals(1));
    });

    // 8. Edge referencing missing start node
    test('8. Edge referencing missing start node throws GraphException with MISSING_START_NODE', () {
      final graph = SpatialGraph();
      graph.addNode(createNode('n2'));

      expect(
        () => graph.addEdge(createEdge('e1', 'missing-n1', 'n2')),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('MISSING_START_NODE'))
              .having((e) => e.message, 'message', contains('start node')),
        ),
      );
    });

    // 9. Edge referencing missing end node
    test('9. Edge referencing missing end node throws GraphException with MISSING_END_NODE', () {
      final graph = SpatialGraph();
      graph.addNode(createNode('n1'));

      expect(
        () => graph.addEdge(createEdge('e1', 'n1', 'missing-n2')),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('MISSING_END_NODE'))
              .having((e) => e.message, 'message', contains('end node')),
        ),
      );
    });

    // 10. Negative distance
    test('10. Negative finite distance throws GraphException with INVALID_DISTANCE', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);

      expect(
        () => graph.addEdge(createEdge('e1', 'n1', 'n2', distance: -5.0)),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('INVALID_DISTANCE'))
              .having((e) => e.message, 'message', contains('invalid distance')),
        ),
      );
    });

    // 10b. Edge with distance = double.nan
    test('10b. Edge with distance = double.nan throws GraphException with INVALID_DISTANCE', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);

      expect(
        () => graph.addEdge(createEdge('e_nan', 'n1', 'n2', distance: double.nan)),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('INVALID_DISTANCE'))
              .having((e) => e.message, 'message', contains('invalid distance')),
        ),
      );
    });

    // 10c. Edge with distance = double.infinity
    test('10c. Edge with distance = double.infinity throws GraphException with INVALID_DISTANCE', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);

      expect(
        () => graph.addEdge(createEdge('e_inf', 'n1', 'n2', distance: double.infinity)),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('INVALID_DISTANCE'))
              .having((e) => e.message, 'message', contains('invalid distance')),
        ),
      );
    });

    // 10d. Edge with distance = double.negativeInfinity
    test('10d. Edge with distance = double.negativeInfinity throws GraphException with INVALID_DISTANCE', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);

      expect(
        () => graph.addEdge(createEdge('e_neginf', 'n1', 'n2', distance: double.negativeInfinity)),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('INVALID_DISTANCE'))
              .having((e) => e.message, 'message', contains('invalid distance')),
        ),
      );
    });

    // 11. Zero-distance edge
    test('11. Zero-distance edge is valid and accepted', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);
      final zeroEdge = createEdge('e0', 'n1', 'n2', distance: 0.0);
      graph.addEdge(zeroEdge);

      expect(graph.edgeCount, equals(1));
      expect(graph.getEdge('e0')?.distance, equals(0.0));
      expect(graph.validate().isValid, isTrue);
    });

    // 12. Blocked edge remains in graph
    test('12. Blocked edge remains fully represented in graph and outgoing adjacency', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);
      final blockedEdge = createEdge('e_blocked', 'n1', 'n2', blocked: true);
      graph.addEdge(blockedEdge);

      expect(graph.edgeCount, equals(1));
      expect(graph.hasEdge('e_blocked'), isTrue);
      expect(graph.getEdge('e_blocked')?.blocked, isTrue);

      final outgoing = graph.getOutgoingEdges('n1');
      expect(outgoing.length, equals(1));
      expect(outgoing.first.blocked, isTrue);

      final validation = graph.validate();
      expect(validation.isValid, isTrue);
    });

    // 13. Directed edge behavior
    test('13. Directed edge semantics are strictly preserved (A->B does not imply B->A)', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('a'), createNode('b')]);
      final edgeAB = createEdge('e_ab', 'a', 'b', distance: 20.0, bearing: 90.0);
      graph.addEdge(edgeAB);

      expect(graph.hasEdgeBetween('a', 'b'), isTrue);
      expect(graph.hasEdgeBetween('b', 'a'), isFalse);
      expect(graph.getOutgoingEdges('a').map((e) => e.id), equals(['e_ab']));
      expect(graph.getOutgoingEdges('b'), isEmpty);
    });

    // 14. Disconnected components
    test('14. Disconnected components are valid and accurately counted', () {
      final graph = SpatialGraph();
      // Component 1: A -> B
      graph.addNodes([createNode('a'), createNode('b')]);
      graph.addEdge(createEdge('e_ab', 'a', 'b'));

      // Component 2: C -> D
      graph.addNodes([createNode('c'), createNode('d')]);
      graph.addEdge(createEdge('e_cd', 'c', 'd'));

      // Component 3: Isolated Node E
      graph.addNode(createNode('e'));

      expect(graph.nodeCount, equals(5));
      expect(graph.edgeCount, equals(2));
      expect(graph.getConnectedComponentCount(), equals(3));

      final validation = graph.validate();
      expect(validation.isValid, isTrue);
      expect(validation.componentCount, equals(3));
    });

    // 15. Self-loop handling
    test('15. Self-loop is retained in graph and generates a validation warning', () {
      final graph = SpatialGraph();
      graph.addNode(createNode('n1'));
      final loopEdge = createEdge('e_loop', 'n1', 'n1', distance: 0.0);
      graph.addEdge(loopEdge);

      expect(graph.edgeCount, equals(1));
      expect(graph.hasEdgeBetween('n1', 'n1'), isTrue);
      expect(graph.getOutgoingEdges('n1'), equals([loopEdge]));

      final validation = graph.validate();
      expect(validation.isValid, isTrue);
      expect(validation.warnings.length, equals(1));
      expect(validation.warnings.first, contains('Self-loop detected on node'));
    });

    // 16. clear() actually removes all nodes, edges, and adjacency
    test('16. clear() thoroughly removes all nodes, edges, and adjacency entries', () {
      final graph = SpatialGraph();
      graph.addNodes([createNode('n1'), createNode('n2')]);
      graph.addEdge(createEdge('e1', 'n1', 'n2'));

      expect(graph.nodeCount, equals(2));
      expect(graph.edgeCount, equals(1));

      graph.clear();

      expect(graph.isEmpty, isTrue);
      expect(graph.nodeCount, equals(0));
      expect(graph.edgeCount, equals(0));
      expect(graph.allNodes, isEmpty);
      expect(graph.allEdges, isEmpty);
      expect(graph.hasNode('n1'), isFalse);
      expect(graph.hasEdge('e1'), isFalse);
      expect(graph.getOutgoingEdges('n1'), isEmpty);
    });

    // 17, 18, 19, 20. VIT dataset construction and validation
    test('17-20. VIT Floor 1 graph constructs cleanly with accurate counts and adjacency', () {
      final paths = [
        '../../test_data/vit_floor_1.json',
        'assets/test_data/vit_floor_1.json',
        'test_data/vit_floor_1.json',
      ];

      File? file;
      for (final p in paths) {
        final f = File(p);
        if (f.existsSync()) {
          file = f;
          break;
        }
      }

      expect(file, isNotNull, reason: 'vit_floor_1.json must exist');
      final data = jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;

      final rawNodes = data['nodes'] as List<dynamic>;
      final rawEdges = data['edges'] as List<dynamic>;

      final nodes = rawNodes.map((n) => NodeModel.fromJson(n as Map<String, dynamic>)).toList();
      final edges = rawEdges.map((e) => EdgeModel.fromJson(e as Map<String, dynamic>)).toList();

      // 17. Construct via factory constructor
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges, validate: true);

      // 18. Correct node count (8 nodes in vit_floor_1.json)
      expect(graph.nodeCount, equals(8));
      expect(graph.hasNode('entrance'), isTrue);
      expect(graph.hasNode('reception'), isTrue);
      expect(graph.hasNode('corridor'), isTrue);
      expect(graph.hasNode('lab-101'), isTrue);
      expect(graph.hasNode('library'), isTrue);
      expect(graph.hasNode('staircase'), isTrue);
      expect(graph.hasNode('lift'), isTrue);
      expect(graph.hasNode('exit-a'), isTrue);

      // 19. Correct edge count (14 directed edges in vit_floor_1.json)
      expect(graph.edgeCount, equals(14));

      // 20. Verify adjacency integrity
      final receptionOutgoing = graph.getOutgoingEdges('reception');
      expect(receptionOutgoing.length, equals(3));
      final receptionDestinations = receptionOutgoing.map((e) => e.endNodeId).toSet();
      expect(receptionDestinations, equals({'entrance', 'corridor', 'lift'}));

      final corridorOutgoing = graph.getOutgoingEdges('corridor');
      expect(corridorOutgoing.length, equals(3));
      final corridorDestinations = corridorOutgoing.map((e) => e.endNodeId).toSet();
      expect(corridorDestinations, equals({'reception', 'lab-101', 'library'}));

      final validation = graph.validate();
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
      expect(validation.componentCount, equals(1)); // All 8 nodes form a single connected component
    });
  });
}
