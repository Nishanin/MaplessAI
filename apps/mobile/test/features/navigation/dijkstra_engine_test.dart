import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/dijkstra_engine.dart';

void main() {
  // --- Helpers ---
  NodeModel node(String id, {double x = 0, double y = 0}) {
    return NodeModel(
      id: id,
      name: 'Node $id',
      category: 'corridor',
      floorId: 'floor-1',
      x: x,
      y: y,
      accessible: true,
    );
  }

  EdgeModel edge(
    String id,
    String from,
    String to, {
    double distance = 10.0,
    double bearing = 90.0,
    bool blocked = false,
  }) {
    return EdgeModel(
      id: id,
      startNodeId: from,
      endNodeId: to,
      distance: distance,
      bearing: bearing,
      accessible: true,
      blocked: blocked,
    );
  }

  const engine = DijkstraEngine();

  group('Dijkstra Shortest-Path Engine Tests', () {
    // 1. Simple A → B
    test('1. Simple A → B direct path', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 5.0));

      final result = engine.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.pathEdgeIds, equals(['e1']));
      expect(result.totalDistance, equals(5.0));
    });

    // 2. A → B → C where direct A → C is longer
    test('2. A → B → C shorter than direct A → C', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 2.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 10.0));

      final result = engine.findShortestPath(graph, 'A', 'C');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.pathEdgeIds, equals(['e_ab', 'e_bc']));
      expect(result.totalDistance, equals(5.0));
    });

    // 3. Multiple paths; shortest path selected
    test('3. Multiple paths selects shortest', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C'), node('D')]);
      // Path 1: A → B → D (3 + 4 = 7)
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 4.0));
      // Path 2: A → C → D (2 + 2 = 4)
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 2.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 2.0));

      final result = engine.findShortestPath(graph, 'A', 'D');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'C', 'D']));
      expect(result.totalDistance, equals(4.0));
    });

    // 4. Directed asymmetry
    test('4. Directed edge A → B does not imply B → A', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      // A → B exists
      final forward = engine.findShortestPath(graph, 'A', 'B');
      expect(forward.found, isTrue);

      // B → A does not exist
      final backward = engine.findShortestPath(graph, 'B', 'A');
      expect(backward.found, isFalse);
      expect(backward.pathNodeIds, isEmpty);
    });

    // 5. Blocked edge skipped
    test('5. Blocked edge is skipped by default', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      // Direct A → B is blocked
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 1.0, blocked: true));
      // Detour A → C → B
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 3.0));
      graph.addEdge(edge('e_cb', 'C', 'B', distance: 3.0));

      final result = engine.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'C', 'B']));
      expect(result.totalDistance, equals(6.0));
    });

    // 6. All routes blocked → unreachable
    test('6. All routes blocked renders destination unreachable', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0, blocked: true));

      final result = engine.findShortestPath(graph, 'A', 'B');

      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
    });

    // 7. Disconnected destination
    test('7. Disconnected destination returns no route', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C'), node('D')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      final result = engine.findShortestPath(graph, 'A', 'D');

      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
    });

    // 8. Missing start node
    test('8. Missing start node throws GraphException', () {
      final graph = SpatialGraph();
      graph.addNode(node('B'));

      expect(
        () => engine.findShortestPath(graph, 'missing', 'B'),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('START_NODE_NOT_FOUND')),
        ),
      );
    });

    // 9. Missing destination node
    test('9. Missing destination node throws GraphException', () {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      expect(
        () => engine.findShortestPath(graph, 'A', 'missing'),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('DESTINATION_NODE_NOT_FOUND')),
        ),
      );
    });

    // 10. start == destination
    test('10. Start equals destination returns zero-distance single-node path', () {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      final result = engine.findShortestPath(graph, 'A', 'A');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A']));
      expect(result.pathEdgeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
    });

    // 11. Zero-distance edge
    test('11. Zero-distance edge is traversed correctly', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 0.0));

      final result = engine.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(0.0));
    });

    // 12. Zero-distance cycle does not cause infinite loop
    test('12. Zero-distance cycle does not cause infinite loop', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      // Zero-cost cycle: A → B → A
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 0.0));
      graph.addEdge(edge('e_ba', 'B', 'A', distance: 0.0));
      // Actual route to C
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final result = engine.findShortestPath(graph, 'A', 'C');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.totalDistance, equals(5.0));
    });

    // 13 + 14. Multiple equal-cost shortest paths + deterministic tie-breaking
    test('13-14. Equal-cost paths produce deterministic result across runs', () {
      // Diamond graph: A → B → D and A → C → D, both cost 10
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C'), node('D')]);
      // B path added first in adjacency list
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 5.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      // Run multiple times and verify deterministic result
      DijkstraResult? firstResult;
      for (var i = 0; i < 10; i++) {
        final result = engine.findShortestPath(graph, 'A', 'D');
        expect(result.found, isTrue);
        expect(result.totalDistance, equals(10.0));

        if (firstResult == null) {
          firstResult = result;
        } else {
          expect(result.pathNodeIds, equals(firstResult.pathNodeIds),
              reason: 'Dijkstra must produce identical path on run $i');
          expect(result.pathEdgeIds, equals(firstResult.pathEdgeIds),
              reason: 'Dijkstra must produce identical edges on run $i');
        }
      }

      // Verify the path goes through B (first in adjacency order)
      expect(firstResult!.pathNodeIds, equals(['A', 'B', 'D']));
    });

    // 15. Graph with isolated nodes
    test('15. Isolated nodes do not affect routing of connected nodes', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('isolated1'), node('isolated2')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 7.0));

      final result = engine.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(7.0));
    });

    // 16. Graph with multiple disconnected components
    test('16. Routing within a component succeeds while cross-component fails', () {
      final graph = SpatialGraph();
      // Component 1
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      // Component 2
      graph.addNodes([node('C'), node('D')]);
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 4.0));

      // Within component 1
      final r1 = engine.findShortestPath(graph, 'A', 'B');
      expect(r1.found, isTrue);
      expect(r1.totalDistance, equals(3.0));

      // Within component 2
      final r2 = engine.findShortestPath(graph, 'C', 'D');
      expect(r2.found, isTrue);
      expect(r2.totalDistance, equals(4.0));

      // Cross-component
      final r3 = engine.findShortestPath(graph, 'A', 'D');
      expect(r3.found, isFalse);
    });

    // 17. VIT graph route using actual graph data
    test('17. VIT Floor 1 graph: real Dijkstra route entrance → lab-101', () {
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
      final nodes = (data['nodes'] as List)
          .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
          .toList();
      final edges = (data['edges'] as List)
          .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = engine.findShortestPath(graph, 'entrance', 'lab-101');

      expect(result.found, isTrue);
      expect(result.pathNodeIds.first, equals('entrance'));
      expect(result.pathNodeIds.last, equals('lab-101'));
      expect(result.totalDistance, greaterThan(0.0));

      // Verify the path is entrance → reception → corridor → lab-101
      // based on the known graph structure:
      // entrance→reception: 10m, reception→corridor: 15m, corridor→lab-101: 15m = 40m
      expect(result.pathNodeIds, equals(['entrance', 'reception', 'corridor', 'lab-101']));
      expect(result.totalDistance, equals(40.0));
    });

    // 18. Verify returned path contains valid consecutive edges
    test('18. Every consecutive node pair in path has a real directed edge', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C'), node('D')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 1.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 2.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 3.0));

      final result = engine.findShortestPath(graph, 'A', 'D');
      expect(result.found, isTrue);

      // Verify each consecutive pair has a real edge
      for (var i = 0; i < result.pathNodeIds.length - 1; i++) {
        final from = result.pathNodeIds[i];
        final to = result.pathNodeIds[i + 1];
        expect(graph.hasEdgeBetween(from, to), isTrue,
            reason: 'Edge from $from to $to must exist in graph');
      }
    });

    // 19. Verify returned total distance equals selected edge sum
    test('19. Total distance equals sum of traversed edge distances', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 7.5));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 3.5));

      final result = engine.findShortestPath(graph, 'A', 'C');
      expect(result.found, isTrue);

      // Manually sum the edge distances from the returned edge IDs
      double edgeSum = 0.0;
      for (final edgeId in result.pathEdgeIds) {
        final e = graph.getEdge(edgeId);
        expect(e, isNotNull, reason: 'Edge $edgeId must exist in graph');
        edgeSum += e!.distance;
      }
      expect(result.totalDistance, equals(edgeSum));
    });

    // 20. Verify no fabricated direct start → destination path
    test('20. No fabricated direct path when only indirect route exists', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      // No direct A → C edge exists, only A → B → C
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 4.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 6.0));

      final result = engine.findShortestPath(graph, 'A', 'C');
      expect(result.found, isTrue);

      // Must NOT be [A, C] — must be [A, B, C]
      expect(result.pathNodeIds.length, greaterThan(2));
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.totalDistance, equals(10.0));
    });

    // 21. Larger synthetic graph for basic performance sanity
    test('21. Larger synthetic graph completes correctly', () {
      final graph = SpatialGraph();

      // Create a chain of 100 nodes: n0 → n1 → n2 → ... → n99
      const count = 100;
      for (var i = 0; i < count; i++) {
        graph.addNode(node('n$i'));
      }
      for (var i = 0; i < count - 1; i++) {
        graph.addEdge(edge('e_${i}_${i + 1}', 'n$i', 'n${i + 1}', distance: 1.0));
      }
      // Add a shortcut: n0 → n50 with distance 60 (longer than chain of 50)
      graph.addEdge(edge('e_shortcut', 'n0', 'n50', distance: 60.0));

      final result = engine.findShortestPath(graph, 'n0', 'n99');

      expect(result.found, isTrue);
      expect(result.pathNodeIds.first, equals('n0'));
      expect(result.pathNodeIds.last, equals('n99'));
      // Chain path: 99 edges × 1.0 = 99.0 (shorter than shortcut-based)
      expect(result.totalDistance, equals(99.0));
      expect(result.pathNodeIds.length, equals(100));
    });

    // Additional: skipBlocked = false allows traversal of blocked edges
    test('Blocked edge traversed when skipBlocked is false', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0, blocked: true));

      final result = engine.findShortestPath(graph, 'A', 'B', skipBlocked: false);

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(5.0));
    });
  });
}
