/// Edge domain model matching contracts/edge.schema.json
class EdgeModel {
  final String id;
  final String startNodeId;
  final String endNodeId;
  final double distance;
  final double bearing;
  final bool accessible;
  final bool blocked;
  final Map<String, dynamic> metadata;

  const EdgeModel({
    required this.id,
    required this.startNodeId,
    required this.endNodeId,
    required this.distance,
    required this.bearing,
    required this.accessible,
    required this.blocked,
    this.metadata = const {},
  });

  factory EdgeModel.fromJson(Map<String, dynamic> json) {
    return EdgeModel(
      id: json['id'] as String,
      startNodeId: json['startNodeId'] as String,
      endNodeId: json['endNodeId'] as String,
      distance: (json['distance'] as num).toDouble(),
      bearing: (json['bearing'] as num).toDouble(),
      accessible: json['accessible'] as bool? ?? true,
      blocked: json['blocked'] as bool? ?? false,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startNodeId': startNodeId,
      'endNodeId': endNodeId,
      'distance': distance,
      'bearing': bearing,
      'accessible': accessible,
      'blocked': blocked,
      'metadata': metadata,
    };
  }

  EdgeModel copyWith({
    String? id,
    String? startNodeId,
    String? endNodeId,
    double? distance,
    double? bearing,
    bool? accessible,
    bool? blocked,
    Map<String, dynamic>? metadata,
  }) {
    return EdgeModel(
      id: id ?? this.id,
      startNodeId: startNodeId ?? this.startNodeId,
      endNodeId: endNodeId ?? this.endNodeId,
      distance: distance ?? this.distance,
      bearing: bearing ?? this.bearing,
      accessible: accessible ?? this.accessible,
      blocked: blocked ?? this.blocked,
      metadata: metadata ?? this.metadata,
    );
  }
}
