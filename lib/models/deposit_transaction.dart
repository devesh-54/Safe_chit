class DepositTransaction {
  final String id;
  final String? depositId;
  final String groupId;
  final String memberId;
  final String type; // 'pay', 'refund', 'forfeit'
  final double amount;
  final String status; // 'success', 'failed'
  final String? reference;
  final String? failureReason;
  final DateTime createdAt;

  DepositTransaction({
    required this.id,
    this.depositId,
    required this.groupId,
    required this.memberId,
    required this.type,
    required this.amount,
    required this.status,
    this.reference,
    this.failureReason,
    required this.createdAt,
  });

  factory DepositTransaction.fromJson(Map<String, dynamic> json) {
    DateTime parseLocal(dynamic val) {
      if (val == null) return DateTime.now();
      final dt = DateTime.tryParse(val.toString());
      if (dt == null) return DateTime.now();
      return dt.toLocal();
    }

    return DepositTransaction(
      id: json['id']?.toString() ?? '',
      depositId: json['deposit_id']?.toString(),
      groupId: json['group_id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      type: (json['type']?.toString() ?? 'pay').toLowerCase(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status']?.toString() ?? 'success').toLowerCase(),
      reference: json['reference']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      createdAt: parseLocal(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deposit_id': depositId,
      'group_id': groupId,
      'member_id': memberId,
      'type': type,
      'amount': amount,
      'status': status,
      'reference': reference,
      'failure_reason': failureReason,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  DateTime get localCreatedAt => createdAt.toLocal();

  bool get isSuccess => status == 'success';
}
