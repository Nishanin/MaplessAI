import 'package:flutter_test/flutter_test.dart';
import 'package:mapless_ai/core/models/building_model.dart';
import 'package:mapless_ai/core/models/floor_model.dart';
import 'package:mapless_ai/core/models/node_model.dart';
import 'package:mapless_ai/core/state/spatial_state.dart';

void main() {
  group('Global UI & Spatial Selection State Verification', () {
    test('State initialization sets default campus buildings, floor, and nodes', () async {
      final controller = SpatialController();
      await controller.initialize();
      final state = controller.currentState;

      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.availableBuildings, isNotEmpty);
      expect(state.availableBuildings.first.id, equals('bld-vit-cc-01'));
      expect(state.selectedBuilding, isNotNull);
      expect(state.selectedBuilding!.id, equals('bld-vit-cc-01'));
      expect(state.selectedFloor, isNotNull);
      expect(state.availableFloors, isNotEmpty);
      expect(state.hasValidSelection, isTrue);
    });

    test('Selected building state updates building, floors, and locations', () async {
      final controller = SpatialController();
      await controller.initialize();

      const newBuilding = BuildingModel(
        id: 'bld-vit-tt-02',
        name: 'Technology Tower (TT)',
        address: 'East Campus Quad',
        category: 'academic',
        latitude: 12.8412,
        longitude: 80.1540,
      );

      controller.selectBuilding(newBuilding);
      var state = controller.currentState;

      expect(state.selectedBuilding?.id, equals('bld-vit-tt-02'));
      expect(state.selectedBuilding?.name, equals('Technology Tower (TT)'));
      expect(state.availableFloors, isNotEmpty);
      expect(state.selectedFloor?.buildingId, equals('bld-vit-tt-02'));

      // Selecting null building clears all selections
      controller.selectBuilding(null);
      state = controller.currentState;

      expect(state.selectedBuilding, isNull);
      expect(state.selectedFloor, isNull);
      expect(state.selectedCurrentLocation, isNull);
      expect(state.selectedDestination, isNull);
      expect(state.availableFloors, isEmpty);
      expect(state.availableNodes, isEmpty);
    });

    test('Selected floor state updates active floor and clears on null', () async {
      final controller = SpatialController();
      await controller.initialize();

      const secondFloor = FloorModel(
        id: 'flr-vit-ab1-02',
        buildingId: 'bld-vit-cc-01',
        floorNumber: 2,
        name: 'First Floor (Floor 2)',
        elevation: 4.0,
      );

      controller.selectFloor(secondFloor);
      var state = controller.currentState;

      expect(state.selectedFloor?.id, equals('flr-vit-ab1-02'));
      expect(state.selectedFloor?.floorNumber, equals(2));

      // Deselect floor
      controller.selectFloor(null);
      state = controller.currentState;

      expect(state.selectedFloor, isNull);
      expect(state.selectedCurrentLocation, isNull);
      expect(state.selectedDestination, isNull);
    });

    test('Selected location state updates current location, destination, and allows swap', () async {
      final controller = SpatialController();
      await controller.initialize();

      const startNode = NodeModel(
        id: 'node-entrance-01',
        name: 'Main Entrance',
        category: 'entrance',
        floorId: 'flr-vit-ab1-01',
        x: 10.0,
        y: 20.0,
        accessible: true,
      );

      const destNode = NodeModel(
        id: 'node-lab-101',
        name: 'Robotics Lab 101',
        category: 'room',
        floorId: 'flr-vit-ab1-01',
        x: 70.0,
        y: 20.0,
        accessible: true,
      );

      controller.setCurrentLocation(startNode);
      controller.setDestination(destNode);

      var state = controller.currentState;
      expect(state.selectedCurrentLocation?.id, equals('node-entrance-01'));
      expect(state.selectedDestination?.id, equals('node-lab-101'));
      expect(state.hasRoutePoints, isTrue);

      // Swap locations
      controller.swapLocations();
      state = controller.currentState;

      expect(state.selectedCurrentLocation?.id, equals('node-lab-101'));
      expect(state.selectedDestination?.id, equals('node-entrance-01'));

      // Set by ID lookup
      controller.setCurrentLocationById('node-corridor-01');
      state = controller.currentState;
      expect(state.selectedCurrentLocation?.id, equals('node-corridor-01'));
    });

    test('State reset restores state to clean, unselected baseline', () async {
      final controller = SpatialController();
      await controller.initialize();

      expect(controller.currentState.selectedBuilding, isNotNull);

      // Execute reset
      controller.reset();
      final state = controller.currentState;

      expect(state.selectedBuilding, isNull);
      expect(state.selectedFloor, isNull);
      expect(state.selectedCurrentLocation, isNull);
      expect(state.selectedDestination, isNull);
      expect(state.availableFloors, isEmpty);
      expect(state.availableNodes, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.hasValidSelection, isFalse);
      expect(state.hasRoutePoints, isFalse);
    });
  });
}
