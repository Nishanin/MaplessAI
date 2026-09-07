/// Node domain model matching contracts/node.schema.json
class NodeModel {
  final String id;
  final String name;
  final String category;
  final String floorId;
  final double x;
  final double y;
  final bool accessible;
  final Map<String, dynamic> metadata;

  const NodeModel({
    required this.id,
    required this.name,
    required this.category,
    required this.floorId,
    required this.x,
    required this.y,
    required this.accessible,
    this.metadata = const {},
  });

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    return NodeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      floorId: json['floorId'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      accessible: json['accessible'] as bool? ?? true,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'floorId': floorId,
      'x': x,
      'y': y,
      'accessible': accessible,
      'metadata': metadata,
    };
  }

  NodeModel copyWith({
    String? id,
    String? name,
    String? category,
    String? floorId,
    double? x,
    double? y,
    bool? accessible,
    Map<String, dynamic>? metadata,
  }) {
    return NodeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      floorId: floorId ?? this.floorId,
      x: x ?? this.x,
      y: y ?? this.y,
      accessible: accessible ?? this.accessible,
      metadata: metadata ?? this.metadata,
    );
  }
}
