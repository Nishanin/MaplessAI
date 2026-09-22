import '../../../core/models/semantic_metadata_model.dart';

/// Semantic Knowledge Graph data structure
/// Owner: Surabhi (Semantic AI Domain)
///
/// Stores contextual relationships, room categories, tags, aliases,
/// and operational parameters used for natural-language query resolution.
///
/// CRITICAL SECURITY INVARIANT:
/// This class performs read-only in-memory lookups. It never constructs or
/// executes SQL queries, database commands, or network requests.
class SemanticKnowledgeGraph {
  final Map<String, SemanticMetadataModel> _entityMetadata = {};

  SemanticKnowledgeGraph();

  /// Adds or replaces the semantic metadata entry for an entity.
  void addMetadata(SemanticMetadataModel metadata) {
    _entityMetadata[metadata.entityId] = metadata;
  }

  /// Returns the semantic metadata for a given entity ID, or null if absent.
  SemanticMetadataModel? getMetadata(String entityId) =>
      _entityMetadata[entityId];

  /// Returns a deduplicated list of node IDs whose semantic metadata satisfies
  /// ALL of the supplied (non-null) filter criteria simultaneously.
  ///
  /// Filters applied:
  ///   [category]      — entity's [SemanticMetadataModel.entityType] value must
  ///                     be 'node', and a node whose spatial category matches
  ///                     this value. Category matching is case-insensitive.
  ///                     NOTE: SemanticMetadataModel does not directly carry the
  ///                     spatial category from node.schema.json; until the graph
  ///                     is populated with node category data, this filter narrows
  ///                     by checking tags for a matching category keyword as a
  ///                     best-effort fallback.
  ///   [tag]           — at least one of the entity's tags equals [tag]
  ///                     (case-insensitive exact match).
  ///   [alias]         — at least one of the entity's aliases contains [alias]
  ///                     as a substring (case-insensitive).
  ///   [accessibleOnly]— when true, only entities whose [SemanticMetadataModel]
  ///                     carries a custom attribute "accessible" == true are
  ///                     included. Entities without that attribute are excluded
  ///                     when this filter is active.
  ///
  /// If no filters are supplied, all node-type entity IDs are returned.
  /// If no entities match, an empty list is returned — no node ID is invented.
  /// Returned IDs are deduplicated; the order is map-iteration order (stable
  /// across the lifetime of this graph instance).
  List<String> findMatchingNodeIds({
    String? category,
    String? tag,
    String? alias,
    bool? accessibleOnly,
  }) {
    final seen = <String>{};
    final matches = <String>[];

    for (final entry in _entityMetadata.entries) {
      final meta = entry.value;

      // Only consider node-type entities
      if (meta.entityType != 'node') continue;

      // ── category filter ──────────────────────────────────────────────────
      if (category != null) {
        // Best-effort: check tags for a keyword matching the requested category,
        // since SemanticMetadataModel does not redundantly store node.category.
        final categoryLower = category.toLowerCase();
        final categoryMatches = meta.tags.any(
          (t) => t.toLowerCase() == categoryLower,
        );
        if (!categoryMatches) continue;
      }

      // ── tag filter ───────────────────────────────────────────────────────
      if (tag != null) {
        final tagLower = tag.toLowerCase();
        final tagMatches = meta.tags.any(
          (t) => t.toLowerCase() == tagLower,
        );
        if (!tagMatches) continue;
      }

      // ── alias filter ─────────────────────────────────────────────────────
      if (alias != null) {
        final aliasLower = alias.toLowerCase();
        final aliasMatches = meta.aliases.any(
          (a) => a.toLowerCase().contains(aliasLower),
        );
        if (!aliasMatches) continue;
      }

      // ── accessibleOnly filter ────────────────────────────────────────────
      if (accessibleOnly == true) {
        final accessible =
            meta.customAttributes['accessible'] as bool? ?? false;
        if (!accessible) continue;
      }

      // ── deduplicate and collect ──────────────────────────────────────────
      if (seen.add(entry.key)) {
        matches.add(entry.key);
      }
    }

    return matches;
  }

  /// Total number of stored metadata entries (all entity types).
  int get count => _entityMetadata.length;

  /// Removes all stored metadata entries.
  void clear() {
    _entityMetadata.clear();
  }
}
