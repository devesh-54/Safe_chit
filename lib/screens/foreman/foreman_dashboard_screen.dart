import 'package:flutter/material.dart';
import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../services/supabase_service.dart';
import 'create_group_screen.dart';
import 'escrow_controls_screen.dart';

import '../../models/chit_join_request.dart';

class ForemanDashboardScreen extends StatefulWidget {
  const ForemanDashboardScreen({super.key});

  @override
  State<ForemanDashboardScreen> createState() => _ForemanDashboardScreenState();
}

class _ForemanDashboardScreenState extends State<ForemanDashboardScreen> {
  int _currentIndex = 0;

  // Active group selection and states
  List<ChitGroup> _groups = [];
  List<ChitMemberRisk> _members = [];
  List<ChitJoinRequest> _pendingRequests = [];
  ChitGroup? _selectedGroup;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final groups = await SupabaseService.getChitGroups();
    final pending = await SupabaseService.getPendingJoinRequests();
    
    if (groups.isNotEmpty) {
      _groups = groups;
      // Default to first group if not already selected
      _selectedGroup ??= groups.first;
      _members = await SupabaseService.getGroupMembers(_selectedGroup!.id);
    }

    setState(() {
      _pendingRequests = pending;
      _isLoading = false;
    });
  }

  void _changeGroup(ChitGroup? newGroup) async {
    if (newGroup == null) return;
    setState(() {
      _isLoading = true;
      _selectedGroup = newGroup;
    });
    final members = await SupabaseService.getGroupMembers(newGroup.id);
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  // Calculate dynamic stats
  double get _totalExposedAmount {
    return _members
        .where((m) => !m.forfeited)
        .fold(0.0, (sum, m) => sum + m.amountExposed);
  }

  int get _defaulterAlertsCount {
    return _members.where((m) => m.hasDefaulted && !m.forfeited).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Cream Base
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C81), // Primary Deep Teal
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: Color(0xFFD97706), size: 20), // Gold Accent
            ),
            const SizedBox(width: 10),
            const Text(
              'ChitGuard Host',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadDashboardData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dashboard data refreshed!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              Navigator.pop(context); // back to onboarding/landing
            },
          ),
        ],
        elevation: 0,
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFFE2E8F0), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Reload data if going back to home
            if (index == 0) {
              _loadDashboardData();
            }
          },
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0F4C81),
          unselectedItemColor: const Color(0xFF5A6E72),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline_rounded),
              activeIcon: Icon(Icons.add_circle_rounded),
              label: 'Create Group',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.gavel_outlined),
              activeIcon: Icon(Icons.gavel_rounded),
              label: 'Escrow Control',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return CreateGroupScreen(
          onGroupCreated: () {
            setState(() {
              _currentIndex = 0; // Navigate back to home
            });
            _loadDashboardData();
          },
        );
      case 2:
        return EscrowControlsScreen(
          onStateChanged: () {
            _loadDashboardData();
          },
        );
      default:
        return const Center(child: Text('View not found'));
    }
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: const Color(0xFF0F4C81)),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_add_outlined, size: 70, color: Color(0xFF007A87)),
              const SizedBox(height: 20),
              const Text(
                'No Chit Groups Active',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
              const SizedBox(height: 8),
              const Text(
                'You have not launched any chit groups yet. Create your first group to start risk tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5A6E72), height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1; // switch to create group
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C81),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Create a Chit Group'),
              )
            ],
          ),
        ),
      );
    }

    // Filter members list based on query
    final filteredMembers = _members.where((m) {
      final nameLower = m.name.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return nameLower.contains(queryLower);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Selector Dropdown
              _buildGroupSelector(),
              const SizedBox(height: 20),

              // Exposure Score Card
              _buildExposureSummaryCard(),
              const SizedBox(height: 24),

              // Quick Metrics Panels
              _buildMetricsRow(),
              const SizedBox(height: 28),

              // Pending Join Requests Section
              _buildJoinRequestsSection(),
              const SizedBox(height: 28),

              // Search and List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Member Default Risk Profiles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F4C81),
                    ),
                  ),
                  Text(
                    '${filteredMembers.length} Members',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E72), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search member by name...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF5A6E72)),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Member List
              filteredMembers.isEmpty
                  ? _buildEmptySearchPlaceholder()
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = filteredMembers[index];
                        return _buildMemberRiskCard(member);
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Member Join Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F4C81),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _pendingRequests.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF007A87),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pendingRequests.length} Pending',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Members applying via 6-digit code. Reviews display basic profile info only (sensitive IDs hidden).',
          style: TextStyle(fontSize: 12, color: Color(0xFF5A6E72)),
        ),
        const SizedBox(height: 12),

        if (_pendingRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Color(0xFF007A87), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No pending join requests right now. Shares 6-digit code with members to invite them.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _pendingRequests.map((req) => _buildJoinRequestCard(req)).toList(),
          ),
      ],
    );
  }

  Widget _buildJoinRequestCard(ChitJoinRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1.5),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF2ECE1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0F4C81), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.memberName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Requested to join: ${req.groupName} (Code: ${req.inviteCode})',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF007A87), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${req.reputationScore.toStringAsFixed(0)}/100 🛡️',
                  style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF5A6E72)),
              const SizedBox(width: 4),
              Text(req.memberPhone, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
              const SizedBox(width: 16),
              const Icon(Icons.email_outlined, size: 14, color: Color(0xFF5A6E72)),
              const SizedBox(width: 4),
              Text(req.memberEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
              const Spacer(),
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF5A6E72)),
              const SizedBox(width: 4),
              Text(req.memberCity, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await SupabaseService.respondToJoinRequest(requestId: req.id, accept: false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Declined join request from ${req.memberName}.')),
                      );
                      _loadDashboardData();
                    }
                  },
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await SupabaseService.respondToJoinRequest(requestId: req.id, accept: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 Approved ${req.memberName} to join ${req.groupName}!'),
                          backgroundColor: const Color(0xFF007A87),
                        ),
                      );
                      _loadDashboardData();
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Accept & Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C81),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ChitGroup>(
          value: _selectedGroup,
          items: _groups.map((group) {
            return DropdownMenuItem<ChitGroup>(
              value: group,
              child: Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F4C81),
                  fontSize: 15,
                ),
              ),
            );
          }).toList(),
          onChanged: _changeGroup,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F4C81)),
          isExpanded: true,
        ),
      ),
    );
  }

  Widget _buildExposureSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF007A87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F4C81).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HOST DEFAULT EXPOSURE SCORE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF2ECE1),
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Color(0xFFD97706), size: 8), // Gold Accent indicator
                    const SizedBox(width: 6),
                    Text(
                      'Cycle ${_selectedGroup?.currentCycle ?? 1}/${_selectedGroup?.durationMonths ?? 10}',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${_totalExposedAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cumulative risk capital exposed to member payment default in this group. Security deposits in escrow reduce net loss.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    double escrowPool = (_selectedGroup?.securityDeposit ?? 20000.0) * (_selectedGroup?.membersCount ?? 10);
    return Row(
      children: [
        // Metrics 1: Defaulter Alerts
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _defaulterAlertsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
                width: _defaulterAlertsCount > 0 ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _defaulterAlertsCount > 0
                        ? const Color(0xFFDC2626).withOpacity(0.08)
                        : const Color(0xFFF2ECE1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: _defaulterAlertsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Defaulters Alert',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5A6E72)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_defaulterAlertsCount Active',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _defaulterAlertsCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF0A2540),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Metrics 2: Escrow Cover
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAF7F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_outlined,
                    color: Color(0xFF007A87),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Escrow Cover Pool',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF5A6E72)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${escrowPool.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberRiskCard(ChitMemberRisk member) {
    Color riskColor;
    String riskText;

    if (member.forfeited) {
      riskColor = const Color(0xFF64748B); // Forfeited/Frozen
      riskText = 'Forfeited';
    } else if (member.defaultRiskScore > 70) {
      riskColor = const Color(0xFFDC2626); // High Risk
      riskText = 'High Risk';
    } else if (member.defaultRiskScore > 35) {
      riskColor = const Color(0xFFD97706); // Medium Risk
      riskText = 'Medium Risk';
    } else {
      riskColor = const Color(0xFF059669); // Low Risk
      riskText = 'Low Risk';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: _buildRiskIndicatorCircular(member.defaultRiskScore, riskColor),
            title: Text(
              member.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: const Color(0xFF0A2540),
                decoration: member.forfeited ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Row(
              children: [
                Text(
                  'Risk Score: ${member.defaultRiskScore.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, color: riskColor, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    riskText,
                    style: TextStyle(fontSize: 9, color: riskColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),
                    
                    // Risk Factors Breakdown Title
                    const Text(
                      'RISK EXPLAINER FACTORS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A6E72),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Factor 1: Payout Position
                    _buildRiskFactorRow(
                      icon: Icons.monetization_on_outlined,
                      label: 'Payout Position',
                      value: member.payoutPosition,
                      riskStatus: member.payoutPosition.contains('Paid') ? 'High default leverage (already paid)' : 'Low default leverage (waiting)',
                      isWarning: member.payoutPosition.contains('Paid'),
                    ),
                    const SizedBox(height: 8),

                    // Factor 2: Payment Trend
                    _buildRiskFactorRow(
                      icon: Icons.timeline,
                      label: 'Payment Trend',
                      value: member.paymentTrend,
                      riskStatus: member.paymentTrend.contains('Delayed') ? 'Instability detected in payments' : 'Solid performance record',
                      isWarning: member.paymentTrend.contains('Delayed'),
                    ),
                    const SizedBox(height: 8),

                    // Factor 3: Guarantor status
                    _buildRiskFactorRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Guarantor Status',
                      value: member.guarantorStatus,
                      riskStatus: member.guarantorStatus.contains('None') ? 'No backup security links' : 'Covered by signed guarantors',
                      isWarning: member.guarantorStatus.contains('None'),
                    ),
                    const SizedBox(height: 12),

                    // Exposure & Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CAPITAL EXPOSED',
                              style: TextStyle(fontSize: 9, color: Color(0xFF5A6E72), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${member.amountExposed.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F4C81)),
                            ),
                          ],
                        ),
                        if (!member.forfeited && member.hasDefaulted)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _currentIndex = 2; // Jump to Escrow Tab
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: const Text('Manage Escrow', style: TextStyle(fontSize: 12)),
                          )
                        else if (member.forfeited)
                          const Text(
                            'Frozen Account',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskIndicatorCircular(double score, Color color) {
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: CircularProgressIndicator(
        value: score / 100,
        backgroundColor: Colors.grey.withOpacity(0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        strokeWidth: 3.5,
      ),
    );
  }

  Widget _buildRiskFactorRow({
    required IconData icon,
    required String label,
    required String value,
    required String riskStatus,
    required bool isWarning,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isWarning ? const Color(0xFFD97706) : const Color(0xFF007A87)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? const Color(0xFFD97706) : const Color(0xFF007A87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                riskStatus,
                style: const TextStyle(fontSize: 11, color: Color(0xFF5A6E72)),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildEmptySearchPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36.0),
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF64748B)),
            const SizedBox(height: 12),
            const Text(
              'No Members Match Search',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
            ),
            const SizedBox(height: 4),
            Text(
              'Try adjusting your search query for "$_searchQuery".',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E72)),
            ),
          ],
        ),
      ),
    );
  }
}
