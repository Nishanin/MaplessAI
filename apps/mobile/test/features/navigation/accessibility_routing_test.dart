import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/astar_engine.dart';
import 'package:mapless_ai/features/navigation/services/dijkstra_engine.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';
import 'package:mapless_ai/features/navigation/services/traversal_policy.dart';

void main() {
  const dijkstra = DijkstraEngine();
  const astar = AStarEngine();
  final service = PathfindingService();

  // ---------------------------------------------------------------------------
  // Helper loaders & builders
  // ---------------------------------------------------------------------------

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

  /// Builds a graph with two parallel routes:
  /// - Fast path: A -> S -> B (total 10m), but S or edge (A->S) can be stairs / inaccessible
  /// - Accessible/ramp path: A -> R -> B (total 25m), fully accessible
  SpatialGraph buildDualRouteGraph({
    bool fastEdgeAccessible = false,
    bool fastNodeAccessible = false,
    String fastNodeCategory = 'stairs',
    Map<String, dynamic>? fastEdgeMetadata,
    bool rampEdgeAccessible = true,
    bool rampNodeAccessible = true,
  }) {
    final nodes = [
      NodeModel(
        id: 'start',
        name: 'Start Node',
        category: 'corridor',
        floorId: 'floor-1',
        x: 0.0,
        y: 0.0,
        accessible: true,
      ),
      NodeModel(
        id: 'fast_mid',
        name: 'Fast Mid Node',
        category: fastNodeCategory,
        floorId: 'floor-1',
        x: 5.0,
        y: 0.0,
        accessible: fastNodeAccessible,
      ),
      NodeModel(
        id: 'ramp_mid',
        name: 'Ramp Mid Node',
        category: 'ramp',
        floorId: 'floor-1',
        x: 10.0,
        y: 10.0,
        accessible: rampNodeAccessible,
      ),
      NodeModel(
        id: 'dest',
        name: 'Destination Node',
        category: 'office',
        floorId: 'floor-1',
        x: 10.0,
        y: 0.0,
        accessible: true,
      ),
    ];

    final edges = [
      // Fast path: 5m + 5m = 10m
      EdgeModel(
        id: 'edge-start-fast',
        startNodeId: 'start',
        endNodeId: 'fast_mid',
        distance: 5.0,
        bearing: 90.0,
        accessible: fastEdgeAccessible,
        blocked: false,
        metadata: fastEdgeMetadata ?? const {},
      ),
      EdgeModel(
        id: 'edge-fast-dest',
        startNodeId: 'fast_mid',
        endNodeId: 'dest',
        distance: 5.0,
        bearing: 90.0,
        accessible: fastEdgeAccessible,
        blocked: false,
        metadata: fastEdgeMetadata ?? const {},
      ),
      // Ramp path: 12.5m + 12.5m = 25m
      EdgeModel(
        id: 'edge-start-ramp',
        startNodeId: 'start',
        endNodeId: 'ramp_mid',
        distance: 12.5,
        bearing: 45.0,
        accessible: rampEdgeAccessible,
        blocked: false,
        metadata: const {'connectorType': 'ramp'},
      ),
      EdgeModel(
        id: 'edge-ramp-dest',
        startNodeId: 'ramp_mid',
        endNodeId: 'dest',
        distance: 12.5,
        bearing: 135.0,
        accessible: rampEdgeAccessible,
        blocked: false,
        metadata: const {'connectorType': 'ramp'},
      ),
    ];

    return SpatialGraph.fromNodesAndEdges(nodes, edges, validate: true);
  }

  // ---------------------------------------------------------------------------
  // 1. Default routing behavior unchanged
  // ---------------------------------------------------------------------------
  group('1. Default routing behavior preserved', () {
    test('Default routing uses faster stair path when preferences are inactive', () {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: false,
        fastNodeAccessible: false,
        fastNodeCategory: 'stairs',
      );

      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'dest',
        preferences: const NavigationPreferencesModel(
          accessible: false,
          avoidStairs: false,
        ),
      );

      // TraversalPolicy default
      final policy = TraversalPolicy.fromPreferences(
        req.preferences,
        destinationNodeId: 'dest',
      );
      final dResult = dijkstra.findShortestPath(graph, 'start', 'dest', policy: policy);
      final aResult = astar.findShortestPath(graph, 'start', 'dest', policy: policy);

      expect(dResult.found, isTrue);
      expect(dResult.pathNodeIds, equals(['start', 'fast_mid', 'dest']));
      expect(dResult.totalDistance, equals(10.0));

      expect(aResult.found, isTrue);
      expect(aResult.pathNodeIds, equals(['start', 'fast_mid', 'dest']));
      expect(aResult.totalDistance, equals(10.0));
    });

    test('PathfindingService default preferences match engine default path', () async {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: false,
        fastNodeAccessible: false,
      );

      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'dest',
        // Default preferences has accessible: false, avoidStairs: false
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'fast_mid', 'dest']));
      expect(response.totalDistance, equals(10.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Accessible Routing (accessible == true)
  // ---------------------------------------------------------------------------
  group('2. Accessible routing (accessible == true)', () {
    test('Excludes inaccessible edge and selects accessible alternative', () {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: false, // Edge is inaccessible
        fastNodeAccessible: true,
      );

      final policy = const TraversalPolicy(
        accessible: true,
        destinationNodeId: 'dest',
      );

      final dResult = dijkstra.findShortestPath(graph, 'start', 'dest', policy: policy);
      final aResult = astar.findShortestPath(graph, 'start', 'dest', policy: policy);

      expect(dResult.found, isTrue);
      expect(dResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(dResult.totalDistance, equals(25.0));

      expect(aResult.found, isTrue);
      expect(aResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(aResult.totalDistance, equals(25.0));
    });

    test('Excludes inaccessible intermediate node and selects accessible alternative', () {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: true,
        fastNodeAccessible: false, // Node is inaccessible
      );

      final policy = const TraversalPolicy(
        accessible: true,
        destinationNodeId: 'dest',
      );

      final dResult = dijkstra.findShortestPath(graph, 'start', 'dest', policy: policy);
      final aResult = astar.findShortestPath(graph, 'start', 'dest', policy: policy);

      expect(dResult.found, isTrue);
      expect(dResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(dResult.totalDistance, equals(25.0));

      expect(aResult.found, isTrue);
      expect(aResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(aResult.totalDistance, equals(25.0));
    });

    test('Allows reaching destination endpoint even when destination node.accessible == false', () {
      // Endpoint is accessible == false, but connecting edge and intermediate nodes are accessible
      final nodes = [
        NodeModel(
          id: 'start',
          name: 'Start',
          category: 'corridor',
          floorId: 'f1',
          x: 0,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'corridor',
          name: 'Corridor',
          category: 'corridor',
          floorId: 'f1',
          x: 5,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'inaccessible_dest',
          name: 'Storage Room',
          category: 'storage',
          floorId: 'f1',
          x: 10,
          y: 0,
          accessible: false, // Destination itself marked false
        ),
      ];

      final edges = [
        EdgeModel(
          id: 'e1',
          startNodeId: 'start',
          endNodeId: 'corridor',
          distance: 5.0,
          bearing: 90.0,
          accessible: true,
          blocked: false,
        ),
        EdgeModel(
          id: 'e2',
          startNodeId: 'corridor',
          endNodeId: 'inaccessible_dest',
          distance: 5.0,
          bearing: 90.0,
          accessible: true, // Edge is accessible
          blocked: false,
        ),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final policy = const TraversalPolicy(
        accessible: true,
        destinationNodeId: 'inaccessible_dest',
      );

      final result = dijkstra.findShortestPath(graph, 'start', 'inaccessible_dest', policy: policy);
      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['start', 'corridor', 'inaccessible_dest']));
      expect(result.totalDistance, equals(10.0));
    });

    test('Allows initiating route from start endpoint when start node.accessible == false', () {
      final nodes = [
        NodeModel(
          id: 'start_inaccessible',
          name: 'Office',
          category: 'office',
          floorId: 'f1',
          x: 0,
          y: 0,
          accessible: false, // Start node marked false
        ),
        NodeModel(
          id: 'dest_accessible',
          name: 'Lobby',
          category: 'lobby',
          floorId: 'f1',
          x: 10,
          y: 0,
          accessible: true,
        ),
      ];

      final edges = [
        EdgeModel(
          id: 'e1',
          startNodeId: 'start_inaccessible',
          endNodeId: 'dest_accessible',
          distance: 10.0,
          bearing: 90.0,
          accessible: true,
          blocked: false,
        ),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final policy = const TraversalPolicy(
        accessible: true,
        destinationNodeId: 'dest_accessible',
      );

      final result = dijkstra.findShortestPath(graph, 'start_inaccessible', 'dest_accessible', policy: policy);
      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['start_inaccessible', 'dest_accessible']));
    });

    test('Returns noRoute when only route contains an inaccessible edge and accessible == true', () async {
      final nodes = [
        NodeModel(
          id: 'start',
          name: 'Start',
          category: 'corridor',
          floorId: 'f1',
          x: 0,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'dest',
          name: 'Dest',
          category: 'room',
          floorId: 'f1',
          x: 10,
          y: 0,
          accessible: true,
        ),
      ];

      final edges = [
        EdgeModel(
          id: 'e1',
          startNodeId: 'start',
          endNodeId: 'dest',
          distance: 10.0,
          bearing: 90.0,
          accessible: false, // inaccessble edge
          blocked: false,
        ),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'dest',
        preferences: const NavigationPreferencesModel(accessible: true),
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
      expect(response.pathNodeIds, isEmpty);
      expect(response.totalDistance, equals(0.0));
      expect(response.turnInstructions, isEmpty);
      expect(response.floorTransitions, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Stair Avoidance (avoidStairs == true)
  // ---------------------------------------------------------------------------
  group('3. Stair avoidance (avoidStairs == true)', () {
    test('Multi-floor routing avoids stairs in favor of elevator when avoidStairs == true', () async {
      final graph = loadVitTwoFloorsGraph();

      // vit_two_floors has:
      // stairs path: entrance -> corridor-f1 -> stairs-f1 -> stairs-f2 -> corridor-f2 -> lab-201 (75.0m)
      // lift path: entrance -> corridor-f1 -> lift-f1 -> lift-f2 -> corridor-f2 -> lab-201 (69.0m)
      // Let's modify edge distance so stairs is shorter: stairs-f1 -> stairs-f2 is 2.0m, lift is 30.0m
      final modifiedEdges = graph.allEdges.map((e) {
        if (e.id == 'edge-stairs1-stairs2') {
          return EdgeModel(
            id: e.id,
            startNodeId: e.startNodeId,
            endNodeId: e.endNodeId,
            distance: 2.0, // Shorter than lift
            bearing: e.bearing,
            accessible: true, // mark accessible so only avoidStairs affects it
            blocked: false,
            metadata: e.metadata,
          );
        }
        if (e.id == 'edge-lift1-lift2') {
          return EdgeModel(
            id: e.id,
            startNodeId: e.startNodeId,
            endNodeId: e.endNodeId,
            distance: 30.0, // Longer
            bearing: e.bearing,
            accessible: true,
            blocked: false,
            metadata: e.metadata,
          );
        }
        return e;
      }).toList();

      final customGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, modifiedEdges);

      // Without avoidStairs, stairs is chosen (shorter: 20 + 15 + 2 + 15 + 15 = 67m vs lift: 20 + 15 + 30 + 15 + 15 = 95m)
      final reqDefault = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(avoidStairs: false, accessible: false),
      );
      final resDefault = await service.computeRoute(customGraph, reqDefault);
      expect(resDefault.success, isTrue);
      expect(resDefault.pathNodeIds, contains('stairs-f1'));
      expect(resDefault.totalDistance, equals(67.0));

      // With avoidStairs == true, elevator is chosen despite longer distance
      final reqAvoidStairs = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(avoidStairs: true, accessible: false),
      );
      final resAvoid = await service.computeRoute(customGraph, reqAvoidStairs);
      expect(resAvoid.success, isTrue);
      expect(resAvoid.pathNodeIds, contains('lift-f1'));
      expect(resAvoid.pathNodeIds, contains('lift-f2'));
      expect(resAvoid.pathNodeIds, isNot(contains('stairs-f1')));
      expect(resAvoid.totalDistance, equals(95.0));
      expect(resAvoid.floorTransitions.single.viaType, equals('elevator'));
    });

    test('Same-floor routing avoids stairs in favor of ramp', () {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: true,
        fastNodeAccessible: true,
        fastNodeCategory: 'stairs',
      );

      final policy = const TraversalPolicy(
        avoidStairs: true,
        destinationNodeId: 'dest',
      );

      final dResult = dijkstra.findShortestPath(graph, 'start', 'dest', policy: policy);
      final aResult = astar.findShortestPath(graph, 'start', 'dest', policy: policy);

      expect(dResult.found, isTrue);
      expect(dResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(dResult.totalDistance, equals(25.0));

      expect(aResult.found, isTrue);
      expect(aResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(aResult.totalDistance, equals(25.0));
    });

    test('Avoids stairs based on edge connectorType metadata', () {
      final graph = buildDualRouteGraph(
        fastEdgeAccessible: true,
        fastNodeAccessible: true,
        fastNodeCategory: 'corridor', // node category is corridor, but edge metadata is stairs
        fastEdgeMetadata: const {'connectorType': 'stairs'},
      );

      final policy = const TraversalPolicy(
        avoidStairs: true,
        destinationNodeId: 'dest',
      );

      final dResult = dijkstra.findShortestPath(graph, 'start', 'dest', policy: policy);
      expect(dResult.pathNodeIds, equals(['start', 'ramp_mid', 'dest']));
      expect(dResult.totalDistance, equals(25.0));
    });

    test('Returns noRoute when only path uses stairs and avoidStairs == true', () async {
      final nodes = [
        NodeModel(
          id: 'f1_start',
          name: 'F1 Start',
          category: 'corridor',
          floorId: 'floor-1',
          x: 0,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'stairs_f1',
          name: 'Stairs F1',
          category: 'stairs',
          floorId: 'floor-1',
          x: 5,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'stairs_f2',
          name: 'Stairs F2',
          category: 'stairs',
          floorId: 'floor-2',
          x: 5,
          y: 0,
          accessible: true,
        ),
        NodeModel(
          id: 'f2_dest',
          name: 'F2 Dest',
          category: 'room',
          floorId: 'floor-2',
          x: 10,
          y: 0,
          accessible: true,
        ),
      ];

      final edges = [
        EdgeModel(
          id: 'e1',
          startNodeId: 'f1_start',
          endNodeId: 'stairs_f1',
          distance: 5.0,
          bearing: 90.0,
          accessible: true,
          blocked: false,
        ),
        EdgeModel(
          id: 'e2',
          startNodeId: 'stairs_f1',
          endNodeId: 'stairs_f2',
          distance: 5.0,
          bearing: 0.0,
          accessible: true,
          blocked: false,
          metadata: const {'connectorType': 'stairs'},
        ),
        EdgeModel(
          id: 'e3',
          startNodeId: 'stairs_f2',
          endNodeId: 'f2_dest',
          distance: 5.0,
          bearing: 90.0,
          accessible: true,
          blocked: false,
        ),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'f1_start',
        destinationNodeId: 'f2_dest',
        preferences: const NavigationPreferencesModel(avoidStairs: true),
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Combined preferences and blocked connectors
  // ---------------------------------------------------------------------------
  group('4. Combined preferences & blocked connectors', () {
    test('accessible == true and avoidStairs == true both satisfied on vit_two_floors', () async {
      final graph = loadVitTwoFloorsGraph();

      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(
          accessible: true,
          avoidStairs: true,
          avoidBlockedEdges: true,
        ),
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals([
        'entrance',
        'corridor-f1',
        'lift-f1',
        'lift-f2',
        'corridor-f2',
        'lab-201',
      ]));
      expect(response.totalDistance, equals(69.0));
      expect(response.floorTransitions.length, equals(1));
      expect(response.floorTransitions.first.viaType, equals('elevator'));
      expect(response.floorTransitions.first.fromFloorId, equals('floor-1'));
      expect(response.floorTransitions.first.toFloorId, equals('floor-2'));
      expect(response.floorTransitions.first.nodeId, equals('lift-f2'));
    });

    test('When elevator is blocked and stairs is inaccessible, returns noRoute for accessible preference', () async {
      final graph = loadVitTwoFloorsGraph();

      // Block the elevator edge
      final edgesWithBlockedLift = graph.allEdges.map((e) {
        if (e.id == 'edge-lift1-lift2') {
          return EdgeModel(
            id: e.id,
            startNodeId: e.startNodeId,
            endNodeId: e.endNodeId,
            distance: e.distance,
            bearing: e.bearing,
            accessible: e.accessible,
            blocked: true, // BLOCKED
            metadata: e.metadata,
          );
        }
        return e;
      }).toList();

      final blockedGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, edgesWithBlockedLift);

      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(
          accessible: true,
          avoidBlockedEdges: true,
        ),
      );

      final response = await service.computeRoute(blockedGraph, req);
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Dijkstra and A* equivalence under all policies
  // ---------------------------------------------------------------------------
  group('5. Dijkstra and A* equivalence', () {
    test('Both engines produce identical paths and distances across multiple policy permutations', () {
      final graph = loadVitTwoFloorsGraph();

      final policies = [
        const TraversalPolicy(accessible: false, avoidStairs: false, destinationNodeId: 'lab-201'),
        const TraversalPolicy(accessible: true, avoidStairs: false, destinationNodeId: 'lab-201'),
        const TraversalPolicy(accessible: false, avoidStairs: true, destinationNodeId: 'lab-201'),
        const TraversalPolicy(accessible: true, avoidStairs: true, destinationNodeId: 'lab-201'),
      ];

      for (final policy in policies) {
        final dResult = dijkstra.findShortestPath(graph, 'entrance', 'lab-201', policy: policy);
        final aResult = astar.findShortestPath(graph, 'entrance', 'lab-201', policy: policy);

        expect(dResult.found, equals(aResult.found));
        expect(dResult.pathNodeIds, equals(aResult.pathNodeIds));
        expect(dResult.pathEdgeIds, equals(aResult.pathEdgeIds));
        expect(dResult.totalDistance, equals(aResult.totalDistance));
      }
    });

    test('All 8 policy permutations (accessible x avoidStairs x skipBlocked) produce identical results between Dijkstra and A*', () {
      final graph = loadVitTwoFloorsGraph();

      for (final acc in [false, true]) {
        for (final avoid in [false, true]) {
          for (final skip in [false, true]) {
            final policy = TraversalPolicy(
              accessible: acc,
              avoidStairs: avoid,
              skipBlocked: skip,
              destinationNodeId: 'lab-201',
            );

            final dResult = dijkstra.findShortestPath(graph, 'entrance', 'lab-201', policy: policy);
            final aResult = astar.findShortestPath(graph, 'entrance', 'lab-201', policy: policy);

            expect(dResult.found, equals(aResult.found),
                reason: 'acc=$acc, avoid=$avoid, skip=$skip: found mismatch');
            expect(dResult.pathNodeIds, equals(aResult.pathNodeIds),
                reason: 'acc=$acc, avoid=$avoid, skip=$skip: path mismatch');
            expect(dResult.pathEdgeIds, equals(aResult.pathEdgeIds),
                reason: 'acc=$acc, avoid=$avoid, skip=$skip: edge mismatch');
            expect(dResult.totalDistance, equals(aResult.totalDistance),
                reason: 'acc=$acc, avoid=$avoid, skip=$skip: distance mismatch');
          }
        }
      }
    });

    test('A* heuristic admissibility check correctly ignores untraversable edges and remains active', () {
      // Build a graph where an INACCESSIBLE edge violates Euclidean distance
      // (edge.distance < euclidean), but all ACCESSIBLE edges satisfy it.
      final nodes = [
        NodeModel(id: 'A', name: 'A', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'B', name: 'B', category: 'corridor', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'C', name: 'C', category: 'corridor', floorId: 'f1', x: 20, y: 0, accessible: true),
        NodeModel(id: 'X', name: 'X', category: 'corridor', floorId: 'f1', x: 0, y: 20, accessible: true),
      ];

      final edges = [
        // Accessible valid route: A -> B -> C (10m + 10m = 20m)
        EdgeModel(id: 'e_ab', startNodeId: 'A', endNodeId: 'B', distance: 10.0, bearing: 90.0, accessible: true, blocked: false),
        EdgeModel(id: 'e_bc', startNodeId: 'B', endNodeId: 'C', distance: 10.0, bearing: 90.0, accessible: true, blocked: false),
        // Inaccessible edge with broken metric: A -> X has Euclidean 20m, but distance = 1m (inadmissible!)
        EdgeModel(id: 'e_ax', startNodeId: 'A', endNodeId: 'X', distance: 1.0, bearing: 0.0, accessible: false, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      // When accessible == false: the broken edge e_ax is checked -> heuristicActive falls back to false (h=0)
      final defaultPolicy = const TraversalPolicy(accessible: false, destinationNodeId: 'C');
      final aDefault = astar.findShortestPath(graph, 'A', 'C', policy: defaultPolicy);
      expect(aDefault.heuristicActive, isFalse);
      expect(aDefault.totalDistance, equals(20.0));

      // When accessible == true: the broken edge e_ax is excluded by policy -> heuristicActive remains TRUE!
      final accessiblePolicy = const TraversalPolicy(accessible: true, destinationNodeId: 'C');
      final aAccessible = astar.findShortestPath(graph, 'A', 'C', policy: accessiblePolicy);
      final dAccessible = dijkstra.findShortestPath(graph, 'A', 'C', policy: accessiblePolicy);

      expect(aAccessible.heuristicActive, isTrue); // Heuristic safely preserved!
      expect(aAccessible.found, isTrue);
      expect(aAccessible.pathNodeIds, equals(['A', 'B', 'C']));
      expect(aAccessible.totalDistance, equals(20.0));
      expect(aAccessible.totalDistance, equals(dAccessible.totalDistance));
    });

    test('A* safely falls back to h=0 when traversable edge violates Euclidean metric under accessibility', () {
      // Build a graph where a TRAVERSABLE accessible edge violates Euclidean distance
      final nodes = [
        NodeModel(id: 'A', name: 'A', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'B', name: 'B', category: 'corridor', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];

      final edges = [
        // Euclidean is 10m, but edge distance is 5m (metric violation on accessible edge)
        EdgeModel(id: 'e_ab', startNodeId: 'A', endNodeId: 'B', distance: 5.0, bearing: 90.0, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
      final policy = const TraversalPolicy(accessible: true, destinationNodeId: 'B');

      final aResult = astar.findShortestPath(graph, 'A', 'B', policy: policy);
      final dResult = dijkstra.findShortestPath(graph, 'A', 'B', policy: policy);

      expect(aResult.heuristicActive, isFalse); // Safe fallback to h=0
      expect(aResult.found, isTrue);
      expect(aResult.pathNodeIds, equals(['A', 'B']));
      expect(aResult.totalDistance, equals(5.0));
      expect(aResult.totalDistance, equals(dResult.totalDistance));
    });

    test('Both engines work identically via PathfindingService algorithm parameter', () async {
      final graph = loadVitTwoFloorsGraph();

      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(
          accessible: true,
          avoidStairs: true,
        ),
      );

      final dijkstraResp = await service.computeRoute(
        graph,
        req,
        algorithm: NavigationAlgorithm.dijkstra,
      );
      final astarResp = await service.computeRoute(
        graph,
        req,
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(dijkstraResp.success, isTrue);
      expect(astarResp.success, isTrue);
      expect(dijkstraResp.pathNodeIds, equals(astarResp.pathNodeIds));
      expect(dijkstraResp.edgeIds, equals(astarResp.edgeIds));
      expect(dijkstraResp.totalDistance, equals(astarResp.totalDistance));
      expect(dijkstraResp.estimatedTimeSeconds, equals(astarResp.estimatedTimeSeconds));
      expect(dijkstraResp.floorTransitions.length, equals(astarResp.floorTransitions.length));
      expect(dijkstraResp.turnInstructions.length, equals(astarResp.turnInstructions.length));
    });
  });
  // ---------------------------------------------------------------------------
  group('6. Zero Graph Mutation', () {
    test('Computing accessible routes leaves graph nodes, edges, and counts intact', () async {
      final graph = loadVitTwoFloorsGraph();

      final originalNodeCount = graph.nodeCount;
      final originalEdgeCount = graph.edgeCount;
      final originalEdges = List.of(graph.allEdges);
      final originalNodes = List.of(graph.allNodes);

      // Perform multiple routing queries with different preferences
      final req1 = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(accessible: true, avoidStairs: true),
      );
      final req2 = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(accessible: false, avoidStairs: false),
      );

      await service.computeRoute(graph, req1);
      await service.computeRoute(graph, req2);

      // Verify graph structure was completely unchanged
      expect(graph.nodeCount, equals(originalNodeCount));
      expect(graph.edgeCount, equals(originalEdgeCount));
      expect(graph.allEdges.length, equals(originalEdges.length));
      expect(graph.allNodes.length, equals(originalNodes.length));

      for (var i = 0; i < originalEdges.length; i++) {
        expect(graph.allEdges[i].id, equals(originalEdges[i].id));
        expect(graph.allEdges[i].accessible, equals(originalEdges[i].accessible));
        expect(graph.allEdges[i].blocked, equals(originalEdges[i].blocked));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Request Validation and Edge Cases
  // ---------------------------------------------------------------------------
  group('7. Request Validation and Edge Cases', () {
    test('Non-existent start node returns startNodeNotFound', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'missing-node',
        destinationNodeId: 'lab-201',
        preferences: const NavigationPreferencesModel(accessible: true),
      );

      final resp = await service.computeRoute(graph, req);
      expect(resp.success, isFalse);
      expect(resp.routeStatus, equals(RouteStatus.startNodeNotFound));
    });

    test('Non-existent destination node returns destinationNodeNotFound', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'missing-node',
        preferences: const NavigationPreferencesModel(accessible: true),
      );

      final resp = await service.computeRoute(graph, req);
      expect(resp.success, isFalse);
      expect(resp.routeStatus, equals(RouteStatus.destinationNodeNotFound));
    });

    test('Start node == destination node returns zero distance success', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'entrance',
        preferences: const NavigationPreferencesModel(accessible: true, avoidStairs: true),
      );

      final resp = await service.computeRoute(graph, req);
      expect(resp.success, isTrue);
      expect(resp.pathNodeIds, equals(['entrance']));
      expect(resp.totalDistance, equals(0.0));
      expect(resp.estimatedTimeSeconds, equals(0.0));
      expect(resp.floorTransitions, isEmpty);
      expect(resp.turnInstructions.length, equals(1));
      expect(resp.turnInstructions.first.instruction, contains('Arrive at'));
    });
  });
}
