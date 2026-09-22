import 'map_draft_model.dart';

/// Single validation issue (Error or Warning)
class ValidationIssue {
  final String message;
  final String? entityId;
  final bool isError;

  const ValidationIssue({
    required this.message,
    this.entityId,
    this.isError = true,
  });

  bool get isWarning => !isError;
}

/// Structured result of map graph validation
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;

  const ValidationResult({
    required this.isValid,
    this.issues = const [],
  });

  List<ValidationIssue> get errors => issues.where((i) => i.isError).toList();
  List<ValidationIssue> get warnings => issues.where((i) => i.isWarning).toList();
  int get errorCount => errors.length;
  int get warningCount => warnings.length;
}

/// Service validating indoor map graph structure and topological contracts
/// Owner: Nishant (Phase 3 — Creator Graph Validation)
abstract final class MapValidationService {
  static const Set<String> supportedNodeCategories = {
    'room',
    'corridor',
    'entrance',
    'stair',
    'stairs',
    'lift',
    'elevator',
    'emergency_exit',
    'poi',
    'restroom',
    'laboratory',
  };

  /// Validates a [MapDraft] against topological and contract constraints
  static ValidationResult validateDraft(MapDraft draft) {
    final issues = <ValidationIssue>[];

    // 1. Building & Floor Reference Validation
    if (draft.building.id.trim().isEmpty) {
      issues.add(const ValidationIssue(
        message: 'Building ID cannot be empty.',
        isError: true,
      ));
    }
    if (draft.floor.id.trim().isEmpty) {
      issues.add(const ValidationIssue(
        message: 'Floor ID cannot be empty.',
        isError: true,
      ));
    }
    if (draft.floor.buildingId != draft.building.id) {
      issues.add(ValidationIssue(
        message: 'Floor buildingId (${draft.floor.buildingId}) does not match parent building ID (${draft.building.id}).',
        entityId: draft.floor.id,
        isError: true,
      ));
    }

    // 2. Node Validation
    if (draft.nodes.isEmpty) {
      issues.add(const ValidationIssue(
        message: 'Map must contain at least one node to be valid.',
        isError: true,
      ));
    }

    final seenNodeIds = <String>{};
    final validNodeIds = <String>{};

    for (final node in draft.nodes) {
      if (node.id.trim().isEmpty) {
        issues.add(const ValidationIssue(
          message: 'Node ID cannot be empty or whitespace.',
          isError: true,
        ));
        continue;
      }

      if (seenNodeIds.contains(node.id)) {
        issues.add(ValidationIssue(
          message: 'Duplicate node ID detected: "${node.id}".',
          entityId: node.id,
          isError: true,
        ));
      } else {
        seenNodeIds.add(node.id);
        validNodeIds.add(node.id);
      }

      if (node.name.trim().isEmpty) {
        issues.add(ValidationIssue(
          message: 'Node name is required for node "${node.id}".',
          entityId: node.id,
          isError: true,
        ));
      }

      // Check category against contract
      final cat = node.category.toLowerCase().trim();
      if (!supportedNodeCategories.contains(cat)) {
        issues.add(ValidationIssue(
          message: 'Invalid node category "$cat" for node "${node.name}". Must be a supported category.',
          entityId: node.id,
          isError: true,
        ));
      }

      // Check coordinates
      if (node.x.isNaN || node.x.isInfinite || node.y.isNaN || node.y.isInfinite) {
        issues.add(ValidationIssue(
          message: 'Invalid or non-finite coordinates for node "${node.name}".',
          entityId: node.id,
          isError: true,
        ));
      }

      // Check floor ID match
      if (node.floorId != draft.floor.id) {
        issues.add(ValidationIssue(
          message: 'Node "${node.name}" references floorId "${node.floorId}", which does not match active floor "${draft.floor.id}".',
          entityId: node.id,
          isError: true,
        ));
      }
    }

    // 3. Edge Validation
    final seenEdgeKeys = <String>{};
    final connectedNodeIds = <String>{};

    for (final edge in draft.edges) {
      if (edge.id.trim().isEmpty) {
        issues.add(const ValidationIssue(
          message: 'Edge ID cannot be empty.',
          isError: true,
        ));
      }

      final hasStart = edge.startNodeId.trim().isNotEmpty;
      final hasEnd = edge.endNodeId.trim().isNotEmpty;

      if (!hasStart) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" is missing a start node ID.',
          entityId: edge.id,
          isError: true,
        ));
      }
      if (!hasEnd) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" is missing an end node ID.',
          entityId: edge.id,
          isError: true,
        ));
      }

      if (hasStart && !validNodeIds.contains(edge.startNodeId)) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" references non-existent start node: "${edge.startNodeId}".',
          entityId: edge.id,
          isError: true,
        ));
      }

      if (hasEnd && !validNodeIds.contains(edge.endNodeId)) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" references non-existent end node: "${edge.endNodeId}".',
          entityId: edge.id,
          isError: true,
        ));
      }

      if (hasStart && hasEnd && edge.startNodeId == edge.endNodeId) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" is an invalid self-loop (start and destination are identical).',
          entityId: edge.id,
          isError: true,
        ));
      }

      // Check duplicate edges in same direction
      final edgeKey = '${edge.startNodeId}->${edge.endNodeId}';
      if (seenEdgeKeys.contains(edgeKey)) {
        issues.add(ValidationIssue(
          message: 'Duplicate edge detected between "${edge.startNodeId}" and "${edge.endNodeId}".',
          entityId: edge.id,
          isError: true,
        ));
      } else {
        seenEdgeKeys.add(edgeKey);
      }

      // Track connectivity
      if (hasStart && hasEnd) {
        connectedNodeIds.add(edge.startNodeId);
        connectedNodeIds.add(edge.endNodeId);
      }

      // Distance and bearing checks
      if (edge.distance < 0 || edge.distance.isNaN || edge.distance.isInfinite) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" has invalid distance (${edge.distance}m). Distance must be >= 0.',
          entityId: edge.id,
          isError: true,
        ));
      }

      if (edge.bearing < 0 || edge.bearing > 360 || edge.bearing.isNaN || edge.bearing.isInfinite) {
        issues.add(ValidationIssue(
          message: 'Edge "${edge.id}" has invalid bearing (${edge.bearing}°). Bearing must be between 0 and 360.',
          entityId: edge.id,
          isError: true,
        ));
      }

      if (edge.blocked) {
        issues.add(ValidationIssue(
          message: 'Notice: Edge "${edge.id}" is marked as BLOCKED.',
          entityId: edge.id,
          isError: false, // Warning
        ));
      }
    }

    // 4. Connectivity Warnings
    if (draft.nodes.length > 1 && draft.edges.isEmpty) {
      issues.add(const ValidationIssue(
        message: 'Map contains multiple nodes but has no connecting edges.',
        isError: false, // Warning
      ));
    } else if (draft.edges.isNotEmpty) {
      for (final node in draft.nodes) {
        if (!connectedNodeIds.contains(node.id)) {
          issues.add(ValidationIssue(
            message: 'Node "${node.name}" is isolated and has no connecting edges.',
            entityId: node.id,
            isError: false, // Warning
          ));
        }
      }
    }

    // 5. Semantic Metadata Checks
    for (final meta in draft.metadata) {
      if (meta.entityId.trim().isEmpty) {
        issues.add(const ValidationIssue(
          message: 'Metadata entity ID cannot be empty.',
          isError: true,
        ));
      } else if (!validNodeIds.contains(meta.entityId)) {
        issues.add(ValidationIssue(
          message: 'Metadata references entity "${meta.entityId}" which does not exist in the graph.',
          entityId: meta.entityId,
          isError: true,
        ));
      }
      if (meta.capacity != null && meta.capacity! < 0) {
        issues.add(ValidationIssue(
          message: 'Capacity cannot be negative for entity "${meta.entityId}".',
          entityId: meta.entityId,
          isError: true,
        ));
      }
    }

    final hasErrors = issues.any((i) => i.isError);
    return ValidationResult(
      isValid: !hasErrors,
      issues: issues,
    );
  }
}
