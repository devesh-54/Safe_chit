class SecurityDeposit {
  final String id;
  final String groupId;
  final String memberId;
  final double amount;
  final double appliedAmount;
  final String status; // 'pending', 'held', 'refunded', 'forfeited'
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  SecurityDeposit({
    required this.id,
    required this.groupId,
    required this.memberId,
    required this.amount,
    this.appliedAmount = 0.0,
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SecurityDeposit.fromJson(Map<String, dynamic> json) {
    DateTime parseLocal(dynamic val) {
      if (val == null) return DateTime.now();
      final dt = DateTime.tryParse(val.toString());
      if (dt == null) return DateTime.now();
      return dt.toLocal();
    }

    return SecurityDeposit(
      id: json['id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      appliedAmount: (json['applied_amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      createdAt: parseLocal(json['created_at']),
      updatedAt: parseLocal(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'amount': amount,
      'applied_amount': appliedAmount,
      'status': status,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  bool get isHeld => status == 'held';
  bool get isPending => status == 'pending';
  bool get isRefunded => status == 'refunded';
  bool get isForfeited => status == 'forfeited';

  /// Returns timestamps converted to device local time
  DateTime get localCreatedAt => createdAt.toLocal();
  DateTime get localUpdatedAt => updatedAt.toLocal();

  String get displayStatus {
    switch (status) {
      case 'held':
        return 'Recorded';
      case 'refunded':
        return 'Refunded';
      case 'forfeited':
        return 'Forfeited';
      case 'pending':
      default:
        return 'Pending';
    }
  }
}

