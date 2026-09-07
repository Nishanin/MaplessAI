import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../domain/spatial_graph.dart';

/// Pathfinding Service Interface & Baseline Implementation
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Full A*, Dijkstra, multi-floor routing, accessibility routing,
/// and turn instruction generation will be implemented by Pratik
/// on branch: feature/pratik-spatial-engine
abstract class IPathfindingService {
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request,
  );
}

class PathfindingService implements IPathfindingService {
  @override
  Future<NavigationResponseModel> computeRoute(
    SpatialGraph graph,
    NavigationRequestModel request,
  ) async {
    // Stub implementation for initial repository setup
    // Verifies graph presence and returns baseline path
    final startNode = graph.getNode(request.startNodeId);
    final destNode = graph.getNode(request.destinationNodeId);

    if (startNode == null || destNode == null) {
      return NavigationResponseModel(
        success: false,
        pathNodeIds: const [],
        totalDistance: 0.0,
        estimatedTimeSeconds: 0.0,
        turnInstructions: const [],
        message: 'Start or destination node not found in spatial graph',
      );
    }

    return NavigationResponseModel(
      success: true,
      pathNodeIds: [request.startNodeId, request.destinationNodeId],
      totalDistance: 15.0,
      estimatedTimeSeconds: 12.0,
      turnInstructions: [
        TurnInstructionModel(
          step: 1,
          instruction: 'Proceed from ${startNode.name} to ${destNode.name}',
          distance: 15.0,
          bearing: 90.0,
          nodeId: destNode.id,
        ),
      ],
      message: 'Route calculated (spatial engine stub)',
    );
  }
}
