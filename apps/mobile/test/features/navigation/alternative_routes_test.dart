import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/models/alternative_routes_result.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';
import 'package:mapless_ai/features/navigation/services/traversal_policy.dart';
import 'package:mapless_ai/features/navigation/services/yen_algorithm_engine.dart';

void main() {
  final yenEngine = const YenAlgorithmEngine();
  final service = PathfindingService();

  NodeModel testNode({
    required String id,
    String? name,
    String category = 'corridor',
    String floorId = 'f1',
    double x = 0.0,
    double y = 0.0,
    bool accessible = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return NodeModel(
      id: id,
      name: name ?? id,
      category: category,
      floorId: floorId,
      x: x,
      y: y,
      accessible: accessible,
      metadata: metadata,
    );
  }

  EdgeModel testEdge({
    required String id,
    required String startNodeId,
    required String endNodeId,
    required double distance,
    double bearing = 0.0,
    bool accessible = true,
    bool blocked = false,
    Map<String, dynamic> metadata = const {},
  }) {
    return EdgeModel(
      id: id,
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      distance: distance,
      bearing: bearing,
      accessible: accessible,
      blocked: blocked,
      metadata: metadata,
    );
  }

  SpatialGraph loadVitTwoFloorsGraph() {
    final paths = [
      '../../test_data/vit_two_floors.json',
      'assets/test_data/vit_two_floors.json',
      'test_data/vit_two_floors.json',
    ];
    File? file;
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }
    if (file == null) {
      throw StateError('vit_two_floors.json not found in candidate paths: $paths');
    }
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final nodes = (data['nodes'] as List)
        .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
        .toList();
    final edges = (data['edges'] as List)
        .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SpatialGraph.fromNodesAndEdges(nodes, edges, validate: true);
  }

  group('Phase 9 — YenAlgorithmEngine Core Tests', () {
    // -------------------------------------------------------------------------
    // 1. Multiple distinct alternative routes ranked by cumulative distance
    // -------------------------------------------------------------------------
    test('1. Discovers up to K distinct routes ranked in ascending order of distance', () {
      // Graph topology with 3 distinct paths from A to D:
      // Path 1: A -> B -> D (10 + 10 = 20m)
      // Path 2: A -> C -> D (10 + 15 = 25m)
      // Path 3: A -> B -> C -> D (10 + 5 + 15 = 30m)
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 10, y: 10),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 45),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 315),
        testEdge(id: 'e_BC', startNodeId: 'B', endNodeId: 'C', distance: 5.0, bearing: 0),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 3);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(3));

      // Path 1 (Primary)
      expect(result.paths[0].nodeIds, equals(['A', 'B', 'D']));
      expect(result.paths[0].totalDistance, equals(20.0));

      // Path 2
      expect(result.paths[1].nodeIds, equals(['A', 'C', 'D']));
      expect(result.paths[1].totalDistance, equals(25.0));

      // Path 3
      expect(result.paths[2].nodeIds, equals(['A', 'B', 'C', 'D']));
      expect(result.paths[2].totalDistance, equals(30.0));

      // Strictly monotonically non-decreasing distance
      expect(result.paths[0].totalDistance <= result.paths[1].totalDistance, isTrue);
      expect(result.paths[1].totalDistance <= result.paths[2].totalDistance, isTrue);
    });

    // -------------------------------------------------------------------------
    // 2. Returns only available routes when graph has fewer than K paths
    // -------------------------------------------------------------------------
    test('2. Returns only available routes when graph contains fewer paths than requested K', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
      ];

      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'B', k: 4);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths.first.nodeIds, equals(['A', 'B']));
      expect(result.paths.first.totalDistance, equals(10.0));
    });

    // -------------------------------------------------------------------------
    // 3. Loopless path guarantee (no cycles, no repeating nodes)
    // -------------------------------------------------------------------------
    test('3. Guarantees every returned candidate path is strictly loopless (simple path)', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 10, y: 10),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BC', startNodeId: 'B', endNodeId: 'C', distance: 5.0, bearing: 0),
        testEdge(id: 'e_CB', startNodeId: 'C', endNodeId: 'B', distance: 5.0, bearing: 180), // cycle back to B
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 8.0, bearing: 315),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 5);

      expect(result.found, isTrue);
      for (final path in result.paths) {
        final uniqueNodes = path.nodeIds.toSet();
        expect(uniqueNodes.length, equals(path.nodeIds.length),
            reason: 'Path ${path.nodeIds} must not contain duplicate nodes');
      }
    });

    // -------------------------------------------------------------------------
    // 4. Safe deduplication across candidate pool and results
    // -------------------------------------------------------------------------
    test('4. Deduplicates candidates so no duplicate paths are returned', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 10, y: 10),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 45),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 315),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 5);

      final signatures = result.paths.map((p) => p.signature).toSet();
      expect(signatures.length, equals(result.paths.length),
          reason: 'All paths in result must have unique signatures');
    });

    // -------------------------------------------------------------------------
    // 5. Deterministic tie-breaking for equal-cost alternatives
    // -------------------------------------------------------------------------
    test('5. Tie-breaks equal-cost alternatives deterministically across repeated executions', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: -5),
        testNode(id: 'C', x: 10, y: 5),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 90),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 10.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final run1 = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 2);
      final run2 = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 2);

      expect(run1.paths.length, equals(2));
      expect(run2.paths.length, equals(2));

      expect(run1.paths[0].signature, equals(run2.paths[0].signature));
      expect(run1.paths[1].signature, equals(run2.paths[1].signature));
      expect(run1.paths[0].totalDistance, equals(20.0));
      expect(run1.paths[1].totalDistance, equals(20.0));
    });

    // -------------------------------------------------------------------------
    // 6. Graph immutability during Yen spur searches
    // -------------------------------------------------------------------------
    test('6. Preserves SpatialGraph immutability (zero mutation of nodes or edges)', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 10, y: 10),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 45),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 315),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final initialNodeCount = graph.nodeCount;
      final initialEdgeCount = graph.edgeCount;
      final initialEdgeBlockedStates = {for (final e in graph.allEdges) e.id: e.blocked};

      yenEngine.findKShortestPaths(graph, 'A', 'D', k: 3);

      expect(graph.nodeCount, equals(initialNodeCount));
      expect(graph.edgeCount, equals(initialEdgeCount));
      for (final e in graph.allEdges) {
        expect(e.blocked, equals(initialEdgeBlockedStates[e.id]));
      }
    });

    // -------------------------------------------------------------------------
    // 7. Bounds enforcement on K and argument errors
    // -------------------------------------------------------------------------
    test('7. Enforces bounds on K (throws ArgumentError for K < 1, clamps K > 5)', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
      ];
      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      expect(
        () => yenEngine.findKShortestPaths(graph, 'A', 'B', k: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => yenEngine.findKShortestPaths(graph, 'A', 'B', k: -2),
        throwsA(isA<ArgumentError>()),
      );

      final clamped = yenEngine.findKShortestPaths(graph, 'A', 'B', k: 10);
      expect(clamped.paths.length, equals(1));
    });

    // -------------------------------------------------------------------------
    // 8. Trivial start == destination
    // -------------------------------------------------------------------------
    test('8. Returns single trivial route when startNodeId == destinationNodeId', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const <EdgeModel>[]);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'A', k: 3);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths[0].nodeIds, equals(['A']));
      expect(result.paths[0].edgeIds, isEmpty);
      expect(result.paths[0].totalDistance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // 9. Unreachable destination handling
    // -------------------------------------------------------------------------
    test('9. Returns found == false and empty paths when destination is unreachable', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const <EdgeModel>[]);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'B', k: 3);

      expect(result.found, isFalse);
      expect(result.paths, isEmpty);
    });

    // -------------------------------------------------------------------------
    // 10. Missing node throws GraphException
    // -------------------------------------------------------------------------
    test('10. Throws GraphException when start or destination node does not exist', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const <EdgeModel>[]);

      expect(
        () => yenEngine.findKShortestPaths(graph, 'missing_start', 'A'),
        throwsA(isA<GraphException>()),
      );
      expect(
        () => yenEngine.findKShortestPaths(graph, 'A', 'missing_dest'),
        throwsA(isA<GraphException>()),
      );
    });
  });

  group('Phase 9 — TraversalPolicy Integration (Filtering & Preferences)', () {
    // -------------------------------------------------------------------------
    // 11. Blocked-edge exclusion across candidate routes
    // -------------------------------------------------------------------------
    test('11. Blocked edges are excluded from all candidate routes', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: -5),
        testNode(id: 'C', x: 10, y: 0),
        testNode(id: 'E', x: 10, y: 5),
        testNode(id: 'D', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90, blocked: true), // BLOCKED
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 90),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 90),
        testEdge(id: 'e_AE', startNodeId: 'A', endNodeId: 'E', distance: 10.0, bearing: 90),
        testEdge(id: 'e_ED', startNodeId: 'E', endNodeId: 'D', distance: 20.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final policy = const TraversalPolicy(skipBlocked: true, destinationNodeId: 'D');
      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 3, policy: policy);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(2));

      for (final path in result.paths) {
        expect(path.edgeIds.contains('e_BD'), isFalse,
            reason: 'Blocked edge e_BD must not be traversed by any candidate path');
      }
      expect(result.paths[0].nodeIds, equals(['A', 'C', 'D']));
      expect(result.paths[1].nodeIds, equals(['A', 'E', 'D']));
    });

    // -------------------------------------------------------------------------
    // 12. Wheelchair accessibility across candidate routes
    // -------------------------------------------------------------------------
    test('12. Accessible routing avoids inaccessible edges and intermediate nodes across alternatives', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0, accessible: true),
        testNode(id: 'B', x: 10, y: -5, accessible: false), // Inaccessible node
        testNode(id: 'C', x: 10, y: 0, accessible: true),
        testNode(id: 'E', x: 10, y: 5, accessible: true),
        testNode(id: 'D', x: 20, y: 0, accessible: true),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90, accessible: true),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 90, accessible: true),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 90, accessible: true),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 90, accessible: false), // Inaccessible edge
        testEdge(id: 'e_AE', startNodeId: 'A', endNodeId: 'E', distance: 10.0, bearing: 90, accessible: true),
        testEdge(id: 'e_ED', startNodeId: 'E', endNodeId: 'D', distance: 20.0, bearing: 90, accessible: true),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final policy = const TraversalPolicy(accessible: true, destinationNodeId: 'D');
      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 3, policy: policy);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths[0].nodeIds, equals(['A', 'E', 'D']));
      expect(result.paths[0].totalDistance, equals(30.0));
    });

    // -------------------------------------------------------------------------
    // 13. Stair avoidance across candidate routes
    // -------------------------------------------------------------------------
    test('13. Stair avoidance prioritizes elevator/ramp alternatives over stair paths', () {
      final nodes = [
        testNode(id: 'A', name: 'Start', x: 0, y: 0),
        testNode(id: 'S1', name: 'Stairs Landing F1', category: 'stairs', floorId: 'f1', x: 10, y: 0),
        testNode(id: 'S2', name: 'Stairs Landing F2', category: 'stairs', floorId: 'f2', x: 10, y: 0),
        testNode(id: 'E1', name: 'Elevator F1', category: 'elevator', floorId: 'f1', x: 15, y: 0),
        testNode(id: 'E2', name: 'Elevator F2', category: 'elevator', floorId: 'f2', x: 15, y: 0),
        testNode(id: 'D', name: 'Destination', floorId: 'f2', x: 25, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AS1', startNodeId: 'A', endNodeId: 'S1', distance: 10.0, bearing: 90),
        testEdge(id: 'e_S1S2', startNodeId: 'S1', endNodeId: 'S2', distance: 5.0, bearing: 0, metadata: {'viaType': 'stairs'}),
        testEdge(id: 'e_S2D', startNodeId: 'S2', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e_AE1', startNodeId: 'A', endNodeId: 'E1', distance: 15.0, bearing: 90),
        testEdge(id: 'e_E1E2', startNodeId: 'E1', endNodeId: 'E2', distance: 5.0, bearing: 0, metadata: {'viaType': 'elevator'}),
        testEdge(id: 'e_E2D', startNodeId: 'E2', endNodeId: 'D', distance: 15.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final defaultResult = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 2);
      expect(defaultResult.paths.length, equals(2));
      expect(defaultResult.paths[0].nodeIds, equals(['A', 'S1', 'S2', 'D']));
      expect(defaultResult.paths[1].nodeIds, equals(['A', 'E1', 'E2', 'D']));

      final avoidStairsPolicy = const TraversalPolicy(avoidStairs: true, destinationNodeId: 'D');
      final avoidedResult = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 2, policy: avoidStairsPolicy);
      expect(avoidedResult.paths.length, equals(1));
      expect(avoidedResult.paths[0].nodeIds, equals(['A', 'E1', 'E2', 'D']));
      expect(avoidedResult.paths[0].totalDistance, equals(35.0));
    });

    // -------------------------------------------------------------------------
    // 14. Directed edges strictly respected across all alternatives
    // -------------------------------------------------------------------------
    test('14. Strictly respects directed edge orientation (never traverses edges backward)', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 10, y: 10),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BC', startNodeId: 'B', endNodeId: 'C', distance: 10.0, bearing: 0),
        testEdge(id: 'e_CA', startNodeId: 'C', endNodeId: 'A', distance: 10.0, bearing: 225),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'B', 'A', k: 3);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(1));
      expect(result.paths[0].nodeIds, equals(['B', 'C', 'A']));
      expect(result.paths[0].totalDistance, equals(20.0));
    });
  });

  group('Phase 9 — PathfindingService Integration & Route Comparisons', () {
    // -------------------------------------------------------------------------
    // 15. Structured comparisons and delta calculations
    // -------------------------------------------------------------------------
    test('15. Generates structured RouteComparisonModel with accurate distance and time deltas', () async {
      final nodes = [
        testNode(id: 'A', name: 'Start', x: 0, y: 0),
        testNode(id: 'B', name: 'Branch 1', x: 10, y: -5),
        testNode(id: 'C', name: 'Branch 2', x: 10, y: 5),
        testNode(id: 'D', name: 'Destination', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 14.0, bearing: 90),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 15.0, bearing: 90),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 15.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = await service.findAlternativeRoutes(graph, 'A', 'D', maxRoutes: 3);

      expect(result.success, isTrue);
      expect(result.routeStatus, equals(RouteStatus.success));
      expect(result.routes.length, equals(2));
      expect(result.comparisons.length, equals(2));

      // Primary Route
      final comp0 = result.comparisons[0];
      expect(comp0.routeIndex, equals(0));
      expect(comp0.totalDistance, equals(24.0));
      expect(comp0.distanceDeltaFromPrimary, equals(0.0));
      expect(comp0.timeDeltaFromPrimary, equals(0.0));
      expect(comp0.pathNodeIds, equals(['A', 'B', 'D']));

      // Alternative Route 1
      final comp1 = result.comparisons[1];
      expect(comp1.routeIndex, equals(1));
      expect(comp1.totalDistance, equals(30.0));
      expect(comp1.distanceDeltaFromPrimary, equals(6.0));
      expect(comp1.timeDeltaFromPrimary, closeTo(6.0 / PathfindingService.walkingSpeedMetersPerSecond, 1e-4));
      expect(comp1.pathNodeIds, equals(['A', 'C', 'D']));

      // Verify serialization
      final json = result.toJson();
      expect(json['success'], isTrue);
      expect((json['routes'] as List).length, equals(2));
      expect((json['comparisons'] as List).length, equals(2));

      final deserialized = AlternativeRoutesResult.fromJson(json);
      expect(deserialized.success, isTrue);
      expect(deserialized.routes.length, equals(2));
      expect(deserialized.comparisons[1].distanceDeltaFromPrimary, equals(6.0));
    });

    // -------------------------------------------------------------------------
    // 16. Floor transitions preserved in alternative routes
    // -------------------------------------------------------------------------
    test('16. Accurately populates floorTransitions for multi-floor alternative routes', () async {
      final nodes = [
        testNode(id: 'A', name: 'Start', floorId: 'f1', x: 0, y: 0),
        testNode(id: 'E1', name: 'Elevator F1', category: 'elevator', floorId: 'f1', x: 10, y: 0),
        testNode(id: 'E2', name: 'Elevator F2', category: 'elevator', floorId: 'f2', x: 10, y: 0),
        testNode(id: 'S1', name: 'Stairs F1', category: 'stairs', floorId: 'f1', x: 10, y: 10),
        testNode(id: 'S2', name: 'Stairs F2', category: 'stairs', floorId: 'f2', x: 10, y: 10),
        testNode(id: 'D', name: 'Dest', floorId: 'f2', x: 20, y: 0),
      ];

      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'E1', distance: 10.0, bearing: 90),
        testEdge(id: 'e2', startNodeId: 'E1', endNodeId: 'E2', distance: 5.0, bearing: 0, metadata: {'viaType': 'elevator'}),
        testEdge(id: 'e3', startNodeId: 'E2', endNodeId: 'D', distance: 10.0, bearing: 90),
        testEdge(id: 'e4', startNodeId: 'A', endNodeId: 'S1', distance: 15.0, bearing: 45),
        testEdge(id: 'e5', startNodeId: 'S1', endNodeId: 'S2', distance: 5.0, bearing: 0, metadata: {'viaType': 'stairs'}),
        testEdge(id: 'e6', startNodeId: 'S2', endNodeId: 'D', distance: 15.0, bearing: 315),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = await service.findAlternativeRoutes(graph, 'A', 'D', maxRoutes: 2);

      expect(result.success, isTrue);
      expect(result.routes.length, equals(2));

      // Primary route via Elevator
      final r0 = result.routes[0];
      expect(r0.floorTransitions.length, equals(1));
      expect(r0.floorTransitions[0].viaType, equals('elevator'));
      expect(r0.floorTransitions[0].fromFloorId, equals('f1'));
      expect(r0.floorTransitions[0].toFloorId, equals('f2'));
      expect(r0.floorTransitions[0].nodeId, equals('E2'));

      // Alternative route via Stairs
      final r1 = result.routes[1];
      expect(r1.floorTransitions.length, equals(1));
      expect(r1.floorTransitions[0].viaType, equals('stairs'));
      expect(r1.floorTransitions[0].fromFloorId, equals('f1'));
      expect(r1.floorTransitions[0].toFloorId, equals('f2'));
      expect(r1.floorTransitions[0].nodeId, equals('S2'));
    });

    // -------------------------------------------------------------------------
    // 17. A* algorithm alternative route support
    // -------------------------------------------------------------------------
    test('17. Generates valid alternative routes using A* engine with Euclidean heuristic', () async {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 0, y: 10),
        testNode(id: 'D', x: 10, y: 10),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 0),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 0),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 10.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = await service.findAlternativeRoutes(
        graph,
        'A',
        'D',
        maxRoutes: 2,
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(result.success, isTrue);
      expect(result.routes.length, equals(2));
      expect(result.algorithm, equals('a_star'));
      expect(result.routes[0].algorithm, equals('a_star'));
      expect(result.routes[1].algorithm, equals('a_star'));
    });

    // -------------------------------------------------------------------------
    // 18. Missing start and destination node handling
    // -------------------------------------------------------------------------
    test('18. Returns structured startNodeNotFound and destinationNodeNotFound', () async {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const <EdgeModel>[]);

      final badStart = await service.findAlternativeRoutes(graph, 'bad_start', 'A');
      expect(badStart.success, isFalse);
      expect(badStart.routeStatus, equals(RouteStatus.startNodeNotFound));

      final badDest = await service.findAlternativeRoutes(graph, 'A', 'bad_dest');
      expect(badDest.success, isFalse);
      expect(badDest.routeStatus, equals(RouteStatus.destinationNodeNotFound));

      final badK = await service.findAlternativeRoutes(graph, 'A', 'A', maxRoutes: 0);
      expect(badK.success, isFalse);
      expect(badK.routeStatus, equals(RouteStatus.invalidRequest));
    });

    // -------------------------------------------------------------------------
    // 19. Turn instructions generated for all candidate routes
    // -------------------------------------------------------------------------
    test('19. Generates valid turn instructions for every candidate route', () async {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 0, y: 10),
        testNode(id: 'D', x: 10, y: 10),
      ];

      final edges = [
        testEdge(id: 'e_AB', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
        testEdge(id: 'e_BD', startNodeId: 'B', endNodeId: 'D', distance: 10.0, bearing: 0),
        testEdge(id: 'e_AC', startNodeId: 'A', endNodeId: 'C', distance: 10.0, bearing: 0),
        testEdge(id: 'e_CD', startNodeId: 'C', endNodeId: 'D', distance: 10.0, bearing: 90),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = await service.findAlternativeRoutes(graph, 'A', 'D', maxRoutes: 2);

      expect(result.success, isTrue);
      for (final route in result.routes) {
        expect(route.turnInstructions, isNotEmpty);
        expect(route.turnInstructions.last.instruction, contains('Arrive'));
      }
    });
  });

  group('Phase 9 — Real Dataset Verification (vit_two_floors.json)', () {
    // -------------------------------------------------------------------------
    // 20. Alternative routes on multi-floor VIT dataset
    // -------------------------------------------------------------------------
    test('20. Successfully computes alternative routes across floors on vit_two_floors.json', () async {
      final graph = loadVitTwoFloorsGraph();

      final startId = graph.allNodes.first.id;
      final destId = graph.allNodes.last.id;

      final stopwatch = Stopwatch()..start();
      final result = await service.findAlternativeRoutes(
        graph,
        startId,
        destId,
        maxRoutes: 3,
      );
      stopwatch.stop();

      // Report actual measured runtime without guessing
      // ignore: avoid_print
      print('VIT dataset 3-route execution time: ${stopwatch.elapsedMilliseconds} ms');

      expect(result.success, isTrue);
      expect(result.routes, isNotEmpty);
      expect(result.comparisons, isNotEmpty);
      expect(result.routes.first.totalDistance, greaterThan(0.0));

      // Each route is loopless
      for (final r in result.routes) {
        expect(r.pathNodeIds.toSet().length, equals(r.pathNodeIds.length));
      }

      // Ranked by distance
      for (var i = 0; i < result.routes.length - 1; i++) {
        expect(result.routes[i].totalDistance <= result.routes[i + 1].totalDistance, isTrue);
      }
    });
  });

  group('Phase 9 — Backward Compatibility Verification', () {
    // -------------------------------------------------------------------------
    // 21. Standard point-to-point computeRoute remains completely unchanged
    // -------------------------------------------------------------------------
    test('21. Ordinary computeRoute remains 100% backward-compatible and returns single route', () async {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
      ];
      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'A',
        destinationNodeId: 'B',
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['A', 'B']));
      expect(response.totalDistance, equals(10.0));
      expect(response.routeStatus, equals(RouteStatus.success));
    });

    // -------------------------------------------------------------------------
    // 22. Emergency routing remains completely unchanged
    // -------------------------------------------------------------------------
    test('22. Emergency routing via computeEmergencyRoute remains 100% functional', () async {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'Exit', category: 'emergency_exit', x: 10, y: 0),
      ];
      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'Exit', distance: 10.0, bearing: 90),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'A');
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['A', 'Exit']));
      expect(response.totalDistance, equals(10.0));
      expect(response.routeStatus, equals(RouteStatus.success));
    });
  });

  group('Phase 9 — Targeted Regression Tests (Audit Cases)', () {
    // -------------------------------------------------------------------------
    // 23. Alternatives with long shared prefix (3+ initial edges shared)
    // -------------------------------------------------------------------------
    test('23. Correctly generates alternatives that share a long multi-edge prefix', () {
      final nodes = [
        testNode(id: 'S', x: 0, y: 0),
        testNode(id: 'N1', x: 10, y: 0),
        testNode(id: 'N2', x: 20, y: 0),
        testNode(id: 'N3', x: 30, y: 0),
        testNode(id: 'BA', x: 40, y: -5),
        testNode(id: 'BB', x: 40, y: 0),
        testNode(id: 'BC', x: 40, y: 5),
        testNode(id: 'D', x: 50, y: 0),
      ];

      final edges = [
        testEdge(id: 'e_SN1', startNodeId: 'S', endNodeId: 'N1', distance: 10.0),
        testEdge(id: 'e_N1N2', startNodeId: 'N1', endNodeId: 'N2', distance: 10.0),
        testEdge(id: 'e_N2N3', startNodeId: 'N2', endNodeId: 'N3', distance: 10.0),
        testEdge(id: 'e_N3BA', startNodeId: 'N3', endNodeId: 'BA', distance: 10.0),
        testEdge(id: 'e_BAD', startNodeId: 'BA', endNodeId: 'D', distance: 10.0),
        testEdge(id: 'e_N3BB', startNodeId: 'N3', endNodeId: 'BB', distance: 10.0),
        testEdge(id: 'e_BBD', startNodeId: 'BB', endNodeId: 'D', distance: 15.0),
        testEdge(id: 'e_N3BC', startNodeId: 'N3', endNodeId: 'BC', distance: 10.0),
        testEdge(id: 'e_BCD', startNodeId: 'BC', endNodeId: 'D', distance: 20.0),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'S', 'D', k: 3);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(3));

      // All 3 paths must share the initial 3 edges (e_SN1, e_N1N2, e_N2N3)
      for (final p in result.paths) {
        expect(p.nodeIds.sublist(0, 4), equals(['S', 'N1', 'N2', 'N3']));
        expect(p.edgeIds.sublist(0, 3), equals(['e_SN1', 'e_N1N2', 'e_N2N3']));
      }

      expect(result.paths[0].nodeIds, equals(['S', 'N1', 'N2', 'N3', 'BA', 'D']));
      expect(result.paths[0].totalDistance, equals(50.0));
      expect(result.paths[1].nodeIds, equals(['S', 'N1', 'N2', 'N3', 'BB', 'D']));
      expect(result.paths[1].totalDistance, equals(55.0));
      expect(result.paths[2].nodeIds, equals(['S', 'N1', 'N2', 'N3', 'BC', 'D']));
      expect(result.paths[2].totalDistance, equals(60.0));
    });

    // -------------------------------------------------------------------------
    // 24. Parallel edges with identical node sequences
    // -------------------------------------------------------------------------
    test('24. Handles parallel directed edges connecting identical node sequences with deterministic tie-breaking', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
      ];

      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'B', distance: 10.0),
        testEdge(id: 'e2', startNodeId: 'A', endNodeId: 'B', distance: 10.0),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'B', k: 2);

      expect(result.found, isTrue);
      expect(result.paths.length, equals(2));

      // Both paths have node sequence [A, B]
      expect(result.paths[0].nodeIds, equals(['A', 'B']));
      expect(result.paths[1].nodeIds, equals(['A', 'B']));

      // Distinct edge sequences
      expect(result.paths[0].edgeIds, equals(['e1']));
      expect(result.paths[1].edgeIds, equals(['e2']));

      // Deterministic tie-breaking orders e1 before e2
      expect(result.paths[0].signature, equals('A->B|e1'));
      expect(result.paths[1].signature, equals('A->B|e2'));
    });

    // -------------------------------------------------------------------------
    // 25. Candidate costs strictly match recomputed cumulative edge distance
    // -------------------------------------------------------------------------
    test('25. Returned candidate costs strictly match recomputed cumulative edge distances without drift', () {
      final nodes = [
        testNode(id: 'A', x: 0, y: 0),
        testNode(id: 'B', x: 10, y: 0),
        testNode(id: 'C', x: 20, y: 0),
        testNode(id: 'D', x: 30, y: 0),
      ];

      final edges = [
        testEdge(id: 'e1', startNodeId: 'A', endNodeId: 'B', distance: 10.333333),
        testEdge(id: 'e2', startNodeId: 'B', endNodeId: 'C', distance: 20.666667),
        testEdge(id: 'e3', startNodeId: 'C', endNodeId: 'D', distance: 30.123456),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final result = yenEngine.findKShortestPaths(graph, 'A', 'D', k: 1);

      expect(result.found, isTrue);
      final path = result.paths.first;

      double directSum = 0.0;
      for (final edgeId in path.edgeIds) {
        directSum += graph.getEdge(edgeId)!.distance;
      }

      expect(path.totalDistance, equals(directSum));
    });
  });
}
