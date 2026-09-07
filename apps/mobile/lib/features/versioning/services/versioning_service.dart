import '../domain/version_snapshot.dart';

/// Map Versioning Service Interface & Baseline Stub
/// Owner: Piyush (Map Versioning ONLY)
///
/// Full snapshot diffing, audit metadata, and rollback logic
/// will be implemented by Piyush on feature/piyush-versioning
abstract class IVersioningService {
  Future<VersionSnapshot> createVersion(
    String buildingId,
    Map<String, dynamic> snapshotData,
    String changeSummary,
    String createdBy,
  );

  Future<List<VersionSnapshot>> getVersionHistory(String buildingId);

  Future<Map<String, dynamic>> compareVersions(
    String buildingId,
    int baseVersion,
    int targetVersion,
  );

  Future<bool> rollbackVersion(
    String buildingId,
    int targetVersion,
    String restoredBy,
  );
}

class VersioningService implements IVersioningService {
  @override
  Future<VersionSnapshot> createVersion(
    String buildingId,
    Map<String, dynamic> snapshotData,
    String changeSummary,
    String createdBy,
  ) async {
    return VersionSnapshot(
      id: 'snapshot-initial',
      buildingId: buildingId,
      versionNumber: 1,
      versionTag: 'v1.0.0-initial',
      changeSummary: changeSummary,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      graphSnapshot: snapshotData,
    );
  }

  @override
  Future<List<VersionSnapshot>> getVersionHistory(String buildingId) async {
    return [
      VersionSnapshot(
        id: 'snapshot-1',
        buildingId: buildingId,
        versionNumber: 1,
        versionTag: 'v1.0.0-baseline',
        changeSummary: 'Initial creator baseline walkthrough',
        createdBy: 'nishant-creator',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        graphSnapshot: const {},
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> compareVersions(
    String buildingId,
    int baseVersion,
    int targetVersion,
  ) async {
    return {
      'buildingId': buildingId,
      'baseVersion': baseVersion,
      'targetVersion': targetVersion,
      'diff': {'nodesAdded': [], 'nodesRemoved': []},
    };
  }

  @override
  Future<bool> rollbackVersion(
    String buildingId,
    int targetVersion,
    String restoredBy,
  ) async {
    return true;
  }
}
