/// Diagnostic severity classification for graph validation.
/// Owner: Pratik (Spatial Intelligence Domain)
enum DiagnosticSeverity {
  /// Invariants that make pathfinding unsafe, undefined, or impossible to execute correctly.
  error,

  /// Advisory quality findings that indicate suspicious topology or reduced confidence,
  /// but do not strictly prevent graph traversal.
  warning,
}

/// Stable machine-readable diagnostic codes for graph quality validation.
/// Owner: Pratik (Spatial Intelligence Domain)
abstract class DiagnosticCode {
  // --- Errors ---

  /// Graph contains zero nodes. Routing is impossible.
  static const String emptyGraph = 'ERR_EMPTY_GRAPH';

  /// Edge references a start node ID that does not exist in the graph.
  static const String missingStartNode = 'ERR_MISSING_START_NODE';

  /// Edge references an end node ID that does not exist in the graph.
  static const String missingEndNode = 'ERR_MISSING_END_NODE';

  /// Edge distance is negative, NaN, or non-finite.
  static const String invalidDistance = 'ERR_INVALID_DISTANCE';

  /// Fatal error variant of malformed floor connector when strictFloorTransitions is enabled.
  static const String errMalformedFloorConnector = 'ERR_MALFORMED_FLOOR_CONNECTOR';

  // --- Warnings ---

  /// Edge connects a node directly to itself (startNodeId == endNodeId).
  static const String selfLoop = 'WARN_SELF_LOOP';

  /// Graph consists of multiple weakly disconnected components.
  static const String disconnectedComponents = 'WARN_DISCONNECTED_COMPONENTS';

  /// Node has zero incoming and zero outgoing edges.
  static const String isolatedNode = 'WARN_ISOLATED_NODE';

  /// Node has incoming edges but zero outgoing edges in a directed graph.
  static const String deadEndNode = 'WARN_DEAD_END_NODE';

  /// Identical duplicate parallel edge between the same start and end nodes.
  static const String duplicateEdge = 'WARN_DUPLICATE_EDGE';

  /// Edge distance on the same floor is shorter than straight-line Euclidean distance,
  /// or exceeds the configured maximum geometric ratio.
  static const String geometricMismatch = 'WARN_GEOMETRIC_DISTANCE_MISMATCH';

  /// Designated emergency exit has zero incoming edges or is unreachable.
  static const String unreachableEmergencyExit = 'WARN_UNREACHABLE_EMERGENCY_EXIT';

  /// Cross-floor edge specifies conflicting connector metadata.
  static const String conflictingConnectorMetadata = 'WARN_CONFLICTING_CONNECTOR_METADATA';

  /// Cross-floor edge connecting different floors without recognized connector metadata.
  static const String malformedFloorConnector = 'WARN_MALFORMED_FLOOR_CONNECTOR';
}

/// A structured graph diagnostic result with severity, stable code, relevant IDs, and details.
/// Owner: Pratik (Spatial Intelligence Domain)
class GraphDiagnostic {
  /// Severity of the diagnostic (error vs warning).
  final DiagnosticSeverity severity;

  /// Stable machine-readable diagnostic code from [DiagnosticCode].
  final String code;

  /// Human-readable description explaining the issue and impact.
  final String message;

  /// Relevant node ID associated with this diagnostic, if applicable.
  final String? nodeId;

  /// Relevant edge ID associated with this diagnostic, if applicable.
  final String? edgeId;

  /// Optional metadata providing additional numerical or topological context.
  final Map<String, dynamic> metadata;

  const GraphDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.nodeId,
    this.edgeId,
    this.metadata = const {},
  });

  /// Whether this diagnostic represents a structural error.
  bool get isError => severity == DiagnosticSeverity.error;

  /// Whether this diagnostic represents an advisory warning.
  bool get isWarning => severity == DiagnosticSeverity.warning;

  Map<String, dynamic> toJson() => {
    'severity': severity == DiagnosticSeverity.error ? 'error' : 'warning',
    'code': code,
    'message': message,
    if (nodeId != null) 'nodeId': nodeId,
    if (edgeId != null) 'edgeId': edgeId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  String toString() =>
      'GraphDiagnostic([${severity.name.toUpperCase()}] $code: $message)';
}

/// Configuration options for spatial graph quality validation.
/// Owner: Pratik (Spatial Intelligence Domain)
class GraphQualityOptions {
  /// Floating-point tolerance below which an edge distance is considered shorter than Euclidean distance.
  /// Default: 1e-4 meters (0.1 mm).
  final double geometricTolerance;

  /// Optional maximum multiplier of edge.distance / Euclidean distance before an edge is flagged
  /// as suspiciously inflated. Null disables this ratio check.
  final double? maxGeometricRatio;

  /// Whether to validate multi-floor vertical connector metadata. Default: true.
  final bool checkFloorTransitions;

  /// When true, malformed vertical connectors are treated as fatal structural errors
  /// instead of advisory warnings. Default: false.
  final bool strictFloorTransitions;

  /// Whether to validate emergency exit reachability. Default: true.
  final bool checkEmergencyExits;

  /// Whether to flag dead-end nodes (nodes with incoming edges but 0 outgoing edges). Default: true.
  final bool checkDeadEnds;

  /// Whether to flag identical duplicate parallel edges. Default: true.
  final bool checkDuplicateEdges;

  const GraphQualityOptions({
    this.geometricTolerance = 1e-4,
    this.maxGeometricRatio,
    this.checkFloorTransitions = true,
    this.strictFloorTransitions = false,
    this.checkEmergencyExits = true,
    this.checkDeadEnds = true,
    this.checkDuplicateEdges = true,
  });
}
