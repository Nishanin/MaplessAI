import '../../../core/models/navigation_response_model.dart';

/// Structured comparison metrics for a candidate route relative to the primary route.
/// Owner: Pratik (Spatial Intelligence Domain)
class RouteComparisonModel {
  /// Index of the route in the ranked candidates list (0 = primary).
  final int routeIndex;

  /// Full navigation response model for this route.
  final NavigationResponseModel route;

  /// Total traversal distance in meters.
  final double totalDistance;

  /// Estimated walking time in seconds.
  final double estimatedTimeSeconds;

  /// Total number of vertical floor transitions required.
  final int floorTransitionCount;

  /// Sequence of node IDs from start to destination.
  final List<String> pathNodeIds;

  /// Sequence of edge IDs traversed.
  final List<String> edgeIds;

  /// Distance difference compared to the primary route (positive = longer, 0.0 = primary).
  final double distanceDeltaFromPrimary;

  /// Time difference compared to the primary route in seconds (positive = slower, 0.0 = primary).
  final double timeDeltaFromPrimary;

  const RouteComparisonModel({
    required this.routeIndex,
    required this.route,
    required this.totalDistance,
    required this.estimatedTimeSeconds,
    required this.floorTransitionCount,
    required this.pathNodeIds,
    required this.edgeIds,
    required this.distanceDeltaFromPrimary,
    required this.timeDeltaFromPrimary,
  });

  factory RouteComparisonModel.fromJson(Map<String, dynamic> json) {
    return RouteComparisonModel(
      routeIndex: json['routeIndex'] as int,
      route: NavigationResponseModel.fromJson(
        json['route'] as Map<String, dynamic>,
      ),
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedTimeSeconds: (json['estimatedTimeSeconds'] as num).toDouble(),
      floorTransitionCount: json['floorTransitionCount'] as int,
      pathNodeIds: (json['pathNodeIds'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      edgeIds: (json['edgeIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      distanceDeltaFromPrimary:
          (json['distanceDeltaFromPrimary'] as num).toDouble(),
      timeDeltaFromPrimary: (json['timeDeltaFromPrimary'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'routeIndex': routeIndex,
      'route': route.toJson(),
      'totalDistance': totalDistance,
      'estimatedTimeSeconds': estimatedTimeSeconds,
      'floorTransitionCount': floorTransitionCount,
      'pathNodeIds': pathNodeIds,
      'edgeIds': edgeIds,
      'distanceDeltaFromPrimary': distanceDeltaFromPrimary,
      'timeDeltaFromPrimary': timeDeltaFromPrimary,
    };
  }

  @override
  String toString() =>
      'RouteComparisonModel(index: $routeIndex, distance: $totalDistance, '
      'deltaDist: +$distanceDeltaFromPrimary, deltaTime: +$timeDeltaFromPrimary, '
      'floors: $floorTransitionCount)';
}

/// Result of a multi-route computation containing ranked alternative routes
/// and their comparative analysis.
/// Owner: Pratik (Spatial Intelligence Domain)
class AlternativeRoutesResult {
  /// Whether at least one valid route was found.
  final bool success;

  /// Ranked candidate routes (index 0 is primary / shortest route).
  final List<NavigationResponseModel> routes;

  /// Comparative metrics for each candidate route.
  final List<RouteComparisonModel> comparisons;

  /// Structured route outcome status.
  final RouteStatus routeStatus;

  /// Human-readable diagnostic or summary message.
  final String? message;

  /// Algorithm identifier used to generate the routes.
  final String algorithm;

  /// Total number of unique nodes explored across all search iterations.
  final int totalNodesExplored;

  const AlternativeRoutesResult({
    required this.success,
    required this.routes,
    required this.comparisons,
    this.routeStatus = RouteStatus.success,
    this.message,
    this.algorithm = 'dijkstra',
    this.totalNodesExplored = 0,
  });

  /// The primary (shortest) route, or null if no routes were found.
  NavigationResponseModel? get primaryRoute =>
      routes.isNotEmpty ? routes.first : null;

  /// The list of secondary alternative routes excluding the primary route.
  List<NavigationResponseModel> get alternativeRoutes =>
      routes.length > 1 ? routes.sublist(1) : const [];

  factory AlternativeRoutesResult.fromJson(Map<String, dynamic> json) {
    return AlternativeRoutesResult(
      success: json['success'] as bool,
      routes: (json['routes'] as List<dynamic>)
          .map((e) => NavigationResponseModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      comparisons: (json['comparisons'] as List<dynamic>)
          .map((e) => RouteComparisonModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      routeStatus: _routeStatusFromString(
        json['routeStatus'] as String? ?? 'success',
      ),
      message: json['message'] as String?,
      algorithm: json['algorithm'] as String? ?? 'dijkstra',
      totalNodesExplored: json['totalNodesExplored'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'routes': routes.map((r) => r.toJson()).toList(),
      'comparisons': comparisons.map((c) => c.toJson()).toList(),
      'routeStatus': _routeStatusToString(routeStatus),
      if (message != null) 'message': message,
      'algorithm': algorithm,
      'totalNodesExplored': totalNodesExplored,
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

  @override
  String toString() =>
      'AlternativeRoutesResult(success: $success, routes: ${routes.length}, '
      'status: $routeStatus, algorithm: $algorithm, explored: $totalNodesExplored)';
}
