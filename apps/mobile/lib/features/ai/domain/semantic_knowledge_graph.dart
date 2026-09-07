import '../../../core/models/semantic_metadata_model.dart';

/// Semantic Knowledge Graph data structure
/// Owner: Surabhi (Semantic AI Domain)
///
/// Stores contextual relationships, room categories, tags, aliases,
/// and operational parameters used for natural-language query resolution.
class SemanticKnowledgeGraph {
  final Map<String, SemanticMetadataModel> _entityMetadata = {};

  SemanticKnowledgeGraph();

  void addMetadata(SemanticMetadataModel metadata) {
    _entityMetadata[metadata.entityId] = metadata;
  }

  SemanticMetadataModel? getMetadata(String entityId) => _entityMetadata[entityId];

  List<String> findMatchingNodeIds({
    String? category,
    String? tag,
    String? alias,
    bool? accessibleOnly,
  }) {
    final matches = <String>[];

    for (final entry in _entityMetadata.entries) {
      final meta = entry.value;
      if (meta.entityType != 'node') continue;

      if (tag != null && meta.tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        matches.add(entry.key);
        continue;
      }

      if (alias != null &&
          meta.aliases.any((a) => a.toLowerCase().contains(alias.toLowerCase()))) {
        matches.add(entry.key);
        continue;
      }
    }

    return matches;
  }

  int get count => _entityMetadata.length;

  void clear() {
    _entityMetadata.clear();
  }
}
