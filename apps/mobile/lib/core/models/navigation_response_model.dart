/// Turn instruction submodel
class TurnInstructionModel {
  final int step;
  final String instruction;
  final double distance;
  final double bearing;
  final String? nodeId;

  const TurnInstructionModel({
    required this.step,
    required this.instruction,
    required this.distance,
    required this.bearing,
    this.nodeId,
  });

  factory TurnInstructionModel.fromJson(Map<String, dynamic> json) {
    return TurnInstructionModel(
      step: json['step'] as int,
      instruction: json['instruction'] as String,
      distance: (json['distance'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      nodeId: json['nodeId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'instruction': instruction,
      'distance': distance,
      'bearing': bearing,
      if (nodeId != null) 'nodeId': nodeId,
    };
  }
}

/// Floor transition submodel
class FloorTransitionModel {
  final String fromFloorId;
  final String toFloorId;
  final String viaType;
  final String nodeId;

  const FloorTransitionModel({
    required this.fromFloorId,
    required this.toFloorId,
    required this.viaType,
    required this.nodeId,
  });

  factory FloorTransitionModel.fromJson(Map<String, dynamic> json) {
    return FloorTransitionModel(
      fromFloorId: json['fromFloorId'] as String,
      toFloorId: json['toFloorId'] as String,
      viaType: json['viaType'] as String,
      nodeId: json['nodeId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fromFloorId': fromFloorId,
      'toFloorId': toFloorId,
      'viaType': viaType,
      'nodeId': nodeId,
    };
  }
}

/// NavigationResponse domain model matching contracts/navigation-response.schema.json
class NavigationResponseModel {
  final bool success;
  final List<String> pathNodeIds;
  final List<String> edgeIds;
  final double totalDistance;
  final double estimatedTimeSeconds;
  final List<TurnInstructionModel> turnInstructions;
  final List<FloorTransitionModel> floorTransitions;
  final String? message;

  const NavigationResponseModel({
    required this.success,
    required this.pathNodeIds,
    this.edgeIds = const [],
    required this.totalDistance,
    required this.estimatedTimeSeconds,
    required this.turnInstructions,
    this.floorTransitions = const [],
    this.message,
  });

  factory NavigationResponseModel.fromJson(Map<String, dynamic> json) {
    return NavigationResponseModel(
      success: json['success'] as bool,
      pathNodeIds: (json['pathNodeIds'] as List<dynamic>).map((e) => e.toString()).toList(),
      edgeIds: (json['edgeIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      totalDistance: (json['totalDistance'] as num).toDouble(),
      estimatedTimeSeconds: (json['estimatedTimeSeconds'] as num).toDouble(),
      turnInstructions: (json['turnInstructions'] as List<dynamic>)
          .map((e) => TurnInstructionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      floorTransitions: (json['floorTransitions'] as List<dynamic>?)
              ?.map((e) => FloorTransitionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'pathNodeIds': pathNodeIds,
      'edgeIds': edgeIds,
      'totalDistance': totalDistance,
      'estimatedTimeSeconds': estimatedTimeSeconds,
      'turnInstructions': turnInstructions.map((e) => e.toJson()).toList(),
      'floorTransitions': floorTransitions.map((e) => e.toJson()).toList(),
      if (message != null) 'message': message,
    };
  }
}
