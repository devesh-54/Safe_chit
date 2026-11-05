class SecurityDeposit {
  final String id;
  final String groupId;
  final String memberId;
  final double amount;
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
    required this.status,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SecurityDeposit.fromJson(Map<String, dynamic> json) {
    return SecurityDeposit(
      id: json['id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      memberId: json['member_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'amount': amount,
      'status': status,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isHeld => status == 'held';
  bool get isPending => status == 'pending';
  bool get isRefunded => status == 'refunded';
  bool get isForfeited => status == 'forfeited';

  String get displayStatus {
    switch (status) {
      case 'held':
        return 'Held';
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

