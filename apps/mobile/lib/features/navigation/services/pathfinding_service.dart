import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../../../core/models/node_model.dart';
import '../domain/spatial_graph.dart';
import '../models/alternative_routes_result.dart';
import 'astar_engine.dart';
import 'dijkstra_engine.dart';
import 'traversal_policy.dart';
import 'turn_instruction_generator.dart';
import 'yen_algorithm_engine.dart';

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

  /// Computes the optimal evacuation route from [startNodeId] to the nearest
  /// reachable explicitly designated emergency exit in [graph].
  ///
  /// Evaluates candidates using actual graph route distance (not Euclidean distance).
  /// Excludes blocked edges by default and respects active [preferences].
  Future<NavigationResponseModel> computeEmergencyRoute(
    SpatialGraph graph,
    String startNodeId, {
    NavigationPreferencesModel preferences,
    NavigationAlgorithm algorithm,
  });

  /// Computes up to [maxRoutes] distinct loopless alternative routes from
  /// [request.startNodeId] to [request.destinationNodeId] in [graph].
  ///
  /// Routes are returned in ascending order of actual cumulative distance
  /// (primary shortest route first, followed by ranked alternatives).
  /// Respects all active [request.preferences] (blocked edges, accessibility, stairs).
  Future<AlternativeRoutesResult> computeAlternativeRoutes(
    SpatialGraph graph,
    NavigationRequestModel request, {
    int maxRoutes = 3,
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  });

  /// Convenience overload for [computeAlternativeRoutes] taking raw endpoint IDs.
  Future<AlternativeRoutesResult> findAlternativeRoutes(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId, {
    int maxRoutes = 3,
    NavigationPreferencesModel preferences = const NavigationPreferencesModel(),
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
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
  final YenAlgorithmEngine _yenEngine;

  PathfindingService({
    DijkstraEngine? dijkstraEngine,
    AStarEngine? astarEngine,
    TurnInstructionGenerator? turnInstructionGenerator,
    YenAlgorithmEngine? yenEngine,
  })  : _dijkstraEngine = dijkstraEngine ?? const DijkstraEngine(),
        _astarEngine = astarEngine ?? const AStarEngine(),
        _turnInstructionGenerator =
            turnInstructionGenerator ?? const TurnInstructionGenerator(),
        _yenEngine = yenEngine ??
            YenAlgorithmEngine(
              dijkstraEngine: dijkstraEngine,
              astarEngine: astarEngine,
            );


  @override
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request, {
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) async {
    // --- Emergency mode delegation ---
    if (request.preferences.emergencyMode) {
      return computeEmergencyRoute(
        graph,
        request.startNodeId,
        preferences: request.preferences,
        algorithm: algorithm,
      );
    }

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

    final policy = TraversalPolicy.fromPreferences(
      request.preferences,
      destinationNodeId: request.destinationNodeId,
    );

    try {
      switch (algorithm) {
        case NavigationAlgorithm.dijkstra:
          final result = _dijkstraEngine.findShortestPath(
            graph,
            request.startNodeId,
            request.destinationNodeId,
            policy: policy,
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
            policy: policy,
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
      startNodeId: request.startNodeId,
      destinationNodeId: request.destinationNodeId,
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

    // --- Floor transition generation (Phase 6) ---
    final floorTransitions = _buildFloorTransitions(
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
      floorTransitions: floorTransitions,
      message: 'Route calculated via $algorithmLabel',
      routeStatus: RouteStatus.success,
      algorithm: algorithmLabel,
      nodesExplored: nodesExplored,
    );
  }

  @override
  Future<NavigationResponseModel> computeEmergencyRoute(
    SpatialGraph graph,
    String startNodeId, {
    NavigationPreferencesModel preferences = const NavigationPreferencesModel(
      avoidBlockedEdges: true,
      emergencyMode: true,
    ),
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) async {
    // 1. Start node validation
    if (!graph.hasNode(startNodeId)) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "Start node '$startNodeId' not found in spatial graph",
        routeStatus: RouteStatus.startNodeNotFound,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: 0,
      );
    }

    // 2. Identify all explicitly designated emergency exit nodes
    final candidateExits = graph.allNodes.where(_isEmergencyExit).toList();
    if (candidateExits.isEmpty) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "No designated emergency exits found in spatial graph",
        routeStatus: RouteStatus.noRoute,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: 0,
      );
    }

    // 3. Trivial case: user is already at an emergency exit
    final startNode = graph.getNode(startNodeId)!;
    if (_isEmergencyExit(startNode)) {
      final turnInstructions = _turnInstructionGenerator.generate(
        graph: graph,
        pathNodeIds: [startNodeId],
        pathEdgeIds: const [],
      );
      return NavigationResponseModel(
        success: true,
        pathNodeIds: [startNodeId],
        edgeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: turnInstructions,
        floorTransitions: const [],
        message: 'Already at emergency exit "${startNode.name}"',
        routeStatus: RouteStatus.success,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: 0,
      );
    }

    // 4. Evaluate reachable candidate exits using actual graph path costs
    NodeModel? bestExit;
    List<String> bestPathNodeIds = const [];
    List<String> bestPathEdgeIds = const [];
    double bestDistance = double.infinity;
    int totalNodesExplored = 0;

    for (final exitNode in candidateExits) {
      final policy = TraversalPolicy.fromPreferences(
        preferences,
        destinationNodeId: exitNode.id,
      );

      final bool found;
      final List<String> pathNodeIds;
      final List<String> pathEdgeIds;
      final double totalDistance;
      final int nodesExplored;

      switch (algorithm) {
        case NavigationAlgorithm.dijkstra:
          final result = _dijkstraEngine.findShortestPath(
            graph,
            startNodeId,
            exitNode.id,
            policy: policy,
          );
          found = result.found;
          pathNodeIds = result.pathNodeIds;
          pathEdgeIds = result.pathEdgeIds;
          totalDistance = result.totalDistance;
          nodesExplored = result.nodesExplored;

        case NavigationAlgorithm.aStar:
          final result = _astarEngine.findShortestPath(
            graph,
            startNodeId,
            exitNode.id,
            policy: policy,
          );
          found = result.found;
          pathNodeIds = result.pathNodeIds;
          pathEdgeIds = result.pathEdgeIds;
          totalDistance = result.totalDistance;
          nodesExplored = result.nodesExplored;
      }

      totalNodesExplored += nodesExplored;

      if (found && totalDistance < bestDistance) {
        bestDistance = totalDistance;
        bestExit = exitNode;
        bestPathNodeIds = pathNodeIds;
        bestPathEdgeIds = pathEdgeIds;
      }
    }

    // 5. No reachable emergency exit
    if (bestExit == null) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "No reachable emergency exit found from '$startNodeId'",
        routeStatus: RouteStatus.noRoute,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: totalNodesExplored,
      );
    }

    // 6. Path consistency validation
    final validationError = _validatePath(
      graph: graph,
      startNodeId: startNodeId,
      destinationNodeId: bestExit.id,
      pathNodeIds: bestPathNodeIds,
      pathEdgeIds: bestPathEdgeIds,
      totalDistance: bestDistance,
    );
    if (validationError != null) {
      throw GraphException(
        'Engine returned an internally inconsistent path: $validationError',
        code: 'INCONSISTENT_ROUTE_RESULT',
      );
    }

    // 7. Metric, instruction, and transition generation
    final eta = bestDistance > 0 ? bestDistance / walkingSpeedMetersPerSecond : 0.0;

    final turnInstructions = _turnInstructionGenerator.generate(
      graph: graph,
      pathNodeIds: bestPathNodeIds,
      pathEdgeIds: bestPathEdgeIds,
    );

    final floorTransitions = _buildFloorTransitions(
      graph: graph,
      pathNodeIds: bestPathNodeIds,
      pathEdgeIds: bestPathEdgeIds,
    );

    return NavigationResponseModel(
      success: true,
      pathNodeIds: bestPathNodeIds,
      edgeIds: bestPathEdgeIds,
      totalDistance: bestDistance,
      estimatedTimeSeconds: eta,
      turnInstructions: turnInstructions,
      floorTransitions: floorTransitions,
      message: 'Emergency route calculated to "${bestExit.name}" via ${_algorithmLabel(algorithm)}',
      routeStatus: RouteStatus.success,
      algorithm: _algorithmLabel(algorithm),
      nodesExplored: totalNodesExplored,
    );
  }

  @override
  Future<AlternativeRoutesResult> findAlternativeRoutes(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId, {
    int maxRoutes = 3,
    NavigationPreferencesModel preferences = const NavigationPreferencesModel(),
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) {
    final request = NavigationRequestModel(
      buildingId: 'default',
      startNodeId: startNodeId,
      destinationNodeId: destinationNodeId,
      preferences: preferences,
    );
    return computeAlternativeRoutes(
      graph,
      request,
      maxRoutes: maxRoutes,
      algorithm: algorithm,
    );
  }

  @override
  Future<AlternativeRoutesResult> computeAlternativeRoutes(
    SpatialGraph graph,
    NavigationRequestModel request, {
    int maxRoutes = 3,
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) async {
    // 1. Parameter validation
    if (maxRoutes <= 0) {
      return AlternativeRoutesResult(
        success: false,
        routes: const [],
        comparisons: const [],
        routeStatus: RouteStatus.invalidRequest,
        message: 'maxRoutes must be >= 1 (got $maxRoutes)',
        algorithm: _algorithmLabel(algorithm),
        totalNodesExplored: 0,
      );
    }

    // 2. Start node validation
    if (!graph.hasNode(request.startNodeId)) {
      return AlternativeRoutesResult(
        success: false,
        routes: const [],
        comparisons: const [],
        routeStatus: RouteStatus.startNodeNotFound,
        message: "Start node '${request.startNodeId}' not found in spatial graph",
        algorithm: _algorithmLabel(algorithm),
        totalNodesExplored: 0,
      );
    }

    // 3. Destination node validation
    if (!graph.hasNode(request.destinationNodeId)) {
      return AlternativeRoutesResult(
        success: false,
        routes: const [],
        comparisons: const [],
        routeStatus: RouteStatus.destinationNodeNotFound,
        message: "Destination node '${request.destinationNodeId}' not found in spatial graph",
        algorithm: _algorithmLabel(algorithm),
        totalNodesExplored: 0,
      );
    }

    // 4. Construct traversal policy
    final policy = TraversalPolicy.fromPreferences(
      request.preferences,
      destinationNodeId: request.destinationNodeId,
    );

    // 5. Invoke Yen algorithm engine
    final yenResult = _yenEngine.findKShortestPaths(
      graph,
      request.startNodeId,
      request.destinationNodeId,
      k: maxRoutes,
      policy: policy,
      algorithm: algorithm,
    );

    if (!yenResult.found || yenResult.paths.isEmpty) {
      return AlternativeRoutesResult(
        success: false,
        routes: const [],
        comparisons: const [],
        routeStatus: RouteStatus.noRoute,
        message: "No route found from '${request.startNodeId}' "
            "to '${request.destinationNodeId}'",
        algorithm: _algorithmLabel(algorithm),
        totalNodesExplored: yenResult.totalNodesExplored,
      );
    }

    // 6. Map each YenPath to NavigationResponseModel and RouteComparisonModel
    final routeModels = <NavigationResponseModel>[];
    final comparisons = <RouteComparisonModel>[];

    double primaryDistance = 0.0;
    double primaryEta = 0.0;

    for (var i = 0; i < yenResult.paths.length; i++) {
      final path = yenResult.paths[i];

      // Validate path integrity
      final validationError = _validatePath(
        graph: graph,
        startNodeId: request.startNodeId,
        destinationNodeId: request.destinationNodeId,
        pathNodeIds: path.nodeIds,
        pathEdgeIds: path.edgeIds,
        totalDistance: path.totalDistance,
      );
      if (validationError != null) {
        throw GraphException(
          'Engine returned an internally inconsistent path: $validationError',
          code: 'INCONSISTENT_ROUTE_RESULT',
        );
      }

      final eta = path.totalDistance > 0
          ? path.totalDistance / walkingSpeedMetersPerSecond
          : 0.0;

      final turnInstructions = _turnInstructionGenerator.generate(
        graph: graph,
        pathNodeIds: path.nodeIds,
        pathEdgeIds: path.edgeIds,
      );

      final floorTransitions = _buildFloorTransitions(
        graph: graph,
        pathNodeIds: path.nodeIds,
        pathEdgeIds: path.edgeIds,
      );

      if (i == 0) {
        primaryDistance = path.totalDistance;
        primaryEta = eta;
      }

      final routeModel = NavigationResponseModel(
        success: true,
        pathNodeIds: path.nodeIds,
        edgeIds: path.edgeIds,
        totalDistance: path.totalDistance,
        estimatedTimeSeconds: eta,
        turnInstructions: turnInstructions,
        floorTransitions: floorTransitions,
        message: i == 0
            ? 'Primary route calculated via ${_algorithmLabel(algorithm)}'
            : 'Alternative route #$i calculated via ${_algorithmLabel(algorithm)}',
        routeStatus: RouteStatus.success,
        algorithm: _algorithmLabel(algorithm),
        nodesExplored: path.nodesExplored,
      );

      final comparison = RouteComparisonModel(
        routeIndex: i,
        route: routeModel,
        totalDistance: path.totalDistance,
        estimatedTimeSeconds: eta,
        floorTransitionCount: floorTransitions.length,
        pathNodeIds: path.nodeIds,
        edgeIds: path.edgeIds,
        distanceDeltaFromPrimary: path.totalDistance - primaryDistance,
        timeDeltaFromPrimary: eta - primaryEta,
      );

      routeModels.add(routeModel);
      comparisons.add(comparison);
    }

    return AlternativeRoutesResult(
      success: true,
      routes: routeModels,
      comparisons: comparisons,
      routeStatus: RouteStatus.success,
      message: 'Generated ${routeModels.length} route(s) via ${_algorithmLabel(algorithm)}',
      algorithm: _algorithmLabel(algorithm),
      totalNodesExplored: yenResult.totalNodesExplored,
    );
  }

  /// Returns true if [node] is explicitly designated as an emergency exit.
  ///
  /// Inspects canonical category 'emergency_exit' and explicit boolean metadata flags.
  /// Does NOT classify ordinary entrances, doors, or corridors as emergency exits.
  static bool _isEmergencyExit(NodeModel node) {
    final cat = node.category.trim().toLowerCase();
    if (cat == 'emergency_exit' || cat == 'emergency-exit' || cat == 'emergency exit') {
      return true;
    }
    final meta = node.metadata;
    if (meta['isEmergencyExit'] == true || meta['emergencyExit'] == true) {
      return true;
    }
    return false;
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
    required String startNodeId,
    required String destinationNodeId,
    required List<String> pathNodeIds,
    required List<String> pathEdgeIds,
    required double totalDistance,
  }) {
    if (pathNodeIds.isEmpty) return 'pathNodeIds is empty';

    if (pathNodeIds.first != startNodeId) {
      return 'First path node "${pathNodeIds.first}" != '
          'requested start "$startNodeId"';
    }
    if (pathNodeIds.last != destinationNodeId) {
      return 'Last path node "${pathNodeIds.last}" != '
          'requested destination "$destinationNodeId"';
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

  /// Extracts multi-floor transition records from a validated route path.
  ///
  /// Conforms to contracts/navigation-response.schema.json:
  /// - [fromFloorId]: ID of origin floor
  /// - [toFloorId]: ID of destination floor
  /// - [viaType]: Strictly one of "stairs", "elevator", "ramp"
  /// - [nodeId]: ID of the arrival node on the destination floor
  static List<FloorTransitionModel> _buildFloorTransitions({
    required SpatialGraph graph,
    required List<String> pathNodeIds,
    required List<String> pathEdgeIds,
  }) {
    final transitions = <FloorTransitionModel>[];

    for (var i = 0; i < pathNodeIds.length - 1; i++) {
      final fromNode = graph.getNode(pathNodeIds[i])!;
      final toNode = graph.getNode(pathNodeIds[i + 1])!;

      if (fromNode.floorId != toNode.floorId) {
        final edge = graph.getEdge(pathEdgeIds[i])!;
        final viaType = _detectContractViaType(fromNode, toNode, edge);

        transitions.add(
          FloorTransitionModel(
            fromFloorId: fromNode.floorId,
            toFloorId: toNode.floorId,
            viaType: viaType,
            nodeId: toNode.id,
          ),
        );
      }
    }

    return transitions;
  }

  static Set<String> _extractCategoryTokens(NodeModel node) {
    final cat = node.category.trim().toLowerCase();
    if (cat.isEmpty) return const {};
    return cat.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toSet();
  }

  /// Determines the contract-compliant [viaType] ('stairs', 'elevator', 'ramp').
  ///
  /// Strictly adheres to contracts/navigation-response.schema.json enum values.
  /// Does NOT emit 'lift' into structured contract data.
  /// Throws [GraphException] if the connector type cannot be determined.
  static String _detectContractViaType(
    NodeModel from,
    NodeModel to,
    EdgeModel edge,
  ) {
    final tokensFrom = _extractCategoryTokens(from);
    final tokensTo = _extractCategoryTokens(to);
    final allTokens = {...tokensFrom, ...tokensTo};

    // Also inspect edge metadata if specified
    final edgeVia = edge.metadata['viaType']?.toString().toLowerCase() ??
        edge.metadata['connectorType']?.toString().toLowerCase();
    if (edgeVia != null) {
      final edgeTokens =
          edgeVia.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty);
      allTokens.addAll(edgeTokens);
    }

    if (allTokens.contains('lift') ||
        allTokens.contains('elevator') ||
        allTokens.contains('elevators') ||
        allTokens.contains('lifts')) {
      return 'elevator';
    }
    if (allTokens.contains('ramp') || allTokens.contains('ramps')) {
      return 'ramp';
    }
    if (allTokens.contains('stairs') ||
        allTokens.contains('staircase') ||
        allTokens.contains('stair') ||
        allTokens.contains('stairwell') ||
        allTokens.contains('stairway')) {
      return 'stairs';
    }

    throw GraphException(
      "Cannot determine valid viaType ('stairs', 'elevator', 'ramp') for floor "
      "transition from '${from.id}' (${from.floorId}) to '${to.id}' (${to.floorId}). "
      "Neither node categories ('${from.category}', '${to.category}') nor edge "
      "metadata specify a recognized vertical connector type.",
      code: 'UNKNOWN_FLOOR_TRANSITION_TYPE',
    );
  }
}
