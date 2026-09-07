import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/navigation_request_model.dart';
import '../../../core/models/navigation_response_model.dart';
import '../domain/spatial_graph.dart';
import '../services/pathfinding_service.dart';

class NavigationState {
  final bool isLoading;
  final NavigationResponseModel? currentRoute;
  final String? errorMessage;
  final String? selectedStartNodeId;
  final String? selectedDestinationNodeId;

  const NavigationState({
    this.isLoading = false,
    this.currentRoute,
    this.errorMessage,
    this.selectedStartNodeId,
    this.selectedDestinationNodeId,
  });

  NavigationState copyWith({
    bool? isLoading,
    NavigationResponseModel? currentRoute,
    String? errorMessage,
    String? selectedStartNodeId,
    String? selectedDestinationNodeId,
  }) {
    return NavigationState(
      isLoading: isLoading ?? this.isLoading,
      currentRoute: currentRoute ?? this.currentRoute,
      errorMessage: errorMessage,
      selectedStartNodeId: selectedStartNodeId ?? this.selectedStartNodeId,
      selectedDestinationNodeId: selectedDestinationNodeId ?? this.selectedDestinationNodeId,
    );
  }
}

class NavigationController extends StateNotifier<NavigationState> {
  final IPathfindingService _service;

  NavigationController({IPathfindingService? service})
      : _service = service ?? PathfindingService(),
        super(const NavigationState());

  void setStartNode(String nodeId) {
    state = state.copyWith(selectedStartNodeId: nodeId);
  }

  void setDestinationNode(String nodeId) {
    state = state.copyWith(selectedDestinationNodeId: nodeId);
  }

  Future<void> calculateRoute(SpatialGraph graph, String buildingId) async {
    if (state.selectedStartNodeId == null || state.selectedDestinationNodeId == null) {
      state = state.copyWith(errorMessage: 'Please select both start and destination locations');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final request = NavigationRequestModel(
        buildingId: buildingId,
        startNodeId: state.selectedStartNodeId!,
        destinationNodeId: state.selectedDestinationNodeId!,
      );
      final response = await _service.computeRoute(graph, request);
      state = state.copyWith(isLoading: false, currentRoute: response);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearRoute() {
    state = const NavigationState();
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationController, NavigationState>((ref) {
  return NavigationController();
});
