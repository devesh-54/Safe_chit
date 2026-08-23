class ChitMemberRisk {
  final String id;
  final String groupId;
  final String name;
  final double defaultRiskScore; // 0 to 100
  final String payoutPosition; // e.g. 'Paid (Month 2)', 'Unpaid (Bidder)'
  final String paymentTrend; // e.g. 'On-Time', 'Delayed 2x', 'Delayed 4x'
  final String guarantorStatus; // e.g. 'Verified', 'Pending', 'None'
  final double amountExposed; // ₹ exposed to organizer default risk
  final bool hasDefaulted;
  final DateTime lastPaymentDate;
  final String phone;
  final bool forfeited; // Escrow forfeiture trigger status
  final bool defaultNoticeSent;
  final String? defaultNoticeText;

  const ChitMemberRisk({
    required this.id,
    required this.groupId,
    required this.name,
    required this.defaultRiskScore,
    required this.payoutPosition,
    required this.paymentTrend,
    required this.guarantorStatus,
    required this.amountExposed,
    this.hasDefaulted = false,
    required this.lastPaymentDate,
    required this.phone,
    this.forfeited = false,
    this.defaultNoticeSent = false,
    this.defaultNoticeText,
  });

  /// Factory constructor to create a ChitMemberRisk from JSON/Map
  factory ChitMemberRisk.fromJson(Map<String, dynamic> json) {
    return ChitMemberRisk(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      defaultRiskScore: (json['default_risk_score'] as num).toDouble(),
      payoutPosition: json['payout_position'] as String,
      paymentTrend: json['payment_trend'] as String,
      guarantorStatus: json['guarantor_status'] as String,
      amountExposed: (json['amount_exposed'] as num).toDouble(),
      hasDefaulted: json['has_defaulted'] as bool? ?? false,
      lastPaymentDate: DateTime.parse(json['last_payment_date'] as String),
      phone: json['phone'] as String? ?? '',
      forfeited: json['forfeited'] as bool? ?? false,
      defaultNoticeSent: json['default_notice_sent'] as bool? ?? false,
      defaultNoticeText: json['default_notice_text'] as String?,
    );
  }

  /// Convert a ChitMemberRisk instance into a JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'default_risk_score': defaultRiskScore,
      'payout_position': payoutPosition,
      'payment_trend': paymentTrend,
      'guarantor_status': guarantorStatus,
      'amount_exposed': amountExposed,
      'has_defaulted': hasDefaulted,
      'last_payment_date': lastPaymentDate.toIso8601String(),
      'phone': phone,
      'forfeited': forfeited,
      'default_notice_sent': defaultNoticeSent,
      'default_notice_text': defaultNoticeText,
    };
  }

  /// Create a copy of ChitMemberRisk with modified fields
  ChitMemberRisk copyWith({
    String? id,
    String? groupId,
    String? name,
    double? defaultRiskScore,
    String? payoutPosition,
    String? paymentTrend,
    String? guarantorStatus,
    double? amountExposed,
    bool? hasDefaulted,
    DateTime? lastPaymentDate,
    String? phone,
    bool? forfeited,
    bool? defaultNoticeSent,
    String? defaultNoticeText,
  }) {
    return ChitMemberRisk(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      defaultRiskScore: defaultRiskScore ?? this.defaultRiskScore,
      payoutPosition: payoutPosition ?? this.payoutPosition,
      paymentTrend: paymentTrend ?? this.paymentTrend,
      guarantorStatus: guarantorStatus ?? this.guarantorStatus,
      amountExposed: amountExposed ?? this.amountExposed,
      hasDefaulted: hasDefaulted ?? this.hasDefaulted,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      phone: phone ?? this.phone,
      forfeited: forfeited ?? this.forfeited,
      defaultNoticeSent: defaultNoticeSent ?? this.defaultNoticeSent,
      defaultNoticeText: defaultNoticeText ?? this.defaultNoticeText,
    );
  }
}
