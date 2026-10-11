import 'dart:math' as math;

import '../../../core/errors/exceptions.dart';
import '../domain/spatial_graph.dart';
import 'astar_engine.dart';
import 'dijkstra_engine.dart';
import 'pathfinding_service.dart';
import 'traversal_policy.dart';

/// Single candidate path discovered during Yen's algorithm execution.
/// Owner: Pratik (Spatial Intelligence Domain)
class YenPath {
  /// True if a valid path was found.
  final bool found;

  /// Ordered node IDs from start to destination.
  final List<String> nodeIds;

  /// Ordered edge IDs traversed along the path.
  final List<String> edgeIds;

  /// Total cumulative distance of the path in meters.
  final double totalDistance;

  /// Number of unique nodes expanded during this specific path search.
  final int nodesExplored;

  const YenPath({
    this.found = true,
    required this.nodeIds,
    required this.edgeIds,
    required this.totalDistance,
    this.nodesExplored = 0,
  });

  /// Path identity signature based on node sequence.
  String get nodeSignature => nodeIds.join('->');

  /// Full path identity signature combining node sequence and edge sequence.
  String get signature => '${nodeIds.join("->")}|${edgeIds.join("->")}';

  @override
  String toString() =>
      'YenPath(found: $found, nodes: ${nodeIds.length}, '
      'dist: $totalDistance, path: $nodeSignature)';
}

/// Result of Yen's K-shortest loopless paths search.
/// Owner: Pratik (Spatial Intelligence Domain)
class YenResult {
  /// True if at least one valid path was found.
  final bool found;

  /// Ranked list of loopless paths (from shortest to longest).
  final List<YenPath> paths;

  /// Total number of unique nodes expanded across all search iterations.
  final int totalNodesExplored;

  const YenResult({
    required this.found,
    this.paths = const [],
    this.totalNodesExplored = 0,
  });

  @override
  String toString() =>
      'YenResult(found: $found, paths: ${paths.length}, explored: $totalNodesExplored)';
}

/// Deterministic implementation of Yen's K-Shortest Loopless Paths Algorithm (1971).
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Discovers up to K distinct, loopless paths ranked in ascending order of actual
/// cumulative distance: d(P_0) <= d(P_1) <= ... <= d(P_{K-1}).
///
/// Key Properties:
/// 1. Loopless Guarantee: Root prefix nodes prior to the spur node are strictly
///    excluded during spur search, guaranteeing zero self-intersecting loops.
/// 2. Graph Immutability: Zero graph mutation. Temporary deviations and root
///    exclusions are enforced purely during edge relaxation via [TraversalPolicy].
/// 3. Reuses Existing Engines: Delegates baseline and spur path searches to
///    [DijkstraEngine] and [AStarEngine].
/// 4. Deterministic Tie-Breaking: When two alternative candidate paths have equal
///    cumulative distance, paths are ordered deterministically by node signature.
/// 5. Policy Compatibility: Respects all [TraversalPolicy] constraints including
///    blocked edges, wheelchair accessibility, and stair avoidance.
class YenAlgorithmEngine {
  /// Maximum number of alternative routes supported.
  static const int maxK = 5;

  final DijkstraEngine _dijkstraEngine;
  final AStarEngine _astarEngine;

  const YenAlgorithmEngine({
    DijkstraEngine? dijkstraEngine,
    AStarEngine? astarEngine,
  })  : _dijkstraEngine = dijkstraEngine ?? const DijkstraEngine(),
        _astarEngine = astarEngine ?? const AStarEngine();

  /// Computes up to [k] shortest loopless paths from [startNodeId] to
  /// [destinationNodeId] in [graph].
  ///
  /// Throws [GraphException] if [startNodeId] or [destinationNodeId] do not exist.
  /// Throws [ArgumentError] if [k] < 1.
  YenResult findKShortestPaths(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId, {
    int k = 3,
    TraversalPolicy? policy,
    NavigationAlgorithm algorithm = NavigationAlgorithm.dijkstra,
  }) {
    if (k < 1) {
      throw ArgumentError.value(k, 'k', 'k must be greater than or equal to 1');
    }

    if (!graph.hasNode(startNodeId)) {
      throw GraphException(
        "Start node '$startNodeId' does not exist in the graph.",
        code: 'START_NODE_NOT_FOUND',
      );
    }

    if (!graph.hasNode(destinationNodeId)) {
      throw GraphException(
        "Destination node '$destinationNodeId' does not exist in the graph.",
        code: 'DESTINATION_NODE_NOT_FOUND',
      );
    }

    final effectiveK = math.min(k, maxK);

    // Trivial case: start == destination
    if (startNodeId == destinationNodeId) {
      return YenResult(
        found: true,
        paths: [
          YenPath(
            found: true,
            nodeIds: [startNodeId],
            edgeIds: const [],
            totalDistance: 0.0,
            nodesExplored: 0,
          ),
        ],
        totalNodesExplored: 0,
      );
    }

    final basePolicy = policy ??
        TraversalPolicy(
          destinationNodeId: destinationNodeId,
        );

    int totalNodesExplored = 0;

    // 1. Compute the first shortest path A[0]
    final initialPath = _findSinglePath(
      graph,
      startNodeId,
      destinationNodeId,
      basePolicy,
      algorithm,
    );
    totalNodesExplored += initialPath.nodesExplored;

    if (!initialPath.found) {
      return YenResult(
        found: false,
        paths: const [],
        totalNodesExplored: totalNodesExplored,
      );
    }

    final A = <YenPath>[initialPath];
    final aSignatures = <String>{initialPath.signature};

    if (effectiveK == 1) {
      return YenResult(
        found: true,
        paths: A,
        totalNodesExplored: totalNodesExplored,
      );
    }

    // Candidate pool B
    final B = <YenPath>[];
    final bSignatures = <String>{};

    // 2. Iteratively discover A[1] ... A[effectiveK - 1]
    for (var targetK = 1; targetK < effectiveK; targetK++) {
      final previousPath = A[targetK - 1];

      // Spur node index i ranges from 0 to previousPath.nodeIds.length - 2
      for (var i = 0; i < previousPath.nodeIds.length - 1; i++) {
        final spurNodeId = previousPath.nodeIds[i];
        final rootNodeIds = previousPath.nodeIds.sublist(0, i + 1);
        final rootEdgeIds = previousPath.edgeIds.sublist(0, i);

        // Edges branching from spurNodeId already used by any previously accepted
        // path in A that shares this exact root prefix (both nodes and edges) must be excluded.
        final excludedEdgeIds = <String>{};
        for (final p in A) {
          if (p.nodeIds.length > i &&
              _listEquals(p.nodeIds.sublist(0, i + 1), rootNodeIds) &&
              _listEquals(p.edgeIds.sublist(0, i), rootEdgeIds)) {
            if (p.edgeIds.length > i) {
              excludedEdgeIds.add(p.edgeIds[i]);
            }
          }
        }

        // Nodes in the root prefix strictly before the spur node are excluded
        // to prevent the spur path from looping back into the root prefix.
        final excludedNodeIds = <String>{};
        for (var j = 0; j < i; j++) {
          excludedNodeIds.add(rootNodeIds[j]);
        }

        final spurPolicy = basePolicy.copyWith(
          excludedNodeIds: {
            ...basePolicy.excludedNodeIds,
            ...excludedNodeIds,
          },
          excludedEdgeIds: {
            ...basePolicy.excludedEdgeIds,
            ...excludedEdgeIds,
          },
          destinationNodeId: destinationNodeId,
        );

        // Compute spur path from spurNodeId to destinationNodeId
        final spurPath = _findSinglePath(
          graph,
          spurNodeId,
          destinationNodeId,
          spurPolicy,
          algorithm,
        );
        totalNodesExplored += spurPath.nodesExplored;

        if (spurPath.found) {
          // Construct candidate path = root path prefix + spur path
          final candidateNodeIds = [
            ...rootNodeIds.sublist(0, i),
            ...spurPath.nodeIds,
          ];
          final candidateEdgeIds = [
            ...rootEdgeIds,
            ...spurPath.edgeIds,
          ];

          // Recompute cumulative edge distance directly from candidate edges to avoid
          // floating-point drift or reliance on accumulated partial sums.
          double candidateDistance = 0.0;
          for (final edgeId in candidateEdgeIds) {
            final edge = graph.getEdge(edgeId);
            if (edge != null) {
              candidateDistance += edge.distance;
            }
          }

          // Verify candidate path is strictly loopless
          if (candidateNodeIds.toSet().length == candidateNodeIds.length) {
            final candidate = YenPath(
              found: true,
              nodeIds: candidateNodeIds,
              edgeIds: candidateEdgeIds,
              totalDistance: candidateDistance,
              nodesExplored: spurPath.nodesExplored,
            );

            // Deduplicate against A and B
            if (!aSignatures.contains(candidate.signature) &&
                !bSignatures.contains(candidate.signature)) {
              bSignatures.add(candidate.signature);
              B.add(candidate);
            }
          }
        }
      }

      if (B.isEmpty) {
        // No more alternative paths exist in the graph
        break;
      }

      // Sort candidate pool B by cumulative distance, with deterministic tie-breaking
      B.sort((p1, p2) {
        final distDiff = p1.totalDistance - p2.totalDistance;
        if (distDiff.abs() > 1e-6) {
          return distDiff.compareTo(0.0);
        }
        // Deterministic tie-breaking: node signature, then edge signature
        final nodeComp = p1.nodeSignature.compareTo(p2.nodeSignature);
        if (nodeComp != 0) return nodeComp;
        return p1.signature.compareTo(p2.signature);
      });

      // Move best candidate from B to A
      final bestCandidate = B.removeAt(0);
      bSignatures.remove(bestCandidate.signature);
      aSignatures.add(bestCandidate.signature);
      A.add(bestCandidate);
    }

    return YenResult(
      found: A.isNotEmpty,
      paths: A,
      totalNodesExplored: totalNodesExplored,
    );
  }

  /// Helper to compute a single shortest path using the chosen algorithm engine.
  YenPath _findSinglePath(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId,
    TraversalPolicy policy,
    NavigationAlgorithm algorithm,
  ) {
    switch (algorithm) {
      case NavigationAlgorithm.dijkstra:
        final result = _dijkstraEngine.findShortestPath(
          graph,
          startNodeId,
          destinationNodeId,
          policy: policy,
        );
        return YenPath(
          found: result.found,
          nodeIds: result.pathNodeIds,
          edgeIds: result.pathEdgeIds,
          totalDistance: result.totalDistance,
          nodesExplored: result.nodesExplored,
        );

      case NavigationAlgorithm.aStar:
        final result = _astarEngine.findShortestPath(
          graph,
          startNodeId,
          destinationNodeId,
          policy: policy,
        );
        return YenPath(
          found: result.found,
          nodeIds: result.pathNodeIds,
          edgeIds: result.pathEdgeIds,
          totalDistance: result.totalDistance,
          nodesExplored: result.nodesExplored,
        );
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
