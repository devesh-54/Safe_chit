import 'dart:io';

import '../models/onboarding_state.dart';

import '../models/chit_group.dart';

import '../models/member_risk.dart';

import '../models/chit_join_request.dart';

import '../models/digital_agreement.dart';

import '../models/chit_payment_record.dart';

import '../models/guarantee_request.dart';

import '../models/reputation_event.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/widgets.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://sjemdgjcjjozaljhzvzm.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZW1kZ2pjampvemFsamh6dnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjgwMDgsImV4cCI6MjEwMjgwNDAwOH0.EdvMnsMwI0HoX8p55hJE5LfYsYTM5rs4M8ZvoDrDB5A';

  static bool _isInitialized = false;

  // In-memory fallback registry for offline/local simulation

  static final Set<String> _registeredUsernames = {
    'admin',
    'host',
    'demo',
    'foreman_admin',
    'member_demo',
  };

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
      final isFlutterTest = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('Test');

      if (!isFlutterTest) {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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

          'is_mobile_verified':
              state.mobileStatus == VerificationStatus.verified,

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

          'is_gov_id_verified':
              state.govIdStatus == VerificationStatus.verified,

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

        print(
          '✅ Successfully stored onboarding data in user_onboardings table!',
        );

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

      await supaClient.storage
          .from(bucketName)
          .upload(
            remoteFileName,

            file,

            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Get public URL of the uploaded file

      final String publicUrl = supaClient.storage
          .from(bucketName)
          .getPublicUrl(remoteFileName);

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error uploading image to bucket $bucketName: $e');
      }

      return null;
    }
  }

  // In-memory fallback tables for chit groups and members

  static String _currentForemanUpiId = 'devesh1@oksbi';

  static String get foremanUpiId => _currentForemanUpiId;

  static set foremanUpiId(String vpa) => _currentForemanUpiId = vpa.trim();

  /// Updates the Foreman receiving UPI ID across Supabase, in-memory state and groups

  static Future<bool> updateForemanUpiId(
    String newUpiId, {
    String? groupId,
  }) async {
    final cleanUpi = newUpiId.trim();

    _currentForemanUpiId = cleanUpi;

    if (groupId != null) {
      final index = _mockGroups.indexWhere((g) => g.id == groupId);

      if (index != -1) {
        _mockGroups[index] = _mockGroups[index].copyWith(
          foremanUpiId: _currentForemanUpiId,
        );
      }
    } else {
      for (int i = 0; i < _mockGroups.length; i++) {
        _mockGroups[i] = _mockGroups[i].copyWith(
          foremanUpiId: _currentForemanUpiId,
        );
      }
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        if (groupId != null) {
          await supaClient
              .from('chit_groups')
              .update({'foreman_upi_id': cleanUpi})
              .eq('id', groupId);
        } else {
          // Update all chit groups if no single group is specified

          await supaClient
              .from('chit_groups')
              .update({'foreman_upi_id': cleanUpi})
              .neq('id', '');
        }

        if (kDebugMode) {
          print('✅ Supabase: Updated foreman_upi_id to $cleanUpi');
        }

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase updateForemanUpiId error: $e');
      }
    }

    return false;
  }

  static final List<ChitGroup> _mockGroups = [
    const ChitGroup(
      id: 'group_1',

      name: 'Koramangala Testing Chit (₹5 Pool)',

      totalPoolSize: 5.0,

      durationMonths: 5,

      monthlyContribution: 1.0,

      securityDeposit: 1.0,

      payoutRules:
          'Bidding starts at 20% discount. Minimum bid increment ₹0.10.',

      inviteCode: 'CG-KORA-982',

      status: 'Active',

      currentCycle: 1,

      membersCount: 5,

      foremanUpiId: 'devesh1@oksbi',
    ),

    const ChitGroup(
      id: 'group_2',

      name: 'Indiranagar Quick Pool (₹5 Pool)',

      totalPoolSize: 5.0,

      durationMonths: 5,

      monthlyContribution: 1.0,

      securityDeposit: 1.0,

      payoutRules:
          'Fixed payout at Month 2 and Month 4. Bidding for other months.',

      inviteCode: 'CG-INDI-401',

      status: 'Active',

      currentCycle: 1,

      membersCount: 5,

      foremanUpiId: 'devesh1@oksbi',
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

      amountExposed: 2.0,

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

      amountExposed: 1.0,

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

      amountExposed: 3.0,

      hasDefaulted: true,

      lastPaymentDate: DateTime.now().subtract(const Duration(days: 22)),

      phone: '+91 95432 87654',
    ),
  ];

  /// Get user role based on username

  static Future<UserRole> getUserRole(String username) async {
    final cleanUsername = username.trim().toLowerCase();

    // Check local fallback dictionary

    if (cleanUsername == 'member_demo' || cleanUsername.contains('member')) {
      return UserRole.member;
    }

    if (cleanUsername == 'foreman_admin' ||
        cleanUsername.contains('host') ||
        cleanUsername.contains('foreman')) {
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

  /// Get user profile (full name, phone, email, city) from user_onboardings

  /// Sanity check if username exists for guarantor nomination

  static Future<bool> checkUserExists(String username) async {
    final cleanUsername = username.trim().toLowerCase();

    if (cleanUsername.isEmpty) return false;

    if (_userCredentials.containsKey(cleanUsername) ||
        cleanUsername == 'member_demo' ||
        cleanUsername == 'foreman' ||
        cleanUsername == 'member_test2') {
      return true;
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        final res = await supaClient
            .from('user_onboardings')
            .select('username')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (res != null) return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase checkUserExists notice: $e');
      }
    }

    return false;
  }

  static String currentUsername = 'member_demo';

  static final List<ReputationEvent> _mockReputationEvents = [
    ReputationEvent(
      id: 'rep_1',
      username: 'member_demo',
      role: 'member',
      eventType: 'on_time_payment',
      scoreDelta: 5.0,
      description: 'On-time installment for Bengaluru Techies Chit',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ReputationEvent(
      id: 'rep_2',
      username: 'member_demo',
      role: 'member',
      eventType: 'group_completed',
      scoreDelta: 10.0,
      description: 'Completed Koramangala 5-Month Chit cycle with 0 defaults',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    ReputationEvent(
      id: 'rep_3',
      username: 'member_demo',
      role: 'member',
      eventType: 'clean_guarantee',
      scoreDelta: 5.0,
      description: 'Acted as guarantor for group participant with 0 defaults',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    ReputationEvent(
      id: 'rep_4',
      username: 'member_test2',
      role: 'member',
      eventType: 'on_time_payment',
      scoreDelta: 5.0,
      description: 'On-time installment collection verified',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ReputationEvent(
      id: 'rep_5',
      username: 'member_test2',
      role: 'member',
      eventType: 'clean_guarantee',
      scoreDelta: 5.0,
      description: 'Guarantee nomination accepted & active',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ReputationEvent(
      id: 'rep_6',
      username: 'foreman_admin',
      role: 'foreman',
      eventType: 'group_hosted',
      scoreDelta: 15.0,
      description: 'Successfully hosted and closed Koramangala Professional Chit',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    ReputationEvent(
      id: 'rep_7',
      username: 'foreman_admin',
      role: 'foreman',
      eventType: 'escrow_disbursed',
      scoreDelta: 10.0,
      description: 'Escrow payout released on schedule to winning bidder',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    ReputationEvent(
      id: 'rep_8',
      username: 'foreman_admin',
      role: 'foreman',
      eventType: 'zero_dispute',
      scoreDelta: 5.0,
      description: '100% on-time disbursement streak maintained',
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
  ];

  static Future<Map<String, dynamic>?> getUserProfile(String username) async {
    final cleanUsername = username.trim().toLowerCase();

    try {
      final supaClient = client;

      if (supaClient != null) {
        // First try exact username match
        var profile = await supaClient
            .from('user_onboardings')
            .select(
              'full_name, mobile_number, email, perm_city, username, role, created_at',
            )
            .ilike('username', cleanUsername)
            .maybeSingle();

        // If not found, try searching by full_name
        if (profile == null) {
          final firstWord = cleanUsername.split(' ').first;
          profile = await supaClient
              .from('user_onboardings')
              .select(
                'full_name, mobile_number, email, perm_city, username, role, created_at',
              )
              .ilike('full_name', '%$firstWord%')
              .maybeSingle();
        }

        if (profile != null) {
          return Map<String, dynamic>.from(profile);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getUserProfile notice: $e');
      }
    }

    // Fallback sensible mock profile for demo accounts
    if (cleanUsername.contains('foreman')) {
      return {
        'full_name': 'Rajesh Kumar (Foreman)',
        'username': 'foreman_admin',
        'mobile_number': '9876543210',
        'email': 'foreman@chitguard.in',
        'perm_city': 'Chennai',
        'role': 'host',
        'created_at': '2026-09-01T10:00:00Z',
      };
    } else if (cleanUsername.contains('member_test2')) {
      return {
        'full_name': 'Suresh Raina',
        'username': 'member_test2',
        'mobile_number': '9876599999',
        'email': 'member2@chitguard.in',
        'perm_city': 'Bengaluru',
        'role': 'member',
        'created_at': '2026-10-15T10:00:00Z',
      };
    } else if (cleanUsername.contains('suresh') || cleanUsername.contains('member')) {
      return {
        'full_name': 'Suresh Raina',
        'username': 'member_demo',
        'mobile_number': '9876512345',
        'email': 'suresh.raina@chitguard.in',
        'perm_city': 'Bengaluru',
        'role': 'member',
        'created_at': '2026-10-01T10:00:00Z',
      };
    }

    return {
      'full_name': username,
      'username': username,
      'mobile_number': '9876500000',
      'email': '$cleanUsername@chitguard.in',
      'perm_city': 'Bengaluru',
      'role': 'member',
      'created_at': '2026-10-01T10:00:00Z',
    };
  }

  /// Fetch reputation events for a user and optional role
  static Future<List<ReputationEvent>> getReputationEvents(
    String username, {
    String? role,
  }) async {
    final cleanUser = username.trim().toLowerCase();
    try {
      final supaClient = client;
      if (supaClient != null) {
        var query = supaClient
            .from('reputation_events')
            .select()
            .ilike('username', cleanUser);
        if (role != null) {
          query = query.eq('role', role.toLowerCase());
        }
        final response = await query.order('created_at', ascending: false);
        if (response.isNotEmpty) {
          return response
              .map((json) => ReputationEvent.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getReputationEvents fallback: $e');
      }
    }

    // Fallback to in-memory mock events
    return _mockReputationEvents
        .where((e) {
          final matchesUser = e.username.toLowerCase() == cleanUser ||
              cleanUser.contains(e.username.toLowerCase()) ||
              e.username.toLowerCase().contains(cleanUser);
          final matchesRole =
              role == null || e.role.toLowerCase() == role.toLowerCase();
          return matchesUser && matchesRole;
        })
        .toList();
  }

  /// Calculates dual-role performance statistics and activity for a given user
  static Future<Map<String, dynamic>> getUserRolePerformance(
    String username,
  ) async {
    final cleanUser = username.trim().toLowerCase();

    // 1. Fetch user profile
    final profile = await getUserProfile(username);
    final userRole = profile?['role']?.toString().toLowerCase() ?? '';

    // 2. Fetch Member activity
    final memberEvents = await getReputationEvents(username, role: 'member');
    final memberRequests = await getMemberJoinRequests(username);
    final int memberGroupCount = memberRequests.where((r) => r.isApproved).length > 0
        ? memberRequests.where((r) => r.isApproved).length
        : memberRequests.length;

    final bool isMemberActive = memberGroupCount > 0 || memberEvents.isNotEmpty;

    double memberDeltaSum = 0;
    for (var ev in memberEvents) {
      memberDeltaSum += ev.scoreDelta;
    }
    final double memberScore = (100.0 + memberDeltaSum).clamp(0.0, 100.0);
    String memberTier = 'Tier 1: Elite Member';
    if (memberScore < 70) {
      memberTier = 'Tier 4: Caution';
    } else if (memberScore < 85) {
      memberTier = 'Tier 3: Standard';
    } else if (memberScore < 95) {
      memberTier = 'Tier 2: Prime';
    }

    // 3. Fetch Foreman activity
    final foremanEvents = await getReputationEvents(username, role: 'foreman');
    final allGroups = await getChitGroups();
    final bool isHostUser = userRole == 'host' || cleanUser.contains('foreman');
    int foremanGroupCount = 0;
    for (var g in allGroups) {
      if (g.foremanUpiId.toLowerCase().contains(cleanUser) ||
          (isHostUser && allGroups.isNotEmpty)) {
        foremanGroupCount++;
      }
    }

    final bool isForemanActive =
        foremanGroupCount > 0 || foremanEvents.isNotEmpty;

    double foremanDeltaSum = 0;
    for (var ev in foremanEvents) {
      foremanDeltaSum += ev.scoreDelta;
    }
    final double foremanScore = (100.0 + foremanDeltaSum).clamp(0.0, 100.0);
    String foremanTier = 'Tier 1: Master Organizer';
    if (foremanScore < 70) {
      foremanTier = 'Tier 4: At Risk';
    } else if (foremanScore < 85) {
      foremanTier = 'Tier 3: Standard';
    } else if (foremanScore < 95) {
      foremanTier = 'Tier 2: Certified';
    }

    return {
      'profile': profile,
      'member': {
        'isActive': isMemberActive,
        'score': memberScore,
        'tier': memberTier,
        'completedChits': memberGroupCount,
        'onTimeRate': 100.0,
        'defaults': 0,
        'events': memberEvents,
        'activityCount': memberGroupCount + memberEvents.length,
      },
      'foreman': {
        'isActive': isForemanActive,
        'score': foremanScore,
        'tier': foremanTier,
        'completedChits': foremanGroupCount,
        'onTimeRate': 100.0,
        'defaults': 0,
        'events': foremanEvents,
        'activityCount': foremanGroupCount + foremanEvents.length,
      },
    };
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

  /// Fetch a single chit group by ID

  static Future<ChitGroup?> getChitGroupById(String id) async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_groups')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (response != null) {
          return ChitGroup.fromJson(response);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getChitGroupById error: $e');
      }
    }

    try {
      return _mockGroups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Create a new chit group

  static Future<void> createChitGroup(ChitGroup group) async {
    // Add to in-memory list first

    if (!_mockGroups.any((g) => g.id == group.id)) {
      _mockGroups.add(group);
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        final groupJson = group.toJson();

        try {
          await supaClient.from('chit_groups').insert(groupJson);
        } catch (insertError) {
          // If foreman_upi_id column is not yet created in Supabase schema, insert without it

          if (insertError.toString().contains('foreman_upi_id') ||
              insertError.toString().contains('PGRST204')) {
            groupJson.remove('foreman_upi_id');

            await supaClient.from('chit_groups').insert(groupJson);
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'ℹ️ Supabase createChitGroup notice (using fallback local check): $e',
        );
      }
    }
  }

  /// Fetch members for a group with risk profiles

  static Future<List<ChitMemberRisk>> getGroupMembers(String groupId) async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('group_members')
            .select()
            .eq('group_id', groupId);

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

  /// Allows the group foreman to join their own group as a member.
  /// 1. Only allowed when group has not started its first cycle (currentCycle <= 1).
  /// 2. Only allowed when a seat is free (membersCount < durationMonths).
  /// 3. Only allowed when foreman is not already a member.
  /// 4. Creates host installment automatically as HOST_SHARE / "Paid (host share)".
  /// 5. TODO: Apply refundable security deposit to the foreman once the deposit flow exists.
  static Future<bool> joinGroupAsHostMember({
    required ChitGroup group,
    required String foremanUsername,
    String? foremanPhone,
  }) async {
    // 1. Group must not have started its first cycle
    if (group.currentCycle > 1) {
      return false;
    }

    // 2. A seat must be free
    if (group.membersCount >= group.durationMonths) {
      return false;
    }

    // 3. Foreman must not already be a member of this group
    final currentMembers = await getGroupMembers(group.id);
    final isAlreadyMember = currentMembers.any(
      (m) =>
          m.isHostMember ||
          m.name.trim().toLowerCase() == foremanUsername.trim().toLowerCase(),
    );
    if (isAlreadyMember) {
      return false;
    }

    // TODO: Apply refundable security deposit to the foreman once the deposit flow exists.

    final newMemberId = 'mem_host_${DateTime.now().millisecondsSinceEpoch}';
    final hostMember = ChitMemberRisk(
      id: newMemberId,
      groupId: group.id,
      name: foremanUsername,
      defaultRiskScore: 0.0,
      payoutPosition: 'Host · Month 2',
      paymentTrend: 'On-Time',
      guarantorStatus: 'Not Required',
      amountExposed: 0,
      lastPaymentDate: DateTime.now(),
      phone: foremanPhone ?? 'Host Account',
      isHostMember: true,
    );

    _mockMembers.add(hostMember);

    // Increment group membersCount in mock
    final groupIndex = _mockGroups.indexWhere((g) => g.id == group.id);
    if (groupIndex != -1) {
      final g = _mockGroups[groupIndex];
      _mockGroups[groupIndex] = ChitGroup(
        id: g.id,
        name: g.name,
        totalPoolSize: g.totalPoolSize,
        durationMonths: g.durationMonths,
        monthlyContribution: g.monthlyContribution,
        securityDeposit: g.securityDeposit,
        payoutRules: g.payoutRules,
        inviteCode: g.inviteCode,
        status: g.status,
        currentCycle: g.currentCycle,
        membersCount: g.membersCount + 1,
        schemeType: g.schemeType,
        isPublic: g.isPublic,
        city: g.city,
        foremanUpiId: g.foremanUpiId,
      );
    }

    // Requirement 3: Automatically create month's installment for the foreman as already paid,
    // with method HOST_SHARE and label "Paid (host share)" in the ledger.
    final hostPayment = ChitPaymentRecord(
      id: 'pay_host_${group.id}_c${group.currentCycle}',
      groupId: group.id,
      groupName: group.name,
      cycle: group.currentCycle,
      memberUsername: foremanUsername,
      memberName: foremanUsername,
      amount: group.monthlyContribution,
      amountPaise: (group.monthlyContribution * 100).toInt(),
      paymentMethod: 'HOST_SHARE',
      status: 'PAID',
      payeeVpa: group.foremanUpiId,
      payeeName: foremanUsername,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
      notes: 'Paid (host share)',
    );
    _mockPayments.insert(0, hostPayment);

    // Persist to Supabase if connected
    try {
      final supaClient = client;
      if (supaClient != null) {
        await supaClient.from('group_members').insert({
          'group_id': group.id,
          'name': foremanUsername,
          'default_risk_score': 0.0,
          'payout_position': 'Host · Month 2',
          'payment_trend': 'On-Time',
          'guarantor_status': 'Not Required',
          'amount_exposed': 0,
          'has_defaulted': false,
          'phone': foremanPhone ?? 'Host Account',
          'is_host_member': true,
        });

        await supaClient
            .from('chit_groups')
            .update({'members_count': group.membersCount + 1})
            .eq('id', group.id);

        await supaClient.from('chit_payments').insert({
          'id': hostPayment.id,
          'group_id': group.id,
          'group_name': group.name,
          'cycle': group.currentCycle,
          'member_username': foremanUsername,
          'member_name': foremanUsername,
          'amount': group.monthlyContribution,
          'amount_paise': (group.monthlyContribution * 100).toInt(),
          'payment_method': 'HOST_SHARE',
          'status': 'PAID',
          'notes': 'Paid (host share)',
          'payee_vpa': group.foremanUpiId,
          'payee_name': foremanUsername,
          'completed_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase joinGroupAsHostMember fallback: $e');
      }
    }

    return true;
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
        await supaClient
            .from('group_members')
            .update({
              'forfeited': true,

              'default_risk_score': 100.0,

              'amount_exposed': 0,
            })
            .eq('id', memberId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase triggerForfeiture notice: $e');
      }
    }
  }

  /// Generate and persist a Section 28 Default Notice

  static Future<void> saveDefaultNotice(
    String memberId,
    String noticeText,
  ) async {
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
        await supaClient
            .from('group_members')
            .update({
              'default_notice_sent': true,

              'default_notice_text': noticeText,
            })
            .eq('id', memberId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase saveDefaultNotice notice: $e');
      }
    }
  }

  static final List<GuaranteeRequest> _mockGuaranteeRequests = [];

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
      return _mockGroups.firstWhere(
        (g) =>
            g.inviteCode.trim() == cleanCode ||
            g.inviteCode.endsWith(cleanCode),
      );
    } catch (_) {
      return null;
    }
  }

  /// Submit a member join request via 6-digit code (contains non-sensitive info only)

  static Future<bool> submitJoinRequest({
    required String inviteCode,

    required String memberUsername,

    String? guarantorUsername,

    String? guarantorRelation,
  }) async {
    final cleanCode = inviteCode.trim();

    final cleanUsername = memberUsername.trim().toLowerCase();

    final cleanGuarantor =
        (guarantorUsername != null && guarantorUsername.trim().isNotEmpty)
        ? guarantorUsername.trim().toLowerCase()
        : null;

    final relation = guarantorRelation ?? 'Friend';

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

      guarantorUsername: cleanGuarantor,

      guarantorRelation: cleanGuarantor != null ? relation : null,

      guarantorStatus: cleanGuarantor != null ? 'pending' : null,
    );

    _mockJoinRequests.add(newReq);

    // Save to Supabase chit_join_requests

    try {
      final supaClient = client;

      if (supaClient != null) {
        try {
          await supaClient.from('chit_join_requests').upsert(newReq.toJson());
        } catch (_) {
          // Fallback if public.chit_join_requests lacks guarantor columns

          await supaClient.from('chit_join_requests').upsert(newReq.toDbJson());
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase submitJoinRequest notice: $e');
      }
    }

    // 3. If guarantor specified, create guarantee_requests record

    if (cleanGuarantor != null && cleanGuarantor.isNotEmpty) {
      final guaranteeReq = GuaranteeRequest(
        id: 'gr_${DateTime.now().millisecondsSinceEpoch}',

        groupId: group.id,

        groupName: group.name,

        joinRequestId: newReq.id,

        memberId: cleanUsername,

        memberName: memberName,

        guarantorId: cleanGuarantor,

        relation: relation,

        status: 'pending',

        chitValue: group.totalPoolSize,

        durationMonths: group.durationMonths,

        createdAt: DateTime.now(),
      );

      _mockGuaranteeRequests.add(guaranteeReq);

      try {
        final supaClient = client;

        if (supaClient != null) {
          await supaClient
              .from('guarantee_requests')
              .insert(guaranteeReq.toJson());
        }
      } catch (e) {
        if (kDebugMode) {
          print('ℹ️ Supabase guarantee_requests insert notice: $e');
        }
      }
    }

    return true;
  }

  /// Get pending join requests for Foreman to review

  /// Get incoming guarantee requests for a given guarantor

  static Future<List<GuaranteeRequest>> getGuaranteeRequestsForGuarantor(
    String guarantorUsername,
  ) async {
    final cleanGuarantor = guarantorUsername.trim().toLowerCase();

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('guarantee_requests')
            .select()
            .eq('guarantor_id', cleanGuarantor)
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          final List<GuaranteeRequest> list = [];

          for (var item in response) {
            var req = GuaranteeRequest.fromJson(item);

            final group = await getChitGroupById(req.groupId);

            final profile = await getUserProfile(req.memberId);

            req = req.copyWith(
              groupName: group?.name ?? 'Chit Group',

              chitValue: group?.totalPoolSize ?? 0.0,

              durationMonths: group?.durationMonths ?? 1,

              memberName:
                  profile?['full_name'] as String? ?? 'Member ${req.memberId}',
            );

            list.add(req);
          }

          return list;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getGuaranteeRequestsForGuarantor fallback: $e');
      }
    }

    return _mockGuaranteeRequests
        .where((r) => r.guarantorId.toLowerCase() == cleanGuarantor)
        .toList();
  }

  /// Accept or Decline an incoming guarantee request

  static Future<bool> respondToGuaranteeRequest({
    required String requestId,

    required bool accept,
  }) async {
    final newStatus = accept ? 'accepted' : 'declined';

    final now = DateTime.now();

    // 1. Update in-memory mock

    final mockIdx = _mockGuaranteeRequests.indexWhere((r) => r.id == requestId);

    String? joinReqId;

    if (mockIdx != -1) {
      joinReqId = _mockGuaranteeRequests[mockIdx].joinRequestId;

      _mockGuaranteeRequests[mockIdx] = _mockGuaranteeRequests[mockIdx]
          .copyWith(status: newStatus, respondedAt: now);
    }

    if (joinReqId != null) {
      final joinIdx = _mockJoinRequests.indexWhere((r) => r.id == joinReqId);

      if (joinIdx != -1) {
        _mockJoinRequests[joinIdx] = _mockJoinRequests[joinIdx].copyWith(
          guarantorStatus: newStatus,
        );
      }
    }

    // 2. Update Supabase

    try {
      final supaClient = client;

      if (supaClient != null) {
        if (joinReqId == null) {
          final row = await supaClient
              .from('guarantee_requests')
              .select('join_request_id')
              .eq('id', requestId)
              .maybeSingle();

          joinReqId = row?['join_request_id'] as String?;
        }

        final List<dynamic> updatedRows = await supaClient
            .from('guarantee_requests')
            .update({
              'status': newStatus,
              'responded_at': now.toUtc().toIso8601String(),
            })
            .eq('id', requestId)
            .select();

        // Check that the update affects exactly one row
        if (updatedRows.length != 1) {
          if (kDebugMode) {
            print(
              '⚠️ respondToGuaranteeRequest: Expected exactly 1 row updated, got ${updatedRows.length}',
            );
          }
          return false;
        }

        if (joinReqId != null) {
          try {
            await supaClient
                .from('chit_join_requests')
                .update({'guarantor_status': newStatus})
                .eq('id', joinReqId);
          } catch (_) {}
        }

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase respondToGuaranteeRequest notice: $e');
      }
      return false;
    }

    return mockIdx != -1;
  }

  static Future<List<ChitJoinRequest>> getPendingJoinRequests() async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_join_requests')
            .select()
            .eq('status', 'pending');

        if (response.isNotEmpty) {
          // Fetch guarantee requests to merge live guarantor info

          List<dynamic> guaranteeRows = [];

          try {
            guaranteeRows = await supaClient
                .from('guarantee_requests')
                .select()
                .order('created_at', ascending: false);
          } catch (_) {}

          final allGuarantees = [
            ...guaranteeRows.map((r) => GuaranteeRequest.fromJson(r)),

            ..._mockGuaranteeRequests,
          ];

          return response.map((j) {
            var req = ChitJoinRequest.fromJson(j);

            // Match priority:

            // 1. by join_request_id

            // 2. by member_id AND group_id

            // 3. by member_id

            // 4. by member_name

            GuaranteeRequest? matchedGr;

            for (var g in allGuarantees) {
              if (g.joinRequestId.isNotEmpty && g.joinRequestId == req.id) {
                matchedGr = g;

                break;
              }
            }

            if (matchedGr == null) {
              for (var g in allGuarantees) {
                if (g.memberId.isNotEmpty &&
                    g.memberId.toLowerCase() ==
                        req.memberUsername.toLowerCase() &&
                    g.groupId.isNotEmpty &&
                    g.groupId == req.groupId) {
                  matchedGr = g;

                  break;
                }
              }
            }

            if (matchedGr == null) {
              for (var g in allGuarantees) {
                if (g.memberId.isNotEmpty &&
                    g.memberId.toLowerCase() ==
                        req.memberUsername.toLowerCase()) {
                  matchedGr = g;

                  break;
                }
              }
            }

            if (matchedGr == null) {
              for (var g in allGuarantees) {
                if (g.memberName != null &&
                    g.memberName!.trim().isNotEmpty &&
                    g.memberName!.trim().toLowerCase() ==
                        req.memberName.trim().toLowerCase()) {
                  matchedGr = g;

                  break;
                }
              }
            }

            if (matchedGr != null) {
              req = req.copyWith(
                guarantorUsername: matchedGr.guarantorId,

                guarantorRelation: matchedGr.relation,

                guarantorStatus: matchedGr.status,
              );
            }

            return req;
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getPendingJoinRequests fallback: $e');
      }
    }

    return _mockJoinRequests.where((r) => r.status == 'pending').map((req) {
      final gr = _mockGuaranteeRequests.firstWhere(
        (g) =>
            g.joinRequestId == req.id ||
            (g.memberId.toLowerCase() == req.memberUsername.toLowerCase() &&
                g.groupId == req.groupId),

        orElse: () => GuaranteeRequest(
          id: '',
          groupId: '',
          joinRequestId: '',
          memberId: '',
          guarantorId: '',
          relation: '',
          createdAt: DateTime.now(),
        ),
      );

      if (gr.id.isNotEmpty) {
        return req.copyWith(
          guarantorUsername: gr.guarantorId,

          guarantorRelation: gr.relation,

          guarantorStatus: gr.status,
        );
      }

      return req;
    }).toList();
  }

  /// Get member's join requests / joined groups

  static Future<List<ChitJoinRequest>> getMemberJoinRequests(
    String memberUsername,
  ) async {
    final cleanUsername = memberUsername.trim().toLowerCase();

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_join_requests')
            .select()
            .eq('member_username', cleanUsername);

        List<dynamic> guaranteeRows = [];

        try {
          guaranteeRows = await supaClient
              .from('guarantee_requests')
              .select()
              .eq('member_id', cleanUsername);
        } catch (_) {}

        final Map<String, dynamic> grByJoinReq = {};

        final Map<String, dynamic> grByGroup = {};

        for (var gr in guaranteeRows) {
          final jid = gr['join_request_id'] as String?;

          if (jid != null && jid.isNotEmpty) grByJoinReq[jid] = gr;

          final gid = gr['group_id'] as String? ?? '';

          if (gid.isNotEmpty) grByGroup[gid] = gr;
        }

        return response.map((j) {
          var req = ChitJoinRequest.fromJson(j);

          final gr = grByJoinReq[req.id] ?? grByGroup[req.groupId];

          if (gr != null) {
            req = req.copyWith(
              guarantorUsername: gr['guarantor_id'] as String?,

              guarantorRelation: gr['relation'] as String?,

              guarantorStatus: gr['status'] as String?,
            );
          }

          return req;
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getMemberJoinRequests fallback: $e');
      }
    }

    return _mockJoinRequests
        .where(
          (r) =>
              r.memberUsername == cleanUsername ||
              (cleanUsername == 'demo' && r.memberUsername == 'member_demo'),
        )
        .map((req) {
          final gr = _mockGuaranteeRequests.firstWhere(
            (g) =>
                g.joinRequestId == req.id ||
                (g.memberId.toLowerCase() == req.memberUsername.toLowerCase() &&
                    g.groupId == req.groupId),

            orElse: () => GuaranteeRequest(
              id: '',
              groupId: '',
              joinRequestId: '',
              memberId: '',
              guarantorId: '',
              relation: '',
              createdAt: DateTime.now(),
            ),
          );

          if (gr.id.isNotEmpty) {
            return req.copyWith(
              guarantorUsername: gr.guarantorId,

              guarantorRelation: gr.relation,

              guarantorStatus: gr.status,
            );
          }

          return req;
        })
        .toList();
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

        _mockMembers.add(
          ChitMemberRisk(
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
          ),
        );
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

        if (accept) {
          String groupId = '';
          String memberName = 'Member';
          String memberPhone = '';
          String guarantorStatus = 'Verified';

          if (idx != -1) {
            final req = _mockJoinRequests[idx];
            groupId = req.groupId;
            memberName = req.memberName;
            memberPhone = req.memberPhone;
            guarantorStatus = req.guarantorStatus == 'accepted'
                ? 'Verified (@\${req.guarantorUsername})'
                : (req.guarantorUsername != null
                      ? 'Pending (@\${req.guarantorUsername})'
                      : 'Verified');
          } else {
            final row = await supaClient
                .from('chit_join_requests')
                .select()
                .eq('id', requestId)
                .maybeSingle();
            if (row != null) {
              groupId = row['group_id'] as String? ?? '';
              memberName = row['member_name'] as String? ?? 'Member';
              memberPhone = row['member_phone'] as String? ?? '';
            }
          }

          if (groupId.isNotEmpty) {
            await supaClient.from('group_members').insert({
              'group_id': groupId,
              'name': memberName,
              'default_risk_score': 15.0,
              'payout_position': 'Unpaid (Bidder)',
              'payment_trend': 'On-Time',
              'guarantor_status': guarantorStatus,
              'amount_exposed': 0,
              'has_defaulted': false,
              'phone': memberPhone,
            });
          }
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

        if (schemeType != null &&
            schemeType != 'All' &&
            schemeType.isNotEmpty) {
          req = req.eq('scheme_type', schemeType);
        }

        final List<dynamic> data = await req;

        final groups = data
            .map((item) => ChitGroup.fromJson(item as Map<String, dynamic>))
            .toList();

        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();

          return groups
              .where(
                (g) =>
                    g.name.toLowerCase().contains(q) ||
                    g.inviteCode.contains(q),
              )
              .toList();
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

      filtered = filtered
          .where(
            (g) => g.name.toLowerCase().contains(q) || g.inviteCode.contains(q),
          )
          .toList();
    }

    return filtered;
  }

  /// Get User Dashboard Metrics (Chits Joined, Monthly Payment Due, Defaults)

  static Future<Map<String, dynamic>> getUserDashboardMetrics(
    String memberUsername,
  ) async {
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
              monthlyDue += (groupData['monthly_contribution'] as num)
                  .toDouble();
            }
          }
        }

        return {
          'chitsJoined': chitsJoined,

          'monthlyAmountDue': monthlyDue,

          'totalDefaults': defaultsCount,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getUserDashboardMetrics fallback: ');
      }
    }

    final approvedMockReqs = _mockJoinRequests
        .where(
          (r) =>
              (r.memberUsername == cleanUser ||
                  (cleanUser == 'demo' && r.memberUsername == 'member_demo')) &&
              r.status == 'approved',
        )
        .toList();

    chitsJoined = approvedMockReqs.length;

    for (var req in approvedMockReqs) {
      final group = _mockGroups.firstWhere(
        (g) => g.id == req.groupId,
        orElse: () => _mockGroups.first,
      );

      monthlyDue += group.monthlyContribution;
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
          return DigitalAgreement.fromJson(data);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getDigitalAgreement fallback: $e');
      }
    }

    final found = _mockAgreements
        .where(
          (a) =>
              a.groupId == groupId &&
              (a.memberUsername == cleanUser || cleanUser == 'demo'),
        )
        .toList();

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

      final newStatus = (updatedForemanSigned && updatedMemberSigned)
          ? 'fully_executed'
          : 'pending_signatures';

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

        foremanSignatureUrl: isForeman
            ? signatureUrl
            : current.foremanSignatureUrl,

        foremanSignedAt: isForeman ? now : current.foremanSignedAt,

        memberSigned: updatedMemberSigned,

        memberSignatureUrl: !isForeman
            ? signatureUrl
            : current.memberSignatureUrl,

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

  // ==========================================

  // CHIT INSTALLMENT & PAYMENT LEDGER METHODS

  // ==========================================

  static final List<ChitPaymentRecord> _mockPayments = [
    ChitPaymentRecord(
      id: 'pay_demo_001',

      groupId: 'group_1',

      groupName: 'Indiranagar Traders Chit',

      cycle: 1,

      memberUsername: 'member_demo',

      memberName: 'Demo Member',

      amount: 5000.0,

      amountPaise: 500000,

      paymentMethod: 'UPI',

      status: 'PAID',

      utr: '429182749102',

      paymentSessionId: 'youpi_sess_001',

      payeeVpa: 'safechit.foreman@upi',

      payeeName: 'Rajesh Kumar (Foreman)',

      createdAt: DateTime.now().subtract(const Duration(days: 2)),

      completedAt: DateTime.now().subtract(const Duration(days: 2, minutes: 2)),

      notes: 'Cycle 1 Monthly Installment Paid via Google Pay',
    ),
  ];

  /// Records a new payment session or initiated payment in Supabase & memory

  static Future<bool> recordPayment(ChitPaymentRecord payment) async {
    _mockPayments.removeWhere((p) => p.id == payment.id);

    _mockPayments.insert(0, payment);

    try {
      final supaClient = client;

      if (supaClient != null) {
        await supaClient.from('chit_payments').upsert(payment.toMap());

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase recordPayment fallback: $e');
      }
    }

    return true;
  }

  /// Retrieves all payments for a given Chit Group

  static Future<List<ChitPaymentRecord>> getGroupPayments(
    String groupId,
  ) async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_payments')
            .select()
            .eq('group_id', groupId)
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return response.map((row) => ChitPaymentRecord.fromMap(row)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getGroupPayments fallback: $e');
      }
    }

    return _mockPayments.where((p) => p.groupId == groupId).toList();
  }

  /// Retrieves all payments for a specific subscriber member

  static Future<List<ChitPaymentRecord>> getMemberPayments(
    String memberUsername,
  ) async {
    final cleanUser = memberUsername.trim().toLowerCase();

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_payments')
            .select()
            .eq('member_username', cleanUser)
            .order('created_at', ascending: false);

        if (response.isNotEmpty) {
          return response.map((row) => ChitPaymentRecord.fromMap(row)).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getMemberPayments fallback: $e');
      }
    }

    return _mockPayments
        .where(
          (p) =>
              p.memberUsername.toLowerCase() == cleanUser ||
              cleanUser == 'demo',
        )
        .toList();
  }

  /// Updates an active payment to terminal status (PAID, FAILED, EXPIRED)

  static Future<bool> updatePaymentStatus({
    required String paymentId,

    required String status,

    String? utr,

    DateTime? completedAt,
  }) async {
    final idx = _mockPayments.indexWhere((p) => p.id == paymentId);

    if (idx != -1) {
      final current = _mockPayments[idx];

      _mockPayments[idx] = current.copyWith(
        status: status,

        utr: utr ?? current.utr,

        completedAt: completedAt ?? DateTime.now(),
      );
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        await supaClient
            .from('chit_payments')
            .update({
              'status': status,

              if (utr != null) 'utr': utr,

              'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
            })
            .eq('id', paymentId);

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase updatePaymentStatus fallback: $e');
      }
    }

    return true;
  }

  /// Foreman manual confirmation for in-person cash payments (CASH_COUNTER)

  static Future<bool> confirmCashPayment({
    required String paymentId,

    required String foremanUsername,

    String? notes,
  }) async {
    final now = DateTime.now();

    final idx = _mockPayments.indexWhere((p) => p.id == paymentId);

    if (idx != -1) {
      final current = _mockPayments[idx];

      _mockPayments[idx] = current.copyWith(
        status: 'PAID',

        paymentMethod: 'CASH_COUNTER',

        completedAt: now,

        notes: notes ?? 'Cash payment confirmed by Foreman ($foremanUsername)',
      );
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        await supaClient
            .from('chit_payments')
            .update({
              'status': 'PAID',

              'payment_method': 'CASH_COUNTER',

              'completed_at': now.toIso8601String(),

              'notes':
                  notes ??
                  'Cash payment confirmed by Foreman ($foremanUsername)',
            })
            .eq('id', paymentId);

        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase confirmCashPayment fallback: $e');
      }
    }

    return true;
  }

  /// Find single payment by ID

  static Future<ChitPaymentRecord?> getPaymentById(String paymentId) async {
    final found = _mockPayments.where((p) => p.id == paymentId).toList();

    if (found.isNotEmpty) return found.first;

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_payments')
            .select()
            .eq('id', paymentId)
            .maybeSingle();

        if (response != null) {
          return ChitPaymentRecord.fromMap(response);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase getPaymentById fallback: $e');
      }
    }

    return null;
  }
}
