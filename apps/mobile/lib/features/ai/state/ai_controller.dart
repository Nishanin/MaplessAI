import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ai_query_model.dart';
import '../../../core/models/ai_response_model.dart';
import '../domain/semantic_knowledge_graph.dart';
import '../services/slm_query_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final AiResponseModel? response;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.response,
  });
}

class AiState {
  final bool isLoading;
  final List<ChatMessage> messages;
  final String? errorMessage;

  const AiState({
    this.isLoading = false,
    this.messages = const [],
    this.errorMessage,
  });

  AiState copyWith({
    bool? isLoading,
    List<ChatMessage>? messages,
    String? errorMessage,
  }) {
    return AiState(
      isLoading: isLoading ?? this.isLoading,
      messages: messages ?? this.messages,
      errorMessage: errorMessage,
    );
  }
}

class AiController extends StateNotifier<AiState> {
  final ISlmQueryService _service;

  AiController({ISlmQueryService? service})
      : _service = service ?? SlmQueryService(),
        super(const AiState());

  Future<void> submitQuery(
    String text,
    String buildingId,
    SemanticKnowledgeGraph knowledgeGraph, {
    String? currentNodeId,
    bool? accessible,
  }) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      isLoading: true,
      messages: [...state.messages, userMsg],
      errorMessage: null,
    );

    try {
      final query = AiQueryModel(
        text: text,
        buildingId: buildingId,
        userContext: UserContextModel(
          currentNodeId: currentNodeId,
          accessible: accessible,
        ),
      );

      final response = await _service.processQuery(query, knowledgeGraph);

      final botMsg = ChatMessage(
        text: response.responseMessage ?? 'Intent resolved: ${response.intent}',
        isUser: false,
        timestamp: DateTime.now(),
        response: response,
      );

      state = state.copyWith(
        isLoading: false,
        messages: [...state.messages, botMsg],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clearConversation() {
    state = const AiState();
  }
}

final aiProvider = StateNotifierProvider<AiController, AiState>((ref) {
  return AiController();
});
