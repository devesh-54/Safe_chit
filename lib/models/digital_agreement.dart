class DigitalAgreement {
  final String id;
  final String groupId;
  final String groupName;
  final String foremanUsername;
  final String foremanName;
  final String memberUsername;
  final String memberName;
  final double poolAmount;
  final int durationMonths;
  final double monthlyContribution;
  final String schemeType; // 'Bidding' or 'Random Picking'
  final String agreementText;
  final bool foremanSigned;
  final String? foremanSignatureUrl;
  final DateTime? foremanSignedAt;
  final bool memberSigned;
  final String? memberSignatureUrl;
  final DateTime? memberSignedAt;
  final String status; // 'pending_signatures', 'fully_executed'
  final DateTime createdAt;

  const DigitalAgreement({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.foremanUsername,
    required this.foremanName,
    required this.memberUsername,
    required this.memberName,
    required this.poolAmount,
    required this.durationMonths,
    required this.monthlyContribution,
    required this.schemeType,
    required this.agreementText,
    this.foremanSigned = false,
    this.foremanSignatureUrl,
    this.foremanSignedAt,
    this.memberSigned = false,
    this.memberSignatureUrl,
    this.memberSignedAt,
    this.status = 'pending_signatures',
    required this.createdAt,
  });

  factory DigitalAgreement.fromJson(Map<String, dynamic> json) {
    return DigitalAgreement(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      foremanUsername: json['foreman_username'] as String? ?? 'foreman_admin',
      foremanName: json['foreman_name'] as String? ?? 'Rajesh Kumar (Foreman)',
      memberUsername: json['member_username'] as String,
      memberName: json['member_name'] as String,
      poolAmount: (json['pool_amount'] as num).toDouble(),
      durationMonths: json['duration_months'] as int,
      monthlyContribution: (json['monthly_contribution'] as num).toDouble(),
      schemeType: json['scheme_type'] as String? ?? 'Bidding',
      agreementText: json['agreement_text'] as String,
      foremanSigned: json['foreman_signed'] as bool? ?? false,
      foremanSignatureUrl: json['foreman_signature_url'] as String?,
      foremanSignedAt: json['foreman_signed_at'] != null 
          ? DateTime.parse(json['foreman_signed_at'] as String) 
          : null,
      memberSigned: json['member_signed'] as bool? ?? false,
      memberSignatureUrl: json['member_signature_url'] as String?,
      memberSignedAt: json['member_signed_at'] != null 
          ? DateTime.parse(json['member_signed_at'] as String) 
          : null,
      status: json['status'] as String? ?? 'pending_signatures',
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
      'foreman_username': foremanUsername,
      'foreman_name': foremanName,
      'member_username': memberUsername,
      'member_name': memberName,
      'pool_amount': poolAmount,
      'duration_months': durationMonths,
      'monthly_contribution': monthlyContribution,
      'scheme_type': schemeType,
      'agreement_text': agreementText,
      'foreman_signed': foremanSigned,
      'foreman_signature_url': foremanSignatureUrl,
      'foreman_signed_at': foremanSignedAt?.toIso8601String(),
      'member_signed': memberSigned,
      'member_signature_url': memberSignatureUrl,
      'member_signed_at': memberSignedAt?.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Generate standard legally compliant Chit Agreement text based on Chit Funds Act, 1982
  static String generateLegalAgreementText({
    required String groupName,
    required String foremanName,
    required String memberName,
    required double poolAmount,
    required int durationMonths,
    required double monthlyContribution,
    required String schemeType,
    required double securityDeposit,
  }) {
    final today = DateTime.now();
    final formattedDate = "${today.day}/${today.month}/${today.year}";

    return '''
================================================================================
DIGITAL CHIT AGREEMENT & SUBSCRIBER UNDERTAKING
(Formally Executed under Section 6 of the Chit Funds Act, 1982)
Date of Execution: $formattedDate
================================================================================

BETWEEN:
1. THE FOREMAN (ORGANIZER): $foremanName
   Representing Chit Scheme: $groupName

AND:
2. THE SUBSCRIBER (MEMBER): $memberName

--------------------------------------------------------------------------------
ARTICLE I: CHIT SCHEME SPECIFICATIONS & FINANCIAL OBLIGATIONS
--------------------------------------------------------------------------------
1. Total Chit Pool Amount: ₹${poolAmount.toStringAsFixed(0)}
2. Scheme Duration: $durationMonths Months ($durationMonths Installments)
3. Monthly Contribution per Subscriber: ₹${monthlyContribution.toStringAsFixed(0)}
4. Scheme Operation Mechanism: $schemeType System
   - Bidding System: Auction-based discount bidding per monthly cycle.
   - Random Picking System: Transparent lucky-draw lot selection per monthly cycle.
5. Escrow Security Deposit Held: ₹${securityDeposit.toStringAsFixed(0)}

--------------------------------------------------------------------------------
ARTICLE II: SUBSCRIBER COVENANTS & DEFAULT CONSEQUENCES
--------------------------------------------------------------------------------
1. Timely Installments: Subscriber agrees to remit ₹${monthlyContribution.toStringAsFixed(0)} on or before the 5th day of every calendar month.
2. Default Interest & Penalty (Section 28, Chit Funds Act 1982):
   Any delayed installment shall attract penalty interest @ 18% per annum for the period of delay.
3. Default by Non-Prized Subscriber:
   If a non-prized subscriber defaults for two consecutive cycles, the Foreman reserves the legal right to remove the subscriber, forfeit late penalty fees, and replace them.
4. Default by Prized Subscriber (Consolidated Demand & Recovery):
   If a subscriber who has already drawn/prized the chit amount defaults on subsequent monthly installments:
   a) All future remaining installments become IMMEDIATELY DUE AND PAYABLE in one consolidated lump sum.
   b) The Foreman is authorized to forfeit the security deposit held in escrow (₹${securityDeposit.toStringAsFixed(0)}).
   c) Immediate legal recovery proceedings will be initiated under the Bharatiya Nyaya Sanhita (BNS), 2024 (Section 316 - Criminal Breach of Trust / Section 318 - Cheating) and Civil Recovery Suits.

--------------------------------------------------------------------------------
ARTICLE III: FOREMAN UNDERTAKINGS & INDEMNITY
--------------------------------------------------------------------------------
1. The Foreman guarantees the safe custody and timely disbursement of chit funds to the winner of each cycle.
2. The Foreman maintains 100% indemnity for non-prized subscribers against defalcations by defaulted prized subscribers.

--------------------------------------------------------------------------------
ARTICLE IV: DIGITAL SIGNATURE & LEGAL BINDING
--------------------------------------------------------------------------------
By applying digital signatures below, both parties confirm full acceptance of all terms under the Information Technology Act, 2000 and Section 6 of the Chit Funds Act, 1982.
''';
  }
}
