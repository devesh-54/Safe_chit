import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import 'digital_agreement_modal.dart';
import '../../features/bidding/bidding_session_service.dart';
import '../../features/bidding/host_schedule_screen.dart';
import '../../features/bidding/bidding_waiting_room.dart';
import '../../features/bidding/live_bidding_room.dart';
import '../../features/bidding/auction_close_payout.dart';
import '../../widgets/youpi_payment_modal.dart';
import '../../models/chit_payment_record.dart';
import '../../models/security_deposit.dart';
import '../../core/config/deposit_config.dart';
import '../../widgets/razorpay_checkout_modal.dart';
import '../profile/user_profile_screen.dart';

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
  List<ChitPaymentRecord> _groupPayments = [];
  String _rosterFilter = 'All'; // 'All', 'Paid', 'Unpaid'
  bool _isLoading = true;
  StreamSubscription<String>? _biddingStatusSub;

  double get _depositAmount {
    if (widget.group.securityDeposit > 0) {
      return widget.group.securityDeposit;
    }
    return widget.group.monthlyContribution * kDefaultDepositPercentOfInstallment;
  }

  void _openDepositCheckoutModal() {
    RazorpayCheckoutModal.show(
      context: context,
      groupId: widget.group.id,
      groupName: widget.group.name,
      memberId: widget.currentUsername,
      amount: _depositAmount,
      onDepositSuccess: () {
        _loadGroupMembers();
      },
    );
  }

  // Bidding & Draw simulation state
  final TextEditingController _bidController = TextEditingController();
  double _currentWinningBid = 50000.0; // default ₹50k discount
  String _currentWinningBidder = 'Ramesh Verma';
  bool _isBiddingActive = true;
  String? _luckyDrawWinner;

  // User ledger payments list (Member Dashboard view)
  List<Map<String, dynamic>> _userPayments = [];

  // Ledger history mock state
  final List<Map<String, dynamic>> _ledgerHistory = [
    {
      'cycle': 1,
      'date': '01 Aug 2026',
      'winner': 'Ramesh Verma',
      'winningDiscount': 50000.0,
      'payoutAmount': 950000.0,
      'dividendPerMember': 5000.0,
      'status': 'Paid & Distributed',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadGroupMembers();

    _biddingStatusSub = BiddingSessionService.instance.statusStream.listen((
      groupId,
    ) {
      if (!mounted) return;
      if (groupId == widget.group.id) {
        setState(() {});
      }
    });

    BiddingSessionService.instance.startSync(widget.group.id);

    _userPayments = [
      {
        'cycle': 1,
        'amount': widget.group.monthlyContribution,
        'date': '10 Aug 2026, 02:30 PM',
        'foremanConfirmed': '10 Aug 2026, 03:00 PM',
        'memberConfirmed': '10 Aug 2026, 02:35 PM',
        'status': 'Confirmed by both parties',
      },
      {
        'cycle': 2,
        'amount': widget.group.monthlyContribution,
        'date': '10 Sep 2026, 11:15 AM',
        'foremanConfirmed': '10 Sep 2026, 11:45 AM',
        'memberConfirmed': '10 Sep 2026, 11:20 AM',
        'status': 'Confirmed by both parties',
      },
    ];
  }

  @override
  void dispose() {
    _biddingStatusSub?.cancel();
    BiddingSessionService.instance.stopSync(widget.group.id);
    _tabController.dispose();
    _bidController.dispose();
    super.dispose();
  }

  void _handlePayoutReleased() {
    final state = BiddingSessionService.instance.getOrCreateState(
      widget.group.id,
    );
    final winner = state.currentHighestBidder;
    final winningBid = state.currentHighestBid;
    final payoutAmount = widget.group.totalPoolSize - winningBid;
    final dividend =
        winningBid /
        (widget.group.membersCount > 0 ? widget.group.membersCount : 10);
    final ref = state.txnRef ?? 'TXN849102IND';

    setState(() {
      _userPayments.insert(0, {
        'cycle': widget.group.currentCycle,
        'amount': payoutAmount,
        'date': DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now()),
        'foremanConfirmed': DateFormat(
          'd MMM yyyy, hh:mm a',
        ).format(DateTime.now()),
        'memberConfirmed': DateFormat(
          'd MMM yyyy, hh:mm a',
        ).format(DateTime.now()),
        'status': 'Payout Released • Ref: $ref',
      });

      _ledgerHistory.insert(0, {
        'cycle': widget.group.currentCycle,
        'date': DateFormat('d MMM yyyy').format(DateTime.now()),
        'winner': winner,
        'winningDiscount': winningBid,
        'payoutAmount': payoutAmount,
        'dividendPerMember': dividend,
        'status': 'Payout Released',
      });
    });
  }

  void _loadGroupMembers() async {
    setState(() => _isLoading = true);
    final members = await SupabaseService.getGroupMembers(widget.group.id);
    final deposits =
        await SupabaseService.getGroupSecurityDeposits(widget.group.id);
    final payments =
        await SupabaseService.getGroupPayments(widget.group.id);
    final myDep = deposits[widget.currentUsername] ??
        await SupabaseService.getSecurityDeposit(
          groupId: widget.group.id,
          memberId: widget.currentUsername,
        );
    if (mounted) {
      setState(() {
        _members = members;
        _rosterDeposits = deposits;
        _groupPayments = payments;
        _mySecurityDeposit = myDep;
        _isLoading = false;
      });
    }
  }

  void _submitAuctionBid() {
    final bidVal = double.tryParse(_bidController.text.trim());
    final maxCap =
        widget.group.totalPoolSize *
        0.30; // 30% max cap per Chit Funds Act 1982

    if (bidVal == null || bidVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bid discount amount (₹).'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (bidVal > maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bid discount exceeds 30% legal cap (Max ₹${maxCap.toStringAsFixed(0)}).',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (bidVal <= _currentWinningBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bid must be higher than current top discount ₹${_currentWinningBid.toStringAsFixed(0)}.',
          ),
          backgroundColor: const Color(0xFF0F4C81),
        ),
      );
      return;
    }

    setState(() {
      _currentWinningBid = bidVal;
      _currentWinningBidder = widget.currentUsername;
    });

    _bidController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎉 New Winning Bid: ₹${bidVal.toStringAsFixed(0)} discount by $widget.currentUsername!',
        ),
        backgroundColor: const Color(0xFF007A87),
      ),
    );
  }

  void _runRandomPickingDraw() {
    final hostMember = _members.where((m) => m.isHostMember).firstOrNull;

    // Requirement 4: If Cycle 2 and host member exists, skip draw and award full pot to host with 0 discount
    if (widget.group.currentCycle == 2 && hostMember != null) {
      _recordCycle2HostPayout(widget.group, hostMember.name);
      return;
    }

    // In every other cycle: exclude host member from random draw eligibility
    final eligibleMembers = _members.where((m) => !m.isHostMember).toList();
    if (eligibleMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No eligible members available for draw.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final rand = Random();
    final winnerIndex = rand.nextInt(eligibleMembers.length);
    final winner = eligibleMembers[winnerIndex].name;

    setState(() {
      _luckyDrawWinner = winner;
      _ledgerHistory.insert(0, {
        'cycle': widget.group.currentCycle,
        'date': DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now()),
        'winner': winner,
        'winningDiscount': 0.0,
        'payoutAmount': widget.group.totalPoolSize,
        'dividendPerMember': 0.0,
        'status': 'Random Pick Winner',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🎲 Lucky Draw Winner Selected: $winner! Payout: ₹${widget.group.totalPoolSize.toStringAsFixed(0)}',
        ),
        backgroundColor: const Color(0xFF007A87),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _recordCycle2HostPayout(ChitGroup g, String hostMemberName) {
    setState(() {
      _luckyDrawWinner = '$hostMemberName (Host)';
      _ledgerHistory.insert(0, {
        'cycle': 2,
        'date': DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now()),
        'winner': '$hostMemberName (Host)',
        'winningDiscount': 0.0,
        'payoutAmount': g.totalPoolSize,
        'dividendPerMember': 0.0,
        'status': 'Host payout (self)',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Month 2 Host Payout Recorded: ₹${g.totalPoolSize.toStringAsFixed(0)} with no discount.',
        ),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _makeMonthlyPayment() {
    YoupiPaymentModal.show(
      context: context,
      group: widget.group,
      currentUsername: widget.currentUsername,
      onPaymentSuccess: () {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Monthly installment verified and recorded in SafeChit ledger!',
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 4),
          ),
        );
      },
    );
  }

  void _openDigitalAgreement() async {
    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: widget.group.name,
      foremanName: widget.isForeman ? 'Rajesh Kumar (Foreman)' : 'Foreman Host',
      memberName: widget.isForeman
          ? 'Subscriber Member'
          : widget.currentUsername,
      poolAmount: widget.group.totalPoolSize,
      durationMonths: widget.group.durationMonths,
      monthlyContribution: widget.group.monthlyContribution,
      schemeType: widget.group.schemeType,
      securityDeposit: widget.group.securityDeposit,
    );

    var agreement = await SupabaseService.getDigitalAgreement(
      groupId: widget.group.id,
      memberUsername: widget.currentUsername,
    );

    agreement ??= DigitalAgreement(
      id: 'agreement_${widget.group.id}',
      groupId: widget.group.id,
      groupName: widget.group.name,
      foremanUsername: 'foreman_admin',
      foremanName: 'Rajesh Kumar (Foreman)',
      memberUsername: widget.currentUsername,
      memberName: widget.currentUsername,
      poolAmount: widget.group.totalPoolSize,
      durationMonths: widget.group.durationMonths,
      monthlyContribution: widget.group.monthlyContribution,
      schemeType: widget.group.schemeType,
      agreementText: agreementText,
      createdAt: DateTime.now(),
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => DigitalAgreementModal(
          agreement: agreement!,
          isForeman: widget.isForeman,
          onSigned: () {
            _loadGroupMembers();
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final progressPct = (g.currentCycle / g.durationMonths).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          g.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: widget.isForeman
              ? _buildForemanDashboard(g, progressPct)
              : _buildMemberDashboard(g),
        ),
      ),
    );
  }

  Widget _buildForemanDashboard(ChitGroup g, double progressPct) {
    final int pendingHandshakeCount =
        _groupPayments.where((p) => p.isPending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Code: ${g.inviteCode} • ${g.city} • ${g.schemeType} Scheme',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF007A87),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_members.any((m) => m.isHostMember)) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF166534),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The host receives the month 2 payout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Tab Bar: 1. Auction/Draw | 2. Member Roster & Dues | 3. Handshakes | 4. Payout Ledger
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F4C81),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF0F4C81),
          indicatorWeight: 3,
          isScrollable: true,
          tabs: [
            Tab(
              icon: Icon(
                g.schemeType == 'Bidding'
                    ? Icons.gavel_rounded
                    : Icons.casino_rounded,
                size: 18,
              ),
              text: g.schemeType == 'Bidding'
                  ? 'Monthly Auction'
                  : 'Random Draw',
            ),
            const Tab(
              icon: Icon(Icons.people_alt_rounded, size: 18),
              text: 'Member Roster & Dues',
            ),
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.handshake_outlined, size: 18),
                  if (pendingHandshakeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingHandshakeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              text: pendingHandshakeCount > 0
                  ? 'Handshakes ($pendingHandshakeCount)'
                  : 'Handshake Confirmations',
            ),
            const Tab(
              icon: Icon(Icons.receipt_long_rounded, size: 18),
              text: 'Payout Ledger',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tab Views Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSchemeAuctionTab(g, progressPct),
              _buildMemberRosterTab(),
              _buildHandshakeConfirmationsTab(),
              _buildPayoutLedgerTab(g),
            ],
          ),
        ),
      ],
    );
  }

  // --- MEMBER PERSPECTIVE: 5-SECTION DASHBOARD ---
  Widget _buildMemberDashboard(ChitGroup g) {
    final String payoutTurnLabel = "Your turn: Month 9";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Code: ${g.inviteCode} • ${g.city} • ${g.schemeType} Scheme',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF007A87),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (_members.any((m) => m.isHostMember)) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF166534),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The host receives the month 2 payout',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        // SECURITY DEPOSIT STATUS SECTION
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _mySecurityDeposit?.isHeld == true
                ? const Color(0xFFF0FDF4)
                : (_mySecurityDeposit?.isForfeited == true
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFEF3C7)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _mySecurityDeposit?.isHeld == true
                  ? const Color(0xFFBBF7D0)
                  : (_mySecurityDeposit?.isForfeited == true
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFFDE68A)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: _mySecurityDeposit?.isHeld == true
                            ? const Color(0xFF166534)
                            : const Color(0xFF92400E),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Security Deposit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Test mode, no real money',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount: ₹${_depositAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text(
                            'Status: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            _mySecurityDeposit?.displayStatus ?? 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _mySecurityDeposit?.isHeld == true
                                  ? const Color(0xFF166534)
                                  : (_mySecurityDeposit?.isRefunded == true
                                      ? const Color(0xFF0284C7)
                                      : (_mySecurityDeposit?.isForfeited == true
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFD97706))),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_mySecurityDeposit == null || _mySecurityDeposit!.isPending)
                    ElevatedButton.icon(
                      onPressed: _openDepositCheckoutModal,
                      icon: const Icon(Icons.payment_rounded, size: 14),
                      label: const Text('Pay security deposit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F4C81),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _mySecurityDeposit!.isHeld
                            ? const Color(0xFFDCFCE7)
                            : (_mySecurityDeposit!.isRefunded
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _mySecurityDeposit!.isHeld
                            ? 'Deposit Held'
                            : _mySecurityDeposit!.displayStatus,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _mySecurityDeposit!.isHeld
                              ? const Color(0xFF166534)
                              : (_mySecurityDeposit!.isRefunded
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFFDC2626)),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // TOP SECTION — Status Card (always visible, no scroll)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F4C81),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Cycle ${g.currentCycle} of ${g.durationMonths}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 10,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Trusted Member',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEXT CONTRIBUTION',
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          g.monthlyContribution < 10
                              ? '₹${g.monthlyContribution.toStringAsFixed(2)}'
                              : '₹${g.monthlyContribution.toStringAsFixed(0)}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Due: 10th of this Month',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          payoutTurnLabel,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _openRazorpayCardCheckout(g.monthlyContribution),
                          icon: const Icon(Icons.payment_rounded, size: 14),
                          label: const Text(
                            'Pay with Razorpay (Test)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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

        // SCROLLABLE BODY
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ACTIVE BIDDING / DRAW INTERACTIVE TERMINAL
                _buildMemberAuctionBidPanel(g),
                const SizedBox(height: 14),

                // SECOND SECTION — This Cycle
                _buildMemberCycleProgress(g),
                const SizedBox(height: 14),

                // THIRD SECTION — Timeline / Ledger
                _buildMemberLedgerTimeline(g),
                const SizedBox(height: 14),

                // FOURTH SECTION — Group & Foreman Info
                _buildMemberForemanInfo(g),
                const SizedBox(height: 14),

                // FIFTH SECTION — My Reputation
                _buildMemberReputationDetails(g),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAuctionBidPanel(ChitGroup g) {
    final hostMember = _members.where((m) => m.isHostMember).firstOrNull;
    if (g.currentCycle == 2 && hostMember != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF166534),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Month 2: Fixed Host Payout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'The organizer (${hostMember.name}) receives the Month 2 full pot payout with 0% discount per scheme rules. No auction or lucky draw is held.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final bidState = BiddingSessionService.instance.getOrCreateState(g.id);

    if (g.schemeType == 'Bidding') {
      if (bidState.scheduledStartTime == null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF0F4C81), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No bidding session has been scheduled by the Foreman for this cycle yet.',
                  style: TextStyle(color: Color(0xFF475569), fontSize: 12),
                ),
              ),
            ],
          ),
        );
      } else if (bidState.scheduledStartTime != null &&
          !bidState.isAuctionActive &&
          !bidState.isAuctionEnded) {
        return BiddingWaitingRoom(
          groupId: g.id,
          scheduledTime: bidState.scheduledStartTime!,
          onTimerExpired: () {
            setState(() {});
          },
        );
      } else if (bidState.isAuctionActive && !bidState.isAuctionEnded) {
        return Container(
          height: 380, // Bound height inside details column
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LiveBiddingRoom(
            group: g,
            currentUsername: widget.currentUsername,
            isForeman: false,
            isApproved: widget.isApproved,
            onAuctionEnded: () {
              setState(() {});
            },
          ),
        );
      } else {
        // Auction Concluded
        return AuctionClosePayout(
          group: g,
          currentUsername: widget.currentUsername,
          isForeman: false,
          onPayoutReleased: _handlePayoutReleased,
        );
      }
    } else {
      // Random Draw System
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF007A87).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
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
                const Expanded(
                  child: Text(
                    'LUCKY DRAW DRAW STATUS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F4C81),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Draw Eligible',
                    style: TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_luckyDrawWinner != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Color(0xFF166534), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LUCKY DRAW WINNER SELECTED!',
                            style: TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Winner: $_luckyDrawWinner',
                            style: const TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Draw will be conducted by Foreman Rajesh Kumar at the end of the current cycle. Keep an eye on updates!',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildMemberCycleProgress(ChitGroup g) {
    final pastWinners = [
      {'name': 'Ramesh Verma', 'initials': 'RV'},
      {'name': 'Suresh Kumar', 'initials': 'SK'},
      {'name': 'Meena Sharma', 'initials': 'MS'},
    ];

    final collectedAmount =
        g.monthlyContribution * (g.membersCount > 0 ? g.membersCount - 1 : 9);
    final targetAmount =
        g.monthlyContribution * (g.membersCount > 0 ? g.membersCount : 10);
    final progressVal = collectedAmount / (targetAmount > 0 ? targetAmount : 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'THIS CYCLE STATUS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Payout Recipients in Previous Cycles:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: pastWinners.map((winner) {
              return Tooltip(
                message: winner['name']!,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          winner['initials']!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Monthly Collection:',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '₹${collectedAmount.toStringAsFixed(0)} / ₹${targetAmount.toStringAsFixed(0)}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C81),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF007A87),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Deposit held in escrow: ₹${g.securityDeposit.toStringAsFixed(0)}\n(Refundable security amount released upon successful completion)',
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: Color(0xFF15803D),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foreman Receiving UPI ID: ${g.foremanUpiId}\nInstallments transfer directly to this VPA.',
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberLedgerTimeline(ChitGroup g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TIMELINE / LEDGER (TAP FOR DUAL CONFIRMATION DETAILS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userPayments.length,
            itemBuilder: (context, index) {
              final tx = _userPayments[index];
              return InkWell(
                onTap: () => _showTransactionDetails(tx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(0xFF166534),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cycle ${tx['cycle']} installment payment',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tx['date'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${tx['amount'].toStringAsFixed(0)}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F4C81),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.check,
                                  color: Colors.green,
                                  size: 10,
                                ),
                                SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    'Double Confirmed',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMemberForemanInfo(ChitGroup g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GROUP & FOREMAN INFO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0F4C81).withOpacity(0.1),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Color(0xFF0F4C81),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rajesh Kumar (Foreman)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF007A87),
                          size: 10,
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Trusted Foreman (Score: 98/100)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Color(0xFF007A87),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openDigitalAgreement,
              icon: const Icon(Icons.menu_book_rounded, size: 15),
              label: const Text(
                'Digital Terms & Conditions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F4C81),
                side: const BorderSide(color: Color(0xFF0F4C81)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _flagDiscrepancy,
              icon: const Icon(Icons.flag_outlined, size: 15),
              label: const Text(
                'Flag a Discrepancy',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberReputationDetails(ChitGroup g) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY REPUTATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: const [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 3,
                      backgroundColor: Color(0xFFF1F5F9),
                      color: Colors.green,
                    ),
                    Icon(
                      Icons.verified_outlined,
                      color: Colors.green,
                      size: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Trusted Member',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'On-time payments: 4/4. No flags.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 6),
          const Text(
            'Mechanism:\n• New/low reputation accounts are restricted to chits under ₹1,000.\n• Ask a trusted member to guarantee you for higher-value groups.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _openRazorpayCardCheckout(double amount) {
    RazorpayCheckoutModal.show(
      context: context,
      groupId: widget.group.id,
      groupName: widget.group.name,
      memberId: widget.currentUsername,
      amount: amount,
      onDepositSuccess: () {
        setState(() {
          _userPayments.insert(0, {
            'cycle': widget.group.currentCycle,
            'amount': amount,
            'date': 'Today, ${DateFormat('hh:mm a').format(DateTime.now())}',
            'foremanConfirmed':
                'Today, ${DateFormat('hh:mm a').format(DateTime.now().add(const Duration(minutes: 5)))}',
            'memberConfirmed':
                'Today, ${DateFormat('hh:mm a').format(DateTime.now())}',
            'status': 'Confirmed by both parties',
          });
        });
        _loadGroupMembers();
      },
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Two-Party Confirmation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction: Cycle ${tx['cycle']} Contribution',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Amount: ₹${tx['amount'].toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF0F4C81),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Foreman Approved',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24.0, top: 2),
                child: Text(
                  'Approved by: Rajesh Kumar (Foreman)\nAt: ${tx['foremanConfirmed']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Subscriber Confirmed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24.0, top: 2),
                child: Text(
                  'Approved by: You (${widget.currentUsername})\nAt: ${tx['memberConfirmed']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _flagDiscrepancy() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              const Icon(
                Icons.report_problem_outlined,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Flag a Discrepancy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Describe the discrepancy or issue you observed. The Foreman and system admin will be notified immediately.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter details here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final issue = controller.text.trim();
                if (issue.isNotEmpty) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🚨 Discrepancy successfully logged. Foreman notified!',
                      ),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Flag'),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 1: AUCTION / RANDOM DRAW FUNCTIONALITY ---
  Widget _buildSchemeAuctionTab(ChitGroup g, double progressPct) {
    final bidState = BiddingSessionService.instance.getOrCreateState(g.id);
    final hostMember = _members.where((m) => m.isHostMember).firstOrNull;
    final bool hasHostMember = hostMember != null;
    final bool isCycle2HostPayout = g.currentCycle == 2 && hasHostMember;
    final bool isHostPayoutRecorded = _ledgerHistory.any(
      (item) => item['cycle'] == 2 && item['status'] == 'Host payout (self)',
    );
    final pendingInGroup = _groupPayments.where((p) => p.isPending).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isForeman && pendingInGroup.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _tabController.animateTo(2),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      color: Color(0xFFB45309),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pendingInGroup.length} Payment${pendingInGroup.length > 1 ? "s" : ""} Awaiting Foreman Handshake',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Subscribers submitted contributions. Tap to verify & confirm receipts.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFFB45309),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Schedule Banner (1st & 10th of every month)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4C81),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            g.schemeType == 'Bidding'
                                ? Icons.gavel
                                : Icons.casino,
                            color: const Color(0xFF059669),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              g.schemeType == 'Bidding'
                                  ? 'Bidding Auction Starts'
                                  : 'Lucky Draw Date',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '1st of Every Month',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 36, width: 1, color: Colors.white24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.payment_rounded,
                            color: Color(0xFF86EFAC),
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Subscriber Payment Due',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '10th of Every Month',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Requirement 4: In Cycle 2, if host is member, skip auction/random draw and fix payout to host
          if (isCycle2HostPayout) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 36,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Month 2: Fixed Host Payout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Per scheme rules, the host (${hostMember.name}) receives the Month 2 full pot payout with 0% discount and 0 dividend. Auction and random draw are skipped for Cycle 2.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Full Pot Payout (No discount)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          '₹${g.totalPoolSize.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isHostPayoutRecorded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Host Payout Recorded in Ledger (Self) ✓',
                          style: TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else if (widget.isForeman)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _recordCycle2HostPayout(g, hostMember.name);
                        },
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Record Host Payout (Self)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (g.schemeType == 'Bidding') ...[
            if (bidState.scheduledStartTime == null) ...[
              // Screen A: No session scheduled -> Show Schedule button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 48,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No Auction Scheduled for this Cycle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'As the host/foreman, you must schedule a bidding session. Members will receive advance reminders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HostScheduleScreen(group: g),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 16),
                        label: const Text('Schedule Bidding Session'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (bidState.scheduledStartTime != null &&
                !bidState.isAuctionActive &&
                !bidState.isAuctionEnded) ...[
              // Screen B: Session scheduled but not started
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 48,
                      color: Color(0xFF0F4C81),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bidding Session Scheduled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F4C81),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled to start: ${DateFormat('d MMM yyyy, hh:mm a').format(bidState.scheduledStartTime!)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reminders have been sent to all group members.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => BiddingSessionService.instance
                                .cancelSchedule(g.id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel Schedule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final minBid = g.totalPoolSize * 0.05;
                              final maxCap = g.totalPoolSize * 0.30;
                              BiddingSessionService.instance.startAuction(
                                g.id,
                                minBid,
                                maxCap,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Start Now',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (bidState.isAuctionActive &&
                !bidState.isAuctionEnded) ...[
              // Screen C: Live Bidding Room (Active)
              Container(
                height: 480, // Constrained height for tab view
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: LiveBiddingRoom(
                  group: g,
                  currentUsername: widget.currentUsername,
                  isForeman: true,
                  isApproved: true,
                  onAuctionEnded: () => setState(() {}),
                ),
              ),
            ] else if (bidState.isAuctionEnded) ...[
              // Screen D: Auction Ended / Concluded Summary
              AuctionClosePayout(
                group: g,
                currentUsername: widget.currentUsername,
                isForeman: true,
                onPayoutReleased: _handlePayoutReleased,
              ),
            ],
          ] else ...[
            // Random Draw Lucky Draw panel (retains existing draw UI)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF007A87).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'RANDOM PICKING CHIT (LUCKY DRAW)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF0F4C81),
                          ),
                        ),
                      ),
                      Chip(
                        label: const Text('Draw Eligible'),
                        backgroundColor: const Color(0xFFDCFCE7),
                        labelStyle: const TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_luckyDrawWinner != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFF166534),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Winner Picked: $_luckyDrawWinner 🎉',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                Text(
                                  'Full Payout Amount: ₹${g.totalPoolSize.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Monthly winner is randomly picked from eligible un-prized subscribers.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _runRandomPickingDraw,
                        icon: const Icon(Icons.casino_rounded, size: 18),
                        label: const Text('Run Monthly Lucky Draw'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007A87),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Subscriber Payment Action (10th of every month)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Color(0xFF007A87),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Contribution Installment: ₹${g.monthlyContribution.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Text(
                        'Due date: 10th of every month',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _makeMonthlyPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007A87),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Pay Installment'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Digital Agreement Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openDigitalAgreement,
              icon: const Icon(Icons.gavel_rounded, color: Color(0xFF0F4C81)),
              label: const Text(
                'Inspect Signed Digital Agreement (Chit Funds Act 1982)',
                style: TextStyle(
                  color: Color(0xFF0F4C81),
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F4C81), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: MEMBER ROSTER & DUES ---
  Widget _buildMemberRosterTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F4C81)),
      );
    }

    if (_members.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'No members subscribed yet. Share 6-digit code to invite members.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final sessionState =
        BiddingSessionService.instance.getOrCreateState(widget.group.id);
    final double auctionDiscount = sessionState.currentHighestBid > 0
        ? sessionState.currentHighestBid
        : _currentWinningBid;
    final int memberCount = widget.group.durationMonths > 0
        ? widget.group.durationMonths
        : (_members.isNotEmpty ? _members.length : 1);
    final double dividendPerMember =
        auctionDiscount > 0 ? (auctionDiscount / memberCount) : 0.0;
    final double baseInstallment = widget.group.monthlyContribution;
    final double reducedInstallment =
        (baseInstallment - dividendPerMember).clamp(0.0, baseInstallment);

    // Paid vs Unpaid breakdown for current cycle
    final paidIdentifiers = _groupPayments
        .where((p) => p.isPaid && p.cycle == widget.group.currentCycle)
        .map((p) => p.memberUsername.toLowerCase())
        .toSet();
    final paidNames = _groupPayments
        .where((p) => p.isPaid && p.cycle == widget.group.currentCycle)
        .map((p) => p.memberName.toLowerCase())
        .toSet();

    final paidMembers = _members.where((m) {
      final lower = m.name.toLowerCase();
      return m.isHostMember ||
          paidIdentifiers.contains(lower) ||
          paidNames.contains(lower);
    }).toList();

    final unpaidMembers =
        _members.where((m) => !paidMembers.contains(m)).toList();

    List<ChitMemberRisk> displayMembers = _members;
    if (_rosterFilter == 'Paid') {
      displayMembers = paidMembers;
    } else if (_rosterFilter == 'Unpaid') {
      displayMembers = unpaidMembers;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Upcoming Month Reduced Installment Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_down_rounded,
                        size: 18,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Upcoming Month Installment (Cycle ${widget.group.currentCycle + 1})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Dividend Applied',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Base Contribution',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        baseInstallment < 10
                            ? '₹${baseInstallment.toStringAsFixed(2)}'
                            : '₹${baseInstallment.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '-',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Auction Dividend',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF059669),
                        ),
                      ),
                      Text(
                        dividendPerMember < 10
                            ? '₹${dividendPerMember.toStringAsFixed(2)}'
                            : '₹${dividendPerMember.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '=',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Net Upcoming Due',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      Text(
                        reducedInstallment < 10
                            ? '₹${reducedInstallment.toStringAsFixed(2)}'
                            : '₹${reducedInstallment.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Winning discount: ₹${auctionDiscount < 10 ? auctionDiscount.toStringAsFixed(2) : auctionDiscount.toStringAsFixed(0)} ÷ $memberCount members = ₹${dividendPerMember < 10 ? dividendPerMember.toStringAsFixed(2) : dividendPerMember.toStringAsFixed(0)} savings per member.',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),

        // 2. Collection Dues Summary and Filters
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Cycle ${widget.group.currentCycle}: ${paidMembers.length}/${_members.length} Paid',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Wrap(
                spacing: 4,
                children: ['All', 'Paid', 'Unpaid'].map((filter) {
                  final isSelected = _rosterFilter == filter;
                  final count = filter == 'All'
                      ? _members.length
                      : (filter == 'Paid'
                          ? paidMembers.length
                          : unpaidMembers.length);
                  return ChoiceChip(
                    label: Text('$filter ($count)'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _rosterFilter = filter),
                    selectedColor: const Color(0xFF0F4C81),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // 3. Member List
        Expanded(
          child: displayMembers.isEmpty
              ? Center(
                  child: Text(
                    _rosterFilter == 'Unpaid'
                        ? 'All members have paid for Cycle ${widget.group.currentCycle}!'
                        : 'No members in this filter.',
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              : ListView.builder(
                  itemCount: displayMembers.length,
                  itemBuilder: (context, index) {
                    final m = displayMembers[index];
                    final dep = _rosterDeposits[m.name];
                    final depStatus = dep?.displayStatus ?? 'Pending';
                    final depAmt = dep?.amount ?? _depositAmount;
                    final bool isMemberPaid = paidMembers.contains(m);

                    Color depBadgeBg = const Color(0xFFFEF3C7);
                    Color depBadgeText = const Color(0xFF92400E);
                    if (dep?.isHeld == true) {
                      depBadgeBg = const Color(0xFFDCFCE7);
                      depBadgeText = const Color(0xFF166534);
                    } else if (dep?.isRefunded == true) {
                      depBadgeBg = const Color(0xFFE0F2FE);
                      depBadgeText = const Color(0xFF0369A1);
                    } else if (dep?.isForfeited == true) {
                      depBadgeBg = const Color(0xFFFEE2E2);
                      depBadgeText = const Color(0xFF991B1B);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMemberPaid
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isMemberPaid
                                    ? const Color(0xFF0F4C81)
                                    : const Color(0xFFDC2626),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => UserProfileScreen(
                                              username: m.name,
                                              isOwnProfile: false,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                                decoration:
                                                    TextDecoration.underline,
                                                decorationColor:
                                                    Color(0xFFCBD5E1),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (m.isHostMember) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFBBF7D0),
                                                ),
                                              ),
                                              child: const Text(
                                                'Host · Month 2',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF166534),
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.open_in_new,
                                            size: 12,
                                            color: Color(0xFF007A87),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Payout: ${m.payoutPosition} • Trend: ${m.paymentTrend}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMemberPaid
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      m.isHostMember
                                          ? 'Paid (Host share)'
                                          : (isMemberPaid
                                              ? 'Paid (Cycle ${widget.group.currentCycle})'
                                              : 'Due ₹${baseInstallment < 10 ? baseInstallment.toStringAsFixed(2) : baseInstallment.toStringAsFixed(0)}'),
                                      style: TextStyle(
                                        color: isMemberPaid
                                            ? const Color(0xFF166534)
                                            : const Color(0xFF991B1B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: depBadgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Deposit: $depStatus',
                                      style: TextStyle(
                                        color: depBadgeText,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 12,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Next Month Net Due: ₹${reducedInstallment < 10 ? reducedInstallment.toStringAsFixed(2) : reducedInstallment.toStringAsFixed(0)} (Saved ₹${dividendPerMember < 10 ? dividendPerMember.toStringAsFixed(2) : dividendPerMember.toStringAsFixed(0)} via auction dividend)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              if (!isMemberPaid &&
                                  !m.isHostMember &&
                                  widget.isForeman) ...[
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Payment reminder sent to ${m.name} for Cycle ${widget.group.currentCycle}!',
                                        ),
                                        backgroundColor:
                                            const Color(0xFF0F4C81),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.notifications_active_outlined,
                                    size: 12,
                                  ),
                                  label: const Text(
                                    'Remind',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    foregroundColor: const Color(0xFFDC2626),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (widget.isForeman && kDevTools) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await SupabaseService.refundDeposit(
                                      depositId: dep?.id ?? '',
                                      groupId: widget.group.id,
                                      memberId: m.name,
                                      amount: depAmt,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deposit refunded for ${m.name} (₹${depAmt.toStringAsFixed(0)})',
                                          ),
                                          backgroundColor:
                                              const Color(0xFF0284C7),
                                        ),
                                      );
                                      _loadGroupMembers();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.replay_rounded,
                                    size: 12,
                                  ),
                                  label: const Text(
                                    'Test: refund deposit',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF0284C7),
                                    ),
                                    foregroundColor: const Color(0xFF0284C7),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await SupabaseService.forfeitDeposit(
                                      depositId: dep?.id ?? '',
                                      groupId: widget.group.id,
                                      memberId: m.name,
                                      amount: depAmt,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deposit forfeited for ${m.name} & applied to missed installment',
                                          ),
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                      );
                                      _loadGroupMembers();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.gavel_rounded,
                                    size: 12,
                                  ),
                                  label: const Text(
                                    'Test: forfeit deposit',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFDC2626),
                                    ),
                                    foregroundColor: const Color(0xFFDC2626),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TAB 3: HANDSHAKE CONFIRMATIONS ---
  Widget _buildHandshakeConfirmationsTab() {
    final pending = _groupPayments.where((p) => p.isPending).toList();

    if (pending.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.handshake_rounded,
                  size: 48,
                  color: Color(0xFF166534),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'All Handshakes Confirmed!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No pending payments awaiting foreman confirmation for ${widget.group.name}.\nMember installments will appear here for verification when submitted.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final p = pending[index];
        final formattedDate =
            DateFormat('d MMM yyyy, hh:mm a').format(p.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF007A87), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F4F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.handshake_outlined,
                      color: Color(0xFF007A87),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.memberName.isNotEmpty
                              ? p.memberName
                              : p.memberUsername,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.amount < 10
                              ? '₹${p.amount.toStringAsFixed(2)} via ${p.paymentMethod}'
                              : '₹${p.amount.toStringAsFixed(0)} via ${p.paymentMethod}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Txn: ${p.utr ?? p.id} • $formattedDate',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Awaiting Confirmation',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmPaymentWithCelebration(p),
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text(
                    'Confirm Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007A87),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmPaymentWithCelebration(ChitPaymentRecord p) async {
    final success = await SupabaseService.confirmPaymentHandshake(
      paymentId: p.id,
      foremanUsername: widget.currentUsername,
      notes: 'Foreman verified receipt of ₹${p.amount} from ${p.memberName}',
    );

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm payment handshake.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    _loadGroupMembers();

    if (!mounted) return;

    // Pop-up celebratory notification message
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF166534),
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Confirmed! 🤝',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment handshake verified for ${p.memberName.isNotEmpty ? p.memberName : p.memberUsername}.\n'
                'Amount: ₹${p.amount < 10 ? p.amount.toStringAsFixed(2) : p.amount.toStringAsFixed(0)}\n'
                'Cycle ${p.cycle} contribution is recorded in the group ledger.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: Color(0xFF007A87),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notification and digital payment receipt dispatched to member.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007A87),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Payment confirmed for ${p.memberName}! Notification sent.'),
        backgroundColor: const Color(0xFF059669),
      ),
    );
  }

  // --- TAB 3: PAYOUT & INSTALLMENT LEDGER ---
  Widget _buildPayoutLedgerTab(ChitGroup g) {
    return FutureBuilder<List<ChitPaymentRecord>>(
      future: SupabaseService.getGroupPayments(g.id),
      builder: (context, snapshot) {
        final payments = snapshot.data ?? [];
        return ListView(
          children: [
            // Section 1: Recent Auction Payouts
            if (_ledgerHistory.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Auction Winning Payouts & Dividends',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              ..._ledgerHistory.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cycle ${item["cycle"]} Ledger Entry',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F4C81),
                            ),
                          ),
                          Chip(
                            label: Text('${item["status"]}'),
                            backgroundColor: const Color(0xFF007A87),
                            labelStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Winner: ${item["winner"]}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Payout: ₹${(item["payoutAmount"] as double).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${item["date"]} • Member Dividend: ₹${(item["dividendPerMember"] as double).toStringAsFixed(0)}/user',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Section 2: Verified Member Installment Collections (YouPI & Cash)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Verified Subscriber Installments (YouPI & Cash)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
            if (payments.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No installment collections recorded yet.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              )
            else
              ...payments.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: p.isPaid
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: p.isPaid
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          p.isPaid
                              ? Icons.check_circle_rounded
                              : Icons.pending_rounded,
                          color: p.isPaid
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.memberName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              p.paymentMethod == 'HOST_SHARE'
                                  ? 'Host Share • Auto-credited'
                                  : 'UTR: ${p.utr ?? "Pending verification"} • ${p.paymentMethod}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${p.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.isPaid
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.paymentMethod == 'HOST_SHARE'
                                  ? 'Paid (host share)'
                                  : p.status,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: p.isPaid
                                    ? const Color(0xFF166534)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
