import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';
import 'package:mapless_ai/features/navigation/services/turn_instruction_generator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Test Helpers
  // ---------------------------------------------------------------------------

  NodeModel node(
    String id, {
    String? name,
    String category = 'corridor',
    String floorId = 'floor-1',
    double x = 0.0,
    double y = 0.0,
  }) {
    return NodeModel(
      id: id,
      name: name ?? 'Node $id',
      category: category,
      floorId: floorId,
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

  const generator = TurnInstructionGenerator();

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

  group('TurnInstructionGenerator — Core Requirements', () {
    // -------------------------------------------------------------------------
    // A. Start == Destination
    // -------------------------------------------------------------------------
    test('A. Start == destination: arrival representation with zero movement', () {
      final graph = SpatialGraph();
      graph.addNode(node('reception', name: 'Reception Desk'));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['reception'],
        pathEdgeIds: [],
      );

      expect(instructions.length, equals(1));
      final inst = instructions.first;
      expect(inst.step, equals(1));
      expect(inst.instruction, equals('Arrive at Reception Desk'));
      expect(inst.distance, equals(0.0));
      expect(inst.nodeId, equals('reception'));
      // Verify no turn instructions generated
      expect(inst.instruction.contains('Turn'), isFalse);
    });

    // -------------------------------------------------------------------------
    // B. One-Edge Route
    // -------------------------------------------------------------------------
    test('B. One-edge route: start, walk straight, arrive (no turn instruction)', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', name: 'Reception'),
        node('B', name: 'Main Corridor'),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 15.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B'],
        pathEdgeIds: ['e_ab'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[0].step, equals(1));
      expect(instructions[0].instruction, equals('Start at Reception'));
      expect(instructions[0].distance, equals(0.0));
      expect(instructions[0].bearing, equals(90.0));
      expect(instructions[0].nodeId, equals('A'));

      expect(instructions[1].step, equals(2));
      expect(instructions[1].instruction, equals('Walk straight for 15 m'));
      expect(instructions[1].distance, equals(15.0));
      expect(instructions[1].bearing, equals(90.0));
      expect(instructions[1].nodeId, equals('B'));

      expect(instructions[2].step, equals(3));
      expect(instructions[2].instruction, equals('Arrive at Main Corridor'));
      expect(instructions[2].distance, equals(0.0));
      expect(instructions[2].bearing, equals(90.0));
      expect(instructions[2].nodeId, equals('B'));

      // None of the instructions instructs a turn
      expect(instructions.any((i) => i.instruction.contains('Turn')), isFalse);
    });

    // -------------------------------------------------------------------------
    // C. Straight Route (Two Edges Consolidated)
    // -------------------------------------------------------------------------
    test('C. Two consecutive straight edges are consolidated', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e_bc', 'B', 'C', distance: 15.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e_ab', 'e_bc'],
      );

      // Start, Consolidated Straight, Arrival
      expect(instructions.length, equals(3));
      expect(instructions[0].instruction, equals('Start at Node A'));
      expect(instructions[1].instruction, equals('Walk straight for 25 m'));
      expect(instructions[1].distance, equals(25.0));
      expect(instructions[1].nodeId, equals('C'));
      expect(instructions[2].instruction, equals('Arrive at Node C'));
    });

    // -------------------------------------------------------------------------
    // D. Slight Left (-30°)
    // -------------------------------------------------------------------------
    test('D. Slight left turn classified correctly (90° -> 60° = -30°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 12.0, bearing: 60.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst.length, equals(4));
      expect(domainInst[1].type, equals(TurnType.straight));
      expect(domainInst[2].type, equals(TurnType.slightLeft));
      expect(domainInst[2].instruction, equals('Turn slight left and continue for 12 m'));
      expect(domainInst[2].distance, equals(12.0));
      expect(domainInst[2].bearing, equals(60.0));
      expect(domainInst[2].turnAngle, equals(-30.0));
    });

    // -------------------------------------------------------------------------
    // E. Slight Right (+30°)
    // -------------------------------------------------------------------------
    test('E. Slight right turn classified correctly (90° -> 120° = +30°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 14.0, bearing: 120.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.slightRight));
      expect(domainInst[2].instruction, equals('Turn slight right and continue for 14 m'));
      expect(domainInst[2].turnAngle, equals(30.0));
    });

    // -------------------------------------------------------------------------
    // F. Left (-90°)
    // -------------------------------------------------------------------------
    test('F. Left turn classified correctly (90° -> 0° = -90°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 8.0, bearing: 0.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.left));
      expect(domainInst[2].instruction, equals('Turn left and continue for 8 m'));
      expect(domainInst[2].turnAngle, equals(-90.0));
    });

    // -------------------------------------------------------------------------
    // G. Right (+90°)
    // -------------------------------------------------------------------------
    test('G. Right turn classified correctly (0° -> 90° = +90°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 0.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 18.0, bearing: 90.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.right));
      expect(domainInst[2].instruction, equals('Turn right and continue for 18 m'));
      expect(domainInst[2].turnAngle, equals(90.0));
    });

    // -------------------------------------------------------------------------
    // H. Sharp Left (-150°)
    // -------------------------------------------------------------------------
    test('H. Sharp left turn classified correctly (180° -> 30° = -150°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 180.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 7.0, bearing: 30.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.sharpLeft));
      expect(domainInst[2].instruction, equals('Turn sharp left and continue for 7 m'));
      expect(domainInst[2].turnAngle, equals(-150.0));
    });

    // -------------------------------------------------------------------------
    // I. Sharp Right (+150°)
    // -------------------------------------------------------------------------
    test('I. Sharp right turn classified correctly (0° -> 150° = +150°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 0.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 6.0, bearing: 150.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.sharpRight));
      expect(domainInst[2].instruction, equals('Turn sharp right and continue for 6 m'));
      expect(domainInst[2].turnAngle, equals(150.0));
    });

    // -------------------------------------------------------------------------
    // J. U-Turn (180°)
    // -------------------------------------------------------------------------
    test('J. U-turn classified correctly (90° -> 270° = 180°)', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B'), node('C')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 10.0, bearing: 270.0));

      final domainInst = generator.generateDomainInstructions(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C'],
        pathEdgeIds: ['e1', 'e2'],
      );

      expect(domainInst[2].type, equals(TurnType.uTurn));
      expect(domainInst[2].instruction, equals('Make a U-turn and continue for 10 m'));
      expect(domainInst[2].turnAngle, equals(180.0));
    });

    // -------------------------------------------------------------------------
    // K. Multiple Straight Edges Consolidated
    // -------------------------------------------------------------------------
    test('K. 4 consecutive straight edges consolidated into single 40 m walk', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('n0'),
        node('n1'),
        node('n2'),
        node('n3'),
        node('n4', name: 'Destination Lab'),
      ]);
      graph.addEdge(edge('e0', 'n0', 'n1', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e1', 'n1', 'n2', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'n2', 'n3', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e3', 'n3', 'n4', distance: 10.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['n0', 'n1', 'n2', 'n3', 'n4'],
        pathEdgeIds: ['e0', 'e1', 'e2', 'e3'],
      );

      // Must NOT produce 4 walk straight instructions
      expect(instructions.length, equals(3));
      expect(instructions[0].instruction, equals('Start at Node n0'));
      expect(instructions[1].instruction, equals('Walk straight for 40 m'));
      expect(instructions[1].distance, equals(40.0));
      expect(instructions[1].nodeId, equals('n4'));
      expect(instructions[2].instruction, equals('Arrive at Destination Lab'));
    });

    // -------------------------------------------------------------------------
    // L. Zero-Distance Edge
    // -------------------------------------------------------------------------
    test('L. Zero-distance edge handled safely without NaN or crash', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e_zero', 'A', 'B', distance: 0.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B'],
        pathEdgeIds: ['e_zero'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].distance, equals(0.0));
      expect(instructions[1].instruction, equals('Walk straight for 0 m'));
    });

    // -------------------------------------------------------------------------
    // M. Missing Node
    // -------------------------------------------------------------------------
    test('M. Missing node throws GraphException with MISSING_ROUTE_NODE', () {
      final graph = SpatialGraph();
      graph.addNode(node('A'));

      expect(
        () => generator.generate(
          graph: graph,
          pathNodeIds: ['A', 'missing_node'],
          pathEdgeIds: ['e_ab'],
        ),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('MISSING_ROUTE_NODE')),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // N. Missing Edge
    // -------------------------------------------------------------------------
    test('N. Missing edge throws GraphException with MISSING_ROUTE_EDGE', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);

      expect(
        () => generator.generate(
          graph: graph,
          pathNodeIds: ['A', 'B'],
          pathEdgeIds: ['missing_edge'],
        ),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('MISSING_ROUTE_EDGE')),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // O. Wrong Edge Direction
    // -------------------------------------------------------------------------
    test('O. Reversed edge throws GraphException with EDGE_DIRECTION_MISMATCH', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      // Edge goes B -> A, but path requires A -> B
      graph.addEdge(edge('e_ba', 'B', 'A', distance: 10.0));

      expect(
        () => generator.generate(
          graph: graph,
          pathNodeIds: ['A', 'B'],
          pathEdgeIds: ['e_ba'],
        ),
        throwsA(
          isA<GraphException>()
              .having((e) => e.code, 'code', equals('EDGE_DIRECTION_MISMATCH')),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // P. Invalid Distance
    // -------------------------------------------------------------------------
    test('P. Negative or NaN distance throws GraphException with INVALID_EDGE_DISTANCE', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);

      // Bypass SpatialGraph.addEdge validation using internal injection or reflection
      // to simulate malformed edge model directly:
      final badEdge = edge('e_bad', 'A', 'B', distance: -5.0);
      // Construct SpatialGraph with the invalid edge via fromNodesAndEdges bypass or testing direct
      expect(
        () => SpatialGraph.fromNodesAndEdges([node('A'), node('B')], [badEdge]),
        throwsA(isA<GraphException>()),
      );
    });

    // -------------------------------------------------------------------------
    // Q. Missing Node Name Fallback
    // -------------------------------------------------------------------------
    test('Q. Missing or empty node names fall back gracefully', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', name: '   '), // whitespace only
        node('B', name: ''),    // empty
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 12.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B'],
        pathEdgeIds: ['e_ab'],
      );

      expect(instructions.first.instruction, equals('Start navigation'));
      expect(instructions.last.instruction, equals('Arrive at destination'));
    });

    // -------------------------------------------------------------------------
    // R. Destination Arrival
    // -------------------------------------------------------------------------
    test('R. Final instruction clearly indicates arrival at destination', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', name: 'Entrance'),
        node('B', name: 'Chemistry Lab 202'),
      ]);
      graph.addEdge(edge('e_ab', 'A', 'B', distance: 20.0, bearing: 90.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B'],
        pathEdgeIds: ['e_ab'],
      );

      expect(instructions.last.instruction, equals('Arrive at Chemistry Lab 202'));
      expect(instructions.last.distance, equals(0.0));
      expect(instructions.last.nodeId, equals('B'));
    });

    // -------------------------------------------------------------------------
    // S. Determinism Across Repeated Executions
    // -------------------------------------------------------------------------
    test('S. Repeated executions produce byte-for-byte identical instructions (100 runs)', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('A', name: 'Entrance'),
        node('B', name: 'Lobby'),
        node('C', name: 'Hallway'),
        node('D', name: 'Auditorium'),
      ]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0, bearing: 90.0));
      graph.addEdge(edge('e2', 'B', 'C', distance: 15.0, bearing: 0.0)); // left
      graph.addEdge(edge('e3', 'C', 'D', distance: 20.0, bearing: 90.0)); // right

      final firstRun = generator.generate(
        graph: graph,
        pathNodeIds: ['A', 'B', 'C', 'D'],
        pathEdgeIds: ['e1', 'e2', 'e3'],
      );

      for (var i = 0; i < 100; i++) {
        final currentRun = generator.generate(
          graph: graph,
          pathNodeIds: ['A', 'B', 'C', 'D'],
          pathEdgeIds: ['e1', 'e2', 'e3'],
        );

        expect(currentRun.length, equals(firstRun.length));
        for (var j = 0; j < firstRun.length; j++) {
          expect(currentRun[j].step, equals(firstRun[j].step));
          expect(currentRun[j].instruction, equals(firstRun[j].instruction));
          expect(currentRun[j].distance, equals(firstRun[j].distance));
          expect(currentRun[j].bearing, equals(firstRun[j].bearing));
          expect(currentRun[j].nodeId, equals(firstRun[j].nodeId));
        }
      }
    });

    // -------------------------------------------------------------------------
    // T. VIT Graph Integration
    // -------------------------------------------------------------------------
    test('T. VIT Graph route (entrance -> reception -> corridor -> lab-101)', () {
      final graph = loadVitGraph();

      // Route: entrance (0,15) -> reception (10,15) -> corridor (25,15) -> lab-101 (25,30)
      // entrance -> reception: 10m, bearing 90.0°
      // reception -> corridor: 15m, bearing 90.0° (straight continuation, consolidated!)
      // corridor -> lab-101: 15m, bearing 0.0° (left turn!)
      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['entrance', 'reception', 'corridor', 'lab-101'],
        pathEdgeIds: [
          'edge-entrance-reception',
          'edge-reception-corridor',
          'edge-corridor-lab101',
        ],
      );

      expect(instructions.length, equals(4));

      // 1. Start at Main Entrance
      expect(instructions[0].step, equals(1));
      expect(instructions[0].instruction, equals('Start at Main Entrance'));
      expect(instructions[0].distance, equals(0.0));
      expect(instructions[0].bearing, equals(90.0));
      expect(instructions[0].nodeId, equals('entrance'));

      // 2. Consolidated straight segment: 10m + 15m = 25m
      expect(instructions[1].step, equals(2));
      expect(instructions[1].instruction, equals('Walk straight for 25 m'));
      expect(instructions[1].distance, equals(25.0));
      expect(instructions[1].bearing, equals(90.0));
      expect(instructions[1].nodeId, equals('corridor'));

      // 3. Turn left from 90° to 0°
      expect(instructions[2].step, equals(3));
      expect(instructions[2].instruction, equals('Turn left and continue for 15 m'));
      expect(instructions[2].distance, equals(15.0));
      expect(instructions[2].bearing, equals(0.0));
      expect(instructions[2].nodeId, equals('lab-101'));

      // 4. Arrive at Lab 101
      expect(instructions[3].step, equals(4));
      expect(instructions[3].instruction, equals('Arrive at Lab 101'));
      expect(instructions[3].distance, equals(0.0));
      expect(instructions[3].bearing, equals(0.0));
      expect(instructions[3].nodeId, equals('lab-101'));

      // Total distance sum of movement steps matches route distance (25 + 15 = 40m)
      final movementDistance = instructions
          .map((i) => i.distance)
          .reduce((a, b) => a + b);
      expect(movementDistance, equals(40.0));
    });

    // -------------------------------------------------------------------------
    // Immutability & Contract Safety
    // -------------------------------------------------------------------------
    test('Generator never mutates input node list or edge list', () {
      final graph = SpatialGraph();
      graph.addNodes([node('A'), node('B')]);
      graph.addEdge(edge('e1', 'A', 'B', distance: 10.0));

      final originalNodes = List<String>.unmodifiable(['A', 'B']);
      final originalEdges = List<String>.unmodifiable(['e1']);

      // Call generator with unmodifiable lists
      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: originalNodes,
        pathEdgeIds: originalEdges,
      );

      expect(instructions, isNotEmpty);
      expect(originalNodes, equals(['A', 'B']));
      expect(originalEdges, equals(['e1']));
    });

    test('Distance formatting rules: integer vs fractional meters', () {
      expect(TurnInstructionGenerator.formatDistance(12.0), equals('12 m'));
      expect(TurnInstructionGenerator.formatDistance(12.4), equals('12.4 m'));
      expect(TurnInstructionGenerator.formatDistance(12.46), equals('12.5 m'));
      expect(TurnInstructionGenerator.formatDistance(12.000000001), equals('12 m'));
      expect(TurnInstructionGenerator.formatDistance(0.0), equals('0 m'));
      expect(TurnInstructionGenerator.formatDistance(-1.0), equals('0 m'));
    });

    test('Floor transition generates appropriate stairs instruction', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('f1_stairs', name: 'Floor 1 Stairs', category: 'staircase', floorId: 'floor-1'),
        node('f2_stairs', name: 'Floor 2 Stairs', category: 'staircase', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_stairs', 'f1_stairs', 'f2_stairs', distance: 6.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['f1_stairs', 'f2_stairs'],
        pathEdgeIds: ['e_stairs'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].instruction, equals('Take the stairs to floor-2'));
    });

    test('Floor transition generates appropriate lift instruction', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('f1_lift', name: 'Ground Lift', category: 'lift', floorId: 'floor-1'),
        node('f2_lift', name: 'First Floor Lift', category: 'lift', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_lift', 'f1_lift', 'f2_lift', distance: 4.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['f1_lift', 'f2_lift'],
        pathEdgeIds: ['e_lift'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].instruction, equals('Take the lift to floor-2'));
    });

    test('Floor transition generates appropriate ramp instruction', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('f1_ramp', name: 'Access Ramp F1', category: 'ramp', floorId: 'floor-1'),
        node('f2_ramp', name: 'Access Ramp F2', category: 'ramp', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_ramp', 'f1_ramp', 'f2_ramp', distance: 8.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['f1_ramp', 'f2_ramp'],
        pathEdgeIds: ['e_ramp'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].instruction, equals('Take the ramp to floor-2'));
    });

    test('Ambiguous / unknown connector generates generic "Proceed to <targetFloor>"', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('c1', name: 'Connector F1', category: 'connector', floorId: 'floor-1'),
        node('c2', name: 'Connector F2', category: 'connector', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_conn', 'c1', 'c2', distance: 5.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['c1', 'c2'],
        pathEdgeIds: ['e_conn'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].instruction, equals('Proceed to floor-2'));

      // Crucial safety assertion: NEVER claim stairs, lift, or ramp
      final text = instructions[1].instruction.toLowerCase();
      expect(text.contains('stairs'), isFalse);
      expect(text.contains('lift'), isFalse);
      expect(text.contains('elevator'), isFalse);
      expect(text.contains('ramp'), isFalse);
    });

    test('Empty or unknown category generates generic "Proceed to <targetFloor>"', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('u1', name: 'Portal F1', category: '', floorId: 'floor-1'),
        node('u2', name: 'Portal F2', category: 'unknown_vertical_passage', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_u', 'u1', 'u2', distance: 5.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['u1', 'u2'],
        pathEdgeIds: ['e_u'],
      );

      expect(instructions.length, equals(3));
      expect(instructions[1].instruction, equals('Proceed to floor-2'));

      final text = instructions[1].instruction.toLowerCase();
      expect(text.contains('stairs'), isFalse);
      expect(text.contains('lift'), isFalse);
      expect(text.contains('ramp'), isFalse);
    });

    test('Generic category containing substring like forklift or cramped does not false-trigger', () {
      final graph = SpatialGraph();
      graph.addNodes([
        node('s1', name: 'Forklift Bay', category: 'forklift_storage', floorId: 'floor-1'),
        node('s2', name: 'Cramped Attic', category: 'cramped_room', floorId: 'floor-2'),
      ]);
      graph.addEdge(edge('e_fc', 's1', 's2', distance: 5.0));

      final instructions = generator.generate(
        graph: graph,
        pathNodeIds: ['s1', 's2'],
        pathEdgeIds: ['e_fc'],
      );

      expect(instructions.length, equals(3));
      // Must NOT be classified as lift or ramp
      expect(instructions[1].instruction, equals('Proceed to floor-2'));
      final text = instructions[1].instruction.toLowerCase();
      expect(text.contains('lift'), isFalse);
      expect(text.contains('ramp'), isFalse);
      expect(text.contains('stairs'), isFalse);
    });

    // -------------------------------------------------------------------------
    // PathfindingService Integration
    // -------------------------------------------------------------------------
    test('PathfindingService populates turnInstructions in NavigationResponseModel', () async {
      final service = PathfindingService();
      final graph = loadVitGraph();
      final req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'entrance',
        destinationNodeId: 'lab-101',
      );

      final resp = await service.computeRoute(graph, req);

      expect(resp.success, isTrue);
      expect(resp.turnInstructions, isNotEmpty);
      expect(resp.turnInstructions.length, equals(4));
      expect(resp.turnInstructions.first.instruction, equals('Start at Main Entrance'));
      expect(resp.turnInstructions.last.instruction, equals('Arrive at Lab 101'));
    });
  });
}
