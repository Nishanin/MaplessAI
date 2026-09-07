/// Building domain model matching contracts/building.schema.json
class BuildingModel {
  final String id;
  final String name;
  final String address;
  final String category;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> metadata;

  const BuildingModel({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.metadata = const {},
  });

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      category: json['category'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'metadata': metadata,
    };
  }
}
