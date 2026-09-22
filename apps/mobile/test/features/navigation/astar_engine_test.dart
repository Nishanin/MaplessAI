import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/astar_engine.dart';
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

  const astar = AStarEngine();
  const dijkstra = DijkstraEngine();

  /// Small floating-point tolerance for A* vs Dijkstra distance comparison.
  const epsilon = 1e-9;

  group('A* Shortest-Path Engine Tests', () {
    // 1. Simple direct route
    test('1. Simple A → B direct path', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 5, y: 0)]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.pathEdgeIds, equals(['e1']));
      expect(result.totalDistance, equals(5.0));
      expect(result.algorithm, equals('A*'));
    });

    // 2. Multi-edge shortest route
    test('2. A → B → C shorter than direct A → C', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 0),
        node('C', x: 5, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 2.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 10.0));

      final result = astar.findShortestPath(graph, 'A', 'C');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.pathEdgeIds, equals(['e_ab', 'e_bc']));
      expect(result.totalDistance, equals(5.0));
    });

    // 3. Multiple alternative routes
    test('3. Multiple paths selects shortest', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 3),
        node('C', x: 2, y: 1),
        node('D', x: 5, y: 0),
      ]);
      // Path 1: A → B → D (3 + 4 = 7)
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 4.0));
      // Path 2: A → C → D (2 + 2 = 4) — shorter
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 2.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 2.0));

      final result = astar.findShortestPath(graph, 'A', 'D');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'C', 'D']));
      expect(result.totalDistance, equals(4.0));
    });

    // 4. Directed graph
    test('4. Directed edge A → B does not imply B → A', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 5, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      final forward = astar.findShortestPath(graph, 'A', 'B');
      expect(forward.found, isTrue);

      final backward = astar.findShortestPath(graph, 'B', 'A');
      expect(backward.found, isFalse);
      expect(backward.pathNodeIds, isEmpty);
    });

    // 5. Blocked edge
    test('5. Blocked edge is skipped by default', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 3, y: 3),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 1.0, blocked: true));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 3.0));
      graph.addEdge(edge('e_cb', 'C', 'B', distance: 3.0));

      final result = astar.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'C', 'B']));
      expect(result.totalDistance, equals(6.0));
    });

    // 6. All routes blocked
    test('6. All routes blocked renders destination unreachable', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 5, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0, blocked: true));

      final result = astar.findShortestPath(graph, 'A', 'B');

      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
    });

    // 7. Disconnected destination
    test('7. Disconnected destination returns no route', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 20, y: 0),
        node('D', x: 25, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'D');

      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
    });

    // 8. Missing start node
    test('8. Missing start node throws GraphException', () {
      final graph = SpatialGraph();
      graph.addNode(node('B'));

      expect(
        () => astar.findShortestPath(graph, 'missing', 'B'),
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
        () => astar.findShortestPath(graph, 'A', 'missing'),
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

      final result = astar.findShortestPath(graph, 'A', 'A');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A']));
      expect(result.pathEdgeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
      expect(result.nodesExplored, equals(0));
    });

    // 11. Zero-distance edge
    test('11. Zero-distance edge is traversed correctly', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 0, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 0.0));

      final result = astar.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(0.0));
    });

    // 12. Zero-distance cycle
    test('12. Zero-distance cycle does not cause infinite loop', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 0, y: 0),
        node('C', x: 5, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 0.0));
      graph.addEdge(edge('e_ba', 'B', 'A', distance: 0.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'C');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.totalDistance, equals(5.0));
    });

    // 13. Equal-cost deterministic paths
    test('13. Equal-cost paths produce deterministic result', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 5),
        node('C', x: 5, y: -5),
        node('D', x: 10, y: 0),
      ]);
      // B path added first
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 5.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'D');
      expect(result.found, isTrue);
      expect(result.totalDistance, equals(10.0));
      // B was inserted first → A → B → D wins via first-discovered tie-breaking
      expect(result.pathNodeIds, equals(['A', 'B', 'D']));
    });

    // 14. Repeated deterministic execution
    test('14. Repeated execution produces identical results (100 runs)', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 5),
        node('C', x: 5, y: -5),
        node('D', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 5.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      final first = astar.findShortestPath(graph, 'A', 'D');
      for (var i = 1; i < 100; i++) {
        final result = astar.findShortestPath(graph, 'A', 'D');
        expect(result.pathNodeIds, equals(first.pathNodeIds),
            reason: 'Run $i pathNodeIds diverged');
        expect(result.pathEdgeIds, equals(first.pathEdgeIds),
            reason: 'Run $i pathEdgeIds diverged');
        expect(result.totalDistance, equals(first.totalDistance),
            reason: 'Run $i totalDistance diverged');
      }
    });

    // 15. Isolated nodes
    test('15. Isolated nodes do not affect routing', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 7, y: 0),
        node('isolated1', x: 50, y: 50),
        node('isolated2', x: -50, y: -50),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 7.0));

      final result = astar.findShortestPath(graph, 'A', 'B');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(7.0));
    });

    // 16. Multiple components
    test('16. Within-component succeeds, cross-component fails', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addNodes([
        node('C', x: 20, y: 0),
        node('D', x: 24, y: 0),
      ]);
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 4.0));

      expect(astar.findShortestPath(graph, 'A', 'B').found, isTrue);
      expect(astar.findShortestPath(graph, 'C', 'D').found, isTrue);
      expect(astar.findShortestPath(graph, 'A', 'D').found, isFalse);
    });

    // 17. VIT graph
    test('17. VIT Floor 1 graph: A* route entrance → lab-101', () {
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

      final result = astar.findShortestPath(graph, 'entrance', 'lab-101');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['entrance', 'reception', 'corridor', 'lab-101']));
      expect(result.totalDistance, equals(40.0));
      expect(result.heuristicActive, isTrue,
          reason: 'VIT graph edges satisfy admissibility');
    });

    // 18. Path node/edge consistency
    test('18. Every consecutive node pair in path has a real directed edge', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 1, y: 0),
        node('C', x: 2, y: 0),
        node('D', x: 3, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 1.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 2.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 3.0));

      final result = astar.findShortestPath(graph, 'A', 'D');
      expect(result.found, isTrue);

      for (var i = 0; i < result.pathNodeIds.length - 1; i++) {
        final from = result.pathNodeIds[i];
        final to = result.pathNodeIds[i + 1];
        expect(graph.hasEdgeBetween(from, to), isTrue,
            reason: 'Edge from $from to $to must exist');
      }
    });

    // 19. Total distance equals edge sum
    test('19. Total distance equals sum of traversed edge distances', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 7.5, y: 0),
        node('C', x: 11, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 7.5));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 3.5));

      final result = astar.findShortestPath(graph, 'A', 'C');
      expect(result.found, isTrue);

      double edgeSum = 0.0;
      for (final edgeId in result.pathEdgeIds) {
        final e = graph.getEdge(edgeId);
        expect(e, isNotNull);
        edgeSum += e!.distance;
      }
      expect(result.totalDistance, equals(edgeSum));
    });

    // 20. No fabricated route
    test('20. No fabricated direct path when only indirect route exists', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 4, y: 0),
        node('C', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 4.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 6.0));

      final result = astar.findShortestPath(graph, 'A', 'C');
      expect(result.found, isTrue);
      expect(result.pathNodeIds.length, greaterThan(2));
      expect(result.pathNodeIds, equals(['A', 'B', 'C']));
      expect(result.totalDistance, equals(10.0));
    });

    // 21. A* distance equals Dijkstra distance
    test('21. A* returns same optimal distance as Dijkstra', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 4),
        node('C', x: 6, y: 0),
        node('D', x: 10, y: 0),
        node('E', x: 5, y: 8),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 6.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 8.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 4.0));
      graph.addEdge(edge('e_be', 'B', 'E', distance: 5.0));
      graph.addEdge(edge('e_ed', 'E', 'D', distance: 7.0));

      final astarResult = astar.findShortestPath(graph, 'A', 'D');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'D');

      expect(astarResult.found, equals(dijkstraResult.found));
      expect(
        (astarResult.totalDistance - dijkstraResult.totalDistance).abs(),
        lessThan(epsilon),
        reason: 'A* and Dijkstra must agree on optimal distance',
      );
    });

    // 22. A* path is valid according to SpatialGraph
    test('22. A* path edges all exist in graph with correct direction', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 10, y: 0),
        node('D', x: 15, y: 0),
        node('E', x: 20, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));
      graph.addEdge(edge('e_de', 'D', 'E', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'E');
      expect(result.found, isTrue);

      // Verify every returned edge ID exists and matches the node pair
      expect(result.pathEdgeIds.length, equals(result.pathNodeIds.length - 1));
      for (var i = 0; i < result.pathEdgeIds.length; i++) {
        final e = graph.getEdge(result.pathEdgeIds[i]);
        expect(e, isNotNull);
        expect(e!.startNodeId, equals(result.pathNodeIds[i]));
        expect(e.endNodeId, equals(result.pathNodeIds[i + 1]));
      }
    });

    // 23. Heuristic admissibility: VIT graph uses Euclidean heuristic
    test('23. Heuristic is active when graph edges satisfy admissibility', () {
      // Graph where edge.distance == Euclidean(start, end) for all edges
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 4),  // Euclidean from A = 5.0
        node('C', x: 6, y: 0),  // Euclidean from B = 5.0
      ]);
      // edge.distance == Euclidean for each edge
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final result = astar.findShortestPath(graph, 'A', 'C');

      expect(result.found, isTrue);
      expect(result.heuristicActive, isTrue);
      expect(result.totalDistance, equals(10.0));
    });

    // 24. Heuristic fallback when graph violates admissibility
    test('24. Heuristic falls back to h=0 when edge.distance < Euclidean', () {
      // Create a graph where edge.distance < Euclidean(start, end)
      // This violates the admissibility assumption.
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 10, y: 0), // Euclidean A→B = 10.0
        node('C', x: 20, y: 0), // Euclidean B→C = 10.0
      ]);
      // edge distance (3.0) < Euclidean distance (10.0) — violates admissibility!
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 3.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 3.0));

      final astarResult = astar.findShortestPath(graph, 'A', 'C');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'C');

      // A* must fall back to h=0, producing same result as Dijkstra
      expect(astarResult.heuristicActive, isFalse,
          reason: 'Heuristic must be deactivated for inadmissible graph');
      expect(astarResult.found, isTrue);
      expect(astarResult.totalDistance, equals(dijkstraResult.totalDistance));
      expect(astarResult.pathNodeIds, equals(dijkstraResult.pathNodeIds));
    });

    // 24b. Verify A* never returns worse distance than Dijkstra on inadmissible graph
    test('24b. A* never returns suboptimal distance (inadmissible graph with alternatives)', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 100, y: 0), // coordinates suggest far away
        node('C', x: 50, y: 0),
      ]);
      // Short edge to B despite large coordinate distance
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 2.0)); // violates admissibility
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 50.0));
      graph.addEdge(edge('e_cb', 'C', 'B', distance: 50.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 50.0));

      final astarResult = astar.findShortestPath(graph, 'A', 'C');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'C');

      expect(astarResult.heuristicActive, isFalse);
      expect(
        (astarResult.totalDistance - dijkstraResult.totalDistance).abs(),
        lessThan(epsilon),
        reason: 'A* with h=0 fallback must match Dijkstra distance',
      );
    });

    // 25. Larger synthetic graph
    test('25. Larger synthetic graph (100 nodes) completes correctly', () {
      final graph = SpatialGraph();

      const count = 100;
      for (var i = 0; i < count; i++) {
        graph.addNode(node('n$i', x: i.toDouble(), y: 0));
      }
      for (var i = 0; i < count - 1; i++) {
        graph.addEdge(edge('e_${i}_${i + 1}', 'n$i', 'n${i + 1}', distance: 1.0));
      }
      // Shortcut: n0 → n50, distance 60 (longer than chain)
      graph.addEdge(edge('e_shortcut', 'n0', 'n50', distance: 60.0));

      final result = astar.findShortestPath(graph, 'n0', 'n99');

      expect(result.found, isTrue);
      expect(result.pathNodeIds.first, equals('n0'));
      expect(result.pathNodeIds.last, equals('n99'));
      expect(result.totalDistance, equals(99.0));
      expect(result.pathNodeIds.length, equals(100));
    });

    // skipBlocked = false allows blocked traversal
    test('Blocked edge traversed when skipBlocked is false', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 5, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0, blocked: true));

      final result = astar.findShortestPath(graph, 'A', 'B', skipBlocked: false);

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['A', 'B']));
      expect(result.totalDistance, equals(5.0));
    });
  });

  group('A* vs Dijkstra Comparison Tests', () {
    // VIT graph comparison
    test('VIT graph: A* and Dijkstra return same optimal distance', () {
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

      // Test multiple VIT routes
      final routes = [
        ['entrance', 'lab-101'],
        ['entrance', 'library'],
        ['reception', 'exit-a'],
        ['corridor', 'lift'],
        ['lab-101', 'entrance'],
      ];

      for (final route in routes) {
        final astarResult = astar.findShortestPath(graph, route[0], route[1]);
        final dijkstraResult = dijkstra.findShortestPath(graph, route[0], route[1]);

        expect(astarResult.found, equals(dijkstraResult.found),
            reason: 'Reachability mismatch for ${route[0]} → ${route[1]}');

        if (astarResult.found) {
          expect(
            (astarResult.totalDistance - dijkstraResult.totalDistance).abs(),
            lessThan(epsilon),
            reason: 'Distance mismatch for ${route[0]} → ${route[1]}: '
                'A*=${astarResult.totalDistance}, Dijkstra=${dijkstraResult.totalDistance}',
          );
        }
      }
    });

    // Synthetic graph comparison with nodesExplored
    test('Synthetic graph: A* explores <= Dijkstra nodes (admissible graph)', () {
      // Linear graph with correct coordinates: heuristic should help
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 10, y: 0),
        node('C', x: 20, y: 0),
        node('D', x: 30, y: 0),
        node('E', x: 40, y: 0),
        // Dead-end branch (away from goal)
        node('F', x: 0, y: 10),
        node('G', x: 0, y: 20),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 10.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 10.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 10.0));
      graph.addEdge(edge('e_de', 'D', 'E', distance: 10.0));
      // Dead-end branch
      graph.addEdge(edge('e_af', 'A', 'F', distance: 10.0));
      graph.addEdge(edge('e_fg', 'F', 'G', distance: 10.0));

      final astarResult = astar.findShortestPath(graph, 'A', 'E');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'E');

      expect(astarResult.found, isTrue);
      expect(dijkstraResult.found, isTrue);
      expect(
        (astarResult.totalDistance - dijkstraResult.totalDistance).abs(),
        lessThan(epsilon),
      );

      // A* should explore fewer or equal nodes due to heuristic guidance
      expect(astarResult.nodesExplored, lessThanOrEqualTo(dijkstraResult.nodesExplored),
          reason: 'A* explored ${astarResult.nodesExplored} vs '
              'Dijkstra ${dijkstraResult.nodesExplored}');
    });

    // Larger synthetic comparison
    test('Larger graph: A* and Dijkstra agree on distance (grid-like)', () {
      final graph = SpatialGraph();

      // 5x5 grid, each cell 10m apart
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 5; col++) {
          graph.addNode(node('n${row}_$col',
              x: col * 10.0, y: row * 10.0));
        }
      }
      // Horizontal edges
      for (var row = 0; row < 5; row++) {
        for (var col = 0; col < 4; col++) {
          final from = 'n${row}_$col';
          final to = 'n${row}_${col + 1}';
          graph.addEdge(edge('h_${row}_$col', from, to, distance: 10.0));
          graph.addEdge(edge('h_${row}_${col}_r', to, from, distance: 10.0));
        }
      }
      // Vertical edges
      for (var row = 0; row < 4; row++) {
        for (var col = 0; col < 5; col++) {
          final from = 'n${row}_$col';
          final to = 'n${row + 1}_$col';
          graph.addEdge(edge('v_${row}_$col', from, to, distance: 10.0));
          graph.addEdge(edge('v_${row}_${col}_r', to, from, distance: 10.0));
        }
      }

      // Route from top-left to bottom-right
      final astarResult = astar.findShortestPath(graph, 'n0_0', 'n4_4');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'n0_0', 'n4_4');

      expect(astarResult.found, isTrue);
      expect(dijkstraResult.found, isTrue);
      expect(
        (astarResult.totalDistance - dijkstraResult.totalDistance).abs(),
        lessThan(epsilon),
        reason: 'A* distance ${astarResult.totalDistance} must match '
            'Dijkstra ${dijkstraResult.totalDistance}',
      );

      // Both should find optimal = 80m (8 edges × 10m)
      expect(astarResult.totalDistance, closeTo(80.0, epsilon));
    });

    // Unreachable comparison
    test('Unreachable destination: A* and Dijkstra both return not found', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 20, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      final astarResult = astar.findShortestPath(graph, 'A', 'C');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'C');

      expect(astarResult.found, isFalse);
      expect(dijkstraResult.found, isFalse);
    });

    // start == destination comparison
    test('Start == destination: A* and Dijkstra both return same result', () {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      final astarResult = astar.findShortestPath(graph, 'A', 'A');
      final dijkstraResult = dijkstra.findShortestPath(graph, 'A', 'A');

      expect(astarResult.found, equals(dijkstraResult.found));
      expect(astarResult.pathNodeIds, equals(dijkstraResult.pathNodeIds));
      expect(astarResult.totalDistance, equals(dijkstraResult.totalDistance));
    });
  });
}
