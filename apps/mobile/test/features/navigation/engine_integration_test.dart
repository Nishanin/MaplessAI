import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/models/alternative_routes_result.dart';
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

    // -------------------------------------------------------------------------
    // 13. Contract & Serialization Round-Trip: Success and Failure States
    // -------------------------------------------------------------------------
    test(
      '13. Full JSON round-trip serialization and deserialization across all RouteStatus values and AlternativeRoutesResult',
      () async {
        final graph = loadVitTwoFloorsGraph();

        // (a) Successful route round-trip
        final successReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'stairs-f1',
        );
        final successResp = await service.computeRoute(graph, successReq);
        expect(successResp.success, isTrue);
        expect(successResp.routeStatus, equals(RouteStatus.success));

        final successJson = successResp.toJson();
        expect(successJson['success'], isTrue);
        expect(successJson['pathNodeIds'], isNotEmpty);
        expect(successJson['routeStatus'], equals('success'));
        expect(successJson['algorithm'], equals('dijkstra'));

        final deserializedSuccess = NavigationResponseModel.fromJson(
          successJson,
        );
        expect(deserializedSuccess.success, isTrue);
        expect(deserializedSuccess.routeStatus, equals(RouteStatus.success));
        expect(
          deserializedSuccess.pathNodeIds,
          equals(successResp.pathNodeIds),
        );
        expect(
          deserializedSuccess.totalDistance,
          equals(successResp.totalDistance),
        );
        expect(
          deserializedSuccess.turnInstructions.length,
          equals(successResp.turnInstructions.length),
        );

        // (b) startNodeNotFound round-trip
        final missingStartReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'non-existent-start',
          destinationNodeId: 'stairs-f1',
        );
        final missingStartResp = await service.computeRoute(
          graph,
          missingStartReq,
        );
        expect(missingStartResp.success, isFalse);
        expect(
          missingStartResp.routeStatus,
          equals(RouteStatus.startNodeNotFound),
        );

        final missingStartJson = missingStartResp.toJson();
        expect(missingStartJson['success'], isFalse);
        expect(missingStartJson['routeStatus'], equals('start_node_not_found'));
        expect(missingStartJson['pathNodeIds'], isEmpty);
        expect(missingStartJson['turnInstructions'], isEmpty);

        final deserializedMissingStart = NavigationResponseModel.fromJson(
          missingStartJson,
        );
        expect(deserializedMissingStart.success, isFalse);
        expect(
          deserializedMissingStart.routeStatus,
          equals(RouteStatus.startNodeNotFound),
        );
        expect(
          deserializedMissingStart.message,
          contains('non-existent-start'),
        );

        // (c) destinationNodeNotFound round-trip
        final missingDestReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'non-existent-dest',
        );
        final missingDestResp = await service.computeRoute(
          graph,
          missingDestReq,
        );
        expect(missingDestResp.success, isFalse);
        expect(
          missingDestResp.routeStatus,
          equals(RouteStatus.destinationNodeNotFound),
        );

        final missingDestJson = missingDestResp.toJson();
        expect(
          missingDestJson['routeStatus'],
          equals('destination_node_not_found'),
        );
        final deserializedMissingDest = NavigationResponseModel.fromJson(
          missingDestJson,
        );
        expect(
          deserializedMissingDest.routeStatus,
          equals(RouteStatus.destinationNodeNotFound),
        );

        // (d) noRoute round-trip
        final isolatedGraph = SpatialGraph()
          ..addNode(createNode('iso-1'))
          ..addNode(createNode('iso-2'));
        final noRouteReq = const NavigationRequestModel(
          buildingId: 'test',
          startNodeId: 'iso-1',
          destinationNodeId: 'iso-2',
        );
        final noRouteResp = await service.computeRoute(
          isolatedGraph,
          noRouteReq,
        );
        expect(noRouteResp.success, isFalse);
        expect(noRouteResp.routeStatus, equals(RouteStatus.noRoute));

        final noRouteJson = noRouteResp.toJson();
        expect(noRouteJson['routeStatus'], equals('no_route'));
        final deserializedNoRoute = NavigationResponseModel.fromJson(
          noRouteJson,
        );
        expect(deserializedNoRoute.routeStatus, equals(RouteStatus.noRoute));

        // (e) invalidRequest round-trip (via synthetic NavigationResponseModel)
        const invalidResp = NavigationResponseModel(
          success: false,
          pathNodeIds: [],
          totalDistance: 0.0,
          estimatedTimeSeconds: 0.0,
          turnInstructions: [],
          routeStatus: RouteStatus.invalidRequest,
          message: 'Invalid navigation request parameter',
          algorithm: 'dijkstra',
        );
        final invalidJson = invalidResp.toJson();
        expect(invalidJson['routeStatus'], equals('invalid_request'));
        final deserializedInvalid = NavigationResponseModel.fromJson(
          invalidJson,
        );
        expect(
          deserializedInvalid.routeStatus,
          equals(RouteStatus.invalidRequest),
        );

        // (f) AlternativeRoutesResult success round-trip
        final multiReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'entrance',
          destinationNodeId: 'lab-201',
        );
        final altResult = await service.computeAlternativeRoutes(
          graph,
          multiReq,
          maxRoutes: 2,
        );
        expect(altResult.success, isTrue);
        expect(altResult.routes.length, greaterThanOrEqualTo(1));
        expect(altResult.comparisons.length, equals(altResult.routes.length));

        final altJson = altResult.toJson();
        expect(altJson['success'], isTrue);
        expect(altJson['routes'], isA<List>());
        expect(altJson['comparisons'], isA<List>());
        expect(altJson['routeStatus'], equals('success'));

        final deserializedAlt = AlternativeRoutesResult.fromJson(altJson);
        expect(deserializedAlt.success, isTrue);
        expect(deserializedAlt.routes.length, equals(altResult.routes.length));
        expect(
          deserializedAlt.comparisons.length,
          equals(altResult.comparisons.length),
        );
        expect(deserializedAlt.routeStatus, equals(RouteStatus.success));
        expect(
          deserializedAlt.comparisons.first.distanceDeltaFromPrimary,
          equals(0.0),
        );

        // (g) AlternativeRoutesResult failure round-trip (invalid maxRoutes)
        final badAltResult = await service.computeAlternativeRoutes(
          graph,
          multiReq,
          maxRoutes: 0,
        );
        expect(badAltResult.success, isFalse);
        expect(badAltResult.routeStatus, equals(RouteStatus.invalidRequest));

        final badAltJson = badAltResult.toJson();
        expect(badAltJson['success'], isFalse);
        expect(badAltJson['routeStatus'], equals('invalid_request'));

        final deserializedBadAlt = AlternativeRoutesResult.fromJson(badAltJson);
        expect(deserializedBadAlt.success, isFalse);
        expect(
          deserializedBadAlt.routeStatus,
          equals(RouteStatus.invalidRequest),
        );
        expect(deserializedBadAlt.message, contains('maxRoutes'));

        // (h) Emergency request model round-trip and dynamic exit routing via computeRoute
        final floor1Graph = loadVitFloor1Graph();
        final emergencyReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: 'reception',
          destinationNodeId: 'placeholder_exit',
          preferences: NavigationPreferencesModel(
            emergencyMode: true,
            avoidBlockedEdges: true,
          ),
        );

        final emergencyReqJson = emergencyReq.toJson();
        expect(emergencyReqJson['buildingId'], equals('vit-ce'));
        expect(emergencyReqJson['startNodeId'], equals('reception'));
        expect(
          emergencyReqJson['destinationNodeId'],
          equals('placeholder_exit'),
        );
        expect(emergencyReqJson['preferences']['emergencyMode'], isTrue);

        final deserializedEmergencyReq = NavigationRequestModel.fromJson(
          emergencyReqJson,
        );
        expect(deserializedEmergencyReq.buildingId, equals('vit-ce'));
        expect(deserializedEmergencyReq.startNodeId, equals('reception'));
        expect(
          deserializedEmergencyReq.destinationNodeId,
          equals('placeholder_exit'),
        );
        expect(deserializedEmergencyReq.preferences.emergencyMode, isTrue);

        // computeRoute ignores placeholder_exit and discovers exit-a
        final emergencyResp = await service.computeRoute(
          floor1Graph,
          deserializedEmergencyReq,
        );
        expect(emergencyResp.success, isTrue);
        expect(emergencyResp.routeStatus, equals(RouteStatus.success));
        expect(emergencyResp.pathNodeIds.first, equals('reception'));
        expect(emergencyResp.pathNodeIds.last, equals('exit-a'));
        expect(emergencyResp.totalDistance, greaterThan(0.0));

        final emergencyRespJson = emergencyResp.toJson();
        final deserializedEmergencyResp = NavigationResponseModel.fromJson(
          emergencyRespJson,
        );
        expect(deserializedEmergencyResp.success, isTrue);
        expect(deserializedEmergencyResp.pathNodeIds.last, equals('exit-a'));

        // (i) In emergencyMode, destinationNodeId is bypassed by the engine,
        // but startNodeId MUST be a real, existing node in the graph.
        // An empty or non-existent startNodeId is rejected with startNodeNotFound.
        final emptyStartEmergencyReq = const NavigationRequestModel(
          buildingId: 'vit-ce',
          startNodeId: '',
          destinationNodeId: 'emergency_exit',
          preferences: NavigationPreferencesModel(emergencyMode: true),
        );
        final emptyStartResp = await service.computeRoute(
          floor1Graph,
          emptyStartEmergencyReq,
        );
        expect(emptyStartResp.success, isFalse);
        expect(
          emptyStartResp.routeStatus,
          equals(RouteStatus.startNodeNotFound),
        );

        // (j) Exact public behavior when fields are null or absent in JSON:
        // When startNodeId is omitted or null in JSON, NavigationRequestModel.fromJson throws TypeError
        expect(
          () => NavigationRequestModel.fromJson({
            'buildingId': 'vit-ce',
            'destinationNodeId': 'exit-a',
            'preferences': {'emergencyMode': true},
          }),
          throwsA(isA<TypeError>()),
        );

        // When destinationNodeId is omitted or null in JSON, NavigationRequestModel.fromJson throws TypeError
        expect(
          () => NavigationRequestModel.fromJson({
            'buildingId': 'vit-ce',
            'startNodeId': 'reception',
            'preferences': {'emergencyMode': true},
          }),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });
}
