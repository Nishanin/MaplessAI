import '../../../core/models/edge_model.dart';
import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/node_model.dart';

/// Traversal policy governing edge and node accessibility rules during pathfinding.
/// Owner: Pratik (Spatial Intelligence Domain)
///
/// Encapsulates accessibility filtering, stair avoidance, and blocked-edge exclusion
/// so that both Dijkstra and A* engines evaluate identical traversal invariants.
class TraversalPolicy {
  /// Whether to exclude edges where `blocked == true`.
  final bool skipBlocked;

  /// Whether wheelchair / barrier-free accessible routing is required.
  /// When true, inaccessible edges (`edge.accessible == false`) and inaccessible
  /// intermediate nodes (`node.accessible == false`) cannot be traversed.
  final bool accessible;

  /// Whether stairs should be avoided in favor of elevators or ramps.
  final bool avoidStairs;

  /// The requested destination node ID. Used to differentiate intermediate nodes
  /// from destination endpoints (e.g. allowing reaching an endpoint even if its node
  /// model has `accessible == false` or is a stair landing, provided the approach is valid).
  final String destinationNodeId;

  const TraversalPolicy({
    this.skipBlocked = true,
    this.accessible = false,
    this.avoidStairs = false,
    this.destinationNodeId = '',
  });

  /// Constructs a [TraversalPolicy] from [NavigationPreferencesModel].
  factory TraversalPolicy.fromPreferences(
    NavigationPreferencesModel preferences, {
    required String destinationNodeId,
  }) {
    return TraversalPolicy(
      skipBlocked: preferences.avoidBlockedEdges,
      accessible: preferences.accessible,
      avoidStairs: preferences.avoidStairs,
      destinationNodeId: destinationNodeId,
    );
  }

  static const Set<String> _stairTokens = {
    'stairs',
    'staircase',
    'stair',
    'stairwell',
    'stairway',
  };

  static const Set<String> _nonStairTokens = {
    'elevator',
    'elevators',
    'lift',
    'lifts',
    'ramp',
    'ramps',
  };

  /// Evaluates whether an outgoing [edge] from [fromNode] to [toNode] can be traversed.
  bool canTraverse({
    required EdgeModel edge,
    required NodeModel fromNode,
    required NodeModel toNode,
  }) {
    // 1. Blocked edge exclusion
    if (skipBlocked && edge.blocked) {
      return false;
    }

    // 2. Wheelchair / barrier-free accessibility constraint
    if (accessible) {
      // Inaccessible edge cannot be traversed
      if (!edge.accessible) {
        return false;
      }
      // Inaccessible intermediate node cannot be traversed through
      if (toNode.id != destinationNodeId && !toNode.accessible) {
        return false;
      }
    }

    // 3. Stair avoidance constraint
    if (avoidStairs) {
      if (isStairs(edge: edge, fromNode: fromNode, toNode: toNode)) {
        return false;
      }
    }

    return true;
  }

  /// Determines whether the given edge/transition represents stairs.
  bool isStairs({
    required EdgeModel edge,
    required NodeModel fromNode,
    required NodeModel toNode,
  }) {
    // 1. Explicit edge metadata declaration
    final edgeVia = edge.metadata['viaType']?.toString().toLowerCase() ??
        edge.metadata['connectorType']?.toString().toLowerCase() ??
        edge.metadata['type']?.toString().toLowerCase();
    if (edgeVia != null) {
      final edgeTokens = _extractTokens(edgeVia);
      if (edgeTokens.any(_stairTokens.contains)) {
        return true;
      }
      if (edgeTokens.any(_nonStairTokens.contains)) {
        return false;
      }
    }

    // 2. Cross-floor connector
    if (fromNode.floorId != toNode.floorId) {
      final fromTokens = _extractTokens(fromNode.category);
      final toTokens = _extractTokens(toNode.category);
      final allTokens = {...fromTokens, ...toTokens};

      // If either node specifies elevator or ramp, it is not stairs
      if (allTokens.any(_nonStairTokens.contains)) {
        return false;
      }

      if (allTokens.any(_stairTokens.contains)) {
        return true;
      }
    }

    // 3. Same-floor stair connector / intermediate stair node
    final toTokens = _extractTokens(toNode.category);
    if (toTokens.any(_nonStairTokens.contains)) {
      return false;
    }
    if (toTokens.any(_stairTokens.contains)) {
      final fromTokens = _extractTokens(fromNode.category);
      // Both endpoints are stairs -> internal stair run
      if (fromTokens.any(_stairTokens.contains)) {
        return true;
      }
      // toNode is an intermediate stair node (not the destination endpoint)
      if (toNode.id != destinationNodeId) {
        return true;
      }
    }

    return false;
  }

  static Set<String> _extractTokens(String text) {
    final trimmed = text.trim().toLowerCase();
    if (trimmed.isEmpty) return const {};
    return trimmed.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty).toSet();
  }
}
