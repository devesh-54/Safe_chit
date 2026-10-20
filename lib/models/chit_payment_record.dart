class ChitPaymentRecord {
  final String id;
  final String groupId;
  final String groupName;
  final int cycle;
  final String memberUsername;
  final String memberName;
  final double amount;
  final int amountPaise;
  final String paymentMethod; // 'UPI', 'CASH_COUNTER', 'CARD_COUNTER'
  final String status; // 'INITIATED', 'QUEUED', 'ACTIVE', 'PAID', 'FAILED', 'EXPIRED'
  final String? utr;
  final String? paymentSessionId;
  final String payeeVpa;
  final String payeeName;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? notes;

  ChitPaymentRecord({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.cycle,
    required this.memberUsername,
    required this.memberName,
    required this.amount,
    required this.amountPaise,
    required this.paymentMethod,
    required this.status,
    this.utr,
    this.paymentSessionId,
    required this.payeeVpa,
    required this.payeeName,
    required this.createdAt,
    this.completedAt,
    this.notes,
  });

  bool get isPaid => status == 'PAID' || status == 'SUCCESS';
  bool get isPending => status == 'ACTIVE' || status == 'INITIATED' || status == 'QUEUED';

  factory ChitPaymentRecord.fromMap(Map<String, dynamic> map) {
    final amountDouble = (map['amount'] as num?)?.toDouble() ?? 
        ((map['amount_paise'] as num?) != null ? (map['amount_paise'] as num).toDouble() / 100.0 : 0.0);
    final amountPaiseInt = (map['amount_paise'] as num?)?.toInt() ?? (amountDouble * 100).toInt();

    return ChitPaymentRecord(
      id: map['id']?.toString() ?? '',
      groupId: map['group_id']?.toString() ?? '',
      groupName: map['group_name']?.toString() ?? 'Chit Group',
      cycle: (map['cycle'] as num?)?.toInt() ?? 1,
      memberUsername: map['member_username']?.toString() ?? '',
      memberName: map['member_name']?.toString() ?? '',
      amount: amountDouble,
      amountPaise: amountPaiseInt,
      paymentMethod: map['payment_method']?.toString() ?? 'UPI',
      status: map['status']?.toString() ?? 'INITIATED',
      utr: map['utr']?.toString(),
      paymentSessionId: map['payment_session_id']?.toString(),
      payeeVpa: map['payee_vpa']?.toString() ?? 'safechit.foreman@upi',
      payeeName: map['payee_name']?.toString() ?? 'SafeChit Foreman',
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      completedAt: map['completed_at'] != null ? DateTime.tryParse(map['completed_at'].toString()) : null,
      notes: map['notes']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'group_name': groupName,
      'cycle': cycle,
      'member_username': memberUsername,
      'member_name': memberName,
      'amount': amount,
      'amount_paise': amountPaise,
      'payment_method': paymentMethod,
      'status': status,
      'utr': utr,
      'payment_session_id': paymentSessionId,
      'payee_vpa': payeeVpa,
      'payee_name': payeeName,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  ChitPaymentRecord copyWith({
    String? id,
    String? groupId,
    String? groupName,
    int? cycle,
    String? memberUsername,
    String? memberName,
    double? amount,
    int? amountPaise,
    String? paymentMethod,
    String? status,
    String? utr,
    String? paymentSessionId,
    String? payeeVpa,
    String? payeeName,
    DateTime? createdAt,
    DateTime? completedAt,
    String? notes,
  }) {
    return ChitPaymentRecord(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      cycle: cycle ?? this.cycle,
      memberUsername: memberUsername ?? this.memberUsername,
      memberName: memberName ?? this.memberName,
      amount: amount ?? this.amount,
      amountPaise: amountPaise ?? this.amountPaise,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      utr: utr ?? this.utr,
      paymentSessionId: paymentSessionId ?? this.paymentSessionId,
      payeeVpa: payeeVpa ?? this.payeeVpa,
      payeeName: payeeName ?? this.payeeName,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}
