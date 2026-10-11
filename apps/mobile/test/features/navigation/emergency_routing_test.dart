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
  final service = PathfindingService();

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

  group('Phase 8 — Emergency Routing Tests', () {
    // -------------------------------------------------------------------------
    // 1. Nearest reachable emergency exit by actual route distance
    // -------------------------------------------------------------------------
    test('1. Selects the nearest reachable emergency exit by actual route distance', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_near', name: 'Fire Exit East', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_far', name: 'Fire Exit West', category: 'emergency_exit', floorId: 'f1', x: -30, y: 0, accessible: true),
      ];

      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_near', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e2', startNodeId: 'start', endNodeId: 'exit_far', distance: 30.0, bearing: 270, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      expect(response.routeStatus, equals(RouteStatus.success));
      expect(response.pathNodeIds, equals(['start', 'exit_near']));
      expect(response.totalDistance, equals(10.0));
      expect(response.message, contains('Fire Exit East'));
    });

    test('1b. Emergency mode via computeRoute with NavigationRequestModel selects nearest exit', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_near', name: 'Fire Exit East', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_far', name: 'Fire Exit West', category: 'emergency_exit', floorId: 'f1', x: -30, y: 0, accessible: true),
      ];

      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_near', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e2', startNodeId: 'start', endNodeId: 'exit_far', distance: 30.0, bearing: 270, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final request = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'arbitrary_target', // Overridden by emergencyMode: true
        preferences: const NavigationPreferencesModel(emergencyMode: true),
      );

      final response = await service.computeRoute(graph, request);
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'exit_near']));
      expect(response.totalDistance, equals(10.0));
    });

    // -------------------------------------------------------------------------
    // 2. Geometrically closer exit rejected when its graph route is longer
    // -------------------------------------------------------------------------
    test('2. Rejects geometrically closer exit when actual graph route is longer', () async {
      // Start is at (0, 0).
      // Exit A is at (0, 5) -> Euclidean distance = 5.0m
      // But route to Exit A has a detour: start(0,0) -> c1(10,0) -> c2(10,5) -> exit_a(0,5) = 10 + 5 + 10 = 25m
      // Exit B is at (15, 0) -> Euclidean distance = 15.0m (> 5m)
      // But route to Exit B is direct: start(0,0) -> exit_b(15,0) = 15m (< 25m)
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'c1', name: 'Corridor 1', category: 'corridor', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'c2', name: 'Corridor 2', category: 'corridor', floorId: 'f1', x: 10, y: 5, accessible: true),
        NodeModel(id: 'exit_a', name: 'Exit Geometric Close', category: 'emergency_exit', floorId: 'f1', x: 0, y: 5, accessible: true),
        NodeModel(id: 'exit_b', name: 'Exit Route Optimal', category: 'emergency_exit', floorId: 'f1', x: 15, y: 0, accessible: true),
      ];

      final edges = [
        // Path to Exit A (total 25m)
        EdgeModel(id: 'e_s_c1', startNodeId: 'start', endNodeId: 'c1', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e_c1_c2', startNodeId: 'c1', endNodeId: 'c2', distance: 5.0, bearing: 0, accessible: true, blocked: false),
        EdgeModel(id: 'e_c2_ea', startNodeId: 'c2', endNodeId: 'exit_a', distance: 10.0, bearing: 270, accessible: true, blocked: false),
        // Path to Exit B (total 15m)
        EdgeModel(id: 'e_s_eb', startNodeId: 'start', endNodeId: 'exit_b', distance: 15.0, bearing: 90, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      // Confirms Exit B was selected despite Exit A having smaller Euclidean distance
      expect(response.pathNodeIds, equals(['start', 'exit_b']));
      expect(response.totalDistance, equals(15.0));
    });

    // -------------------------------------------------------------------------
    // 3. Blocked edges are not used by default
    // -------------------------------------------------------------------------
    test('3. Bypasses blocked edge to nearest exit and chooses clear alternative exit', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_blocked', name: 'Exit North (Blocked)', category: 'emergency_exit', floorId: 'f1', x: 5, y: 0, accessible: true),
        NodeModel(id: 'exit_clear', name: 'Exit South (Clear)', category: 'emergency_exit', floorId: 'f1', x: 20, y: 0, accessible: true),
      ];

      final edges = [
        // Short route (5m) is blocked
        EdgeModel(id: 'e_blocked', startNodeId: 'start', endNodeId: 'exit_blocked', distance: 5.0, bearing: 90, accessible: true, blocked: true),
        // Longer route (20m) is clear
        EdgeModel(id: 'e_clear', startNodeId: 'start', endNodeId: 'exit_clear', distance: 20.0, bearing: 90, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'exit_clear']));
      expect(response.totalDistance, equals(20.0));
    });

    // -------------------------------------------------------------------------
    // 4. Unreachable or disconnected exit handled correctly
    // -------------------------------------------------------------------------
    test('4. Correctly ignores disconnected exit and routes to reachable exit', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_reachable', name: 'Reachable Exit', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        // Disconnected component
        NodeModel(id: 'island_start', name: 'Island Start', category: 'corridor', floorId: 'f1', x: 50, y: 50, accessible: true),
        NodeModel(id: 'exit_island', name: 'Island Exit', category: 'emergency_exit', floorId: 'f1', x: 55, y: 50, accessible: true),
      ];

      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_reachable', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e_island', startNodeId: 'island_start', endNodeId: 'exit_island', distance: 5.0, bearing: 90, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'exit_reachable']));
      expect(response.totalDistance, equals(10.0));
    });

    // -------------------------------------------------------------------------
    // 5. NO_ROUTE returned when no designated exit is reachable
    // -------------------------------------------------------------------------
    test('5a. Returns noRoute when only path to exit is blocked', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];

      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_1', distance: 10.0, bearing: 90, accessible: true, blocked: true),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
      expect(response.pathNodeIds, isEmpty);
      expect(response.edgeIds, isEmpty);
      expect(response.totalDistance, equals(0.0));
      expect(response.message, contains('No reachable emergency exit found'));
    });

    test('5b. Returns noRoute when graph contains zero designated emergency exits', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'room_101', name: 'Room 101', category: 'laboratory', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];

      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'room_101', distance: 10.0, bearing: 90, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
      expect(response.message, contains('No designated emergency exits found'));
    });

    // -------------------------------------------------------------------------
    // 6. Multi-floor emergency routing with existing connector metadata
    // -------------------------------------------------------------------------
    test('6. Multi-floor emergency routing successfully descends floors to emergency exit', () async {
      final baseGraph = loadVitTwoFloorsGraph();

      // Add emergency exit on Floor 1 connected to corridor-f1
      final exitNode = NodeModel(
        id: 'exit-south',
        name: 'South Fire Exit',
        category: 'emergency_exit',
        floorId: 'floor-1',
        x: 30.0,
        y: 15.0,
        accessible: true,
      );
      final exitEdge = EdgeModel(
        id: 'edge-corridor1-exitsouth',
        startNodeId: 'corridor-f1',
        endNodeId: 'exit-south',
        distance: 10.0,
        bearing: 90.0,
        accessible: true,
        blocked: false,
      );

      final multiFloorGraph = SpatialGraph.fromNodesAndEdges(
        [...baseGraph.allNodes, exitNode],
        [...baseGraph.allEdges, exitEdge],
        validate: true,
      );

      // Start on Floor 2 at lab-201
      final response = await service.computeEmergencyRoute(multiFloorGraph, 'lab-201');
      expect(response.success, isTrue);
      expect(response.routeStatus, equals(RouteStatus.success));
      expect(response.pathNodeIds.first, equals('lab-201'));
      expect(response.pathNodeIds.last, equals('exit-south'));
      // Verify floor transition was properly generated from floor-2 to floor-1
      expect(response.floorTransitions, isNotEmpty);
      expect(response.floorTransitions.first.fromFloorId, equals('floor-2'));
      expect(response.floorTransitions.first.toFloorId, equals('floor-1'));
      expect(response.turnInstructions, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // 7. Directed edges are respected
    // -------------------------------------------------------------------------
    test('7. Respects directed edges and cannot traverse one-way edges in reverse', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_reverse', name: 'Exit Reverse Only', category: 'emergency_exit', floorId: 'f1', x: 5, y: 0, accessible: true),
        NodeModel(id: 'exit_forward', name: 'Exit Forward', category: 'emergency_exit', floorId: 'f1', x: 20, y: 0, accessible: true),
      ];

      final edges = [
        // Directed edge: exit_reverse -> start (CANNOT travel start -> exit_reverse)
        EdgeModel(id: 'e_rev', startNodeId: 'exit_reverse', endNodeId: 'start', distance: 5.0, bearing: 270, accessible: true, blocked: false),
        // Directed edge: start -> exit_forward
        EdgeModel(id: 'e_fwd', startNodeId: 'start', endNodeId: 'exit_forward', distance: 20.0, bearing: 90, accessible: true, blocked: false),
      ];

      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'exit_forward']));
      expect(response.totalDistance, equals(20.0));
    });

    // -------------------------------------------------------------------------
    // 8. Missing start nodes and invalid requests
    // -------------------------------------------------------------------------
    test('8. Missing start node returns startNodeNotFound', () async {
      final nodes = [
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 0, y: 0, accessible: true),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const []);

      final response = await service.computeEmergencyRoute(graph, 'non_existent_start');
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.startNodeNotFound));
      expect(response.pathNodeIds, isEmpty);
      expect(response.message, contains("Start node 'non_existent_start' not found"));
    });

    // -------------------------------------------------------------------------
    // 9. Graph is not mutated by route calculation
    // -------------------------------------------------------------------------
    test('9. SpatialGraph remains completely immutable after emergency route calculation', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_1', distance: 10.0, bearing: 90, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final nodeCountBefore = graph.nodeCount;
      final edgeCountBefore = graph.edgeCount;

      await service.computeEmergencyRoute(graph, 'start');

      expect(graph.nodeCount, equals(nodeCountBefore));
      expect(graph.edgeCount, equals(edgeCountBefore));
      expect(graph.getNode('start')?.category, equals('corridor'));
      expect(graph.getEdge('e1')?.blocked, isFalse);
    });

    // -------------------------------------------------------------------------
    // 10. Existing accessibility policies and ordinary routing remain unchanged
    // -------------------------------------------------------------------------
    test('10a. Ordinary navigation request with emergencyMode == false routes to target room', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'room_101', name: 'Room 101', category: 'laboratory', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 5, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'room_101', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e2', startNodeId: 'start', endNodeId: 'exit_1', distance: 5.0, bearing: 90, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'room_101',
        preferences: const NavigationPreferencesModel(emergencyMode: false),
      );

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      // Confirms ordinary request routed to room_101, NOT exit_1
      expect(response.pathNodeIds, equals(['start', 'room_101']));
      expect(response.totalDistance, equals(10.0));
    });

    test('10b. Wheelchair emergency routing (accessible: true) rejects stairs and chooses accessible exit', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_stairs', name: 'Exit via Stairs', category: 'emergency_exit', floorId: 'f1', x: 5, y: 0, accessible: true),
        NodeModel(id: 'exit_ramp', name: 'Exit via Ramp', category: 'emergency_exit', floorId: 'f1', x: 15, y: 0, accessible: true),
      ];
      final edges = [
        // Exit with stairs: short (5m) but inaccessible
        EdgeModel(id: 'e_stairs', startNodeId: 'start', endNodeId: 'exit_stairs', distance: 5.0, bearing: 90, accessible: false, blocked: false, metadata: const {'connectorType': 'stairs'}),
        // Exit with ramp: longer (15m) and accessible
        EdgeModel(id: 'e_ramp', startNodeId: 'start', endNodeId: 'exit_ramp', distance: 15.0, bearing: 90, accessible: true, blocked: false, metadata: const {'connectorType': 'ramp'}),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(
        graph,
        'start',
        preferences: const NavigationPreferencesModel(
          accessible: true,
          avoidStairs: true,
          emergencyMode: true,
        ),
      );

      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['start', 'exit_ramp']));
      expect(response.totalDistance, equals(15.0));
    });

    // -------------------------------------------------------------------------
    // 11. Already at an emergency exit
    // -------------------------------------------------------------------------
    test('11. Returns zero-distance success when user is already at an emergency exit', () async {
      final nodes = [
        NodeModel(id: 'exit_here', name: 'Immediate Exit', category: 'emergency_exit', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_other', name: 'Other Exit', category: 'emergency_exit', floorId: 'f1', x: 20, y: 0, accessible: true),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, const []);

      final response = await service.computeEmergencyRoute(graph, 'exit_here');
      expect(response.success, isTrue);
      expect(response.pathNodeIds, equals(['exit_here']));
      expect(response.totalDistance, equals(0.0));
      expect(response.message, contains('Already at emergency exit "Immediate Exit"'));
    });

    // -------------------------------------------------------------------------
    // 12. Dijkstra and A* equivalence in emergency routing
    // -------------------------------------------------------------------------
    test('12. Dijkstra and A* produce identical emergency routes and distances', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'm1', name: 'M1', category: 'corridor', floorId: 'f1', x: 5, y: 0, accessible: true),
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_2', name: 'Exit 2', category: 'emergency_exit', floorId: 'f1', x: 0, y: 20, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'm1', distance: 5.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e2', startNodeId: 'm1', endNodeId: 'exit_1', distance: 5.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e3', startNodeId: 'start', endNodeId: 'exit_2', distance: 20.0, bearing: 0, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final dResp = await service.computeEmergencyRoute(
        graph,
        'start',
        algorithm: NavigationAlgorithm.dijkstra,
      );
      final aResp = await service.computeEmergencyRoute(
        graph,
        'start',
        algorithm: NavigationAlgorithm.aStar,
      );

      expect(dResp.success, isTrue);
      expect(aResp.success, isTrue);
      expect(dResp.pathNodeIds, equals(aResp.pathNodeIds));
      expect(dResp.edgeIds, equals(aResp.edgeIds));
      expect(dResp.totalDistance, equals(aResp.totalDistance));
    });

    // -------------------------------------------------------------------------
    // 13. Ordinary entrance is NOT treated as an emergency exit
    // -------------------------------------------------------------------------
    test('13. Ordinary entrance node is not treated as emergency exit', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        // Ordinary entrance closer in distance
        NodeModel(id: 'main_entrance', name: 'Main Entrance', category: 'entrance', floorId: 'f1', x: 2, y: 0, accessible: true),
        // Explicit emergency exit further away
        NodeModel(id: 'fire_exit', name: 'Fire Exit', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e_ent', startNodeId: 'start', endNodeId: 'main_entrance', distance: 2.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e_exit', startNodeId: 'start', endNodeId: 'fire_exit', distance: 10.0, bearing: 90, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      // Strictly routes to fire_exit, never to main_entrance
      expect(response.pathNodeIds, equals(['start', 'fire_exit']));
      expect(response.totalDistance, equals(10.0));
    });

    // -------------------------------------------------------------------------
    // 14. Emergency mode with non-existent destinationNodeId succeeds
    // -------------------------------------------------------------------------
    test('14. computeRoute with emergencyMode succeeds even when destinationNodeId does not exist in graph', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'fire_exit', name: 'Fire Exit', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'fire_exit', distance: 10.0, bearing: 90, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      // Caller passes a non-existent destinationNodeId, but emergencyMode: true
      final request = NavigationRequestModel(
        buildingId: 'b1',
        startNodeId: 'start',
        destinationNodeId: 'non_existent_destination',
        preferences: const NavigationPreferencesModel(emergencyMode: true),
      );

      final response = await service.computeRoute(graph, request);
      expect(response.success, isTrue);
      expect(response.routeStatus, equals(RouteStatus.success));
      expect(response.pathNodeIds, equals(['start', 'fire_exit']));
      expect(response.totalDistance, equals(10.0));
    });

    // -------------------------------------------------------------------------
    // 15. All paths to multiple exits blocked returns noRoute
    // -------------------------------------------------------------------------
    test('15. Returns noRoute when all paths to multiple candidate exits are blocked', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_1', name: 'Exit 1', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_2', name: 'Exit 2', category: 'emergency_exit', floorId: 'f1', x: -10, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'exit_1', distance: 10.0, bearing: 90, accessible: true, blocked: true),
        EdgeModel(id: 'e2', startNodeId: 'start', endNodeId: 'exit_2', distance: 10.0, bearing: 270, accessible: true, blocked: true),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
      expect(response.pathNodeIds, isEmpty);
      expect(response.totalDistance, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // 16. Deterministic tie-breaking for equal distance exits
    // -------------------------------------------------------------------------
    test('16. Deterministic tie-breaking retains first insertion-order exit when distances are equal', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'exit_alpha', name: 'Exit Alpha', category: 'emergency_exit', floorId: 'f1', x: 10, y: 0, accessible: true),
        NodeModel(id: 'exit_beta', name: 'Exit Beta', category: 'emergency_exit', floorId: 'f1', x: -10, y: 0, accessible: true),
      ];
      final edges = [
        EdgeModel(id: 'e_a', startNodeId: 'start', endNodeId: 'exit_alpha', distance: 10.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e_b', startNodeId: 'start', endNodeId: 'exit_beta', distance: 10.0, bearing: 270, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final resp1 = await service.computeEmergencyRoute(graph, 'start');
      final resp2 = await service.computeEmergencyRoute(graph, 'start');

      expect(resp1.success, isTrue);
      expect(resp1.pathNodeIds, equals(['start', 'exit_alpha']));
      expect(resp2.pathNodeIds, equals(resp1.pathNodeIds)); // Repeatability
    });

    // -------------------------------------------------------------------------
    // 17. Malformed / non-boolean metadata flags do not trigger exit classification
    // -------------------------------------------------------------------------
    test('17. Malformed or non-boolean metadata flags do not trigger emergency exit classification', () async {
      final nodes = [
        NodeModel(id: 'start', name: 'Start', category: 'corridor', floorId: 'f1', x: 0, y: 0, accessible: true),
        NodeModel(id: 'corridor_false', name: 'Corridor False', category: 'corridor', floorId: 'f1', x: 5, y: 0, accessible: true, metadata: {'isEmergencyExit': false}),
        NodeModel(id: 'corridor_string', name: 'Corridor String', category: 'corridor', floorId: 'f1', x: 5, y: 5, accessible: true, metadata: {'isEmergencyExit': 'true'}),
        NodeModel(id: 'real_exit', name: 'Real Exit', category: 'office', floorId: 'f1', x: 15, y: 0, accessible: true, metadata: {'isEmergencyExit': true}),
      ];
      final edges = [
        EdgeModel(id: 'e1', startNodeId: 'start', endNodeId: 'corridor_false', distance: 5.0, bearing: 90, accessible: true, blocked: false),
        EdgeModel(id: 'e2', startNodeId: 'start', endNodeId: 'corridor_string', distance: 5.0, bearing: 45, accessible: true, blocked: false),
        EdgeModel(id: 'e3', startNodeId: 'start', endNodeId: 'real_exit', distance: 15.0, bearing: 90, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final response = await service.computeEmergencyRoute(graph, 'start');
      expect(response.success, isTrue);
      // Strictly routes to real_exit, ignoring corridor_false and corridor_string
      expect(response.pathNodeIds, equals(['start', 'real_exit']));
      expect(response.totalDistance, equals(15.0));
    });
  });
}
