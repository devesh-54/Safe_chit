import 'dart:io';
import '../models/onboarding_state.dart';
import '../models/chit_group.dart';
import '../models/member_risk.dart';
import '../models/chit_join_request.dart';
import '../models/digital_agreement.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://sjemdgjcjjozaljhzvzm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZW1kZ2pjampvemFsamh6dnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjgwMDgsImV4cCI6MjEwMjgwNDAwOH0.EdvMnsMwI0HoX8p55hJE5LfYsYTM5rs4M8ZvoDrDB5A';

  static bool _isInitialized = false;

  // In-memory fallback registry for offline/local simulation
  static final Set<String> _registeredUsernames = {'admin', 'host', 'demo', 'foreman_admin', 'member_demo'};
  static final Map<String, String> _userCredentials = {
    'admin': 'admin123',
    'host': 'host123',
    'demo': 'demo123',
    'foreman_admin': 'foreman123',
    'member_demo': 'member123',
  };

  /// Initialize Supabase client
  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final isFlutterTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (!isFlutterTest) {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
      }
      if (kDebugMode) {
        print('✅ Supabase initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase initialization note: $e');
      }
    }
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Check whether a username is unique by querying Supabase table 'profiles' or 'users'.
  static Future<bool> isUsernameUnique(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;

    // Check in-memory fallback list first
    if (_registeredUsernames.contains(cleanUsername)) {
      return false;
    }

    try {
      final supaClient = client;
      if (supaClient != null) {
        // Query Supabase table 'user_onboardings'
        try {
          final response = await supaClient
              .from('user_onboardings')
              .select('username')
              .eq('username', cleanUsername)
              .maybeSingle();

          if (response != null) {
            return false;
          }
        } catch (_) {
          // Fallback query to 'profiles'
          final response = await supaClient
              .from('profiles')
              .select('username')
              .eq('username', cleanUsername)
              .maybeSingle();

          if (response != null) {
            return false;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase query notice (using fallback local check): $e');
      }
    }

    return true;
  }

  /// Register username and password to Supabase and local cache
  /// Returns null if successful, or an error message string if failed.
  static Future<String?> registerUser({
    required String username,
    required String password,
    required OnboardingState state,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    // Check uniqueness
    final unique = await isUsernameUnique(cleanUsername);
    if (!unique) return 'Username is already taken.';

    // Store in local fallback map
    _registeredUsernames.add(cleanUsername);
    _userCredentials[cleanUsername] = password;

    try {
      final supaClient = client;
      if (supaClient == null) {
        return 'Supabase client is not initialized.';
      }

      try {
        await supaClient.from('user_onboardings').upsert({
          'username': cleanUsername,
          'password': password,
          'role': state.role?.name,
          
          // Account Setup
          'mobile_number': state.mobileNumber,
          'is_mobile_verified': state.mobileStatus == VerificationStatus.verified,
          'email': state.emailAddress,
          'is_email_verified': state.emailStatus == VerificationStatus.verified,
          
          // Personal Details
          'full_name': state.legalName,
          'date_of_birth': state.dob?.toIso8601String().split('T')[0],
          'gender': state.gender,
          
          // Government ID
          'pan_number': state.panNumber,
          'aadhaar_number': state.aadhaarNumber,
          'id_document_url': state.idDocumentPath,
          'is_gov_id_verified': state.govIdStatus == VerificationStatus.verified,
          
          // Address Details
          'perm_address': state.permAddress,
          'perm_city': state.permCity,
          'perm_state': state.permState,
          'perm_pin_code': state.permPinCode,
          'is_current_same_as_permanent': state.isCurrentSameAsPermanent,
          'curr_address': state.currAddress,
          'curr_city': state.currCity,
          'curr_state': state.currState,
          'curr_pin_code': state.currPinCode,
          
          // Bank Account
          'bank_account_number': state.bankAccountNumber,
          'bank_ifsc': state.bankIfsc,
          'bank_name': state.bankName,
          'bank_branch': state.bankBranch,
          'is_bank_verified': state.bankStatus == VerificationStatus.verified,
          
          // KYC Consent
          'has_consented': state.hasConsented,
          'consent_timestamp': DateTime.now().toIso8601String(),
          
          // Signature Photo
          'signature_document_url': state.signaturePath,
          
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'username');
        print('✅ Successfully stored onboarding data in user_onboardings table!');
        return null; // Success!
      } catch (e) {
        print('⚠️ Error upserting to user_onboardings: $e');
        return e.toString();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase registration notice: $e');
      }
      return e.toString();
    }
  }

  /// Authenticate username and password for Sign In
  static Future<bool> authenticate({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    // Check local fallback dictionary first
    if (_userCredentials.containsKey(cleanUsername)) {
      return _userCredentials[cleanUsername] == password;
    }

    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('user_onboardings')
            .select('password')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (response != null && response['password'] == password) {
          return true; // Match found in Supabase
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase auth notice: $e');
      }
    }

    return false;
  }

  /// Uploads a local image file to a public Supabase Storage bucket
  /// and returns its public download URL string.
  static Future<String?> uploadImage({
    required String bucketName,
    required String filePath,
    required String remoteFileName,
  }) async {
    try {
      final supaClient = client;
      if (supaClient == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      // Upload file to Supabase storage
      await supaClient.storage.from(bucketName).upload(
        remoteFileName,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      // Get public URL of the uploaded file
      final String publicUrl = supaClient.storage.from(bucketName).getPublicUrl(remoteFileName);
      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error uploading image to bucket $bucketName: $e');
      }
      return null;
    }
  }

  // In-memory fallback tables for chit groups and members
  static final List<ChitGroup> _mockGroups = [
    const ChitGroup(
      id: 'group_1',
      name: 'Koramangala Professional Chit',
      totalPoolSize: 1000000.0,
      durationMonths: 10,
      monthlyContribution: 10000.0,
      securityDeposit: 20000.0,
      payoutRules: 'Bidding starts at 20% discount. Minimum bid increment ₹1,000.',
      inviteCode: 'CG-KORA-982',
      status: 'Active',
      currentCycle: 4,
      membersCount: 10,
    ),
    const ChitGroup(
      id: 'group_2',
      name: 'Indiranagar Business Pool',
      totalPoolSize: 2500000.0,
      durationMonths: 20,
      monthlyContribution: 12500.0,
      securityDeposit: 50000.0,
      payoutRules: 'Fixed payout at Month 5 and Month 10. Bidding for other months.',
      inviteCode: 'CG-INDI-401',
      status: 'Active',
      currentCycle: 8,
      membersCount: 20,
    ),
  ];

  static final List<ChitMemberRisk> _mockMembers = [
    ChitMemberRisk(
      id: 'member_1',
      groupId: 'group_1',
      name: 'Rajesh Kumar',
      defaultRiskScore: 84.0,
      payoutPosition: 'Paid (Month 2)',
      paymentTrend: 'Delayed 3x',
      guarantorStatus: 'None',
      amountExposed: 200000.0,
      hasDefaulted: true,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 15)),
      phone: '+91 98765 43210',
    ),
    ChitMemberRisk(
      id: 'member_2',
      groupId: 'group_1',
      name: 'Amit Sharma',
      defaultRiskScore: 45.0,
      payoutPosition: 'Paid (Month 3)',
      paymentTrend: 'Delayed 1x',
      guarantorStatus: 'Pending (1 guarantor)',
      amountExposed: 150000.0,
      hasDefaulted: false,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 5)),
      phone: '+91 87654 32109',
    ),
    ChitMemberRisk(
      id: 'member_3',
      groupId: 'group_1',
      name: 'Priya Patel',
      defaultRiskScore: 12.0,
      payoutPosition: 'Unpaid (Bidder)',
      paymentTrend: 'Always On-Time',
      guarantorStatus: 'Verified (2 guarantors)',
      amountExposed: 0.0,
      hasDefaulted: false,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 2)),
      phone: '+91 76543 21098',
    ),
    ChitMemberRisk(
      id: 'member_4',
      groupId: 'group_1',
      name: 'Vikram Singh',
      defaultRiskScore: 8.0,
      payoutPosition: 'Unpaid (Bidder)',
      paymentTrend: 'Always On-Time',
      guarantorStatus: 'Verified (2 guarantors)',
      amountExposed: 0.0,
      hasDefaulted: false,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 3)),
      phone: '+91 65432 10987',
    ),
    ChitMemberRisk(
      id: 'member_5',
      groupId: 'group_1',
      name: 'Sneha Reddy',
      defaultRiskScore: 78.0,
      payoutPosition: 'Paid (Month 1)',
      paymentTrend: 'Delayed 4x',
      guarantorStatus: 'None',
      amountExposed: 350000.0,
      hasDefaulted: true,
      lastPaymentDate: DateTime.now().subtract(const Duration(days: 22)),
      phone: '+91 95432 87654',
    ),
  ];

  /// Get user role based on username
  static Future<UserRole> getUserRole(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    
    // Check local fallback dictionary
    if (cleanUsername.contains('host') || cleanUsername.contains('admin') || cleanUsername.contains('demo')) {
      return UserRole.host;
    }
    
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('user_onboardings')
            .select('role')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (response != null && response['role'] != null) {
          final roleStr = response['role'] as String;
          return roleStr == 'host' ? UserRole.host : UserRole.member;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getUserRole notice: $e');
      }
    }
    
    // Default fallback
    return UserRole.host;
  }

  /// Fetch all chit groups
  static Future<List<ChitGroup>> getChitGroups() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient.from('chit_groups').select();
        if (response.isNotEmpty) {
          return response.map((json) => ChitGroup.fromJson(json)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getChitGroups fallback to mock: $e');
      }
    }
    return _mockGroups;
  }

  /// Create a new chit group
  static Future<void> createChitGroup(ChitGroup group) async {
    // Add to in-memory list first
    _mockGroups.add(group);
    
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('chit_groups').insert(group.toJson());
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase createChitGroup notice (using fallback local check): $e');
      }
    }
  }

  /// Fetch members for a group with risk profiles
  static Future<List<ChitMemberRisk>> getGroupMembers(String groupId) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient.from('group_members').select().eq('group_id', groupId);
        if (response.isNotEmpty) {
          return response.map((json) => ChitMemberRisk.fromJson(json)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getGroupMembers fallback to mock: $e');
      }
    }
    return _mockMembers.where((m) => m.groupId == groupId).toList();
  }

  /// Trigger forfeiture for a member in a group (Escrow Control)
  static Future<void> triggerForfeiture(String memberId) async {
    // Update local list
    final index = _mockMembers.indexWhere((m) => m.id == memberId);
    if (index != -1) {
      final oldMember = _mockMembers[index];
      _mockMembers[index] = oldMember.copyWith(
        forfeited: true,
        defaultRiskScore: 100.0, // Risk is absolute after forfeiture
        amountExposed: 0, // Cleared after forfeiture/escrow settlement
      );
    }
    
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('group_members').update({
          'forfeited': true,
          'default_risk_score': 100.0,
          'amount_exposed': 0,
        }).eq('id', memberId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase triggerForfeiture notice: $e');
      }
    }
  }

  /// Generate and persist a Section 28 Default Notice
  static Future<void> saveDefaultNotice(String memberId, String noticeText) async {
    // Update local list
    final index = _mockMembers.indexWhere((m) => m.id == memberId);
    if (index != -1) {
      final oldMember = _mockMembers[index];
      _mockMembers[index] = oldMember.copyWith(
        defaultNoticeSent: true,
        defaultNoticeText: noticeText,
      );
    }
    
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('group_members').update({
          'default_notice_sent': true,
          'default_notice_text': noticeText,
        }).eq('id', memberId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase saveDefaultNotice notice: $e');
      }
    }
  }

  static final List<ChitJoinRequest> _mockJoinRequests = [
    ChitJoinRequest(
      id: 'req_101',
      groupId: 'group_1',
      groupName: 'Koramangala Professional Chit',
      inviteCode: '849201',
      memberUsername: 'member_demo',
      memberName: 'Suresh Raina',
      memberPhone: '+91 98765 12345',
      memberEmail: 'suresh@gmail.com',
      memberCity: 'Bengaluru',
      reputationScore: 98.0,
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  /// Find group by 6-digit invite code
  static Future<ChitGroup?> getGroupByInviteCode(String code) async {
    final cleanCode = code.trim();
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('chit_groups')
            .select()
            .eq('invite_code', cleanCode)
            .maybeSingle();
        if (response != null) {
          return ChitGroup.fromJson(response);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getGroupByInviteCode fallback: $e');
      }
    }
    
    // Fallback search in memory
    try {
      return _mockGroups.firstWhere((g) => g.inviteCode.trim() == cleanCode || g.inviteCode.endsWith(cleanCode));
    } catch (_) {
      return null;
    }
  }

  /// Submit a member join request via 6-digit code (contains non-sensitive info only)
  static Future<bool> submitJoinRequest({
    required String inviteCode,
    required String memberUsername,
  }) async {
    final cleanCode = inviteCode.trim();
    final cleanUsername = memberUsername.trim().toLowerCase();

    // 1. Find target group
    final group = await getGroupByInviteCode(cleanCode);
    if (group == null) return false;

    // 2. Fetch non-sensitive member details from Supabase or memory
    String memberName = 'Member $cleanUsername';
    String memberPhone = '+91 98765 43210';
    String memberEmail = '$cleanUsername@gmail.com';
    String memberCity = 'India';

    try {
      final supaClient = client;
      if (supaClient != null) {
        final profile = await supaClient
            .from('user_onboardings')
            .select('full_name, mobile_number, email, perm_city')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (profile != null) {
          memberName = profile['full_name'] as String? ?? memberName;
          memberPhone = profile['mobile_number'] as String? ?? memberPhone;
          memberEmail = profile['email'] as String? ?? memberEmail;
          memberCity = profile['perm_city'] as String? ?? memberCity;
        }
      }
    } catch (_) {}

    final newReq = ChitJoinRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      groupId: group.id,
      groupName: group.name,
      inviteCode: cleanCode,
      memberUsername: cleanUsername,
      memberName: memberName,
      memberPhone: memberPhone,
      memberEmail: memberEmail,
      memberCity: memberCity,
      reputationScore: 100.0,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // Save to local list
    _mockJoinRequests.add(newReq);

    // Save to Supabase chit_join_requests
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('chit_join_requests').upsert(newReq.toJson());
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase submitJoinRequest notice: $e');
      }
    }

    return true;
  }

  /// Get pending join requests for Foreman to review
  static Future<List<ChitJoinRequest>> getPendingJoinRequests() async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('chit_join_requests')
            .select()
            .eq('status', 'pending');
        if (response.isNotEmpty) {
          return response.map((j) => ChitJoinRequest.fromJson(j)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getPendingJoinRequests fallback: $e');
      }
    }
    return _mockJoinRequests.where((r) => r.status == 'pending').toList();
  }

  /// Get member's join requests / joined groups
  static Future<List<ChitJoinRequest>> getMemberJoinRequests(String memberUsername) async {
    final cleanUsername = memberUsername.trim().toLowerCase();
    try {
      final supaClient = client;
      if (supaClient != null) {
        final response = await supaClient
            .from('chit_join_requests')
            .select()
            .eq('member_username', cleanUsername);
        if (response.isNotEmpty) {
          return response.map((j) => ChitJoinRequest.fromJson(j)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getMemberJoinRequests fallback: $e');
      }
    }
    return _mockJoinRequests.where((r) => r.memberUsername == cleanUsername || cleanUsername == 'demo' || cleanUsername.contains('member')).toList();
  }

  /// Accept or Reject a Join Request
  static Future<void> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {
    final newStatus = accept ? 'approved' : 'rejected';

    // 1. Update in-memory list
    final idx = _mockJoinRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = _mockJoinRequests[idx];
      _mockJoinRequests[idx] = req.copyWith(status: newStatus);

      if (accept) {
        // Add as a member to group
        _mockMembers.add(ChitMemberRisk(
          id: 'member_${DateTime.now().millisecondsSinceEpoch}',
          groupId: req.groupId,
          name: req.memberName,
          defaultRiskScore: 15.0,
          payoutPosition: 'Unpaid (Bidder)',
          paymentTrend: 'On-Time',
          guarantorStatus: 'Verified',
          amountExposed: 0,
          hasDefaulted: false,
          lastPaymentDate: DateTime.now(),
          phone: req.memberPhone,
        ));
      }
    }

    // 2. Update Supabase table chit_join_requests
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient
            .from('chit_join_requests')
            .update({'status': newStatus})
            .eq('id', requestId);

        if (accept && idx != -1) {
          final req = _mockJoinRequests[idx];
          await supaClient.from('group_members').insert({
            'group_id': req.groupId,
            'name': req.memberName,
            'default_risk_score': 15.0,
            'payout_position': 'Unpaid (Bidder)',
            'payment_trend': 'On-Time',
            'guarantor_status': 'Verified',
            'amount_exposed': 0,
            'has_defaulted': false,
            'phone': req.memberPhone,
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase respondToJoinRequest notice: $e');
      }
    }
  }

  // In-memory agreements storage fallback
  static final List<DigitalAgreement> _mockAgreements = [];

  /// Get Public Chit Groups for Discovery Marketplace
  static Future<List<ChitGroup>> getPublicChitGroups({
    String? query,
    String? schemeType,
  }) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        var req = supaClient.from('chit_groups').select().eq('is_public', true);
        if (schemeType != null && schemeType != 'All' && schemeType.isNotEmpty) {
          req = req.eq('scheme_type', schemeType);
        }
        final List<dynamic> data = await req;
        final groups = data.map((item) => ChitGroup.fromJson(item as Map<String, dynamic>)).toList();
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          return groups.where((g) => g.name.toLowerCase().contains(q) || g.inviteCode.contains(q)).toList();
        }
        if (groups.isNotEmpty) return groups;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getPublicChitGroups fallback: $e');
      }
    }

    // Fallback in-memory query
    var filtered = _mockGroups.where((g) => g.isPublic).toList();
    if (schemeType != null && schemeType != 'All' && schemeType.isNotEmpty) {
      filtered = filtered.where((g) => g.schemeType == schemeType).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      filtered = filtered.where((g) => g.name.toLowerCase().contains(q) || g.inviteCode.contains(q)).toList();
    }
    return filtered;
  }

  /// Get User Dashboard Metrics (Chits Joined, Monthly Payment Due, Defaults)
  static Future<Map<String, dynamic>> getUserDashboardMetrics(String memberUsername) async {
    final cleanUser = memberUsername.trim().toLowerCase();
    int chitsJoined = 0;
    double monthlyDue = 0.0;
    int defaultsCount = 0;

    try {
      final supaClient = client;
      if (supaClient != null) {
        final List<dynamic> joinReqs = await supaClient
            .from('chit_join_requests')
            .select('group_id, status')
            .eq('member_username', cleanUser)
            .eq('status', 'approved');
        
        chitsJoined = joinReqs.length;

        for (var req in joinReqs) {
          final groupId = req['group_id'] as String?;
          if (groupId != null) {
            final groupData = await supaClient
                .from('chit_groups')
                .select('monthly_contribution')
                .eq('id', groupId)
                .maybeSingle();
            if (groupData != null) {
              monthlyDue += (groupData['monthly_contribution'] as num).toDouble();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getUserDashboardMetrics fallback: $e');
      }
    }

    if (chitsJoined == 0) {
      final approvedMockReqs = _mockJoinRequests
          .where((r) => (r.memberUsername == cleanUser || cleanUser == 'demo' || cleanUser.contains('member')) && r.status == 'approved')
          .toList();
      chitsJoined = approvedMockReqs.length;
      for (var req in approvedMockReqs) {
        final group = _mockGroups.firstWhere((g) => g.id == req.groupId, orElse: () => _mockGroups.first);
        monthlyDue += group.monthlyContribution;
      }
    }

    return {
      'chitsJoined': chitsJoined,
      'monthlyAmountDue': monthlyDue,
      'totalDefaults': defaultsCount,
    };
  }

  /// Save or Update Digital Agreement
  static Future<bool> saveDigitalAgreement(DigitalAgreement agreement) async {
    _mockAgreements.removeWhere((a) => a.id == agreement.id);
    _mockAgreements.add(agreement);

    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('digital_agreements').upsert(agreement.toJson());
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase saveDigitalAgreement fallback: $e');
      }
    }
    return true;
  }

  /// Get Digital Agreement for Group & Member
  static Future<DigitalAgreement?> getDigitalAgreement({
    required String groupId,
    required String memberUsername,
  }) async {
    final cleanUser = memberUsername.trim().toLowerCase();

    try {
      final supaClient = client;
      if (supaClient != null) {
        final data = await supaClient
            .from('digital_agreements')
            .select()
            .eq('group_id', groupId)
            .eq('member_username', cleanUser)
            .maybeSingle();
        if (data != null) {
          return DigitalAgreement.fromJson(data as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getDigitalAgreement fallback: $e');
      }
    }

    final found = _mockAgreements.where((a) => a.groupId == groupId && (a.memberUsername == cleanUser || cleanUser == 'demo')).toList();
    if (found.isNotEmpty) return found.last;
    return null;
  }

  /// Digitally Sign Agreement (Host or Subscriber)
  static Future<bool> signDigitalAgreement({
    required String agreementId,
    required bool isForeman,
    required String signatureUrl,
  }) async {
    final now = DateTime.now();

    final idx = _mockAgreements.indexWhere((a) => a.id == agreementId);
    if (idx != -1) {
      final current = _mockAgreements[idx];
      final updatedForemanSigned = isForeman ? true : current.foremanSigned;
      final updatedMemberSigned = !isForeman ? true : current.memberSigned;
      final newStatus = (updatedForemanSigned && updatedMemberSigned) ? 'fully_executed' : 'pending_signatures';

      _mockAgreements[idx] = DigitalAgreement(
        id: current.id,
        groupId: current.groupId,
        groupName: current.groupName,
        foremanUsername: current.foremanUsername,
        foremanName: current.foremanName,
        memberUsername: current.memberUsername,
        memberName: current.memberName,
        poolAmount: current.poolAmount,
        durationMonths: current.durationMonths,
        monthlyContribution: current.monthlyContribution,
        schemeType: current.schemeType,
        agreementText: current.agreementText,
        foremanSigned: updatedForemanSigned,
        foremanSignatureUrl: isForeman ? signatureUrl : current.foremanSignatureUrl,
        foremanSignedAt: isForeman ? now : current.foremanSignedAt,
        memberSigned: updatedMemberSigned,
        memberSignatureUrl: !isForeman ? signatureUrl : current.memberSignatureUrl,
        memberSignedAt: !isForeman ? now : current.memberSignedAt,
        status: newStatus,
        createdAt: current.createdAt,
      );
    }

    try {
      final supaClient = client;
      if (supaClient != null) {
        final updateData = isForeman
            ? {
                'foreman_signed': true,
                'foreman_signature_url': signatureUrl,
                'foreman_signed_at': now.toIso8601String(),
              }
            : {
                'member_signed': true,
                'member_signature_url': signatureUrl,
                'member_signed_at': now.toIso8601String(),
              };

        await supaClient
            .from('digital_agreements')
            .update(updateData)
            .eq('id', agreementId);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase signDigitalAgreement notice: $e');
      }
    }
    return true;
  }
}
