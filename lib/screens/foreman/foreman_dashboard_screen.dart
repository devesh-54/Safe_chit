import 'package:flutter/material.dart';
import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../models/chit_join_request.dart';
import '../../services/supabase_service.dart';
import '../common/group_details_modal.dart';
import 'create_group_screen.dart';
import 'escrow_controls_screen.dart';

class ForemanDashboardScreen extends StatefulWidget {
  const ForemanDashboardScreen({super.key});

  @override
  State<ForemanDashboardScreen> createState() => _ForemanDashboardScreenState();
}

class _ForemanDashboardScreenState extends State<ForemanDashboardScreen> {
  int _currentIndex = 0; // 0: Dashboard, 1: My Groups, 2: Create Group, 3: Escrow Control
  bool _isSidebarCollapsed = false; // Collapsible / Retractable sidebar state

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

  void _openGroupDetails(ChitGroup group) {
    showDialog(
      context: context,
      builder: (_) => GroupDetailsModal(
        group: group,
        isForeman: true,
        currentUsername: 'foreman_admin',
      ),
    );
  }

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isSidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded),
          tooltip: _isSidebarCollapsed ? 'Expand Sidebar' : 'Retract Sidebar',
          onPressed: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'ChitGuard Host Console',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadDashboardData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dashboard refreshed!'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // Animated Retractable / Collapsible Sidebar Navigation
          _buildSidebarNav(),

          // Main View Content
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNav() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isSidebarCollapsed ? 72 : 240,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildSidebarItem(index: 0, icon: Icons.dashboard_rounded, label: 'Dashboard'),
          _buildSidebarItem(index: 1, icon: Icons.groups_rounded, label: 'My Groups', badgeCount: _groups.length),
          _buildSidebarItem(index: 2, icon: Icons.add_circle_rounded, label: 'Create Group'),
          _buildSidebarItem(index: 3, icon: Icons.gavel_rounded, label: 'Escrow Control'),
          const Spacer(),
          if (!_isSidebarCollapsed)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF007A87), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Licensed Foreman Protocol', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message: 'Licensed Foreman Protocol',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF007A87), size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _currentIndex == index;
    
    if (_isSidebarCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() {
                _currentIndex = index;
              });
              if (index == 0 || index == 1) {
                _loadDashboardData();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F4C81) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 22),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0F4C81) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 20),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF0F4C81),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0 || index == 1) {
            _loadDashboardData();
          }
        },
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildMyGroupsTab();
      case 2:
        return CreateGroupScreen(
          onGroupCreated: () {
            setState(() {
              _currentIndex = 1; // navigate to my groups
            });
            _loadDashboardData();
          },
        );
      case 3:
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81)));
    }

    final filteredMembers = _members.where((m) {
      final nameLower = m.name.toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      return nameLower.contains(queryLower);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Selector Dropdown
              if (_groups.isNotEmpty) ...[
                _buildGroupSelector(),
                const SizedBox(height: 20),
                _buildExposureSummaryCard(),
                const SizedBox(height: 24),
                _buildMetricsRow(),
                const SizedBox(height: 28),
              ],

              // Pending Join Requests
              _buildJoinRequestsSection(),
              const SizedBox(height: 28),

              // Members Default Risk List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Member Default Risk Profiles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                  Text('${filteredMembers.length} Members', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search member by name...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 16),

              if (filteredMembers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: const Center(child: Text('No members found.', style: TextStyle(color: Color(0xFF64748B)))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) => _buildMemberRiskCard(filteredMembers[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Foreman Chit Schemes & Groups', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Click any group card to view 1st-of-month bidding dates & payment schedules.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _currentIndex = 2),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New Group'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81)))
              else if (_groups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      const Text('No Chit Groups Active', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Create your first chit scheme to start risk tracking.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() => _currentIndex = 2),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
                        child: const Text('Create a Chit Group'),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _groups.map((group) => _buildForemanGroupCard(group)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForemanGroupCard(ChitGroup group) {
    return GestureDetector(
      onTap: () => _openGroupDetails(group),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    group.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded,
                    color: const Color(0xFF0F4C81),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('6-Digit Code: ${group.inviteCode} • ${group.city}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Chip(
                  label: Text(group.schemeType),
                  backgroundColor: const Color(0xFF0F4C81),
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: const [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF007A87)),
                  SizedBox(width: 6),
                  Text('Bidding/Draw: 1st of month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Spacer(),
                  Icon(Icons.payment_rounded, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text('Payment Due: 10th of month', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Pool: ₹${group.totalPoolSize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                Text('Monthly: ₹${group.monthlyContribution.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF007A87))),
                Text('Capacity: ${group.membersCount} Members', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ],
            ),
          ],
        ),
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
                '${group.name} (Code: ${group.inviteCode})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F4C81), fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: _changeGroup,
        ),
      ),
    );
  }

  Widget _buildExposureSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text('TOTAL EXPOSURE AT RISK', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              Chip(
                label: Text('${_selectedGroup?.schemeType ?? "Bidding"} System'),
                backgroundColor: Colors.white.withOpacity(0.2),
                labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('₹${_totalExposedAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Total uncollateralized chit payout exposure across active subscribers', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(title: 'Active Defaulters', value: '$_defaulterAlertsCount', icon: Icons.warning_amber_rounded, color: const Color(0xFFDC2626)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(title: 'Total Subscribers', value: '${_members.length}', icon: Icons.people_rounded, color: const Color(0xFF0F4C81)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(title: 'Monthly Pool', value: '₹${_selectedGroup?.totalPoolSize.toStringAsFixed(0) ?? "0"}', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF007A87)),
        ),
      ],
    );
  }

  Widget _buildMetricTile({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        ],
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
            const Text('Pending Member Join Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
            Chip(
              label: Text('${_pendingRequests.length} Pending'),
              backgroundColor: _pendingRequests.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF007A87),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Members applying via 6-digit code. Reviews display basic profile info only.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        if (_pendingRequests.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF007A87), size: 24),
                SizedBox(width: 12),
                Text('No pending join requests right now.', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              ],
            ),
          )
        else
          Column(children: _pendingRequests.map((req) => _buildJoinRequestCard(req)).toList()),
      ],
    );
  }

  Widget _buildJoinRequestCard(ChitJoinRequest req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.memberName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Requested: ${req.groupName} (Code: ${req.inviteCode})', style: const TextStyle(fontSize: 12, color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Chip(
                label: Text('${req.reputationScore.toStringAsFixed(0)}/100 🛡️'),
                backgroundColor: const Color(0xFFDCFCE7),
                labelStyle: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Phone: ${req.memberPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const Spacer(),
              Text('City: ${req.memberCity}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await SupabaseService.respondToJoinRequest(requestId: req.id, accept: false);
                    _loadDashboardData();
                  },
                  child: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await SupabaseService.respondToJoinRequest(requestId: req.id, accept: true);
                    _loadDashboardData();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
                  child: const Text('Accept & Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRiskCard(ChitMemberRisk member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: member.hasDefaulted ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
            child: Icon(Icons.person, color: member.hasDefaulted ? const Color(0xFFDC2626) : const Color(0xFF0F4C81)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Position: ${member.payoutPosition} • Trend: ${member.paymentTrend}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text('Exposed: ₹${member.amountExposed.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706))),
        ],
      ),
    );
  }
}
