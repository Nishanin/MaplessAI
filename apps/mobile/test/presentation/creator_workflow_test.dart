import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/routing/app_router.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_editor_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_mapping_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_preview_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_publish_screen.dart';
import 'package:mapless_ai/features/mapping/state/creator_controller.dart';

void main() {
  group('Creator Mapping Workflow Presentation Tests', () {
    const testBuilding = BuildingModel(
      id: 'bld-vit-cc-01',
      name: 'Academic Block 1 (AB-1)',
      address: 'Chennai Campus',
      category: 'academic',
      latitude: 12.8406,
      longitude: 80.1534,
    );

    const testFloor = FloorModel(
      id: 'flr-vit-ab1-01',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 1,
      name: 'Ground Floor (Floor 1)',
      elevation: 0.0,
    );

    const testNodeA = NodeModel(
      id: 'node-a',
      name: 'Main Entrance',
      category: 'entrance',
      floorId: 'flr-vit-ab1-01',
      x: 10.0,
      y: 20.0,
      accessible: true,
    );

    const testNodeB = NodeModel(
      id: 'node-b',
      name: 'Corridor Junction',
      category: 'corridor',
      floorId: 'flr-vit-ab1-01',
      x: 25.0,
      y: 20.0,
      accessible: true,
    );

    const testEdgeAB = EdgeModel(
      id: 'edge-a-b',
      startNodeId: 'node-a',
      endNodeId: 'node-b',
      distance: 15.0,
      bearing: 90.0,
      accessible: true,
      blocked: false,
    );

    testWidgets('Creator sub-routes resolve to correct screen widgets in AppRouter', (tester) async {
      final routesToVerify = <String, Type>{
        AppRouter.creator: CreatorMappingScreen,
        AppRouter.creatorEditor: CreatorEditorScreen,
        AppRouter.creatorPreview: CreatorPreviewScreen,
        AppRouter.creatorPublish: CreatorPublishScreen,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (final entry in routesToVerify.entries) {
                final route = AppRouter.generateRoute(RouteSettings(name: entry.key));
                expect(route, isA<MaterialPageRoute>());
                final pageRoute = route as MaterialPageRoute;
                final widget = pageRoute.builder(context);
                expect(widget.runtimeType, equals(entry.value));
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('Creator Dashboard renders projects, counters, and Phase 4 stub notice', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreatorMappingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header title
      expect(find.text('Creator Mapping Hub'), findsOneWidget);
      expect(find.text('Indoor Map Creator Hub'), findsOneWidget);

      // Section headings & actions
      expect(find.textContaining('Saved Draft Maps'), findsOneWidget);
      expect(find.textContaining('Published Campus Maps'), findsOneWidget);

      // Phase 4 Sensor engine preview card and notice
      expect(find.text('Phase 4 Sensor Engine (PDR & Orientation)'), findsOneWidget);
      expect(find.textContaining('Live sensor fusion is active'), findsOneWidget);
      expect(find.textContaining('Manual coordinate authoring remains available'), findsOneWidget);
      expect(find.text('Step Counter'), findsOneWidget);
      expect(find.text('Compass Heading'), findsOneWidget);
    });

    testWidgets('Creator Editor displays empty state when no draft active, and full session when active', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Test 1: Empty state
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No active mapping session'), findsOneWidget);
      expect(find.text('Go to Creator Dashboard'), findsOneWidget);

      // Test 2: Populate active draft
      final controller = container.read(creatorProvider.notifier);
      controller.startNewSession(building: testBuilding, floor: testFloor);
      controller.addNode(testNodeA);
      controller.addNode(testNodeB);
      controller.connectNodes(testEdgeAB);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Session Header Info
      expect(find.textContaining('Academic Block 1 (AB-1)'), findsWidgets);
      expect(find.textContaining('2 Nodes • 1 Connections'), findsOneWidget);
      expect(find.text('Add Node'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Validate'), findsOneWidget);

      // Tap Validate
      await tester.tap(find.text('Validate'));
      await tester.pumpAndSettle();

      expect(find.text('Graph Validated'), findsOneWidget);
    });

    testWidgets('Creator Preview Screen displays draft metrics, legend, and proceed action', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(creatorProvider.notifier);
      controller.startNewSession(building: testBuilding, floor: testFloor);
      controller.addNode(testNodeA);
      controller.addNode(testNodeB);
      controller.connectNodes(testEdgeAB);
      controller.validateCurrentDraft();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorPreviewScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Map Preview'), findsWidgets);
      expect(find.text('Locations'), findsOneWidget);
      expect(find.text('Edges (Walkable)'), findsOneWidget);
      expect(find.text('Blocked Edges'), findsOneWidget);
      expect(find.text('Graph Visual Layout'), findsOneWidget);
      expect(find.textContaining('Mock Persistence: Local in-memory repository'), findsOneWidget);
      expect(find.text('Return to Editor'), findsOneWidget);
      expect(find.text('Proceed to Publish'), findsOneWidget);
    });

    testWidgets('Creator Publish Screen confirms publication and renders success state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(creatorProvider.notifier);
      controller.startNewSession(building: testBuilding, floor: testFloor);
      controller.addNode(testNodeA);
      controller.addNode(testNodeB);
      controller.connectNodes(testEdgeAB);
      controller.validateCurrentDraft();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorPublishScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publish Indoor Map'), findsOneWidget);
      expect(find.textContaining('Graph validation passed'), findsOneWidget);
      expect(find.textContaining('Mock Storage Persistence Notice'), findsOneWidget);
      expect(find.text('Publish Map'), findsOneWidget);

      // Tap Publish Map
      await tester.tap(find.text('Publish Map'));
      await tester.pumpAndSettle();

      // Verify Success State
      expect(find.text('Map Published Successfully!'), findsOneWidget);
      expect(find.text('Go to Creator Dashboard'), findsOneWidget);
      expect(find.text('View Campus Buildings'), findsOneWidget);
    });

    testWidgets('Creator Mapping Hub does not produce RenderFlex overflow at 360 width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreatorMappingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CreatorMappingScreen), findsOneWidget);
    });

    testWidgets('Creator Mapping Hub does not produce RenderFlex overflow at 390 width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreatorMappingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CreatorMappingScreen), findsOneWidget);
    });

    testWidgets('Creator Mapping Hub does not produce RenderFlex overflow at 430 width', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CreatorMappingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(CreatorMappingScreen), findsOneWidget);
    });

    testWidgets('Creator Mapping Hub controls remain responsive and non-overflowing when toggled at 360 width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorMappingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll until Start Walkthrough is visible inside SingleChildScrollView
      final startButton = find.text('Start Walkthrough');
      await tester.scrollUntilVisible(startButton, 200);
      expect(startButton, findsOneWidget);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Stop Walkthrough'), findsOneWidget);

      // Tap Zero Heading and Reset
      final calibrateButton = find.text('Zero Heading (0°)');
      expect(calibrateButton, findsOneWidget);
      await tester.tap(calibrateButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final resetButton = find.text('Reset Origin');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
