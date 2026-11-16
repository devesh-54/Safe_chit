import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/onboarding_state.dart';
import '../../models/chit_group.dart';
import '../../models/chit_join_request.dart';
import '../../models/chit_payment_record.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import '../common/digital_agreement_modal.dart';
import '../common/group_details_modal.dart';
import '../../widgets/youpi_payment_modal.dart';
import '../payment/payment_checkout_screen.dart';
import '../../models/guarantee_request.dart';
import '../../core/config/guarantor_rules.dart';
import '../../models/security_deposit.dart';
import '../../core/config/deposit_config.dart';
import '../../widgets/razorpay_checkout_modal.dart';
import '../profile/user_profile_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  final OnboardingState? state;

  const MemberDashboardScreen({super.key, this.state});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  final _codeController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSearching = false;
  ChitGroup? _searchedGroup;
  List<ChitJoinRequest> _myRequests = [];
  Map<String, SecurityDeposit> _depositsMap = {};
  Map<String, ChitGroup> _groupDetailsMap = {};
  List<ChitGroup> _publicMarketplaceGroups = [];
  List<GuaranteeRequest> _incomingGuaranteeRequests = [];

  // Metrics
  int _chitsJoinedCount = 0;
  double _monthlyAmountDue = 0.0;
  int _totalDefaultsCount = 0;

  String _username = 'demo_member';
  String _displayName = '';
  String _selectedFilterType = 'All'; // 'All', 'Bidding', 'Random Picking'
  int _currentIndex = 0; // 0: Overview, 1: Joined Schemes, 2: Discovery, 3: Notifications, 4: Profile

  Map<String, bool> _signedAgreementsMap = {};
  List<ChitPaymentRecord> _memberPayments = [];
  String _notificationFilter = 'All'; // 'All', 'Guarantees', 'Approvals', 'Payments'

  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    if (widget.state != null && widget.state!.username.isNotEmpty) {
      _username = widget.state!.username;
      _displayName = widget.state!.legalName;
    }
    _loadMemberData();
    _startRealtimeDataStream();
  }

  bool _isQuietlyRefreshing = false;

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    _codeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startRealtimeDataStream() {
    // Background polling every 8 seconds with re-entrancy protection
    _realtimeTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!mounted) return;
      _loadMemberDataQuietly();
    });
  }

  Future<void> _loadMemberDataQuietly() async {
    if (_isQuietlyRefreshing || !mounted) return;
    _isQuietlyRefreshing = true;

    try {
      final results = await Future.wait([
        SupabaseService.getMemberJoinRequests(_username),
        SupabaseService.getUserDashboardMetrics(_username),
        SupabaseService.getGuaranteeRequestsForGuarantor(_username),
        SupabaseService.getMemberPayments(_username),
      ]);

      final requests = results[0] as List<ChitJoinRequest>;
      final metrics = results[1] as Map<String, dynamic>;
      final incomingGuarantees = results[2] as List<GuaranteeRequest>;
      final memberPayments = results[3] as List<ChitPaymentRecord>;

      final Map<String, SecurityDeposit> depMap = Map.from(_depositsMap);
      final Map<String, ChitGroup> grpMap = Map.from(_groupDetailsMap);
      final Map<String, bool> signedMap = Map.from(_signedAgreementsMap);

      // Concurrently fetch missing group or deposit details
      await Future.wait(requests.map((req) async {
        if (!grpMap.containsKey(req.groupId)) {
          final grp = await SupabaseService.getChitGroupById(req.groupId);
          if (grp != null) grpMap[req.groupId] = grp;
        }

        if (req.isApproved && !depMap.containsKey(req.groupId)) {
          final dep = await SupabaseService.getSecurityDeposit(
            groupId: req.groupId,
            memberId: _username,
          );
          if (dep != null) {
            depMap[req.groupId] = dep;
          }
        }
      }));

      if (mounted) {
        setState(() {
          _myRequests = requests;
          _depositsMap = depMap;
          _groupDetailsMap = grpMap;
          _signedAgreementsMap = signedMap;
          _memberPayments = memberPayments;
          _chitsJoinedCount = metrics['chitsJoined'] as int? ??
              requests.where((r) => r.status == 'approved').length;
          _monthlyAmountDue =
              (metrics['monthlyAmountDue'] as num?)?.toDouble() ?? 0.0;
          _totalDefaultsCount = metrics['totalDefaults'] as int? ?? 0;
          _incomingGuaranteeRequests = incomingGuarantees;
        });
      }
    } catch (_) {
    } finally {
      _isQuietlyRefreshing = false;
    }
  }

  void _loadMemberData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Parallel fetch all top-level data concurrently
      final results = await Future.wait([
        SupabaseService.getUserProfile(_username),
        SupabaseService.getMemberJoinRequests(_username),
        SupabaseService.getUserDashboardMetrics(_username),
        SupabaseService.getGuaranteeRequestsForGuarantor(_username),
        SupabaseService.getPublicChitGroups(
          query: _searchController.text,
          schemeType: _selectedFilterType,
        ),
        SupabaseService.getMemberPayments(_username),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final requests = results[1] as List<ChitJoinRequest>;
      final metrics = results[2] as Map<String, dynamic>;
      final incomingGuarantees = results[3] as List<GuaranteeRequest>;
      final publicGroups = results[4] as List<ChitGroup>;
      final memberPayments = results[5] as List<ChitPaymentRecord>;

      final profileName = profile?['full_name'] as String?;
      if (profileName != null && profileName.trim().isNotEmpty) {
        _displayName = profileName.trim();
      }
      if (profile != null && profile['username'] != null) {
        final pUser = (profile['username'] as String).trim();
        if (pUser.isNotEmpty && pUser.toLowerCase() != _username.toLowerCase()) {
          _username = pUser;
        }
      }

      final Map<String, SecurityDeposit> depMap = {};
      final Map<String, ChitGroup> grpMap = {};
      final Map<String, bool> signedMap = {};

      // Concurrently fetch child group, agreement, and deposit details in parallel
      await Future.wait(requests.map((req) async {
        final childResults = await Future.wait([
          SupabaseService.getChitGroupById(req.groupId),
          SupabaseService.getDigitalAgreement(
            groupId: req.groupId,
            memberUsername: _username,
          ),
          req.isApproved
              ? SupabaseService.getSecurityDeposit(
                  groupId: req.groupId,
                  memberId: _username,
                )
              : Future.value(null),
        ]);

        final grp = childResults[0] as ChitGroup?;
        final agreement = childResults[1] as DigitalAgreement?;
        final dep = childResults[2] as SecurityDeposit?;

        if (grp != null) grpMap[req.groupId] = grp;
        if (agreement != null && agreement.memberSigned) {
          signedMap[req.groupId] = true;
        }
        if (dep != null) {
          depMap[req.groupId] = dep;
        }
      }));

      if (mounted) {
        setState(() {
          _myRequests = requests;
          _depositsMap = depMap;
          _groupDetailsMap = grpMap;
          _signedAgreementsMap = signedMap;
          _memberPayments = memberPayments;
          _chitsJoinedCount =
              metrics['chitsJoined'] as int? ??
              requests.where((r) => r.status == 'approved').length;
          _monthlyAmountDue =
              (metrics['monthlyAmountDue'] as num?)?.toDouble() ?? 0.0;
          _totalDefaultsCount = metrics['totalDefaults'] as int? ?? 0;
          _publicMarketplaceGroups = publicGroups;
          _incomingGuaranteeRequests = incomingGuarantees;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openJoinChitModalWithGuarantor(ChitGroup group) async {
    // Mutual Exclusion Check: Ensure current user is not already a guarantor in this group
    final isAlreadyGuarantor = await SupabaseService.isUserGuarantorInGroup(
      groupId: group.id,
      username: _username,
    );
    if (!mounted) return;
    if (isAlreadyGuarantor) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text(
                'Cannot Join Group',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: Text(
            'You are already acting as a guarantor for a member in "${group.name}".\n\n'
            'A guarantor cannot join the same chit group as a member to protect against dual-default risk.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final guarantorController = TextEditingController();
    String selectedRelation = 'Friend';
    String? inlineError;
    bool isSubmitting = false;
    final bool guarantorRequired = isGuarantorRequired(
      joinedChitsCount: _chitsJoinedCount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
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
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F4C81).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.group_add_rounded,
                            color: Color(0xFF0F4C81),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Pool: ₹${group.totalPoolSize.toStringAsFixed(0)} • ₹${group.monthlyContribution.toStringAsFixed(0)}/mo • ${group.durationMonths} Mos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Requirement Banner if new member (< 2 groups)
                    if (guarantorRequired) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.shield,
                              color: Color(0xFF1D4ED8),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Guarantor Required: New members who have joined fewer than 2 groups must nominate a guarantor.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E40AF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: Color(0xFF0F4C81),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          guarantorRequired
                              ? 'Nominate a Guarantor (Mandatory)'
                              : 'Nominate a Guarantor (Optional)',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      guarantorRequired
                          ? 'Enter the username of a registered member who will guarantee your chit installments.'
                          : 'You have joined >= 2 groups. Providing a guarantor is optional.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: guarantorController,
                      decoration: InputDecoration(
                        labelText: guarantorRequired
                            ? "Guarantor's Username *"
                            : "Guarantor's Username",
                        hintText: "e.g. member_demo",
                        prefixIcon: const Icon(Icons.alternate_email, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (_) {
                        if (inlineError != null) {
                          setModalState(() => inlineError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRelation,
                      decoration: InputDecoration(
                        labelText: 'Relationship to Guarantor',
                        prefixIcon: const Icon(Icons.people_outline, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Family',
                          child: Text('Family'),
                        ),
                        DropdownMenuItem(
                          value: 'Friend',
                          child: Text('Friend'),
                        ),
                        DropdownMenuItem(
                          value: 'Colleague',
                          child: Text('Colleague'),
                        ),
                        DropdownMenuItem(
                          value: 'Neighbour',
                          child: Text('Neighbour'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedRelation = val);
                        }
                      },
                    ),
                    if (inlineError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                inlineError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(modalContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final guarantorText = guarantorController
                                        .text
                                        .trim();

                                    // Condition: New members (< 2 groups) CANNOT join without guarantor
                                    if (guarantorRequired &&
                                        guarantorText.isEmpty) {
                                      setModalState(() {
                                        inlineError =
                                            'New members (fewer than 2 joined groups) must provide a guarantor to apply.';
                                      });
                                      return;
                                    }

                                    // Sanity check 1: cannot name themselves
                                    if (guarantorText.isNotEmpty &&
                                        guarantorText.toLowerCase() ==
                                            _username.toLowerCase()) {
                                      setModalState(() {
                                        inlineError =
                                            'You cannot name yourself as guarantor.';
                                      });
                                      return;
                                    }

                                    // Sanity check 2: guarantor username must exist
                                    if (guarantorText.isNotEmpty) {
                                      setModalState(() => isSubmitting = true);
                                      final exists =
                                          await SupabaseService.checkUserExists(
                                            guarantorText,
                                          );
                                      if (!exists) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          inlineError =
                                              "Guarantor username '@$guarantorText' does not exist.";
                                        });
                                        return;
                                      }

                                      final ruleResult =
                                          validateGuarantorRequest(
                                            memberUsername: _username,
                                            guarantorUsername: guarantorText,
                                            relation: selectedRelation,
                                            chitPoolValue: group.totalPoolSize,
                                          );
                                      if (!ruleResult.isAllowed) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          inlineError =
                                              ruleResult.reason ??
                                              'Guarantor request not allowed.';
                                        });
                                        return;
                                      }

                                      // Mutual exclusion: nominated guarantor cannot already be a member of this group
                                      final isGuarantorMember =
                                          await SupabaseService.isUserMemberOfGroup(
                                            groupId: group.id,
                                            username: guarantorText,
                                          );
                                      if (isGuarantorMember) {
                                        setModalState(() {
                                          isSubmitting = false;
                                          inlineError =
                                              "@$guarantorText is already a member of this chit group. A member and their guarantor cannot belong to the same chit group.";
                                        });
                                        return;
                                      }
                                    }

                                    Navigator.pop(modalContext);

                                    // 1. Prepare Digital Chit Agreement under Section 6 Chit Funds Act
                                    final agreement = DigitalAgreement(
                                      id: 'agreement_${group.id}_${DateTime.now().millisecondsSinceEpoch}',
                                      groupId: group.id,
                                      groupName: group.name,
                                      foremanUsername: 'foreman',
                                      foremanName: 'Rajesh Kumar (Foreman)',
                                      memberUsername: _username,
                                      memberName: _displayName.isNotEmpty ? _displayName : 'Member $_username',
                                      poolAmount: group.totalPoolSize,
                                      durationMonths: group.durationMonths,
                                      monthlyContribution: group.monthlyContribution,
                                      schemeType: group.schemeType,
                                      createdAt: DateTime.now(),
                                      agreementText: DigitalAgreement.generateLegalAgreementText(
                                        groupName: group.name,
                                        foremanName: 'Rajesh Kumar (Foreman)',
                                        memberName: _displayName.isNotEmpty ? _displayName : 'Member $_username',
                                        poolAmount: group.totalPoolSize,
                                        durationMonths: group.durationMonths,
                                        monthlyContribution: group.monthlyContribution,
                                        schemeType: group.schemeType,
                                        securityDeposit: group.securityDeposit,
                                      ),
                                    );

                                    // 2. Present Digital Agreement in Full Screen
                                    await DigitalAgreementModal.open(
                                      context: context,
                                      agreement: agreement,
                                      isForeman: false,
                                      onSigned: () async {
                                        await SupabaseService.saveDigitalAgreement(
                                          agreement.copyWith(
                                            memberSigned: true,
                                            memberSignedAt: DateTime.now(),
                                            status: 'member_signed',
                                          ),
                                        );

                                        final joinSuccess =
                                            await SupabaseService.submitJoinRequest(
                                          inviteCode: group.inviteCode,
                                          memberUsername: _username,
                                          guarantorUsername:
                                              guarantorText.isEmpty
                                                  ? null
                                                  : guarantorText,
                                          guarantorRelation:
                                              guarantorText.isEmpty
                                                  ? null
                                                  : selectedRelation,
                                        );

                                        if (mounted) {
                                          _loadMemberData();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                joinSuccess
                                                    ? (guarantorText.isNotEmpty
                                                        ? 'Agreement signed & request sent with guarantor @$guarantorText!'
                                                        : 'Agreement signed & join request submitted to Foreman!')
                                                    : 'Join request failed due to mutual exclusion or restriction.',
                                              ),
                                              backgroundColor: joinSuccess
                                                  ? const Color(0xFF0F4C81)
                                                  : const Color(0xFFDC2626),
                                            ),
                                          );
                                        }
                                      },
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.gavel_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Review Agreement & Request to Join',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showGuaranteeRequestsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.8,
              ),
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xFF0F4C81),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Guarantee Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Members who have asked you to serve as their guarantor for chit group membership.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _incomingGuaranteeRequests.isEmpty
                        ? const Center(
                            child: Text(
                              'No guarantee requests received yet.',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _incomingGuaranteeRequests.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final req = _incomingGuaranteeRequests[index];
                              final isPending = req.status == 'pending';
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isPending
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFE2E8F0),
                                    width: isPending ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: const Color(
                                            0xFF0F4C81,
                                          ).withOpacity(0.1),
                                          child: const Icon(
                                            Icons.person,
                                            color: Color(0xFF0F4C81),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          UserProfileScreen(
                                                        username: req.memberId,
                                                        isOwnProfile: false,
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        req.memberName ??
                                                            req.memberId,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                          color:
                                                              Color(0xFF0F172A),
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          decorationColor:
                                                              Color(0xFFCBD5E1),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.open_in_new_rounded,
                                                      size: 13,
                                                      color: Color(0xFF007A87),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '@${req.memberId} • Relation: ${req.relation}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF007A87),
                                                  fontWeight: FontWeight.w600,
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
                                            color: req.status == 'accepted'
                                                ? const Color(0xFFDCFCE7)
                                                : (req.status == 'declined'
                                                      ? const Color(0xFFFEE2E2)
                                                      : const Color(
                                                          0xFFDCFCE7,
                                                        )),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            req.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: req.status == 'accepted'
                                                  ? const Color(0xFF166534)
                                                  : (req.status == 'declined'
                                                        ? const Color(
                                                            0xFF991B1B,
                                                          )
                                                        : const Color(
                                                            0xFF166534,
                                                          )),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Chit Scheme',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                req.groupName.isNotEmpty
                                                    ? req.groupName
                                                    : 'Chit Group',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Chit Value',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                '₹${req.chitValue.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F4C81),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Duration',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                              Text(
                                                '${req.durationMonths} Mos',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              req.consentText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () async {
                                                final success =
                                                    await SupabaseService.respondToGuaranteeRequest(
                                                      requestId: req.id,
                                                      accept: false,
                                                    );
                                                if (!context.mounted) return;
                                                if (!success) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Failed to decline guarantee request. Please try again.',
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFDC2626,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                final updated =
                                                    await SupabaseService.getGuaranteeRequestsForGuarantor(
                                                      _username,
                                                    );
                                                setState(
                                                  () =>
                                                      _incomingGuaranteeRequests =
                                                          updated,
                                                );
                                                setModalState(() {});
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Guarantee request declined.',
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(
                                                  0xFFDC2626,
                                                ),
                                                side: const BorderSide(
                                                  color: Color(0xFFDC2626),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Decline'),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                // Mutual exclusion: User cannot accept guarantee if already a member of this group
                                                final isMember =
                                                    await SupabaseService.isUserMemberOfGroup(
                                                      groupId: req.groupId,
                                                      username: _username,
                                                    );
                                                if (!context.mounted) return;
                                                if (isMember) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Cannot accept: You are already a member of this chit group. A member and their guarantor cannot belong to the same chit group.',
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFDC2626,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                final success =
                                                    await SupabaseService.respondToGuaranteeRequest(
                                                      requestId: req.id,
                                                      accept: true,
                                                    );
                                                if (!context.mounted) return;
                                                if (!success) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Failed to accept guarantee request (mutual exclusion or conflict).',
                                                      ),
                                                      backgroundColor: Color(
                                                        0xFFDC2626,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                final updated =
                                                    await SupabaseService.getGuaranteeRequestsForGuarantor(
                                                      _username,
                                                    );
                                                setState(
                                                  () =>
                                                      _incomingGuaranteeRequests =
                                                          updated,
                                                );
                                                setModalState(() {});
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Guarantee request accepted! Status saved in Supabase.',
                                                    ),
                                                    backgroundColor: Color(
                                                      0xFF166534,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF166534,
                                                ),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Accept'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        req.status == 'accepted'
                                            ? '✓ You accepted this request'
                                            : '✗ You declined this request',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: req.status == 'accepted'
                                              ? const Color(0xFF166534)
                                              : const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openDigitalAgreement(ChitJoinRequest req) async {
    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: req.groupName,
      foremanName: 'Rajesh Kumar (Foreman)',
      memberName: req.memberName,
      poolAmount: 5.0, // fallback pool representation
      durationMonths: 5,
      monthlyContribution: 1.0,
      schemeType: 'Bidding',
      securityDeposit: 1.0,
    );

    var agreement = await SupabaseService.getDigitalAgreement(
      groupId: req.groupId,
      memberUsername: _username,
    );

    agreement ??= DigitalAgreement(
      id: 'agreement_${req.groupId}',
      groupId: req.groupId,
      groupName: req.groupName,
      foremanUsername: 'foreman_admin',
      foremanName: 'Rajesh Kumar (Foreman)',
      memberUsername: _username,
      memberName: req.memberName,
      poolAmount: 5.0,
      durationMonths: 5,
      monthlyContribution: 1.0,
      schemeType: 'Bidding',
      agreementText: agreementText,
      createdAt: DateTime.now(),
    );

    if (mounted) {
      DigitalAgreementModal.open(
        context: context,
        agreement: agreement!,
        isForeman: false,
        onSigned: () {
          _loadMemberData();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName.isNotEmpty
        ? _displayName
        : (widget.state?.legalName.isNotEmpty == true
              ? widget.state!.legalName
              : _username);

    final hasPendingNotifications =
        _incomingGuaranteeRequests.any((r) => r.status == 'pending') ||
            _myRequests.any((r) => r.isApproved);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _currentIndex == 4
          ? null
          : AppBar(
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Member Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              elevation: 0,
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      tooltip: 'Notifications',
                      onPressed: () {
                        setState(() => _currentIndex = 3);
                      },
                    ),
                    if (hasPendingNotifications)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    _loadMemberData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Refreshed member data!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Log Out',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0F4C81)),
              )
            : IndexedStack(
                index: _currentIndex,
                children: [
                  _buildOverviewDashboard(displayName),
                  _buildJoinedChitsPage(),
                  _buildMarketplacePage(),
                  _buildNotificationCenterPage(),
                  UserProfileScreen(
                    username: _username,
                    isOwnProfile: true,
                    initialRole: 'member',
                  ),
                ],
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0F4C81),
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(
              Icons.groups_rounded,
              _myRequests.any((r) => r.isApproved),
            ),
            label: 'Joined Schemes',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(
              Icons.storefront_outlined,
              _publicMarketplaceGroups.isNotEmpty,
            ),
            label: 'Discovery',
          ),
          BottomNavigationBarItem(
            icon: _buildBadgeIcon(
              Icons.notifications_rounded,
              hasPendingNotifications,
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(IconData iconData, bool showBadge) {
    if (!showBadge) return Icon(iconData);
    return Stack(
      children: [
        Icon(iconData),
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
          ),
        ),
      ],
    );
  }

  void _openJoinChitBottomSheet() {
    setState(() {
      _codeController.clear();
      _searchedGroup = null;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Join via 6-Digit Code',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the private 6-digit code provided by your Foreman to request direct access.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter 6-Digit Code',
                            counterText: '',
                            prefixIcon: Icon(
                              Icons.vpn_key_outlined,
                              color: Color(0xFF0F4C81),
                            ),
                            fillColor: Color(0xFFF8FAFC),
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSearching
                            ? null
                            : () async {
                                setSheetState(() {
                                  _isSearching = true;
                                  _searchedGroup = null;
                                });

                                final code = _codeController.text.trim();
                                if (code.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a 6-digit Chit Group code.',
                                      ),
                                      backgroundColor: Color(0xFF0F4C81),
                                    ),
                                  );
                                  setSheetState(() {
                                    _isSearching = false;
                                  });
                                  return;
                                }

                                final group =
                                    await SupabaseService.getGroupByInviteCode(
                                      code,
                                    );

                                setSheetState(() {
                                  _isSearching = false;
                                  _searchedGroup = group;
                                });

                                if (group == null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'No group found for code "$code". Please verify with Foreman.',
                                      ),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Search',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
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
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF007A87),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchedGroup!.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(_searchedGroup!.schemeType),
                                backgroundColor: const Color(0xFF0F4C81),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Pool: ₹${_searchedGroup!.totalPoolSize.toStringAsFixed(0)} • Monthly: ₹${_searchedGroup!.monthlyContribution.toStringAsFixed(0)}/mo',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openJoinChitModalWithGuarantor(
                                  _searchedGroup!,
                                );
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Send Join Request to Foreman'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A87),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
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
          },
        );
      },
    );
  }

  Widget _buildOverviewDashboard(String displayName) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Banner
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        username: _username,
                        isOwnProfile: true,
                        initialRole: 'member',
                      ),
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '@$_username • Verified Subscriber',
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007A87),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'View Performance & Score →',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mandated Metrics Row
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
                      color: _totalDefaultsCount > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Welcome status card
              Container(
                width: double.infinity,
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
                        const Icon(
                          Icons.waving_hand_rounded,
                          color: Color(0xFF059669),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Welcome back, $displayName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All your joined chit schemes are in excellent standing. You can manage your payout positions, confirm monthly collections, sign legal agreements, and review your reputation score from the left navigation menu.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentIndex = 1;
                              });
                            },
                            icon: const Icon(Icons.groups_rounded, size: 16),
                            label: const Text(
                              'View Joined Schemes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentIndex = 2;
                              });
                            },
                            icon: const Icon(
                              Icons.storefront_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Discover Public Chits',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F4C81),
                              side: const BorderSide(color: Color(0xFF0F4C81)),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildUpcomingDuesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingDuesCard() {
    final approvedGroups = _myRequests.where((r) => r.isApproved).toList();
    if (approvedGroups.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: const [
              Icon(Icons.payment_rounded, color: Color(0xFF0F4C81), size: 22),
              SizedBox(width: 8),
              Text(
                'Upcoming Monthly Installments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Instant 0% fee P2P UPI payments directly to Foreman Escrow account.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ...approvedGroups.map((req) {
            return FutureBuilder<ChitGroup?>(
              future: SupabaseService.getChitGroupById(req.groupId),
              builder: (context, snapshot) {
                final group = snapshot.data;
                final amount = group?.monthlyContribution ?? 1.0;
                final cycle = (group?.currentCycle ?? 0) + 1;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.groupName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Due Date: 10th of this month • Cycle $cycle',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              amount < 10
                                  ? '₹${amount.toStringAsFixed(2)}'
                                  : '₹${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF0F4C81),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          if (group != null && mounted) {
                            PaymentCheckoutScreen.open(
                              context: context,
                              group: group,
                              currentUsername: _username,
                              onPaymentSuccess: () {
                                _loadMemberData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '🎉 Monthly installment verified and recorded in SafeChit ledger!',
                                    ),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              },
                            );
                          }
                        },
                        icon: const Icon(Icons.payment_rounded, size: 16),
                        label: const Text('Pay Installment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJoinedChitsPage() {
    final joinedGroups = _myRequests.where((r) => r.isApproved).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Joined Chit Schemes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage and open dashboards for all active and approved chit groups you are a member of.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              if (joinedGroups.isEmpty)
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
                      Icon(
                        Icons.groups_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No Joined Chit Schemes Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Browse the Discovery tab to explore verified public chit schemes or search by private 6-digit code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: joinedGroups
                      .map((req) => _buildJoinedRequestCard(req))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCenterPage() {
    final pendingGuarantees = _incomingGuaranteeRequests
        .where((r) => r.status == 'pending')
        .toList();
    final acceptedGuarantees = _incomingGuaranteeRequests
        .where((r) => r.status == 'accepted')
        .toList();

    final totalGuarantees = _incomingGuaranteeRequests.length;
    final totalChitApprovals = _myRequests.length;
    final totalPayments = _memberPayments.length + _depositsMap.length;

    return RefreshIndicator(
      onRefresh: () async => _loadMemberData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4C81).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF0F4C81),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Guarantees, payments, and chit scheme approvals in one place',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildNotificationFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildNotificationFilterChip('Guarantees', totalGuarantees),
                      const SizedBox(width: 8),
                      _buildNotificationFilterChip(
                        'Chit Approvals',
                        totalChitApprovals,
                      ),
                      const SizedBox(width: 8),
                      _buildNotificationFilterChip('Payments', totalPayments),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Active Guarantor Backing banner
                if (acceptedGuarantees.isNotEmpty &&
                    (_notificationFilter == 'All' ||
                        _notificationFilter == 'Guarantees')) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: Color(0xFF166534),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Guarantor Backing (${acceptedGuarantees.length})',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'You are actively backing: ${acceptedGuarantees.map((g) => '@${g.memberId}').join(', ')}',
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
                  ),
                ],

                // Notification Content
                _buildNotificationItemsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationFilterChip(String label, int? count) {
    final isSelected = _notificationFilter == label;
    return ChoiceChip(
      label: Text(count != null && count > 0 ? '$label ($count)' : label),
      selected: isSelected,
      onSelected: (_) => setState(() => _notificationFilter = label),
      selectedColor: const Color(0xFF0F4C81),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF0F4C81) : const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildNotificationItemsList() {
    final List<Widget> items = [];

    // 1. Guarantee Requests
    if (_notificationFilter == 'All' || _notificationFilter == 'Guarantees') {
      final sortedGuarantees =
          List<GuaranteeRequest>.from(_incomingGuaranteeRequests)
            ..sort((a, b) {
              if (a.status == 'pending' && b.status != 'pending') return -1;
              if (b.status == 'pending' && a.status != 'pending') return 1;
              return b.createdAt.compareTo(a.createdAt);
            });

      for (var req in sortedGuarantees) {
        items.add(_buildGuaranteeNotificationCard(req));
      }
    }

    // 2. Chit Approvals & Join Requests
    if (_notificationFilter == 'All' ||
        _notificationFilter == 'Chit Approvals') {
      for (var req in _myRequests) {
        items.add(_buildChitApprovalNotificationCard(req));
      }
    }

    // 3. Payments & Deposits
    if (_notificationFilter == 'All' || _notificationFilter == 'Payments') {
      for (var p in _memberPayments) {
        items.add(_buildPaymentNotificationCard(p));
      }
      _depositsMap.forEach((groupId, dep) {
        items.add(_buildDepositNotificationCard(dep));
      });
    }

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'You have no updates in this category right now.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildGuaranteeNotificationCard(GuaranteeRequest req) {
    final isPending = req.status == 'pending';
    final isAccepted = req.status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending
              ? const Color(0xFFF59E0B)
              : (isAccepted
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFE2E8F0)),
          width: isPending ? 1.5 : 1.0,
        ),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF3C7)
                      : (isAccepted
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAccepted
                      ? Icons.verified_user_rounded
                      : (isPending
                          ? Icons.shield_outlined
                          : Icons.cancel_rounded),
                  color: isAccepted
                      ? const Color(0xFF166534)
                      : (isPending
                          ? const Color(0xFFB45309)
                          : const Color(0xFF991B1B)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.memberName?.isNotEmpty == true
                          ? req.memberName!
                          : 'Member @${req.memberId}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Guarantor Nomination • Relation: ${req.relation}',
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
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF3C7)
                      : (isAccepted
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPending
                      ? 'ACTION REQUIRED'
                      : (isAccepted ? 'ACCEPTED' : 'DECLINED'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isPending
                        ? const Color(0xFFB45309)
                        : (isAccepted
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Nominated you as guarantor for chit scheme "${req.groupName}" (Pool: ₹${req.chitValue.toStringAsFixed(0)}, ${req.durationMonths} Months).',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _respondGuarantee(req: req, accept: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _respondGuarantee(req: req, accept: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4C81),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Accept & Back',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChitApprovalNotificationCard(ChitJoinRequest req) {
    final isApproved = req.status == 'approved';
    final isPending = req.status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF86EFAC)
              : (isPending
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFFECACA)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFDCFCE7)
                      : (isPending
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isApproved
                      ? Icons.how_to_reg_rounded
                      : (isPending
                          ? Icons.hourglass_top_rounded
                          : Icons.cancel_rounded),
                  color: isApproved
                      ? const Color(0xFF166534)
                      : (isPending
                          ? const Color(0xFFB45309)
                          : const Color(0xFF991B1B)),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.groupName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Chit Scheme Membership',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFDCFCE7)
                      : (isPending
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFFEE2E2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isApproved
                      ? 'APPROVED'
                      : (isPending ? 'PENDING HOST' : 'DECLINED'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isApproved
                        ? const Color(0xFF166534)
                        : (isPending
                            ? const Color(0xFFB45309)
                            : const Color(0xFF991B1B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isApproved
                ? '🎉 Foreman approved your join request! You are now an active subscriber in "${req.groupName}".'
                : (isPending
                    ? 'Your join request for "${req.groupName}" has been submitted to the foreman for review.'
                    : 'Your join request for "${req.groupName}" was declined by the foreman.'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
          ),
          if (isApproved) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openMemberDashboard(req),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text(
                  'Open Chit Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F4C81),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentNotificationCard(ChitPaymentRecord p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF0369A1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${p.amount.toStringAsFixed(0)} • ${p.groupName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.status,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Cycle ${p.cycle} Installment via ${p.paymentMethod} • UTR: ${p.utr ?? p.id}',
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
    );
  }

  Widget _buildDepositNotificationCard(SecurityDeposit dep) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
            decoration: BoxDecoration(
              color: dep.isHeld
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              dep.isHeld ? Icons.lock_rounded : Icons.pending_actions_rounded,
              color: dep.isHeld
                  ? const Color(0xFF166534)
                  : const Color(0xFFB45309),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Deposit: ₹${dep.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dep.isHeld
                      ? 'Safely held in Foreman Escrow for your chit scheme.'
                      : 'Pending deposit payment.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: dep.isHeld
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dep.displayStatus.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: dep.isHeld
                    ? const Color(0xFF166534)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _respondGuarantee({
    required GuaranteeRequest req,
    required bool accept,
  }) async {
    if (accept) {
      final isMember = await SupabaseService.isUserMemberOfGroup(
        groupId: req.groupId,
        username: _username,
      );
      if (!mounted) return;
      if (isMember) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot accept: You are already a member of this chit group. A member and their guarantor cannot belong to the same chit group.',
            ),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }
    }

    final success = await SupabaseService.respondToGuaranteeRequest(
      requestId: req.id,
      accept: accept,
    );
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Failed to accept guarantee request (mutual exclusion or conflict).'
                : 'Failed to decline guarantee request.',
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? '🎉 You accepted the guarantee request for @${req.memberId} in ${req.groupName}!'
              : 'Guarantee request declined.',
        ),
        backgroundColor:
            accept ? const Color(0xFF166534) : const Color(0xFF64748B),
      ),
    );
    _loadMemberData();
  }

  Widget _buildGuarantorHubPage() {
    final activeGuarantees = _incomingGuaranteeRequests
        .where((r) => r.status == 'accepted')
        .toList();
    final pendingGuarantees = _incomingGuaranteeRequests
        .where((r) => r.status == 'pending')
        .toList();
    final totalPoolGuaranteed = activeGuarantees.fold<double>(
      0.0,
      (sum, r) => sum + r.chitValue,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF0F4C81),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Guarantor Hub',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Monitor members you are backing, their chit groups, and repayment progress.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'ACTIVE GUARANTEES',
                      value: ' Active',
                      icon: Icons.shield_rounded,
                      color: const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'TOTAL GUARANTEED',
                      value: '₹',
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF0F4C81),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'PENDING REQUESTS',
                      value: ' Requests',
                      icon: Icons.pending_actions_rounded,
                      color: const Color(0xFF0F4C81),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Guaranteed Members & Chit Schemes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Live progress, monthly standing, and active chit schemes for members you guarantee.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (_incomingGuaranteeRequests.isEmpty)
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
                      Icon(
                        Icons.shield_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No Guaranteed Members Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'When another member nominates you as their guarantor to join a chit scheme, their groups and repayment standing will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._incomingGuaranteeRequests
                    .map((req) => _buildGuaranteedMemberCard(req))
                    .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuaranteedMemberCard(GuaranteeRequest req) {
    final isAccepted = req.status == 'accepted';
    final isPending = req.status == 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAccepted
              ? const Color(0xFF10B981).withOpacity(0.4)
              : (isPending
                    ? const Color(0xFF059669).withOpacity(0.35)
                    : const Color(0xFFE2E8F0)),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF0F4C81).withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF0F4C81),
                  size: 22,
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
                              username: req.memberId,
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
                              req.memberName?.isNotEmpty == true
                                  ? req.memberName!
                                  : 'Member @${req.memberId}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: Color(0xFF007A87),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '@${req.memberId} • Relation: ${req.relation}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF007A87),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isAccepted
                      ? const Color(0xFFDCFCE7)
                      : (req.status == 'declined'
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAccepted
                          ? Icons.check_circle_rounded
                          : (isPending
                                ? Icons.hourglass_top_rounded
                                : Icons.cancel_rounded),
                      size: 14,
                      color: isAccepted
                          ? const Color(0xFF166534)
                          : (req.status == 'declined'
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAccepted
                          ? 'Active Guarantee'
                          : (isPending ? 'Pending Consent' : 'Declined'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAccepted
                            ? const Color(0xFF166534)
                            : (req.status == 'declined'
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.group_work_rounded,
                      size: 16,
                      color: Color(0xFF0F4C81),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        req.groupName.isNotEmpty
                            ? req.groupName
                            : 'Chit Scheme',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGroupStatItem(
                      'Pool Size',
                      '₹${req.chitValue.toStringAsFixed(0)}',
                    ),
                    _buildGroupStatItem(
                      'Duration',
                      '${req.durationMonths} Months',
                    ),
                    _buildGroupStatItem(
                      'Your Exposure',
                      '₹${req.chitValue.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isAccepted
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAccepted
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isAccepted ? Icons.trending_up_rounded : Icons.info_outline,
                  size: 18,
                  color: isAccepted
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAccepted
                        ? 'Member Progress: In Good Standing • Payments Current • 0 Defaults'
                        : 'Awaiting your acceptance to activate guarantee coverage for this group.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isAccepted
                          ? const Color(0xFF166534)
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final success =
                          await SupabaseService.respondToGuaranteeRequest(
                            requestId: req.id,
                            accept: false,
                          );
                      if (!mounted) return;
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to decline guarantee request. Please try again.',
                            ),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }
                      _loadMemberData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Guarantee request declined.'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final success =
                          await SupabaseService.respondToGuaranteeRequest(
                            requestId: req.id,
                            accept: true,
                          );
                      if (!mounted) return;
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to accept guarantee request. Please try again.',
                            ),
                            backgroundColor: Color(0xFFDC2626),
                          ),
                        );
                        return;
                      }
                      _loadMemberData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Guarantee accepted! You can now monitor their progress here.',
                          ),
                          backgroundColor: Color(0xFF166534),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF166534),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Accept & Guarantee'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketplacePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Header
              const Text(
                'Public Discovery Marketplace',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Discover and join verified public chit schemes hosted by licensed foremen.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Search Input Bar
              TextField(
                controller: _searchController,
                onChanged: (_) => _loadMemberData(),
                decoration: InputDecoration(
                  hintText: 'Search schemes by name or code...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0F4C81),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Action: Enter 6-Digit Private Code
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openJoinChitBottomSheet,
                      icon: const Icon(Icons.pin_outlined, size: 16),
                      label: const Text(
                        'Join Private Chit with 6-Digit Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F4C81),
                        side: const BorderSide(color: Color(0xFF0F4C81), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Bidding', 'Random Picking'].map((type) {
                    final isSelected = _selectedFilterType == type;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(
                          type == 'All' ? 'All Schemes' : '$type System',
                        ),
                        selectedColor: const Color(0xFF0F4C81),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
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
                      Icon(
                        Icons.storefront_outlined,
                        size: 48,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No Public Schemes Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Foremen have not listed public schemes matching this filter.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: _publicMarketplaceGroups
                      .map((group) => _buildMarketplaceSchemeCard(group))
                      .toList(),
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedRequestCard(ChitJoinRequest req) {
    final group = _groupDetailsMap[req.groupId];
    final dep = _depositsMap[req.groupId];

    final poolSize = group?.totalPoolSize ?? 0.0;
    final monthly = group?.monthlyContribution ?? 0.0;
    final duration = group?.durationMonths ?? 0;
    final schemeType = group?.schemeType ?? 'Bidding';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMemberDashboard(req),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F4C81).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: Color(0xFF0F4C81),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req.groupName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code: ${req.inviteCode}${req.memberCity.isNotEmpty ? " • ${req.memberCity}" : ""}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Approved & Active',
                        style: TextStyle(
                          color: Color(0xFF166534),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pool Value',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            poolSize > 0 ? '₹${poolSize.toStringAsFixed(0)}' : '₹10,00,000',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Due',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            monthly > 0 ? '₹${monthly.toStringAsFixed(0)}/mo' : '₹10,000/mo',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007A87),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Duration / Type',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            duration > 0 ? '$duration Mos ($schemeType)' : '10 Mos ($schemeType)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (dep != null && dep.isHeld) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: Color(0xFF166534),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Deposit: Held (₹${dep.amount.toStringAsFixed(0)})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Text(
                      'Tap to open group dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  group.schemeType == 'Bidding'
                      ? Icons.gavel_rounded
                      : Icons.casino_rounded,
                  color: const Color(0xFF0F4C81),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Hosted in ${group.city} • Code: ${group.inviteCode}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C81),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${group.schemeType} System',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Pool',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${group.totalPoolSize.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Cont.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${group.monthlyContribution.toStringAsFixed(0)}/mo',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF007A87),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duration',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${group.durationMonths} Mos',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openJoinChitModalWithGuarantor(group),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Send Join Request to Foreman'),
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
    );
  }

  void _openMemberDashboard(ChitJoinRequest req) async {
    setState(() => _isLoading = true);
    final group = await SupabaseService.getChitGroupById(req.groupId);
    setState(() => _isLoading = false);

    if (group != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailsModal(
            group: group,
            isForeman: false,
            currentUsername: _username,
            isApproved: req.status == 'approved',
          ),
        ),
      );
    }
  }
}
