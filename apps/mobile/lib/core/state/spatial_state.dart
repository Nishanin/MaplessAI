import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building_model.dart';
import '../models/floor_model.dart';
import '../models/node_model.dart';
import '../utils/json_utils.dart';

/// Global UI and Spatial Selection State
/// Owner: Nishant (Phase 2 — Global UI State)
class SpatialState {
  final bool isLoading;
  final BuildingModel? selectedBuilding;
  final FloorModel? selectedFloor;
  final NodeModel? selectedCurrentLocation;
  final NodeModel? selectedDestination;
  final List<BuildingModel> availableBuildings;
  final List<FloorModel> availableFloors;
  final List<NodeModel> availableNodes;
  final String? errorMessage;

  const SpatialState({
    this.isLoading = false,
    this.selectedBuilding,
    this.selectedFloor,
    this.selectedCurrentLocation,
    this.selectedDestination,
    this.availableBuildings = const [],
    this.availableFloors = const [],
    this.availableNodes = const [],
    this.errorMessage,
  });

  bool get hasValidSelection => selectedBuilding != null && selectedFloor != null;
  bool get hasRoutePoints => selectedCurrentLocation != null && selectedDestination != null;

  SpatialState copyWith({
    bool? isLoading,
    BuildingModel? selectedBuilding,
    bool clearBuilding = false,
    FloorModel? selectedFloor,
    bool clearFloor = false,
    NodeModel? selectedCurrentLocation,
    bool clearCurrentLocation = false,
    NodeModel? selectedDestination,
    bool clearDestination = false,
    List<BuildingModel>? availableBuildings,
    List<FloorModel>? availableFloors,
    List<NodeModel>? availableNodes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SpatialState(
      isLoading: isLoading ?? this.isLoading,
      selectedBuilding: clearBuilding ? null : (selectedBuilding ?? this.selectedBuilding),
      selectedFloor: clearFloor ? null : (selectedFloor ?? this.selectedFloor),
      selectedCurrentLocation:
          clearCurrentLocation ? null : (selectedCurrentLocation ?? this.selectedCurrentLocation),
      selectedDestination:
          clearDestination ? null : (selectedDestination ?? this.selectedDestination),
      availableBuildings: availableBuildings ?? this.availableBuildings,
      availableFloors: availableFloors ?? this.availableFloors,
      availableNodes: availableNodes ?? this.availableNodes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing application spatial selection state
class SpatialController extends StateNotifier<SpatialState> {
  SpatialController() : super(const SpatialState(availableBuildings: _defaultBuildings)) {
    initialize();
  }

  static const List<BuildingModel> _defaultBuildings = [
    BuildingModel(
      id: 'bld-vit-cc-01',
      name: 'Academic Block 1 (AB-1)',
      address: 'Vandalur-Kelambakkam Road, Chennai, TN 600127',
      category: 'academic',
      latitude: 12.8406,
      longitude: 80.1534,
      metadata: {'floors': 3, 'campus': 'VIT Chennai'},
    ),
    BuildingModel(
      id: 'bld-vit-tt-02',
      name: 'Technology Tower (TT)',
      address: 'East Campus Quad, Chennai, TN',
      category: 'academic',
      latitude: 12.8412,
      longitude: 80.1540,
      metadata: {'floors': 5, 'campus': 'VIT Chennai'},
    ),
    BuildingModel(
      id: 'bld-vit-lib-03',
      name: 'Central Library',
      address: 'Central Square, Campus Center',
      category: 'facility',
      latitude: 12.8400,
      longitude: 80.1528,
      metadata: {'floors': 2, 'campus': 'VIT Chennai'},
    ),
    BuildingModel(
      id: 'bld-vit-adm-04',
      name: 'Admin Block',
      address: 'Main Entrance Avenue',
      category: 'administrative',
      latitude: 12.8395,
      longitude: 80.1520,
      metadata: {'floors': 2, 'campus': 'VIT Chennai'},
    ),
  ];

  static const List<FloorModel> _defaultAb1Floors = [
    FloorModel(
      id: 'flr-vit-ab1-01',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 1,
      name: 'Ground Floor (Floor 1)',
      elevation: 0.0,
    ),
    FloorModel(
      id: 'flr-vit-ab1-02',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 2,
      name: 'First Floor (Floor 2)',
      elevation: 4.0,
    ),
    FloorModel(
      id: 'flr-vit-ab1-03',
      buildingId: 'bld-vit-cc-01',
      floorNumber: 3,
      name: 'Second Floor (Floor 3)',
      elevation: 8.0,
    ),
  ];

  static const List<NodeModel> _defaultNodes = [
    NodeModel(
      id: 'node-entrance-01',
      name: 'Main Entrance',
      category: 'entrance',
      floorId: 'flr-vit-ab1-01',
      x: 10.0,
      y: 20.0,
      accessible: true,
    ),
    NodeModel(
      id: 'node-corridor-01',
      name: 'Corridor Junction A',
      category: 'corridor',
      floorId: 'flr-vit-ab1-01',
      x: 25.0,
      y: 20.0,
      accessible: true,
    ),
    NodeModel(
      id: 'node-corridor-02',
      name: 'Corridor Junction B',
      category: 'corridor',
      floorId: 'flr-vit-ab1-01',
      x: 50.0,
      y: 20.0,
      accessible: true,
    ),
    NodeModel(
      id: 'node-stairs-01',
      name: 'East Stairwell',
      category: 'stairs',
      floorId: 'flr-vit-ab1-01',
      x: 50.0,
      y: 35.0,
      accessible: false,
    ),
    NodeModel(
      id: 'node-elevator-01',
      name: 'Central Elevator',
      category: 'elevator',
      floorId: 'flr-vit-ab1-01',
      x: 25.0,
      y: 5.0,
      accessible: true,
    ),
    NodeModel(
      id: 'node-lab-101',
      name: 'Robotics Lab 101',
      category: 'room',
      floorId: 'flr-vit-ab1-01',
      x: 70.0,
      y: 20.0,
      accessible: true,
    ),
  ];

  /// Initialize state with default mock dataset
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Attempt to load from bundled asset if available, fallback to built-in fixtures
      try {
        final dataset = await JsonUtils.loadMockDatasetFromAsset();
        state = state.copyWith(
          isLoading: false,
          selectedBuilding: dataset.building,
          selectedFloor: dataset.floor,
          availableFloors: _defaultAb1Floors,
          availableNodes: dataset.nodes,
          selectedCurrentLocation: dataset.nodes.isNotEmpty ? dataset.nodes.first : null,
          selectedDestination: dataset.nodes.length > 1 ? dataset.nodes.last : null,
        );
        return;
      } catch (_) {
        // Fallback for tests or environments without asset bundle
      }

      final defaultBuilding = state.availableBuildings.first;
      state = state.copyWith(
        isLoading: false,
        selectedBuilding: defaultBuilding,
        selectedFloor: _defaultAb1Floors.first,
        availableFloors: _defaultAb1Floors,
        availableNodes: _defaultNodes,
        selectedCurrentLocation: _defaultNodes.first,
        selectedDestination: _defaultNodes.last,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Select active building and update corresponding floor list
  void selectBuilding(BuildingModel? building) {
    if (building == null) {
      state = state.copyWith(
        clearBuilding: true,
        clearFloor: true,
        clearCurrentLocation: true,
        clearDestination: true,
        availableFloors: const [],
        availableNodes: const [],
      );
      return;
    }

    // Generate floors for selected building
    final floors = building.id == 'bld-vit-cc-01'
        ? _defaultAb1Floors
        : [
            FloorModel(
              id: 'flr-${building.id}-01',
              buildingId: building.id,
              floorNumber: 1,
              name: 'Ground Floor',
              elevation: 0.0,
            ),
            FloorModel(
              id: 'flr-${building.id}-02',
              buildingId: building.id,
              floorNumber: 2,
              name: 'Floor 2',
              elevation: 4.0,
            ),
          ];

    final initialFloor = floors.isNotEmpty ? floors.first : null;
    final initialNodes = building.id == 'bld-vit-cc-01' ? _defaultNodes : <NodeModel>[];

    state = state.copyWith(
      selectedBuilding: building,
      selectedFloor: initialFloor,
      availableFloors: floors,
      availableNodes: initialNodes,
      selectedCurrentLocation: initialNodes.isNotEmpty ? initialNodes.first : null,
      selectedDestination: initialNodes.length > 1 ? initialNodes.last : null,
      clearError: true,
    );
  }

  /// Select active floor and filter or load corresponding nodes
  void selectFloor(FloorModel? floor) {
    if (floor == null) {
      state = state.copyWith(
        clearFloor: true,
        clearCurrentLocation: true,
        clearDestination: true,
        availableNodes: const [],
      );
      return;
    }

    state = state.copyWith(
      selectedFloor: floor,
      clearError: true,
    );
  }

  /// Set user's current location node
  void setCurrentLocation(NodeModel? node) {
    state = state.copyWith(
      selectedCurrentLocation: node,
      clearCurrentLocation: node == null,
    );
  }

  /// Set user's current location by node ID
  void setCurrentLocationById(String? nodeId) {
    if (nodeId == null) {
      setCurrentLocation(null);
      return;
    }
    final match = state.availableNodes.where((n) => n.id == nodeId).firstOrNull;
    if (match != null) {
      setCurrentLocation(match);
    }
  }

  /// Set destination node
  void setDestination(NodeModel? node) {
    state = state.copyWith(
      selectedDestination: node,
      clearDestination: node == null,
    );
  }

  /// Set destination by node ID
  void setDestinationById(String? nodeId) {
    if (nodeId == null) {
      setDestination(null);
      return;
    }
    final match = state.availableNodes.where((n) => n.id == nodeId).firstOrNull;
    if (match != null) {
      setDestination(match);
    }
  }

  /// Swap start location and destination
  void swapLocations() {
    final current = state.selectedCurrentLocation;
    final dest = state.selectedDestination;
    state = state.copyWith(
      selectedCurrentLocation: dest,
      selectedDestination: current,
      clearCurrentLocation: dest == null,
      clearDestination: current == null,
    );
  }

  /// Reset all selections back to clean state
  void reset() {
    state = state.copyWith(
      clearBuilding: true,
      clearFloor: true,
      clearCurrentLocation: true,
      clearDestination: true,
      availableFloors: const [],
      availableNodes: const [],
      clearError: true,
      isLoading: false,
    );
  }

  /// Clear any error message
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  /// Current state snapshot accessor
  SpatialState get currentState => state;
}

/// Global Riverpod Provider for Spatial State
final spatialStateProvider = StateNotifierProvider<SpatialController, SpatialState>((ref) {
  return SpatialController();
});
