import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/building_model.dart';
import '../models/edge_model.dart';
import '../models/floor_model.dart';
import '../models/node_model.dart';
import '../models/semantic_metadata_model.dart';

/// Parsed indoor dataset model
class IndoorDataset {
  final BuildingModel building;
  final FloorModel floor;
  final List<NodeModel> nodes;
  final List<EdgeModel> edges;
  final List<SemanticMetadataModel> semanticMetadata;

  const IndoorDataset({
    required this.building,
    required this.floor,
    required this.nodes,
    required this.edges,
    required this.semanticMetadata,
  });

  factory IndoorDataset.fromJson(Map<String, dynamic> json) {
    final building = BuildingModel.fromJson(json['building'] as Map<String, dynamic>);
    final floor = FloorModel.fromJson(json['floor'] as Map<String, dynamic>);
    final nodes = (json['nodes'] as List<dynamic>)
        .map((e) => NodeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final edges = (json['edges'] as List<dynamic>)
        .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final semanticMetadata = (json['semanticMetadata'] as List<dynamic>?)
            ?.map((e) => SemanticMetadataModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return IndoorDataset(
      building: building,
      floor: floor,
      nodes: nodes,
      edges: edges,
      semanticMetadata: semanticMetadata,
    );
  }
}

/// JSON helper utilities
abstract final class JsonUtils {
  /// Loads mock dataset from bundled asset
  static Future<IndoorDataset> loadMockDatasetFromAsset([
    String assetPath = 'assets/test_data/vit_floor_1.json',
  ]) async {
    final jsonString = await rootBundle.loadString(assetPath);
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return IndoorDataset.fromJson(map);
  }

  /// Parses raw JSON string into IndoorDataset
  static IndoorDataset parseDatasetString(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return IndoorDataset.fromJson(map);
  }
}
