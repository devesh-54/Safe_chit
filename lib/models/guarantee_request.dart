class GuaranteeRequest {
  final String id;
  final String groupId;
  final String groupName;
  final String joinRequestId;
  final String memberId; // member username
  final String? memberName;
  final String guarantorId; // guarantor username
  final String relation; // Family, Friend, Colleague, Neighbour, Other
  final String status; // pending, accepted, declined
  final double chitValue;
  final int durationMonths;
  final String consentText;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const GuaranteeRequest({
    required this.id,
    required this.groupId,
    this.groupName = '',
    required this.joinRequestId,
    required this.memberId,
    this.memberName,
    required this.guarantorId,
    required this.relation,
    this.status = 'pending',
    this.chitValue = 0.0,
    this.durationMonths = 1,
    this.consentText = "By accepting, you agree to act as a guarantor for this member's chit commitments.",
    required this.createdAt,
    this.respondedAt,
  });

  factory GuaranteeRequest.fromJson(Map<String, dynamic> json) {
    return GuaranteeRequest(
      id: json['id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      joinRequestId: json['join_request_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      memberName: json['member_name'] as String?,
      guarantorId: json['guarantor_id'] as String? ?? '',
      relation: json['relation'] as String? ?? 'Friend',
      status: json['status'] as String? ?? 'pending',
      chitValue: (json['chit_value'] as num?)?.toDouble() ?? 0.0,
      durationMonths: json['duration_months'] as int? ?? 1,
      consentText: json['consent_text'] as String? ??
          "By accepting, you agree to act as a guarantor for this member's chit commitments.",
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'join_request_id': joinRequestId,
      'member_id': memberId,
      'guarantor_id': guarantorId,
      'relation': relation,
      'status': status,
      'consent_text': consentText,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  GuaranteeRequest copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? joinRequestId,
    String? memberId,
    String? memberName,
    String? guarantorId,
    String? relation,
    String? status,
    double? chitValue,
    int? durationMonths,
    String? consentText,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return GuaranteeRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      joinRequestId: joinRequestId ?? this.joinRequestId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      guarantorId: guarantorId ?? this.guarantorId,
      relation: relation ?? this.relation,
      status: status ?? this.status,
      chitValue: chitValue ?? this.chitValue,
      durationMonths: durationMonths ?? this.durationMonths,
      consentText: consentText ?? this.consentText,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

