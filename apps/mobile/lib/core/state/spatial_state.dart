import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/building_model.dart';
import '../models/edge_model.dart';
import '../models/floor_model.dart';
import '../models/node_model.dart';
import '../utils/json_utils.dart';

/// Global UI and Spatial Selection State
/// Owner: Nishant (Phase 2 — Global UI State, Phase 5 — Spatial Visualization State)
class SpatialState {
  final bool isLoading;
  final BuildingModel? selectedBuilding;
  final FloorModel? selectedFloor;
  final NodeModel? selectedCurrentLocation;
  final NodeModel? selectedDestination;
  final NodeModel? selectedNode;
  final List<BuildingModel> availableBuildings;
  final List<FloorModel> availableFloors;
  final List<NodeModel> availableNodes;
  final List<EdgeModel> availableEdges;
  final String? errorMessage;

  const SpatialState({
    this.isLoading = false,
    this.selectedBuilding,
    this.selectedFloor,
    this.selectedCurrentLocation,
    this.selectedDestination,
    this.selectedNode,
    this.availableBuildings = const [],
    this.availableFloors = const [],
    this.availableNodes = const [],
    this.availableEdges = const [],
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
    NodeModel? selectedNode,
    bool clearSelectedNode = false,
    List<BuildingModel>? availableBuildings,
    List<FloorModel>? availableFloors,
    List<NodeModel>? availableNodes,
    List<EdgeModel>? availableEdges,
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
      selectedNode: clearSelectedNode ? null : (selectedNode ?? this.selectedNode),
      availableBuildings: availableBuildings ?? this.availableBuildings,
      availableFloors: availableFloors ?? this.availableFloors,
      availableNodes: availableNodes ?? this.availableNodes,
      availableEdges: availableEdges ?? this.availableEdges,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller managing application spatial selection state
class SpatialController extends StateNotifier<SpatialState> {
  SpatialController({SpatialState? initialState, bool autoInitialize = true})
      : super(initialState ?? const SpatialState(availableBuildings: _defaultBuildings)) {
    if (autoInitialize && initialState == null) {
      initialize();
    }
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

  static List<NodeModel> _getNodesForFloor(String floorId) {
    switch (floorId) {
      case 'flr-vit-ab1-01':
        return const [
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
            x: 35.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-elevator-01',
            name: 'Central Elevator',
            category: 'elevator',
            floorId: 'flr-vit-ab1-01',
            x: 35.0,
            y: 5.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-corridor-02',
            name: 'Corridor Junction B',
            category: 'corridor',
            floorId: 'flr-vit-ab1-01',
            x: 60.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-stairs-01',
            name: 'East Stairwell',
            category: 'stairs',
            floorId: 'flr-vit-ab1-01',
            x: 60.0,
            y: 35.0,
            accessible: false,
          ),
          NodeModel(
            id: 'node-lab-101',
            name: 'Robotics Lab 101',
            category: 'room',
            floorId: 'flr-vit-ab1-01',
            x: 85.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-exit-01',
            name: 'Emergency Exit East',
            category: 'emergency_exit',
            floorId: 'flr-vit-ab1-01',
            x: 60.0,
            y: 50.0,
            accessible: true,
          ),
        ];

      case 'flr-vit-ab1-02':
        return const [
          NodeModel(
            id: 'node-f2-elevator-01',
            name: 'Central Elevator (F2)',
            category: 'elevator',
            floorId: 'flr-vit-ab1-02',
            x: 35.0,
            y: 5.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f2-corridor-01',
            name: 'Corridor Junction (F2)',
            category: 'corridor',
            floorId: 'flr-vit-ab1-02',
            x: 35.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f2-lounge',
            name: 'Faculty Lounge 202',
            category: 'room',
            floorId: 'flr-vit-ab1-02',
            x: 10.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f2-corridor-02',
            name: 'East Corridor (F2)',
            category: 'corridor',
            floorId: 'flr-vit-ab1-02',
            x: 60.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f2-stairs-01',
            name: 'East Stairwell (F2)',
            category: 'stairs',
            floorId: 'flr-vit-ab1-02',
            x: 60.0,
            y: 35.0,
            accessible: false,
          ),
          NodeModel(
            id: 'node-f2-lab-201',
            name: 'Software Eng Lab 201',
            category: 'room',
            floorId: 'flr-vit-ab1-02',
            x: 85.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f2-exit-02',
            name: 'Emergency Exit 2',
            category: 'emergency_exit',
            floorId: 'flr-vit-ab1-02',
            x: 60.0,
            y: 50.0,
            accessible: true,
          ),
        ];

      case 'flr-vit-ab1-03':
        return const [
          NodeModel(
            id: 'node-f3-elevator-01',
            name: 'Central Elevator (F3)',
            category: 'elevator',
            floorId: 'flr-vit-ab1-03',
            x: 35.0,
            y: 5.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f3-corridor-01',
            name: 'Executive Corridor (F3)',
            category: 'corridor',
            floorId: 'flr-vit-ab1-03',
            x: 35.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f3-dean',
            name: "Dean's Office 301",
            category: 'room',
            floorId: 'flr-vit-ab1-03',
            x: 10.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f3-corridor-02',
            name: 'Conference Corridor (F3)',
            category: 'corridor',
            floorId: 'flr-vit-ab1-03',
            x: 60.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f3-stairs-01',
            name: 'East Stairwell (F3)',
            category: 'stairs',
            floorId: 'flr-vit-ab1-03',
            x: 60.0,
            y: 35.0,
            accessible: false,
          ),
          NodeModel(
            id: 'node-f3-seminar',
            name: 'Auditorium & Seminar 302',
            category: 'room',
            floorId: 'flr-vit-ab1-03',
            x: 85.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-f3-exit-03',
            name: 'Emergency Exit 3',
            category: 'emergency_exit',
            floorId: 'flr-vit-ab1-03',
            x: 60.0,
            y: 50.0,
            accessible: true,
          ),
        ];

      default:
        // Generic floor template for other buildings
        return [
          NodeModel(
            id: 'node-$floorId-entrance',
            name: 'Floor Lobby',
            category: 'entrance',
            floorId: floorId,
            x: 15.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-$floorId-corridor',
            name: 'Main Hallway',
            category: 'corridor',
            floorId: floorId,
            x: 40.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-$floorId-elevator',
            name: 'Elevator Shaft',
            category: 'elevator',
            floorId: floorId,
            x: 40.0,
            y: 5.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-$floorId-stairs',
            name: 'Main Staircase',
            category: 'stairs',
            floorId: floorId,
            x: 65.0,
            y: 35.0,
            accessible: false,
          ),
          NodeModel(
            id: 'node-$floorId-room1',
            name: 'Research Room',
            category: 'room',
            floorId: floorId,
            x: 85.0,
            y: 20.0,
            accessible: true,
          ),
          NodeModel(
            id: 'node-$floorId-exit',
            name: 'Emergency Exit',
            category: 'emergency_exit',
            floorId: floorId,
            x: 65.0,
            y: 50.0,
            accessible: true,
          ),
        ];
    }
  }

  static List<EdgeModel> _getEdgesForFloor(String floorId) {
    final nodes = _getNodesForFloor(floorId);
    if (nodes.length < 2) return const [];

    final edges = <EdgeModel>[];
    // Create standard hallway linkages
    for (int i = 0; i < nodes.length - 1; i++) {
      final a = nodes[i];
      final b = nodes[i + 1];
      final dist = (a.x - b.x).abs() + (a.y - b.y).abs();
      edges.add(
        EdgeModel(
          id: 'edge-${a.id}-${b.id}',
          startNodeId: a.id,
          endNodeId: b.id,
          distance: dist > 0 ? dist : 5.0,
          bearing: 90.0,
          accessible: a.accessible && b.accessible,
          blocked: false,
        ),
      );
    }
    return edges;
  }

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
          availableEdges: dataset.edges,
          selectedCurrentLocation: dataset.nodes.isNotEmpty ? dataset.nodes.first : null,
          selectedDestination: dataset.nodes.length > 1 ? dataset.nodes.last : null,
        );
        return;
      } catch (_) {
        // Fallback for tests or environments without asset bundle
      }

      final defaultBuilding = state.availableBuildings.first;
      final defaultFloor = _defaultAb1Floors.first;
      final floorNodes = _getNodesForFloor(defaultFloor.id);
      final floorEdges = _getEdgesForFloor(defaultFloor.id);

      state = state.copyWith(
        isLoading: false,
        selectedBuilding: defaultBuilding,
        selectedFloor: defaultFloor,
        availableFloors: _defaultAb1Floors,
        availableNodes: floorNodes,
        availableEdges: floorEdges,
        selectedCurrentLocation: floorNodes.first,
        selectedDestination: floorNodes.last,
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
        clearSelectedNode: true,
        availableFloors: const [],
        availableNodes: const [],
        availableEdges: const [],
      );
      return;
    }

    // Generate floors for selected building
    final floors = building.id == 'bld-vit-cc-01'
        ? _defaultAb1Floors
        : building.id == 'bld-vit-tt-02'
            ? List.generate(
                5,
                (i) => FloorModel(
                  id: 'flr-${building.id}-0${i + 1}',
                  buildingId: building.id,
                  floorNumber: i + 1,
                  name: i == 0 ? 'Ground Floor (Lobby)' : 'Level ${i + 1}',
                  elevation: i * 4.0,
                ),
              )
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
                  name: 'Level 2',
                  elevation: 4.0,
                ),
              ];

    final initialFloor = floors.isNotEmpty ? floors.first : null;
    final initialNodes = initialFloor != null ? _getNodesForFloor(initialFloor.id) : <NodeModel>[];
    final initialEdges = initialFloor != null ? _getEdgesForFloor(initialFloor.id) : <EdgeModel>[];

    state = state.copyWith(
      selectedBuilding: building,
      selectedFloor: initialFloor,
      availableFloors: floors,
      availableNodes: initialNodes,
      availableEdges: initialEdges,
      selectedCurrentLocation: initialNodes.isNotEmpty ? initialNodes.first : null,
      selectedDestination: initialNodes.length > 1 ? initialNodes.last : null,
      clearSelectedNode: true,
      clearError: true,
    );
  }

  /// Select active floor and filter or load corresponding nodes and edges
  void selectFloor(FloorModel? floor) {
    if (floor == null) {
      state = state.copyWith(
        clearFloor: true,
        clearCurrentLocation: true,
        clearDestination: true,
        clearSelectedNode: true,
        availableNodes: const [],
        availableEdges: const [],
      );
      return;
    }

    final floorNodes = _getNodesForFloor(floor.id);
    final floorEdges = _getEdgesForFloor(floor.id);

    // If current selections are on another floor, update them to this floor's nodes
    final currentLoc = state.selectedCurrentLocation?.floorId == floor.id
        ? state.selectedCurrentLocation
        : (floorNodes.isNotEmpty ? floorNodes.first : null);

    final dest = state.selectedDestination?.floorId == floor.id
        ? state.selectedDestination
        : (floorNodes.length > 1 ? floorNodes.last : null);

    state = state.copyWith(
      selectedFloor: floor,
      availableNodes: floorNodes,
      availableEdges: floorEdges,
      selectedCurrentLocation: currentLoc,
      selectedDestination: dest,
      clearSelectedNode: state.selectedNode?.floorId != floor.id,
      clearError: true,
    );
  }

  /// Select a node for inspector / highlighted inspection
  void selectNode(NodeModel? node) {
    state = state.copyWith(
      selectedNode: node,
      clearSelectedNode: node == null,
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
      clearSelectedNode: true,
      availableFloors: const [],
      availableNodes: const [],
      availableEdges: const [],
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
