/// Floor domain model matching contracts/floor.schema.json
class FloorModel {
  final String id;
  final String buildingId;
  final int floorNumber;
  final String name;
  final double elevation;
  final Map<String, dynamic> metadata;

  const FloorModel({
    required this.id,
    required this.buildingId,
    required this.floorNumber,
    required this.name,
    this.elevation = 0.0,
    this.metadata = const {},
  });

  factory FloorModel.fromJson(Map<String, dynamic> json) {
    return FloorModel(
      id: json['id'] as String,
      buildingId: json['buildingId'] as String,
      floorNumber: json['floorNumber'] as int,
      name: json['name'] as String,
      elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buildingId': buildingId,
      'floorNumber': floorNumber,
      'name': name,
      'elevation': elevation,
      'metadata': metadata,
    };
  }
}
