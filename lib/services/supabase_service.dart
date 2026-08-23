import 'dart:io';
import '../models/onboarding_state.dart';
import '../models/chit_group.dart';
import '../models/member_risk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://sjemdgjcjjozaljhzvzm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZW1kZ2pjampvemFsamh6dnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjgwMDgsImV4cCI6MjEwMjgwNDAwOH0.EdvMnsMwI0HoX8p55hJE5LfYsYTM5rs4M8ZvoDrDB5A';

  static bool _isInitialized = false;

  // In-memory fallback registry for offline/local simulation
  static final Set<String> _registeredUsernames = {'admin', 'host', 'demo', 'foreman_admin'};
  static final Map<String, String> _userCredentials = {
    'admin': 'admin123',
    'host': 'host123',
    'demo': 'demo123',
    'foreman_admin': 'foreman123',
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
}
