class ChitGroup {
  final String id;
  final String name;
  final double totalPoolSize;
  final int durationMonths;
  final double monthlyContribution;
  final double securityDeposit;
  final String payoutRules;
  final String inviteCode;
  final String status; // 'Active', 'Pending', 'Completed'
  final int currentCycle;
  final int membersCount;
  final String schemeType; // 'Bidding', 'Random Picking'
  final bool isPublic; // Publicly listed in marketplace
  final String city;
  final String foremanUpiId;

  const ChitGroup({
    required this.id,
    required this.name,
    required this.totalPoolSize,
    required this.durationMonths,
    required this.monthlyContribution,
    required this.securityDeposit,
    required this.payoutRules,
    required this.inviteCode,
    this.status = 'Active',
    this.currentCycle = 1,
    this.membersCount = 5,
    this.schemeType = 'Bidding',
    this.isPublic = true,
    this.city = 'Bengaluru',
    this.foremanUpiId = 'devesh1@oksbi',
  });

  /// Factory constructor to create a ChitGroup from JSON/Map
  factory ChitGroup.fromJson(Map<String, dynamic> json) {
    return ChitGroup(
      id: json['id'] as String? ?? 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Chit Group',
      totalPoolSize: (json['total_pool_size'] as num?)?.toDouble() ?? 5.0,
      durationMonths: json['duration_months'] as int? ?? 5,
      monthlyContribution: (json['monthly_contribution'] as num?)?.toDouble() ?? 1.0,
      securityDeposit: (json['security_deposit'] as num?)?.toDouble() ?? 1.0,
      payoutRules: json['payout_rules'] as String? ?? 'Standard bidding rules per Chit Funds Act 1982.',
      inviteCode: json['invite_code'] as String? ?? '849201',
      status: json['status'] as String? ?? 'Active',
      currentCycle: json['current_cycle'] as int? ?? 1,
      membersCount: json['members_count'] as int? ?? 5,
      schemeType: json['scheme_type'] as String? ?? 'Bidding',
      isPublic: json['is_public'] as bool? ?? true,
      city: json['city'] as String? ?? 'Bengaluru',
      foremanUpiId: json['foreman_upi_id'] as String? ?? 'devesh1@oksbi',
    );
  }

  /// Convert a ChitGroup instance into a JSON-compatible Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'total_pool_size': totalPoolSize,
      'duration_months': durationMonths,
      'monthly_contribution': monthlyContribution,
      'security_deposit': securityDeposit,
      'payout_rules': payoutRules,
      'invite_code': inviteCode,
      'status': status,
      'current_cycle': currentCycle,
      'members_count': membersCount,
      'scheme_type': schemeType,
      'is_public': isPublic,
      'city': city,
      'foreman_upi_id': foremanUpiId,
    };
  }

  /// Create a copy of ChitGroup with modified fields
  ChitGroup copyWith({
    String? id,
    String? name,
    double? totalPoolSize,
    int? durationMonths,
    double? monthlyContribution,
    double? securityDeposit,
    String? payoutRules,
    String? inviteCode,
    String? status,
    int? currentCycle,
    int? membersCount,
    String? schemeType,
    bool? isPublic,
    String? city,
    String? foremanUpiId,
  }) {
    return ChitGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      totalPoolSize: totalPoolSize ?? this.totalPoolSize,
      durationMonths: durationMonths ?? this.durationMonths,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      securityDeposit: securityDeposit ?? this.securityDeposit,
      payoutRules: payoutRules ?? this.payoutRules,
      inviteCode: inviteCode ?? this.inviteCode,
      status: status ?? this.status,
      currentCycle: currentCycle ?? this.currentCycle,
      membersCount: membersCount ?? this.membersCount,
      schemeType: schemeType ?? this.schemeType,
      isPublic: isPublic ?? this.isPublic,
      city: city ?? this.city,
      foremanUpiId: foremanUpiId ?? this.foremanUpiId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChitGroup && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
