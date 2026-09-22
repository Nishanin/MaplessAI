/// Turn instruction submodel
class TurnInstructionModel {
  final int step;
  final String instruction;
  final double distance;
  final double bearing;
  final String? nodeId;

  const TurnInstructionModel({
    required this.step,
    required this.instruction,
    required this.distance,
    required this.bearing,
    this.nodeId,
  });

  factory TurnInstructionModel.fromJson(Map<String, dynamic> json) {
    return TurnInstructionModel(
      step: json['step'] as int,
      instruction: json['instruction'] as String,
      distance: (json['distance'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      nodeId: json['nodeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'instruction': instruction,
      'distance': distance,
      'bearing': bearing,
      if (nodeId != null) 'nodeId': nodeId,
    };
  }
}

/// Floor transition submodel
class FloorTransitionModel {
  final String fromFloorId;
  final String toFloorId;
  final String viaType;
  final String nodeId;

  const FloorTransitionModel({
    required this.fromFloorId,
    required this.toFloorId,
    required this.viaType,
    required this.nodeId,
  });

  factory FloorTransitionModel.fromJson(Map<String, dynamic> json) {
    return FloorTransitionModel(
      fromFloorId: json['fromFloorId'] as String,
      toFloorId: json['toFloorId'] as String,
      viaType: json['viaType'] as String,
      nodeId: json['nodeId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromFloorId': fromFloorId,
      'toFloorId': toFloorId,
      'viaType': viaType,
      'nodeId': nodeId,
    };
  }
}

/// Route status values for NavigationResponseModel.
///
/// A deterministic small set aligned with the project's error conventions.
/// Serialized as a string in the JSON response.
enum RouteStatus {
  /// A valid path was found and the response is complete.
  success,

  /// No path exists between start and destination (disconnected or all blocked).
  noRoute,

  /// The request was structurally invalid (missing/malformed fields).
  invalidRequest,

  /// The start node ID does not exist in the spatial graph.
  startNodeNotFound,

  /// The destination node ID does not exist in the spatial graph.
  destinationNodeNotFound,
}

/// NavigationResponse domain model matching contracts/navigation-response.schema.json
///
/// Phase 4 additions (backward-compatible, schema uses additionalProperties: true):
/// - [routeStatus]: structured status enum for machine-readable outcomes
/// - [algorithm]: identifies which routing engine produced the result
/// - [nodesExplored]: number of unique nodes expanded during search
class NavigationResponseModel {
  final bool success;
  final List<String> pathNodeIds;
  final List<String> edgeIds;
  final double totalDistance;
  final double estimatedTimeSeconds;
  final List<TurnInstructionModel> turnInstructions;
  final List<FloorTransitionModel> floorTransitions;
  final String? message;

  /// Machine-readable route status (Phase 4).
  final RouteStatus routeStatus;

  /// Identifies the routing algorithm that produced this result (Phase 4).
  /// Values: 'dijkstra', 'a_star'
  final String algorithm;

  /// Number of unique nodes expanded during the search (Phase 4).
  /// 0 for trivial start == destination responses or failed lookups.
  final int nodesExplored;

  const NavigationResponseModel({
    required this.success,
    required this.pathNodeIds,
    this.edgeIds = const [],
    required this.totalDistance,
    required this.estimatedTimeSeconds,
    required this.turnInstructions,
    this.floorTransitions = const [],
    this.message,
    this.routeStatus = RouteStatus.success,
    this.algorithm = 'dijkstra',
    this.nodesExplored = 0,
  });

  factory NavigationResponseModel.fromJson(Map<String, dynamic> json) {
    return NavigationResponseModel(
      success: json['success'] as bool,
      pathNodeIds: (json['pathNodeIds'] as List<dynamic>).map((e) => e.toString()).toList(),
      edgeIds: (json['edgeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedTimeSeconds: (json['estimatedTimeSeconds'] as num).toDouble(),
      turnInstructions: (json['turnInstructions'] as List<dynamic>)
          .map((e) => TurnInstructionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      floorTransitions: (json['floorTransitions'] as List<dynamic>?)
              ?.map((e) => FloorTransitionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      message: json['message'] as String?,
      routeStatus: _routeStatusFromString(json['routeStatus'] as String? ?? 'success'),
      algorithm: json['algorithm'] as String? ?? 'dijkstra',
      nodesExplored: json['nodesExplored'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'pathNodeIds': pathNodeIds,
      'edgeIds': edgeIds,
      'totalDistance': totalDistance,
      'estimatedTimeSeconds': estimatedTimeSeconds,
      'turnInstructions': turnInstructions.map((e) => e.toJson()).toList(),
      'floorTransitions': floorTransitions.map((e) => e.toJson()).toList(),
      if (message != null) 'message': message,
      'routeStatus': _routeStatusToString(routeStatus),
      'algorithm': algorithm,
      'nodesExplored': nodesExplored,
    };
  }

  static String _routeStatusToString(RouteStatus status) {
    switch (status) {
      case RouteStatus.success:
        return 'success';
      case RouteStatus.noRoute:
        return 'no_route';
      case RouteStatus.invalidRequest:
        return 'invalid_request';
      case RouteStatus.startNodeNotFound:
        return 'start_node_not_found';
      case RouteStatus.destinationNodeNotFound:
        return 'destination_node_not_found';
    }
  }

  static RouteStatus _routeStatusFromString(String value) {
    switch (value) {
      case 'no_route':
        return RouteStatus.noRoute;
      case 'invalid_request':
        return RouteStatus.invalidRequest;
      case 'start_node_not_found':
        return RouteStatus.startNodeNotFound;
      case 'destination_node_not_found':
        return RouteStatus.destinationNodeNotFound;
      default:
        return RouteStatus.success;
    }
  }
}

