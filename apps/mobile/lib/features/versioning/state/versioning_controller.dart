import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/version_snapshot.dart';
import '../services/versioning_service.dart';

class VersioningState {
  final bool isLoading;
  final List<VersionSnapshot> history;
  final String? errorMessage;
  final String? statusMessage;

  const VersioningState({
    this.isLoading = false,
    this.history = const [],
    this.errorMessage,
    this.statusMessage,
  });

  VersioningState copyWith({
    bool? isLoading,
    List<VersionSnapshot>? history,
    String? errorMessage,
    String? statusMessage,
  }) {
    return VersioningState(
      isLoading: isLoading ?? this.isLoading,
      history: history ?? this.history,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
    );
  }
}

class VersioningController extends StateNotifier<VersioningState> {
  final IVersioningService _service;

  VersioningController({IVersioningService? service})
      : _service = service ?? VersioningService(),
        super(const VersioningState());

  Future<void> fetchHistory(String buildingId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _service.getVersionHistory(buildingId);
      state = state.copyWith(isLoading: false, history: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> createSnapshot(
    String buildingId,
    Map<String, dynamic> data,
    String summary,
    String author,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final snapshot = await _service.createVersion(buildingId, data, summary, author);
      state = state.copyWith(
        isLoading: false,
        history: [snapshot, ...state.history],
        statusMessage: 'Snapshot v${snapshot.versionNumber} created',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final versioningProvider =
    StateNotifierProvider<VersioningController, VersioningState>((ref) {
  return VersioningController();
});
