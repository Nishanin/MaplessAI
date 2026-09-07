/// Version snapshot domain entity
/// Owner: Piyush (Map Versioning ONLY)
class VersionSnapshot {
  final String id;
  final String buildingId;
  final int versionNumber;
  final String versionTag;
  final String changeSummary;
  final String createdBy;
  final DateTime createdAt;
  final Map<String, dynamic> graphSnapshot;

  const VersionSnapshot({
    required this.id,
    required this.buildingId,
    required this.versionNumber,
    required this.versionTag,
    required this.changeSummary,
    required this.createdBy,
    required this.createdAt,
    required this.graphSnapshot,
  });

  factory VersionSnapshot.fromJson(Map<String, dynamic> json) {
    return VersionSnapshot(
      id: json['id'] as String,
      buildingId: json['buildingId'] as String,
      versionNumber: json['versionNumber'] as int,
      versionTag: json['versionTag'] as String,
      changeSummary: json['changeSummary'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      graphSnapshot: (json['graphSnapshot'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buildingId': buildingId,
      'versionNumber': versionNumber,
      'versionTag': versionTag,
      'changeSummary': changeSummary,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'graphSnapshot': graphSnapshot,
    };
  }
}
