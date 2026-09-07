/// SemanticMetadata domain model matching contracts/semantic-metadata.schema.json
class SemanticMetadataModel {
  final String entityId;
  final String entityType;
  final List<String> tags;
  final List<String> aliases;
  final String? description;
  final String? department;
  final String? operationalHours;
  final int? capacity;
  final Map<String, dynamic> customAttributes;

  const SemanticMetadataModel({
    required this.entityId,
    required this.entityType,
    this.tags = const [],
    this.aliases = const [],
    this.description,
    this.department,
    this.operationalHours,
    this.capacity,
    this.customAttributes = const {},
  });

  factory SemanticMetadataModel.fromJson(Map<String, dynamic> json) {
    return SemanticMetadataModel(
      entityId: json['entityId'] as String,
      entityType: json['entityType'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      aliases: (json['aliases'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      description: json['description'] as String?,
      department: json['department'] as String?,
      operationalHours: json['operationalHours'] as String?,
      capacity: json['capacity'] as int?,
      customAttributes: (json['customAttributes'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entityId': entityId,
      'entityType': entityType,
      'tags': tags,
      'aliases': aliases,
      if (description != null) 'description': description,
      if (department != null) 'department': department,
      if (operationalHours != null) 'operationalHours': operationalHours,
      if (capacity != null) 'capacity': capacity,
      'customAttributes': customAttributes,
    };
  }
}
