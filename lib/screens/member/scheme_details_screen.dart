import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/chit_group.dart';

class SchemeDetailsScreen extends StatefulWidget {
  final ChitGroup group;
  final void Function(ChitGroup group)? onSendJoinRequest;

  const SchemeDetailsScreen({
    super.key,
    required this.group,
    this.onSendJoinRequest,
  });

  @override
  State<SchemeDetailsScreen> createState() => _SchemeDetailsScreenState();
}

class _SchemeDetailsScreenState extends State<SchemeDetailsScreen> {
  // 0: Month 1 (Urgent), 1: Month Mid, 2: Month Final (Wealth)
  int _selectedScenario = 0;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isBidding = group.schemeType.toLowerCase().contains('bidding');
    final totalMonths = math.max(1, group.durationMonths);
    final midMonth = math.max(2, (totalMonths / 2).round());
    final enrolled = group.membersCount;
    final slotsLeft = math.max(0, totalMonths - enrolled);
    final capacityRatio = (enrolled / totalMonths).clamp(0.0, 1.0);

    final estDividendMin = (group.monthlyContribution * 0.08).round();
    final estDividendMax = (group.monthlyContribution * 0.16).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF000E2B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scheme Details',
          style: TextStyle(
            color: Color(0xFF000E2B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86F2E4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_rounded, size: 14, color: Color(0xFF006A61)),
                SizedBox(width: 4),
                Text(
                  'Verified Scheme',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF006A61),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Architectural Placeholder Image Banner (as in Stitch)
                _buildTopHeroBanner(),

                // Overlapping Content Zone
                Transform.translate(
                  offset: const Offset(0, -32),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Card with decorative accent
                        _buildHeaderCard(group, slotsLeft),
                        const SizedBox(height: 14),

                        // Financial Matrix 2x2 Grid
                        _buildFinancialMatrix(
                          group,
                          enrolled,
                          totalMonths,
                          slotsLeft,
                          capacityRatio,
                          estDividendMin,
                          estDividendMax,
                        ),
                        const SizedBox(height: 14),

                        // Rules Breakdown Card (Reverse Auction or Random Picking)
                        _buildRulesCard(group, isBidding),
                        const SizedBox(height: 14),

                        // Interactive Cycle Payout Simulator
                        _buildPayoutSimulator(group, midMonth, totalMonths, isBidding),
                        const SizedBox(height: 14),

                        // Institutional Security Architecture
                        _buildSecurityArchitectureCard(group),
                        const SizedBox(height: 14),

                        // Cohort Foreman / Host Profile Card
                        _buildForemanProfileCard(group),
                        const SizedBox(height: 14),

                        // Legal Transparency Note
                        _buildLegalTransparencyNote(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Fixed / Sticky Bottom Conversion Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomDock(group),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 0. Top Architectural Hero Banner (Stitch Placeholder Design)
  // ---------------------------------------------------------------------------
  Widget _buildTopHeroBanner() {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        children: [
          // Architectural facade photo
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=800&q=80',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF000E2B), Color(0xFF0D234A), Color(0xFF006A61)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.apartment_rounded, size: 64, color: Colors.white24),
                ),
              ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF000E2B).withValues(alpha: 0.25),
                    const Color(0xFFDCE9FF).withValues(alpha: 0.55),
                    const Color(0xFFF8F9FF),
                  ],
                ),
              ),
            ),
          ),
          // Top Tag Pill: Registrar Registered Scheme
          Positioned(
            top: 14,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x15000E2B), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF006A61),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'REGISTRAR REGISTERED SCHEME',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF006A61),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom-Right Tag: Starts in 5 days
          Positioned(
            bottom: 42,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF86F2E4),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x15000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: const Text(
                'Starts in 5 days',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D47),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header Card: Scheme Overview & Regulatory Accreditations
  // ---------------------------------------------------------------------------
  Widget _buildHeaderCard(ChitGroup group, int slotsLeft) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0D234A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative Top Accent Stripe
          Container(
            height: 4,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFF006A61), Color(0xFF86F2E4), Color(0xFF0D234A)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'GROUP CHIT FUND • #${group.inviteCode}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D234A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        slotsLeft > 0 ? '$slotsLeft Slots Left' : 'Full / Waitlist',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF000E2B),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF006A61)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Hosted in ${group.city} • SafeChit Registered',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Compliance Pill Matrix
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildPill(Icons.gavel_rounded, 'Act of 1982 Compliant'),
                    _buildPill(
                      Icons.shield_rounded,
                      '27% Security Deposit Reserve',
                      bgColor: const Color(0xFFEFF4FF),
                      textColor: const Color(0xFF0D234A),
                    ),
                    _buildPill(
                      group.schemeType == 'Bidding'
                          ? Icons.trending_down_rounded
                          : Icons.casino_rounded,
                      group.schemeType == 'Bidding'
                          ? 'Live Reverse Bidding'
                          : 'Random Picking Draw',
                      bgColor: const Color(0xFFE6FFFA),
                      textColor: const Color(0xFF006A61),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Cycle timeline metadata
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDF2F7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF006A61)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${group.durationMonths} Months Tenure (Fixed Pool)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Monthly recurring cycle • Current Month: ${group.currentCycle} of ${group.durationMonths}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Financial Matrix 2x2 Grid
  // ---------------------------------------------------------------------------
  Widget _buildFinancialMatrix(
    ChitGroup group,
    int enrolled,
    int totalMonths,
    int slotsLeft,
    double capacityRatio,
    int estDividendMin,
    int estDividendMax,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Tile 1: Gross Pot Payout
        _buildMetricTile(
          title: 'Gross Pot Payout',
          value: '₹${group.totalPoolSize.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet_rounded,
          footerText: '100% Guaranteed Pool',
          footerColor: const Color(0xFF006A61),
        ),
        // Tile 2: Nominal Ticket (Monthly Contribution)
        _buildMetricTile(
          title: 'Nominal Ticket',
          value: '₹${group.monthlyContribution.toStringAsFixed(0)}',
          unit: '/mo',
          icon: Icons.savings_rounded,
          footerText: 'Reduces via Dividend',
          footerColor: const Color(0xFF006A61),
        ),
        // Tile 3: Cohort Capacity & Progress
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cohort Capacity',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$slotsLeft left',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '$enrolled / $totalMonths Joined',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000E2B),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: capacityRatio,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF006A61)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildMiniAvatar('A', const Color(0xFF0D234A)),
                      _buildMiniAvatar('R', const Color(0xFF006A61)),
                      _buildMiniAvatar('+$enrolled', const Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        'Verified peers',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        // Tile 4: Est. Dividend Offset
        _buildMetricTile(
          title: 'Est. Dividend Offset',
          value: '₹$estDividendMin - ₹$estDividendMax',
          icon: Icons.check_circle_rounded,
          footerText: 'Earned Monthly',
          footerColor: const Color(0xFF006A61),
          valueColor: const Color(0xFF006A61),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    required String footerText,
    required Color footerColor,
    Color valueColor = const Color(0xFF000E2B),
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
          Row(
            children: [
              Icon(icon, size: 13, color: footerColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  footerText,
                  style: TextStyle(fontSize: 10, color: footerColor, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String text, Color bg) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Rules Breakdown Card
  // ---------------------------------------------------------------------------
  Widget _buildRulesCard(ChitGroup group, bool isBidding) {
    final minDiscount = (group.totalPoolSize * 0.05).toStringAsFixed(0);
    final maxDiscount = (group.totalPoolSize * 0.30).toStringAsFixed(0);
    final foremanFee = (group.totalPoolSize * 0.05).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.balance_rounded, size: 18, color: Color(0xFF0D234A)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBidding ? 'Reverse Auction Rules' : 'Transparent Draw Rules',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000E2B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Act of 1982',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isBidding
                ? 'Reverse auction empowers members needing emergency capital to bid a discount. The highest discount wins the pot, while the surplus discount is directly returned to everyone as monthly dividend deductions.'
                : 'In Random Picking schemes, a cryptographic fair draw selects one member each month to receive the full chit pool, with zero bidding deductions.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
          ),
          const SizedBox(height: 12),
          // Rule Items
          if (isBidding) ...[
            _buildRuleItem(
              Icons.alarm_rounded,
              'Auction Time Window',
              '1st of every month at 7:00 PM IST (30 mins sharp via SafeChit App)',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              Icons.unfold_more_rounded,
              'Bid Floor & Max Cap: 5% to 30%',
              'Min discount floor: ₹$minDiscount (5%). Max statutory legal cap: ₹$maxDiscount (30%).',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              Icons.percent_rounded,
              'Regulated Foreman Fee (5%)',
              'Standard legal fee of ₹$foremanFee for managing operations, compliance, and defaults.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              Icons.shuffle_rounded,
              'Fair Tie-Breaker Protocol',
              'When multiple bids hit the 30% statutory ceiling, an automated cryptographic lot draws the recipient transparently.',
            ),
          ] else ...[
            _buildRuleItem(
              Icons.casino_rounded,
              'Cryptographic Lot Draw',
              '1st of every month at 7:00 PM IST, the smart contract conducts a live transparent draw.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              Icons.verified_rounded,
              'Equal Payouts Guarantee',
              'Every member is guaranteed exactly one turn to receive the full pot with zero discount penalty.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleItem(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF006A61)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Interactive Cycle Payout Simulator
  // ---------------------------------------------------------------------------
  Widget _buildPayoutSimulator(ChitGroup group, int midMonth, int totalMonths, bool isBidding) {
    final pool = group.totalPoolSize;
    final installment = group.monthlyContribution;
    final otherMembers = math.max(1, totalMonths - 1);

    // Scenario 0: Urgent (Month 1, 25% discount)
    final m1Discount = pool * 0.25;
    final m1Winner = pool - m1Discount;
    final m1Foreman = pool * 0.05;
    final m1Surplus = m1Discount - m1Foreman;
    final m1DivPerMember = m1Surplus / otherMembers;
    final m1Due = math.max(0.0, installment - m1DivPerMember);

    // Scenario 1: Mid (Month mid, 12% discount)
    final midDiscount = pool * 0.12;
    final midWinner = pool - midDiscount;
    final midForeman = pool * 0.05;
    final midSurplus = midDiscount - midForeman;
    final midDivPerMember = midSurplus / otherMembers;
    final midDue = math.max(0.0, installment - midDivPerMember);

    // Scenario 2: Wealth / Saver (Month total, 0% discount)
    final endWinner = pool - (pool * 0.05); // minus 5% legal commission
    final endDue = installment;

    String bidTag;
    String badge;
    String winnerAmt;
    String dueAmt;
    String saveNote;
    String desc;

    if (_selectedScenario == 0) {
      bidTag = 'Bid Discount: 25% (₹${m1Discount.toStringAsFixed(0)})';
      badge = 'Emergency Capital';
      winnerAmt = '₹${m1Winner.toStringAsFixed(0)}';
      dueAmt = '₹${m1Due.toStringAsFixed(0)}';
      saveNote = '₹${m1DivPerMember.toStringAsFixed(0)} dividend profit saved!';
      desc =
          'Early rounds serve entrepreneurs or wedding/medical contingencies. Non-winners gain huge cash dividends directly offset against their monthly dues.';
    } else if (_selectedScenario == 1) {
      bidTag = 'Bid Discount: 12% (₹${midDiscount.toStringAsFixed(0)})';
      badge = 'Balanced Growth';
      winnerAmt = '₹${midWinner.toStringAsFixed(0)}';
      dueAmt = '₹${midDue.toStringAsFixed(0)}';
      saveNote = '₹${midDivPerMember.toStringAsFixed(0)} monthly dividend earned';
      desc =
          'Mid-cycle rounds offer a sweet balance between early liquidity and high accumulated returns for all continuing group members.';
    } else {
      bidTag = 'Bid Discount: 0% (Floor Auction)';
      badge = 'Disciplined Savings';
      winnerAmt = '₹${endWinner.toStringAsFixed(0)}';
      dueAmt = '₹${endDue.toStringAsFixed(0)}';
      saveNote = 'Full savings corpus matured!';
      desc =
          'Last month subscriber takes home the near-total ₹${endWinner.toStringAsFixed(0)} pot (minus foreman 5% regulatory charge), yielding pure return on regular savings.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calculate_rounded, size: 18, color: Color(0xFF0D234A)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cycle Payout Simulator',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000E2B),
                    ),
                  ),
                ],
              ),
              const Text(
                'Sample Scenarios',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006A61),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 3-Segment Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildScenarioTab(0, 'Month 1\n(Urgent)'),
                _buildScenarioTab(1, 'Month $midMonth\n(Mid)'),
                _buildScenarioTab(2, 'Month $totalMonths\n(Wealth)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Dynamic Scenario Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDF2F7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        bidTag,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Winner Receives',
                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              winnerAmt,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF006A61),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Direct payout within 2 hrs',
                              style: TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Other $otherMembers Members Pay',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dueAmt,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF000E2B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              saveNote,
                              style: const TextStyle(fontSize: 9, color: Color(0xFF006A61), fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF006A61)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        desc,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioTab(int index, String label) {
    final isSelected = _selectedScenario == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedScenario = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1)),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF000E2B) : const Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Institutional Security Architecture (Scrubbed compliant terms)
  // ---------------------------------------------------------------------------
  Widget _buildSecurityArchitectureCard(ChitGroup group) {
    final depositAmount = group.effectiveDepositAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF0D234A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Institutional Security Architecture',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000E2B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSecurityItem(
            Icons.account_balance_rounded,
            'Verified Dual-Ledger Foreman Account',
            'Funds never sit unattended. Tracked strictly in an auditable double-entry ledger compliant with Chit Funds Act 1982.',
          ),
          const SizedBox(height: 10),
          _buildSecurityItem(
            Icons.assured_workload_rounded,
            '27% Refundable Security Deposit (₹${depositAmount.toStringAsFixed(0)})',
            'Members maintain a 27% security reserve held in safe custody to prevent non-payment risk and protect continuing subscribers.',
          ),
          const SizedBox(height: 10),
          _buildSecurityItem(
            Icons.history_edu_rounded,
            'Legal Aadhaar e-Sign Agreement',
            'Legally binding bi-party contract under the Information Technology Act 2000 and Section 6 of Chit Funds Act 1982.',
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFCCFBF1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF006A61)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Cohort Foreman / Host Profile Card
  // ---------------------------------------------------------------------------
  Widget _buildForemanProfileCard(ChitGroup group) {
    final foremanHandle = group.foremanUpiId.isNotEmpty ? group.foremanUpiId.split('@').first : 'Foreman';
    final foremanInitial = foremanHandle.isNotEmpty ? foremanHandle[0].toUpperCase() : 'F';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COHORT FOREMAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.star_rounded, size: 13, color: Color(0xFF006A61)),
                    SizedBox(width: 3),
                    Text(
                      'GOLD Organiser',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006A61),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D234A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86F2E4), width: 2),
                ),
                child: Center(
                  child: Text(
                    foremanInitial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                        Text(
                          '@$foremanHandle',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000E2B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF006A61)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Licensed Chit Organizer • ${group.city}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          '4.95',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          ' • 34 Chits Closed • KYC Verified',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Inquiry Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Inquiry channel with @$foremanHandle is ready upon request submission.'),
                    backgroundColor: const Color(0xFF0D234A),
                  ),
                );
              },
              icon: const Icon(Icons.forum_rounded, size: 16, color: Color(0xFF006A61)),
              label: Text(
                'Ask @$foremanHandle a question',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D234A)),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Legal Transparency Note
  // ---------------------------------------------------------------------------
  Widget _buildLegalTransparencyNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Privacy Safeguard: The subscriber roster remains anonymized to outsiders to respect member privacy until mutual bi-party digital agreements are signed.',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Sticky Bottom Conversion Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildStickyBottomDock(ChitGroup group) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000E2B),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Installment Details
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'First Month Due',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${group.monthlyContribution.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000E2B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '₹0 Fee',
                    style: TextStyle(fontSize: 11, color: Color(0xFF006A61), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Right: Join Pool CTA
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (widget.onSendJoinRequest != null) {
                  Navigator.of(context).pop();
                  widget.onSendJoinRequest!(group);
                }
              },
              icon: const Text(
                'Join Pool & Review',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              label: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000E2B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text, {Color? bgColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor ?? const Color(0xFF475569)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor ?? const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
