import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/widgets/app_button.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/creator_editor_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/widgets/indoor_canvas.dart';
import 'package:mapless_ai/features/mapping/presentation/widgets/node_form_dialog.dart';
import 'package:mapless_ai/features/mapping/services/sensor_data_source.dart';
import 'package:mapless_ai/features/mapping/services/sensor_models.dart';
import 'package:mapless_ai/features/mapping/services/sensor_provider.dart';
import 'package:mapless_ai/features/mapping/services/sensor_service.dart';
import 'package:mapless_ai/features/mapping/state/creator_controller.dart';
import 'package:mapless_ai/features/mapping/state/walkthrough_controller.dart';
import 'package:mapless_ai/features/mapping/state/walkthrough_state.dart';

void main() {
  group('Phase 6 — Sensor-Assisted Creator Mapping Presentation Tests', () {
    const testBuilding = BuildingModel(
      id: 'bld-cc-test',
      name: 'Technology Tower',
      address: 'Vellore Campus',
      category: 'academic',
      latitude: 12.9716,
      longitude: 79.1588,
    );

    const testFloor = FloorModel(
      id: 'flr-tt-01',
      buildingId: 'bld-cc-test',
      floorNumber: 1,
      name: 'Ground Floor',
      elevation: 0.0,
    );

    const nodeA = NodeModel(
      id: 'node-start',
      name: 'South Entrance',
      category: 'entrance',
      floorId: 'flr-tt-01',
      x: 0.0,
      y: 0.0,
      accessible: true,
    );

    const nodeB = NodeModel(
      id: 'node-hall',
      name: 'Central Hall',
      category: 'room',
      floorId: 'flr-tt-01',
      x: 10.0,
      y: 15.0,
      accessible: true,
    );

    late FakeSensorDataSource fakeSensorSource;
    late SensorService sensorService;

    setUp(() async {
      fakeSensorSource = FakeSensorDataSource(
        mockAvailability: const SensorAvailability(),
        mockPermissionStatus: SensorPermissionStatus.granted,
      );
      sensorService = SensorService(dataSource: fakeSensorSource);
      await sensorService.initialize();
    });

    tearDown(() {
      sensorService.dispose();
      fakeSensorSource.dispose();
    });

    testWidgets('1. IndoorCanvas renders walked path and creator mapping avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: IndoorCanvas(
                nodes: const [nodeA, nodeB],
                edges: const [],
                creatorMappingPosition: const Offset(5.0, 7.5),
                creatorHeading: 45.0,
                creatorWalkedPath: const [
                  Offset.zero,
                  Offset(2.5, 3.5),
                  Offset(5.0, 7.5),
                ],
                isRecordingWalkthrough: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IndoorCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('No spatial nodes to render on this floor'), findsNothing);
    });

    testWidgets('2. IndoorCanvas renders empty floor with active walkthrough without placeholder error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: IndoorCanvas(
                nodes: const [],
                edges: const [],
                creatorMappingPosition: Offset.zero,
                creatorHeading: 0.0,
                creatorWalkedPath: const [Offset.zero],
                isRecordingWalkthrough: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render canvas rather than 'No spatial nodes'
      expect(find.text('No spatial nodes to render on this floor'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('3. CreatorEditorScreen displays Walkthrough HUD and launches walkthrough', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sensorServiceProvider.overrideWithValue(sensorService),
        ],
      );
      addTearDown(container.dispose);

      // Start new session
      container.read(creatorProvider.notifier).startNewSession(
            building: testBuilding,
            floor: testFloor,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Walkthrough HUD is rendered
      expect(find.text('IDLE'), findsOneWidget);
      expect(find.text('Start Walkthrough'), findsOneWidget);

      // Tap Start Walkthrough
      await tester.tap(find.text('Start Walkthrough'));
      await tester.pumpAndSettle();

      // Status should become RECORDING
      expect(find.text('RECORDING'), findsOneWidget);
      expect(find.text('Add Location Here'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Reset Origin'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
    });

    testWidgets('4. Add Location Here prefills sensor coordinates in NodeFormDialog', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          sensorServiceProvider.overrideWithValue(sensorService),
        ],
      );
      addTearDown(container.dispose);

      container.read(creatorProvider.notifier).startNewSession(
            building: testBuilding,
            floor: testFloor,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start walkthrough
      await tester.tap(find.text('Start Walkthrough'));
      await tester.pumpAndSettle();

      // Tap Add Location Here
      await tester.tap(find.text('Add Location Here'));
      await tester.pumpAndSettle();

      // Form dialog should be visible
      expect(find.byType(NodeFormDialog), findsOneWidget);
      // X and Y should be prefilled with 0.00 (sensor origin)
      expect(find.text('0.00'), findsNWidgets(2));

      // Enter name and save
      await tester.enterText(find.byType(TextFormField).first, 'Lab 101');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Add Location'));
      await tester.tap(find.widgetWithText(AppButton, 'Add Location'));
      await tester.pumpAndSettle();

      // Verify node added to draft
      final draft = container.read(creatorProvider).activeDraft;
      expect(draft?.nodes.length, equals(1));
      expect(draft?.nodes.first.name, equals('Lab 101'));
    });

    testWidgets('5. Candidate connection banner appears and connects nodes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          sensorServiceProvider.overrideWithValue(sensorService),
        ],
      );
      addTearDown(container.dispose);

      container.read(creatorProvider.notifier).startNewSession(
            building: testBuilding,
            floor: testFloor,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CreatorEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start walkthrough
      await tester.tap(find.text('Start Walkthrough'));
      await tester.pumpAndSettle();

      // Add Node 1
      await tester.tap(find.text('Add Location Here'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Node One');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Add Location'));
      await tester.tap(find.widgetWithText(AppButton, 'Add Location'));
      await tester.pumpAndSettle();

      // Add Node 2
      await tester.tap(find.text('Add Location Here'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Node Two');
      await tester.enterText(find.byType(TextFormField).at(1), '10.0');
      await tester.enterText(find.byType(TextFormField).at(2), '20.0');
      await tester.ensureVisible(find.widgetWithText(AppButton, 'Add Location'));
      await tester.tap(find.widgetWithText(AppButton, 'Add Location'));
      await tester.pumpAndSettle();

      // Auto-connect banner should appear
      expect(find.textContaining('Connect "Node One" ➔ "Node Two"'), findsOneWidget);

      // Tap Connect in the candidate banner
      await tester.tap(find.widgetWithText(TextButton, 'Connect'));
      await tester.pumpAndSettle();

      // Edge should be created in draft
      final draft = container.read(creatorProvider).activeDraft;
      expect(draft?.edges.length, equals(1));
    });

    testWidgets('6. Responsive check: Zero RenderFlex overflow at 360, 390, and 430 widths', (tester) async {
      final viewports = [
        const Size(360, 800),
        const Size(390, 844),
        const Size(430, 932),
      ];

      for (final size in viewports) {
        final container = ProviderContainer(
          overrides: [
            sensorServiceProvider.overrideWithValue(sensorService),
          ],
        );

        container.read(creatorProvider.notifier).startNewSession(
              building: testBuilding,
              floor: testFloor,
            );

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: CreatorEditorScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start walkthrough
        await tester.tap(find.text('Start Walkthrough'));
        await tester.pumpAndSettle();

        // Check for overflow exceptions
        expect(tester.takeException(), isNull, reason: 'Overflow at size $size');

        container.dispose();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
