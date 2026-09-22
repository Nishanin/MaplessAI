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
  final String status;
  final String? parentVersionId;

  const VersionSnapshot({
    required this.id,
    required this.buildingId,
    required this.versionNumber,
    required this.versionTag,
    required this.changeSummary,
    required this.createdBy,
    required this.createdAt,
    required this.graphSnapshot,
    this.status = 'published',
    this.parentVersionId,
  });

  factory VersionSnapshot.fromJson(Map<String, dynamic> json) {
    return VersionSnapshot(
      id: json['id'] as String? ?? '',
      buildingId: json['buildingId'] as String? ?? '',
      versionNumber: json['versionNumber'] as int? ?? 1,
      versionTag: json['versionTag'] as String? ?? '',
      changeSummary: json['changeSummary'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      graphSnapshot: (json['graphSnapshot'] as Map<String, dynamic>?) ?? const {},
      status: json['status'] as String? ?? 'published',
      parentVersionId: json['parentVersionId'] as String?,
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
      'status': status,
      if (parentVersionId != null) 'parentVersionId': parentVersionId,
    };
  }
}
