import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../models/chit_payment_record.dart';
import '../../models/security_deposit.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import '../../core/config/deposit_config.dart';
import '../../features/bidding/live_bidding_room.dart';
import '../../widgets/razorpay_checkout_modal.dart';
import '../payment/payment_checkout_screen.dart';
import '../payment/simulated_bank_screen.dart';
import 'digital_agreement_modal.dart';

class GroupDetailsModal extends StatefulWidget {
  final ChitGroup group;
  final bool isForeman;
  final String currentUsername;
  final bool isApproved;

  const GroupDetailsModal({
    super.key,
    required this.group,
    required this.isForeman,
    required this.currentUsername,
    this.isApproved = true,
  });

  @override
  State<GroupDetailsModal> createState() => _GroupDetailsModalState();
}

class _GroupDetailsModalState extends State<GroupDetailsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChitMemberRisk> _members = [];
  Map<String, SecurityDeposit> _rosterDeposits = {};
  SecurityDeposit? _mySecurityDeposit;
  bool _isLoading = true;
  bool _isPaidCurrentCycle = false;
  Timer? _countdownTimer;
  int _countdownSeconds = 22 * 60 + 15; // 22 mins, 15 secs simulation
  int _countdownHours = 14;
  int _countdownDays = 2;

  // Design Tokens (Calm Financial Trust palette)
  static const Color _kSurface = Color(0xFFF8F9FF);
  static const Color _kPrimaryContainer = Color(0xFF0D234A);
  static const Color _kSecondary = Color(0xFF006A61);
  static const Color _kSecondaryAccent = Color(0xFF0D9488);
  static const Color _kSecondaryContainer = Color(0xFFCCFBF1);
  static const Color _kOnSurface = Color(0xFF0B1C30);
  static const Color _kOnSurfaceVariant = Color(0xFF44474E);
  static const Color _kSurfaceContainerLow = Color(0xFFEFF4FF);
  static const Color _kSurfaceContainer = Color(0xFFE5EEFF);
  static const Color _kSurfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color _kBorder = Color(0xFFE2E8F0);
  static const Color _kAmberBg = Color(0xFFFEF3C7);
  static const Color _kAmberText = Color(0xFF92400E);

  String get _foremanName => 'Rajesh Kumar (Foreman)';

  String _formatCurrency(double val) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: val % 1 == 0 ? 0 : 2,
    ).format(val);
  }

  double get _depositAmount => widget.group.effectiveDepositAmount;

  int _getUserPayoutMonth() {
    final idx = _members.indexWhere(
      (m) => m.name.toLowerCase() == widget.currentUsername.toLowerCase(),
    );
    if (idx != -1) {
      return (idx + 1).clamp(1, widget.group.durationMonths);
    }
    return (widget.group.durationMonths - 1).clamp(1, widget.group.durationMonths);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupMembers();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_countdownSeconds > 0) {
          _countdownSeconds--;
        } else {
          _countdownSeconds = 59;
          if (_countdownHours > 0) {
            _countdownHours--;
          } else {
            _countdownHours = 23;
            if (_countdownDays > 0) _countdownDays--;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getGroupMembers(widget.group.id),
        SupabaseService.getGroupSecurityDeposits(widget.group.id),
        SupabaseService.getGroupPayments(widget.group.id),
        SupabaseService.getSecurityDeposit(
          groupId: widget.group.id,
          memberId: widget.currentUsername,
        ),
      ]);

      final members = results[0] as List<ChitMemberRisk>;
      final deposits = results[1] as Map<String, SecurityDeposit>;
      final payments = results[2] as List<ChitPaymentRecord>;
      final myDep = deposits[widget.currentUsername] ?? results[3] as SecurityDeposit?;

      final paid = payments.any(
        (p) =>
            p.memberUsername.toLowerCase() == widget.currentUsername.toLowerCase() &&
            (p.cycle == widget.group.currentCycle || p.cycle == widget.group.currentCycle + 1) &&
            (p.status == 'PAID' || p.status == 'CONFIRMED'),
      );

      if (mounted) {
        setState(() {
          _members = members;
          _rosterDeposits = deposits;
          _mySecurityDeposit = myDep;
          _isPaidCurrentCycle = paid;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDepositCheckoutModal() {
    if (!kDepositViaRazorpay) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SimulatedBankScreen(
            groupId: widget.group.id,
            groupName: widget.group.name,
            memberId: widget.currentUsername,
            amount: _depositAmount,
            onDepositCompleted: () {
              _loadGroupMembers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security deposit recorded successfully!'),
                  backgroundColor: Color(0xFF0D9488),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    RazorpayCheckoutModal.show(
      context: context,
      groupId: widget.group.id,
      groupName: widget.group.name,
      memberId: widget.currentUsername,
      amount: _depositAmount,
      onDepositSuccess: () {
        _loadGroupMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security deposit verified and recorded!'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _openInstallmentCheckout() async {
    await PaymentCheckoutScreen.open(
      context: context,
      group: widget.group,
      currentUsername: widget.currentUsername,
      onPaymentSuccess: () {
        if (mounted) {
          setState(() {
            _isPaidCurrentCycle = true;
          });
        }
      },
    );
    if (mounted) {
      _loadGroupMembers();
    }
  }

  void _openDigitalAgreement() {
    final agreement = DigitalAgreement(
      id: 'AGR-${widget.group.id}-${widget.currentUsername}',
      groupId: widget.group.id,
      groupName: widget.group.name,
      foremanUsername: 'foreman',
      foremanName: _foremanName,
      memberUsername: widget.currentUsername,
      memberName: widget.currentUsername,
      poolAmount: widget.group.totalPoolSize,
      durationMonths: widget.group.durationMonths,
      monthlyContribution: widget.group.monthlyContribution,
      schemeType: widget.group.schemeType,
      agreementText: 'Standard Chit Agreement compliant with Chit Funds Act 1982.',
      memberSigned: true,
      foremanSigned: true,
      status: 'fully_executed',
      createdAt: DateTime.now(),
    );
    DigitalAgreementModal.open(
      context: context,
      agreement: agreement,
      isForeman: widget.isForeman,
      onSigned: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Digital agreement timestamped and recorded.'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      },
    );
  }

  void _openGroupInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.group.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kOnSurface,
              ),
            ),
            Text(
              'Chit Funds Act 1982 • Licensed Group',
              style: TextStyle(fontSize: 12, color: _kOnSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Chit ID Code', '#${widget.group.inviteCode}'),
            _buildDetailRow(
              'Total Pool Amount',
              '₹${NumberFormat('#,##,###').format(widget.group.totalPoolSize.toInt())}',
            ),
            _buildDetailRow('Scheme Duration', '${widget.group.durationMonths} Months'),
            _buildDetailRow(
              'Monthly Contribution',
              '₹${NumberFormat('#,##,###').format(widget.group.monthlyContribution.toInt())}',
            ),
            _buildDetailRow('Host / Foreman', _foremanName),
            _buildDetailRow('Receiving UPI', widget.group.foremanUpiId.isNotEmpty ? widget.group.foremanUpiId : 'devesh1@oksbi'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close Group Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _kOnSurfaceVariant, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _kOnSurface,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _openReportProblemModal() {
    int selectedReason = 0;
    final reasons = [
      'Discrepancy in installment amount or dividend',
      'Host did not acknowledge payment',
      'Auction rules or timing issue',
      'Other question or assistance',
    ];
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Report an issue with this group',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kOnSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kSecondaryContainer.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.verified_user_rounded,
                          size: 20,
                          color: _kSecondary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Our dispute resolution team reviews all logs and host confirmations. Your transactions remain recorded in SafeChit.',
                            style: TextStyle(fontSize: 12, color: _kOnSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(reasons.length, (i) {
                    final isSel = selectedReason == i;
                    return InkWell(
                      onTap: () => setModalState(() => selectedReason = i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSel ? _kSurfaceContainerLow : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? _kSecondaryAccent : _kBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSel ? _kSecondaryAccent : const Color(0xFF94A3B8),
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reasons[i],
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _kOnSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'Add details (optional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kOnSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Explain what happened so our mediator can resolve this smoothly...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _kOnSurfaceVariant.withOpacity(0.6),
                      ),
                      filled: true,
                      fillColor: _kSurfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _kBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: _kBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Report submitted. SafeChit team will review within 2 hours.',
                                ),
                                backgroundColor: Color(0xFF0F4C81),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimaryContainer,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Submit report'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openReceiptDrawer(String type) {
    String title = 'Installment #${widget.group.currentCycle}';
    String amount =
        '₹${NumberFormat('#,##,###').format(widget.group.monthlyContribution.toInt())}';
    String badge = 'Confirmed';
    bool isConfirmed = true;

    if (type == 'preview-due' || type == 'm3-pending') {
      badge = 'Due in 3 days';
      isConfirmed = false;
    } else if (type == 'sec-dep') {
      title = 'Initial Security Deposit';
      amount = _formatCurrency(_depositAmount);
      badge = 'Deposit recorded';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction Receipt',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kOnSurface,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VERIFIED CHIT VOUCHER',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kOnSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _kOnSurface,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isConfirmed
                          ? _kSecondaryContainer
                          : _kAmberBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isConfirmed
                              ? Icons.done_all_rounded
                              : Icons.schedule_rounded,
                          size: 14,
                          color: isConfirmed ? _kSecondary : _kAmberText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed ? _kSecondary : _kAmberText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Purpose', title),
            _buildDetailRow('Digital Transaction UTR', 'SC${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
            _buildDetailRow(
              'Host Confirmation',
              'Verified by $_foremanName (Direct Confirmation)',
            ),
            _buildDetailRow('Payment Mode', 'UPI Instant Settlement'),
            _buildDetailRow(
              'Timestamp',
              DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openReportProblemModal();
                },
                child: const Text(
                  'Report a problem with this entry',
                  style: TextStyle(fontSize: 12, color: _kOnSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMemberListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.80,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chit Members (${_members.length}/${widget.group.durationMonths})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kOnSurface,
                        ),
                      ),
                      Text(
                        '${widget.group.name} • ${widget.group.durationMonths} Months',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kOnSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: widget.group.durationMonths,
                  itemBuilder: (context, i) {
                    if (i < _members.length) {
                      final m = _members[i];
                      final isHost = m.isHostMember ||
                          m.name.toLowerCase().contains('foreman') ||
                          m.name.toLowerCase() == _foremanName.toLowerCase();
                      final isYou =
                          m.name.toLowerCase() == widget.currentUsername.toLowerCase();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isYou
                              ? _kSecondaryContainer.withOpacity(0.35)
                              : _kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: isYou
                              ? Border.all(color: _kSecondaryAccent.withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isHost
                                  ? _kPrimaryContainer
                                  : isYou
                                      ? _kSecondary
                                      : _kSurfaceContainerHighest,
                              foregroundColor: (isHost || isYou)
                                  ? Colors.white
                                  : _kOnSurface,
                              child: Text(
                                m.name.isNotEmpty
                                    ? m.name.substring(0, 1).toUpperCase()
                                    : 'M',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          m.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isYou
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 14,
                                            color: _kOnSurface,
                                          ),
                                        ),
                                      ),
                                      if (m.memberUsername.isNotEmpty &&
                                          m.memberUsername.toLowerCase() !=
                                              m.name.toLowerCase()) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(@${m.memberUsername})',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _kOnSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      if (isHost)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kPrimaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'HOST',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      if (isYou)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kSecondary,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    isHost
                                        ? 'Gold Tier Host • Payout Month 2'
                                        : 'Payout: Month ${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isYou ? _kSecondary : _kOnSurfaceVariant,
                                    ),
                                  ),
                                  Builder(builder: (_) {
                                    final mDep = _rosterDeposits[m.memberUsername] ??
                                        _rosterDeposits[m.id] ??
                                        _rosterDeposits.values
                                            .where((d) =>
                                                m.memberUsername.isNotEmpty &&
                                                d.memberId.toLowerCase() ==
                                                    m.memberUsername
                                                        .toLowerCase())
                                            .firstOrNull;
                                    final mDepStatus =
                                        mDep?.displayStatus ?? 'Pending';
                                    final mDepAmt = mDep?.amount ?? _depositAmount;
                                    return Text(
                                      'Deposit: ${_formatCurrency(mDepAmt)} ($mDepStatus)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: mDepStatus == 'Recorded'
                                            ? const Color(0xFF16A34A)
                                            : (mDepStatus == 'Refunded'
                                                ? const Color(0xFF2563EB)
                                                : (mDepStatus == 'Forfeited'
                                                    ? const Color(0xFFDC2626)
                                                    : const Color(0xFFD97706))),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            if (i < widget.group.currentCycle - 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _kSecondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Prized',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _kSecondary,
                                  ),
                                ),
                              )
                            else if (i == widget.group.currentCycle - 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _kAmberBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Upcoming',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _kAmberText,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _kOnSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      );
                    } else {
                      // Open Slot
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _kSurfaceContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _kBorder,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _kSurfaceContainer,
                              child: const Icon(
                                Icons.person_add_rounded,
                                size: 18,
                                color: _kOnSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Slot #${i + 1}: Invite Pending',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _kOnSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Share 6-digit code: ${widget.group.inviteCode}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _kOnSurfaceVariant.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Open',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kOnSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Privacy protected: Personal risk ratings are private',
                    style: TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryContainer,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kSurface,
        appBar: AppBar(
          backgroundColor: _kSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _kOnSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _kSecondaryAccent),
        ),
      );
    }

    final double installmentAmount = widget.group.monthlyContribution;
    final int openSlots =
        (widget.group.durationMonths - _members.length).clamp(0, widget.group.durationMonths);

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _kOnSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kOnSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.group.name} • Verified Chit',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _kSecondary,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _kOnSurfaceVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'terms') {
                _openDigitalAgreement();
              } else if (val == 'info') {
                _openGroupInfoSheet();
              } else if (val == 'report') {
                _openReportProblemModal();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'terms',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, size: 18, color: _kOnSurfaceVariant),
                    SizedBox(width: 10),
                    Text('My terms (Agreement)', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: _kOnSurfaceVariant),
                    SizedBox(width: 10),
                    Text('Group info', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report_problem_outlined, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Text(
                      'Report a problem',
                      style: TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _kSecondaryContainer,
              foregroundColor: _kSecondary,
              child: Text(
                widget.currentUsername.isNotEmpty
                    ? widget.currentUsername.substring(0, 1).toUpperCase()
                    : 'U',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Context Tag
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: _kSecondaryAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ACTIVE CHIT GROUP • MONTH ${widget.group.currentCycle}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _kSecondary,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _kSurfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Chit ID: #${widget.group.inviteCode.isNotEmpty ? widget.group.inviteCode : widget.group.id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _kOnSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 3-Second Instant Clarity Hero Status Card
                      _buildHeroStatusCard(installmentAmount),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              // Sticky Tab Navigation
              SliverAppBar(
                pinned: true,
                floating: false,
                primary: false,
                automaticallyImplyLeading: false,
                backgroundColor: _kSurface,
                elevation: 0,
                toolbarHeight: 0,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: _kPrimaryContainer,
                  indicatorWeight: 3,
                  labelColor: _kPrimaryContainer,
                  unselectedLabelColor: _kOnSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.dashboard_rounded, size: 18),
                      text: 'Overview',
                    ),
                    Tab(
                      icon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gavel_rounded, size: 18),
                          SizedBox(width: 4),
                          CircleAvatar(radius: 3, backgroundColor: _kSecondaryAccent),
                        ],
                      ),
                      text: 'Auction',
                    ),
                    Tab(
                      icon: Icon(Icons.menu_book_rounded, size: 18),
                      text: 'Ledger',
                    ),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(openSlots),
                _buildAuctionTab(),
                _buildLedgerTab(),
              ],
            ),
          ),
        ),
          // Persistent Floating Bottom Bar
          if (!_isPaidCurrentCycle)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPersistentBottomBar(installmentAmount),
            ),
        ],
      ),
    );
  }

  // ==================== HERO STATUS CARD ====================
  Widget _buildHeroStatusCard(double installmentAmount) {
    final int currentStep = widget.group.currentCycle;
    final int totalSteps = widget.group.durationMonths;
    final int percentComplete = ((currentStep / totalSteps) * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kPrimaryContainer.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stepper: Cycle X of Y
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timelapse_rounded, size: 16, color: _kSecondaryAccent),
                  const SizedBox(width: 6),
                  Text(
                    'Cycle $currentStep of $totalSteps',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _kOnSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kSecondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$percentComplete% Complete',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _kSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 10 Step Progress Bar
          Row(
            children: List.generate(totalSteps, (index) {
              final stepNum = index + 1;
              final bool isCompleted = stepNum < currentStep;
              final bool isActive = stepNum == currentStep;

              return Expanded(
                child: Container(
                  height: 7,
                  margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? _kSecondaryAccent
                        : isActive
                            ? _kSecondary
                            : _kSurfaceContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: isActive
                        ? Border.all(color: _kSecondaryAccent, width: 1.5)
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          // Financials Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Installment Due',
                          style: TextStyle(fontSize: 12, color: _kOnSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${NumberFormat('#,##,###').format(installmentAmount.toInt())}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _kOnSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _isPaidCurrentCycle
                                    ? _kSecondaryContainer
                                    : _kAmberBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isPaidCurrentCycle ? 'Paid' : '3 days left',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _isPaidCurrentCycle
                                      ? _kSecondary
                                      : _kAmberText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Due by 10th of this month',
                          style: TextStyle(
                            fontSize: 11,
                            color: _kOnSurfaceVariant.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      color: _kOnSurfaceVariant,
                      onPressed: () => _openReceiptDrawer('preview-due'),
                      tooltip: 'View breakdown',
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFCBD5E1)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Assigned Payout',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kOnSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Month ${_getUserPayoutMonth()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _kOnSurface,
                            ),
                          ),
                          Text(
                            '₹${NumberFormat('#,##,###').format(widget.group.totalPoolSize.toInt())} pot value',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security Deposit',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kOnSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatCurrency(_depositAmount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _kOnSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _mySecurityDeposit?.isHeld == true
                                    ? Icons.verified_user_rounded
                                    : Icons.info_outline_rounded,
                                size: 14,
                                color: _kSecondaryAccent,
                              ),
                            ],
                          ),
                          Text(
                            _mySecurityDeposit?.isHeld == true
                                ? 'Deposit recorded'
                                : 'Pending Deposit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _mySecurityDeposit?.isHeld == true
                                  ? _kSecondary
                                  : _kAmberText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action Buttons
          if (!_isPaidCurrentCycle) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openInstallmentCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimaryContainer,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                label: Text(
                  'Pay ₹${NumberFormat('#,##,###').format(installmentAmount.toInt())} Installment',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _kSecondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: _kSecondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Paid for Month ${widget.group.currentCycle}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _kSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_mySecurityDeposit?.isHeld != true) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _openDepositCheckoutModal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kPrimaryContainer,
                  side: const BorderSide(color: _kPrimaryContainer, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: Text(
                  'Pay Security Deposit (${_formatCurrency(_depositAmount)})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_outlined, size: 12, color: _kSecondaryAccent),
                SizedBox(width: 4),
                Text(
                  'Prototype, no real money',
                  style: TextStyle(fontSize: 10, color: _kOnSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: OVERVIEW ====================
  Widget _buildOverviewTab(int openSlots) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // 1. Members Joined Summary Card (Clickable)
          InkWell(
            onTap: _openMemberListModal,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _kOnSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _kSecondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_members.length} of ${widget.group.durationMonths} Joined',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _kSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _kSecondary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: _kSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Avatar stack
                      Row(
                        children: [
                          for (int i = 0; i < (_members.length > 4 ? 4 : _members.length); i++)
                            Align(
                              widthFactor: 0.75,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: i == 0
                                      ? _kPrimaryContainer
                                      : i == 1
                                          ? _kSecondary
                                          : _kSurfaceContainerHighest,
                                  foregroundColor: i < 2 ? Colors.white : _kOnSurface,
                                  child: Text(
                                    _members[i].name.isNotEmpty
                                        ? _members[i].name.substring(0, 1).toUpperCase()
                                        : 'M',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_members.length > 4)
                            Align(
                              widthFactor: 0.75,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: _kSecondaryContainer,
                                  child: Text(
                                    '+${_members.length - 4}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _kSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _kSurfaceContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_add_rounded,
                              size: 14,
                              color: _kSecondaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$openSlots open slots',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _kOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Cycle Collection Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cycle ${widget.group.currentCycle} Collection',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kOnSurface,
                      ),
                    ),
                    Text(
                      '₹${NumberFormat('#,##,###').format((_members.length * widget.group.monthlyContribution * 0.7).toInt())} / ₹${NumberFormat('#,##,###').format(widget.group.totalPoolSize.toInt())}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _kSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.70,
                    minHeight: 8,
                    backgroundColor: _kSurfaceContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(_kSecondaryAccent),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(_members.length * 0.7).ceil()} of ${_members.length} active members paid',
                      style: const TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                    ),
                    const Text(
                      '1 payment processing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kAmberText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Payout Timeline (Horizontal Strip)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payout Timeline',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _kOnSurface,
                          ),
                        ),
                        Text(
                          'Rotating payout allocation schedule',
                          style: TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.calendar_view_week_rounded,
                      size: 20,
                      color: _kSecondaryAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 104,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.group.durationMonths,
                    itemBuilder: (context, idx) {
                      final monthNum = idx + 1;
                      final isCurrent = monthNum == widget.group.currentCycle;
                      final isYou = monthNum == _getUserPayoutMonth();
                      final isPast = monthNum < widget.group.currentCycle;

                      return Container(
                        width: isYou ? 124 : 106,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isYou
                              ? _kPrimaryContainer
                              : isCurrent
                                  ? _kSecondaryContainer.withOpacity(0.4)
                                  : _kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: isCurrent
                              ? Border.all(color: _kSecondaryAccent, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Month $monthNum',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isYou ? Colors.white : _kOnSurface,
                                  ),
                                ),
                                if (isYou) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _kSecondaryAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isYou
                                  ? Colors.white.withOpacity(0.2)
                                  : _kSurfaceContainer,
                              child: Text(
                                isPast
                                    ? '✓'
                                    : isYou
                                        ? widget.currentUsername.substring(0, 1).toUpperCase()
                                        : 'M$monthNum',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isYou ? Colors.white : _kOnSurface,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPast
                                  ? 'Disbursed'
                                  : isCurrent
                                      ? 'Active Due'
                                      : '₹${NumberFormat('#,##,###').format(widget.group.totalPoolSize.toInt())}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isYou
                                    ? _kSecondaryContainer
                                    : isCurrent
                                        ? _kSecondary
                                        : _kOnSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Host Trust & Security Deposit Guarantee Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _kPrimaryContainer,
                      foregroundColor: Colors.white,
                      child: Text(
                        _foremanName.isNotEmpty
                            ? _foremanName.substring(0, 1).toUpperCase()
                            : 'F',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _foremanName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: _kOnSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _kSecondaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 11,
                                      color: _kSecondary,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      'Gold Host',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _kSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Foreman & Community Organizer',
                            style: TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildMetricRow(
                        Icons.star_rounded,
                        const Color(0xFFF59E0B),
                        'Host Rating',
                        '4.9★ (14 successful groups)',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        Icons.security_rounded,
                        _kSecondaryAccent,
                        'Foreman Security Bond',
                        '₹50,000 Deposited',
                      ),
                      const SizedBox(height: 8),
                      _buildMetricRow(
                        Icons.history_rounded,
                        _kOnSurfaceVariant,
                        'Default Rate',
                        '0.0% historic defaults',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. My Reputation Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kSecondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: _kSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elite Member',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _kOnSurface,
                        ),
                      ),
                      Text(
                        '100% on-time record across chit groups',
                        style: TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: _kSecondaryAccent,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, Color iconColor, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: _kOnSurfaceVariant)),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _kOnSurface,
          ),
        ),
      ],
    );
  }

  // ==================== TAB 2: AUCTION ====================
  Widget _buildAuctionTab() {
    final double maxCap = widget.group.totalPoolSize * 0.20;
    final double minDividend = maxCap / widget.group.durationMonths;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // Live Auction Schedule Countdown Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kPrimaryContainer, Color(0xFF1A365D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _kPrimaryContainer.withOpacity(0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.sensors_rounded, size: 16, color: Color(0xFF89F5E7)),
                        SizedBox(width: 4),
                        Text(
                          'CYCLE 3 AUCTION WINDOW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF89F5E7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '100% Online',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '1st of next month, 7:00 PM',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Bidding opens for all non-prized members',
                  style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                ),
                const SizedBox(height: 14),
                // 4 Countdown Boxes
                Row(
                  children: [
                    _buildCountdownBox('$_countdownDays', 'DAYS'),
                    const SizedBox(width: 6),
                    _buildCountdownBox(
                      _countdownHours < 10 ? '0$_countdownHours' : '$_countdownHours',
                      'HOURS',
                    ),
                    const SizedBox(width: 6),
                    _buildCountdownBox(
                      '${(_countdownSeconds ~/ 60) < 10 ? '0' : ''}${_countdownSeconds ~/ 60}',
                      'MINS',
                    ),
                    const SizedBox(width: 6),
                    _buildCountdownBox(
                      '${(_countdownSeconds % 60) < 10 ? '0' : ''}${_countdownSeconds % 60}',
                      'SECS',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Statutory Chit Act Caps & Dividends Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auction Rules & Safeguards',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _kOnSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Max Discount Cap',
                              style: TextStyle(
                                fontSize: 11,
                                color: _kOnSurfaceVariant,
                              ),
                            ),
                            Text(
                              '₹${NumberFormat('#,##,###').format(maxCap.toInt())}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _kOnSurface,
                              ),
                            ),
                            const Text(
                              '20% Legal Ceiling',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _kSecondary,
                              ),
                            ),
                            Text(
                              'As per Chit Funds Act',
                              style: TextStyle(
                                fontSize: 9,
                                color: _kOnSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Minimum Dividend',
                              style: TextStyle(
                                fontSize: 11,
                                color: _kOnSurfaceVariant,
                              ),
                            ),
                            Text(
                              '₹${NumberFormat('#,##,###').format(minDividend.toInt())}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _kSecondary,
                              ),
                            ),
                            const Text(
                              'Per non-bidder',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _kSecondary,
                              ),
                            ),
                            Text(
                              'Reduces next due',
                              style: TextStyle(
                                fontSize: 9,
                                color: _kOnSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSecondaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: _kSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are scheduled for payout in Month ${_getUserPayoutMonth()}. Bidding early will forfeit your priority allocation for month ${_getUserPayoutMonth()}.',
                          style: const TextStyle(fontSize: 11, color: _kOnSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Past Auction (Cycle 2) Result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Past Auction (Cycle ${widget.group.currentCycle > 1 ? widget.group.currentCycle - 1 : 1})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kOnSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kSurfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '14 Oct 2025',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _kOnSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Winning Bid Discount',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kOnSurfaceVariant,
                            ),
                          ),
                          Text(
                            '₹14,500',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _kOnSurface,
                            ),
                          ),
                          Text(
                            'Winner: Prized Member',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            'Dividend Earned By You',
                            style: TextStyle(
                              fontSize: 11,
                              color: _kOnSurfaceVariant,
                            ),
                          ),
                          Text(
                            '+₹1,611',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _kSecondary,
                            ),
                          ),
                          Text(
                            'Deducted from Oct due',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _kSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Auction Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveBiddingRoom(
                      group: widget.group,
                      currentUsername: widget.currentUsername,
                      isForeman: widget.isForeman,
                      isApproved: true,
                      onAuctionEnded: () {
                        _loadGroupMembers();
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kSecondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: const Text(
                'Enter Live Auction Room',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Auction event synced to your calendar reminder.'),
                  backgroundColor: Color(0xFF0F4C81),
                ),
              );
            },
            icon: const Icon(Icons.event_rounded, size: 16, color: _kSecondary),
            label: const Text(
              'Add to Google Calendar reminder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _kSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String val, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 3: LEDGER ====================
  Widget _buildLedgerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // Passbook Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Member Passbook',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kOnSurface,
                      ),
                    ),
                    Text(
                      'Digitally timestamped dual-party ledger',
                      style: TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Downloading digitally signed passbook PDF...'),
                        backgroundColor: Color(0xFF0F4C81),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kSurfaceContainer,
                    foregroundColor: _kOnSurface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text(
                    'Export',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Passbook Entry: Current Due
          _buildPassbookCard(
            title: 'Installment #${widget.group.currentCycle} (${DateFormat('MMM').format(DateTime.now())})',
            dateSubtitle: _isPaidCurrentCycle
                ? 'Paid ${DateFormat('dd MMM yyyy').format(DateTime.now())}'
                : 'Due by 10th of this month',
            amount:
                '₹${NumberFormat('#,##,###').format(widget.group.monthlyContribution.toInt())}',
            badgeText: _isPaidCurrentCycle ? 'Confirmed' : 'Due in 3 days',
            isConfirmed: _isPaidCurrentCycle,
            subLeft: _isPaidCurrentCycle ? 'Verified UPI Transfer' : 'Standard installment',
            subRight: _isPaidCurrentCycle ? 'UTR: Verified • View receipt →' : 'Tap to view break-up →',
            onTap: () => _openReceiptDrawer('preview-due'),
          ),
          const SizedBox(height: 8),

          // Passbook Entry: Previous Month Installment
          _buildPassbookCard(
            title: 'Installment #${widget.group.currentCycle > 1 ? widget.group.currentCycle - 1 : 1} (Oct)',
            dateSubtitle: 'Paid 14 Oct 2025',
            amount:
                '₹${NumberFormat('#,##,###').format((widget.group.monthlyContribution * 0.85).toInt())}',
            badgeText: 'Confirmed',
            isConfirmed: true,
            subLeft: 'Saved ₹1,450 dividend discount',
            subRight: 'UPI • UTR: #SC849102834',
            onTap: () => _openReceiptDrawer('m2-oct'),
          ),
          const SizedBox(height: 8),

          // Passbook Entry: Installment #1
          _buildPassbookCard(
            title: 'Installment #1 (Sep)',
            dateSubtitle: 'Paid 12 Sep 2025',
            amount:
                '₹${NumberFormat('#,##,###').format((widget.group.monthlyContribution * 0.83).toInt())}',
            badgeText: 'Confirmed',
            isConfirmed: true,
            subLeft: 'Saved ₹1,611 dividend discount',
            subRight: 'UPI • UTR: #SC710294821',
            onTap: () => _openReceiptDrawer('m1-sep'),
          ),
          const SizedBox(height: 8),

          // Passbook Entry: Security Deposit
          _buildPassbookCard(
            title: 'Initial Security Deposit',
            dateSubtitle: 'Paid 10 Sep 2025',
            amount: _formatCurrency(_depositAmount),
            badgeText: _mySecurityDeposit?.isHeld == true ? 'Deposit recorded' : 'Pending',
            isConfirmed: _mySecurityDeposit?.isHeld == true,
            subLeft: '100% Refundable at cycle close',
            subRight: 'Autopay • UTR: #SC102938472',
            icon: Icons.shield_rounded,
            onTap: () => _openReceiptDrawer('sec-dep'),
          ),
        ],
      ),
    );
  }

  Widget _buildPassbookCard({
    required String title,
    required String dateSubtitle,
    required String amount,
    required String badgeText,
    required bool isConfirmed,
    required String subLeft,
    required String subRight,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: isConfirmed
                          ? _kSecondaryContainer
                          : _kAmberBg,
                      child: Icon(
                        icon ??
                            (isConfirmed
                                ? Icons.check_rounded
                                : Icons.pending_rounded),
                        size: 18,
                        color: isConfirmed ? _kSecondary : _kAmberText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _kOnSurface,
                          ),
                        ),
                        Text(
                          dateSubtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _kOnSurface,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isConfirmed
                            ? _kSecondaryContainer
                            : _kAmberBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isConfirmed ? _kSecondary : _kAmberText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subLeft,
                    style: TextStyle(
                      fontSize: 11,
                      color: isConfirmed ? _kSecondary : _kOnSurfaceVariant,
                      fontWeight: isConfirmed ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subRight,
                    style: const TextStyle(fontSize: 10, color: _kOnSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== PERSISTENT FLOATING BOTTOM ACTION BAR ====================
  Widget _buildPersistentBottomBar(double installmentAmount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: _kPrimaryContainer.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '₹${NumberFormat('#,##,###').format(installmentAmount.toInt())}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kOnSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kAmberBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '3 days left',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _kAmberText,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Cycle ${widget.group.currentCycle} Installment Due',
                  style: const TextStyle(fontSize: 11, color: _kOnSurfaceVariant),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openInstallmentCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kSecondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Text(
                'Pay now',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
