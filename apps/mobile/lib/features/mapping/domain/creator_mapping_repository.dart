import 'map_draft_model.dart';

/// Result envelope for map publishing operations
class PublishResult {
  final bool isSuccess;
  final MapDraft draft;
  final bool isMock;
  final String message;
  final DateTime? publishedAt;
  final String? error;

  const PublishResult({
    required this.isSuccess,
    required this.draft,
    required this.isMock,
    required this.message,
    this.publishedAt,
    this.error,
  });

  factory PublishResult.success({
    required MapDraft draft,
    required bool isMock,
    required String message,
  }) {
    return PublishResult(
      isSuccess: true,
      draft: draft,
      isMock: isMock,
      message: message,
      publishedAt: DateTime.now(),
    );
  }

  factory PublishResult.failure({
    required MapDraft draft,
    required bool isMock,
    required String error,
  }) {
    return PublishResult(
      isSuccess: false,
      draft: draft,
      isMock: isMock,
      message: 'Failed to publish map graph: $error',
      error: error,
    );
  }
}

/// Abstract repository for creator mapping persistence
/// Owner: Nishant (Phase 3 — Creator Repository Abstraction)
abstract class ICreatorMappingRepository {
  /// Fetches all active draft maps
  Future<List<MapDraft>> getDrafts();

  /// Fetches all published maps
  Future<List<MapDraft>> getPublishedMaps();

  /// Retrieves a specific draft by ID
  Future<MapDraft?> getDraftById(String draftId);

  /// Saves or updates a draft map locally
  Future<MapDraft> saveDraft(MapDraft draft);

  /// Deletes a draft map
  Future<void> deleteDraft(String draftId);

  /// Submits a validated map for publishing
  Future<PublishResult> publishMap(MapDraft draft, {bool simulateFailure = false});
}
