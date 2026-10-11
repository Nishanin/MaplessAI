import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';
import 'package:mapless_ai/features/navigation/services/astar_engine.dart';
import 'package:mapless_ai/features/navigation/services/dijkstra_engine.dart';
import 'package:mapless_ai/features/navigation/services/pathfinding_service.dart';
import 'package:mapless_ai/features/navigation/services/yen_algorithm_engine.dart';

/// Statistical timing summary across multiple measured samples.
class SampledTiming {
  final int samples;
  final double medianMs;
  final double p95Ms;
  final double minMs;
  final double maxMs;

  const SampledTiming({
    required this.samples,
    required this.medianMs,
    required this.p95Ms,
    required this.minMs,
    required this.maxMs,
  });
}

/// Helper that strictly separates warm-up iterations from timed sample runs.
Future<SampledTiming> measureSampledTiming({
  required int warmupRuns,
  required int sampleRuns,
  required FutureOr<void> Function() execute,
}) async {
  // 1. Separate warm-up iterations (timing excluded)
  for (var i = 0; i < warmupRuns; i++) {
    await execute();
  }

  // 2. Measured sample iterations
  final timings = <double>[];
  for (var i = 0; i < sampleRuns; i++) {
    final sw = Stopwatch()..start();
    await execute();
    sw.stop();
    timings.add(sw.elapsedMicroseconds / 1000.0);
  }

  timings.sort();
  final median = timings[timings.length ~/ 2];
  final p95Index = ((timings.length * 0.95).ceil() - 1).clamp(
    0,
    timings.length - 1,
  );
  final p95 = timings[p95Index];

  return SampledTiming(
    samples: sampleRuns,
    medianMs: median,
    p95Ms: p95,
    minMs: timings.first,
    maxMs: timings.last,
  );
}

/// Single benchmark measurement record with statistical distribution.
class BenchmarkRecord {
  final String scenario;
  final String operation;
  final int nodeCount;
  final int edgeCount;
  final int samples;
  final double medianMs;
  final double p95Ms;
  final int nodesExplored;
  final double totalDistance;
  final bool success;
  final Map<String, dynamic> metadata;

  const BenchmarkRecord({
    required this.scenario,
    required this.operation,
    required this.nodeCount,
    required this.edgeCount,
    required this.samples,
    required this.medianMs,
    required this.p95Ms,
    required this.nodesExplored,
    required this.totalDistance,
    required this.success,
    this.metadata = const {},
  });

  @override
  String toString() {
    return '| ${scenario.padRight(8)} | ${operation.padRight(32)} | ${samples.toString().padLeft(3)} runs | ${medianMs.toStringAsFixed(2).padLeft(8)} ms | ${p95Ms.toStringAsFixed(2).padLeft(8)} ms | ${nodeCount.toString().padLeft(5)} nodes | ${edgeCount.toString().padLeft(6)} edges | ${nodesExplored.toString().padLeft(6)} exp | ${totalDistance.toStringAsFixed(1).padLeft(7)} m | ${success ? 'OK' : 'FAIL'} |';
  }
}

/// Node attribute snapshot for deep immutability verification.
class NodeSnapshot {
  final String id;
  final String name;
  final String category;
  final String floorId;
  final double x;
  final double y;
  final bool accessible;
  final Map<String, dynamic> metadata;

  NodeSnapshot.from(NodeModel node)
    : id = node.id,
      name = node.name,
      category = node.category,
      floorId = node.floorId,
      x = node.x,
      y = node.y,
      accessible = node.accessible,
      metadata = Map.unmodifiable(Map.from(node.metadata));
}

/// Edge attribute snapshot for deep immutability verification.
class EdgeSnapshot {
  final String id;
  final String startNodeId;
  final String endNodeId;
  final double distance;
  final double bearing;
  final bool accessible;
  final bool blocked;
  final Map<String, dynamic> metadata;

  EdgeSnapshot.from(EdgeModel edge)
    : id = edge.id,
      startNodeId = edge.startNodeId,
      endNodeId = edge.endNodeId,
      distance = edge.distance,
      bearing = edge.bearing,
      accessible = edge.accessible,
      blocked = edge.blocked,
      metadata = Map.unmodifiable(Map.from(edge.metadata));
}

/// Comprehensive deep snapshot of graph state (nodes, edges, and adjacency lists).
class GraphSnapshot {
  final Map<String, NodeSnapshot> nodes;
  final Map<String, EdgeSnapshot> edges;
  final Map<String, List<String>> outgoingEdgeIds;

  const GraphSnapshot({
    required this.nodes,
    required this.edges,
    required this.outgoingEdgeIds,
  });

  /// Captures an immutable snapshot of all graph attributes and adjacency lists.
  static GraphSnapshot capture(SpatialGraph graph) {
    final nodeMap = <String, NodeSnapshot>{};
    for (final node in graph.allNodes) {
      nodeMap[node.id] = NodeSnapshot.from(node);
    }

    final edgeMap = <String, EdgeSnapshot>{};
    for (final edge in graph.allEdges) {
      edgeMap[edge.id] = EdgeSnapshot.from(edge);
    }

    final adjMap = <String, List<String>>{};
    for (final node in graph.allNodes) {
      adjMap[node.id] = graph
          .getOutgoingEdges(node.id)
          .map((e) => e.id)
          .toList();
    }

    return GraphSnapshot(
      nodes: nodeMap,
      edges: edgeMap,
      outgoingEdgeIds: adjMap,
    );
  }

  /// Asserts that [graph] has not undergone any mutation of attributes or topology.
  void verifyIdentical(SpatialGraph graph) {
    expect(
      graph.nodeCount,
      equals(nodes.length),
      reason: 'Node count must match baseline snapshot',
    );
    expect(
      graph.edgeCount,
      equals(edges.length),
      reason: 'Edge count must match baseline snapshot',
    );

    for (final current in graph.allNodes) {
      final snap = nodes[current.id];
      expect(
        snap,
        isNotNull,
        reason: "Node '${current.id}' must exist in snapshot",
      );
      expect(
        current.name,
        equals(snap!.name),
        reason: "Node '${current.id}' name mutated",
      );
      expect(
        current.category,
        equals(snap.category),
        reason: "Node '${current.id}' category mutated",
      );
      expect(
        current.floorId,
        equals(snap.floorId),
        reason: "Node '${current.id}' floorId mutated",
      );
      expect(
        current.x,
        equals(snap.x),
        reason: "Node '${current.id}' x mutated",
      );
      expect(
        current.y,
        equals(snap.y),
        reason: "Node '${current.id}' y mutated",
      );
      expect(
        current.accessible,
        equals(snap.accessible),
        reason: "Node '${current.id}' accessible mutated",
      );
      expect(
        current.metadata,
        equals(snap.metadata),
        reason: "Node '${current.id}' metadata mutated",
      );
    }

    for (final current in graph.allEdges) {
      final snap = edges[current.id];
      expect(
        snap,
        isNotNull,
        reason: "Edge '${current.id}' must exist in snapshot",
      );
      expect(
        current.startNodeId,
        equals(snap!.startNodeId),
        reason: "Edge '${current.id}' startNodeId mutated",
      );
      expect(
        current.endNodeId,
        equals(snap.endNodeId),
        reason: "Edge '${current.id}' endNodeId mutated",
      );
      expect(
        current.distance,
        equals(snap.distance),
        reason: "Edge '${current.id}' distance mutated",
      );
      expect(
        current.bearing,
        equals(snap.bearing),
        reason: "Edge '${current.id}' bearing mutated",
      );
      expect(
        current.accessible,
        equals(snap.accessible),
        reason: "Edge '${current.id}' accessible mutated",
      );
      expect(
        current.blocked,
        equals(snap.blocked),
        reason: "Edge '${current.id}' blocked mutated",
      );
      expect(
        current.metadata,
        equals(snap.metadata),
        reason: "Edge '${current.id}' metadata mutated",
      );
    }

    for (final node in graph.allNodes) {
      final snapAdj = outgoingEdgeIds[node.id]!;
      final currentAdj = graph
          .getOutgoingEdges(node.id)
          .map((e) => e.id)
          .toList();
      expect(
        currentAdj,
        equals(snapAdj),
        reason: "Adjacency order mutated for node '${node.id}'",
      );
    }
  }
}

/// Verifies strict structural and domain correctness properties on calculated routes.
void verifyRouteCorrectness({
  required SpatialGraph graph,
  required List<String> pathNodeIds,
  required List<String> pathEdgeIds,
  required double totalDistance,
  bool requireAccessible = false,
  bool requireAvoidStairs = false,
  bool requireSkipBlocked = true,
  Set<String> excludedNodeIds = const {},
  Set<String> excludedEdgeIds = const {},
}) {
  expect(
    pathNodeIds.isNotEmpty,
    isTrue,
    reason: 'Path nodes must not be empty',
  );
  if (pathNodeIds.length == 1) {
    expect(pathEdgeIds, isEmpty);
    expect(totalDistance, equals(0.0));
    return;
  }
  expect(
    pathEdgeIds.length,
    equals(pathNodeIds.length - 1),
    reason: 'Edge count must be node count - 1',
  );

  double edgeSum = 0.0;
  for (var i = 0; i < pathEdgeIds.length; i++) {
    final edgeId = pathEdgeIds[i];
    final fromNodeId = pathNodeIds[i];
    final toNodeId = pathNodeIds[i + 1];

    final edge = graph.getEdge(edgeId);
    expect(edge, isNotNull, reason: "Edge '$edgeId' exists in spatial graph");
    expect(
      edge!.startNodeId,
      equals(fromNodeId),
      reason: "Edge '$edgeId' start matches path node '$fromNodeId'",
    );
    expect(
      edge.endNodeId,
      equals(toNodeId),
      reason: "Edge '$edgeId' end matches next path node '$toNodeId'",
    );

    if (requireSkipBlocked) {
      expect(
        edge.blocked,
        isFalse,
        reason: "Edge '$edgeId' in route must not be marked blocked",
      );
    }
    if (excludedEdgeIds.isNotEmpty) {
      expect(
        excludedEdgeIds.contains(edge.id),
        isFalse,
        reason: "Edge '$edgeId' must not be in excluded edges set",
      );
    }
    if (requireAccessible) {
      expect(
        edge.accessible,
        isTrue,
        reason: "Edge '$edgeId' must be wheelchair accessible",
      );
      if (i < pathEdgeIds.length - 1) {
        final toNode = graph.getNode(toNodeId)!;
        expect(
          toNode.accessible,
          isTrue,
          reason: "Intermediate node '$toNodeId' must be wheelchair accessible",
        );
      }
    }
    if (requireAvoidStairs) {
      final via = edge.metadata['viaType']?.toString().toLowerCase();
      expect(
        via != 'stairs',
        isTrue,
        reason: "Edge '$edgeId' must not be stairs when avoidStairs is active",
      );
    }
    if (excludedNodeIds.isNotEmpty && i < pathEdgeIds.length - 1) {
      expect(
        excludedNodeIds.contains(toNodeId),
        isFalse,
        reason: "Intermediate node '$toNodeId' must not be in excluded nodes",
      );
    }

    edgeSum += edge.distance;
  }

  expect(
    totalDistance,
    closeTo(edgeSum, 1e-6),
    reason: 'Reported totalDistance must exactly equal sum of edge distances',
  );
}

/// Synthetic indoor graph generator producing deterministic, realistic
/// multi-floor indoor corridor/room topologies.
class SyntheticGraphBuilder {
  final int floors;
  final int rows;
  final int cols;
  final Set<int> stairColIndices;
  final Set<int> elevatorColIndices;
  final int exitsPerFloor;
  final double nodeSpacingMeters;
  final double floorHeightMeters;

  const SyntheticGraphBuilder({
    required this.floors,
    required this.rows,
    required this.cols,
    this.stairColIndices = const {0},
    this.elevatorColIndices = const {4},
    this.exitsPerFloor = 2,
    this.nodeSpacingMeters = 2.5,
    this.floorHeightMeters = 4.0,
  });

  String nodeId(int f, int r, int c) => 'n_f${f}_r${r}_c$c';

  /// Generates the deterministic [SpatialGraph].
  SpatialGraph build({Set<String> blockedEdgeKeys = const {}}) {
    final nodes = <NodeModel>[];
    final edges = <EdgeModel>[];

    // 1. Generate Nodes
    for (var f = 1; f <= floors; f++) {
      final floorId = 'floor-$f';
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final id = nodeId(f, r, c);
          final x = c * nodeSpacingMeters;
          final y = r * nodeSpacingMeters;

          // Categorize nodes
          final isStairCol =
              stairColIndices.contains(c) && (r == 0 || r == rows - 1);
          final isElevatorCol =
              elevatorColIndices.contains(c) && (r == rows ~/ 2);
          final isExit = f == 1 && (r == 0 && c < exitsPerFloor);

          String category = 'corridor';
          bool accessible = true;
          Map<String, dynamic> metadata = {};

          if (isExit) {
            category = 'emergency_exit';
            metadata = {'isEmergencyExit': true};
          } else if (isStairCol) {
            category = 'stairs';
            accessible = false;
          } else if (isElevatorCol) {
            category = 'elevator';
            accessible = true;
          } else if (r % 2 == 1 && c % 2 == 1) {
            category = 'room';
          }

          nodes.add(
            NodeModel(
              id: id,
              name: 'Node F$f R$r C$c',
              category: category,
              floorId: floorId,
              x: x,
              y: y,
              accessible: accessible,
              metadata: metadata,
            ),
          );
        }
      }
    }

    // 2. Generate Horizontal In-Floor Edges (bidirectional)
    for (var f = 1; f <= floors; f++) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final uId = nodeId(f, r, c);

          // Horizontal neighbor: (r, c) <-> (r, c + 1)
          if (c + 1 < cols) {
            final vId = nodeId(f, r, c + 1);
            final keyForward = '$uId->$vId';
            final keyBackward = '$vId->$uId';
            final isBlockedForward = blockedEdgeKeys.contains(keyForward);
            final isBlockedBackward = blockedEdgeKeys.contains(keyBackward);

            edges.add(
              EdgeModel(
                id: 'e_f${f}_h_${r}_${c}_fwd',
                startNodeId: uId,
                endNodeId: vId,
                distance: nodeSpacingMeters,
                bearing: 90.0,
                accessible: true,
                blocked: isBlockedForward,
              ),
            );
            edges.add(
              EdgeModel(
                id: 'e_f${f}_h_${r}_${c}_bwd',
                startNodeId: vId,
                endNodeId: uId,
                distance: nodeSpacingMeters,
                bearing: 270.0,
                accessible: true,
                blocked: isBlockedBackward,
              ),
            );
          }

          // Vertical corridor neighbor: (r, c) <-> (r + 1, c)
          if (r + 1 < rows) {
            final vId = nodeId(f, r + 1, c);
            final keyForward = '$uId->$vId';
            final keyBackward = '$vId->$uId';
            final isBlockedForward = blockedEdgeKeys.contains(keyForward);
            final isBlockedBackward = blockedEdgeKeys.contains(keyBackward);

            edges.add(
              EdgeModel(
                id: 'e_f${f}_v_${r}_${c}_fwd',
                startNodeId: uId,
                endNodeId: vId,
                distance: nodeSpacingMeters,
                bearing: 180.0,
                accessible: true,
                blocked: isBlockedForward,
              ),
            );
            edges.add(
              EdgeModel(
                id: 'e_f${f}_v_${r}_${c}_bwd',
                startNodeId: vId,
                endNodeId: uId,
                distance: nodeSpacingMeters,
                bearing: 0.0,
                accessible: true,
                blocked: isBlockedBackward,
              ),
            );
          }
        }
      }
    }

    // 3. Generate Vertical Connectors between Adjacent Floors
    for (var f = 1; f < floors; f++) {
      final fNext = f + 1;

      // Stairs connectors
      for (final c in stairColIndices) {
        for (final r in [0, rows - 1]) {
          final uId = nodeId(f, r, c);
          final vId = nodeId(fNext, r, c);

          edges.add(
            EdgeModel(
              id: 'e_stairs_up_f${f}_to_f${fNext}_r${r}_c$c',
              startNodeId: uId,
              endNodeId: vId,
              distance: floorHeightMeters,
              bearing: 0.0,
              accessible: false,
              blocked: false,
              metadata: const {'viaType': 'stairs', 'connectorType': 'stairs'},
            ),
          );
          edges.add(
            EdgeModel(
              id: 'e_stairs_down_f${fNext}_to_f${f}_r${r}_c$c',
              startNodeId: vId,
              endNodeId: uId,
              distance: floorHeightMeters,
              bearing: 180.0,
              accessible: false,
              blocked: false,
              metadata: const {'viaType': 'stairs', 'connectorType': 'stairs'},
            ),
          );
        }
      }

      // Elevator connectors
      for (final c in elevatorColIndices) {
        final r = rows ~/ 2;
        final uId = nodeId(f, r, c);
        final vId = nodeId(fNext, r, c);

        edges.add(
          EdgeModel(
            id: 'e_elevator_up_f${f}_to_f${fNext}_r${r}_c$c',
            startNodeId: uId,
            endNodeId: vId,
            distance: floorHeightMeters,
            bearing: 0.0,
            accessible: true,
            blocked: false,
            metadata: const {
              'viaType': 'elevator',
              'connectorType': 'elevator',
            },
          ),
        );
        edges.add(
          EdgeModel(
            id: 'e_elevator_down_f${fNext}_to_f${f}_r${r}_c$c',
            startNodeId: vId,
            endNodeId: uId,
            distance: floorHeightMeters,
            bearing: 180.0,
            accessible: true,
            blocked: false,
            metadata: const {
              'viaType': 'elevator',
              'connectorType': 'elevator',
            },
          ),
        );
      }
    }

    return SpatialGraph.fromNodesAndEdges(nodes, edges);
  }
}

void main() {
  final allRecords = <BenchmarkRecord>[];

  void record(BenchmarkRecord rec) {
    allRecords.add(rec);
  }

  void printSummaryTable() {
    // ignore: avoid_print
    print(
      '\n===================================================================================================================================================',
    );
    // ignore: avoid_print
    print(
      '| SCALE    | OPERATION                        | SAMPLES  | MEDIAN (ms) | P95 (ms)    | NODES       | EDGES        | EXPLORED   | DISTANCE  | STATUS |',
    );
    // ignore: avoid_print
    print(
      '===================================================================================================================================================',
    );
    for (final rec in allRecords) {
      // ignore: avoid_print
      print(rec);
    }
    // ignore: avoid_print
    print(
      '===================================================================================================================================================\n',
    );
  }

  group('Navigation Engine Performance & Scalability Benchmarks', () {
    const dijkstraEngine = DijkstraEngine();
    const astarEngine = AStarEngine();
    const yenEngine = YenAlgorithmEngine();
    final pathfindingService = PathfindingService(
      dijkstraEngine: dijkstraEngine,
      astarEngine: astarEngine,
      yenEngine: yenEngine,
    );

    // -------------------------------------------------------------------------
    // 1. SMALL GRAPH (~100 nodes)
    // -------------------------------------------------------------------------
    group('1. Small Indoor Graph (~100 nodes)', () {
      late SpatialGraph smallGraph;
      const builder = SyntheticGraphBuilder(
        floors: 2,
        rows: 5,
        cols: 10,
        stairColIndices: {0},
        elevatorColIndices: {5},
        exitsPerFloor: 2,
      );

      final startNodeId = builder.nodeId(2, 4, 9); // Floor 2 corner
      final destNodeId = builder.nodeId(1, 0, 0); // Floor 1 opposite corner

      test('A. Graph Construction & Validation (Isolated & Sampled)', () async {
        // Measure Construction timing in isolation
        final buildTiming = await measureSampledTiming(
          warmupRuns: 2,
          sampleRuns: 5,
          execute: () {
            smallGraph = builder.build();
          },
        );

        record(
          BenchmarkRecord(
            scenario: 'Small',
            operation: 'Graph Construction',
            nodeCount: smallGraph.nodeCount,
            edgeCount: smallGraph.edgeCount,
            samples: buildTiming.samples,
            medianMs: buildTiming.medianMs,
            p95Ms: buildTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: true,
          ),
        );

        // Measure Validation timing in isolation
        final valTiming = await measureSampledTiming(
          warmupRuns: 2,
          sampleRuns: 5,
          execute: () {
            smallGraph.validate(
              options: const GraphQualityOptions(
                checkDuplicateEdges: true,
                checkDeadEnds: true,
                checkEmergencyExits: true,
              ),
            );
          },
        );

        final validation = smallGraph.validate();
        expect(validation.isValid, isTrue);
        expect(validation.errors, isEmpty);

        record(
          BenchmarkRecord(
            scenario: 'Small',
            operation: 'Graph Validation',
            nodeCount: smallGraph.nodeCount,
            edgeCount: smallGraph.edgeCount,
            samples: valTiming.samples,
            medianMs: valTiming.medianMs,
            p95Ms: valTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: validation.isValid,
            metadata: {'warnings': validation.warnings.length},
          ),
        );
      });

      test(
        'B. Dijkstra vs A* Route Computation (Separate Warm-up & Samples)',
        () async {
          late DijkstraResult dijkstraResult;
          late AStarResult astarResult;

          // Isolated Dijkstra timing (warmup + 10 samples)
          final dijkstraTiming = await measureSampledTiming(
            warmupRuns: 3,
            sampleRuns: 10,
            execute: () {
              dijkstraResult = dijkstraEngine.findShortestPath(
                smallGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          // Isolated A* timing (warmup + 10 samples)
          final astarTiming = await measureSampledTiming(
            warmupRuns: 3,
            sampleRuns: 10,
            execute: () {
              astarResult = astarEngine.findShortestPath(
                smallGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          expect(dijkstraResult.found, isTrue);
          expect(astarResult.found, isTrue);
          expect(
            astarResult.totalDistance,
            closeTo(dijkstraResult.totalDistance, 1e-6),
          );

          // Correctness Verification (excluded from timing)
          verifyRouteCorrectness(
            graph: smallGraph,
            pathNodeIds: dijkstraResult.pathNodeIds,
            pathEdgeIds: dijkstraResult.pathEdgeIds,
            totalDistance: dijkstraResult.totalDistance,
          );
          verifyRouteCorrectness(
            graph: smallGraph,
            pathNodeIds: astarResult.pathNodeIds,
            pathEdgeIds: astarResult.pathEdgeIds,
            totalDistance: astarResult.totalDistance,
          );

          record(
            BenchmarkRecord(
              scenario: 'Small',
              operation: 'Dijkstra Route',
              nodeCount: smallGraph.nodeCount,
              edgeCount: smallGraph.edgeCount,
              samples: dijkstraTiming.samples,
              medianMs: dijkstraTiming.medianMs,
              p95Ms: dijkstraTiming.p95Ms,
              nodesExplored: dijkstraResult.nodesExplored,
              totalDistance: dijkstraResult.totalDistance,
              success: dijkstraResult.found,
            ),
          );

          record(
            BenchmarkRecord(
              scenario: 'Small',
              operation: 'A* Route',
              nodeCount: smallGraph.nodeCount,
              edgeCount: smallGraph.edgeCount,
              samples: astarTiming.samples,
              medianMs: astarTiming.medianMs,
              p95Ms: astarTiming.p95Ms,
              nodesExplored: astarResult.nodesExplored,
              totalDistance: astarResult.totalDistance,
              success: astarResult.found,
              metadata: {'heuristicActive': astarResult.heuristicActive},
            ),
          );
        },
      );

      test(
        'C. Accessibility Routing Exercising Real Stair-vs-Elevator Choice',
        () async {
          // Start directly above the stairs at (0, 0)
          final stairStartId = builder.nodeId(2, 0, 0);
          final stairDestId = builder.nodeId(1, 0, 0);

          // 1. Unconstrained routing takes the adjacent stairs directly (optimal path)
          final unconstrained = dijkstraEngine.findShortestPath(
            smallGraph,
            stairStartId,
            stairDestId,
          );
          expect(unconstrained.found, isTrue);
          expect(unconstrained.totalDistance, equals(4.0)); // 1 stair hop
          expect(
            unconstrained.pathEdgeIds.any((e) => e.contains('stairs')),
            isTrue,
          );

          // 2. Wheelchair accessibility forces detour away from stairs to the elevator
          final req = NavigationRequestModel(
            buildingId: 'synthetic-bld',
            startNodeId: stairStartId,
            destinationNodeId: stairDestId,
            preferences: const NavigationPreferencesModel(
              accessible: true,
              avoidStairs: true,
              avoidBlockedEdges: true,
            ),
          );

          late NavigationResponseModel response;
          final timing = await measureSampledTiming(
            warmupRuns: 2,
            sampleRuns: 5,
            execute: () async {
              response = await pathfindingService.computeRoute(smallGraph, req);
            },
          );

          expect(response.success, isTrue);
          // Meaningful choice proven: distance is longer because it must walk to elevator at c=5 and back
          expect(
            response.totalDistance,
            greaterThan(unconstrained.totalDistance),
          );
          expect(response.floorTransitions.length, equals(1));
          expect(response.floorTransitions.first.viaType, equals('elevator'));
          expect(response.edgeIds.any((e) => e.contains('stairs')), isFalse);

          verifyRouteCorrectness(
            graph: smallGraph,
            pathNodeIds: response.pathNodeIds,
            pathEdgeIds: response.edgeIds,
            totalDistance: response.totalDistance,
            requireAccessible: true,
            requireAvoidStairs: true,
          );

          record(
            BenchmarkRecord(
              scenario: 'Small',
              operation: 'Accessible Routing (Stair Detour)',
              nodeCount: smallGraph.nodeCount,
              edgeCount: smallGraph.edgeCount,
              samples: timing.samples,
              medianMs: timing.medianMs,
              p95Ms: timing.p95Ms,
              nodesExplored: response.nodesExplored,
              totalDistance: response.totalDistance,
              success: response.success,
            ),
          );
        },
      );

      test('D. Emergency-Exit Selection & Optimality (Sampled)', () async {
        late NavigationResponseModel emergencyResponse;
        final timing = await measureSampledTiming(
          warmupRuns: 2,
          sampleRuns: 5,
          execute: () async {
            emergencyResponse = await pathfindingService.computeEmergencyRoute(
              smallGraph,
              startNodeId,
            );
          },
        );

        expect(emergencyResponse.success, isTrue);
        expect(
          emergencyResponse.pathNodeIds.last.startsWith('n_f1_r0_c'),
          isTrue,
        );

        verifyRouteCorrectness(
          graph: smallGraph,
          pathNodeIds: emergencyResponse.pathNodeIds,
          pathEdgeIds: emergencyResponse.edgeIds,
          totalDistance: emergencyResponse.totalDistance,
        );

        // Verify exit optimality: distance to chosen exit <= distance to any other exit
        final exit0 = dijkstraEngine.findShortestPath(
          smallGraph,
          startNodeId,
          builder.nodeId(1, 0, 0),
        );
        final exit1 = dijkstraEngine.findShortestPath(
          smallGraph,
          startNodeId,
          builder.nodeId(1, 0, 1),
        );
        final minExitDist = math.min(exit0.totalDistance, exit1.totalDistance);
        expect(emergencyResponse.totalDistance, closeTo(minExitDist, 1e-6));

        record(
          BenchmarkRecord(
            scenario: 'Small',
            operation: 'Emergency Routing',
            nodeCount: smallGraph.nodeCount,
            edgeCount: smallGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: emergencyResponse.nodesExplored,
            totalDistance: emergencyResponse.totalDistance,
            success: emergencyResponse.success,
          ),
        );
      });

      test('E. Alternative Routes (Yen K = 1, 3, 5 Sampled)', () async {
        for (final k in [1, 3, 5]) {
          late YenResult yenRes;
          final timing = await measureSampledTiming(
            warmupRuns: 1,
            sampleRuns: 3,
            execute: () {
              yenRes = yenEngine.findKShortestPaths(
                smallGraph,
                startNodeId,
                destNodeId,
                k: k,
              );
            },
          );

          expect(yenRes.found, isTrue);
          expect(yenRes.paths.length, equals(k));

          // Invariant: strictly loopless and sorted by distance
          for (var i = 0; i < yenRes.paths.length; i++) {
            final p = yenRes.paths[i];
            expect(p.nodeIds.toSet().length, equals(p.nodeIds.length));
            verifyRouteCorrectness(
              graph: smallGraph,
              pathNodeIds: p.nodeIds,
              pathEdgeIds: p.edgeIds,
              totalDistance: p.totalDistance,
            );
            if (i > 0) {
              expect(
                p.totalDistance,
                greaterThanOrEqualTo(yenRes.paths[i - 1].totalDistance - 1e-6),
              );
            }
          }

          record(
            BenchmarkRecord(
              scenario: 'Small',
              operation: 'Yen Alternative Routes (K=$k)',
              nodeCount: smallGraph.nodeCount,
              edgeCount: smallGraph.edgeCount,
              samples: timing.samples,
              medianMs: timing.medianMs,
              p95Ms: timing.p95Ms,
              nodesExplored: yenRes.totalNodesExplored,
              totalDistance: yenRes.paths.first.totalDistance,
              success: yenRes.found,
            ),
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // 2. MEDIUM GRAPH (~1,000 nodes)
    // -------------------------------------------------------------------------
    group('2. Medium Indoor Graph (~1,000 nodes)', () {
      late SpatialGraph mediumGraph;
      const builder = SyntheticGraphBuilder(
        floors: 2,
        rows: 20,
        cols: 25,
        stairColIndices: {0, 24},
        elevatorColIndices: {6, 18},
        exitsPerFloor: 4,
      );

      final startNodeId = builder.nodeId(2, 19, 24); // Floor 2 corner
      final destNodeId = builder.nodeId(1, 0, 0); // Floor 1 opposite corner

      test('A. Graph Construction & Validation (Sampled)', () async {
        final buildTiming = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () {
            mediumGraph = builder.build();
          },
        );

        record(
          BenchmarkRecord(
            scenario: 'Medium',
            operation: 'Graph Construction',
            nodeCount: mediumGraph.nodeCount,
            edgeCount: mediumGraph.edgeCount,
            samples: buildTiming.samples,
            medianMs: buildTiming.medianMs,
            p95Ms: buildTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: true,
          ),
        );

        final valTiming = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () {
            mediumGraph.validate(
              options: const GraphQualityOptions(
                checkDuplicateEdges: true,
                checkDeadEnds: true,
                checkEmergencyExits: true,
              ),
            );
          },
        );

        final validation = mediumGraph.validate();
        expect(validation.isValid, isTrue);

        record(
          BenchmarkRecord(
            scenario: 'Medium',
            operation: 'Graph Validation',
            nodeCount: mediumGraph.nodeCount,
            edgeCount: mediumGraph.edgeCount,
            samples: valTiming.samples,
            medianMs: valTiming.medianMs,
            p95Ms: valTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: validation.isValid,
          ),
        );
      });

      test(
        'B. Dijkstra vs A* Point-to-Point Route Computation (Sampled)',
        () async {
          late DijkstraResult dijkstraResult;
          late AStarResult astarResult;

          final dijkstraTiming = await measureSampledTiming(
            warmupRuns: 2,
            sampleRuns: 5,
            execute: () {
              dijkstraResult = dijkstraEngine.findShortestPath(
                mediumGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          final astarTiming = await measureSampledTiming(
            warmupRuns: 2,
            sampleRuns: 5,
            execute: () {
              astarResult = astarEngine.findShortestPath(
                mediumGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          expect(dijkstraResult.found, isTrue);
          expect(astarResult.found, isTrue);
          expect(
            astarResult.totalDistance,
            closeTo(dijkstraResult.totalDistance, 1e-6),
          );

          verifyRouteCorrectness(
            graph: mediumGraph,
            pathNodeIds: dijkstraResult.pathNodeIds,
            pathEdgeIds: dijkstraResult.pathEdgeIds,
            totalDistance: dijkstraResult.totalDistance,
          );
          verifyRouteCorrectness(
            graph: mediumGraph,
            pathNodeIds: astarResult.pathNodeIds,
            pathEdgeIds: astarResult.pathEdgeIds,
            totalDistance: astarResult.totalDistance,
          );

          record(
            BenchmarkRecord(
              scenario: 'Medium',
              operation: 'Dijkstra Route',
              nodeCount: mediumGraph.nodeCount,
              edgeCount: mediumGraph.edgeCount,
              samples: dijkstraTiming.samples,
              medianMs: dijkstraTiming.medianMs,
              p95Ms: dijkstraTiming.p95Ms,
              nodesExplored: dijkstraResult.nodesExplored,
              totalDistance: dijkstraResult.totalDistance,
              success: dijkstraResult.found,
            ),
          );

          record(
            BenchmarkRecord(
              scenario: 'Medium',
              operation: 'A* Route',
              nodeCount: mediumGraph.nodeCount,
              edgeCount: mediumGraph.edgeCount,
              samples: astarTiming.samples,
              medianMs: astarTiming.medianMs,
              p95Ms: astarTiming.p95Ms,
              nodesExplored: astarResult.nodesExplored,
              totalDistance: astarResult.totalDistance,
              success: astarResult.found,
              metadata: {'heuristicActive': astarResult.heuristicActive},
            ),
          );
        },
      );

      test('C. Blocked-Edge Scenario Exercising Real Detour', () async {
        final detourStart = builder.nodeId(2, 10, 9);
        final detourDest = builder.nodeId(2, 10, 11);

        // 1. Unblocked graph: direct 2-edge path has distance 5.0m
        final unblockedRes = dijkstraEngine.findShortestPath(
          mediumGraph,
          detourStart,
          detourDest,
        );
        expect(unblockedRes.found, isTrue);
        expect(unblockedRes.totalDistance, equals(5.0)); // 2 hops * 2.5m

        // 2. Block the direct corridor segment (10, 9) <-> (10, 10)
        final blockedKeyFwd =
            '${builder.nodeId(2, 10, 9)}->${builder.nodeId(2, 10, 10)}';
        final blockedKeyBwd =
            '${builder.nodeId(2, 10, 10)}->${builder.nodeId(2, 10, 9)}';
        final blockedGraph = builder.build(
          blockedEdgeKeys: {blockedKeyFwd, blockedKeyBwd},
        );

        late DijkstraResult blockedRes;
        final timing = await measureSampledTiming(
          warmupRuns: 2,
          sampleRuns: 5,
          execute: () {
            blockedRes = dijkstraEngine.findShortestPath(
              blockedGraph,
              detourStart,
              detourDest,
            );
          },
        );

        expect(blockedRes.found, isTrue);
        // Meaningful detour proven: blocked route is longer than the direct 5.0m corridor
        expect(
          blockedRes.totalDistance,
          greaterThan(unblockedRes.totalDistance),
        );
        expect(
          blockedRes.totalDistance,
          equals(10.0),
        ); // Detour around corridor grid
        expect(blockedRes.pathEdgeIds.contains('e_f2_h_10_9_fwd'), isFalse);

        verifyRouteCorrectness(
          graph: blockedGraph,
          pathNodeIds: blockedRes.pathNodeIds,
          pathEdgeIds: blockedRes.pathEdgeIds,
          totalDistance: blockedRes.totalDistance,
          requireSkipBlocked: true,
        );

        record(
          BenchmarkRecord(
            scenario: 'Medium',
            operation: 'Blocked-Edge Real Detour',
            nodeCount: blockedGraph.nodeCount,
            edgeCount: blockedGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: blockedRes.nodesExplored,
            totalDistance: blockedRes.totalDistance,
            success: blockedRes.found,
          ),
        );
      });

      test('D. Accessibility-Constrained Routing (Sampled)', () async {
        final req = NavigationRequestModel(
          buildingId: 'synthetic-bld',
          startNodeId: startNodeId,
          destinationNodeId: destNodeId,
          preferences: const NavigationPreferencesModel(
            accessible: true,
            avoidStairs: true,
            avoidBlockedEdges: true,
          ),
        );

        late NavigationResponseModel response;
        final timing = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () async {
            response = await pathfindingService.computeRoute(mediumGraph, req);
          },
        );

        expect(response.success, isTrue);
        expect(response.floorTransitions.first.viaType, equals('elevator'));

        verifyRouteCorrectness(
          graph: mediumGraph,
          pathNodeIds: response.pathNodeIds,
          pathEdgeIds: response.edgeIds,
          totalDistance: response.totalDistance,
          requireAccessible: true,
          requireAvoidStairs: true,
        );

        record(
          BenchmarkRecord(
            scenario: 'Medium',
            operation: 'Accessible Routing',
            nodeCount: mediumGraph.nodeCount,
            edgeCount: mediumGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: response.nodesExplored,
            totalDistance: response.totalDistance,
            success: response.success,
          ),
        );
      });

      test('E. Emergency-Exit Selection (Sampled)', () async {
        late NavigationResponseModel emergencyResponse;
        final timing = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () async {
            emergencyResponse = await pathfindingService.computeEmergencyRoute(
              mediumGraph,
              startNodeId,
            );
          },
        );

        expect(emergencyResponse.success, isTrue);

        verifyRouteCorrectness(
          graph: mediumGraph,
          pathNodeIds: emergencyResponse.pathNodeIds,
          pathEdgeIds: emergencyResponse.edgeIds,
          totalDistance: emergencyResponse.totalDistance,
        );

        record(
          BenchmarkRecord(
            scenario: 'Medium',
            operation: 'Emergency Routing',
            nodeCount: mediumGraph.nodeCount,
            edgeCount: mediumGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: emergencyResponse.nodesExplored,
            totalDistance: emergencyResponse.totalDistance,
            success: emergencyResponse.success,
          ),
        );
      });

      test('F. Alternative Routes (Yen K = 1, 3, 5 Sampled)', () async {
        for (final k in [1, 3, 5]) {
          late YenResult yenRes;
          final timing = await measureSampledTiming(
            warmupRuns: 1,
            sampleRuns: 2,
            execute: () {
              yenRes = yenEngine.findKShortestPaths(
                mediumGraph,
                startNodeId,
                destNodeId,
                k: k,
              );
            },
          );

          expect(yenRes.found, isTrue);
          expect(yenRes.paths.length, equals(k));

          for (final p in yenRes.paths) {
            expect(p.nodeIds.toSet().length, equals(p.nodeIds.length));
            verifyRouteCorrectness(
              graph: mediumGraph,
              pathNodeIds: p.nodeIds,
              pathEdgeIds: p.edgeIds,
              totalDistance: p.totalDistance,
            );
          }

          record(
            BenchmarkRecord(
              scenario: 'Medium',
              operation: 'Yen Alternative Routes (K=$k)',
              nodeCount: mediumGraph.nodeCount,
              edgeCount: mediumGraph.edgeCount,
              samples: timing.samples,
              medianMs: timing.medianMs,
              p95Ms: timing.p95Ms,
              nodesExplored: yenRes.totalNodesExplored,
              totalDistance: yenRes.paths.first.totalDistance,
              success: yenRes.found,
            ),
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // 3. LARGE GRAPH (~5,000 nodes)
    // -------------------------------------------------------------------------
    group('3. Large Indoor Graph (~5,000 nodes)', () {
      late SpatialGraph largeGraph;
      const builder = SyntheticGraphBuilder(
        floors: 5,
        rows: 25,
        cols: 40,
        stairColIndices: {0, 39},
        elevatorColIndices: {10, 29},
        exitsPerFloor: 4,
      );

      final startNodeId = builder.nodeId(5, 24, 39); // Top floor corner
      final destNodeId = builder.nodeId(
        1,
        0,
        0,
      ); // Ground floor opposite corner

      test('A. Graph Construction & Validation (Sampled)', () async {
        final buildTiming = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () {
            largeGraph = builder.build();
          },
        );

        record(
          BenchmarkRecord(
            scenario: 'Large',
            operation: 'Graph Construction',
            nodeCount: largeGraph.nodeCount,
            edgeCount: largeGraph.edgeCount,
            samples: buildTiming.samples,
            medianMs: buildTiming.medianMs,
            p95Ms: buildTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: true,
          ),
        );

        final valTiming = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 3,
          execute: () {
            largeGraph.validate(
              options: const GraphQualityOptions(
                checkDuplicateEdges: true,
                checkDeadEnds: true,
                checkEmergencyExits: true,
              ),
            );
          },
        );

        final validation = largeGraph.validate();
        expect(validation.isValid, isTrue);

        record(
          BenchmarkRecord(
            scenario: 'Large',
            operation: 'Graph Validation',
            nodeCount: largeGraph.nodeCount,
            edgeCount: largeGraph.edgeCount,
            samples: valTiming.samples,
            medianMs: valTiming.medianMs,
            p95Ms: valTiming.p95Ms,
            nodesExplored: 0,
            totalDistance: 0.0,
            success: validation.isValid,
          ),
        );
      });

      test(
        'B. Dijkstra vs A* Point-to-Point Route Computation (Sampled)',
        () async {
          late DijkstraResult dijkstraResult;
          late AStarResult astarResult;

          final dijkstraTiming = await measureSampledTiming(
            warmupRuns: 1,
            sampleRuns: 3,
            execute: () {
              dijkstraResult = dijkstraEngine.findShortestPath(
                largeGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          final astarTiming = await measureSampledTiming(
            warmupRuns: 1,
            sampleRuns: 3,
            execute: () {
              astarResult = astarEngine.findShortestPath(
                largeGraph,
                startNodeId,
                destNodeId,
              );
            },
          );

          expect(dijkstraResult.found, isTrue);
          expect(astarResult.found, isTrue);
          expect(
            astarResult.totalDistance,
            closeTo(dijkstraResult.totalDistance, 1e-6),
          );

          verifyRouteCorrectness(
            graph: largeGraph,
            pathNodeIds: dijkstraResult.pathNodeIds,
            pathEdgeIds: dijkstraResult.pathEdgeIds,
            totalDistance: dijkstraResult.totalDistance,
          );
          verifyRouteCorrectness(
            graph: largeGraph,
            pathNodeIds: astarResult.pathNodeIds,
            pathEdgeIds: astarResult.pathEdgeIds,
            totalDistance: astarResult.totalDistance,
          );

          record(
            BenchmarkRecord(
              scenario: 'Large',
              operation: 'Dijkstra Route',
              nodeCount: largeGraph.nodeCount,
              edgeCount: largeGraph.edgeCount,
              samples: dijkstraTiming.samples,
              medianMs: dijkstraTiming.medianMs,
              p95Ms: dijkstraTiming.p95Ms,
              nodesExplored: dijkstraResult.nodesExplored,
              totalDistance: dijkstraResult.totalDistance,
              success: dijkstraResult.found,
            ),
          );

          record(
            BenchmarkRecord(
              scenario: 'Large',
              operation: 'A* Route',
              nodeCount: largeGraph.nodeCount,
              edgeCount: largeGraph.edgeCount,
              samples: astarTiming.samples,
              medianMs: astarTiming.medianMs,
              p95Ms: astarTiming.p95Ms,
              nodesExplored: astarResult.nodesExplored,
              totalDistance: astarResult.totalDistance,
              success: astarResult.found,
              metadata: {'heuristicActive': astarResult.heuristicActive},
            ),
          );
        },
      );

      test('C. Accessibility-Constrained Routing (Sampled)', () async {
        final req = NavigationRequestModel(
          buildingId: 'synthetic-bld',
          startNodeId: startNodeId,
          destinationNodeId: destNodeId,
          preferences: const NavigationPreferencesModel(
            accessible: true,
            avoidStairs: true,
            avoidBlockedEdges: true,
          ),
        );

        late NavigationResponseModel response;
        final timing = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 2,
          execute: () async {
            response = await pathfindingService.computeRoute(largeGraph, req);
          },
        );

        expect(response.success, isTrue);
        for (final t in response.floorTransitions) {
          expect(t.viaType, equals('elevator'));
        }

        verifyRouteCorrectness(
          graph: largeGraph,
          pathNodeIds: response.pathNodeIds,
          pathEdgeIds: response.edgeIds,
          totalDistance: response.totalDistance,
          requireAccessible: true,
          requireAvoidStairs: true,
        );

        record(
          BenchmarkRecord(
            scenario: 'Large',
            operation: 'Accessible Routing',
            nodeCount: largeGraph.nodeCount,
            edgeCount: largeGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: response.nodesExplored,
            totalDistance: response.totalDistance,
            success: response.success,
          ),
        );
      });

      test('D. Emergency-Exit Selection (Sampled)', () async {
        late NavigationResponseModel emergencyResponse;
        final timing = await measureSampledTiming(
          warmupRuns: 1,
          sampleRuns: 2,
          execute: () async {
            emergencyResponse = await pathfindingService.computeEmergencyRoute(
              largeGraph,
              startNodeId,
            );
          },
        );

        expect(emergencyResponse.success, isTrue);

        verifyRouteCorrectness(
          graph: largeGraph,
          pathNodeIds: emergencyResponse.pathNodeIds,
          pathEdgeIds: emergencyResponse.edgeIds,
          totalDistance: emergencyResponse.totalDistance,
        );

        record(
          BenchmarkRecord(
            scenario: 'Large',
            operation: 'Emergency Routing',
            nodeCount: largeGraph.nodeCount,
            edgeCount: largeGraph.edgeCount,
            samples: timing.samples,
            medianMs: timing.medianMs,
            p95Ms: timing.p95Ms,
            nodesExplored: emergencyResponse.nodesExplored,
            totalDistance: emergencyResponse.totalDistance,
            success: emergencyResponse.success,
          ),
        );
      });

      test('E. Alternative Routes (Yen K = 1, 3, 5 Sampled)', () async {
        for (final k in [1, 3, 5]) {
          late YenResult yenRes;
          final timing = await measureSampledTiming(
            warmupRuns: 0,
            sampleRuns: 1,
            execute: () {
              yenRes = yenEngine.findKShortestPaths(
                largeGraph,
                startNodeId,
                destNodeId,
                k: k,
              );
            },
          );

          expect(yenRes.found, isTrue);
          expect(yenRes.paths.length, equals(k));

          for (final p in yenRes.paths) {
            expect(p.nodeIds.toSet().length, equals(p.nodeIds.length));
            verifyRouteCorrectness(
              graph: largeGraph,
              pathNodeIds: p.nodeIds,
              pathEdgeIds: p.edgeIds,
              totalDistance: p.totalDistance,
            );
          }

          record(
            BenchmarkRecord(
              scenario: 'Large',
              operation: 'Yen Alternative Routes (K=$k)',
              nodeCount: largeGraph.nodeCount,
              edgeCount: largeGraph.edgeCount,
              samples: timing.samples,
              medianMs: timing.medianMs,
              p95Ms: timing.p95Ms,
              nodesExplored: yenRes.totalNodesExplored,
              totalDistance: yenRes.paths.first.totalDistance,
              success: yenRes.found,
            ),
          );
        }
      });
    });

    // -------------------------------------------------------------------------
    // 4. DEEP GRAPH IMMUTABILITY SNAPSHOTS & DETERMINISM
    // -------------------------------------------------------------------------
    test('4. Deep Graph Immutability Snapshots & Determinism', () async {
      const builder = SyntheticGraphBuilder(
        floors: 2,
        rows: 5,
        cols: 10,
        stairColIndices: {0},
        elevatorColIndices: {5},
      );
      final graph = builder.build();

      // Deep snapshot capturing all node attributes, edge attributes, and adjacency order
      final baselineSnapshot = GraphSnapshot.capture(graph);

      final startId = builder.nodeId(2, 4, 9);
      final destId = builder.nodeId(1, 0, 0);

      // Execute 20 repeated runs and verify deterministic byte-identical outputs
      String? baselineSignature;
      for (var run = 0; run < 20; run++) {
        final result = dijkstraEngine.findShortestPath(graph, startId, destId);
        final signature =
            '${result.pathNodeIds.join(">")}:${result.totalDistance}';
        if (baselineSignature == null) {
          baselineSignature = signature;
        } else {
          expect(signature, equals(baselineSignature));
        }
      }

      // Execute emergency route and Yen alternative search on the same graph
      await pathfindingService.computeEmergencyRoute(graph, startId);
      yenEngine.findKShortestPaths(graph, startId, destId, k: 3);

      // Deep verification that nodes, edges, attributes, and adjacency lists are 100% unaltered
      baselineSnapshot.verifyIdentical(graph);

      printSummaryTable();
    });
  });
}
