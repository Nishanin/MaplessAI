/// Entity extracted by SLM
class AiEntityModel {
  final String type;
  final String value;

  const AiEntityModel({
    required this.type,
    required this.value,
  });

  factory AiEntityModel.fromJson(Map<String, dynamic> json) {
    return AiEntityModel(
      type: json['type'] as String,
      value: json['value'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
    };
  }
}

/// AiResponse domain model matching contracts/ai-response.schema.json
class AiResponseModel {
  final String intent;
  final List<AiEntityModel> entities;
  final Map<String, dynamic> constraints;
  final String? targetNodeId;
  final double confidence;
  final String? responseMessage;

  const AiResponseModel({
    required this.intent,
    required this.entities,
    required this.constraints,
    this.targetNodeId,
    required this.confidence,
    this.responseMessage,
  });

  factory AiResponseModel.fromJson(Map<String, dynamic> json) {
    return AiResponseModel(
      intent: json['intent'] as String,
      entities: (json['entities'] as List<dynamic>)
          .map((e) => AiEntityModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      constraints: (json['constraints'] as Map<String, dynamic>?) ?? const {},
      targetNodeId: json['targetNodeId'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      responseMessage: json['responseMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'entities': entities.map((e) => e.toJson()).toList(),
      'constraints': constraints,
      if (targetNodeId != null) 'targetNodeId': targetNodeId,
      'confidence': confidence,
      if (responseMessage != null) 'responseMessage': responseMessage,
    };
  }
}
