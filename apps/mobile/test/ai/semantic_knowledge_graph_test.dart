import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/semantic_metadata_model.dart';
import 'package:mapless_ai/features/ai/domain/semantic_knowledge_graph.dart';

/// Unit tests for SemanticKnowledgeGraph
/// Owner: Surabhi (Semantic AI Domain)
///
/// Covers:
///   - tag filtering
///   - alias filtering
///   - category filtering (via tags)
///   - accessibleOnly filtering
///   - no-match behaviour (empty list, no invented IDs)
///   - duplicate prevention
///   - entityType guard (non-node entities excluded)
void main() {
  // ── Fixtures ─────────────────────────────────────────────────────────────

  /// Lab-101 semantic metadata from vit_floor_1.json
  const labMeta = SemanticMetadataModel(
    entityId: 'lab-101',
    entityType: 'node',
    tags: ['computers', 'software', 'ai', 'programming', 'linux', 'workstations'],
    aliases: ['Software Lab 1', 'Computer Lab 101', 'Advanced Computing Lab'],
    department: 'Computer Engineering',
    operationalHours: '08:00 - 18:00',
    capacity: 45,
    customAttributes: {'airConditioned': true, 'projectorAvailable': true},
  );

  /// Library semantic metadata from vit_floor_1.json
  const libraryMeta = SemanticMetadataModel(
    entityId: 'library',
    entityType: 'node',
    tags: ['books', 'study', 'research', 'quiet', 'journals'],
    aliases: ['Dept Library', 'CE Reference Section'],
    department: 'Computer Engineering',
    operationalHours: '09:00 - 17:00',
    capacity: 60,
    customAttributes: {'wifiZone': true},
  );

  /// Reception semantic metadata from vit_floor_1.json
  const receptionMeta = SemanticMetadataModel(
    entityId: 'reception',
    entityType: 'node',
    tags: ['help', 'info', 'inquiries', 'visitor desk', 'staff'],
    aliases: ['Help Desk', 'Front Desk', 'Information Desk'],
    department: 'Administration',
    operationalHours: '08:30 - 17:30',
    capacity: 5,
    customAttributes: {'emergencyFirstAid': true},
  );

  /// Emergency exit semantic metadata from vit_floor_1.json
  /// Note: the fixture's customAttributes for exit-a is {evacuationPriority: 1}
  /// — it does NOT contain an 'accessible' key.
  const exitMeta = SemanticMetadataModel(
    entityId: 'exit-a',
    entityType: 'node',
    tags: ['emergency', 'fire exit', 'safety', 'evacuation'],
    aliases: ['Fire Exit 1', 'Emergency Door South'],
    department: 'Safety & Facilities',
    operationalHours: '24/7',
    capacity: 100,
    customAttributes: {'evacuationPriority': 1},
  );

  /// A building-type entity — must never appear in node results
  const buildingMeta = SemanticMetadataModel(
    entityId: 'vit-ce',
    entityType: 'building',
    tags: ['computers', 'college'],
    aliases: ['VIT CE'],
    customAttributes: {},
  );

  /// A lab-type entity with accessible: true
  const accessibleLabMeta = SemanticMetadataModel(
    entityId: 'lab-accessible',
    entityType: 'node',
    tags: ['computers', 'laboratory'],
    aliases: ['Accessible Lab'],
    customAttributes: {'accessible': true},
  );

  /// A lab-type entity without accessible attribute
  const inaccessibleLabMeta = SemanticMetadataModel(
    entityId: 'lab-inaccessible',
    entityType: 'node',
    tags: ['computers', 'laboratory'],
    aliases: ['Old Lab'],
    customAttributes: {},
  );

  // ── Factory helper ────────────────────────────────────────────────────────

  /// Returns a freshly populated graph containing all VIT fixture entries.
  SemanticKnowledgeGraph buildVitGraph() {
    final graph = SemanticKnowledgeGraph();
    graph.addMetadata(labMeta);
    graph.addMetadata(libraryMeta);
    graph.addMetadata(receptionMeta);
    graph.addMetadata(exitMeta);
    return graph;
  }

  // ── addMetadata / getMetadata ─────────────────────────────────────────────

  group('addMetadata and getMetadata', () {
    test('stores and retrieves metadata by entityId', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(labMeta);
      expect(graph.getMetadata('lab-101'), equals(labMeta));
    });

    test('count reflects number of stored entries', () {
      final graph = buildVitGraph();
      expect(graph.count, equals(4));
    });

    test('getMetadata returns null for unknown entityId', () {
      final graph = buildVitGraph();
      expect(graph.getMetadata('does-not-exist'), isNull);
    });

    test('addMetadata replaces existing entry for same entityId', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(labMeta);
      const updated = SemanticMetadataModel(
        entityId: 'lab-101',
        entityType: 'node',
        tags: ['updated'],
        aliases: [],
        customAttributes: {},
      );
      graph.addMetadata(updated);
      expect(graph.count, equals(1));
      expect(graph.getMetadata('lab-101')!.tags, equals(['updated']));
    });
  });

  // ── Tag filtering ─────────────────────────────────────────────────────────

  group('findMatchingNodeIds — tag filter', () {
    test('returns node IDs whose tags contain an exact match', () {
      final graph = buildVitGraph();
      final results = graph.findMatchingNodeIds(tag: 'computers');
      expect(results, contains('lab-101'));
      expect(results, isNot(contains('library')));
    });

    test('tag matching is case-insensitive', () {
      final graph = buildVitGraph();
      expect(graph.findMatchingNodeIds(tag: 'COMPUTERS'), contains('lab-101'));
      expect(graph.findMatchingNodeIds(tag: 'Computers'), contains('lab-101'));
    });

    test('tag matching is exact — partial tag does not match', () {
      final graph = buildVitGraph();
      // 'computer' is NOT a tag; 'computers' is
      expect(graph.findMatchingNodeIds(tag: 'computer'), isEmpty);
    });

    test('returns multiple nodes when tag is shared', () {
      // Both labMeta and accessibleLabMeta have 'computers'
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(labMeta);
      graph.addMetadata(accessibleLabMeta);
      final results = graph.findMatchingNodeIds(tag: 'computers');
      expect(results.length, equals(2));
      expect(results, containsAll(['lab-101', 'lab-accessible']));
    });

    test('returns empty list when no node has the given tag', () {
      final graph = buildVitGraph();
      expect(graph.findMatchingNodeIds(tag: 'canteen'), isEmpty);
    });
  });

  // ── Alias filtering ───────────────────────────────────────────────────────

  group('findMatchingNodeIds — alias filter', () {
    test('returns node ID when alias substring matches', () {
      final graph = buildVitGraph();
      final results = graph.findMatchingNodeIds(alias: 'Software Lab');
      expect(results, contains('lab-101'));
    });

    test('alias matching is case-insensitive', () {
      final graph = buildVitGraph();
      expect(
        graph.findMatchingNodeIds(alias: 'software lab'),
        contains('lab-101'),
      );
      expect(
        graph.findMatchingNodeIds(alias: 'SOFTWARE LAB'),
        contains('lab-101'),
      );
    });

    test('partial alias substring is sufficient', () {
      final graph = buildVitGraph();
      // 'Dept' is a substring of 'Dept Library'
      expect(graph.findMatchingNodeIds(alias: 'Dept'), contains('library'));
    });

    test('returns empty list when no alias matches', () {
      final graph = buildVitGraph();
      expect(graph.findMatchingNodeIds(alias: 'Dean Office'), isEmpty);
    });

    test('alias matching for fire exit', () {
      final graph = buildVitGraph();
      final results = graph.findMatchingNodeIds(alias: 'Fire Exit');
      expect(results, contains('exit-a'));
    });
  });

  // ── Category filtering ────────────────────────────────────────────────────

  group('findMatchingNodeIds — category filter', () {
    test('returns node whose tags include the category keyword', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(accessibleLabMeta); // tags: ['computers', 'laboratory']
      final results = graph.findMatchingNodeIds(category: 'laboratory');
      expect(results, contains('lab-accessible'));
    });

    test('category filter is case-insensitive', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(accessibleLabMeta);
      expect(
        graph.findMatchingNodeIds(category: 'LABORATORY'),
        contains('lab-accessible'),
      );
    });

    test('returns empty when no node tag matches the category', () {
      final graph = buildVitGraph();
      // None of the VIT fixture nodes have 'canteen' in their tags
      expect(graph.findMatchingNodeIds(category: 'canteen'), isEmpty);
    });
  });

  // ── accessibleOnly filtering ───────────────────────────────────────────────

  group('findMatchingNodeIds — accessibleOnly filter', () {
    test('returns only nodes with customAttributes.accessible == true', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(accessibleLabMeta);   // accessible: true
      graph.addMetadata(inaccessibleLabMeta); // no accessible attribute

      final results = graph.findMatchingNodeIds(accessibleOnly: true);
      expect(results, contains('lab-accessible'));
      expect(results, isNot(contains('lab-inaccessible')));
    });

    test('accessible: false excludes entity even when tags match', () {
      final inaccessible = const SemanticMetadataModel(
        entityId: 'lab-blocked',
        entityType: 'node',
        tags: ['computers'],
        aliases: [],
        customAttributes: {'accessible': false},
      );
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(inaccessible);
      expect(graph.findMatchingNodeIds(accessibleOnly: true), isEmpty);
    });

    test('accessibleOnly: false does not filter any entity', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(accessibleLabMeta);
      graph.addMetadata(inaccessibleLabMeta);
      // accessibleOnly: false means the filter is inactive
      final results = graph.findMatchingNodeIds(accessibleOnly: false);
      expect(results.length, equals(2));
    });

    test('accessibleOnly: null does not filter any entity', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(accessibleLabMeta);
      graph.addMetadata(inaccessibleLabMeta);
      final results = graph.findMatchingNodeIds();
      expect(results.length, equals(2));
    });
  });

  // ── No-match behaviour ────────────────────────────────────────────────────

  group('findMatchingNodeIds — no-match behaviour', () {
    test('returns an empty list when graph is empty', () {
      final graph = SemanticKnowledgeGraph();
      expect(graph.findMatchingNodeIds(tag: 'computers'), isEmpty);
    });

    test('no node ID is invented when there is no match', () {
      final graph = buildVitGraph();
      final result = graph.findMatchingNodeIds(tag: 'canteen');
      expect(result, isEmpty);
      // Confirm the result contains nothing — no hardcoded fallback ID
      expect(result.contains('lab-101'), isFalse);
      expect(result.contains('exit-a'), isFalse);
    });
  });

  // ── Duplicate prevention ───────────────────────────────────────────────────

  group('findMatchingNodeIds — duplicate prevention', () {
    test('each node ID appears at most once even when multiple filters could match it', () {
      // The combined filter scenario: a node matches both tag and alias
      // When only one filter is supplied at a time this is fine, but
      // calling with no filters (all null) should return each ID once.
      final graph = buildVitGraph();
      final results = graph.findMatchingNodeIds(); // no filters → all nodes
      final unique = results.toSet();
      expect(results.length, equals(unique.length),
          reason: 'Duplicate node IDs found in results');
    });

    test('adding the same metadata twice does not produce duplicate IDs', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(labMeta);
      graph.addMetadata(labMeta); // overwrite — same entityId
      final results = graph.findMatchingNodeIds(tag: 'computers');
      expect(results.where((id) => id == 'lab-101').length, equals(1));
    });
  });

  // ── entityType guard ──────────────────────────────────────────────────────

  group('findMatchingNodeIds — entityType guard', () {
    test('building-type entities are excluded even if their tags match', () {
      final graph = SemanticKnowledgeGraph();
      graph.addMetadata(buildingMeta); // entityType: 'building', tags: ['computers']
      final results = graph.findMatchingNodeIds(tag: 'computers');
      expect(results, isEmpty);
      expect(results, isNot(contains('vit-ce')));
    });
  });

  // ── clear ─────────────────────────────────────────────────────────────────

  group('clear', () {
    test('removes all metadata and returns 0 count', () {
      final graph = buildVitGraph();
      expect(graph.count, equals(4));
      graph.clear();
      expect(graph.count, equals(0));
      expect(graph.findMatchingNodeIds(tag: 'computers'), isEmpty);
    });
  });

  // ── Integration: load from vit_floor_1.json ────────────────────────────

  group('Integration — vit_floor_1.json fixture', () {
    late SemanticKnowledgeGraph graph;

    setUpAll(() {
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
      final json =
          jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;
      final rawMeta = json['semanticMetadata'] as List<dynamic>;

      graph = SemanticKnowledgeGraph();
      for (final m in rawMeta) {
        graph.addMetadata(
          SemanticMetadataModel.fromJson(m as Map<String, dynamic>),
        );
      }
    });

    test('graph is populated with 4 entries from the fixture', () {
      expect(graph.count, equals(4));
    });

    test('"computers" tag resolves to lab-101', () {
      final results = graph.findMatchingNodeIds(tag: 'computers');
      expect(results, contains('lab-101'));
    });

    test('"emergency" tag resolves to exit-a', () {
      final results = graph.findMatchingNodeIds(tag: 'emergency');
      expect(results, contains('exit-a'));
    });

    test('"quiet" tag resolves to library', () {
      final results = graph.findMatchingNodeIds(tag: 'quiet');
      expect(results, contains('library'));
    });

    test('alias "Software Lab" resolves to lab-101', () {
      final results = graph.findMatchingNodeIds(alias: 'Software Lab');
      expect(results, contains('lab-101'));
    });

    test('alias "Fire Exit" resolves to exit-a', () {
      final results = graph.findMatchingNodeIds(alias: 'Fire Exit');
      expect(results, contains('exit-a'));
    });

    test('accessibleOnly=true returns empty list — no fixture entry has accessible:true in customAttributes', () {
      // The vit_floor_1.json semantic metadata does not include 'accessible: true'
      // in any customAttributes field. The node's own 'accessible' field is a
      // spatial graph attribute, not part of SemanticMetadataModel.customAttributes.
      // This correctly tests the filter contract: no match → empty list.
      final results = graph.findMatchingNodeIds(accessibleOnly: true);
      expect(results, isEmpty);
    });
  });
}
