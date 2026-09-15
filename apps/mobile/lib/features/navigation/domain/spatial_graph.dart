import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/node_model.dart';

/// Validation report for a [SpatialGraph].
class GraphValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final int componentCount;

  const GraphValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.componentCount = 0,
  });

  @override
  String toString() =>
      'GraphValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length}, componentCount: $componentCount)';
}

/// Spatial Graph data structure for indoor topological navigation.
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Responsibilities:
/// - Deterministic graph storage (nodes, edges, adjacency)
/// - Graph integrity validation (missing endpoints, negative distance, duplicate IDs)
/// - Preservation of directed edge semantics and blocked edge flags
/// - Adjacency querying for future pathfinding engines (A*, Dijkstra)
///
/// Self-Loop Policy:
/// Self-loops (edges where startNodeId == endNodeId) are permitted as valid graph
/// data provided the endpoint exists and distance >= 0. A warning is recorded
/// during validation.
class SpatialGraph {
  final Map<String, NodeModel> _nodes = {};
  final Map<String, EdgeModel> _edges = {};
  final Map<String, List<EdgeModel>> _adjacencyList = {};

  SpatialGraph();

  /// Constructs and populates a [SpatialGraph] from node and edge collections.
  /// Throws [GraphException] if [validate] is true and validation fails.
  factory SpatialGraph.fromNodesAndEdges(
    Iterable<NodeModel> nodes,
    Iterable<EdgeModel> edges, {
    bool validate = false,
  }) {
    final graph = SpatialGraph();
    for (final node in nodes) {
      graph.addNode(node);
    }
    for (final edge in edges) {
      graph.addEdge(edge);
    }
    if (validate) {
      graph.validateOrThrow();
    }
    return graph;
  }

  /// Adds a [NodeModel] to the graph.
  /// Throws [GraphException] if a node with the same ID already exists.
  void addNode(NodeModel node) {
    if (_nodes.containsKey(node.id)) {
      throw GraphException(
        "Duplicate node ID: '${node.id}' already exists in the graph.",
        code: 'DUPLICATE_NODE_ID',
      );
    }
    _nodes[node.id] = node;
    _adjacencyList.putIfAbsent(node.id, () => []);
  }

  /// Adds multiple nodes to the graph.
  void addNodes(Iterable<NodeModel> nodes) {
    for (final node in nodes) {
      addNode(node);
    }
  }

  /// Adds an [EdgeModel] to the graph.
  ///
  /// Throws [GraphException] if:
  /// - An edge with the same ID already exists.
  /// - The start node does not exist in the graph.
  /// - The end node does not exist in the graph.
  /// - The edge distance is negative, NaN, or non-finite.
  void addEdge(EdgeModel edge) {
    if (_edges.containsKey(edge.id)) {
      throw GraphException(
        "Duplicate edge ID: '${edge.id}' already exists in the graph.",
        code: 'DUPLICATE_EDGE_ID',
      );
    }
    if (!_nodes.containsKey(edge.startNodeId)) {
      throw GraphException(
        "Cannot add edge '${edge.id}': start node '${edge.startNodeId}' does not exist in the graph.",
        code: 'MISSING_START_NODE',
      );
    }
    if (!_nodes.containsKey(edge.endNodeId)) {
      throw GraphException(
        "Cannot add edge '${edge.id}': end node '${edge.endNodeId}' does not exist in the graph.",
        code: 'MISSING_END_NODE',
      );
    }
    if (edge.distance.isNaN || edge.distance.isInfinite || edge.distance < 0) {
      throw GraphException(
        "Cannot add edge '${edge.id}': invalid distance '${edge.distance}'. Distance must be a non-negative finite number.",
        code: 'INVALID_DISTANCE',
      );
    }

    _edges[edge.id] = edge;
    _adjacencyList.putIfAbsent(edge.startNodeId, () => []).add(edge);
  }

  /// Adds multiple edges to the graph.
  void addEdges(Iterable<EdgeModel> edges) {
    for (final edge in edges) {
      addEdge(edge);
    }
  }

  /// Retrieves a node by its unique [id]. Returns `null` if not found.
  NodeModel? getNode(String id) => _nodes[id];

  /// Checks whether a node with the given [id] exists in the graph.
  bool hasNode(String id) => _nodes.containsKey(id);

  /// Retrieves an edge by its unique [id]. Returns `null` if not found.
  EdgeModel? getEdge(String id) => _edges[id];

  /// Checks whether an edge with the given [id] exists in the graph.
  bool hasEdge(String id) => _edges.containsKey(id);

  /// Checks whether an edge directly connects [startNodeId] to [endNodeId].
  bool hasEdgeBetween(String startNodeId, String endNodeId) {
    final outgoing = _adjacencyList[startNodeId];
    if (outgoing == null || outgoing.isEmpty) return false;
    return outgoing.any((e) => e.endNodeId == endNodeId);
  }

  /// Retrieves all outgoing edges originating from [nodeId].
  /// Blocked edges remain included in the returned list.
  List<EdgeModel> getOutgoingEdges(String nodeId) =>
      List.unmodifiable(_adjacencyList[nodeId] ?? const <EdgeModel>[]);

  /// Alias for [getOutgoingEdges] to maintain backward compatibility.
  List<EdgeModel> getNeighbors(String nodeId) => getOutgoingEdges(nodeId);

  /// Returns all nodes in insertion order.
  List<NodeModel> get allNodes => List.unmodifiable(_nodes.values.toList());

  /// Returns all edges in insertion order.
  List<EdgeModel> get allEdges => List.unmodifiable(_edges.values.toList());

  /// Total number of nodes in the graph.
  int get nodeCount => _nodes.length;

  /// Total number of edges in the graph.
  int get edgeCount => _edges.length;

  /// Checks whether the graph contains no nodes.
  bool get isEmpty => _nodes.isEmpty;

  /// Checks whether the graph contains at least one node.
  bool get isNotEmpty => _nodes.isNotEmpty;

  /// Safely resets and clears all nodes, edges, and adjacency lists.
  void clear() {
    _nodes.clear();
    _edges.clear();
    _adjacencyList.clear();
  }

  /// Validates graph structure and data integrity.
  /// Returns a [GraphValidationResult] detailing validity, errors, warnings, and component count.
  GraphValidationResult validate() {
    final errors = <String>[];
    final warnings = <String>[];

    if (_nodes.isEmpty) {
      errors.add('Spatial graph is empty: contains 0 nodes.');
    }

    for (final edge in _edges.values) {
      if (!_nodes.containsKey(edge.startNodeId)) {
        errors.add("Edge '${edge.id}' references nonexistent start node '${edge.startNodeId}'.");
      }
      if (!_nodes.containsKey(edge.endNodeId)) {
        errors.add("Edge '${edge.id}' references nonexistent end node '${edge.endNodeId}'.");
      }
      if (edge.distance.isNaN || edge.distance.isInfinite || edge.distance < 0) {
        errors.add("Edge '${edge.id}' has invalid distance: ${edge.distance}.");
      }
      if (edge.startNodeId == edge.endNodeId) {
        warnings.add("Self-loop detected on node '${edge.startNodeId}' via edge '${edge.id}'.");
      }
    }

    final componentCount = getConnectedComponentCount();

    return GraphValidationResult(
      isValid: errors.isEmpty,
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
      componentCount: componentCount,
    );
  }

  /// Validates graph integrity and throws [GraphException] if validation fails.
  void validateOrThrow() {
    final result = validate();
    if (!result.isValid) {
      throw GraphException(
        'SpatialGraph validation failed: ${result.errors.join('; ')}',
        code: 'GRAPH_VALIDATION_FAILED',
        details: result.errors,
      );
    }
  }

  /// Computes the number of weakly connected components in the graph.
  /// Treats edges as undirected for topological component discovery.
  int getConnectedComponentCount() {
    if (_nodes.isEmpty) return 0;

    final visited = <String>{};
    int components = 0;

    final undirectedAdj = <String, Set<String>>{};
    for (final nodeId in _nodes.keys) {
      undirectedAdj[nodeId] = <String>{};
    }
    for (final edge in _edges.values) {
      if (_nodes.containsKey(edge.startNodeId) && _nodes.containsKey(edge.endNodeId)) {
        undirectedAdj[edge.startNodeId]?.add(edge.endNodeId);
        undirectedAdj[edge.endNodeId]?.add(edge.startNodeId);
      }
    }

    for (final nodeId in _nodes.keys) {
      if (!visited.contains(nodeId)) {
        components++;
        final queue = <String>[nodeId];
        visited.add(nodeId);

        while (queue.isNotEmpty) {
          final current = queue.removeLast();
          for (final neighbor in undirectedAdj[current] ?? const <String>{}) {
            if (visited.add(neighbor)) {
              queue.add(neighbor);
            }
          }
        }
      }
    }

    return components;
  }
}
