import 'dart:async';
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
  int _currentIndex = 0; // 0: Dashboard, 1: My Groups, 2: Join Requests, 3: Create Group, 4: Escrow Control
  bool _isSidebarCollapsed = false;

  List<ChitGroup> _groups = [];
  List<ChitMemberRisk> _members = [];
  List<ChitJoinRequest> _pendingRequests = [];
  ChitGroup? _selectedGroup;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRiskFilter = 'All'; // 'All', 'High Risk', 'Low Risk'

  // Real-time live data streaming timer
  Timer? _realtimeTimer;
  StreamSubscription? _requestsSubscription;

  // Two-party handshake pending payments state
  final List<Map<String, dynamic>> _pendingPayments = [
    {
      'id': 'pay_1',
      'memberName': 'Ramesh Verma',
      'amount': 10000.0,
      'date': 'Today, 2:30 PM',
      'txnId': 'UPI_9823746123',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _startRealtimeDataStream();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  /// Start Real-time Data Streaming (Updates live without needing refresh)
  void _startRealtimeDataStream() {
    // 1. Periodic background polling every 2 seconds for live sync
    _realtimeTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final pending = await SupabaseService.getPendingJoinRequests();
      final groups = await SupabaseService.getChitGroups();
      if (mounted) {
        setState(() {
          _pendingRequests = pending;
          _groups = groups;
        });
      }
    });

    // 2. Supabase Realtime channel stream listener
    try {
      final supaClient = SupabaseService.client;
      if (supaClient != null) {
        _requestsSubscription = supaClient
            .from('chit_join_requests')
            .stream(primaryKey: ['id'])
            .eq('status', 'pending')
            .listen((data) {
              if (mounted) {
                setState(() {
                  _pendingRequests = data.map((item) => ChitJoinRequest.fromJson(item)).toList();
                });
              }
            });
      }
    } catch (_) {}
  }

  void _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final groups = await SupabaseService.getChitGroups();
    final pending = await SupabaseService.getPendingJoinRequests();
    
    if (groups.isNotEmpty) {
      _groups = groups;
      if (_selectedGroup != null && groups.contains(_selectedGroup)) {
        _selectedGroup = groups.firstWhere((g) => g == _selectedGroup);
      } else {
        _selectedGroup = groups.first;
      }
      _members = await SupabaseService.getGroupMembers(_selectedGroup!.id);
    } else {
      _selectedGroup = null;
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

  void _showMemberExplainableRisk(ChitMemberRisk m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              m.hasDefaulted ? Icons.warning_amber_rounded : Icons.shield_rounded,
              color: m.hasDefaulted ? const Color(0xFFDC2626) : const Color(0xFF007A87),
            ),
            const SizedBox(width: 10),
            Text('${m.name} Risk Analysis'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payout Position: ${m.payoutPosition}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Payment Streak: ${m.paymentTrend}', style: const TextStyle(color: Color(0xFF64748B))),
            Text('Amount Exposed: ₹${m.amountExposed.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: m.hasDefaulted ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                m.hasDefaulted 
                    ? '⚠️ Flagged: Already paid out + 2 late payments detected in current cycle.' 
                    : '🛡️ Low Risk: Subscriber holds collateralized escrow security deposit + 100% on-time payment track record.',
                style: TextStyle(
                  color: m.hasDefaulted ? const Color(0xFF991B1B) : const Color(0xFF0F4C81),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  void _confirmPaymentHandshake(Map<String, dynamic> p) {
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
                      decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Color(0xFF166534), size: 48),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('Payment Confirmed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text('Handshake verified for ${p["memberName"]}\nAmount: ₹${(p["amount"] as double).toStringAsFixed(0)}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pendingPayments.removeWhere((item) => item['id'] == p['id']);
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A87), foregroundColor: Colors.white),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmPayoutRelease() {
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
                duration: const Duration(milliseconds: 600),
                curve: Curves.bounceOut,
                builder: (context, val, child) {
                  return Transform.scale(
                    scale: val,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 54),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text('🎉 Payout Released!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              const Text('Escrow payout disbursed & verified under Section 20 of the Chit Funds Act, 1982.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _totalExposedAmount {
    return _members
        .where((m) => !m.forfeited)
        .fold(0.0, (sum, m) => sum + m.amountExposed);
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
            const Expanded(
              child: Text(
                'Host Console',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            // Live Real-Time Stream Status Badge (Flexible)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF166534),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fiber_manual_record, color: Color(0xFF86EFAC), size: 8),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'LIVE',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
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
          _buildSidebarNav(),
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
          // Dedicated Tab for Join Requests with Live Badge Count
          _buildSidebarItem(index: 2, icon: Icons.person_add_rounded, label: 'Join Requests', badgeCount: _pendingRequests.length),
          _buildSidebarItem(index: 3, icon: Icons.add_circle_rounded, label: 'Create Group'),
          _buildSidebarItem(index: 4, icon: Icons.gavel_rounded, label: 'Escrow Control'),
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
              if (index == 0 || index == 1 || index == 2) {
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
      child: Material(
        color: isSelected ? const Color(0xFF0F4C81) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
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
            if (index == 0 || index == 1 || index == 2) {
              _loadDashboardData();
            }
          },
        ),
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
        return _buildJoinRequestsTab();
      case 3:
        return CreateGroupScreen(
          onGroupCreated: () {
            setState(() {
              _currentIndex = 1;
            });
            _loadDashboardData();
          },
        );
      case 4:
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
      final nameMatches = m.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_selectedRiskFilter == 'High Risk') return nameMatches && m.hasDefaulted;
      if (_selectedRiskFilter == 'Low Risk') return nameMatches && !m.hasDefaulted;
      return nameMatches;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        _loadDashboardData();
      },
      color: const Color(0xFF0F4C81),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_groups.isNotEmpty) ...[
                  _buildGroupSelector(),
                  const SizedBox(height: 20),
                  
                  // SECTION 1: EXPOSURE SUMMARY CARD
                  _buildSection1ExposureSummaryCard(),
                  const SizedBox(height: 24),
                ],

                // SECTION 2: MEMBER RISK LIST
                _buildSection2MemberRiskList(filteredMembers),
                const SizedBox(height: 28),

                // SECTION 3: PENDING ACTIONS
                _buildSection3PendingActions(),
                const SizedBox(height: 28),

                // SECTION 4: GROUP MANAGEMENT
                if (_selectedGroup != null) ...[
                  _buildSection4GroupManagement(),
                  const SizedBox(height: 28),
                ],

                // SECTION 5: FOREMAN REPUTATION SCORE CARD
                _buildSection5ForemanReputationCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DEDICATED TAB 2: MEMBER JOIN REQUESTS FULL PAGE ---
  Widget _buildJoinRequestsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadDashboardData();
      },
      color: const Color(0xFF0F4C81),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                        Text('Subscriber Join Requests', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Live streaming applicant requests submitted via 6-digit code.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    Chip(
                      label: Text('${_pendingRequests.length} Live Pending'),
                      backgroundColor: const Color(0xFFD97706),
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_pendingRequests.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.check_circle_outline_rounded, size: 54, color: Color(0xFF007A87)),
                        SizedBox(height: 14),
                        Text('No Pending Join Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 6),
                        Text('All member join requests have been processed. New subscriber requests will appear here live in real time.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _pendingRequests.map((req) => _buildJoinRequestCard(req)).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SECTION 1: EXPOSURE SUMMARY CARD ---
  Widget _buildSection1ExposureSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F4C81),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
              const Text(
                'PRIMARY EXPOSURE RISK METRIC',
                style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Hero(
                tag: 'scheme_type_chip_${_selectedGroup?.id ?? "default"}',
                child: Material(
                  color: Colors.transparent,
                  child: Chip(
                    label: Text('${_selectedGroup?.schemeType ?? "Bidding"} System'),
                    backgroundColor: Colors.white.withOpacity(0.2),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: _totalExposedAmount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Text(
                '₹${value.toStringAsFixed(0)} of next payout at risk',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              );
            },
          ),
          const SizedBox(height: 6),

          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Viewing exposure breakdown for ${_members.length} members.')),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tap to view contributing members breakdown',
                  style: TextStyle(color: Color(0xFF86EFAC), fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, color: Color(0xFF86EFAC), size: 14),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Cycle Group Health (Collected vs Expected):', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontWeight: FontWeight.w600)),
              Text('₹80,000 / ₹1,00,000 (80%)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 0.8),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (context, val, child) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007A87)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 2: MEMBER RISK LIST ---
  Widget _buildSection2MemberRiskList(List<ChitMemberRisk> filteredMembers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Member Default Risk Profiles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
            DropdownButton<String>(
              value: _selectedRiskFilter,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
              underline: const SizedBox(),
              items: ['All', 'High Risk', 'Low Risk'].map((f) => DropdownMenuItem(value: f, child: Text('Filter: $f'))).toList(),
              onChanged: (val) => setState(() => _selectedRiskFilter = val ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 12),

        if (filteredMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const Center(child: Text('No members found matching filter.', style: TextStyle(color: Color(0xFF64748B)))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredMembers.length,
            itemBuilder: (context, index) => _buildMemberRiskCardItem(filteredMembers[index]),
          ),
      ],
    );
  }

  Widget _buildMemberRiskCardItem(ChitMemberRisk member) {
    final riskBadgeColor = member.hasDefaulted ? const Color(0xFFDC2626) : const Color(0xFF166534);
    final riskBadgeBg = member.hasDefaulted ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final riskLabel = member.hasDefaulted ? 'High Risk' : 'Low Risk';

    return GestureDetector(
      onTap: () => _showMemberExplainableRisk(member),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'member_avatar_${member.id}',
              child: CircleAvatar(
                backgroundColor: riskBadgeBg,
                child: Icon(Icons.person, color: riskBadgeColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          member.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: Container(
                          key: ValueKey(riskLabel),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: riskBadgeBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(riskLabel, style: TextStyle(color: riskBadgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Payout: ${member.payoutPosition} • Trend: ${member.paymentTrend}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Exposed: ₹${member.amountExposed.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFD97706))),
                const Text('Tap for risk detail', style: TextStyle(fontSize: 10, color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- SECTION 3: PENDING ACTIONS ---
  Widget _buildSection3PendingActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pending Actions Requiring Approval', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
        const SizedBox(height: 12),

        _buildJoinRequestsSection(),
        const SizedBox(height: 16),

        if (_pendingPayments.isNotEmpty) ...[
          const Text('Payments Awaiting Foreman Confirmation (Handshake)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Column(
            children: _pendingPayments.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF007A87))),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, color: Color(0xFF007A87), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p["memberName"]} sent ₹${(p["amount"] as double).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Txn: ${p["txnId"]} • ${p["date"]}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _confirmPaymentHandshake(p),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A87), foregroundColor: Colors.white),
                    child: const Text('Confirm Receipt'),
                  ),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF0F4C81), size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cycle 1 Payout Release Confirmation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Confirm escrow disbursement for winning auction bidder', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _confirmPayoutRelease,
                child: const Text('Release Payout'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                child: const Text('KYC Submitted', style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
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

  // --- SECTION 4: GROUP MANAGEMENT ---
  Widget _buildSection4GroupManagement() {
    final g = _selectedGroup!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Group Management: ${g.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
              OutlinedButton.icon(
                onPressed: () => _openGroupDetails(g),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('View/Edit Terms & Conditions'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text('Subscriber Payout Order (Locked for assigned positions):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Column(
            children: [
              _buildPayoutOrderTile(slot: 'Month 1 Slot', memberName: 'Foreman Priority', isLocked: true),
              _buildPayoutOrderTile(slot: 'Month 2 Slot', memberName: 'Ramesh Verma (Prized)', isLocked: true),
              _buildPayoutOrderTile(slot: 'Month 3 Slot', memberName: 'Suresh Raina (Unassigned)', isLocked: false),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monthly: ₹${g.monthlyContribution.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Length: ${g.durationMonths} Mos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('Deposit: ₹${g.securityDeposit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF007A87))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutOrderTile({required String slot, required String memberName, required bool isLocked}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(isLocked ? Icons.lock_outline : Icons.drag_indicator, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text('$slot: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(child: Text(memberName, style: const TextStyle(fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: isLocked ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
            child: Text(isLocked ? 'Locked (Agreed Position)' : 'Re-orderable', style: TextStyle(color: isLocked ? const Color(0xFF991B1B) : const Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- SECTION 5: MY REPUTATION (AS FOREMAN) ---
  Widget _buildSection5ForemanReputationCard() {
    return Container(
      width: double.infinity,
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
            children: const [
              Text('FOREMAN REPUTATION SCORE', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              Text('99 / 100 🛡️ Verified Organizer', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Zero default record as organizer • 100% Escrow deposit compliance', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadDashboardData();
      },
      color: const Color(0xFF0F4C81),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      onPressed: () => setState(() => _currentIndex = 3),
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
                          onPressed: () => setState(() => _currentIndex = 3),
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
                Hero(
                  tag: 'group_avatar_${group.id}',
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                    child: Icon(
                      group.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded,
                      color: const Color(0xFF0F4C81),
                      size: 22,
                    ),
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
    final validSelectedGroup = (_selectedGroup != null && _groups.contains(_selectedGroup))
        ? _selectedGroup
        : (_groups.isNotEmpty ? _groups.first : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ChitGroup>(
          value: validSelectedGroup,
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
}
