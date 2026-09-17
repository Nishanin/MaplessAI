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
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
    bool blocked = false,
  }) {
    return EdgeModel(
      id: id,
      startNodeId: from,
      endNodeId: to,
      distance: distance,
      bearing: 90.0,
      accessible: true,
      blocked: blocked,
    );
  }

  NavigationRequestModel request(String from, String to, {bool avoidBlocked = true}) {
    return NavigationRequestModel(
      buildingId: 'test-building',
      startNodeId: from,
      destinationNodeId: to,
      preferences: NavigationPreferencesModel(avoidBlockedEdges: avoidBlocked),
    );
  }

  final service = PathfindingService();

  // ---------------------------------------------------------------------------
  // Shared VIT graph loader
  // ---------------------------------------------------------------------------
  SpatialGraph loadVitGraph() {
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
    if (file == null) throw StateError('vit_floor_1.json not found');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final nodes = (data['nodes'] as List)
        .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
        .toList();
    final edges = (data['edges'] as List)
        .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return SpatialGraph.fromNodesAndEdges(nodes, edges);
  }

  // ---------------------------------------------------------------------------
  // 1. Successful Dijkstra response
  // ---------------------------------------------------------------------------
  group('PathfindingService — NavigationResponse Tests', () {
    test('1. Successful Dijkstra response has correct structure', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 10, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 10.0));

      final resp = await service.computeRoute(
        graph,
        request('A', 'B'),
        algorithm: NavigationAlgorithm.dijkstra,
      );

      expect(resp.success, isTrue);
      expect(resp.algorithm, equals('dijkstra'));
      expect(resp.routeStatus, equals(RouteStatus.success));
      expect(resp.pathNodeIds, equals(['A', 'B']));
      expect(resp.edgeIds, equals(['e_ab']));
      expect(resp.totalDistance, equals(10.0));
    });

    // 2. Successful A* response
    test('2. Successful A* response has correct structure', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 10, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 10.0));

      final resp = await service.computeRoute(
        graph,
        request('A', 'B'),
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(resp.success, isTrue);
      expect(resp.algorithm, equals('a_star'));
      expect(resp.routeStatus, equals(RouteStatus.success));
      expect(resp.pathNodeIds, equals(['A', 'B']));
      expect(resp.edgeIds, equals(['e_ab']));
      expect(resp.totalDistance, equals(10.0));
    });

    // 3. Correct ordered node IDs
    test('3. Response contains correct ordered node IDs', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final resp = await service.computeRoute(graph, request('A', 'C'));

      expect(resp.pathNodeIds, equals(['A', 'B', 'C']));
      expect(resp.pathNodeIds.first, equals('A'));
      expect(resp.pathNodeIds.last, equals('C'));
    });

    // 4. Correct ordered edge IDs
    test('4. Response contains correct ordered edge IDs', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final resp = await service.computeRoute(graph, request('A', 'C'));

      expect(resp.edgeIds, equals(['e_ab', 'e_bc']));
      expect(resp.edgeIds.length, equals(resp.pathNodeIds.length - 1));
    });

    // 5. Total distance equals edge sum
    test('5. Response total distance equals sum of traversed edge distances', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 7, y: 0),
        node('C', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 7.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 3.0));

      final resp = await service.computeRoute(graph, request('A', 'C'));

      expect(resp.totalDistance, equals(10.0));

      // Verify directly against edge sum
      double sum = 0;
      for (final id in resp.edgeIds) {
        sum += graph.getEdge(id)!.distance;
      }
      expect(resp.totalDistance, closeTo(sum, 1e-9));
    });

    // 6. ETA is calculated correctly
    test('6. ETA = totalDistance / 1.2 m/s', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 12, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 12.0));

      final resp = await service.computeRoute(graph, request('A', 'B'));

      expect(resp.estimatedTimeSeconds, closeTo(10.0, 1e-9));
      expect(
        resp.estimatedTimeSeconds,
        closeTo(resp.totalDistance / PathfindingService.walkingSpeedMetersPerSecond, 1e-9),
      );
    });

    // 7. Response reports nodesExplored
    test('7. Response reports nodesExplored > 0 for non-trivial route', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));

      final resp = await service.computeRoute(graph, request('A', 'C'));

      expect(resp.nodesExplored, greaterThan(0));
    });

    // 8. Response reports correct algorithm
    test('8a. Dijkstra algorithm label', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      final resp = await service.computeRoute(
        graph,
        request('A', 'B'),
        algorithm: NavigationAlgorithm.dijkstra,
      );
      expect(resp.algorithm, equals('dijkstra'));
    });

    test('8b. A* algorithm label', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      final resp = await service.computeRoute(
        graph,
        request('A', 'B'),
        algorithm: NavigationAlgorithm.aStar,
      );
      expect(resp.algorithm, equals('a_star'));
    });

    // 9. start == destination
    test('9. Start equals destination: success, single node, zero ETA', () async {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      final resp = await service.computeRoute(graph, request('A', 'A'));

      expect(resp.success, isTrue);
      expect(resp.routeStatus, equals(RouteStatus.success));
      expect(resp.pathNodeIds, equals(['A']));
      expect(resp.edgeIds, isEmpty);
      expect(resp.totalDistance, equals(0.0));
      expect(resp.estimatedTimeSeconds, equals(0.0));
    });

    // 10. NO_ROUTE
    test('10. No route: success=false, routeStatus=noRoute, no path', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      // No edge connecting A to B

      final resp = await service.computeRoute(graph, request('A', 'B'));

      expect(resp.success, isFalse);
      expect(resp.routeStatus, equals(RouteStatus.noRoute));
      expect(resp.pathNodeIds, isEmpty);
      expect(resp.edgeIds, isEmpty);
      expect(resp.totalDistance, equals(0.0));
      expect(resp.estimatedTimeSeconds, equals(0.0));
    });

    // 11. Missing start node
    test('11. Missing start node: success=false, routeStatus=startNodeNotFound', () async {
      final graph = SpatialGraph();
      graph.addNode(node('B'));

      final resp = await service.computeRoute(graph, request('ghost', 'B'));

      expect(resp.success, isFalse);
      expect(resp.routeStatus, equals(RouteStatus.startNodeNotFound));
      expect(resp.pathNodeIds, isEmpty);
      expect(resp.nodesExplored, equals(0));
    });

    // 12. Missing destination node
    test('12. Missing destination node: success=false, routeStatus=destinationNodeNotFound',
        () async {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      final resp = await service.computeRoute(graph, request('A', 'ghost'));

      expect(resp.success, isFalse);
      expect(resp.routeStatus, equals(RouteStatus.destinationNodeNotFound));
      expect(resp.pathNodeIds, isEmpty);
      expect(resp.nodesExplored, equals(0));
    });

    // 13. Blocked edges
    test('13. Blocked edge is skipped; service routes around it', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 3, y: 4),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 1.0, blocked: true));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 3.0));
      graph.addEdge(edge('e_cb', 'C', 'B', distance: 3.0));

      final resp = await service.computeRoute(graph, request('A', 'B'));

      expect(resp.success, isTrue);
      expect(resp.pathNodeIds, equals(['A', 'C', 'B']));
      expect(resp.totalDistance, equals(6.0));
      // Blocked edge must not appear in the path
      expect(resp.edgeIds, isNot(contains('e_ab')));
    });

    // 14. Multiple alternative routes — service selects shortest
    test('14. Multiple routes: shortest is selected', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 5, y: 0),
        node('C', x: 10, y: 0),
        node('D', x: 15, y: 0),
      ]);
      graph.addEdge(edge('e_ad', 'A', 'D', distance: 50.0));
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 5.0));

      final resp = await service.computeRoute(graph, request('A', 'D'));

      expect(resp.success, isTrue);
      expect(resp.totalDistance, equals(15.0));
      expect(resp.pathNodeIds, equals(['A', 'B', 'C', 'D']));
    });

    // 15. Dijkstra determinism
    test('15. Dijkstra response is deterministic across runs', () async {
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

      final first = await service.computeRoute(
        graph,
        request('A', 'D'),
        algorithm: NavigationAlgorithm.dijkstra,
      );
      for (var i = 0; i < 20; i++) {
        final r = await service.computeRoute(
          graph,
          request('A', 'D'),
          algorithm: NavigationAlgorithm.dijkstra,
        );
        expect(r.pathNodeIds, equals(first.pathNodeIds), reason: 'Run $i diverged');
        expect(r.totalDistance, equals(first.totalDistance), reason: 'Run $i diverged');
      }
    });

    // 16. A* determinism
    test('16. A* response is deterministic across runs', () async {
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

      final first = await service.computeRoute(
        graph,
        request('A', 'D'),
        algorithm: NavigationAlgorithm.aStar,
      );
      for (var i = 0; i < 20; i++) {
        final r = await service.computeRoute(
          graph,
          request('A', 'D'),
          algorithm: NavigationAlgorithm.aStar,
        );
        expect(r.pathNodeIds, equals(first.pathNodeIds), reason: 'Run $i diverged');
        expect(r.totalDistance, equals(first.totalDistance), reason: 'Run $i diverged');
      }
    });

    // 17. A* and Dijkstra produce same optimal distance
    test('17. A* and Dijkstra produce same optimal distance', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 3, y: 4),
        node('C', x: 6, y: 0),
        node('D', x: 10, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      graph.addEdge(edge('e_ac', 'A', 'C', distance: 6.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 5.0));
      graph.addEdge(edge('e_cd', 'C', 'D', distance: 4.0));
      graph.addEdge(edge('e_bd', 'B', 'D', distance: 9.0));

      final dResp = await service.computeRoute(
        graph,
        request('A', 'D'),
        algorithm: NavigationAlgorithm.dijkstra,
      );
      final aResp = await service.computeRoute(
        graph,
        request('A', 'D'),
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(dResp.success, isTrue);
      expect(aResp.success, isTrue);
      expect(
        (dResp.totalDistance - aResp.totalDistance).abs(),
        lessThan(1e-9),
        reason: 'Dijkstra=${dResp.totalDistance}, A*=${aResp.totalDistance}',
      );
    });

    // 18. Invalid engine result is NOT returned as success
    // (The path validator throws GraphException for internally inconsistent results)
    // We test this via a mock-like approach: we can't inject a bad engine result
    // through the service's public API without a real engine defect, so we verify
    // the validation logic with a unit-level call to the internal helper indirectly
    // by constructing a scenario that would produce inconsistency.
    // Instead, verify that a legitimate route never produces an inconsistent
    // response (the validator passed silently).
    test('18. Valid engine result passes path validation (no exception)', () async {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', x: 0, y: 0),
        node('B', x: 10, y: 0),
        node('C', x: 20, y: 0),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 10.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 10.0));

      // Must not throw — path validation should pass
      final resp = await service.computeRoute(graph, request('A', 'C'));
      expect(resp.success, isTrue);
      expect(resp.routeStatus, equals(RouteStatus.success));
    });

    // 19. No fabricated path
    test('19. No fabricated path for disconnected destination', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));
      // C is disconnected

      final resp = await service.computeRoute(graph, request('A', 'C'));

      expect(resp.success, isFalse);
      expect(resp.pathNodeIds, isEmpty);
      expect(resp.edgeIds, isEmpty);
      expect(resp.totalDistance, equals(0.0));
    });

    // 20. VIT graph route
    test('20. VIT graph: entrance → lab-101 route is correct', () async {
      final graph = loadVitGraph();

      final resp = await service.computeRoute(graph, request('entrance', 'lab-101'));

      expect(resp.success, isTrue);
      expect(resp.pathNodeIds, equals(['entrance', 'reception', 'corridor', 'lab-101']));
      expect(resp.totalDistance, closeTo(40.0, 1e-9));
      expect(resp.edgeIds.length, equals(3));
      expect(resp.routeStatus, equals(RouteStatus.success));
    });

    // 21. Response serialization matches shared contract
    test('21. Response serialization round-trips correctly', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A', x: 0, y: 0), node('B', x: 12, y: 0)]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 12.0));

      final resp = await service.computeRoute(graph, request('A', 'B'));
      final json = resp.toJson();

      // Required contract fields
      expect(json.containsKey('success'), isTrue);
      expect(json.containsKey('pathNodeIds'), isTrue);
      expect(json.containsKey('totalDistance'), isTrue);
      expect(json.containsKey('estimatedTimeSeconds'), isTrue);
      expect(json.containsKey('turnInstructions'), isTrue);

      // Phase 4 fields
      expect(json.containsKey('algorithm'), isTrue);
      expect(json.containsKey('nodesExplored'), isTrue);
      expect(json.containsKey('routeStatus'), isTrue);

      // Values are the right types
      expect(json['success'], isA<bool>());
      expect(json['pathNodeIds'], isA<List>());
      expect(json['totalDistance'], isA<double>());
      expect(json['estimatedTimeSeconds'], isA<double>());
      expect(json['algorithm'], isA<String>());
      expect(json['nodesExplored'], isA<int>());
      expect(json['routeStatus'], isA<String>());

      // Round-trip fromJson → toJson
      final restored = NavigationResponseModel.fromJson(json);
      expect(restored.success, equals(resp.success));
      expect(restored.pathNodeIds, equals(resp.pathNodeIds));
      expect(restored.totalDistance, equals(resp.totalDistance));
      expect(restored.algorithm, equals(resp.algorithm));
      expect(restored.nodesExplored, equals(resp.nodesExplored));
      expect(restored.routeStatus, equals(resp.routeStatus));
    });

    // 22. Default algorithm is Dijkstra (backward compatibility)
    test('22. Default algorithm is dijkstra (backward compatible callers)', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      // Call without specifying algorithm — must default to Dijkstra
      final resp = await service.computeRoute(graph, request('A', 'B'));

      expect(resp.success, isTrue);
      expect(resp.algorithm, equals('dijkstra'));
    });

    // 23. A* tests still pass (Phase 3 regression)
    test('23. Phase 3 A* correctness: VIT graph A* distance matches Dijkstra', () async {
      final graph = loadVitGraph();

      final dijResp = await service.computeRoute(
        graph,
        request('entrance', 'lab-101'),
        algorithm: NavigationAlgorithm.dijkstra,
      );
      final astarResp = await service.computeRoute(
        graph,
        request('entrance', 'lab-101'),
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(dijResp.success, isTrue);
      expect(astarResp.success, isTrue);
      expect(
        (dijResp.totalDistance - astarResp.totalDistance).abs(),
        lessThan(1e-9),
      );
    });

    // Extra: nodesExplored is 0 for start == destination
    test('Extra: nodesExplored = 0 for start == destination', () async {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      final respD = await service.computeRoute(
        graph,
        request('A', 'A'),
        algorithm: NavigationAlgorithm.dijkstra,
      );
      final respA = await service.computeRoute(
        graph,
        request('A', 'A'),
        algorithm: NavigationAlgorithm.aStar,
      );
      expect(respD.nodesExplored, equals(0));
      expect(respA.nodesExplored, equals(0));
    });

    // Extra: nodesExplored included in no-route response
    test('Extra: nodesExplored is included even in no-route response', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 5.0));

      final resp = await service.computeRoute(graph, request('A', 'C'));
      // nodesExplored may be > 0 (engine explored some nodes before giving up)
      expect(resp.nodesExplored, isNonNegative);
    });

    // Extra: RouteStatus serialization round-trip
    test('Extra: RouteStatus serializes and deserializes correctly', () async {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);

      final resp = await service.computeRoute(graph, request('A', 'B'));
      final json = resp.toJson();

      expect(json['routeStatus'], equals('no_route'));
      final restored = NavigationResponseModel.fromJson(json);
      expect(restored.routeStatus, equals(RouteStatus.noRoute));
    });

    // Extra: ETA is zero for start == destination
    test('Extra: ETA is 0.0 for start == destination', () async {
      final graph = SpatialGraph();
      graph.addNode(node('X'));
      final resp = await service.computeRoute(graph, request('X', 'X'));
      expect(resp.estimatedTimeSeconds, equals(0.0));
    });
  });
}
