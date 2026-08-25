import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../models/chit_group.dart';
import '../../models/chit_join_request.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import '../common/digital_agreement_modal.dart';
import '../common/group_details_modal.dart';

class MemberDashboardScreen extends StatefulWidget {
  final OnboardingState? state;

  const MemberDashboardScreen({
    super.key,
    this.state,
  });

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  ChitGroup? _searchedGroup;
  List<ChitJoinRequest> _myRequests = [];
  List<ChitGroup> _publicMarketplaceGroups = [];

  // Metrics
  int _chitsJoinedCount = 0;
  double _monthlyAmountDue = 0.0;
  int _totalDefaultsCount = 0;

  String _username = 'demo_member';
  String _selectedFilterType = 'All'; // 'All', 'Bidding', 'Random Picking'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.state != null && widget.state!.username.isNotEmpty) {
      _username = widget.state!.username;
    }
    _loadMemberData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadMemberData() async {
    setState(() {
      _isLoading = true;
    });

    final requests = await SupabaseService.getMemberJoinRequests(_username);
    final metrics = await SupabaseService.getUserDashboardMetrics(_username);
    final publicGroups = await SupabaseService.getPublicChitGroups(
      query: _searchController.text,
      schemeType: _selectedFilterType,
    );

    setState(() {
      _myRequests = requests;
      _chitsJoinedCount = metrics['chitsJoined'] as int? ?? requests.where((r) => r.status == 'approved').length;
      _monthlyAmountDue = (metrics['monthlyAmountDue'] as num?)?.toDouble() ?? 10000.0;
      _totalDefaultsCount = metrics['totalDefaults'] as int? ?? 0;
      _publicMarketplaceGroups = publicGroups;
      _isLoading = false;
    });
  }

  void _searchGroupByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 6-digit Chit Group code.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchedGroup = null;
    });

    final group = await SupabaseService.getGroupByInviteCode(code);

    setState(() {
      _isSearching = false;
      _searchedGroup = group;
    });

    if (group == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No group found for code "$code". Please verify with Foreman.'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _submitJoinRequest(ChitGroup group) async {
    final displayName = widget.state?.legalName.isNotEmpty == true 
        ? widget.state!.legalName 
        : _username;

    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: group.name,
      foremanName: 'Foreman Host (Licensed Organizer)',
      memberName: displayName,
      poolAmount: group.totalPoolSize,
      durationMonths: group.durationMonths,
      monthlyContribution: group.monthlyContribution,
      schemeType: group.schemeType,
      securityDeposit: group.securityDeposit,
    );

    final agreement = DigitalAgreement(
      id: 'agreement_${group.id}_$_username',
      groupId: group.id,
      groupName: group.name,
      foremanUsername: 'foreman_admin',
      foremanName: 'Foreman Host (Licensed Organizer)',
      memberUsername: _username,
      memberName: displayName,
      poolAmount: group.totalPoolSize,
      durationMonths: group.durationMonths,
      monthlyContribution: group.monthlyContribution,
      schemeType: group.schemeType,
      agreementText: agreementText,
      foremanSigned: true, // Host signed during group creation
      memberSigned: false,
      createdAt: DateTime.now(),
    );

    // Trigger Digital Agreement modal for Subscriber signature once when submitting group join request
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DigitalAgreementModal(
        agreement: agreement,
        isForeman: false,
        onSigned: () async {
          setState(() {
            _isLoading = true;
          });

          await SupabaseService.saveDigitalAgreement(agreement);

          final success = await SupabaseService.submitJoinRequest(
            inviteCode: group.inviteCode,
            memberUsername: _username,
          );

          if (mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎉 Digital Agreement signed & Join request sent for "${group.name}"!'),
                  backgroundColor: const Color(0xFF007A87),
                ),
              );
              _codeController.clear();
              _searchedGroup = null;
              _loadMemberData();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to submit join request. Please try again.'),
                  backgroundColor: Color(0xFFDC2626),
                ),
              );
              setState(() {
                _isLoading = false;
              });
            }
          }
        },
      ),
    );
  }

  void _openDigitalAgreement(ChitJoinRequest req) async {
    final displayName = widget.state?.legalName.isNotEmpty == true 
        ? widget.state!.legalName 
        : 'Suresh Raina';

    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: req.groupName,
      foremanName: 'Rajesh Kumar (Foreman)',
      memberName: displayName,
      poolAmount: 1000000,
      durationMonths: 10,
      monthlyContribution: 10000,
      schemeType: 'Bidding System',
      securityDeposit: 25000,
    );

    var agreement = await SupabaseService.getDigitalAgreement(
      groupId: req.groupId,
      memberUsername: _username,
    );

    agreement ??= DigitalAgreement(
      id: 'agreement_${req.id}',
      groupId: req.groupId,
      groupName: req.groupName,
      foremanUsername: 'foreman_admin',
      foremanName: 'Rajesh Kumar (Foreman)',
      memberUsername: _username,
      memberName: displayName,
      poolAmount: 1000000,
      durationMonths: 10,
      monthlyContribution: 10000,
      schemeType: 'Bidding System',
      agreementText: agreementText,
      createdAt: DateTime.now(),
    );

    await SupabaseService.saveDigitalAgreement(agreement);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => DigitalAgreementModal(
          agreement: agreement!,
          isForeman: false,
          onSigned: () {
            _loadMemberData();
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.state?.legalName.isNotEmpty == true 
        ? widget.state!.legalName 
        : 'Suresh Raina';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Pure Crisp Off-White & Dark Blue Theme
      appBar: AppBar(
        title: const Text(
          '👤 Member Savings & Discovery Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadMemberData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshed member data!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFF59E0B),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'My Chits & Code Join'),
            Tab(icon: Icon(Icons.storefront_outlined, size: 18), text: 'Public Chit Marketplace'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMyChitsTab(displayName),
            _buildMarketplaceTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyChitsTab(String displayName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C81),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Color(0xFFF59E0B), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '@$_username • Verified Subscriber',
                            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007A87),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('100 / 100 🛡️ Verified', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mandated Metrics Row (Chits Joined, Monthly Payment Due, Defaults)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'CHITS JOINED',
                      value: '$_chitsJoinedCount Chits',
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF0F4C81),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'MONTHLY PAYMENT DUE',
                      value: '₹${_monthlyAmountDue.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF007A87),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'TOTAL DEFAULTS',
                      value: '$_totalDefaultsCount Defaults',
                      icon: Icons.shield_outlined,
                      color: _totalDefaultsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Code Join Box
              const Text('Join via 6-Digit Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('Enter code provided by your Foreman to request access directly.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3),
                            decoration: const InputDecoration(
                              hintText: 'Enter 6-Digit Code (e.g. 849201)',
                              counterText: '',
                              prefixIcon: Icon(Icons.vpn_key_outlined, color: Color(0xFF0F4C81)),
                              fillColor: Color(0xFFF8FAFC),
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isSearching ? null : _searchGroupByCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSearching
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    if (_searchedGroup != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified, color: Color(0xFF007A87), size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_searchedGroup!.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                                Chip(
                                  label: Text(_searchedGroup!.schemeType),
                                  backgroundColor: const Color(0xFF0F4C81),
                                  labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Total Pool: ₹${_searchedGroup!.totalPoolSize.toStringAsFixed(0)} • Monthly: ₹${_searchedGroup!.monthlyContribution.toStringAsFixed(0)}/mo'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _submitJoinRequest(_searchedGroup!),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Send Join Request to Foreman'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF007A87),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Joined Chits List
              const Text('My Joined Chit Schemes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Color(0xFF0F4C81))))
              else if (_myRequests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.groups_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No Joined Chit Schemes Yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      SizedBox(height: 4),
                      Text('Search a 6-digit code or browse the Public Marketplace tab.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                Column(
                  children: _myRequests.map((req) => _buildJoinedRequestCard(req)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketplaceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Header
              const Text('Public Chit Discovery Marketplace', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Discover and join verified public chit schemes hosted by licensed foremen.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              // Search Input Bar
              TextField(
                controller: _searchController,
                onChanged: (_) => _loadMemberData(),
                decoration: InputDecoration(
                  hintText: 'Search schemes by name or code...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0F4C81)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),

              // Filter Chips
              Row(
                children: ['All', 'Bidding', 'Random Picking'].map((type) {
                  final isSelected = _selectedFilterType == type;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(type == 'All' ? 'All Schemes' : '$type System'),
                      selectedColor: const Color(0xFF0F4C81),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilterType = type;
                        });
                        _loadMemberData();
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Marketplace Schemes List
              if (_publicMarketplaceGroups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No Public Schemes Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Foremen have not listed public schemes matching this filter.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                Column(
                  children: _publicMarketplaceGroups.map((group) => _buildMarketplaceSchemeCard(group)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedRequestCard(ChitJoinRequest req) {
    Color badgeBg;
    Color badgeText;
    String statusLabel;

    if (req.status == 'approved') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
      statusLabel = 'Approved & Active';
    } else if (req.status == 'rejected') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
      statusLabel = 'Declined';
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
      statusLabel = 'Pending Review';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Code: ${req.inviteCode}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel, style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openDigitalAgreement(req),
                icon: const Icon(Icons.gavel_rounded, size: 16, color: Color(0xFF0F4C81)),
                label: const Text('Digital Agreement', style: TextStyle(color: Color(0xFF0F4C81), fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F4C81)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (req.status == 'approved')
                ElevatedButton.icon(
                  onPressed: () => _openMemberDashboard(req),
                  icon: const Icon(Icons.dashboard_rounded, size: 14, color: Colors.white),
                  label: const Text('Open Dashboard', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              Text('City: ${req.memberCity}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceSchemeCard(ChitGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  group.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded,
                  color: const Color(0xFF0F4C81),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Hosted in ${group.city} • Code: ${group.inviteCode}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF0F4C81), borderRadius: BorderRadius.circular(12)),
                child: Text('${group.schemeType} System', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pool', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  Text('₹${group.totalPoolSize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Monthly Cont.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  Text('₹${group.monthlyContribution.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF007A87))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Duration', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  Text('${group.durationMonths} Mos', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _submitJoinRequest(group),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Join Request to Foreman'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMemberDashboard(ChitJoinRequest req) async {
    setState(() => _isLoading = true);
    final group = await SupabaseService.getChitGroupById(req.groupId);
    setState(() => _isLoading = false);

    if (group != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => GroupDetailsModal(
          group: group,
          isForeman: false,
          currentUsername: _username,
        ),
      );
    }
  }
}
