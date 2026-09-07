/// User context submodel for AI query
class UserContextModel {
  final String? currentNodeId;
  final bool? accessible;
  final String? currentFloorId;

  const UserContextModel({
    this.currentNodeId,
    this.accessible,
    this.currentFloorId,
  });

  factory UserContextModel.fromJson(Map<String, dynamic> json) {
    return UserContextModel(
      currentNodeId: json['currentNodeId'] as String?,
      accessible: json['accessible'] as bool?,
      currentFloorId: json['currentFloorId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (currentNodeId != null) 'currentNodeId': currentNodeId,
      if (accessible != null) 'accessible': accessible,
      if (currentFloorId != null) 'currentFloorId': currentFloorId,
    };
  }
}

/// AiQuery domain model matching contracts/ai-query.schema.json
class AiQueryModel {
  final String text;
  final String buildingId;
  final UserContextModel? userContext;

  const AiQueryModel({
    required this.text,
    required this.buildingId,
    this.userContext,
  });

  factory AiQueryModel.fromJson(Map<String, dynamic> json) {
    return AiQueryModel(
      text: json['text'] as String,
      buildingId: json['buildingId'] as String,
      userContext: json['userContext'] != null
          ? UserContextModel.fromJson(json['userContext'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'buildingId': buildingId,
      if (userContext != null) 'userContext': userContext!.toJson(),
    };
  }
}
