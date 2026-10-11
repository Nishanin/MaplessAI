import 'dart:math' as math;
import 'package:meta/meta.dart';

import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/node_model.dart';
import 'graph_diagnostic.dart';

export 'graph_diagnostic.dart';

/// Validation report for a [SpatialGraph] containing structural validity,
/// categorized error/warning messages, component count, and structured diagnostics.
/// Owner: Pratik (Spatial Intelligence Domain)
class GraphValidationResult {
  /// Whether the graph is structurally valid (contains zero errors).
  final bool isValid;

  /// String messages for all error diagnostics.
  final List<String> errors;

  /// String messages for all advisory warning diagnostics.
  final List<String> warnings;

  /// Number of weakly connected components.
  final int componentCount;

  /// Structured diagnostic findings ordered deterministically.
  final List<GraphDiagnostic> diagnostics;

  const GraphValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.componentCount = 0,
    this.diagnostics = const [],
  });

  /// Whether any structural error diagnostics were recorded.
  bool get hasErrors => errors.isNotEmpty;

  /// Whether any advisory warning diagnostics were recorded.
  bool get hasWarnings => warnings.isNotEmpty;

  /// Filtered list of error diagnostics.
  List<GraphDiagnostic> get errorDiagnostics =>
      diagnostics.where((d) => d.isError).toList();

  /// Filtered list of warning diagnostics.
  List<GraphDiagnostic> get warningDiagnostics =>
      diagnostics.where((d) => d.isWarning).toList();

  /// Checks if any diagnostic matches [code].
  bool hasCode(String code) => diagnostics.any((d) => d.code == code);

  /// Returns all diagnostics matching [code].
  List<GraphDiagnostic> byCode(String code) =>
      diagnostics.where((d) => d.code == code).toList();

  @override
  String toString() =>
      'GraphValidationResult(isValid: $isValid, errors: ${errors.length}, '
      'warnings: ${warnings.length}, componentCount: $componentCount, '
      'diagnostics: ${diagnostics.length})';
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
    GraphQualityOptions options = const GraphQualityOptions(),
  }) {
    final graph = SpatialGraph();
    for (final node in nodes) {
      graph.addNode(node);
    }
    for (final edge in edges) {
      graph.addEdge(edge);
    }
    if (validate) {
      graph.validateOrThrow(options: options);
    }
    return graph;
  }

  /// Factory constructor for testing corrupted graph topologies directly in [validate].
  @visibleForTesting
  factory SpatialGraph.raw({
    Iterable<NodeModel>? nodes,
    Iterable<EdgeModel>? edges,
  }) {
    final graph = SpatialGraph();
    if (nodes != null) {
      for (final n in nodes) {
        graph._nodes[n.id] = n;
        graph._adjacencyList.putIfAbsent(n.id, () => []);
      }
    }
    if (edges != null) {
      for (final e in edges) {
        graph._edges[e.id] = e;
        graph._adjacencyList.putIfAbsent(e.startNodeId, () => []).add(e);
      }
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
  /// Returns a [GraphValidationResult] detailing validity, errors, warnings,
  /// component count, and structured diagnostics.
  GraphValidationResult validate({
    GraphQualityOptions options = const GraphQualityOptions(),
  }) {
    final diagnostics = <GraphDiagnostic>[];

    // 1. Empty graph check
    if (_nodes.isEmpty) {
      diagnostics.add(
        const GraphDiagnostic(
          severity: DiagnosticSeverity.error,
          code: DiagnosticCode.emptyGraph,
          message: 'Spatial graph is empty: contains 0 nodes.',
        ),
      );
    }

    final inDegree = <String, int>{for (final id in _nodes.keys) id: 0};
    final outDegree = <String, int>{for (final id in _nodes.keys) id: 0};
    final incomingEdges = <String, List<EdgeModel>>{
      for (final id in _nodes.keys) id: <EdgeModel>[],
    };
    final seenDirectedEdges = <String, String>{};

    // 2. Iterate edges and validate edge-level invariants
    for (final edge in _edges.values) {
      final startNode = _nodes[edge.startNodeId];
      final endNode = _nodes[edge.endNodeId];

      if (startNode == null) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.error,
            code: DiagnosticCode.missingStartNode,
            message:
                "Edge '${edge.id}' references nonexistent start node '${edge.startNodeId}'.",
            nodeId: edge.startNodeId,
            edgeId: edge.id,
          ),
        );
      }
      if (endNode == null) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.error,
            code: DiagnosticCode.missingEndNode,
            message:
                "Edge '${edge.id}' references nonexistent end node '${edge.endNodeId}'.",
            nodeId: edge.endNodeId,
            edgeId: edge.id,
          ),
        );
      }
      if (edge.distance.isNaN || edge.distance.isInfinite || edge.distance < 0) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.error,
            code: DiagnosticCode.invalidDistance,
            message: "Edge '${edge.id}' has invalid distance: ${edge.distance}.",
            edgeId: edge.id,
            metadata: {'distance': edge.distance},
          ),
        );
      }
      if (edge.startNodeId == edge.endNodeId) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.warning,
            code: DiagnosticCode.selfLoop,
            message:
                "Self-loop detected on node '${edge.startNodeId}' via edge '${edge.id}'.",
            nodeId: edge.startNodeId,
            edgeId: edge.id,
          ),
        );
      }

      if (options.checkDuplicateEdges) {
        final pairKey = '${edge.startNodeId}->${edge.endNodeId}';
        final existingEdgeId = seenDirectedEdges[pairKey];
        if (existingEdgeId != null) {
          diagnostics.add(
            GraphDiagnostic(
              severity: DiagnosticSeverity.warning,
              code: DiagnosticCode.duplicateEdge,
              message:
                  "Duplicate parallel edge '${edge.id}' connects '${edge.startNodeId}' to '${edge.endNodeId}' (already connected by '$existingEdgeId').",
              nodeId: edge.startNodeId,
              edgeId: edge.id,
              metadata: {
                'startNodeId': edge.startNodeId,
                'endNodeId': edge.endNodeId,
                'firstEdgeId': existingEdgeId,
              },
            ),
          );
        } else {
          seenDirectedEdges[pairKey] = edge.id;
        }
      }

      if (startNode != null && endNode != null && startNode.floorId == endNode.floorId) {
        final dx = startNode.x - endNode.x;
        final dy = startNode.y - endNode.y;
        final euclidean = math.sqrt(dx * dx + dy * dy);

        if (edge.distance < euclidean - options.geometricTolerance) {
          diagnostics.add(
            GraphDiagnostic(
              severity: DiagnosticSeverity.warning,
              code: DiagnosticCode.geometricMismatch,
              message:
                  "Edge '${edge.id}' distance (${edge.distance.toStringAsFixed(2)} m) is shorter than Euclidean distance (${euclidean.toStringAsFixed(2)} m).",
              edgeId: edge.id,
              nodeId: edge.startNodeId,
              metadata: {
                'edgeDistance': edge.distance,
                'euclideanDistance': euclidean,
                'type': 'sub_euclidean',
              },
            ),
          );
        } else if (options.maxGeometricRatio != null &&
            euclidean > options.geometricTolerance &&
            edge.distance > options.geometricTolerance) {
          final ratio = edge.distance / euclidean;
          if (ratio > options.maxGeometricRatio!) {
            diagnostics.add(
              GraphDiagnostic(
                severity: DiagnosticSeverity.warning,
                code: DiagnosticCode.geometricMismatch,
                message:
                    "Edge '${edge.id}' distance (${edge.distance.toStringAsFixed(2)} m) exceeds Euclidean distance (${euclidean.toStringAsFixed(2)} m) by ratio ${ratio.toStringAsFixed(2)} (max allowed: ${options.maxGeometricRatio}).",
                edgeId: edge.id,
                nodeId: edge.startNodeId,
                metadata: {
                  'edgeDistance': edge.distance,
                  'euclideanDistance': euclidean,
                  'ratio': ratio,
                  'type': 'inflated_ratio',
                },
              ),
            );
          }
        }
      }

      if (options.checkFloorTransitions &&
          startNode != null &&
          endNode != null &&
          startNode.floorId != endNode.floorId) {
        _validateFloorTransitionEdge(
          edge,
          startNode,
          endNode,
          diagnostics,
          strict: options.strictFloorTransitions,
        );
      }

      if (startNode != null) {
        outDegree[edge.startNodeId] = (outDegree[edge.startNodeId] ?? 0) + 1;
      }
      if (endNode != null) {
        inDegree[edge.endNodeId] = (inDegree[edge.endNodeId] ?? 0) + 1;
        incomingEdges[edge.endNodeId]?.add(edge);
      }
    }

    // 3. Node-level quality checks
    for (final node in _nodes.values) {
      final inCount = inDegree[node.id] ?? 0;
      final outCount = outDegree[node.id] ?? 0;

      if (inCount == 0 && outCount == 0) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.warning,
            code: DiagnosticCode.isolatedNode,
            message:
                "Node '${node.id}' is isolated with no incoming or outgoing edges.",
            nodeId: node.id,
          ),
        );
      } else if (options.checkDeadEnds && inCount > 0 && outCount == 0) {
        diagnostics.add(
          GraphDiagnostic(
            severity: DiagnosticSeverity.warning,
            code: DiagnosticCode.deadEndNode,
            message: "Node '${node.id}' is a dead end with no outgoing edges.",
            nodeId: node.id,
          ),
        );
      }

      if (options.checkEmergencyExits &&
          _isEmergencyExit(node) &&
          _nodes.length > 1) {
        final incomingToNode = incomingEdges[node.id] ?? const <EdgeModel>[];
        final allIncomingFromOthers = incomingToNode
            .where((e) => e.startNodeId != node.id)
            .toList();
        final unblockedIncomingFromOthers = allIncomingFromOthers
            .where((e) => !e.blocked)
            .toList();

        if (allIncomingFromOthers.isEmpty) {
          diagnostics.add(
            GraphDiagnostic(
              severity: DiagnosticSeverity.warning,
              code: DiagnosticCode.unreachableEmergencyExit,
              message:
                  "Designated emergency exit '${node.id}' has no incoming edges from other nodes and cannot be reached.",
              nodeId: node.id,
            ),
          );
        } else if (unblockedIncomingFromOthers.isEmpty) {
          diagnostics.add(
            GraphDiagnostic(
              severity: DiagnosticSeverity.warning,
              code: DiagnosticCode.unreachableEmergencyExit,
              message:
                  "Designated emergency exit '${node.id}' has only blocked incoming edges and cannot be reached under standard traversal.",
              nodeId: node.id,
            ),
          );
        } else if (!_canReachExit(node.id, incomingEdges)) {
          diagnostics.add(
            GraphDiagnostic(
              severity: DiagnosticSeverity.warning,
              code: DiagnosticCode.unreachableEmergencyExit,
              message:
                  "Designated emergency exit '${node.id}' has no traversable incoming path from any other node in its component.",
              nodeId: node.id,
            ),
          );
        }
      }
    }

    // 4. Connected components
    final componentCount = getConnectedComponentCount();
    if (componentCount > 1) {
      diagnostics.add(
        GraphDiagnostic(
          severity: DiagnosticSeverity.warning,
          code: DiagnosticCode.disconnectedComponents,
          message:
              'Spatial graph contains $componentCount disconnected components.',
          metadata: {'componentCount': componentCount},
        ),
      );
    }

    // 5. Deterministic sorting: severity (error before warning) -> code -> nodeId -> edgeId -> message
    diagnostics.sort((a, b) {
      if (a.severity != b.severity) {
        return a.severity == DiagnosticSeverity.error ? -1 : 1;
      }
      final codeCmp = a.code.compareTo(b.code);
      if (codeCmp != 0) return codeCmp;
      final nodeCmp = (a.nodeId ?? '').compareTo(b.nodeId ?? '');
      if (nodeCmp != 0) return nodeCmp;
      final edgeCmp = (a.edgeId ?? '').compareTo(b.edgeId ?? '');
      if (edgeCmp != 0) return edgeCmp;
      return a.message.compareTo(b.message);
    });

    final errors = diagnostics
        .where((d) => d.isError)
        .map((d) => d.message)
        .toList();
    final warnings = diagnostics
        .where((d) => d.isWarning)
        .map((d) => d.message)
        .toList();

    return GraphValidationResult(
      isValid: errors.isEmpty,
      errors: List.unmodifiable(errors),
      warnings: List.unmodifiable(warnings),
      componentCount: componentCount,
      diagnostics: List.unmodifiable(diagnostics),
    );
  }

  /// Validates graph integrity and throws [GraphException] if validation fails.
  void validateOrThrow({
    GraphQualityOptions options = const GraphQualityOptions(),
  }) {
    final result = validate(options: options);
    if (!result.isValid) {
      throw GraphException(
        'SpatialGraph validation failed: ${result.errors.join('; ')}',
        code: 'GRAPH_VALIDATION_FAILED',
        details: result.errors,
      );
    }
  }

  static Set<String> _extractTokens(String text) {
    final trimmed = text.trim().toLowerCase();
    if (trimmed.isEmpty) return const {};
    return trimmed.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toSet();
  }

  static void _validateFloorTransitionEdge(
    EdgeModel edge,
    NodeModel startNode,
    NodeModel endNode,
    List<GraphDiagnostic> diagnostics, {
    bool strict = false,
  }) {
    final tokens = <String>{
      ..._extractTokens(startNode.category),
      ..._extractTokens(endNode.category),
    };
    final edgeVia = edge.metadata['viaType']?.toString() ??
        edge.metadata['connectorType']?.toString();
    if (edgeVia != null) {
      tokens.addAll(_extractTokens(edgeVia));
    }

    final hasElevator = tokens.contains('lift') ||
        tokens.contains('elevator') ||
        tokens.contains('elevators') ||
        tokens.contains('lifts');
    final hasRamp = tokens.contains('ramp') || tokens.contains('ramps');
    final hasStairs = tokens.contains('stairs') ||
        tokens.contains('staircase') ||
        tokens.contains('stair') ||
        tokens.contains('stairwell') ||
        tokens.contains('stairway');

    final detectedTypes = <String>[
      if (hasElevator) 'elevator',
      if (hasRamp) 'ramp',
      if (hasStairs) 'stairs',
    ];

    if (detectedTypes.isEmpty) {
      diagnostics.add(
        GraphDiagnostic(
          severity: strict ? DiagnosticSeverity.error : DiagnosticSeverity.warning,
          code: strict
              ? DiagnosticCode.errMalformedFloorConnector
              : DiagnosticCode.malformedFloorConnector,
          message:
              "Cross-floor edge '${edge.id}' from '${startNode.id}' (${startNode.floorId}) to '${endNode.id}' (${endNode.floorId}) lacks recognized vertical connector metadata ('stairs', 'elevator', 'ramp'). Routes traversing this edge cannot generate structured floor transitions.",
          nodeId: endNode.id,
          edgeId: edge.id,
          metadata: {
            'fromFloorId': startNode.floorId,
            'toFloorId': endNode.floorId,
          },
        ),
      );
    } else if (detectedTypes.length > 1) {
      diagnostics.add(
        GraphDiagnostic(
          severity: DiagnosticSeverity.warning,
          code: DiagnosticCode.conflictingConnectorMetadata,
          message:
              "Cross-floor edge '${edge.id}' has conflicting vertical connector metadata: ${detectedTypes.join(', ')}.",
          nodeId: endNode.id,
          edgeId: edge.id,
          metadata: {'types': detectedTypes},
        ),
      );
    }
  }

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

  static bool _canReachExit(
    String exitId,
    Map<String, List<EdgeModel>> incomingEdges,
  ) {
    final visited = <String>{exitId};
    final queue = <String>[exitId];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final incoming in incomingEdges[current] ?? const <EdgeModel>[]) {
        if (incoming.blocked) continue;
        final predecessor = incoming.startNodeId;
        if (predecessor != exitId) {
          return true;
        }
        if (visited.add(predecessor)) {
          queue.add(predecessor);
        }
      }
    }

    return false;
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
