import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../domain/spatial_graph.dart';

/// Result of a Dijkstra shortest-path computation.
///
/// Contains the ordered node path from start to destination,
/// the ordered edge IDs traversed, and the total traversal cost.
class DijkstraResult {
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

  const DijkstraResult({
    required this.found,
    this.pathNodeIds = const [],
    this.pathEdgeIds = const [],
    this.totalDistance = 0.0,
  });

  @override
  String toString() =>
      'DijkstraResult(found: $found, nodes: ${pathNodeIds.length}, distance: $totalDistance)';
}

/// Deterministic weighted Dijkstra shortest-path engine.
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Operates on [SpatialGraph] using edge.distance as the sole traversal cost.
/// Preserves directed edge semantics and respects blocked-edge exclusion.
///
/// Complexity: O((V + E) log V) using a lazy priority queue with stale-entry
/// skipping. No decrease-key operation is required.
///
/// Tie-breaking rule: When two candidate paths have equal total distance,
/// the path discovered via the edge that appears first in the adjacency list
/// (SpatialGraph insertion order) is retained. Since SpatialGraph uses
/// deterministic insertion-order maps and lists, this guarantees identical
/// results across repeated runs on the same graph.
///
/// Blocked-edge policy: By default, edges with blocked == true are skipped
/// during traversal. This is controlled by [skipBlocked] parameter.
/// Blocked edges remain in the graph; only the routing decision excludes them.
///
/// This class has NO dependency on Flutter, UI, SLM, semantic AI, or versioning.
class DijkstraEngine {
  const DijkstraEngine();

  /// Computes the shortest path from [startNodeId] to [destinationNodeId]
  /// in the given [graph].
  ///
  /// [skipBlocked]: If true (default), edges with `blocked == true` are
  /// excluded from traversal. Matches the project convention where
  /// `avoidBlockedEdges` defaults to `true` in NavigationPreferencesModel.
  ///
  /// Throws [GraphException] if:
  /// - [startNodeId] does not exist in the graph.
  /// - [destinationNodeId] does not exist in the graph.
  ///
  /// Returns [DijkstraResult] with `found == false` if the destination is
  /// unreachable from the start (no valid path exists).
  ///
  /// If `startNodeId == destinationNodeId`, returns a zero-distance path
  /// containing only that node.
  DijkstraResult findShortestPath(
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
      return DijkstraResult(
        found: true,
        pathNodeIds: [startNodeId],
        pathEdgeIds: const [],
        totalDistance: 0.0,
      );
    }

    // Distance map: best known distance from start to each node
    final dist = <String, double>{};
    dist[startNodeId] = 0.0;

    // Predecessor map: stores the edge used to reach each node
    final predecessorEdge = <String, EdgeModel>{};

    // Finalized set: nodes whose shortest distance is confirmed
    final finalized = <String>{};

    // Lazy priority queue: list of (distance, nodeId) entries sorted on pop.
    // Using a simple binary heap implemented via list operations.
    final pq = _MinHeap();
    pq.insert(0.0, startNodeId);

    while (pq.isNotEmpty) {
      final entry = pq.removeMin();
      final currentNodeId = entry.nodeId;
      final currentDist = entry.distance;

      // Skip stale entries: if we already finalized this node, or if we
      // already found a better distance, this entry is outdated.
      if (finalized.contains(currentNodeId)) continue;
      if (currentDist > (dist[currentNodeId] ?? double.maxFinite)) continue;

      // Finalize this node
      finalized.add(currentNodeId);

      // Early termination: destination reached
      if (currentNodeId == destinationNodeId) {
        return _reconstructPath(startNodeId, destinationNodeId, predecessorEdge, currentDist);
      }

      // Relax outgoing edges
      final outgoing = graph.getOutgoingEdges(currentNodeId);
      for (final edge in outgoing) {
        // Skip blocked edges if requested
        if (skipBlocked && edge.blocked) continue;

        final neighborId = edge.endNodeId;

        // Skip already finalized nodes
        if (finalized.contains(neighborId)) continue;

        final newDist = currentDist + edge.distance;

        // Strict improvement check (< not <=) preserves first-discovered path
        // for deterministic tie-breaking.
        final knownDist = dist[neighborId];
        if (knownDist == null || newDist < knownDist) {
          dist[neighborId] = newDist;
          predecessorEdge[neighborId] = edge;
          pq.insert(newDist, neighborId);
        }
      }
    }

    // Priority queue exhausted without reaching destination
    return const DijkstraResult(
      found: false,
      pathNodeIds: [],
      pathEdgeIds: [],
      totalDistance: 0.0,
    );
  }

  /// Reconstructs the shortest path from predecessor information.
  DijkstraResult _reconstructPath(
    String startNodeId,
    String destinationNodeId,
    Map<String, EdgeModel> predecessorEdge,
    double totalDistance,
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

    // Reverse to get start → destination order
    return DijkstraResult(
      found: true,
      pathNodeIds: pathNodes.reversed.toList(),
      pathEdgeIds: pathEdges.reversed.toList(),
      totalDistance: totalDistance,
    );
  }
}

/// A priority queue entry pairing a distance with a node ID.
class _HeapEntry {
  final double distance;
  final String nodeId;

  const _HeapEntry(this.distance, this.nodeId);
}

/// A binary min-heap priority queue for Dijkstra.
///
/// Supports O(log n) insert and O(log n) removeMin.
/// Uses lazy deletion via stale-entry skipping in the algorithm above,
/// so no decrease-key operation is needed.
class _MinHeap {
  final List<_HeapEntry> _data = [];

  bool get isNotEmpty => _data.isNotEmpty;
  bool get isEmpty => _data.isEmpty;

  void insert(double distance, String nodeId) {
    _data.add(_HeapEntry(distance, nodeId));
    _bubbleUp(_data.length - 1);
  }

  _HeapEntry removeMin() {
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
      if (_data[index].distance < _data[parentIndex].distance) {
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

      if (left < length && _data[left].distance < _data[smallest].distance) {
        smallest = left;
      }
      if (right < length && _data[right].distance < _data[smallest].distance) {
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
