import 'dart:math' as math;

import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/node_model.dart';
import '../domain/spatial_graph.dart';

/// Result of an A* shortest-path computation.
///
/// Contains the ordered node path, edge IDs, total distance,
/// search metrics, and the algorithm identifier.
class AStarResult {
  /// True if a valid path was found from start to destination.
  final bool found;

  /// Ordered node IDs from start (first) to destination (last).
  /// Empty if [found] is false.
  final List<String> pathNodeIds;

  /// Ordered edge IDs traversed along the path.
  /// Empty if [found] is false.
  final List<String> pathEdgeIds;

  /// Total distance of the shortest path (sum of edge distances).
  /// 0.0 if [found] is false or start == destination.
  final double totalDistance;

  /// Number of unique nodes expanded (removed from PQ and processed).
  /// Does not count stale priority-queue entries.
  /// For start == destination, this is 0 (trivial return, no search).
  final int nodesExplored;

  /// Algorithm identifier.
  final String algorithm;

  /// Whether the Euclidean heuristic was used (true) or the safe
  /// zero-heuristic fallback was applied (false).
  final bool heuristicActive;

  const AStarResult({
    required this.found,
    this.pathNodeIds = const [],
    this.pathEdgeIds = const [],
    this.totalDistance = 0.0,
    this.nodesExplored = 0,
    this.algorithm = 'A*',
    this.heuristicActive = false,
  });

  @override
  String toString() =>
      'AStarResult(found: $found, nodes: ${pathNodeIds.length}, '
      'distance: $totalDistance, explored: $nodesExplored, '
      'heuristic: $heuristicActive)';
}

/// Deterministic A* shortest-path engine with coordinate-based heuristic.
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Operates on [SpatialGraph] using edge.distance as the sole traversal cost.
/// Preserves directed edge semantics and respects blocked-edge exclusion.
///
/// ## Heuristic Design
///
/// The intended heuristic is Euclidean distance between node coordinates:
///
///   h(n) = sqrt((x_n - x_goal)^2 + (y_n - y_goal)^2)
///
/// Coordinates are in meters (NodeModel.x, NodeModel.y).
///
/// ## Admissibility Guarantee
///
/// For A* to guarantee optimal paths, the heuristic must be admissible:
/// h(n) must not overestimate the true minimum cost to reach the goal.
///
/// The project's edge.distance is described as "Physical distance in meters"
/// (edge.schema.json). However, **no code or schema validation enforces**
/// that edge.distance >= Euclidean(startNode, endNode) for every edge.
///
/// Therefore, before using the Euclidean heuristic, A* validates
/// admissibility at runtime by checking every traversable edge in the graph:
///
///   edge.distance >= Euclidean(edge.startNode, edge.endNode)
///
/// If ALL edges satisfy this condition, the Euclidean heuristic is used
/// (providing search-space pruning). If ANY edge violates it, the engine
/// falls back to h(n) = 0 for all nodes, which reduces A* to Dijkstra
/// behavior — correct but without heuristic pruning.
///
/// ## Consistency
///
/// When admissible, the Euclidean heuristic is also consistent because
/// the triangle inequality holds for Euclidean distances:
///
///   h(u) <= Euclidean(u, v) <= distance(u, v) + h(v)
///
/// (since Euclidean satisfies the triangle inequality by definition, and
/// edge.distance >= Euclidean when the admissibility check passes).
///
/// With a consistent heuristic, finalized nodes never need reopening,
/// so the finalized-set optimization is safe.
///
/// When the zero fallback is active, h(n) = 0 is trivially consistent.
///
/// ## Tie-Breaking
///
/// Identical to Dijkstra: strict `<` comparison preserves the first-
/// discovered path. Since SpatialGraph uses insertion-order maps and lists,
/// this guarantees deterministic results across repeated runs.
///
/// ## Complexity
///
/// O((V + E) log V) using a lazy binary min-heap with stale-entry skipping.
///
/// This class has NO dependency on Flutter, UI, SLM, semantic AI, or versioning.
class AStarEngine {
  const AStarEngine();

  /// Computes the shortest path from [startNodeId] to [destinationNodeId]
  /// in the given [graph] using A* with a coordinate-based Euclidean heuristic.
  ///
  /// [skipBlocked]: If true (default), edges with `blocked == true` are
  /// excluded from traversal. Matches the project convention where
  /// `avoidBlockedEdges` defaults to `true` in NavigationPreferencesModel.
  ///
  /// Throws [GraphException] if:
  /// - [startNodeId] does not exist in the graph.
  /// - [destinationNodeId] does not exist in the graph.
  ///
  /// Returns [AStarResult] with `found == false` if the destination is
  /// unreachable from the start.
  ///
  /// If `startNodeId == destinationNodeId`, returns a zero-distance path
  /// containing only that node with nodesExplored = 0.
  AStarResult findShortestPath(
    SpatialGraph graph,
    String startNodeId,
    String destinationNodeId, {
    bool skipBlocked = true,
  }) {
    // Validate that start node exists
    if (!graph.hasNode(startNodeId)) {
      throw GraphException(
        "Start node '$startNodeId' does not exist in the graph.",
        code: 'START_NODE_NOT_FOUND',
      );
    }

    // Validate that destination node exists
    if (!graph.hasNode(destinationNodeId)) {
      throw GraphException(
        "Destination node '$destinationNodeId' does not exist in the graph.",
        code: 'DESTINATION_NODE_NOT_FOUND',
      );
    }

    // Trivial case: start == destination
    if (startNodeId == destinationNodeId) {
      return AStarResult(
        found: true,
        pathNodeIds: [startNodeId],
        pathEdgeIds: const [],
        totalDistance: 0.0,
        nodesExplored: 0,
        heuristicActive: false,
      );
    }

    // Determine heuristic admissibility
    final goalNode = graph.getNode(destinationNodeId)!;
    final heuristicActive = _isHeuristicAdmissible(graph, skipBlocked);

    // g-score map: best known distance from start to each node
    final gScore = <String, double>{};
    gScore[startNodeId] = 0.0;

    // Predecessor map: stores the edge used to reach each node
    final predecessorEdge = <String, EdgeModel>{};

    // Finalized set: nodes whose shortest distance is confirmed
    final finalized = <String>{};

    // Track nodes explored (unique nodes expanded from PQ)
    int nodesExplored = 0;

    // Priority queue ordered by f(n) = g(n) + h(n)
    final pq = _AStarHeap();
    final startH = heuristicActive
        ? _euclidean(graph.getNode(startNodeId)!, goalNode)
        : 0.0;
    pq.insert(startH, 0.0, startNodeId);

    while (pq.isNotEmpty) {
      final entry = pq.removeMin();
      final currentNodeId = entry.nodeId;
      final currentG = entry.gScore;

      // Skip stale entries
      if (finalized.contains(currentNodeId)) continue;
      if (currentG > (gScore[currentNodeId] ?? double.maxFinite)) continue;

      // Finalize this node
      finalized.add(currentNodeId);
      nodesExplored++;

      // Early termination: destination reached
      if (currentNodeId == destinationNodeId) {
        return _reconstructPath(
          startNodeId,
          destinationNodeId,
          predecessorEdge,
          currentG,
          nodesExplored,
          heuristicActive,
        );
      }

      // Relax outgoing edges
      final outgoing = graph.getOutgoingEdges(currentNodeId);
      for (final edge in outgoing) {
        // Skip blocked edges if requested
        if (skipBlocked && edge.blocked) continue;

        final neighborId = edge.endNodeId;

        // Skip already finalized nodes
        if (finalized.contains(neighborId)) continue;

        final newG = currentG + edge.distance;

        // Strict improvement check (< not <=) preserves first-discovered
        // path for deterministic tie-breaking.
        final knownG = gScore[neighborId];
        if (knownG == null || newG < knownG) {
          gScore[neighborId] = newG;
          predecessorEdge[neighborId] = edge;

          final h = heuristicActive
              ? _euclidean(graph.getNode(neighborId)!, goalNode)
              : 0.0;
          final fScore = newG + h;
          pq.insert(fScore, newG, neighborId);
        }
      }
    }

    // Priority queue exhausted without reaching destination
    return AStarResult(
      found: false,
      pathNodeIds: const [],
      pathEdgeIds: const [],
      totalDistance: 0.0,
      nodesExplored: nodesExplored,
      heuristicActive: heuristicActive,
    );
  }

  /// Computes Euclidean distance between two nodes using their (x, y) coords.
  static double _euclidean(NodeModel a, NodeModel b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Validates whether Euclidean distance is an admissible heuristic for
  /// the given graph.
  ///
  /// For admissibility, every traversable edge must satisfy:
  ///   edge.distance >= Euclidean(startNode, endNode)
  ///
  /// If any edge violates this, returns false and the engine will use
  /// h(n) = 0 as a safe fallback.
  bool _isHeuristicAdmissible(SpatialGraph graph, bool skipBlocked) {
    for (final edge in graph.allEdges) {
      // Only check edges that would actually be traversed
      if (skipBlocked && edge.blocked) continue;

      final startNode = graph.getNode(edge.startNodeId);
      final endNode = graph.getNode(edge.endNodeId);
      if (startNode == null || endNode == null) continue;

      final euclidean = _euclidean(startNode, endNode);
      // Use a small tolerance for floating-point comparison
      if (edge.distance < euclidean - 1e-9) {
        return false;
      }
    }
    return true;
  }

  /// Reconstructs the shortest path from predecessor information.
  AStarResult _reconstructPath(
    String startNodeId,
    String destinationNodeId,
    Map<String, EdgeModel> predecessorEdge,
    double totalDistance,
    int nodesExplored,
    bool heuristicActive,
  ) {
    final pathNodes = <String>[];
    final pathEdges = <String>[];

    var current = destinationNodeId;
    while (current != startNodeId) {
      pathNodes.add(current);
      final edge = predecessorEdge[current]!;
      pathEdges.add(edge.id);
      current = edge.startNodeId;
    }
    pathNodes.add(startNodeId);

    return AStarResult(
      found: true,
      pathNodeIds: pathNodes.reversed.toList(),
      pathEdgeIds: pathEdges.reversed.toList(),
      totalDistance: totalDistance,
      nodesExplored: nodesExplored,
      heuristicActive: heuristicActive,
    );
  }
}

/// A priority queue entry for A* pairing an f-score, g-score, and node ID.
class _AStarHeapEntry {
  final double fScore;
  final double gScore;
  final String nodeId;

  const _AStarHeapEntry(this.fScore, this.gScore, this.nodeId);
}

/// A binary min-heap priority queue for A*, ordered by f-score.
///
/// Supports O(log n) insert and O(log n) removeMin.
/// Uses lazy deletion via stale-entry skipping in the algorithm above.
class _AStarHeap {
  final List<_AStarHeapEntry> _data = [];

  bool get isNotEmpty => _data.isNotEmpty;
  bool get isEmpty => _data.isEmpty;

  void insert(double fScore, double gScore, String nodeId) {
    _data.add(_AStarHeapEntry(fScore, gScore, nodeId));
    _bubbleUp(_data.length - 1);
  }

  _AStarHeapEntry removeMin() {
    final min = _data[0];
    final last = _data.removeLast();
    if (_data.isNotEmpty) {
      _data[0] = last;
      _bubbleDown(0);
    }
    return min;
  }

  void _bubbleUp(int index) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      if (_data[index].fScore < _data[parentIndex].fScore) {
        _swap(index, parentIndex);
        index = parentIndex;
      } else {
        break;
      }
    }
  }

  void _bubbleDown(int index) {
    final length = _data.length;
    while (true) {
      var smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;

      if (left < length && _data[left].fScore < _data[smallest].fScore) {
        smallest = left;
      }
      if (right < length && _data[right].fScore < _data[smallest].fScore) {
        smallest = right;
      }

      if (smallest != index) {
        _swap(index, smallest);
        index = smallest;
      } else {
        break;
      }
    }
  }

  void _swap(int a, int b) {
    final tmp = _data[a];
    _data[a] = _data[b];
    _data[b] = tmp;
  }
}
