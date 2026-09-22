import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/constants/api_constants.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/networking/api_client.dart';
import 'package:mapless_ai/features/versioning/services/versioning_service.dart';

class MockApiClient extends ApiClient {
  String? lastGetUrl;
  String? lastPostUrl;
  Map<String, dynamic>? lastPostBody;
  Map<String, dynamic> responseToReturn = {};
  bool shouldThrow = false;

  @override
  Future<Map<String, dynamic>> get(String url) async {
    lastGetUrl = url;
    if (shouldThrow) {
      throw const NetworkException('Connection failed');
    }
    return responseToReturn;
  }

  @override
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    lastPostUrl = url;
    lastPostBody = body;
    if (shouldThrow) {
      throw const NetworkException('Connection failed');
    }
    return responseToReturn;
  }
}

void main() {
  group('VersioningService Endpoint Construction & Integration Tests', () {
    late MockApiClient mockApiClient;
    late VersioningService service;
    const testBuildingId = 'building-ab1-vit';
    const customBaseUrl = 'https://api.mapless.ai';

    setUp(() {
      mockApiClient = MockApiClient();
      service = VersioningService(
        apiClient: mockApiClient,
        baseUrl: customBaseUrl,
      );
    });

    test('1. Snapshot endpoint contains correct buildingId and API prefix', () async {
      mockApiClient.responseToReturn = {
        'version': {
          'id': 'snap-001',
          'buildingId': testBuildingId,
          'versionNumber': 2,
          'versionTag': 'v2.0.0',
          'changeSummary': 'Added Floor 2 nodes',
          'createdBy': 'test-creator',
          'createdAt': '2026-09-22T12:00:00.000Z',
          'graphSnapshot': {'nodes': []},
        },
      };

      final snapshot = await service.createVersion(
        testBuildingId,
        {'nodes': []},
        'Added Floor 2 nodes',
        'test-creator',
      );

      // Verify exact URL construction
      const expectedEndpoint =
          '$customBaseUrl/api/v1/versioning/buildings/$testBuildingId/snapshots';
      expect(mockApiClient.lastPostUrl, equals(expectedEndpoint));
      expect(mockApiClient.lastPostUrl, contains('/api/v1/versioning'));
      expect(mockApiClient.lastPostUrl, contains('/buildings/$testBuildingId/snapshots'));
      expect(mockApiClient.lastPostUrl, isNot(contains('/buildings//snapshots')));

      // Verify result parsing
      expect(snapshot.id, equals('snap-001'));
      expect(snapshot.buildingId, equals(testBuildingId));
      expect(snapshot.versionNumber, equals(2));
    });

    test('2. History endpoint contains correct buildingId and API prefix', () async {
      mockApiClient.responseToReturn = {
        'versions': [
          {
            'id': 'snap-001',
            'buildingId': testBuildingId,
            'versionNumber': 1,
            'versionTag': 'v1.0.0',
            'changeSummary': 'Initial baseline',
            'createdBy': 'nishant-creator',
            'createdAt': '2026-09-20T10:00:00.000Z',
            'graphSnapshot': <String, dynamic>{},
          }
        ],
      };

      final history = await service.getVersionHistory(testBuildingId);

      // Verify exact URL construction
      const expectedEndpoint =
          '$customBaseUrl/api/v1/versioning/buildings/$testBuildingId/history';
      expect(mockApiClient.lastGetUrl, equals(expectedEndpoint));
      expect(mockApiClient.lastGetUrl, contains('/api/v1/versioning'));
      expect(mockApiClient.lastGetUrl, contains('/buildings/$testBuildingId/history'));
      expect(mockApiClient.lastGetUrl, isNot(contains('/buildings//history')));

      // Verify result parsing
      expect(history.length, equals(1));
      expect(history.first.id, equals('snap-001'));
      expect(history.first.buildingId, equals(testBuildingId));
    });

    test('3. Compare endpoint contains correct buildingId and API prefix', () async {
      mockApiClient.responseToReturn = {
        'buildingId': testBuildingId,
        'baseVersion': 1,
        'targetVersion': 2,
        'diff': {
          'nodesAdded': ['node-f2-101'],
          'nodesRemoved': [],
          'nodesModified': [],
        },
      };

      final diff = await service.compareVersions(testBuildingId, 1, 2);

      // Verify exact URL construction
      const expectedEndpoint =
          '$customBaseUrl/api/v1/versioning/buildings/$testBuildingId/compare';
      expect(mockApiClient.lastPostUrl, equals(expectedEndpoint));
      expect(mockApiClient.lastPostUrl, contains('/api/v1/versioning'));
      expect(mockApiClient.lastPostUrl, contains('/buildings/$testBuildingId/compare'));
      expect(mockApiClient.lastPostUrl, isNot(contains('/buildings//compare')));

      // Verify body
      expect(mockApiClient.lastPostBody?['baseVersion'], equals(1));
      expect(mockApiClient.lastPostBody?['targetVersion'], equals(2));
      expect(diff['diff']['nodesAdded'], contains('node-f2-101'));
    });

    test('4. Rollback endpoint contains correct buildingId and API prefix', () async {
      mockApiClient.responseToReturn = {
        'success': true,
        'restoredVersion': 1,
      };

      final success = await service.rollbackVersion(testBuildingId, 1, 'admin-user');

      // Verify exact URL construction
      const expectedEndpoint =
          '$customBaseUrl/api/v1/versioning/buildings/$testBuildingId/rollback';
      expect(mockApiClient.lastPostUrl, equals(expectedEndpoint));
      expect(mockApiClient.lastPostUrl, contains('/api/v1/versioning'));
      expect(mockApiClient.lastPostUrl, contains('/buildings/$testBuildingId/rollback'));
      expect(mockApiClient.lastPostUrl, isNot(contains('/buildings//rollback')));

      // Verify body
      expect(mockApiClient.lastPostBody?['targetVersion'], equals(1));
      expect(mockApiClient.lastPostBody?['restoredBy'], equals('admin-user'));
      expect(success, isTrue);
    });

    test('5. Default baseUrl uses ApiConstants.localhostBaseUrl and versioningPrefix', () async {
      final defaultService = VersioningService(apiClient: mockApiClient);
      mockApiClient.responseToReturn = {'versions': []};

      await defaultService.getVersionHistory('default-bldg');

      expect(
        mockApiClient.lastGetUrl,
        equals(
          '${ApiConstants.localhostBaseUrl}${ApiConstants.versioningPrefix}/buildings/default-bldg/history',
        ),
      );
    });

    group('6. Graceful Offline Fallback & Error Handling', () {
      setUp(() {
        mockApiClient.shouldThrow = true;
      });

      test('createVersion falls back to local offline snapshot on network error', () async {
        final result = await service.createVersion(
          testBuildingId,
          {'test': 123},
          'Offline commit',
          'tester',
        );

        expect(result.id, equals('snapshot-local'));
        expect(result.buildingId, equals(testBuildingId));
        expect(result.versionNumber, equals(1));
        expect(result.versionTag, equals('v1.0.0-offline'));
        expect(result.changeSummary, equals('Offline commit'));
        expect(result.createdBy, equals('tester'));
      });

      test('getVersionHistory falls back to baseline snapshot list on network error', () async {
        final history = await service.getVersionHistory(testBuildingId);

        expect(history.length, equals(1));
        expect(history.first.id, equals('snapshot-baseline'));
        expect(history.first.buildingId, equals(testBuildingId));
        expect(history.first.versionTag, equals('v1.0.0-baseline'));
      });

      test('compareVersions falls back to empty diff structure on network error', () async {
        final diff = await service.compareVersions(testBuildingId, 1, 2);

        expect(diff['buildingId'], equals(testBuildingId));
        expect(diff['baseVersion'], equals(1));
        expect(diff['targetVersion'], equals(2));
        expect(diff['diff']['nodesAdded'], isEmpty);
        expect(diff['diff']['nodesRemoved'], isEmpty);
        expect(diff['diff']['nodesModified'], isEmpty);
      });

      test('rollbackVersion falls back to true on network error', () async {
        final success = await service.rollbackVersion(testBuildingId, 1, 'tester');
        expect(success, isTrue);
      });
    });
  });
}
