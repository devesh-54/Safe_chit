import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import 'digital_agreement_modal.dart';

class GroupDetailsModal extends StatefulWidget {
  final ChitGroup group;
  final bool isForeman;
  final String currentUsername;

  const GroupDetailsModal({
    super.key,
    required this.group,
    required this.isForeman,
    required this.currentUsername,
  });

  @override
  State<GroupDetailsModal> createState() => _GroupDetailsModalState();
}

class _GroupDetailsModalState extends State<GroupDetailsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChitMemberRisk> _members = [];
  bool _isLoading = true;

  // Bidding & Draw simulation state
  final TextEditingController _bidController = TextEditingController();
  double _currentWinningBid = 50000.0; // default ₹50k discount
  String _currentWinningBidder = 'Ramesh Verma';
  bool _isBiddingActive = true;
  String? _luckyDrawWinner;

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
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bidController.dispose();
    super.dispose();
  }

  void _loadGroupMembers() async {
    setState(() => _isLoading = true);
    final members = await SupabaseService.getGroupMembers(widget.group.id);
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  void _submitAuctionBid() {
    final bidVal = double.tryParse(_bidController.text.trim());
    final maxCap = widget.group.totalPoolSize * 0.30; // 30% max cap per Chit Funds Act 1982

    if (bidVal == null || bidVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bid discount amount (₹).'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    if (bidVal > maxCap) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid discount exceeds 30% legal cap (Max ₹${maxCap.toStringAsFixed(0)}).'), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

    if (bidVal <= _currentWinningBid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bid must be higher than current top discount ₹${_currentWinningBid.toStringAsFixed(0)}.'), backgroundColor: const Color(0xFFD97706)),
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
        content: Text('🎉 New Winning Bid: ₹${bidVal.toStringAsFixed(0)} discount by $widget.currentUsername!'),
        backgroundColor: const Color(0xFF007A87),
      ),
    );
  }

  void _runRandomPickingDraw() {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members available for draw.'), backgroundColor: Color(0xFFDC2626)),
      );
      return;
    }

    final rand = Random();
    final winnerIndex = rand.nextInt(_members.length);
    final winner = _members[winnerIndex].name;

    setState(() {
      _luckyDrawWinner = winner;
      _ledgerHistory.add({
        'cycle': widget.group.currentCycle + 1,
        'date': 'Today (1st of month)',
        'winner': winner,
        'winningDiscount': 0.0,
        'payoutAmount': widget.group.totalPoolSize,
        'dividendPerMember': 0.0,
        'status': 'Random Pick Winner',
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 Lucky Draw Winner Selected: $winner! Payout: ₹${widget.group.totalPoolSize.toStringAsFixed(0)}'),
        backgroundColor: const Color(0xFF007A87),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _makeMonthlyPayment() {
    final amount = widget.group.monthlyContribution;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 Handshake Payment of ₹${amount.toStringAsFixed(0)} sent to Foreman for confirmation!'),
        backgroundColor: const Color(0xFF007A87),
      ),
    );
  }

  void _openDigitalAgreement() async {
    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: widget.group.name,
      foremanName: widget.isForeman ? 'Rajesh Kumar (Foreman)' : 'Foreman Host',
      memberName: widget.isForeman ? 'Subscriber Member' : widget.currentUsername,
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 850),
        height: MediaQuery.of(context).size.height * 0.90,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C81).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    g.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded,
                    color: const Color(0xFF0F4C81),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Code: ${g.inviteCode} • ${g.city} • ${g.schemeType} Scheme',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF007A87), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar: 1. Scheme Auction/Draw | 2. Member Roster | 3. Payout Ledger
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0F4C81),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0F4C81),
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: Icon(g.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded, size: 18),
                  text: g.schemeType == 'Bidding' ? 'Monthly Auction' : 'Random Draw',
                ),
                const Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Member Roster'),
                const Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Payout Ledger'),
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
                  _buildPayoutLedgerTab(g),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: AUCTION / RANDOM DRAW FUNCTIONALITY ---
  Widget _buildSchemeAuctionTab(ChitGroup g, double progressPct) {
    final dividendPerMember = _currentWinningBid / (g.membersCount > 0 ? g.membersCount : 10);
    final discountedPayout = g.totalPoolSize - _currentWinningBid;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          Icon(g.schemeType == 'Bidding' ? Icons.gavel : Icons.casino, color: const Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 6),
                          Text(g.schemeType == 'Bidding' ? 'Bidding Auction Starts' : 'Lucky Draw Date', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('1st of Every Month', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
                          Icon(Icons.payment_rounded, color: Color(0xFF86EFAC), size: 16),
                          SizedBox(width: 6),
                          Text('Subscriber Payment Due', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('10th of Every Month', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Bidding Section vs Random Draw Section
          if (g.schemeType == 'Bidding') ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF007A87).withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('LIVE MONTHLY AUCTION (CYCLE 1)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F4C81))),
                      Chip(
                        label: const Text('Bidding Active'),
                        backgroundColor: const Color(0xFFDCFCE7),
                        labelStyle: const TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Top Discount Bid:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text('₹${_currentWinningBid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                            Text('Bidder: $_currentWinningBidder', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF007A87))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Winner Take-Home Payout:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Text('₹${discountedPayout.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F4C81))),
                            Text('Member Dividend Gain: ₹${dividendPerMember.toStringAsFixed(0)}/user', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bid Input Field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bidController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter discount bid amount (₹)...',
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _submitAuctionBid,
                        icon: const Icon(Icons.gavel, size: 16),
                        label: const Text('Place Bid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Random Picking Chit System
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF007A87).withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('RANDOM PICKING CHIT (LUCKY DRAW)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F4C81))),
                      Chip(
                        label: const Text('Draw Eligible'),
                        backgroundColor: const Color(0xFFFEF3C7),
                        labelStyle: const TextStyle(color: Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_luckyDrawWinner != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFF166534), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Winner Picked: $_luckyDrawWinner 🎉', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF166534))),
                                Text('Full Payout Amount: ₹${g.totalPoolSize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF15803D))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text('Monthly winner is randomly picked from eligible un-prized subscribers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF007A87), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly Contribution Installment: ₹${g.monthlyContribution.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text('Due date: 10th of every month', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _makeMonthlyPayment,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A87), foregroundColor: Colors.white),
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
              label: const Text('Inspect Signed Digital Agreement (Chit Funds Act 1982)', style: TextStyle(color: Color(0xFF0F4C81), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0F4C81), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: MEMBER ROSTER ---
  Widget _buildMemberRosterTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81)));
    }

    if (_members.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
        child: const Center(
          child: Text('No members subscribed yet. Share 6-digit code to invite members.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return ListView.builder(
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0F4C81),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Payout: ${m.payoutPosition} • Trend: ${m.paymentTrend}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                child: const Text('Verified Member', style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: PAYOUT LEDGER ---
  Widget _buildPayoutLedgerTab(ChitGroup g) {
    return ListView.builder(
      itemCount: _ledgerHistory.length,
      itemBuilder: (context, index) {
        final item = _ledgerHistory[index];
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
                  Text('Cycle ${item["cycle"]} Ledger Entry', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F4C81))),
                  Chip(
                    label: Text('${item["status"]}'),
                    backgroundColor: const Color(0xFF007A87),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Winner: ${item["winner"]}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Text('Payout: ₹${(item["payoutAmount"] as double).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                ],
              ),
              const SizedBox(height: 4),
              Text('Date: ${item["date"]} • Member Dividend: ₹${(item["dividendPerMember"] as double).toStringAsFixed(0)}/user', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        );
      },
    );
  }
}
