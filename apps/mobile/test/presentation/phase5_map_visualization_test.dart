import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/edge_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/routing/app_router.dart';
import 'package:mapless_ai/core/state/spatial_state.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/building_overview_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/buildings_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/screens/map_view_screen.dart';
import 'package:mapless_ai/features/mapping/presentation/widgets/indoor_canvas.dart';
import 'package:mapless_ai/features/mapping/presentation/widgets/multi_floor_visualizer.dart';

void main() {
  const testBuilding = BuildingModel(
    id: 'bld-vit-ab1',
    name: 'Academic Block 1 (AB1)',
    address: 'VIT Campus, Central Avenue',
    category: 'academic',
    latitude: 12.8406,
    longitude: 80.1534,
    metadata: {'floors': 3},
  );

  const List<FloorModel> testFloors = [
    FloorModel(
      id: 'flr-vit-ab1-01',
      buildingId: 'bld-vit-ab1',
      floorNumber: 0,
      name: 'Ground Floor',
      elevation: 0.0,
      metadata: {'width': 100.0, 'height': 80.0},
    ),
    FloorModel(
      id: 'flr-vit-ab1-02',
      buildingId: 'bld-vit-ab1',
      floorNumber: 1,
      name: 'Second Floor',
      elevation: 4.0,
      metadata: {'width': 100.0, 'height': 80.0},
    ),
    FloorModel(
      id: 'flr-vit-ab1-03',
      buildingId: 'bld-vit-ab1',
      floorNumber: 2,
      name: 'Third Floor',
      elevation: 8.0,
      metadata: {'width': 100.0, 'height': 80.0},
    ),
  ];

  const List<NodeModel> testNodes = [
    NodeModel(
      id: 'n1',
      name: 'Main Entrance',
      category: 'entrance',
      floorId: 'flr-vit-ab1-01',
      x: 50.0,
      y: 50.0,
      accessible: true,
    ),
    NodeModel(
      id: 'n2',
      name: 'Central Elevator',
      category: 'elevator',
      floorId: 'flr-vit-ab1-01',
      x: 100.0,
      y: 100.0,
      accessible: true,
    ),
    NodeModel(
      id: 'n3',
      name: 'East Stairwell',
      category: 'stairs',
      floorId: 'flr-vit-ab1-01',
      x: 150.0,
      y: 150.0,
      accessible: false,
    ),
    NodeModel(
      id: 'n4',
      name: 'Emergency Exit East',
      category: 'emergency_exit',
      floorId: 'flr-vit-ab1-01',
      x: 200.0,
      y: 200.0,
      accessible: true,
    ),
    NodeModel(
      id: 'n5',
      name: 'Robotics Lab 101',
      category: 'room',
      floorId: 'flr-vit-ab1-01',
      x: 250.0,
      y: 250.0,
      accessible: true,
    ),
  ];

  const List<EdgeModel> testEdges = [
    EdgeModel(
      id: 'e1',
      startNodeId: 'n1',
      endNodeId: 'n2',
      distance: 5.0,
      bearing: 45.0,
      accessible: true,
      blocked: false,
    ),
    EdgeModel(
      id: 'e2',
      startNodeId: 'n2',
      endNodeId: 'n3',
      distance: 5.0,
      bearing: 45.0,
      accessible: true,
      blocked: false,
    ),
    EdgeModel(
      id: 'e3',
      startNodeId: 'n3',
      endNodeId: 'n4',
      distance: 5.0,
      bearing: 45.0,
      accessible: true,
      blocked: false,
    ),
    EdgeModel(
      id: 'e4',
      startNodeId: 'n2',
      endNodeId: 'n5',
      distance: 10.0,
      bearing: 90.0,
      accessible: true,
      blocked: false,
    ),
  ];

  Widget createTestWidget({
    required Widget child,
    SpatialState? initialState,
    Size size = const Size(390, 844),
  }) {
    return ProviderScope(
      overrides: [
        if (initialState != null)
          spatialStateProvider.overrideWith(
            (ref) => _PresetSpatialController(initialState),
          ),
      ],
      child: MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Phase 5 — MultiFloorVisualizer Widget', () {
    testWidgets('renders all floors sorted from highest to lowest elevation', (tester) async {
      FloorModel? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiFloorVisualizer(
                floors: testFloors,
                selectedFloor: testFloors.first,
                onFloorSelected: (f) => selected = f,
                allNodes: testNodes,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top floor should be rendered first (Third Floor)
      expect(find.text('Third Floor'), findsOneWidget);
      expect(find.text('Second Floor'), findsOneWidget);
      expect(find.text('Ground Floor'), findsOneWidget);

      // Elevation indicators
      expect(find.text('+8.0m'), findsOneWidget);
      expect(find.text('+4.0m'), findsOneWidget);
      expect(find.text('0.0m'), findsOneWidget);

      // Tap on Third Floor
      await tester.tap(find.text('Third Floor'));
      await tester.pumpAndSettle();
      expect(selected?.id, equals('flr-vit-ab1-03'));
    });

    testWidgets('displays facility count indicators for elevator, stairs, exit, room', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiFloorVisualizer(
                floors: testFloors,
                selectedFloor: testFloors.first,
                onFloorSelected: (_) {},
                allNodes: testNodes,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Facility icons on ground floor
      expect(find.byIcon(Icons.elevator), findsWidgets);
      expect(find.byIcon(Icons.stairs), findsWidgets);
      expect(find.byIcon(Icons.exit_to_app), findsWidgets);
      expect(find.byIcon(Icons.meeting_room), findsWidgets);
    });
  });

  group('Phase 5 — BuildingOverviewScreen', () {
    testWidgets('displays building metadata and embedded floor visualizer', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const BuildingOverviewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Academic Block 1 (AB1)'), findsWidgets);
      expect(find.text('VIT Campus, Central Avenue'), findsOneWidget);
      expect(find.text('ACADEMIC'), findsOneWidget);
      expect(find.byType(MultiFloorVisualizer), findsOneWidget);
      expect(find.text('Open 2D Indoor Map'), findsOneWidget);
    });

    testWidgets('floor card tap updates selected floor', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const BuildingOverviewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      // Tap on Second Floor
      await tester.tap(find.text('Second Floor'));
      await tester.pumpAndSettle();

      // Second floor is now the selected floor view
      expect(find.textContaining('Second Floor'), findsWidgets);
    });

    testWidgets('tapping Open 2D Indoor Map navigates to MapViewScreen', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const BuildingOverviewScreen(),
        initialState: state,
      ));
      // Ensure button is visible by scrolling
      final buttonFinder = find.text('Open 2D Indoor Map');
      await tester.scrollUntilVisible(buttonFinder, 200);
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(MapViewScreen), findsOneWidget);
    });
  });

  group('Phase 5 — MapViewScreen & IndoorCanvas', () {
    testWidgets('renders IndoorCanvas with vertical floor switcher', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const MapViewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(IndoorCanvas), findsOneWidget);

      // Floor buttons in vertical switcher: F2 (level 2), F1 (level 1), G (level 0)
      expect(find.text('F2'), findsOneWidget);
      expect(find.text('F1'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);

      // Zoom and fit controls
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
    });

    testWidgets('tapping vertical floor button changes active floor', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const MapViewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      // Tap F1
      await tester.tap(find.text('F1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Second Floor'), findsOneWidget);
    });

    testWidgets('zoom controls and fit-to-screen execute without error', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const MapViewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      // Tap zoom in
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Tap zoom out
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      // Tap fit to screen
      await tester.tap(find.byIcon(Icons.center_focus_strong));
      await tester.pump();

      // Toggle labels
      await tester.tap(find.byIcon(Icons.label));
      await tester.pump();
      expect(find.byIcon(Icons.label_off), findsOneWidget);

      // Toggle accessibility
      await tester.tap(find.byIcon(Icons.accessible_forward));
      await tester.pump();
      expect(find.byIcon(Icons.not_accessible), findsOneWidget);
    });

    testWidgets('tapping a node on IndoorCanvas opens Node Inspector card', (tester) async {
      final state = SpatialState(
        availableBuildings: [testBuilding],
        selectedBuilding: testBuilding,
        availableFloors: testFloors,
        selectedFloor: testFloors.first,
        availableNodes: testNodes,
        availableEdges: testEdges,
      );

      await tester.pumpWidget(createTestWidget(
        child: const MapViewScreen(),
        initialState: state,
      ));
      await tester.pumpAndSettle();

      // Initial state: no node inspector
      expect(find.text('Set Destination'), findsNothing);

      // Tap center of canvas where East Stairwell (x: 150, y: 150) is rendered
      final canvasFinder = find.byType(IndoorCanvas);
      await tester.tap(canvasFinder);
      await tester.pumpAndSettle();

      // Inspector card should now be displayed
      expect(find.text('East Stairwell'), findsWidgets);
      expect(find.text('STAIRS'), findsOneWidget);
      expect(find.text('Set Destination'), findsOneWidget);

      // Tap 'Set Destination'
      await tester.tap(find.text('Set Destination'));
      await tester.pumpAndSettle();

      // Tap close/deselect button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Set Destination'), findsNothing);
    });
  });

  group('Phase 5 — Responsive Viewport Verification (Zero RenderFlex Overflow)', () {
    const viewports = [
      Size(360, 800), // Narrow Android (Pixel / Samsung A series)
      Size(390, 844), // Standard Mobile (iPhone 12-14)
      Size(430, 932), // Large Mobile (iPhone Pro Max / Pixel Pro)
    ];

    for (final size in viewports) {
      testWidgets('BuildingOverviewScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
        final state = SpatialState(
          availableBuildings: [testBuilding],
          selectedBuilding: testBuilding,
          availableFloors: testFloors,
          selectedFloor: testFloors.first,
          availableNodes: testNodes,
          availableEdges: testEdges,
        );

        await tester.pumpWidget(createTestWidget(
          child: const BuildingOverviewScreen(),
          initialState: state,
          size: size,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BuildingOverviewScreen), findsOneWidget);
      });

      testWidgets('MapViewScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
        final state = SpatialState(
          availableBuildings: [testBuilding],
          selectedBuilding: testBuilding,
          availableFloors: testFloors,
          selectedFloor: testFloors.first,
          availableNodes: testNodes,
          availableEdges: testEdges,
        );

        await tester.pumpWidget(createTestWidget(
          child: const MapViewScreen(),
          initialState: state,
          size: size,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MapViewScreen), findsOneWidget);
      });

      testWidgets('BuildingsScreen renders without overflow at ${size.width}x${size.height}', (tester) async {
        final state = SpatialState(
          availableBuildings: [testBuilding],
          selectedBuilding: testBuilding,
          availableFloors: testFloors,
          selectedFloor: testFloors.first,
          availableNodes: testNodes,
          availableEdges: testEdges,
        );

        await tester.pumpWidget(createTestWidget(
          child: const BuildingsScreen(),
          initialState: state,
          size: size,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BuildingsScreen), findsOneWidget);
      });
    }
  });
}

class _PresetSpatialController extends SpatialController {
  _PresetSpatialController(SpatialState presetState)
      : super(initialState: presetState, autoInitialize: false);
}
