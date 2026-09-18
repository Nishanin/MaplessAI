import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/astar_engine.dart';
import 'package:mapless_ai/features/navigation/services/dijkstra_engine.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';

void main() {
  const dijkstra = DijkstraEngine();
  const astar = AStarEngine();
  final service = PathfindingService();

  // ---------------------------------------------------------------------------
  // Fixture loader
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

  // Helper request builder
  NavigationRequestModel buildRequest(
    String from,
    String to, {
    bool avoidBlocked = true,
  }) {
    return NavigationRequestModel(
      buildingId: 'vit-ce',
      startNodeId: from,
      destinationNodeId: to,
      preferences: NavigationPreferencesModel(avoidBlockedEdges: avoidBlocked),
    );
  }

  // ---------------------------------------------------------------------------
  // A. Multi-Floor Test Fixture Verification
  // ---------------------------------------------------------------------------
  group('A. Multi-Floor Test Fixture Verification', () {
    test('vit_two_floors.json loads cleanly into SpatialGraph with 8 nodes and 16 edges', () {
      final graph = loadVitTwoFloorsGraph();
      expect(graph.nodeCount, equals(8));
      expect(graph.edgeCount, equals(16));

      // Floor 1 nodes
      expect(graph.getNode('entrance')?.floorId, equals('floor-1'));
      expect(graph.getNode('corridor-f1')?.floorId, equals('floor-1'));
      expect(graph.getNode('stairs-f1')?.floorId, equals('floor-1'));
      expect(graph.getNode('lift-f1')?.floorId, equals('floor-1'));

      // Floor 2 nodes
      expect(graph.getNode('corridor-f2')?.floorId, equals('floor-2'));
      expect(graph.getNode('stairs-f2')?.floorId, equals('floor-2'));
      expect(graph.getNode('lift-f2')?.floorId, equals('floor-2'));
      expect(graph.getNode('lab-201')?.floorId, equals('floor-2'));

      // Vertical edges
      expect(graph.hasEdgeBetween('stairs-f1', 'stairs-f2'), isTrue);
      expect(graph.hasEdgeBetween('stairs-f2', 'stairs-f1'), isTrue);
      expect(graph.hasEdgeBetween('lift-f1', 'lift-f2'), isTrue);
      expect(graph.hasEdgeBetween('lift-f2', 'lift-f1'), isTrue);

      // Verify validation passes
      final validation = graph.validate();
      expect(validation.isValid, isTrue);
      expect(validation.errors, isEmpty);
      expect(validation.componentCount, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // B & C. Dijkstra Cross-Floor Routing
  // ---------------------------------------------------------------------------
  group('B & C. Dijkstra Cross-Floor Routing', () {
    test('1. Same-floor routing operates normally on a multi-floor graph', () {
      final graph = loadVitTwoFloorsGraph();
      final result = dijkstra.findShortestPath(graph, 'entrance', 'corridor-f1');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['entrance', 'corridor-f1']));
      expect(result.pathEdgeIds, equals(['edge-entrance-corridor1']));
      expect(result.totalDistance, equals(20.0));
    });

    test('2. Floor 1 -> Floor 2 cross-floor route works and chooses optimal path (via Lift)', () {
      final graph = loadVitTwoFloorsGraph();
      final result = dijkstra.findShortestPath(graph, 'entrance', 'lab-201');

      expect(result.found, isTrue);
      // Lift path is 20 + 15 + 4 + 15 + 15 = 69.0 m
      // Stairs path is 20 + 15 + 10 + 15 + 15 = 75.0 m
      expect(result.totalDistance, equals(69.0));
      expect(
        result.pathNodeIds,
        equals(['entrance', 'corridor-f1', 'lift-f1', 'lift-f2', 'corridor-f2', 'lab-201']),
      );
      expect(
        result.pathEdgeIds,
        equals([
          'edge-entrance-corridor1',
          'edge-corridor1-lift1',
          'edge-lift1-lift2',
          'edge-lift2-corridor2',
          'edge-corridor2-lab201',
        ]),
      );
    });

    test('3. Floor 2 -> Floor 1 reverse cross-floor route works (lab-201 to entrance)', () {
      final graph = loadVitTwoFloorsGraph();
      final result = dijkstra.findShortestPath(graph, 'lab-201', 'entrance');

      expect(result.found, isTrue);
      expect(result.totalDistance, equals(69.0));
      expect(
        result.pathNodeIds,
        equals(['lab-201', 'corridor-f2', 'lift-f2', 'lift-f1', 'corridor-f1', 'entrance']),
      );
      expect(
        result.pathEdgeIds,
        equals([
          'edge-lab201-corridor2',
          'edge-corridor2-lift2',
          'edge-lift2-lift1',
          'edge-lift1-corridor1',
          'edge-corridor1-entrance',
        ]),
      );
    });

    test('4. Blocked elevator automatically reroutes via stairs', () {
      final graph = loadVitTwoFloorsGraph();

      // Block both directions of the lift edge
      final liftEdge12 = graph.getEdge('edge-lift1-lift2')!.copyWith(blocked: true);
      final liftEdge21 = graph.getEdge('edge-lift2-lift1')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) {
          if (e.id == 'edge-lift1-lift2') return liftEdge12;
          if (e.id == 'edge-lift2-lift1') return liftEdge21;
          return e;
        }),
      );

      final result = dijkstra.findShortestPath(modifiedGraph, 'entrance', 'lab-201');
      expect(result.found, isTrue);
      // Rerouted via stairs: 20 + 15 + 10 + 15 + 15 = 75.0 m
      expect(result.totalDistance, equals(75.0));
      expect(
        result.pathNodeIds,
        equals(['entrance', 'corridor-f1', 'stairs-f1', 'stairs-f2', 'corridor-f2', 'lab-201']),
      );
    });

    test('5. Blocked stairs preserves route via elevator', () {
      final graph = loadVitTwoFloorsGraph();

      // Block the stairs
      final stairsEdge = graph.getEdge('edge-stairs1-stairs2')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) => e.id == 'edge-stairs1-stairs2' ? stairsEdge : e),
      );

      final result = dijkstra.findShortestPath(modifiedGraph, 'entrance', 'lab-201');
      expect(result.found, isTrue);
      expect(result.totalDistance, equals(69.0));
      expect(result.pathNodeIds.contains('lift-f1'), isTrue);
    });

    test('6. All vertical connectors blocked returns found == false (no route)', () {
      final graph = loadVitTwoFloorsGraph();

      // Block both lift and stairs
      final blockedEdges = graph.allEdges.map((e) {
        if (e.id == 'edge-lift1-lift2' || e.id == 'edge-stairs1-stairs2') {
          return e.copyWith(blocked: true);
        }
        return e;
      });
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, blockedEdges);

      final result = dijkstra.findShortestPath(modifiedGraph, 'entrance', 'lab-201');
      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
    });

    test('7. Disconnected floors with no vertical connectors returns found == false', () {
      final graph = loadVitTwoFloorsGraph();

      // Filter out all cross-floor edges
      final horizontalOnlyEdges = graph.allEdges.where((e) {
        final start = graph.getNode(e.startNodeId)!;
        final end = graph.getNode(e.endNodeId)!;
        return start.floorId == end.floorId;
      });
      final disconnectedGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, horizontalOnlyEdges);

      final result = dijkstra.findShortestPath(disconnectedGraph, 'entrance', 'lab-201');
      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
    });

    test('8. Directed vertical edges are strictly respected (one-way stairs)', () {
      final graph = loadVitTwoFloorsGraph();

      // Create one-way stairs: F1 -> F2 only (remove F2 -> F1 stairs and remove both lifts)
      final edges = graph.allEdges.where((e) {
        return e.id != 'edge-stairs2-stairs1' &&
            e.id != 'edge-lift1-lift2' &&
            e.id != 'edge-lift2-lift1';
      });
      final oneWayGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, edges);

      // F1 -> F2 should succeed
      final forward = dijkstra.findShortestPath(oneWayGraph, 'entrance', 'lab-201');
      expect(forward.found, isTrue);
      expect(forward.pathNodeIds.contains('stairs-f1'), isTrue);

      // F2 -> F1 should fail because stairs only go up and lift is gone
      final reverse = dijkstra.findShortestPath(oneWayGraph, 'lab-201', 'entrance');
      expect(reverse.found, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // D. A* Multi-Floor Routing & Equivalence
  // ---------------------------------------------------------------------------
  group('D. A* Multi-Floor Routing & Equivalence', () {
    test('1. A* produces identical optimal distance and path as Dijkstra (Floor 1 -> Floor 2)', () {
      final graph = loadVitTwoFloorsGraph();

      final dijkstraResult = dijkstra.findShortestPath(graph, 'entrance', 'lab-201');
      final astarResult = astar.findShortestPath(graph, 'entrance', 'lab-201');

      expect(astarResult.found, isTrue);
      expect(astarResult.totalDistance, equals(dijkstraResult.totalDistance));
      expect(astarResult.pathNodeIds, equals(dijkstraResult.pathNodeIds));
      expect(astarResult.pathEdgeIds, equals(dijkstraResult.pathEdgeIds));
    });

    test('2. A* produces identical optimal distance and path in reverse (Floor 2 -> Floor 1)', () {
      final graph = loadVitTwoFloorsGraph();

      final dijkstraResult = dijkstra.findShortestPath(graph, 'lab-201', 'entrance');
      final astarResult = astar.findShortestPath(graph, 'lab-201', 'entrance');

      expect(astarResult.found, isTrue);
      expect(astarResult.totalDistance, equals(dijkstraResult.totalDistance));
      expect(astarResult.pathNodeIds, equals(dijkstraResult.pathNodeIds));
    });

    test('3. A* matches Dijkstra when elevator is blocked (rerouting via stairs)', () {
      final graph = loadVitTwoFloorsGraph();
      final liftEdge = graph.getEdge('edge-lift1-lift2')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) => e.id == 'edge-lift1-lift2' ? liftEdge : e),
      );

      final dijkstraResult = dijkstra.findShortestPath(modifiedGraph, 'entrance', 'lab-201');
      final astarResult = astar.findShortestPath(modifiedGraph, 'entrance', 'lab-201');

      expect(astarResult.found, isTrue);
      expect(astarResult.totalDistance, equals(dijkstraResult.totalDistance));
      expect(astarResult.totalDistance, equals(75.0));
      expect(astarResult.pathNodeIds, equals(dijkstraResult.pathNodeIds));
    });

    test('4. A* returns found == false when all vertical connectors are blocked', () {
      final graph = loadVitTwoFloorsGraph();
      final blockedEdges = graph.allEdges.map((e) {
        if (e.id == 'edge-lift1-lift2' || e.id == 'edge-stairs1-stairs2') {
          return e.copyWith(blocked: true);
        }
        return e;
      });
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, blockedEdges);

      final result = astar.findShortestPath(modifiedGraph, 'entrance', 'lab-201');
      expect(result.found, isFalse);
      expect(result.pathNodeIds, isEmpty);
    });

    test('5. A* start == destination on multi-floor graph returns distance 0.0, 1 node', () {
      final graph = loadVitTwoFloorsGraph();
      final result = astar.findShortestPath(graph, 'lab-201', 'lab-201');

      expect(result.found, isTrue);
      expect(result.pathNodeIds, equals(['lab-201']));
      expect(result.pathEdgeIds, isEmpty);
      expect(result.totalDistance, equals(0.0));
      expect(result.nodesExplored, equals(0));
    });

    test('6. Deterministic repeated execution: 100 runs of Dijkstra and A* produce identical results', () {
      final graph = loadVitTwoFloorsGraph();

      final baselineDijkstra = dijkstra.findShortestPath(graph, 'entrance', 'lab-201');
      final baselineAStar = astar.findShortestPath(graph, 'entrance', 'lab-201');

      for (var i = 0; i < 100; i++) {
        final dResult = dijkstra.findShortestPath(graph, 'entrance', 'lab-201');
        final aResult = astar.findShortestPath(graph, 'entrance', 'lab-201');

        expect(dResult.pathNodeIds, equals(baselineDijkstra.pathNodeIds));
        expect(dResult.totalDistance, equals(baselineDijkstra.totalDistance));

        expect(aResult.pathNodeIds, equals(baselineAStar.pathNodeIds));
        expect(aResult.totalDistance, equals(baselineAStar.totalDistance));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // E & F. Floor Transitions & Contract Compliance
  // ---------------------------------------------------------------------------
  group('E & F. Floor Transitions & Contract Compliance', () {
    test('1. Single floor transition populates floorTransitions with elevator viaType', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'lab-201');

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.routeStatus, equals(RouteStatus.success));

      expect(response.floorTransitions.length, equals(1));
      final transition = response.floorTransitions.first;
      expect(transition.fromFloorId, equals('floor-1'));
      expect(transition.toFloorId, equals('floor-2'));
      // Schema requires 'elevator', NOT 'lift'
      expect(transition.viaType, equals('elevator'));
      // nodeId must be arrival node on target floor
      expect(transition.nodeId, equals('lift-f2'));

      // Verify JSON serialization satisfies contracts/navigation-response.schema.json
      final json = transition.toJson();
      expect(json['fromFloorId'], equals('floor-1'));
      expect(json['toFloorId'], equals('floor-2'));
      expect(json['viaType'], equals('elevator'));
      expect(json['nodeId'], equals('lift-f2'));
    });

    test('2. Stairs route populates floorTransitions with stairs viaType', () async {
      final graph = loadVitTwoFloorsGraph();

      // Block elevator to force stairs
      final liftEdge = graph.getEdge('edge-lift1-lift2')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) => e.id == 'edge-lift1-lift2' ? liftEdge : e),
      );

      final req = buildRequest('entrance', 'lab-201');
      final response = await service.computeRoute(modifiedGraph, req);

      expect(response.success, isTrue);
      expect(response.floorTransitions.length, equals(1));
      final transition = response.floorTransitions.first;
      expect(transition.fromFloorId, equals('floor-1'));
      expect(transition.toFloorId, equals('floor-2'));
      expect(transition.viaType, equals('stairs'));
      expect(transition.nodeId, equals('stairs-f2'));
    });

    test('3. Ramp route populates floorTransitions with ramp viaType', () async {
      // Build a small graph with a ramp transition
      final nodes = [
        const NodeModel(id: 'n1', name: 'N1', category: 'ramp', floorId: 'f1', x: 0, y: 0, accessible: true),
        const NodeModel(id: 'n2', name: 'N2', category: 'ramp', floorId: 'f2', x: 10, y: 0, accessible: true),
      ];
      final edges = [
        const EdgeModel(id: 'e12', startNodeId: 'n1', endNodeId: 'n2', distance: 10.0, bearing: 90.0, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = buildRequest('n1', 'n2');
      final response = await service.computeRoute(graph, req);

      expect(response.success, isTrue);
      expect(response.floorTransitions.length, equals(1));
      expect(response.floorTransitions.first.viaType, equals('ramp'));
      expect(response.floorTransitions.first.fromFloorId, equals('f1'));
      expect(response.floorTransitions.first.toFloorId, equals('f2'));
      expect(response.floorTransitions.first.nodeId, equals('n2'));
    });

    test('4. Multiple floor transitions: F1 -> F2 -> F3 preserves ordering and count', () async {
      // Build a 3-floor graph
      final nodes = [
        const NodeModel(id: 'a1', name: 'Start', category: 'room', floorId: 'floor-1', x: 0, y: 0, accessible: true),
        const NodeModel(id: 's1', name: 'Stairs 1', category: 'stairs', floorId: 'floor-1', x: 10, y: 0, accessible: false),
        const NodeModel(id: 's2', name: 'Stairs 2', category: 'stairs', floorId: 'floor-2', x: 10, y: 0, accessible: false),
        const NodeModel(id: 's3', name: 'Stairs 3', category: 'stairs', floorId: 'floor-3', x: 10, y: 0, accessible: false),
        const NodeModel(id: 'a3', name: 'Destination', category: 'room', floorId: 'floor-3', x: 20, y: 0, accessible: true),
      ];
      final edges = [
        const EdgeModel(id: 'e-a1-s1', startNodeId: 'a1', endNodeId: 's1', distance: 10.0, bearing: 90.0, accessible: true, blocked: false),
        const EdgeModel(id: 'e-s1-s2', startNodeId: 's1', endNodeId: 's2', distance: 8.0, bearing: 0.0, accessible: false, blocked: false),
        const EdgeModel(id: 'e-s2-s3', startNodeId: 's2', endNodeId: 's3', distance: 8.0, bearing: 0.0, accessible: false, blocked: false),
        const EdgeModel(id: 'e-s3-a3', startNodeId: 's3', endNodeId: 'a3', distance: 10.0, bearing: 90.0, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = buildRequest('a1', 'a3');
      final response = await service.computeRoute(graph, req);

      expect(response.success, isTrue);
      expect(response.floorTransitions.length, equals(2));

      // Transition 1: floor-1 -> floor-2
      expect(response.floorTransitions[0].fromFloorId, equals('floor-1'));
      expect(response.floorTransitions[0].toFloorId, equals('floor-2'));
      expect(response.floorTransitions[0].viaType, equals('stairs'));
      expect(response.floorTransitions[0].nodeId, equals('s2'));

      // Transition 2: floor-2 -> floor-3
      expect(response.floorTransitions[1].fromFloorId, equals('floor-2'));
      expect(response.floorTransitions[1].toFloorId, equals('floor-3'));
      expect(response.floorTransitions[1].viaType, equals('stairs'));
      expect(response.floorTransitions[1].nodeId, equals('s3'));
    });

    test('5. Same-floor route emits empty floorTransitions list', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'corridor-f1');

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.floorTransitions, isEmpty);
    });

    test('6. Start == destination emits empty floorTransitions list', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'entrance');

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);
      expect(response.floorTransitions, isEmpty);
    });

    test('7. Genuinely unknown connector throws GraphException with UNKNOWN_FLOOR_TRANSITION_TYPE', () async {
      // Build a cross-floor edge between two generic nodes with no connector classification
      final nodes = [
        const NodeModel(id: 'room-f1', name: 'Room F1', category: 'classroom', floorId: 'floor-1', x: 0, y: 0, accessible: true),
        const NodeModel(id: 'room-f2', name: 'Room F2', category: 'classroom', floorId: 'floor-2', x: 0, y: 0, accessible: true),
      ];
      final edges = [
        const EdgeModel(id: 'edge-mystery', startNodeId: 'room-f1', endNodeId: 'room-f2', distance: 5.0, bearing: 0.0, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = buildRequest('room-f1', 'room-f2');

      expect(
        service.computeRoute(graph, req),
        throwsA(
          isA<GraphException>().having(
            (e) => e.code,
            'code',
            equals('UNKNOWN_FLOOR_TRANSITION_TYPE'),
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // G. Turn Instruction Integration
  // ---------------------------------------------------------------------------
  group('G. Turn Instruction Integration', () {
    test('1. Human instruction uses "lift" while floorTransitions uses "elevator"', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'lab-201');

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);

      // 1. Structured contract: viaType must be 'elevator'
      expect(response.floorTransitions.length, equals(1));
      expect(response.floorTransitions.first.viaType, equals('elevator'));

      // 2. Human turn instruction: contains "Take the lift to floor-2"
      final liftInstruction = response.turnInstructions.firstWhere(
        (i) => i.instruction.toLowerCase().contains('lift') || i.instruction.toLowerCase().contains('elevator'),
      );
      expect(liftInstruction.instruction, equals('Take the lift to floor-2'));
    });

    test('2. Human instruction uses "stairs" when routed via staircase', () async {
      final graph = loadVitTwoFloorsGraph();

      // Block elevator
      final liftEdge = graph.getEdge('edge-lift1-lift2')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) => e.id == 'edge-lift1-lift2' ? liftEdge : e),
      );

      final req = buildRequest('entrance', 'lab-201');
      final response = await service.computeRoute(modifiedGraph, req);

      expect(response.success, isTrue);
      expect(response.floorTransitions.first.viaType, equals('stairs'));

      final stairsInstruction = response.turnInstructions.firstWhere(
        (i) => i.instruction.toLowerCase().contains('stairs'),
      );
      expect(stairsInstruction.instruction, equals('Take the stairs to floor-2'));
    });

    test('3. Straight-line consolidation does NOT cross floor transition boundaries', () async {
      final graph = loadVitTwoFloorsGraph();

      // Block elevator to test stairs walk
      final liftEdge = graph.getEdge('edge-lift1-lift2')!.copyWith(blocked: true);
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(
        graph.allNodes,
        graph.allEdges.map((e) => e.id == 'edge-lift1-lift2' ? liftEdge : e),
      );

      final req = buildRequest('entrance', 'lab-201');
      final response = await service.computeRoute(modifiedGraph, req);

      expect(response.success, isTrue);

      // Verify instruction flow:
      // Step 1: Start
      expect(response.turnInstructions[0].instruction, contains('Start'));
      // Step 2: Corridor walk
      expect(response.turnInstructions[1].instruction, contains('Walk straight'));
      // Step 3: Turn right into stairs approach
      expect(response.turnInstructions[2].instruction, contains('Turn right'));
      // Step 4: Floor transition (Take the stairs to floor-2)
      expect(response.turnInstructions[3].instruction, equals('Take the stairs to floor-2'));
      // Step 5: Turn around / walk into corridor F2
      // Step 6: Arrival at destination
      expect(response.turnInstructions.last.instruction, contains('Arrive at Lab 201'));
    });
  });

  // ---------------------------------------------------------------------------
  // H & I. Distance Semantics & Edge Cases
  // ---------------------------------------------------------------------------
  group('H & I. Distance Semantics & Edge Cases', () {
    test('1. Total distance strictly equals sum of all edge distances including vertical', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'lab-201');

      final response = await service.computeRoute(graph, req);
      expect(response.success, isTrue);

      // Sum edges manually:
      // edge-entrance-corridor1 (20.0) + edge-corridor1-lift1 (15.0) +
      // edge-lift1-lift2 (4.0) + edge-lift2-corridor2 (15.0) + edge-corridor2-lab201 (15.0) = 69.0
      expect(response.totalDistance, equals(69.0));
      expect(response.estimatedTimeSeconds, closeTo(69.0 / 1.2, 1e-4));
    });

    test('2. Zero-distance vertical edge is handled safely without NaN or crash', () async {
      // Graph with a zero-distance vertical elevator (instant floor teleporter)
      final nodes = [
        const NodeModel(id: 'n1', name: 'N1', category: 'elevator', floorId: 'f1', x: 0, y: 0, accessible: true),
        const NodeModel(id: 'n2', name: 'N2', category: 'elevator', floorId: 'f2', x: 0, y: 0, accessible: true),
      ];
      final edges = [
        const EdgeModel(id: 'e12', startNodeId: 'n1', endNodeId: 'n2', distance: 0.0, bearing: 0.0, accessible: true, blocked: false),
      ];
      final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);

      final req = buildRequest('n1', 'n2');
      final response = await service.computeRoute(graph, req);

      expect(response.success, isTrue);
      expect(response.totalDistance, equals(0.0));
      expect(response.estimatedTimeSeconds, equals(0.0));
      expect(response.floorTransitions.length, equals(1));
      expect(response.floorTransitions.first.viaType, equals('elevator'));
    });

    test('3. No route returns clean failure with empty floorTransitions', () async {
      final graph = loadVitTwoFloorsGraph();

      // Block both connectors
      final blockedEdges = graph.allEdges.map((e) {
        if (e.id == 'edge-lift1-lift2' || e.id == 'edge-stairs1-stairs2') {
          return e.copyWith(blocked: true);
        }
        return e;
      });
      final modifiedGraph = SpatialGraph.fromNodesAndEdges(graph.allNodes, blockedEdges);

      final req = buildRequest('entrance', 'lab-201');
      final response = await service.computeRoute(modifiedGraph, req);

      expect(response.success, isFalse);
      expect(response.routeStatus, equals(RouteStatus.noRoute));
      expect(response.pathNodeIds, isEmpty);
      expect(response.edgeIds, isEmpty);
      expect(response.floorTransitions, isEmpty);
      expect(response.turnInstructions, isEmpty);
      expect(response.totalDistance, equals(0.0));
    });

    test('4. Full NavigationResponseModel serializes and deserializes cleanly with floorTransitions', () async {
      final graph = loadVitTwoFloorsGraph();
      final req = buildRequest('entrance', 'lab-201');

      final response = await service.computeRoute(graph, req);
      final json = response.toJson();

      // Roundtrip
      final restored = NavigationResponseModel.fromJson(json);
      expect(restored.success, equals(response.success));
      expect(restored.totalDistance, equals(response.totalDistance));
      expect(restored.floorTransitions.length, equals(1));
      expect(restored.floorTransitions.first.fromFloorId, equals('floor-1'));
      expect(restored.floorTransitions.first.toFloorId, equals('floor-2'));
      expect(restored.floorTransitions.first.viaType, equals('elevator'));
      expect(restored.floorTransitions.first.nodeId, equals('lift-f2'));
      expect(restored.routeStatus, equals(RouteStatus.success));
      expect(restored.algorithm, equals('dijkstra'));
    });
  });
}
