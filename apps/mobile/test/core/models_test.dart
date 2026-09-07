import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/navigation_request_model.dart';
import 'package:mapless_ai/core/models/navigation_response_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/models/semantic_metadata_model.dart';
import 'package:mapless_ai/core/models/ai_query_model.dart';
import 'package:mapless_ai/core/models/ai_response_model.dart';

void main() {
  group('Core Models Parsing & Contract Verification', () {
    late Map<String, dynamic> mockJson;

    setUpAll(() {
      // Load the common mock data fixture
      // Looking relative to test execution dir
      final paths = [
        '../../test_data/vit_floor_1.json',
        'assets/test_data/vit_floor_1.json',
        'test_data/vit_floor_1.json',
      ];

      File? file;
      for (final p in paths) {
        final f = File(p);
        if (f.existsSync()) {
          file = f;
          break;
        }
      }

      expect(file, isNotNull, reason: 'vit_floor_1.json must exist');
      final content = file!.readAsStringSync();
      mockJson = jsonDecode(content) as Map<String, dynamic>;
    });

    test('NodeModel correctly parses nodes from vit_floor_1.json', () {
      final rawNodes = mockJson['nodes'] as List<dynamic>;
      expect(rawNodes.length, greaterThan(0));

      final nodes = rawNodes.map((n) => NodeModel.fromJson(n as Map<String, dynamic>)).toList();
      expect(nodes.length, equals(rawNodes.length));

      // Verify specific node attributes
      final entrance = nodes.firstWhere((n) => n.id == 'entrance');
      expect(entrance.name, equals('Main Entrance'));
      expect(entrance.accessible, isTrue);
      expect(entrance.x, equals(0.0));
      expect(entrance.y, equals(15.0));

      final stairs = nodes.firstWhere((n) => n.id == 'staircase');
      expect(stairs.accessible, isFalse);

      // Verify serialization round-trip
      final serialized = entrance.toJson();
      expect(serialized['id'], equals('entrance'));
      expect(serialized['category'], equals('entrance'));
    });

    test('EdgeModel correctly parses edges from vit_floor_1.json', () {
      final rawEdges = mockJson['edges'] as List<dynamic>;
      expect(rawEdges.length, greaterThan(0));

      final edges = rawEdges.map((e) => EdgeModel.fromJson(e as Map<String, dynamic>)).toList();
      expect(edges.length, equals(rawEdges.length));

      final firstEdge = edges.first;
      expect(firstEdge.distance, greaterThan(0));
      expect(firstEdge.bearing, inInclusiveRange(0.0, 360.0));
      expect(firstEdge.blocked, isFalse);
    });

    test('BuildingModel & FloorModel parse correctly', () {
      final building = BuildingModel.fromJson(mockJson['building'] as Map<String, dynamic>);
      expect(building.id, equals('vit-ce'));
      expect(building.name, contains('VIT'));

      final floor = FloorModel.fromJson(mockJson['floor'] as Map<String, dynamic>);
      expect(floor.id, equals('floor-1'));
      expect(floor.floorNumber, equals(1));
    });

    test('SemanticMetadataModel parses semantic entries correctly', () {
      final rawMeta = mockJson['semanticMetadata'] as List<dynamic>;
      expect(rawMeta.length, greaterThan(0));

      final metaList = rawMeta.map((m) => SemanticMetadataModel.fromJson(m as Map<String, dynamic>)).toList();
      final labMeta = metaList.firstWhere((m) => m.entityId == 'lab-101');
      expect(labMeta.tags, contains('computers'));
      expect(labMeta.capacity, equals(45));
    });

    test('NavigationRequestModel serialization conforms to contract', () {
      const req = NavigationRequestModel(
        buildingId: 'vit-ce',
        startNodeId: 'reception',
        destinationNodeId: 'lab-101',
        preferences: NavigationPreferencesModel(
          accessible: true,
          avoidStairs: true,
          avoidBlockedEdges: true,
        ),
      );

      final json = req.toJson();
      expect(json['buildingId'], equals('vit-ce'));
      expect(json['startNodeId'], equals('reception'));
      expect(json['preferences']['accessible'], isTrue);

      final deserialized = NavigationRequestModel.fromJson(json);
      expect(deserialized.buildingId, equals(req.buildingId));
      expect(deserialized.preferences.accessible, isTrue);
    });

    test('NavigationResponseModel serialization conforms to contract', () {
      const resp = NavigationResponseModel(
        success: true,
        pathNodeIds: ['reception', 'corridor', 'lab-101'],
        edgeIds: ['edge-1', 'edge-2'],
        totalDistance: 30.0,
        estimatedTimeSeconds: 25.0,
        turnInstructions: [
          TurnInstructionModel(
            step: 1,
            instruction: 'Walk to corridor',
            distance: 15.0,
            bearing: 90.0,
          ),
        ],
      );

      final json = resp.toJson();
      expect(json['success'], isTrue);
      expect(json['totalDistance'], equals(30.0));
      expect(json['turnInstructions'], isNotEmpty);
    });

    test('AiQuery & AiResponse serialization conforms to contract', () {
      const query = AiQueryModel(
        text: 'Find nearest laboratory',
        buildingId: 'vit-ce',
      );
      expect(query.toJson()['text'], equals('Find nearest laboratory'));

      const response = AiResponseModel(
        intent: 'FIND_NEAREST',
        entities: [AiEntityModel(type: 'category', value: 'laboratory')],
        constraints: {'category': 'laboratory'},
        targetNodeId: 'lab-101',
        confidence: 0.95,
        responseMessage: 'Found Lab 101',
      );
      final resJson = response.toJson();
      expect(resJson['intent'], equals('FIND_NEAREST'));
      expect(resJson['confidence'], equals(0.95));
      expect(resJson['targetNodeId'], equals('lab-101'));
    });
  });
}
