/// Navigation preferences submodel
class NavigationPreferencesModel {
  final bool accessible;
  final bool avoidStairs;
  final bool avoidBlockedEdges;
  final bool emergencyMode;

  const NavigationPreferencesModel({
    this.accessible = false,
    this.avoidStairs = false,
    this.avoidBlockedEdges = true,
    this.emergencyMode = false,
  });

  factory NavigationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NavigationPreferencesModel(
      accessible: json['accessible'] as bool? ?? false,
      avoidStairs: json['avoidStairs'] as bool? ?? false,
      avoidBlockedEdges: json['avoidBlockedEdges'] as bool? ?? true,
      emergencyMode: json['emergencyMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessible': accessible,
      'avoidStairs': avoidStairs,
      'avoidBlockedEdges': avoidBlockedEdges,
      'emergencyMode': emergencyMode,
    };
  }
}

/// NavigationRequest domain model matching contracts/navigation-request.schema.json
class NavigationRequestModel {
  final String buildingId;
  final String startNodeId;
  final String destinationNodeId;
  final NavigationPreferencesModel preferences;

  const NavigationRequestModel({
    required this.buildingId,
    required this.startNodeId,
    required this.destinationNodeId,
    this.preferences = const NavigationPreferencesModel(),
  });

  factory NavigationRequestModel.fromJson(Map<String, dynamic> json) {
    return NavigationRequestModel(
      buildingId: json['buildingId'] as String,
      startNodeId: json['startNodeId'] as String,
      destinationNodeId: json['destinationNodeId'] as String,
      preferences: json['preferences'] != null
          ? NavigationPreferencesModel.fromJson(json['preferences'] as Map<String, dynamic>)
          : const NavigationPreferencesModel(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'startNodeId': startNodeId,
      'destinationNodeId': destinationNodeId,
      'preferences': preferences.toJson(),
    };
  }
}
