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
    this.membersCount = 10,
  });

  /// Factory constructor to create a ChitGroup from JSON/Map
  factory ChitGroup.fromJson(Map<String, dynamic> json) {
    return ChitGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      totalPoolSize: (json['total_pool_size'] as num).toDouble(),
      durationMonths: json['duration_months'] as int,
      monthlyContribution: (json['monthly_contribution'] as num).toDouble(),
      securityDeposit: (json['security_deposit'] as num).toDouble(),
      payoutRules: json['payout_rules'] as String,
      inviteCode: json['invite_code'] as String,
      status: json['status'] as String? ?? 'Active',
      currentCycle: json['current_cycle'] as int? ?? 1,
      membersCount: json['members_count'] as int? ?? 10,
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
    );
  }
}
