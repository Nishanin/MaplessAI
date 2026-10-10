import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';

void main() {
  late PathfindingService service;

  setUp(() {
    service = PathfindingService();
  });

  // Helpers for graph construction
  NodeModel createNode(
    String id, {
    String? name,
    String category = 'corridor',
    String floorId = 'floor-1',
    double x = 0.0,
    double y = 0.0,
    bool accessible = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return NodeModel(
      id: id,
      name: name ?? 'Node $id',
      category: category,
      floorId: floorId,
      x: x,
      y: y,
      accessible: accessible,
      metadata: metadata,
    );
  }

  EdgeModel createEdge(
    String id,
    String startNodeId,
    String endNodeId, {
    double distance = 10.0,
    double bearing = 90.0,
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
    final candidates = [
      '../../test_data/vit_two_floors.json',
      '../test_data/vit_two_floors.json',
      'test_data/vit_two_floors.json',
      'assets/test_data/vit_two_floors.json',
    ];
    File? file;
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }
    expect(file, isNotNull, reason: 'vit_two_floors.json must exist');
    final data = jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;
    final nodes = (data['nodes'] as List<dynamic>)
        .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
        .toList();
    final edges = (data['edges'] as List<dynamic>)
        .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SpatialGraph.fromNodesAndEdges(nodes, edges);
  }

  SpatialGraph loadVitFloor1Graph() {
    final candidates = [
      '../../test_data/vit_floor_1.json',
      '../test_data/vit_floor_1.json',
      'test_data/vit_floor_1.json',
      'assets/test_data/vit_floor_1.json',
    ];
    File? file;
    for (final p in candidates) {
      final f = File(p);
      if (f.existsSync()) {
        file = f;
        break;
      }
    }
    expect(file, isNotNull, reason: 'vit_floor_1.json must exist');
    final data = jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;
    final nodes = (data['nodes'] as List<dynamic>)
        .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
        .toList();
    final edges = (data['edges'] as List<dynamic>)
        .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SpatialGraph.fromNodesAndEdges(nodes, edges);
  }

  group('Phase 11 — Navigation Engine Integration & Contract Readiness', () {
    // -------------------------------------------------------------------------
    // 1. Ordinary multi-floor route with valid connector metadata
    // -------------------------------------------------------------------------
    test(
      '1. Ordinary multi-floor route produces valid transitions and matches contract',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
        );

        final response = await service.computeRoute(graph, request);

        expect(response.success, isTrue);
        expect(response.routeStatus, equals(RouteStatus.success));
        expect(response.pathNodeIds.first, equals('entrance'));
        expect(response.pathNodeIds.last, equals('lab-201'));
        expect(response.totalDistance, greaterThan(0.0));
        expect(
          response.estimatedTimeSeconds,
          equals(response.totalDistance / 1.2),
        );
        expect(response.floorTransitions.length, equals(1));

        final transition = response.floorTransitions.first;
        expect(transition.fromFloorId, equals('floor-1'));
        expect(transition.toFloorId, equals('floor-2'));
        expect(['stairs', 'elevator', 'ramp'], contains(transition.viaType));

        // Serialization contract round-trip
        final json = response.toJson();
        expect(json['success'], isTrue);
        expect(json['routeStatus'], equals('success'));
        final deserialized = NavigationResponseModel.fromJson(json);
        expect(deserialized.totalDistance, equals(response.totalDistance));
        expect(deserialized.floorTransitions.length, equals(1));
      },
    );

    // -------------------------------------------------------------------------
    // 2. Accessibility-constrained route avoiding stairs
    // -------------------------------------------------------------------------
    test(
      '2. Accessibility-constrained route avoids stairs and uses elevator',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
          preferences: NavigationPreferencesModel(
            accessible: true,
            avoidStairs: true,
          ),
        );

        final response = await service.computeRoute(graph, request);

        expect(response.success, isTrue);
        expect(response.routeStatus, equals(RouteStatus.success));
        expect(response.floorTransitions.length, equals(1));
        expect(response.floorTransitions.first.viaType, equals('elevator'));
        expect(response.pathNodeIds, contains('lift-f1'));
        expect(response.pathNodeIds, contains('lift-f2'));
        expect(response.pathNodeIds, isNot(contains('stairs-f1')));
        expect(response.pathNodeIds, isNot(contains('stairs-f2')));

        // Verify all traversed nodes are accessible
        for (final nodeId in response.pathNodeIds) {
          expect(graph.getNode(nodeId)!.accessible, isTrue);
        }
      },
    );

    // -------------------------------------------------------------------------
    // 3. Blocked shortest path with a valid alternative
    // -------------------------------------------------------------------------
    test(
      '3. Blocked shortest path automatically routes via unblocked alternative',
      () async {
        final graph = SpatialGraph();
        // Path 1 (short, 10m): A -> B -> D (blocked)
        // Path 2 (longer, 25m): A -> C -> D (unblocked)
        graph.addNodes([
          createNode('a'),
          createNode('b'),
          createNode('c'),
          createNode('d'),
        ]);
        graph.addEdges([
          createEdge('e_ab', 'a', 'b', distance: 5.0),
          createEdge('e_bd', 'b', 'd', distance: 5.0, blocked: true), // blocked
          createEdge('e_ac', 'a', 'c', distance: 10.0),
          createEdge('e_cd', 'c', 'd', distance: 15.0),
        ]);

        final request = const NavigationRequestModel(
          buildingId: 'b1',
          startNodeId: 'a',
          destinationNodeId: 'd',
          preferences: NavigationPreferencesModel(avoidBlockedEdges: true),
        );

        final response = await service.computeRoute(graph, request);

        expect(response.success, isTrue);
        expect(response.pathNodeIds, equals(['a', 'c', 'd']));
        expect(response.edgeIds, equals(['e_ac', 'e_cd']));
        expect(response.totalDistance, equals(25.0));

        // computeAlternativeRoutes also skips the blocked edge
        final altResult = await service.computeAlternativeRoutes(
          graph,
          request,
          maxRoutes: 3,
        );
        expect(altResult.success, isTrue);
        expect(altResult.routes.length, equals(1));
        expect(altResult.routes.first.pathNodeIds, equals(['a', 'c', 'd']));
      },
    );

    // -------------------------------------------------------------------------
    // 4. Emergency routing selecting lowest-cost reachable designated exit
    // -------------------------------------------------------------------------
    test(
      '4. Emergency routing selects lowest graph path cost exit and skips blocked ones',
      () async {
        final graph = SpatialGraph();
        // Start node S at (0, 0)
        // Exit 1 at (10, 0): physical distance 50m (long detour)
        // Exit 2 at (100, 0): physical distance 20m (short path)
        final s = createNode('s', x: 0.0, y: 0.0);
        final mid1 = createNode('m1', x: 5.0, y: 0.0);
        final exit1 = createNode(
          'exit-1',
          category: 'emergency_exit',
          x: 10.0,
          y: 0.0,
        );
        final mid2 = createNode('m2', x: 50.0, y: 0.0);
        final exit2 = createNode(
          'exit-2',
          category: 'emergency_exit',
          x: 100.0,
          y: 0.0,
        );

        graph.addNodes([s, mid1, exit1, mid2, exit2]);
        graph.addEdges([
          createEdge('e_s_m1', 's', 'm1', distance: 25.0),
          createEdge(
            'e_m1_exit1',
            'm1',
            'exit-1',
            distance: 25.0,
          ), // Total to Exit 1: 50m
          createEdge('e_s_m2', 's', 'm2', distance: 10.0),
          createEdge(
            'e_m2_exit2',
            'm2',
            'exit-2',
            distance: 10.0,
          ), // Total to Exit 2: 20m
        ]);

        // Should choose Exit 2 because actual graph cost (20m) < Exit 1 (50m)
        final response1 = await service.computeEmergencyRoute(graph, 's');
        expect(response1.success, isTrue);
        expect(response1.pathNodeIds.last, equals('exit-2'));
        expect(response1.totalDistance, equals(20.0));

        // Now block Exit 2
        final blockedGraph = SpatialGraph();
        blockedGraph.addNodes([s, mid1, exit1, mid2, exit2]);
        blockedGraph.addEdges([
          createEdge('e_s_m1', 's', 'm1', distance: 25.0),
          createEdge('e_m1_exit1', 'm1', 'exit-1', distance: 25.0),
          createEdge('e_s_m2', 's', 'm2', distance: 10.0),
          createEdge(
            'e_m2_exit2',
            'm2',
            'exit-2',
            distance: 10.0,
            blocked: true,
          ), // Blocked
        ]);

        // Now should route to Exit 1
        final response2 = await service.computeEmergencyRoute(
          blockedGraph,
          's',
        );
        expect(response2.success, isTrue);
        expect(response2.pathNodeIds.last, equals('exit-1'));
        expect(response2.totalDistance, equals(50.0));
      },
    );

    // -------------------------------------------------------------------------
    // 5. Alternative routes on a multi-floor graph with consistent metrics
    // -------------------------------------------------------------------------
    test(
      '5. Multi-floor alternative routes produce consistent comparisons and transitions',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
        );

        final result = await service.computeAlternativeRoutes(
          graph,
          request,
          maxRoutes: 3,
        );

        expect(result.success, isTrue);
        expect(result.routes.length, greaterThanOrEqualTo(2));
        expect(result.comparisons.length, equals(result.routes.length));

        // Ascending distance order
        for (var i = 0; i < result.routes.length - 1; i++) {
          expect(
            result.routes[i].totalDistance,
            lessThanOrEqualTo(result.routes[i + 1].totalDistance),
          );
        }

        // Comparison deltas
        expect(result.comparisons.first.distanceDeltaFromPrimary, equals(0.0));
        expect(result.comparisons.first.timeDeltaFromPrimary, equals(0.0));
        expect(
          result.comparisons[1].distanceDeltaFromPrimary,
          greaterThanOrEqualTo(0.0),
        );

        // Every route has valid floor transitions
        for (final r in result.routes) {
          expect(r.floorTransitions.length, equals(1));
          expect(r.floorTransitions.first.toFloorId, equals('floor-2'));
        }
      },
    );

    // -------------------------------------------------------------------------
    // 6. No route under combined constraints
    // -------------------------------------------------------------------------
    test(
      '6. Combined constraints resulting in no route returns no_route status cleanly',
      () async {
        final graph = SpatialGraph();
        // Floor 1 -> Floor 2 connected ONLY by stairs
        final f1 = createNode('f1', floorId: 'floor-1', category: 'stairs');
        final f2 = createNode('f2', floorId: 'floor-2', category: 'stairs');
        graph.addNodes([f1, f2]);
        graph.addEdge(createEdge('e_stairs', 'f1', 'f2', distance: 10.0));

        // Request avoiding stairs
        final request = const NavigationRequestModel(
          buildingId: 'b1',
          startNodeId: 'f1',
          destinationNodeId: 'f2',
          preferences: NavigationPreferencesModel(avoidStairs: true),
        );

        final response = await service.computeRoute(graph, request);

        expect(response.success, isFalse);
        expect(response.routeStatus, equals(RouteStatus.noRoute));
        expect(response.pathNodeIds, isEmpty);
        expect(response.totalDistance, equals(0.0));
        expect(response.estimatedTimeSeconds, equals(0.0));
        expect(response.floorTransitions, isEmpty);
        expect(response.turnInstructions, isEmpty);

        final json = response.toJson();
        expect(json['success'], isFalse);
        expect(json['routeStatus'], equals('no_route'));
      },
    );

    // -------------------------------------------------------------------------
    // 7. Invalid start/destination requests
    // -------------------------------------------------------------------------
    test(
      '7. Missing start or destination node returns exact structured error status',
      () async {
        final graph = loadVitFloor1Graph();

        // Missing start node
        final missingStart = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'nonexistent-start',
          destinationNodeId: 'reception',
        );
        final r1 = await service.computeRoute(graph, missingStart);
        expect(r1.success, isFalse);
        expect(r1.routeStatus, equals(RouteStatus.startNodeNotFound));
        expect(r1.nodesExplored, equals(0));

        // Missing destination node
        final missingDest = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'reception',
          destinationNodeId: 'nonexistent-dest',
        );
        final r2 = await service.computeRoute(graph, missingDest);
        expect(r2.success, isFalse);
        expect(r2.routeStatus, equals(RouteStatus.destinationNodeNotFound));
        expect(r2.nodesExplored, equals(0));

        // computeAlternativeRoutes with missing nodes
        final altMissing = await service.computeAlternativeRoutes(
          graph,
          missingDest,
        );
        expect(altMissing.success, isFalse);
        expect(
          altMissing.routeStatus,
          equals(RouteStatus.destinationNodeNotFound),
        );
        expect(altMissing.routes, isEmpty);
      },
    );

    // -------------------------------------------------------------------------
    // 8. Start equals destination
    // -------------------------------------------------------------------------
    test(
      '8. Start equals destination returns trivial 0-distance success response',
      () async {
        final graph = loadVitFloor1Graph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'reception',
          destinationNodeId: 'reception',
        );

        final response = await service.computeRoute(graph, request);

        expect(response.success, isTrue);
        expect(response.routeStatus, equals(RouteStatus.success));
        expect(response.pathNodeIds, equals(['reception']));
        expect(response.edgeIds, isEmpty);
        expect(response.totalDistance, equals(0.0));
        expect(response.estimatedTimeSeconds, equals(0.0));
        expect(response.floorTransitions, isEmpty);
        expect(response.turnInstructions.length, equals(1));
        expect(
          response.turnInstructions.first.instruction.toLowerCase(),
          contains('arrive'),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 9. Graph validation warnings without unintended route rejection
    // -------------------------------------------------------------------------
    test(
      '9. Graph quality validation warnings do not block pathfinding execution',
      () async {
        final graph = SpatialGraph();
        // Add a valid path A -> B
        final a = createNode('a', x: 0.0, y: 0.0);
        final b = createNode('b', x: 10.0, y: 0.0);
        final edge = createEdge('e_ab', 'a', 'b', distance: 10.0);

        // Add a self-loop (triggers WARN_SELF_LOOP) and isolated node (triggers WARN_ISOLATED_NODE)
        final isolated = createNode('isolated');
        final loop = createEdge('e_loop', 'a', 'a', distance: 0.0);

        graph.addNodes([a, b, isolated]);
        graph.addEdges([edge, loop]);

        final validation = graph.validate();
        expect(
          validation.isValid,
          isTrue,
        ); // Warnings do not make graph invalid
        expect(validation.hasWarnings, isTrue);
        expect(validation.hasErrors, isFalse);

        // Route computation between A and B succeeds completely
        final request = const NavigationRequestModel(
          buildingId: 'b1',
          startNodeId: 'a',
          destinationNodeId: 'b',
        );
        final response = await service.computeRoute(graph, request);
        expect(response.success, isTrue);
        expect(response.pathNodeIds, equals(['a', 'b']));
        expect(response.totalDistance, equals(10.0));
      },
    );

    // -------------------------------------------------------------------------
    // 10. Consistent route metrics, ETA, and instructions across service APIs
    // -------------------------------------------------------------------------
    test(
      '10. Metric and instruction consistency across Dijkstra and A* and alternatives',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'corridor-f2',
        );

        final dijkstraResp = await service.computeRoute(
          graph,
          request,
          algorithm: NavigationAlgorithm.dijkstra,
        );
        final astarResp = await service.computeRoute(
          graph,
          request,
          algorithm: NavigationAlgorithm.aStar,
        );
        final altResp = await service.computeAlternativeRoutes(
          graph,
          request,
          maxRoutes: 2,
          algorithm: NavigationAlgorithm.dijkstra,
        );

        // Distances match exactly
        expect(dijkstraResp.totalDistance, equals(astarResp.totalDistance));
        expect(
          altResp.routes.first.totalDistance,
          equals(dijkstraResp.totalDistance),
        );

        // ETAs match exactly
        expect(
          dijkstraResp.estimatedTimeSeconds,
          equals(astarResp.estimatedTimeSeconds),
        );
        expect(
          altResp.routes.first.estimatedTimeSeconds,
          equals(dijkstraResp.estimatedTimeSeconds),
        );

        // Floor transitions match exactly
        expect(
          dijkstraResp.floorTransitions.length,
          equals(astarResp.floorTransitions.length),
        );
        expect(
          dijkstraResp.floorTransitions.first.viaType,
          equals(astarResp.floorTransitions.first.viaType),
        );

        // Turn instructions step count matches
        expect(
          dijkstraResp.turnInstructions.length,
          equals(astarResp.turnInstructions.length),
        );
      },
    );

    // -------------------------------------------------------------------------
    // 11. Deterministic output across repeated executions
    // -------------------------------------------------------------------------
    test(
      '11. Repeated executions return strictly identical responses',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
        );

        final baseline = await service.computeRoute(graph, request);

        for (var i = 0; i < 20; i++) {
          final current = await service.computeRoute(graph, request);
          expect(current.pathNodeIds, equals(baseline.pathNodeIds));
          expect(current.edgeIds, equals(baseline.edgeIds));
          expect(current.totalDistance, equals(baseline.totalDistance));
          expect(
            current.estimatedTimeSeconds,
            equals(baseline.estimatedTimeSeconds),
          );
          expect(
            current.floorTransitions.length,
            equals(baseline.floorTransitions.length),
          );
        }
      },
    );

    // -------------------------------------------------------------------------
    // 12. Graph immutability during route computation
    // -------------------------------------------------------------------------
    test(
      '12. Graph structure and edge states are completely immutable across routing calls',
      () async {
        final graph = loadVitTwoFloorsGraph();
        final nodeCountBefore = graph.nodeCount;
        final edgeCountBefore = graph.edgeCount;
        final outgoingBefore = graph.getOutgoingEdges('entrance').length;

        final request = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
          preferences: NavigationPreferencesModel(
            accessible: true,
            avoidStairs: true,
            avoidBlockedEdges: true,
          ),
        );

        // Run computeRoute, computeEmergencyRoute, computeAlternativeRoutes
        await service.computeRoute(graph, request);
        await service.computeEmergencyRoute(graph, 'entrance');
        await service.computeAlternativeRoutes(graph, request, maxRoutes: 3);

        expect(graph.nodeCount, equals(nodeCountBefore));
        expect(graph.edgeCount, equals(edgeCountBefore));
        expect(
          graph.getOutgoingEdges('entrance').length,
          equals(outgoingBefore),
        );
      },
    );
  });
}
