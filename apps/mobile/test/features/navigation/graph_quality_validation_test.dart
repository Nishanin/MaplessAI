import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/errors/exceptions.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/features/navigation/domain/spatial_graph.dart';

void main() {
  NodeModel createNode(
    String id, {
    String? name,
    String category = 'corridor',
    String floorId = 'floor-1',
    double x = 0.0,
    double y = 0.0,
    bool accessible = true,
    Map<String, dynamic> metadata = const {},
  }) {
    return NodeModel(
      id: id,
      name: name ?? 'Node $id',
      category: category,
      floorId: floorId,
      x: x,
      y: y,
      accessible: accessible,
      metadata: metadata,
    );
  }

  EdgeModel createEdge(
    String id,
    String startNodeId,
    String endNodeId, {
    double distance = 10.0,
    double bearing = 90.0,
    bool accessible = true,
    bool blocked = false,
    Map<String, dynamic> metadata = const {},
  }) {
    return EdgeModel(
      id: id,
      startNodeId: startNodeId,
      endNodeId: endNodeId,
      distance: distance,
      bearing: bearing,
      accessible: accessible,
      blocked: blocked,
      metadata: metadata,
    );
  }

  group('Phase 10 — Spatial Graph Quality Validation & Route Robustness', () {
    // -------------------------------------------------------------------------
    // 1. Structural Errors
    // -------------------------------------------------------------------------
    group('1. Structural Errors (DiagnosticSeverity.error)', () {
      test('Empty graph flags ERR_EMPTY_GRAPH and marks validation invalid', () {
        final graph = SpatialGraph();
        final result = graph.validate();

        expect(result.isValid, isFalse);
        expect(result.hasErrors, isTrue);
        expect(result.hasCode(DiagnosticCode.emptyGraph), isTrue);
        expect(result.errorDiagnostics.length, equals(1));
        expect(result.errorDiagnostics.first.severity, equals(DiagnosticSeverity.error));
        expect(result.errorDiagnostics.first.code, equals(DiagnosticCode.emptyGraph));
        expect(result.errors, contains(contains('contains 0 nodes')));

        expect(() => graph.validateOrThrow(), throwsA(isA<GraphException>()));
      });

      test('Missing start node in edge references flags ERR_MISSING_START_NODE', () {
        final nodeB = createNode('b');
        final edge = createEdge('e1', 'missing_a', 'b');
        final graph = SpatialGraph.raw(nodes: [nodeB], edges: [edge]);

        final result = graph.validate();
        expect(result.isValid, isFalse);
        expect(result.hasCode(DiagnosticCode.missingStartNode), isTrue);

        final diag = result.byCode(DiagnosticCode.missingStartNode).first;
        expect(diag.severity, equals(DiagnosticSeverity.error));
        expect(diag.nodeId, equals('missing_a'));
        expect(diag.edgeId, equals('e1'));
        expect(result.errors, contains(contains('nonexistent start node')));
      });

      test('Missing end node in edge references flags ERR_MISSING_END_NODE', () {
        final nodeA = createNode('a');
        final edge = createEdge('e1', 'a', 'missing_b');
        final graph = SpatialGraph.raw(nodes: [nodeA], edges: [edge]);

        final result = graph.validate();
        expect(result.isValid, isFalse);
        expect(result.hasCode(DiagnosticCode.missingEndNode), isTrue);

        final diag = result.byCode(DiagnosticCode.missingEndNode).first;
        expect(diag.severity, equals(DiagnosticSeverity.error));
        expect(diag.nodeId, equals('missing_b'));
        expect(diag.edgeId, equals('e1'));
        expect(result.errors, contains(contains('nonexistent end node')));
      });

      test('Negative, NaN, or infinite edge distance flags ERR_INVALID_DISTANCE', () {
        final nodeA = createNode('a');
        final nodeB = createNode('b');
        final eNeg = createEdge('e_neg', 'a', 'b', distance: -5.0);
        final eNan = createEdge('e_nan', 'a', 'b', distance: double.nan);
        final eInf = createEdge('e_inf', 'a', 'b', distance: double.infinity);

        final graph = SpatialGraph.raw(
          nodes: [nodeA, nodeB],
          edges: [eNeg, eNan, eInf],
        );

        final result = graph.validate();
        expect(result.isValid, isFalse);
        final invalidDistDiags = result.byCode(DiagnosticCode.invalidDistance);
        expect(invalidDistDiags.length, equals(3));
        for (final diag in invalidDistDiags) {
          expect(diag.severity, equals(DiagnosticSeverity.error));
          expect(diag.isError, isTrue);
        }
      });

      test('Cross-floor edge lacking vertical connector metadata generates advisory warning by default, preserving graph validity', () {
        final nodeF1 = createNode('n1', floorId: 'floor-1', category: 'corridor');
        final nodeF2 = createNode('n2', floorId: 'floor-2', category: 'office');
        final edge = createEdge('e_cross', 'n1', 'n2', distance: 15.0);

        final graph = SpatialGraph();
        graph.addNodes([nodeF1, nodeF2]);
        graph.addEdge(edge);

        // Default: advisory warning, isValid remains true (allowing same-floor routes)
        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.hasCode(DiagnosticCode.malformedFloorConnector), isTrue);

        final diag = result.byCode(DiagnosticCode.malformedFloorConnector).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.edgeId, equals('e_cross'));
        expect(diag.nodeId, equals('n2'));
        expect(diag.metadata['fromFloorId'], equals('floor-1'));
        expect(diag.metadata['toFloorId'], equals('floor-2'));

        // Strict mode: promotes to fatal error (isValid = false)
        final strictResult = graph.validate(
          options: const GraphQualityOptions(strictFloorTransitions: true),
        );
        expect(strictResult.isValid, isFalse);
        expect(strictResult.hasErrors, isTrue);
        final strictDiag = strictResult.byCode(DiagnosticCode.errMalformedFloorConnector).first;
        expect(strictDiag.severity, equals(DiagnosticSeverity.error));

        // Disabling checkFloorTransitions suppresses the diagnostic completely
        final relaxedResult = graph.validate(
          options: const GraphQualityOptions(checkFloorTransitions: false),
        );
        expect(relaxedResult.hasCode(DiagnosticCode.malformedFloorConnector), isFalse);
      });

      test('Cross-floor edge with valid connector metadata (stairs, elevator, ramp) passes structural validation', () {
        // Stairs
        final s1 = createNode('s1', floorId: 'floor-1', category: 'stairs');
        final s2 = createNode('s2', floorId: 'floor-2', category: 'stairs');
        final eStairs = createEdge('e_stairs', 's1', 's2', distance: 10.0);

        // Elevator via metadata
        final l1 = createNode('l1', floorId: 'floor-1', category: 'corridor');
        final l2 = createNode('l2', floorId: 'floor-2', category: 'corridor');
        final eLift = createEdge(
          'e_lift',
          'l1',
          'l2',
          distance: 10.0,
          metadata: {'viaType': 'elevator'},
        );

        // Ramp
        final r1 = createNode('r1', floorId: 'floor-1', category: 'ramp');
        final r2 = createNode('r2', floorId: 'floor-2', category: 'ramp');
        final eRamp = createEdge('e_ramp', 'r1', 'r2', distance: 12.0);

        final graph = SpatialGraph();
        graph.addNodes([s1, s2, l1, l2, r1, r2]);
        graph.addEdges([eStairs, eLift, eRamp]);

        final result = graph.validate();
        expect(result.hasCode(DiagnosticCode.malformedFloorConnector), isFalse);
        expect(result.hasErrors, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // 2. Advisory Warnings
    // -------------------------------------------------------------------------
    group('2. Advisory Warnings (DiagnosticSeverity.warning)', () {
      test('Self-loop generates WARN_SELF_LOOP without invalidating graph', () {
        final node = createNode('n1');
        final loopEdge = createEdge('e_loop', 'n1', 'n1', distance: 0.0);

        final graph = SpatialGraph();
        graph.addNode(node);
        graph.addEdge(loopEdge);

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.hasCode(DiagnosticCode.selfLoop), isTrue);

        final diag = result.byCode(DiagnosticCode.selfLoop).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.nodeId, equals('n1'));
        expect(diag.edgeId, equals('e_loop'));
        expect(result.warnings.first, contains('Self-loop detected on node'));
      });

      test('Multiple disconnected components generate WARN_DISCONNECTED_COMPONENTS', () {
        final a = createNode('a');
        final b = createNode('b');
        final c = createNode('c');
        final d = createNode('d');

        final graph = SpatialGraph();
        graph.addNodes([a, b, c, d]);
        graph.addEdge(createEdge('e_ab', 'a', 'b'));
        graph.addEdge(createEdge('e_cd', 'c', 'd'));

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.componentCount, equals(2));
        expect(result.hasCode(DiagnosticCode.disconnectedComponents), isTrue);

        final diag = result.byCode(DiagnosticCode.disconnectedComponents).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.metadata['componentCount'], equals(2));
      });

      test('Isolated node with zero incoming and outgoing edges generates WARN_ISOLATED_NODE', () {
        final a = createNode('a');
        final b = createNode('b');
        final isolated = createNode('isolated');

        final graph = SpatialGraph();
        graph.addNodes([a, b, isolated]);
        graph.addEdge(createEdge('e_ab', 'a', 'b'));

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.isolatedNode), isTrue);

        final diag = result.byCode(DiagnosticCode.isolatedNode).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.nodeId, equals('isolated'));
        expect(diag.message, contains('isolated'));
      });

      test('Dead-end node with incoming edges but zero outgoing edges generates WARN_DEAD_END_NODE', () {
        final a = createNode('a');
        final b = createNode('b');

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdge(createEdge('e_ab', 'a', 'b')); // A -> B directed, B has 0 outgoing

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.deadEndNode), isTrue);

        final diag = result.byCode(DiagnosticCode.deadEndNode).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.nodeId, equals('b'));
        expect(diag.message, contains('dead end'));

        // Disabling checkDeadEnds suppresses warning
        final suppressed = graph.validate(
          options: const GraphQualityOptions(checkDeadEnds: false),
        );
        expect(suppressed.hasCode(DiagnosticCode.deadEndNode), isFalse);
      });

      test('Duplicate parallel edges generate WARN_DUPLICATE_EDGE', () {
        final a = createNode('a');
        final b = createNode('b');
        final e1 = createEdge('e1', 'a', 'b', distance: 10.0);
        final e2 = createEdge('e2', 'a', 'b', distance: 12.0);

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdges([e1, e2]);

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.duplicateEdge), isTrue);

        final diag = result.byCode(DiagnosticCode.duplicateEdge).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.edgeId, equals('e2'));
        expect(diag.nodeId, equals('a'));
        expect(diag.metadata['firstEdgeId'], equals('e1'));

        // Disabling checkDuplicateEdges suppresses warning
        final suppressed = graph.validate(
          options: const GraphQualityOptions(checkDuplicateEdges: false),
        );
        expect(suppressed.hasCode(DiagnosticCode.duplicateEdge), isFalse);
      });

      test('Sub-Euclidean edge distance generates WARN_GEOMETRIC_DISTANCE_MISMATCH', () {
        // Distance in Euclidean coordinates is 10.0 meters
        final a = createNode('a', x: 0.0, y: 0.0);
        final b = createNode('b', x: 10.0, y: 0.0);
        // Stated edge distance is 5.0m (shorter than straight line)
        final eShort = createEdge('e_short', 'a', 'b', distance: 5.0);

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdge(eShort);

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.geometricMismatch), isTrue);

        final diag = result.byCode(DiagnosticCode.geometricMismatch).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.edgeId, equals('e_short'));
        expect(diag.metadata['type'], equals('sub_euclidean'));
        expect(diag.metadata['edgeDistance'], equals(5.0));
        expect(diag.metadata['euclideanDistance'], equals(10.0));
      });

      test('Inflated edge distance exceeding maxGeometricRatio generates WARN_GEOMETRIC_DISTANCE_MISMATCH', () {
        final a = createNode('a', x: 0.0, y: 0.0);
        final b = createNode('b', x: 10.0, y: 0.0);
        // Euclidean is 10.0m. Stated edge distance is 60.0m (ratio = 6.0)
        final eLong = createEdge('e_long', 'a', 'b', distance: 60.0);

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdge(eLong);

        // Default has no maxGeometricRatio check
        final defaultResult = graph.validate();
        expect(defaultResult.hasCode(DiagnosticCode.geometricMismatch), isFalse);

        // When maxGeometricRatio: 5.0 is specified, flags ratio mismatch
        final ratioResult = graph.validate(
          options: const GraphQualityOptions(maxGeometricRatio: 5.0),
        );
        expect(ratioResult.hasCode(DiagnosticCode.geometricMismatch), isTrue);

        final diag = ratioResult.byCode(DiagnosticCode.geometricMismatch).first;
        expect(diag.metadata['type'], equals('inflated_ratio'));
        expect(diag.metadata['ratio'], equals(6.0));
      });

      test('Coincident coordinate edges (euclidean <= tolerance) do not generate false ratio warnings', () {
        // Coincident nodes (e.g. elevator landing or transition portal)
        final a = createNode('portal_in', x: 10.0, y: 15.0);
        final b = createNode('portal_out', x: 10.0, y: 15.0);
        final edgeZero = createEdge('e_zero', 'portal_in', 'portal_out', distance: 0.0);

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdge(edgeZero);

        final result = graph.validate(
          options: const GraphQualityOptions(maxGeometricRatio: 2.0),
        );
        expect(result.hasCode(DiagnosticCode.geometricMismatch), isFalse);
      });

      test('Unreachable designated emergency exit generates WARN_UNREACHABLE_EMERGENCY_EXIT', () {
        final a = createNode('a');
        final b = createNode('b');
        final exitNode = createNode(
          'exit-south',
          category: 'emergency_exit',
          metadata: {'isEmergencyExit': true},
        );

        final graph = SpatialGraph();
        graph.addNodes([a, b, exitNode]);
        graph.addEdge(createEdge('e_ab', 'a', 'b')); // Exit south has 0 incoming edges

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.unreachableEmergencyExit), isTrue);

        final diag = result.byCode(DiagnosticCode.unreachableEmergencyExit).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.nodeId, equals('exit-south'));
        expect(diag.message, contains('cannot be reached'));

        // Disabling checkEmergencyExits suppresses warning
        final suppressed = graph.validate(
          options: const GraphQualityOptions(checkEmergencyExits: false),
        );
        expect(suppressed.hasCode(DiagnosticCode.unreachableEmergencyExit), isFalse);
      });

      test('Emergency exit with only blocked incoming edges generates WARN_UNREACHABLE_EMERGENCY_EXIT', () {
        final a = createNode('a');
        final exitNode = createNode('exit-blocked', category: 'emergency_exit');
        final blockedEdge = createEdge('e_blocked', 'a', 'exit-blocked', blocked: true);

        final graph = SpatialGraph();
        graph.addNodes([a, exitNode]);
        graph.addEdge(blockedEdge);

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.hasCode(DiagnosticCode.unreachableEmergencyExit), isTrue);

        final diag = result.byCode(DiagnosticCode.unreachableEmergencyExit).first;
        expect(diag.message, contains('only blocked incoming edges'));
      });

      test('Reachable emergency exit in one component is not reported as unusable when multiple components exist', () {
        // Component 1: A -> Exit1
        final a = createNode('a');
        final exit1 = createNode('exit-1', category: 'emergency_exit');
        final e1 = createEdge('e_a_exit', 'a', 'exit-1');

        // Component 2: C -> D (disconnected from Component 1)
        final c = createNode('c');
        final d = createNode('d');
        final e2 = createEdge('e_cd', 'c', 'd');

        final graph = SpatialGraph();
        graph.addNodes([a, exit1, c, d]);
        graph.addEdges([e1, e2]);

        final result = graph.validate();
        expect(result.isValid, isTrue);
        expect(result.componentCount, equals(2));
        // Exit1 is reachable within Component 1, so it must NOT be flagged as unreachable
        expect(result.hasCode(DiagnosticCode.unreachableEmergencyExit), isFalse);
      });

      test('Reachable emergency exit does not flag WARN_UNREACHABLE_EMERGENCY_EXIT', () {
        final a = createNode('a');
        final exitNode = createNode(
          'exit-south',
          category: 'emergency_exit',
        );

        final graph = SpatialGraph();
        graph.addNodes([a, exitNode]);
        graph.addEdge(createEdge('e_exit', 'a', 'exit-south'));

        final result = graph.validate();
        expect(result.hasCode(DiagnosticCode.unreachableEmergencyExit), isFalse);
      });

      test('Conflicting vertical connector metadata generates WARN_CONFLICTING_CONNECTOR_METADATA', () {
        // Cross-floor connection where start node has elevator and end node has stairs
        final f1Node = createNode('lift-1', floorId: 'floor-1', category: 'elevator');
        final f2Node = createNode('stairs-2', floorId: 'floor-2', category: 'stairs');
        final edge = createEdge('e_conflict', 'lift-1', 'stairs-2', distance: 10.0);

        final graph = SpatialGraph();
        graph.addNodes([f1Node, f2Node]);
        graph.addEdge(edge);

        final result = graph.validate();
        expect(result.isValid, isTrue); // Conflicting metadata is a warning, not error
        expect(result.hasCode(DiagnosticCode.conflictingConnectorMetadata), isTrue);

        final diag = result.byCode(DiagnosticCode.conflictingConnectorMetadata).first;
        expect(diag.severity, equals(DiagnosticSeverity.warning));
        expect(diag.edgeId, equals('e_conflict'));
        expect(diag.nodeId, equals('stairs-2'));
        expect(diag.metadata['types'], containsAll(['elevator', 'stairs']));
      });
    });

    // -------------------------------------------------------------------------
    // 3. Deterministic Sorting & Immutability
    // -------------------------------------------------------------------------
    group('3. Diagnostic Ordering & Immutability', () {
      test('Diagnostics are sorted deterministically: errors before warnings, then code, nodeId, edgeId', () {
        // Graph with multiple mixed errors and warnings
        final a = createNode('a', x: 0.0, y: 0.0);
        final b = createNode('b', x: 10.0, y: 0.0);
        final subEuclidean = createEdge('e_sub', 'a', 'b', distance: 2.0); // warning
        final loop = createEdge('e_loop', 'a', 'a', distance: 0.0); // warning

        final graph = SpatialGraph.raw(
          nodes: [a, b],
          edges: [
            subEuclidean,
            loop,
            createEdge('e_missing', 'a', 'missing_z'), // error
          ],
        );

        final result = graph.validate();
        expect(result.diagnostics.length, greaterThanOrEqualTo(3));

        // Verify all errors precede all warnings
        bool seenWarning = false;
        for (final diag in result.diagnostics) {
          if (diag.isWarning) {
            seenWarning = true;
          }
          if (seenWarning) {
            expect(diag.severity, equals(DiagnosticSeverity.warning),
                reason: 'No error may appear after a warning');
          }
        }
      });

      test('Graph structure is completely immutable during validate()', () {
        final a = createNode('a');
        final b = createNode('b');
        final edge = createEdge('e1', 'a', 'b');

        final graph = SpatialGraph();
        graph.addNodes([a, b]);
        graph.addEdge(edge);

        final nodeCountBefore = graph.nodeCount;
        final edgeCountBefore = graph.edgeCount;
        final outgoingBefore = graph.getOutgoingEdges('a').length;

        final result = graph.validate();
        expect(result.isValid, isTrue);

        expect(graph.nodeCount, equals(nodeCountBefore));
        expect(graph.edgeCount, equals(edgeCountBefore));
        expect(graph.getOutgoingEdges('a').length, equals(outgoingBefore));
        expect(graph.hasNode('a'), isTrue);
        expect(graph.hasNode('b'), isTrue);
        expect(graph.hasEdge('e1'), isTrue);
      });

      test('GraphDiagnostic serializes cleanly to JSON', () {
        const diag = GraphDiagnostic(
          severity: DiagnosticSeverity.warning,
          code: DiagnosticCode.deadEndNode,
          message: "Node 'test' is a dead end.",
          nodeId: 'test',
          edgeId: 'e1',
          metadata: {'custom': 42},
        );

        final json = diag.toJson();
        expect(json['severity'], equals('warning'));
        expect(json['code'], equals(DiagnosticCode.deadEndNode));
        expect(json['message'], equals("Node 'test' is a dead end."));
        expect(json['nodeId'], equals('test'));
        expect(json['edgeId'], equals('e1'));
        expect(json['metadata']['custom'], equals(42));
        expect(diag.toString(), contains('[WARNING] WARN_DEAD_END_NODE'));
      });
    });

    // -------------------------------------------------------------------------
    // 4. Production Fixture Validation
    // -------------------------------------------------------------------------
    group('4. Production Datasets Quality Validation', () {
      test('vit_floor_1.json passes quality validation with 0 errors and single component', () {
        final candidates = [
          '../../test_data/vit_floor_1.json',
          '../test_data/vit_floor_1.json',
          'test_data/vit_floor_1.json',
          'assets/test_data/vit_floor_1.json',
        ];
        File? file;
        for (final p in candidates) {
          final f = File(p);
          if (f.existsSync()) {
            file = f;
            break;
          }
        }
        expect(file, isNotNull, reason: 'vit_floor_1.json must exist');

        final data = jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;
        final nodes = (data['nodes'] as List<dynamic>)
            .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
            .toList();
        final edges = (data['edges'] as List<dynamic>)
            .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
            .toList();

        final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
        final result = graph.validate();

        expect(result.isValid, isTrue);
        expect(result.hasErrors, isFalse);
        expect(result.errors, isEmpty);
        expect(result.componentCount, equals(1));
      });

      test('vit_two_floors.json passes quality validation with 0 errors and single component', () {
        final candidates = [
          '../../test_data/vit_two_floors.json',
          '../test_data/vit_two_floors.json',
          'test_data/vit_two_floors.json',
          'assets/test_data/vit_two_floors.json',
        ];
        File? file;
        for (final p in candidates) {
          final f = File(p);
          if (f.existsSync()) {
            file = f;
            break;
          }
        }
        expect(file, isNotNull, reason: 'vit_two_floors.json must exist');

        final data = jsonDecode(file!.readAsStringSync()) as Map<String, dynamic>;
        final nodes = (data['nodes'] as List<dynamic>)
            .map((n) => NodeModel.fromJson(n as Map<String, dynamic>))
            .toList();
        final edges = (data['edges'] as List<dynamic>)
            .map((e) => EdgeModel.fromJson(e as Map<String, dynamic>))
            .toList();

        final graph = SpatialGraph.fromNodesAndEdges(nodes, edges);
        final result = graph.validate();

        expect(result.isValid, isTrue);
        expect(result.hasErrors, isFalse);
        expect(result.errors, isEmpty);
        expect(result.componentCount, equals(1));
      });
    });
  });
}
