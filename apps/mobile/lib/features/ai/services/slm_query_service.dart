import '../../../core/models/ai_query_model.dart';
import '../../../core/models/ai_response_model.dart';
import '../domain/semantic_knowledge_graph.dart';

/// SLM Natural Language Query Service Interface & Baseline Stub
/// Owner: Surabhi (Semantic AI Domain)
///
/// CRITICAL SECURITY INVARIANT:
/// This service never constructs or executes arbitrary SQL or database operations.
/// It parses intent, extracts entities, and matches against the SemanticKnowledgeGraph.
abstract class ISlmQueryService {
  Future<AiResponseModel> processQuery(
    AiQueryModel query,
    SemanticKnowledgeGraph knowledgeGraph,
  );
}

class SlmQueryService implements ISlmQueryService {
  @override
  Future<AiResponseModel> processQuery(
    AiQueryModel query,
    SemanticKnowledgeGraph knowledgeGraph,
  ) async {
    final text = query.text.toLowerCase();

    // Baseline rule-based intent parsing placeholder
    // Full SLM pipeline will be developed by Surabhi on feature/surabhi-semantic-ai
    if (text.contains('nearest') || text.contains('closest')) {
      if (text.contains('lab')) {
        return const AiResponseModel(
          intent: 'FIND_NEAREST',
          entities: [AiEntityModel(type: 'category', value: 'laboratory')],
          constraints: {'category': 'laboratory', 'accessible': true},
          targetNodeId: 'lab-101',
          confidence: 0.92,
          responseMessage: 'Found Lab 101 on First Floor.',
        );
      }
    }

    if (text.contains('exit') || text.contains('emergency')) {
      return const AiResponseModel(
        intent: 'EMERGENCY_EXIT',
        entities: [AiEntityModel(type: 'category', value: 'emergency_exit')],
        constraints: {},
        targetNodeId: 'exit-a',
        confidence: 0.98,
        responseMessage: 'Routing to Emergency Exit A.',
      );
    }

    return AiResponseModel(
      intent: 'QUERY_INFO',
      entities: const [],
      constraints: const {},
      targetNodeId: null,
      confidence: 0.70,
      responseMessage: 'Understood request: "${query.text}". Searching campus directory...',
    );
  }
}
