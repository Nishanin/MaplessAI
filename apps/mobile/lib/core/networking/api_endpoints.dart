import '../constants/api_constants.dart';

abstract final class ApiEndpoints {
  static String health(String baseUrl) => '$baseUrl${ApiConstants.healthEndpoint}';

  // Mapping (Nishant)
  static String buildings(String baseUrl) => '$baseUrl${ApiConstants.mappingPrefix}/buildings';
  static String floorGraph(String baseUrl, String buildingId, String floorId) =>
      '$baseUrl${ApiConstants.mappingPrefix}/buildings/$buildingId/floors/$floorId/graph';

  // Navigation (Pratik)
  static String computeRoute(String baseUrl) => '$baseUrl${ApiConstants.navigationPrefix}/route';

  // AI & Semantic (Surabhi)
  static String aiQuery(String baseUrl) => '$baseUrl${ApiConstants.aiPrefix}/query';

  // Versioning (Piyush)
  static String versionSnapshots(String baseUrl, String buildingId) =>
      '$baseUrl${ApiConstants.versioningPrefix}/buildings/$buildingId/snapshots';
  static String versionHistory(String baseUrl, String buildingId) =>
      '$baseUrl${ApiConstants.versioningPrefix}/buildings/$buildingId/history';
  static String versionCompare(String baseUrl, String buildingId) =>
      '$baseUrl${ApiConstants.versioningPrefix}/buildings/$buildingId/compare';
  static String versionRollback(String baseUrl, String buildingId) =>
      '$baseUrl${ApiConstants.versioningPrefix}/buildings/$buildingId/rollback';
}
