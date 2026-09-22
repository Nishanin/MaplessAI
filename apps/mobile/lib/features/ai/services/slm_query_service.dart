import '../../../core/models/ai_query_model.dart';
import '../../../core/models/ai_response_model.dart';
import '../domain/semantic_knowledge_graph.dart';

/// SLM Natural Language Query Service Interface & Rule-Based Implementation
/// Owner: Surabhi (Semantic AI Domain)
///
/// CRITICAL SECURITY INVARIANT:
/// This service never constructs or executes arbitrary SQL or database operations.
/// It parses intent, extracts entities, and resolves candidate node IDs strictly
/// through SemanticKnowledgeGraph lookups. It never invents or hardcodes node IDs.
///
/// targetNodeId is only set when the knowledge graph returns exactly one
/// unambiguous match. Multiple matches or zero matches both leave targetNodeId
/// as null — the caller (navigation layer) handles candidate selection.

/// Minimum confidence required to emit a non-FALLBACK intent.
const double _kConfidenceThreshold = 0.5;

/// Safe fallback response. targetNodeId is always null.
AiResponseModel _fallback(String originalText) {
  return AiResponseModel(
    intent: 'FALLBACK',
    entities: const [],
    constraints: const {},
    targetNodeId: null,
    confidence: 0.0,
    responseMessage:
        'I could not understand that request. Please rephrase — '
        'you can ask me to find rooms, labs, elevators, or emergency exits.',
  );
}

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
    final accessible = query.userContext?.accessible ?? false;

    // ── Intent / entity recognition (rule-based placeholder) ──────────────
    // Full SLM pipeline will be developed by Surabhi on feature/surabhi-semantic-ai.
    String? intent;
    List<AiEntityModel> entities = const [];
    Map<String, dynamic> constraints = const {};
    double confidence = 0.0;
    String? responseMessage;
    List<String> candidateIds = const [];

    if (text.contains('nearest') || text.contains('closest')) {
      if (text.contains('lab') || text.contains('laboratory')) {
        intent = 'FIND_NEAREST';
        entities = const [AiEntityModel(type: 'category', value: 'laboratory')];
        constraints = {
          'category': 'laboratory',
          if (accessible) 'accessible': true,
        };
        confidence = 0.80;
        candidateIds = knowledgeGraph.findMatchingNodeIds(tag: 'computers');
        responseMessage = candidateIds.isNotEmpty
            ? 'Found ${candidateIds.length} laboratory candidate(s). '
              'Please confirm your current location to get directions.'
            : 'No laboratory found in this building\'s directory. '
              'Try asking for a specific room name.';
      } else if (text.contains('exit') || text.contains('emergency')) {
        intent = 'EMERGENCY_EXIT';
        entities = const [
          AiEntityModel(type: 'category', value: 'emergency_exit')
        ];
        constraints = const {};
        confidence = 0.90;
        candidateIds =
            knowledgeGraph.findMatchingNodeIds(tag: 'emergency');
        responseMessage = candidateIds.isNotEmpty
            ? 'Emergency exit located. Please follow the highlighted route.'
            : 'Locating emergency exit. Please follow floor signage.';
      } else if (text.contains('lift') || text.contains('elevator')) {
        intent = 'FIND_NEAREST';
        entities = const [AiEntityModel(type: 'category', value: 'elevator')];
        constraints = {'category': 'elevator'};
        confidence = 0.80;
        candidateIds =
            knowledgeGraph.findMatchingNodeIds(tag: 'elevator');
        responseMessage = 'Looking for the nearest elevator.';
      } else if (text.contains('restroom') ||
          text.contains('toilet') ||
          text.contains('washroom')) {
        intent = 'FIND_NEAREST';
        entities = const [AiEntityModel(type: 'category', value: 'restroom')];
        constraints = {'category': 'restroom'};
        confidence = 0.80;
        candidateIds =
            knowledgeGraph.findMatchingNodeIds(tag: 'restroom');
        responseMessage = 'Looking for the nearest restroom.';
      }
    } else if (text.contains('exit') ||
        text.contains('emergency') ||
        text.contains('evacuat')) {
      intent = 'EMERGENCY_EXIT';
      entities = const [
        AiEntityModel(type: 'category', value: 'emergency_exit')
      ];
      constraints = const {};
      confidence = 0.90;
      candidateIds = knowledgeGraph.findMatchingNodeIds(tag: 'emergency');
      responseMessage = candidateIds.isNotEmpty
          ? 'Emergency exit located. Please follow the highlighted route.'
          : 'Locating emergency exit. Please follow floor signage.';
    } else if (text.contains('go to') ||
        text.contains('take me to') ||
        text.contains('navigate to')) {
      intent = 'NAVIGATE_TO';
      entities = const [];
      constraints = const {};
      confidence = 0.65;
      responseMessage =
          'Navigation requested. Please confirm your destination from the map.';
    } else if (text.contains('where is') ||
        text.contains('find') ||
        text.contains('locate')) {
      intent = 'LOCATE_ROOM';
      entities = const [];
      constraints = const {};
      confidence = 0.60;
      responseMessage =
          'Searching for the location. Please provide more detail if possible.';
    } else if (text.contains('open') ||
        text.contains('hours') ||
        text.contains('capacity') ||
        text.contains('wifi')) {
      intent = 'QUERY_INFO';
      entities = const [];
      constraints = const {};
      confidence = 0.65;
      responseMessage =
          'Looking up facility information. Please specify a room or area name.';
    }

    // ── Confidence gate ────────────────────────────────────────────────────
    if (intent == null || confidence < _kConfidenceThreshold) {
      return _fallback(query.text);
    }

    // ── Resolve targetNodeId — only when exactly one match found ───────────
    // Multiple candidates or zero candidates leave targetNodeId null.
    // The caller is responsible for candidate selection when multiple exist.
    final String? targetNodeId =
        (candidateIds.length == 1) ? candidateIds.first : null;

    return AiResponseModel(
      intent: intent,
      entities: entities,
      constraints: constraints,
      targetNodeId: targetNodeId,
      confidence: confidence,
      responseMessage: responseMessage,
    );
  }
}
