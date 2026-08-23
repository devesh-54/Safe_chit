class ChitJoinRequest {
  final String id;
  final String groupId;
  final String groupName;
  final String inviteCode;
  final String memberUsername;
  final String memberName;
  final String memberPhone;
  final String memberEmail;
  final String memberCity;
  final double reputationScore;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  ChitJoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviteCode,
    required this.memberUsername,
    required this.memberName,
    required this.memberPhone,
    required this.memberEmail,
    required this.memberCity,
    required this.reputationScore,
    required this.status,
    required this.createdAt,
  });

  factory ChitJoinRequest.fromJson(Map<String, dynamic> json) {
    return ChitJoinRequest(
      id: json['id'] as String? ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? 'Chit Group',
      inviteCode: json['invite_code'] as String? ?? '',
      memberUsername: json['member_username'] as String? ?? '',
      memberName: json['member_name'] as String? ?? 'Applicant Member',
      memberPhone: json['member_phone'] as String? ?? '',
      memberEmail: json['member_email'] as String? ?? '',
      memberCity: json['member_city'] as String? ?? '',
      reputationScore: (json['reputation_score'] as num?)?.toDouble() ?? 100.0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'group_name': groupName,
      'invite_code': inviteCode,
      'member_username': memberUsername,
      'member_name': memberName,
      'member_phone': memberPhone,
      'member_email': memberEmail,
      'member_city': memberCity,
      'reputation_score': reputationScore,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChitJoinRequest copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? inviteCode,
    String? memberUsername,
    String? memberName,
    String? memberPhone,
    String? memberEmail,
    String? memberCity,
    double? reputationScore,
    String? status,
    DateTime? createdAt,
  }) {
    return ChitJoinRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      inviteCode: inviteCode ?? this.inviteCode,
      memberUsername: memberUsername ?? this.memberUsername,
      memberName: memberName ?? this.memberName,
      memberPhone: memberPhone ?? this.memberPhone,
      memberEmail: memberEmail ?? this.memberEmail,
      memberCity: memberCity ?? this.memberCity,
      reputationScore: reputationScore ?? this.reputationScore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
