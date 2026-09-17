import '../../../core/errors/exceptions.dart';
import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../domain/spatial_graph.dart';
import 'astar_engine.dart';
import 'dijkstra_engine.dart';
import 'turn_instruction_generator.dart';

/// Algorithm selection for [PathfindingService].
///
/// Internal-only — not exposed in the public NavigationRequest contract.
/// External callers default to [NavigationAlgorithm.dijkstra].
enum NavigationAlgorithm {
  /// Deterministic weighted Dijkstra. Always finds the optimal path.
  dijkstra,

  /// A* with coordinate-based Euclidean heuristic and runtime admissibility
  /// validation. Falls back to h=0 (Dijkstra behavior) when graph violates
  /// the admissibility invariant. Always finds the optimal path.
  aStar,
}

/// Pathfinding Service Interface
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Validates routing requests, invokes the selected pathfinding engine,
/// validates the engine result for internal consistency, and maps
/// the domain result to [NavigationResponseModel].
///
/// Responsibilities (Phase 4 & 5):
/// - algorithm selection (Dijkstra or A*)
/// - request validation (missing nodes)
/// - path consistency validation before constructing the response
/// - ETA calculation
/// - turn instruction generation (Phase 5)
/// - NavigationResponseModel construction
///
/// Does NOT contain pathfinding logic — that belongs to the engines.
abstract class IPathfindingService {
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request, {
    NavigationAlgorithm algorithm,
  });
}

class PathfindingService implements IPathfindingService {
  /// Standard indoor walking speed used for ETA calculation.
  /// Unit: meters per second. Value: 1.2 m/s (~4.3 km/h).
  static const double walkingSpeedMetersPerSecond = 1.2;

  /// Floating-point tolerance for distance consistency checks.
  static const double _distanceTolerance = 1e-6;

  final DijkstraEngine _dijkstraEngine;
  final AStarEngine _astarEngine;
  final TurnInstructionGenerator _turnInstructionGenerator;

  PathfindingService({
    DijkstraEngine? dijkstraEngine,
    AStarEngine? astarEngine,
    TurnInstructionGenerator? turnInstructionGenerator,
  })  : _dijkstraEngine = dijkstraEngine ?? const DijkstraEngine(),
        _astarEngine = astarEngine ?? const AStarEngine(),
        _turnInstructionGenerator =
            turnInstructionGenerator ?? const TurnInstructionGenerator();


  @override
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request, {
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) async {
    // --- Request validation ---
    if (!graph.hasNode(request.startNodeId)) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "Start node '${request.startNodeId}' not found in spatial graph",
        routeStatus: RouteStatus.startNodeNotFound,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: 0,
      );
    }

    if (!graph.hasNode(request.destinationNodeId)) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "Destination node '${request.destinationNodeId}' not found in spatial graph",
        routeStatus: RouteStatus.destinationNodeNotFound,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: 0,
      );
    }

    // --- Engine invocation ---
    final String algorithmLabel;
    final bool found;
    final List<String> pathNodeIds;
    final List<String> pathEdgeIds;
    final double totalDistance;
    final int nodesExplored;

    try {
      switch (algorithm) {
        case NavigationAlgorithm.dijkstra:
          final result = _dijkstraEngine.findShortestPath(
            graph,
            request.startNodeId,
            request.destinationNodeId,
            skipBlocked: request.preferences.avoidBlockedEdges,
          );
          algorithmLabel = 'dijkstra';
          found = result.found;
          pathNodeIds = result.pathNodeIds;
          pathEdgeIds = result.pathEdgeIds;
          totalDistance = result.totalDistance;
          nodesExplored = result.nodesExplored;

        case NavigationAlgorithm.aStar:
          final result = _astarEngine.findShortestPath(
            graph,
            request.startNodeId,
            request.destinationNodeId,
            skipBlocked: request.preferences.avoidBlockedEdges,
          );
          algorithmLabel = 'a_star';
          found = result.found;
          pathNodeIds = result.pathNodeIds;
          pathEdgeIds = result.pathEdgeIds;
          totalDistance = result.totalDistance;
          nodesExplored = result.nodesExplored;
      }
    } on GraphException {
      rethrow;
    }

    // --- No route ---
    if (!found) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "No route found from '${request.startNodeId}' "
            "to '${request.destinationNodeId}'",
        routeStatus: RouteStatus.noRoute,
        algorithm: algorithmLabel,
        nodesExplored: nodesExplored,
      );
    }

    // --- Path consistency validation ---
    final validationError = _validatePath(
      graph: graph,
      request: request,
      pathNodeIds: pathNodeIds,
      pathEdgeIds: pathEdgeIds,
      totalDistance: totalDistance,
    );
    if (validationError != null) {
      throw GraphException(
        'Engine returned an internally inconsistent path: $validationError',
        code: 'INCONSISTENT_ROUTE_RESULT',
      );
    }

    // --- ETA calculation ---
    // For start == destination the engine returns distance 0.0; ETA is 0.
    final eta = totalDistance > 0 ? totalDistance / walkingSpeedMetersPerSecond : 0.0;

    // --- Turn instruction generation ---
    final turnInstructions = _turnInstructionGenerator.generate(
      graph: graph,
      pathNodeIds: pathNodeIds,
      pathEdgeIds: pathEdgeIds,
    );

    // --- Success response ---
    return NavigationResponseModel(
      success: true,
      pathNodeIds: pathNodeIds,
      edgeIds: pathEdgeIds,
      totalDistance: totalDistance,
      estimatedTimeSeconds: eta,
      turnInstructions: turnInstructions,
      message: 'Route calculated via $algorithmLabel',
      routeStatus: RouteStatus.success,
      algorithm: algorithmLabel,
      nodesExplored: nodesExplored,
    );
  }


  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static String _algorithmLabel(NavigationAlgorithm alg) =>
      alg == NavigationAlgorithm.aStar ? 'a_star' : 'dijkstra';

  /// Validates that the engine-returned path is internally self-consistent.
  ///
  /// Returns null if the path is valid, or an error description string if not.
  ///
  /// Checks:
  /// 1. pathNodeIds is non-empty.
  /// 2. First node == requested start.
  /// 3. Last node == requested destination.
  /// 4. Both first and last nodes exist in graph.
  /// 5. Edge count == node count − 1.
  /// 6. Every (pathNodeIds[i], pathNodeIds[i+1]) pair is connected by
  ///    pathEdgeIds[i] in the graph.
  /// 7. totalDistance is finite and non-negative.
  /// 8. totalDistance equals the sum of selected edge distances within tolerance.
  static String? _validatePath({
    required SpatialGraph graph,
    required NavigationRequestModel request,
    required List<String> pathNodeIds,
    required List<String> pathEdgeIds,
    required double totalDistance,
  }) {
    if (pathNodeIds.isEmpty) return 'pathNodeIds is empty';

    if (pathNodeIds.first != request.startNodeId) {
      return 'First path node "${pathNodeIds.first}" != '
          'requested start "${request.startNodeId}"';
    }
    if (pathNodeIds.last != request.destinationNodeId) {
      return 'Last path node "${pathNodeIds.last}" != '
          'requested destination "${request.destinationNodeId}"';
    }

    if (!graph.hasNode(pathNodeIds.first)) {
      return 'First path node "${pathNodeIds.first}" not in graph';
    }
    if (!graph.hasNode(pathNodeIds.last)) {
      return 'Last path node "${pathNodeIds.last}" not in graph';
    }

    final expectedEdgeCount = pathNodeIds.length - 1;
    if (pathEdgeIds.length != expectedEdgeCount) {
      return 'Edge count ${pathEdgeIds.length} != node count − 1 ($expectedEdgeCount)';
    }

    if (totalDistance.isNaN || totalDistance.isInfinite || totalDistance < 0) {
      return 'totalDistance $totalDistance is not a valid non-negative finite number';
    }

    // Verify consecutive node pairs use the stated edges, and accumulate sum
    double edgeSum = 0.0;
    for (var i = 0; i < pathEdgeIds.length; i++) {
      final edgeId = pathEdgeIds[i];
      final fromNodeId = pathNodeIds[i];
      final toNodeId = pathNodeIds[i + 1];

      final edge = graph.getEdge(edgeId);
      if (edge == null) {
        return 'Edge "$edgeId" in pathEdgeIds not found in graph';
      }
      if (edge.startNodeId != fromNodeId || edge.endNodeId != toNodeId) {
        return 'Edge "$edgeId" connects '
            '"${edge.startNodeId}"→"${edge.endNodeId}" '
            'but path requires "$fromNodeId"→"$toNodeId"';
      }
      edgeSum += edge.distance;
    }

    if ((edgeSum - totalDistance).abs() > _distanceTolerance) {
      return 'totalDistance $totalDistance != edge sum $edgeSum '
          '(diff ${(edgeSum - totalDistance).abs()})';
    }

    return null; // valid
  }
}
