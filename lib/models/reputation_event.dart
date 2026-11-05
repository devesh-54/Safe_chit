class ReputationEvent {
  final String id;
  final String username;
  final String role; // 'member' or 'foreman'
  final String eventType;
  final double scoreDelta;
  final String description;
  final DateTime createdAt;

  const ReputationEvent({
    required this.id,
    required this.username,
    required this.role,
    required this.eventType,
    required this.scoreDelta,
    required this.description,
    required this.createdAt,
  });

  factory ReputationEvent.fromJson(Map<String, dynamic> json) {
    return ReputationEvent(
      id: json['id']?.toString() ?? '',
      username: (json['username'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? 'member').trim().toLowerCase(),
      eventType: json['event_type'] as String? ?? 'general',
      scoreDelta: (json['score_delta'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'event_type': eventType,
      'score_delta': scoreDelta,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

