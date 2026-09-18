import '../../../core/errors/exceptions.dart';
import '../../../core/models/edge_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../../../core/models/node_model.dart';
import '../domain/spatial_graph.dart';

/// Semantic classification of navigation maneuvers.
enum TurnType {
  /// Departure / start of navigation.
  start,

  /// Continue straight without significant heading change.
  straight,

  /// Gentle heading adjustment to the left (20° to 45°).
  slightLeft,

  /// Gentle heading adjustment to the right (20° to 45°).
  slightRight,

  /// Standard turn to the left (45° to 135°).
  left,

  /// Standard turn to the right (45° to 135°).
  right,

  /// Acute heading change to the left (135° to 165°).
  sharpLeft,

  /// Acute heading change to the right (135° to 165°).
  sharpRight,

  /// Reversal of heading (> 165°).
  uTurn,

  /// Arrival at the destination node.
  arrival,

  /// Vertical floor transition (stairs, elevator, ramp).
  floorTransition,
}

/// Rich domain representation of a turn-by-turn instruction.
///
/// Converts to [TurnInstructionModel] for contract serialization.
class TurnInstruction {
  final int step;
  final TurnType type;
  final String instruction;
  final double distance;
  final double bearing;
  final double? turnAngle;
  final String? nodeId;

  const TurnInstruction({
    required this.step,
    required this.type,
    required this.instruction,
    required this.distance,
    required this.bearing,
    this.turnAngle,
    this.nodeId,
  });

  /// Converts this domain instruction to the contract [TurnInstructionModel].
  TurnInstructionModel toModel() {
    return TurnInstructionModel(
      step: step,
      instruction: instruction,
      distance: distance,
      bearing: bearing,
      nodeId: nodeId,
    );
  }

  @override
  String toString() =>
      'TurnInstruction(step: $step, type: $type, instruction: "$instruction", '
      'distance: ${distance}m, bearing: $bearing°, turnAngle: $turnAngle, nodeId: $nodeId)';
}

/// Deterministic Turn Instruction Generator.
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Transforms a validated path (sequence of node IDs and edge IDs) over a
/// [SpatialGraph] into a sequence of human-readable navigation instructions.
///
/// ## Bearing & Geometry Conventions
/// - Bearings follow standard compass headings: 0° = North, 90° = East,
///   180° = South, 270° = West.
/// - Turn angles represent signed heading change: $\Delta = \theta_{out} - \theta_{in}$.
/// - Normalized to $(-180^\circ, +180^\circ]$:
///   - Positive values indicate turning clockwise (right).
///   - Negative values indicate turning counter-clockwise (left).
///   - 0° indicates straight ahead.
///   - $\pm 180^\circ$ indicates a U-turn.
///
/// ## Classification Thresholds
/// - Straight: $|\Delta| \le 20.0^\circ$
/// - Slight Right: $20.0^\circ < \Delta \le 45.0^\circ$
/// - Right: $45.0^\circ < \Delta \le 135.0^\circ$
/// - Sharp Right: $135.0^\circ < \Delta \le 165.0^\circ$
/// - U-Turn: $|\Delta| > 165.0^\circ$
/// - Sharp Left: $-165.0^\circ \le \Delta < -135.0^\circ$
/// - Left: $-135.0^\circ \le \Delta < -45.0^\circ$
/// - Slight Left: $-45.0^\circ \le \Delta < -20.0^\circ$
///
/// ## Straight Segment Consolidation
/// Consecutive edges sharing a straight heading ($|\Delta| \le 20.0^\circ$) on
/// the same floor are consolidated into a single movement instruction with
/// accumulated distance.
class TurnInstructionGenerator {
  /// Angular threshold for straight continuation (degrees).
  static const double straightThresholdDegrees = 20.0;

  /// Angular threshold for slight turns (degrees).
  static const double slightTurnThresholdDegrees = 45.0;

  /// Angular threshold for regular turns (degrees).
  static const double regularTurnThresholdDegrees = 135.0;

  /// Angular threshold for sharp turns (degrees). Beyond this is U-turn.
  static const double sharpTurnThresholdDegrees = 165.0;

  const TurnInstructionGenerator();

  /// Generates a list of [TurnInstructionModel] from a validated route.
  ///
  /// Throws [GraphException] if:
  /// - [pathNodeIds] is empty (`INVALID_ROUTE_PATH`).
  /// - Node count and edge count mismatch (`INVALID_ROUTE_PATH`).
  /// - Any referenced node does not exist in [graph] (`MISSING_ROUTE_NODE`).
  /// - Any referenced edge does not exist in [graph] (`MISSING_ROUTE_EDGE`).
  /// - Edge endpoints do not match path node sequence (`EDGE_DIRECTION_MISMATCH`).
  /// - Edge distance is negative, NaN, or infinite (`INVALID_EDGE_DISTANCE`).
  List<TurnInstructionModel> generate({
    required SpatialGraph graph,
    required List<String> pathNodeIds,
    required List<String> pathEdgeIds,
  }) {
    final domainInstructions = generateDomainInstructions(
      graph: graph,
      pathNodeIds: pathNodeIds,
      pathEdgeIds: pathEdgeIds,
    );
    return domainInstructions.map((i) => i.toModel()).toList();
  }

  /// Generates rich [TurnInstruction] domain models from a validated route.
  List<TurnInstruction> generateDomainInstructions({
    required SpatialGraph graph,
    required List<String> pathNodeIds,
    required List<String> pathEdgeIds,
  }) {
    // 1. Validate inputs thoroughly
    _validateInputs(graph, pathNodeIds, pathEdgeIds);

    final instructions = <TurnInstruction>[];

    // Case: start == destination (0 edges)
    if (pathEdgeIds.isEmpty) {
      final node = graph.getNode(pathNodeIds.first)!;
      final name = _cleanNodeName(node.name);
      final destText = name != null ? 'Arrive at $name' : 'Arrive at destination';

      instructions.add(
        TurnInstruction(
          step: 1,
          type: TurnType.arrival,
          instruction: destText,
          distance: 0.0,
          bearing: 0.0,
          nodeId: node.id,
        ),
      );
      return instructions;
    }

    // Retrieve resolved nodes and edges
    final nodes = pathNodeIds.map((id) => graph.getNode(id)!).toList();
    final edges = pathEdgeIds.map((id) => graph.getEdge(id)!).toList();

    int stepCounter = 1;

    // Step 1: Start instruction
    final startNode = nodes.first;
    final startName = _cleanNodeName(startNode.name);
    final startText = startName != null ? 'Start at $startName' : 'Start navigation';

    instructions.add(
      TurnInstruction(
        step: stepCounter++,
        type: TurnType.start,
        instruction: startText,
        distance: 0.0,
        bearing: edges.first.bearing,
        nodeId: startNode.id,
      ),
    );

    // Group edges into consolidated movement segments
    final segments = _buildMovementSegments(nodes, edges);

    for (final seg in segments) {
      final formattedDist = formatDistance(seg.accumulatedDistance);
      final instructionText = _buildSegmentInstruction(seg, formattedDist);

      instructions.add(
        TurnInstruction(
          step: stepCounter++,
          type: seg.type,
          instruction: instructionText,
          distance: seg.accumulatedDistance,
          bearing: seg.initialBearing,
          turnAngle: seg.turnAngle,
          nodeId: seg.endNodeId,
        ),
      );
    }

    // Final step: Arrival instruction
    final destNode = nodes.last;
    final destName = _cleanNodeName(destNode.name);
    final arriveText = destName != null ? 'Arrive at $destName' : 'Arrive at destination';

    instructions.add(
      TurnInstruction(
        step: stepCounter,
        type: TurnType.arrival,
        instruction: arriveText,
        distance: 0.0,
        bearing: edges.last.bearing,
        nodeId: destNode.id,
      ),
    );

    return instructions;
  }

  // ---------------------------------------------------------------------------
  // Segment Builder & Consolidation Logic
  // ---------------------------------------------------------------------------

  List<_MovementSegment> _buildMovementSegments(
    List<NodeModel> nodes,
    List<EdgeModel> edges,
  ) {
    final segments = <_MovementSegment>[];

    // Initialize first segment with the first edge
    var currentSeg = _MovementSegment(
      type: _isFloorTransition(nodes[0], nodes[1])
          ? TurnType.floorTransition
          : TurnType.straight,
      accumulatedDistance: edges[0].distance,
      initialBearing: edges[0].bearing,
      turnAngle: 0.0,
      startNodeId: nodes[0].id,
      endNodeId: nodes[1].id,
      targetFloorId: nodes[1].floorId,
      viaType: _detectViaType(nodes[0], nodes[1]),
    );

    for (var i = 1; i < edges.length; i++) {
      final prevEdge = edges[i - 1];
      final currEdge = edges[i];
      final fromNode = nodes[i];
      final toNode = nodes[i + 1];

      final isTransition = _isFloorTransition(fromNode, toNode);
      final turnAngle = calculateTurnAngle(prevEdge.bearing, currEdge.bearing);
      final turnType = isTransition
          ? TurnType.floorTransition
          : classifyTurn(turnAngle);

      // Check if current edge continues straight on the same floor
      final canConsolidate = !isTransition &&
          currentSeg.type != TurnType.floorTransition &&
          turnType == TurnType.straight;

      if (canConsolidate) {
        // Consolidate into current segment
        currentSeg.accumulatedDistance += currEdge.distance;
        currentSeg.endNodeId = toNode.id;
      } else {
        // Complete current segment and start new one
        segments.add(currentSeg);

        currentSeg = _MovementSegment(
          type: turnType,
          accumulatedDistance: currEdge.distance,
          initialBearing: currEdge.bearing,
          turnAngle: turnAngle,
          startNodeId: fromNode.id,
          endNodeId: toNode.id,
          targetFloorId: toNode.floorId,
          viaType: _detectViaType(fromNode, toNode),
        );
      }
    }

    segments.add(currentSeg);
    return segments;
  }

  String _buildSegmentInstruction(_MovementSegment seg, String formattedDist) {
    switch (seg.type) {
      case TurnType.straight:
        return 'Walk straight for $formattedDist';
      case TurnType.slightLeft:
        return 'Turn slight left and continue for $formattedDist';
      case TurnType.slightRight:
        return 'Turn slight right and continue for $formattedDist';
      case TurnType.left:
        return 'Turn left and continue for $formattedDist';
      case TurnType.right:
        return 'Turn right and continue for $formattedDist';
      case TurnType.sharpLeft:
        return 'Turn sharp left and continue for $formattedDist';
      case TurnType.sharpRight:
        return 'Turn sharp right and continue for $formattedDist';
      case TurnType.uTurn:
        return 'Make a U-turn and continue for $formattedDist';
      case TurnType.floorTransition:
        if (seg.viaType != null) {
          return 'Take the ${seg.viaType} to ${seg.targetFloorId}';
        }
        return 'Proceed to ${seg.targetFloorId}';
      case TurnType.start:
      case TurnType.arrival:
        return 'Continue for $formattedDist';
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry & Turn Classification
  // ---------------------------------------------------------------------------

  /// Calculates the signed turn angle from [incomingBearing] to [outgoingBearing].
  ///
  /// Output is normalized to $(-180.0^\circ, +180.0^\circ]$:
  /// - Positive: turning right (clockwise).
  /// - Negative: turning left (counter-clockwise).
  static double calculateTurnAngle(double incomingBearing, double outgoingBearing) {
    final diff = outgoingBearing - incomingBearing;
    return normalizeAngle(diff);
  }

  /// Normalizes an angle in degrees to the $(-180.0^\circ, +180.0^\circ]$ range.
  static double normalizeAngle(double degrees) {
    var d = degrees % 360.0;
    if (d > 180.0) {
      d -= 360.0;
    } else if (d <= -180.0) {
      d += 360.0;
    }
    // Snap close to 0 to avoid -0.0
    if (d.abs() < 1e-9) return 0.0;
    return (d * 10).round() / 10.0;
  }

  /// Classifies a turn angle into a semantic [TurnType].
  static TurnType classifyTurn(double turnAngleDegrees) {
    final absAngle = turnAngleDegrees.abs();

    if (absAngle <= straightThresholdDegrees) {
      return TurnType.straight;
    }

    if (turnAngleDegrees > 0) {
      if (turnAngleDegrees <= slightTurnThresholdDegrees) {
        return TurnType.slightRight;
      }
      if (turnAngleDegrees <= regularTurnThresholdDegrees) {
        return TurnType.right;
      }
      if (turnAngleDegrees <= sharpTurnThresholdDegrees) {
        return TurnType.sharpRight;
      }
      return TurnType.uTurn;
    } else {
      if (absAngle <= slightTurnThresholdDegrees) {
        return TurnType.slightLeft;
      }
      if (absAngle <= regularTurnThresholdDegrees) {
        return TurnType.left;
      }
      if (absAngle <= sharpTurnThresholdDegrees) {
        return TurnType.sharpLeft;
      }
      return TurnType.uTurn;
    }
  }

  /// Formats distance in meters into a human-readable presentation string.
  ///
  /// Examples:
  /// - `12.0` -> `"12 m"`
  /// - `12.4` -> `"12.4 m"`
  /// - `12.46` -> `"12.5 m"`
  /// - `0.0` -> `"0 m"`
  static String formatDistance(double distanceMeters) {
    if (distanceMeters <= 0.0) return '0 m';

    final roundedTenth = (distanceMeters * 10).round() / 10.0;
    if (roundedTenth == roundedTenth.truncateToDouble()) {
      return '${roundedTenth.toInt()} m';
    }
    return '${roundedTenth.toStringAsFixed(1)} m';
  }

  // ---------------------------------------------------------------------------
  // Floor Transition Detection
  // ---------------------------------------------------------------------------

  static bool _isFloorTransition(NodeModel from, NodeModel to) {
    return from.floorId != to.floorId;
  }

  static Set<String> _extractCategoryTokens(NodeModel node) {
    final cat = node.category.trim().toLowerCase();
    if (cat.isEmpty) return const {};
    return cat.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toSet();
  }

  static String? _detectViaType(NodeModel from, NodeModel to) {
    if (!_isFloorTransition(from, to)) return null;

    final tokensFrom = _extractCategoryTokens(from);
    final tokensTo = _extractCategoryTokens(to);
    final allTokens = {...tokensFrom, ...tokensTo};

    if (allTokens.contains('lift') ||
        allTokens.contains('elevator') ||
        allTokens.contains('elevators') ||
        allTokens.contains('lifts')) {
      return 'lift';
    }
    if (allTokens.contains('ramp') || allTokens.contains('ramps')) {
      return 'ramp';
    }
    if (allTokens.contains('stairs') ||
        allTokens.contains('staircase') ||
        allTokens.contains('stair') ||
        allTokens.contains('stairwell') ||
        allTokens.contains('stairway')) {
      return 'stairs';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Validation & Helpers
  // ---------------------------------------------------------------------------

  static String? _cleanNodeName(String? name) {
    if (name == null) return null;
    final trimmed = name.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }

  static void _validateInputs(
    SpatialGraph graph,
    List<String> pathNodeIds,
    List<String> pathEdgeIds,
  ) {
    if (pathNodeIds.isEmpty) {
      throw const GraphException(
        'Path node IDs cannot be empty.',
        code: 'INVALID_ROUTE_PATH',
      );
    }

    if (pathNodeIds.length == 1) {
      if (pathEdgeIds.isNotEmpty) {
        throw const GraphException(
          'Single-node path cannot contain edge IDs.',
          code: 'INVALID_ROUTE_PATH',
        );
      }
    } else {
      final expectedEdges = pathNodeIds.length - 1;
      if (pathEdgeIds.length != expectedEdges) {
        throw GraphException(
          'Edge count (${pathEdgeIds.length}) does not match node count - 1 ($expectedEdges).',
          code: 'INVALID_ROUTE_PATH',
        );
      }
    }

    // Verify all nodes exist
    for (final nodeId in pathNodeIds) {
      if (!graph.hasNode(nodeId)) {
        throw GraphException(
          "Node '$nodeId' not found in spatial graph.",
          code: 'MISSING_ROUTE_NODE',
        );
      }
    }

    // Verify all edges exist, directions match consecutive node pairs, and distances are valid
    for (var i = 0; i < pathEdgeIds.length; i++) {
      final edgeId = pathEdgeIds[i];
      final edge = graph.getEdge(edgeId);

      if (edge == null) {
        throw GraphException(
          "Edge '$edgeId' not found in spatial graph.",
          code: 'MISSING_ROUTE_EDGE',
        );
      }

      final expectedStart = pathNodeIds[i];
      final expectedEnd = pathNodeIds[i + 1];

      if (edge.startNodeId != expectedStart || edge.endNodeId != expectedEnd) {
        throw GraphException(
          "Edge '$edgeId' connects '${edge.startNodeId}' -> '${edge.endNodeId}', "
          "expected '$expectedStart' -> '$expectedEnd'.",
          code: 'EDGE_DIRECTION_MISMATCH',
        );
      }

      if (edge.distance.isNaN || edge.distance.isInfinite || edge.distance < 0) {
        throw GraphException(
          "Edge '$edgeId' has invalid distance: ${edge.distance}.",
          code: 'INVALID_EDGE_DISTANCE',
        );
      }
    }
  }
}

/// Internal helper to track consolidated movement segments.
class _MovementSegment {
  TurnType type;
  double accumulatedDistance;
  final double initialBearing;
  final double turnAngle;
  final String startNodeId;
  String endNodeId;
  final String? targetFloorId;
  final String? viaType;

  _MovementSegment({
    required this.type,
    required this.accumulatedDistance,
    required this.initialBearing,
    required this.turnAngle,
    required this.startNodeId,
    required this.endNodeId,
    this.targetFloorId,
    this.viaType,
  });
}
