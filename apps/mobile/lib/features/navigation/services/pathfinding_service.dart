import '../../../core/errors/exceptions.dart';
import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../domain/spatial_graph.dart';
import 'dijkstra_engine.dart';

/// Pathfinding Service Interface & Dijkstra Implementation
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Uses [DijkstraEngine] for weighted shortest-path computation.
/// Respects NavigationPreferencesModel.avoidBlockedEdges (default: true).
///
/// Turn instructions and ETA are NOT implemented in Phase 2.
/// They will be added in later phases.
abstract class IPathfindingService {
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request,
  );
}

class PathfindingService implements IPathfindingService {
  final DijkstraEngine _engine;

  PathfindingService({DijkstraEngine? engine})
      : _engine = engine ?? const DijkstraEngine();

  @override
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request,
  ) async {
    // Validate start node exists
    if (!graph.hasNode(request.startNodeId)) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "Start node '${request.startNodeId}' not found in spatial graph",
      );
    }

    // Validate destination node exists
    if (!graph.hasNode(request.destinationNodeId)) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: "Destination node '${request.destinationNodeId}' not found in spatial graph",
      );
    }

    try {
      final result = _engine.findShortestPath(
        graph,
        request.startNodeId,
        request.destinationNodeId,
        skipBlocked: request.preferences.avoidBlockedEdges,
      );

      if (!result.found) {
        return NavigationResponseModel(
          success: false,
          pathNodeIds: const [],
          totalDistance: 0.0,
          estimatedTimeSeconds: 0.0,
          turnInstructions: const [],
          message: "No route found from '${request.startNodeId}' to '${request.destinationNodeId}'",
        );
      }

      return NavigationResponseModel(
        success: true,
        pathNodeIds: result.pathNodeIds,
        edgeIds: result.pathEdgeIds,
        totalDistance: result.totalDistance,
        // ETA placeholder: standard walking speed ~1.2 m/s (Phase 2 stub)
        estimatedTimeSeconds: result.totalDistance / 1.2,
        // Turn instructions will be implemented in a later phase
        turnInstructions: const [],
        message: 'Route calculated via Dijkstra shortest path',
      );
    } on GraphException {
      rethrow;
    }
  }
}

