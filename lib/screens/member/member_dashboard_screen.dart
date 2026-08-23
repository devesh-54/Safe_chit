import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../models/chit_group.dart';
import '../../models/chit_join_request.dart';
import '../../services/supabase_service.dart';

class MemberDashboardScreen extends StatefulWidget {
  final OnboardingState? state;

  const MemberDashboardScreen({
    super.key,
    this.state,
  });

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = true;
  bool _isSearching = false;
  ChitGroup? _searchedGroup;
  List<ChitJoinRequest> _myRequests = [];
  String _username = 'demo_member';

  @override
  void initState() {
    super.initState();
    if (widget.state != null && widget.state!.username.isNotEmpty) {
      _username = widget.state!.username;
    }
    _loadMemberData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _loadMemberData() async {
    setState(() {
      _isLoading = true;
    });

    final requests = await SupabaseService.getMemberJoinRequests(_username);

    setState(() {
      _myRequests = requests;
      _isLoading = false;
    });
  }

  void _searchGroup() async {
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

  void _submitJoinRequest() async {
    if (_searchedGroup == null) return;

    setState(() {
      _isLoading = true;
    });

    final success = await SupabaseService.submitJoinRequest(
      inviteCode: _searchedGroup!.inviteCode,
      memberUsername: _username,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Join request sent to Foreman for "${_searchedGroup!.name}"!'),
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
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.state?.legalName.isNotEmpty == true 
        ? widget.state!.legalName 
        : 'Suresh Raina';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Cream Base
      appBar: AppBar(
        title: const Text(
          '👤 Member Savings Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header Card
                  Container(
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, color: Color(0xFFF59E0B), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '@$_username • Verified Subscriber Profile',
                                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'REPUTATION SCORE',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              '100 / 100 🛡️ Verified',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Section 1: Join a Chit Group via 6-Digit Code
                  const Text(
                    'Join a Chit Group',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the 6-digit invitation code provided by your Foreman to request access.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A6E72)),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
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
                              child: TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 3),
                                decoration: const InputDecoration(
                                  hintText: 'Enter 6-Digit Code (e.g. 849201)',
                                  counterText: '',
                                  prefixIcon: Icon(Icons.vpn_key_outlined, color: Color(0xFF0F4C81)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _isSearching ? null : _searchGroup,
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

                        // Searched Group Preview Card
                        if (_searchedGroup != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2ECE1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2DACD)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified, color: Color(0xFF007A87), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _searchedGroup!.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F4C81),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Code: ${_searchedGroup!.inviteCode}',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Total Pool: ₹${_searchedGroup!.totalPoolSize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('Monthly: ₹${_searchedGroup!.monthlyContribution.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF007A87))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Duration: ${_searchedGroup!.durationMonths} Months • Deposit: ₹${_searchedGroup!.securityDeposit.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E72)),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _submitJoinRequest,
                                    icon: const Icon(Icons.send_rounded, size: 18),
                                    label: const Text('Send Join Request to Foreman'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007A87),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
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

                  // Section 2: My Chit Groups & Requests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Chit Groups',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Chip(
                        label: Text('${_myRequests.length} Groups/Requests'),
                        backgroundColor: const Color(0xFFF2ECE1),
                        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                      ),
                    ],
                  ),
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
                          Icon(Icons.diversity_3_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No Joined Chit Groups Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Enter a 6-digit code above to submit your first join request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: _myRequests.map((req) => _buildRequestCard(req)).toList(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(ChitJoinRequest req) {
    Color badgeBg;
    Color badgeText;
    String statusLabel;
    IconData icon;

    if (req.status == 'approved') {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF166534);
      statusLabel = 'Approved & Active';
      icon = Icons.check_circle_rounded;
    } else if (req.status == 'rejected') {
      badgeBg = const Color(0xFFFEE2E2);
      badgeText = const Color(0xFF991B1B);
      statusLabel = 'Request Declined';
      icon = Icons.cancel_rounded;
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFF92400E);
      statusLabel = 'Pending Foreman Review';
      icon = Icons.hourglass_top_rounded;
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2ECE1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF0F4C81), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.groupName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${req.inviteCode}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: badgeText),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: badgeText, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Requested By: ${req.memberName}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              Text(
                'City: ${req.memberCity}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
