import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/onboarding_state.dart';

import '../models/chit_group.dart';

import '../models/member_risk.dart';

import '../models/chit_join_request.dart';

import '../models/digital_agreement.dart';

import '../models/chit_payment_record.dart';

import '../models/guarantee_request.dart';

import '../models/reputation_event.dart';

import '../models/security_deposit.dart';

import 'package:flutter/widgets.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/dev/mock_fallback.dart';
import '../core/config/deposit_config.dart';

class SupabaseService {
  /// Observable error state. Non-null means a backend call failed.
  /// Cleared automatically after the next successful call.
  static final ValueNotifier<String?> lastBackendError = ValueNotifier<String?>(null);

  /// Log a read-method failure. Sets [lastBackendError].
  /// Returns the mock data if [kAllowMockFallback] is true, otherwise rethrows.
  static T _guardRead<T>(String method, Object error, T mockData) {
    final reason = '$method: ${_shortReason(error)}';
    debugPrint('⚠️ [SupabaseService] READ fallback — $reason');
    lastBackendError.value = reason;
    if (kAllowMockFallback) return mockData;
    throw error;
  }

  /// Log a write-method failure. Sets [lastBackendError].
  /// Rethrows, or returns [failureResult] if provided.
  static T _guardWrite<T>(
    String method,
    Object error, {
    bool hasFailureResult = false,
    T? failureResult,
  }) {
    final reason = '$method: ${_shortReason(error)}';
    debugPrint('❌ [SupabaseService] WRITE failed — $reason');
    lastBackendError.value = reason;
    if (hasFailureResult) return failureResult as T;
    throw error;
  }

  /// Clear the error after a successful call.
  static void _clearError() {
    if (lastBackendError.value != null) lastBackendError.value = null;
  }

  /// Check deposit server health on app start when [kDevTools] is true.
  static Future<void> checkDepositServerHealth() async {
    try {
      final url = Uri.parse('$kDepositBackendUrl/health');
      final res = await http.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) {
        lastBackendError.value = 'Deposit server unreachable at $kDepositBackendUrl';
        debugPrint('⚠️ [SupabaseService] Deposit server returned ${res.statusCode}');
      } else {
        debugPrint('✅ [SupabaseService] Deposit server health OK ($kDepositBackendUrl)');
      }
    } catch (e) {
      lastBackendError.value = 'Deposit server unreachable at $kDepositBackendUrl';
      debugPrint('⚠️ [SupabaseService] Deposit server unreachable at $kDepositBackendUrl: $e');
    }
  }

  static String _shortReason(Object e) {
    final s = e.toString();
    if (s.length <= 80) return s;
    return '${s.substring(0, 77)}...';
  }

  static final List<SecurityDeposit> _mockSecurityDeposits = [];
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

  // High-performance in-memory caches to eliminate redundant network round trips
  static final Map<String, Map<String, dynamic>> _userProfileCache = {};
  static final Map<String, UserRole> _userRoleCache = {};
  static final Map<String, ChitGroup> _groupCache = {};

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
        if (kDevTools) {
          // Check deposit server health on app start
          checkDepositServerHealth();
        }
      }

      debugPrint('✅ Supabase initialized successfully.');
    } catch (e) {
      debugPrint('ℹ️ Supabase initialization note: $e');
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

    if (kAllowMockFallback && _registeredUsernames.contains(cleanUsername)) {
      return false;
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        try {
          final response = await supaClient
              .from('user_onboardings')
              .select('username')
              .eq('username', cleanUsername)
              .maybeSingle();

          if (response != null) {
            _clearError();
            return false;
          }
        } catch (_) {
          final response = await supaClient
              .from('profiles')
              .select('username')
              .eq('username', cleanUsername)
              .maybeSingle();

          if (response != null) {
            _clearError();
            return false;
          }
        }
        _clearError();
      }
      return true;
    } catch (e) {
      return _guardRead(
        'isUsernameUnique',
        e,
        !_registeredUsernames.contains(cleanUsername),
      );
    }
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

    try {
      final supaClient = client;

      if (supaClient == null) {
        if (kAllowMockFallback) {
          lastBackendError.value =
              'registerUser: Supabase client not initialized (offline simulation)';
          _registeredUsernames.add(cleanUsername);
          _userCredentials[cleanUsername] = password;
          return null;
        }
        throw Exception('Supabase client is not initialized.');
      }

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

      _registeredUsernames.add(cleanUsername);
      _userCredentials[cleanUsername] = password;
      _clearError();
      debugPrint('✅ Successfully stored onboarding data in user_onboardings table!');
      return null;
    } catch (e) {
      if (kAllowMockFallback) {
        lastBackendError.value =
            'registerUser: $e (offline simulation)';
        debugPrint('ℹ️ [SupabaseService] registerUser offline simulation: $e');
        _registeredUsernames.add(cleanUsername);
        _userCredentials[cleanUsername] = password;
        return null;
      }
      return _guardWrite(
        'registerUser',
        e,
        hasFailureResult: true,
        failureResult: e.toString(),
      );
    }
  }

  /// Authenticate username and password for Sign In
  static Future<bool> authenticate({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('user_onboardings')
            .select(
              'username, password, role, full_name, mobile_number, email, perm_city, created_at',
            )
            .ilike('username', cleanUsername)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (response != null && response['password'] == password) {
          final profileMap = Map<String, dynamic>.from(response);
          _userProfileCache[cleanUsername] = profileMap;
          final roleStr = response['role']?.toString().toLowerCase() ?? '';
          if (roleStr == 'host' || roleStr == 'foreman') {
            _userRoleCache[cleanUsername] = UserRole.host;
          } else {
            _userRoleCache[cleanUsername] = UserRole.member;
          }
          _clearError();
          return true; // Match found in Supabase
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Supabase auth notice: $e');
      if (kAllowMockFallback && _userCredentials.containsKey(cleanUsername)) {
        if (_userCredentials[cleanUsername] == password) {
          lastBackendError.value =
              'authenticate: Using offline demo credentials ($e)';
          return true;
        }
      }
      return _guardRead('authenticate', e, false);
    }

    if (kAllowMockFallback && _userCredentials.containsKey(cleanUsername)) {
      if (_userCredentials[cleanUsername] == password) {
        lastBackendError.value =
            'authenticate: Using offline demo credentials';
        return true;
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

      if (supaClient == null) throw Exception('Supabase client is not initialized.');

      final file = File(filePath);

      if (!await file.exists()) throw Exception('File does not exist: $filePath');

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
      _clearError();
      return publicUrl;
    } catch (e) {
      return _guardWrite(
        'uploadImage',
        e,
        hasFailureResult: true,
        failureResult: null,
      );
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

    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      if (groupId != null) {
        await supaClient
            .from('chit_groups')
            .update({'foreman_upi_id': cleanUpi})
            .eq('id', groupId);
      } else {
        await supaClient
            .from('chit_groups')
            .update({'foreman_upi_id': cleanUpi})
            .neq('id', '');
      }

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

      _clearError();
      debugPrint('✅ Supabase: Updated foreman_upi_id to $cleanUpi');
      return true;
    } catch (e) {
      return _guardWrite(
        'updateForemanUpiId',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
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

    if (_userRoleCache.containsKey(cleanUsername)) {
      return _userRoleCache[cleanUsername]!;
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('user_onboardings')
            .select('role')
            .ilike('username', cleanUsername)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (response != null && response['role'] != null) {
          final roleStr = response['role'].toString().toLowerCase();
          final userRole = roleStr == 'host' || roleStr == 'foreman'
              ? UserRole.host
              : UserRole.member;
          _userRoleCache[cleanUsername] = userRole;
          _clearError();
          return userRole;
        }
      }
      _clearError();
    } catch (e) {
      UserRole fallbackRole = UserRole.member;
      if (cleanUsername == 'foreman_admin' ||
          cleanUsername.contains('host') ||
          cleanUsername.contains('foreman')) {
        fallbackRole = UserRole.host;
      }
      return _guardRead('getUserRole', e, fallbackRole);
    }

    // Default local demo fallback if not found in db
    if (cleanUsername == 'foreman_admin' ||
        cleanUsername.contains('host') ||
        cleanUsername.contains('foreman')) {
      _userRoleCache[cleanUsername] = UserRole.host;
      return UserRole.host;
    }

    return UserRole.member;
  }

  /// Get user profile (full name, phone, email, city) from user_onboardings
  /// Sanity check if username exists for guarantor nomination
  static Future<bool> checkUserExists(String username) async {
    final cleanUsername = username.trim().toLowerCase();

    if (cleanUsername.isEmpty) return false;

    try {
      final supaClient = client;

      if (supaClient != null) {
        final res = await supaClient
            .from('user_onboardings')
            .select('username')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (res != null) {
          _clearError();
          return true;
        }
      }
      _clearError();
    } catch (e) {
      final inMock = _userCredentials.containsKey(cleanUsername) ||
          cleanUsername == 'member_demo' ||
          cleanUsername == 'foreman' ||
          cleanUsername == 'member_test2';
      return _guardRead('checkUserExists', e, inMock);
    }

    if (kAllowMockFallback &&
        (_userCredentials.containsKey(cleanUsername) ||
            cleanUsername == 'member_demo' ||
            cleanUsername == 'foreman' ||
            cleanUsername == 'member_test2')) {
      return true;
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

    if (_userProfileCache.containsKey(cleanUsername)) {
      return _userProfileCache[cleanUsername];
    }

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
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        // If not found, try searching by full_name
        if (profile == null) {
          final firstWord = cleanUsername.split(' ').first;
          profile = await supaClient
              .from('user_onboardings')
              .select(
                'full_name, mobile_number, email, perm_city, username, role, created_at',
              )
              .ilike('full_name', '%$firstWord%')
              .maybeSingle()
              .timeout(const Duration(seconds: 3));
        }

        if (profile != null) {
          final map = Map<String, dynamic>.from(profile);
          _userProfileCache[cleanUsername] = map;
          _clearError();
          return map;
        }
      }
      _clearError();
    } catch (e) {
      Map<String, dynamic> fallbackProfile = {
        'full_name': username,
        'username': username,
        'mobile_number': '9876500000',
        'email': '$cleanUsername@chitguard.in',
        'perm_city': 'Bengaluru',
        'role': 'member',
        'created_at': '2026-10-01T10:00:00Z',
      };
      if (cleanUsername.contains('foreman')) {
        fallbackProfile = {
          'full_name': 'Rajesh Kumar (Foreman)',
          'username': 'foreman_admin',
          'mobile_number': '9876543210',
          'email': 'foreman@chitguard.in',
          'perm_city': 'Chennai',
          'role': 'host',
          'created_at': '2026-09-01T10:00:00Z',
        };
      } else if (cleanUsername.contains('member_test2')) {
        fallbackProfile = {
          'full_name': 'Suresh Raina',
          'username': 'member_test2',
          'mobile_number': '9876599999',
          'email': 'member2@chitguard.in',
          'perm_city': 'Bengaluru',
          'role': 'member',
          'created_at': '2026-10-15T10:00:00Z',
        };
      } else if (cleanUsername.contains('suresh') || cleanUsername.contains('member')) {
        fallbackProfile = {
          'full_name': 'Suresh Raina',
          'username': 'member_demo',
          'mobile_number': '9876512345',
          'email': 'suresh.raina@chitguard.in',
          'perm_city': 'Bengaluru',
          'role': 'member',
          'created_at': '2026-10-01T10:00:00Z',
        };
      }
      return _guardRead('getUserProfile', e, fallbackProfile);
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
          _clearError();
          return response
              .map((json) => ReputationEvent.fromJson(json))
              .toList();
        }
      }
      _clearError();
      return [];
    } catch (e) {
      final mock = _mockReputationEvents
          .where((ev) {
            final matchesUser = ev.username.toLowerCase() == cleanUser ||
                cleanUser.contains(ev.username.toLowerCase()) ||
                ev.username.toLowerCase().contains(cleanUser);
            final matchesRole =
                role == null || ev.role.toLowerCase() == role.toLowerCase();
            return matchesUser && matchesRole;
          })
          .toList();
      return _guardRead('getReputationEvents', e, mock);
    }
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

  /// Returns a map of groupId -> actual joined member count from group_members and approved join requests
  static Future<Map<String, int>> getGroupMemberCounts() async {
    final Map<String, int> counts = {};

    try {
      final supaClient = client;
      if (supaClient != null) {
        final Map<String, Set<String>> groupMembersMap = {};

        List<Map<String, dynamic>> memberRows = [];
        List<Map<String, dynamic>> joinRows = [];

        await Future.wait([
          supaClient
              .from('group_members')
              .select('group_id, name, phone')
              .timeout(const Duration(seconds: 3))
              .then((res) => memberRows = List<Map<String, dynamic>>.from(res))
              .catchError((_) => memberRows = []),
          supaClient
              .from('chit_join_requests')
              .select('group_id, member_username, member_phone')
              .eq('status', 'approved')
              .timeout(const Duration(seconds: 3))
              .then((res) => joinRows = List<Map<String, dynamic>>.from(res))
              .catchError((_) => joinRows = []),
        ]);

        for (var row in memberRows) {
          final gid = row['group_id'] as String? ?? '';
          final identifier = (row['phone'] as String? ?? row['name'] as String? ?? '').trim();
          if (gid.isNotEmpty) {
            groupMembersMap.putIfAbsent(gid, () => <String>{});
            if (identifier.isNotEmpty) {
              groupMembersMap[gid]!.add(identifier);
            } else {
              groupMembersMap[gid]!.add('mbr_${groupMembersMap[gid]!.length}');
            }
          }
        }

        for (var row in joinRows) {
          final gid = row['group_id'] as String? ?? '';
          final identifier = (row['member_username'] as String? ?? row['member_phone'] as String? ?? '').trim();
          if (gid.isNotEmpty && identifier.isNotEmpty) {
            groupMembersMap.putIfAbsent(gid, () => <String>{});
            groupMembersMap[gid]!.add(identifier);
          }
        }

        groupMembersMap.forEach((k, v) {
          counts[k] = v.length;
        });

        _clearError();
        return counts;
      }
      _clearError();
      return counts;
    } catch (e) {
      final fallbackCounts = <String, int>{};
      for (var m in _mockMembers) {
        fallbackCounts[m.groupId] = (fallbackCounts[m.groupId] ?? 0) + 1;
      }
      return _guardRead('getGroupMemberCounts', e, fallbackCounts);
    }
  }

  /// Returns a map of groupId -> pending handshake payments count
  static Future<Map<String, int>> getPendingHandshakeCounts() async {
    final Map<String, int> counts = {};

    try {
      final supaClient = client;
      if (supaClient != null) {
        final rows = await supaClient
            .from('chit_payments')
            .select('group_id, status')
            .inFilter('status', ['INITIATED', 'ACTIVE', 'QUEUED', 'AWAITING_CONFIRMATION'])
            .timeout(const Duration(seconds: 3));
        final Map<String, int> dbCounts = {};
        for (var row in rows) {
          final gid = row['group_id'] as String? ?? '';
          if (gid.isNotEmpty) {
            dbCounts[gid] = (dbCounts[gid] ?? 0) + 1;
          }
        }
        dbCounts.forEach((k, v) {
          counts[k] = v;
        });
        _clearError();
        return counts;
      }
      _clearError();
      return counts;
    } catch (e) {
      final fallbackCounts = <String, int>{};
      for (var p in _mockPayments) {
        if (p.isPending) {
          fallbackCounts[p.groupId] = (fallbackCounts[p.groupId] ?? 0) + 1;
        }
      }
      return _guardRead('getPendingHandshakeCounts', e, fallbackCounts);
    }
  }

  /// Fetch all chit groups (with actual joined member counts)
  static Future<List<ChitGroup>> getChitGroups() async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        // Parallel fetch groups and actual member counts
        final results = await Future.wait([
          supaClient.from('chit_groups').select().timeout(const Duration(seconds: 4)),
          getGroupMemberCounts(),
        ]);

        final response = results[0] as List<dynamic>;
        final counts = results[1] as Map<String, int>;

        if (response.isNotEmpty) {
          _clearError();
          return response.map((json) {
            final g = ChitGroup.fromJson(json);
            final realCount = counts[g.id] ?? 0;
            final updated = g.copyWith(membersCount: realCount);
            _groupCache[g.id] = updated;
            return updated;
          }).toList();
        }
      }
      _clearError();
      return [];
    } catch (e) {
      final counts = await getGroupMemberCounts();
      final mock = _mockGroups.map((g) {
        final realCount = counts[g.id] ?? _mockMembers.where((m) => m.groupId == g.id).length;
        final updated = g.copyWith(membersCount: realCount);
        _groupCache[g.id] = updated;
        return updated;
      }).toList();
      return _guardRead('getChitGroups', e, mock);
    }
  }

  /// Fetch a single chit group by ID
  static Future<ChitGroup?> getChitGroupById(String id) async {
    if (_groupCache.containsKey(id)) {
      return _groupCache[id];
    }

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_groups')
            .select()
            .eq('id', id)
            .maybeSingle()
            .timeout(const Duration(seconds: 3));

        if (response != null) {
          final g = ChitGroup.fromJson(response);
          _groupCache[id] = g;
          _clearError();
          return g;
        }
      }
      _clearError();
      return null;
    } catch (e) {
      final found = _mockGroups.where((g) => g.id == id).toList();
      return _guardRead('getChitGroupById', e, found.isNotEmpty ? found.first : null);
    }
  }

  /// Fetch all group members across all groups in a single query
  static Future<Map<String, List<ChitMemberRisk>>> getAllGroupMembers() async {
    final Map<String, List<ChitMemberRisk>> memberMap = {};

    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('group_members')
            .select()
            .timeout(const Duration(seconds: 4));

        if (response.isNotEmpty) {
          for (var json in response) {
            final member = ChitMemberRisk.fromJson(json);
            memberMap.putIfAbsent(member.groupId, () => []).add(member);
          }
          _clearError();
          return memberMap;
        }
      }
      _clearError();
      return memberMap;
    } catch (e) {
      final fallbackMap = <String, List<ChitMemberRisk>>{};
      for (var m in _mockMembers) {
        fallbackMap.putIfAbsent(m.groupId, () => []).add(m);
      }
      return _guardRead('getAllGroupMembers', e, fallbackMap);
    }
  }

  /// Create a new chit group
  static Future<void> createChitGroup(ChitGroup group) async {
    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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

      // Add to in-memory list ONLY upon success
      if (!_mockGroups.any((g) => g.id == group.id)) {
        _mockGroups.add(group);
      }
      _clearError();
      debugPrint('✅ Supabase: Chit group ${group.name} created successfully.');
    } catch (e) {
      _guardWrite('createChitGroup', e);
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
          _clearError();
          return response.map((json) => ChitMemberRisk.fromJson(json)).toList();
        }
      }
      _clearError();
      return [];
    } catch (e) {
      return _guardRead(
        'getGroupMembers',
        e,
        _mockMembers.where((m) => m.groupId == groupId).toList(),
      );
    }
  }

  /// Allows the group foreman to join their own group as a member.
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

    // Persist to Supabase first
    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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

      // Update mock lists only after success
      _mockMembers.add(hostMember);
      final groupIndex = _mockGroups.indexWhere((g) => g.id == group.id);
      if (groupIndex != -1) {
        final g = _mockGroups[groupIndex];
        _mockGroups[groupIndex] = g.copyWith(membersCount: g.membersCount + 1);
      }
      _mockPayments.insert(0, hostPayment);

      _clearError();
      return true;
    } catch (e) {
      return _guardWrite(
        'joinGroupAsHostMember',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  /// Trigger forfeiture for a member in a group (Escrow Control)
  static Future<void> triggerForfeiture(String memberId) async {
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('group_members')
          .update({
            'forfeited': true,
            'default_risk_score': 100.0,
            'amount_exposed': 0,
          })
          .eq('id', memberId);

      final index = _mockMembers.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        final oldMember = _mockMembers[index];
        _mockMembers[index] = oldMember.copyWith(
          forfeited: true,
          defaultRiskScore: 100.0,
          amountExposed: 0,
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Triggered forfeiture for member $memberId');
    } catch (e) {
      _guardWrite('triggerForfeiture', e);
    }
  }

  /// Generate and persist a Section 28 Default Notice
  static Future<void> saveDefaultNotice(
    String memberId,
    String noticeText,
  ) async {
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('group_members')
          .update({
            'default_notice_sent': true,
            'default_notice_text': noticeText,
          })
          .eq('id', memberId);

      final index = _mockMembers.indexWhere((m) => m.id == memberId);
      if (index != -1) {
        final oldMember = _mockMembers[index];
        _mockMembers[index] = oldMember.copyWith(
          defaultNoticeSent: true,
          defaultNoticeText: noticeText,
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Saved default notice for member $memberId');
    } catch (e) {
      _guardWrite('saveDefaultNotice', e);
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
          _clearError();
          return ChitGroup.fromJson(response);
        }
      }
      _clearError();
    } catch (e) {
      ChitGroup? found;
      try {
        found = _mockGroups.firstWhere(
          (g) =>
              g.inviteCode.trim() == cleanCode ||
              g.inviteCode.endsWith(cleanCode),
        );
      } catch (_) {
        found = null;
      }
      return _guardRead('getGroupByInviteCode', e, found);
    }

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

  /// Checks whether a given user is an active or approved member of a chit group.
  static Future<bool> isUserMemberOfGroup({
    required String groupId,
    required String username,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;

    try {
      final supaClient = client;
      if (supaClient != null) {
        String? userFullName;
        try {
          final profile = await supaClient
              .from('user_onboardings')
              .select('full_name')
              .eq('username', cleanUsername)
              .maybeSingle();
          userFullName =
              (profile?['full_name'] as String?)?.trim().toLowerCase();
        } catch (_) {}

        // 1. Query group_members
        final memberRows = await supaClient
            .from('group_members')
            .select('id, name')
            .eq('group_id', groupId);

        for (final row in memberRows) {
          final name = (row['name'] as String? ?? '').trim().toLowerCase();
          if (name == cleanUsername ||
              (userFullName != null && name == userFullName)) {
            _clearError();
            return true;
          }
        }

        // 2. Query chit_join_requests for approved status
        final joinRows = await supaClient
            .from('chit_join_requests')
            .select('id')
            .eq('group_id', groupId)
            .eq('status', 'approved')
            .ilike('member_username', cleanUsername);

        if (joinRows.isNotEmpty) {
          _clearError();
          return true;
        }
        _clearError();
        return false;
      }
    } catch (e) {
      final inMock = _mockMembers.any(
            (m) =>
                m.groupId == groupId &&
                m.name.trim().toLowerCase() == cleanUsername,
          ) ||
          _mockJoinRequests.any(
            (r) =>
                r.groupId == groupId &&
                r.memberUsername.trim().toLowerCase() == cleanUsername &&
                r.status == 'approved',
          );
      return _guardRead('isUserMemberOfGroup', e, inMock);
    }

    // Local check fallback
    final inMockMembers = _mockMembers.any(
      (m) =>
          m.groupId == groupId &&
          m.name.trim().toLowerCase() == cleanUsername,
    );
    if (inMockMembers) return true;

    final inMockJoinRequests = _mockJoinRequests.any(
      (r) =>
          r.groupId == groupId &&
          r.memberUsername.trim().toLowerCase() == cleanUsername &&
          r.status == 'approved',
    );
    return inMockJoinRequests;
  }

  /// Checks whether a given user is an active or pending guarantor in a chit group.
  static Future<bool> isUserGuarantorInGroup({
    required String groupId,
    required String username,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;

    try {
      final supaClient = client;
      if (supaClient != null) {
        final grRows = await supaClient
            .from('guarantee_requests')
            .select('id, status')
            .eq('group_id', groupId)
            .ilike('guarantor_id', cleanUsername);

        for (final row in grRows) {
          final status = (row['status'] as String? ?? '').toLowerCase();
          if (status == 'accepted' || status == 'pending') {
            _clearError();
            return true;
          }
        }

        final jrRows = await supaClient
            .from('chit_join_requests')
            .select('id, status')
            .eq('group_id', groupId)
            .ilike('guarantor_username', cleanUsername)
            .neq('status', 'rejected');

        if (jrRows.isNotEmpty) {
          _clearError();
          return true;
        }
        _clearError();
        return false;
      }
    } catch (e) {
      final inMock = _mockGuaranteeRequests.any(
            (g) =>
                g.groupId == groupId &&
                g.guarantorId.trim().toLowerCase() == cleanUsername &&
                (g.status == 'accepted' || g.status == 'pending'),
          ) ||
          _mockJoinRequests.any(
            (r) =>
                r.groupId == groupId &&
                (r.guarantorUsername ?? '').trim().toLowerCase() == cleanUsername &&
                r.status != 'rejected',
          );
      return _guardRead('isUserGuarantorInGroup', e, inMock);
    }

    final inMockGuarantees = _mockGuaranteeRequests.any(
      (g) =>
          g.groupId == groupId &&
          g.guarantorId.trim().toLowerCase() == cleanUsername &&
          (g.status == 'accepted' || g.status == 'pending'),
    );
    if (inMockGuarantees) return true;

    final inMockJoinRequests = _mockJoinRequests.any(
      (r) =>
          r.groupId == groupId &&
          (r.guarantorUsername ?? '').trim().toLowerCase() == cleanUsername &&
          r.status != 'rejected',
    );
    return inMockJoinRequests;
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

    // Member-Guarantor Mutual Exclusion Checks:
    // A: Applicant cannot already be a guarantor in this group
    final isApplicantGuarantor = await isUserGuarantorInGroup(
      groupId: group.id,
      username: cleanUsername,
    );
    if (isApplicantGuarantor) {
      debugPrint(
        '❌ Mutual exclusion: Applicant @$cleanUsername is already a guarantor in group ${group.id}',
      );
      return false;
    }

    // B: Applicant cannot nominate themselves
    if (cleanGuarantor != null && cleanGuarantor == cleanUsername) {
      debugPrint('❌ Mutual exclusion: Applicant cannot nominate themselves as guarantor');
      return false;
    }

    // C: Nominated guarantor cannot already be a member of this group
    if (cleanGuarantor != null && cleanGuarantor.isNotEmpty) {
      final isGuarantorMember = await isUserMemberOfGroup(
        groupId: group.id,
        username: cleanGuarantor,
      );
      if (isGuarantorMember) {
        debugPrint(
          '❌ Mutual exclusion: Nominated guarantor @$cleanGuarantor is already a member of group ${group.id}',
        );
        return false;
      }
    }

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

    GuaranteeRequest? guaranteeReq;
    if (cleanGuarantor != null && cleanGuarantor.isNotEmpty) {
      guaranteeReq = GuaranteeRequest(
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
    }

    // Save to Supabase first
    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      try {
        await supaClient.from('chit_join_requests').upsert(newReq.toJson());
      } catch (_) {
        await supaClient.from('chit_join_requests').upsert(newReq.toDbJson());
      }

      if (guaranteeReq != null) {
        await supaClient
            .from('guarantee_requests')
            .insert(guaranteeReq.toJson());
      }

      // Add to in-memory only upon success
      _mockJoinRequests.add(newReq);
      if (guaranteeReq != null) {
        _mockGuaranteeRequests.add(guaranteeReq);
      }
      _clearError();
      return true;
    } catch (e) {
      return _guardWrite(
        'submitJoinRequest',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

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
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 4));

        if (response.isNotEmpty) {
          final list = await Future.wait(response.map((item) async {
            var req = GuaranteeRequest.fromJson(item);
            final group = await getChitGroupById(req.groupId);
            final profile = await getUserProfile(req.memberId);
            return req.copyWith(
              groupName: group?.name ?? 'Chit Group',
              chitValue: group?.totalPoolSize ?? 0.0,
              durationMonths: group?.durationMonths ?? 1,
              memberName:
                  profile?['full_name'] as String? ?? 'Member ${req.memberId}',
            );
          }));
          _clearError();
          return list;
        }
      }
      _clearError();
      return [];
    } catch (e) {
      return _guardRead(
        'getGuaranteeRequestsForGuarantor',
        e,
        _mockGuaranteeRequests
            .where((r) => r.guarantorId.toLowerCase() == cleanGuarantor)
            .toList(),
      );
    }
  }

  /// Accept or Decline an incoming guarantee request
  static Future<bool> respondToGuaranteeRequest({
    required String requestId,
    required bool accept,
  }) async {
    final newStatus = accept ? 'accepted' : 'declined';
    final now = DateTime.now();

    final mockIdx = _mockGuaranteeRequests.indexWhere((r) => r.id == requestId);

    // Mutual Exclusion Check: A user who is already a member of this group CANNOT accept to be a guarantor
    if (accept) {
      String? targetGroupId;
      String? targetGuarantorId;

      if (mockIdx != -1) {
        targetGroupId = _mockGuaranteeRequests[mockIdx].groupId;
        targetGuarantorId = _mockGuaranteeRequests[mockIdx].guarantorId;
      }

      if (targetGroupId == null || targetGuarantorId == null) {
        try {
          final supaClient = client;
          if (supaClient != null) {
            final row = await supaClient
                .from('guarantee_requests')
                .select('group_id, guarantor_id')
                .eq('id', requestId)
                .maybeSingle();
            if (row != null) {
              targetGroupId = row['group_id'] as String?;
              targetGuarantorId = row['guarantor_id'] as String?;
            }
          }
        } catch (_) {}
      }

      if (targetGroupId != null && targetGuarantorId != null) {
        final isMember = await isUserMemberOfGroup(
          groupId: targetGroupId,
          username: targetGuarantorId,
        );
        if (isMember) {
          debugPrint(
            '❌ Mutual exclusion: Guarantor @$targetGuarantorId is already a member of group $targetGroupId',
          );
          return false;
        }
      }
    }

    String? joinReqId;
    if (mockIdx != -1) {
      joinReqId = _mockGuaranteeRequests[mockIdx].joinRequestId;
    }

    // Persist to Supabase first
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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

      if (updatedRows.length != 1) {
        throw Exception('Expected exactly 1 row updated, got ${updatedRows.length}');
      }

      if (joinReqId != null) {
        try {
          await supaClient
              .from('chit_join_requests')
              .update({'guarantor_status': newStatus})
              .eq('id', joinReqId);
        } catch (_) {}
      }

      // Update in-memory only upon success
      if (mockIdx != -1) {
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

      _clearError();
      return true;
    } catch (e) {
      return _guardWrite(
        'respondToGuaranteeRequest',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  static Future<List<ChitJoinRequest>> getPendingJoinRequests() async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_join_requests')
            .select()
            .eq('status', 'pending')
            .timeout(const Duration(seconds: 4));

        if (response.isNotEmpty) {
          List<dynamic> guaranteeRows = [];
          try {
            guaranteeRows = await supaClient
                .from('guarantee_requests')
                .select()
                .order('created_at', ascending: false)
                .timeout(const Duration(seconds: 4));
          } catch (_) {}

          final allGuarantees = [
            ...guaranteeRows.map((r) => GuaranteeRequest.fromJson(r)),
            ..._mockGuaranteeRequests,
          ];

          final list = response.map((j) {
            var req = ChitJoinRequest.fromJson(j);
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
                    g.memberId.toLowerCase() == req.memberUsername.toLowerCase() &&
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
                    g.memberId.toLowerCase() == req.memberUsername.toLowerCase()) {
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
          _clearError();
          return list;
        }
      }
      _clearError();
      return [];
    } catch (e) {
      final fallback = _mockJoinRequests.where((r) => r.status == 'pending').map((req) {
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
      return _guardRead('getPendingJoinRequests', e, fallback);
    }
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
            .ilike('member_username', cleanUsername)
            .timeout(const Duration(seconds: 4));

        final List<dynamic> rows = List.from(response);

        if (rows.isEmpty) {
          try {
            final altRows = await supaClient
                .from('chit_join_requests')
                .select()
                .or('member_email.ilike.$cleanUsername,member_phone.ilike.$cleanUsername')
                .timeout(const Duration(seconds: 3));
            rows.addAll(altRows);
          } catch (_) {}
        }

        try {
          final profile = await supaClient
              .from('user_onboardings')
              .select('username, mobile_number, email')
              .or('username.ilike.$cleanUsername,email.ilike.$cleanUsername,mobile_number.ilike.$cleanUsername')
              .maybeSingle()
              .timeout(const Duration(seconds: 3));
          if (profile != null) {
            final canonical =
                (profile['username'] as String? ?? '').trim().toLowerCase();
            if (canonical.isNotEmpty && canonical != cleanUsername) {
              final canonicalRows = await supaClient
                  .from('chit_join_requests')
                  .select()
                  .ilike('member_username', canonical)
                  .timeout(const Duration(seconds: 3));
              for (var cr in canonicalRows) {
                if (!rows.any((r) => r['id'] == cr['id'])) {
                  rows.add(cr);
                }
              }
            }
          }
        } catch (_) {}

        List<dynamic> guaranteeRows = [];
        try {
          guaranteeRows = await supaClient
              .from('guarantee_requests')
              .select()
              .ilike('member_id', cleanUsername);
        } catch (_) {}

        final Map<String, dynamic> grByJoinReq = {};
        final Map<String, dynamic> grByGroup = {};

        for (var gr in guaranteeRows) {
          final jid = gr['join_request_id'] as String?;
          if (jid != null && jid.isNotEmpty) grByJoinReq[jid] = gr;
          final gid = gr['group_id'] as String? ?? '';
          if (gid.isNotEmpty) grByGroup[gid] = gr;
        }

        final liveRequests = rows.map((j) {
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

        final isDemo = cleanUsername == 'demo' ||
            cleanUsername == 'demo_member' ||
            cleanUsername == 'member_demo';
        if (isDemo && kAllowMockFallback) {
          for (var mr in _mockJoinRequests) {
            if (!liveRequests.any((r) => r.groupId == mr.groupId)) {
              liveRequests.add(mr);
            }
          }
        }
        _clearError();
        return liveRequests;
      }
      _clearError();
      return [];
    } catch (e) {
      final isDemo = cleanUsername == 'demo' ||
          cleanUsername == 'demo_member' ||
          cleanUsername == 'member_demo';

      final fallback = _mockJoinRequests
          .where(
            (r) =>
                r.memberUsername.toLowerCase() == cleanUsername ||
                (isDemo &&
                    (r.memberUsername == 'member_demo' ||
                        r.memberUsername == 'demo_member')),
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
      return _guardRead('getMemberJoinRequests', e, fallback);
    }
  }

  /// Accept or Reject a Join Request
  static Future<bool> respondToJoinRequest({
    required String requestId,
    required bool accept,
  }) async {
    final newStatus = accept ? 'approved' : 'rejected';
    final idx = _mockJoinRequests.indexWhere((r) => r.id == requestId);

    if (accept) {
      String? groupId;
      String? memberUsername;
      String? guarantorUsername;

      if (idx != -1) {
        final req = _mockJoinRequests[idx];
        groupId = req.groupId;
        memberUsername = req.memberUsername;
        guarantorUsername = req.guarantorUsername;
      } else {
        try {
          final supaClient = client;
          if (supaClient != null) {
            final row = await supaClient
                .from('chit_join_requests')
                .select()
                .eq('id', requestId)
                .maybeSingle();
            if (row != null) {
              groupId = row['group_id'] as String?;
              memberUsername = row['member_username'] as String?;
              guarantorUsername = row['guarantor_username'] as String?;
            }
          }
        } catch (_) {}
      }

      if (groupId != null && memberUsername != null) {
        final isGuarantor = await isUserGuarantorInGroup(
          groupId: groupId,
          username: memberUsername,
        );
        if (isGuarantor) {
          debugPrint(
            '❌ Mutual exclusion: Applicant @$memberUsername is already a guarantor in group $groupId',
          );
          return false;
        }

        if (guarantorUsername != null && guarantorUsername.trim().isNotEmpty) {
          final isGuarantorMember = await isUserMemberOfGroup(
            groupId: groupId,
            username: guarantorUsername,
          );
          if (isGuarantorMember) {
            debugPrint(
              '❌ Mutual exclusion: Nominated guarantor @$guarantorUsername is already a member of group $groupId',
            );
            return false;
          }
        }
      }
    }

    // Persist to Supabase first
    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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
              ? 'Verified (@${req.guarantorUsername})'
              : (req.guarantorUsername != null
                    ? 'Pending (@${req.guarantorUsername})'
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

      // Update mock lists only upon success
      if (idx != -1) {
        final req = _mockJoinRequests[idx];
        _mockJoinRequests[idx] = req.copyWith(status: newStatus);

        if (accept) {
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

      _clearError();
      return true;
    } catch (e) {
      return _guardWrite(
        'respondToJoinRequest',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
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

        final List<dynamic> data = await req.timeout(const Duration(seconds: 4));

        final groups = data
            .map((item) => ChitGroup.fromJson(item as Map<String, dynamic>))
            .toList();

        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim().toLowerCase();
          _clearError();
          return groups
              .where(
                (g) =>
                    g.name.toLowerCase().contains(q) ||
                    g.inviteCode.contains(q),
              )
              .toList();
        }

        if (groups.isNotEmpty) {
          _clearError();
          return groups;
        }
      }
      _clearError();
      return [];
    } catch (e) {
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
      return _guardRead('getPublicChitGroups', e, filtered);
    }
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
            .eq('status', 'approved')
            .timeout(const Duration(seconds: 4));

        chitsJoined = joinReqs.length;

        final groupIds = joinReqs
            .map((r) => r['group_id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        if (groupIds.isNotEmpty) {
          final groupsData = await supaClient
              .from('chit_groups')
              .select('id, monthly_contribution')
              .inFilter('id', groupIds)
              .timeout(const Duration(seconds: 4));

          for (var g in groupsData) {
            monthlyDue += ((g['monthly_contribution'] as num?)?.toDouble() ?? 0.0);
          }
        }

        _clearError();
        return {
          'chitsJoined': chitsJoined,
          'monthlyAmountDue': monthlyDue,
          'totalDefaults': defaultsCount,
        };
      }
      _clearError();
      return {
        'chitsJoined': 0,
        'monthlyAmountDue': 0.0,
        'totalDefaults': 0,
      };
    } catch (e) {
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

      final fallback = {
        'chitsJoined': chitsJoined,
        'monthlyAmountDue': monthlyDue,
        'totalDefaults': defaultsCount,
      };
      return _guardRead('getUserDashboardMetrics', e, fallback);
    }
  }

  /// Save or Update Digital Agreement
  static Future<bool> saveDigitalAgreement(DigitalAgreement agreement) async {
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient.from('digital_agreements').upsert(agreement.toJson());

      _mockAgreements.removeWhere((a) => a.id == agreement.id);
      _mockAgreements.add(agreement);
      _clearError();
      debugPrint('✅ Supabase: Saved digital agreement ${agreement.id}');
      return true;
    } catch (e) {
      return _guardWrite(
        'saveDigitalAgreement',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
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
            .maybeSingle()
            .timeout(const Duration(seconds: 4));

        if (data != null) {
          _clearError();
          return DigitalAgreement.fromJson(data);
        }
      }
      _clearError();
      return null;
    } catch (e) {
      final found = _mockAgreements
          .where(
            (a) =>
                a.groupId == groupId &&
                (a.memberUsername == cleanUser || cleanUser == 'demo'),
          )
          .toList();
      return _guardRead(
        'getDigitalAgreement',
        e,
        found.isNotEmpty ? found.last : null,
      );
    }
  }

  /// Digitally Sign Agreement (Host or Subscriber)
  static Future<bool> signDigitalAgreement({
    required String agreementId,
    required bool isForeman,
    required String signatureUrl,
  }) async {
    final now = DateTime.now();

    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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

      // Update mock only upon success
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

      _clearError();
      debugPrint('✅ Supabase: Signed digital agreement $agreementId');
      return true;
    } catch (e) {
      return _guardWrite(
        'signDigitalAgreement',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  // ==========================================
  // CHIT INSTALLMENT & PAYMENT LEDGER METHODS
  // ==========================================

  static final List<ChitPaymentRecord> _mockPayments = [
    ChitPaymentRecord(
      id: 'pay_handshake_001',
      groupId: 'group_1',
      groupName: 'Indiranagar Traders Chit',
      cycle: 1,
      memberUsername: 'ramesh_verma',
      memberName: 'Ramesh Verma',
      amount: 10000.0,
      amountPaise: 1000000,
      paymentMethod: 'UPI',
      status: 'INITIATED',
      utr: 'UPI_9823746123',
      paymentSessionId: 'sess_handshake_001',
      payeeVpa: 'devesh1@oksbi',
      payeeName: 'Foreman',
      createdAt: DateTime.now().subtract(const Duration(minutes: 35)),
      notes: 'UPI payment submitted, awaiting foreman confirmation',
    ),
    ChitPaymentRecord(
      id: 'pay_handshake_002',
      groupId: 'group_2',
      groupName: 'Koramangala Professionals Chit',
      cycle: 1,
      memberUsername: 'suresh_raina',
      memberName: 'Suresh Raina',
      amount: 10000.0,
      amountPaise: 1000000,
      paymentMethod: 'UPI',
      status: 'INITIATED',
      utr: 'UPI_5544332211',
      paymentSessionId: 'sess_handshake_002',
      payeeVpa: 'devesh1@oksbi',
      payeeName: 'Foreman',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      notes: 'UPI payment submitted, awaiting foreman confirmation',
    ),
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
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient.from('chit_payments').upsert(payment.toMap());

      _mockPayments.removeWhere((p) => p.id == payment.id);
      _mockPayments.insert(0, payment);
      _clearError();
      debugPrint('✅ Supabase: Recorded payment ${payment.id}');
      return true;
    } catch (e) {
      return _guardWrite(
        'recordPayment',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
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
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 4));

        if (response.isNotEmpty) {
          _clearError();
          return response.map((row) => ChitPaymentRecord.fromMap(row)).toList();
        }
      }
      _clearError();
      return [];
    } catch (e) {
      return _guardRead(
        'getGroupPayments',
        e,
        _mockPayments.where((p) => p.groupId == groupId).toList(),
      );
    }
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
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 4));

        if (response.isNotEmpty) {
          _clearError();
          return response.map((row) => ChitPaymentRecord.fromMap(row)).toList();
        }
      }
      _clearError();
      return [];
    } catch (e) {
      final fallback = _mockPayments
          .where(
            (p) =>
                p.memberUsername.toLowerCase() == cleanUser ||
                cleanUser == 'demo',
          )
          .toList();
      return _guardRead('getMemberPayments', e, fallback);
    }
  }

  /// Updates an active payment to terminal status (PAID, FAILED, EXPIRED)
  static Future<bool> updatePaymentStatus({
    required String paymentId,
    required String status,
    String? utr,
    DateTime? completedAt,
  }) async {
    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('chit_payments')
          .update({
            'status': status,
            if (utr != null) 'utr': utr,
            'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
          })
          .eq('id', paymentId);

      final idx = _mockPayments.indexWhere((p) => p.id == paymentId);
      if (idx != -1) {
        final current = _mockPayments[idx];
        _mockPayments[idx] = current.copyWith(
          status: status,
          utr: utr ?? current.utr,
          completedAt: completedAt ?? DateTime.now(),
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Updated payment status $paymentId to $status');
      return true;
    } catch (e) {
      return _guardWrite(
        'updatePaymentStatus',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  /// Foreman manual confirmation for in-person cash payments (CASH_COUNTER)
  static Future<bool> confirmCashPayment({
    required String paymentId,
    required String foremanUsername,
    String? notes,
  }) async {
    final now = DateTime.now();

    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

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
      _clearError();
      debugPrint('✅ Supabase: Confirmed cash payment $paymentId');
      return true;
    } catch (e) {
      return _guardWrite(
        'confirmCashPayment',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  /// Foreman manual confirmation for online UPI handshake payments
  static Future<bool> confirmPaymentHandshake({
    required String paymentId,
    required String foremanUsername,
    String? notes,
  }) async {
    final now = DateTime.now();

    try {
      final supaClient = client;

      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('chit_payments')
          .update({
            'status': 'PAID',
            'completed_at': now.toIso8601String(),
            'notes':
                notes ?? 'UPI payment handshake confirmed by Foreman ($foremanUsername)',
          })
          .eq('id', paymentId);

      final idx = _mockPayments.indexWhere((p) => p.id == paymentId);
      if (idx != -1) {
        final current = _mockPayments[idx];
        _mockPayments[idx] = current.copyWith(
          status: 'PAID',
          completedAt: now,
          notes: notes ?? 'UPI payment handshake confirmed by Foreman ($foremanUsername)',
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Confirmed payment handshake $paymentId');
      return true;
    } catch (e) {
      return _guardWrite(
        'confirmPaymentHandshake',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  /// Find single payment by ID
  static Future<ChitPaymentRecord?> getPaymentById(String paymentId) async {
    try {
      final supaClient = client;

      if (supaClient != null) {
        final response = await supaClient
            .from('chit_payments')
            .select()
            .eq('id', paymentId)
            .maybeSingle();

        if (response != null) {
          _clearError();
          return ChitPaymentRecord.fromMap(response);
        }
      }
      _clearError();
      return null;
    } catch (e) {
      final found = _mockPayments.where((p) => p.id == paymentId).toList();
      return _guardRead(
        'getPaymentById',
        e,
        found.isNotEmpty ? found.first : null,
      );
    }
  }

  // ==========================================
  // SECURITY DEPOSITS (RAZORPAY TEST MODE)
  // ==========================================

  static Future<Map<String, dynamic>> createDepositOrder({
    required String groupId,
    required String memberId,
    required double amount,
  }) async {
    final amountPaise = (amount * 100).toInt();

    try {
      final url = Uri.parse('$kDepositBackendUrl/api/create-deposit-order');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'memberId': memberId,
          'amount': amount,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _clearError();
        return {
          'orderId': data['orderId'],
          'amount': data['amount'] ?? amountPaise,
          'currency': data['currency'] ?? 'INR',
          'depositId': data['depositId'],
        };
      } else {
        throw Exception('Server returned ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      return _guardWrite(
        'createDepositOrder',
        e,
        hasFailureResult: true,
        failureResult: {
          'error': e.toString(),
          'orderId': null,
          'depositId': null,
          'amount': amountPaise,
          'currency': 'INR',
        },
      );
    }
  }

  static Future<bool> verifyDepositSignature({
    required String depositId,
    required String orderId,
    required String paymentId,
    required String signature,
    required String groupId,
    required String memberId,
    required double amount,
  }) async {
    final now = DateTime.now();
    final deposit = SecurityDeposit(
      id: depositId,
      groupId: groupId,
      memberId: memberId,
      amount: amount,
      status: 'held',
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient.from('security_deposits').upsert(deposit.toJson());

      // Update mock only upon success
      _mockSecurityDeposits.removeWhere((d) => d.groupId == groupId && d.memberId == memberId);
      _mockSecurityDeposits.add(deposit);
      _clearError();
      debugPrint('✅ Supabase: Verified and stored security deposit $depositId as held');
      return true;
    } catch (e) {
      return _guardWrite(
        'verifyDepositSignature',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  static Future<SecurityDeposit?> getSecurityDeposit({
    required String groupId,
    required String memberId,
  }) async {
    try {
      final supaClient = client;
      if (supaClient != null) {
        final row = await supaClient
            .from('security_deposits')
            .select()
            .eq('group_id', groupId)
            .eq('member_id', memberId)
            .order('created_at', ascending: false)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (row != null) {
          _clearError();
          return SecurityDeposit.fromJson(row);
        }
      }
      _clearError();
      return null;
    } catch (e) {
      final found = _mockSecurityDeposits.where((d) => d.groupId == groupId && d.memberId == memberId).toList();
      return _guardRead(
        'getSecurityDeposit',
        e,
        found.isNotEmpty ? found.last : null,
      );
    }
  }

  static Future<Map<String, SecurityDeposit>> getGroupSecurityDeposits(
    String groupId,
  ) async {
    final Map<String, SecurityDeposit> result = {};

    try {
      final supaClient = client;
      if (supaClient != null) {
        final List<dynamic> rows = await supaClient
            .from('security_deposits')
            .select()
            .eq('group_id', groupId);
        for (final r in rows) {
          final dep = SecurityDeposit.fromJson(r as Map<String, dynamic>);
          result[dep.memberId] = dep;
        }
        _clearError();
        return result;
      }
      _clearError();
      return result;
    } catch (e) {
      final fallbackMap = <String, SecurityDeposit>{};
      for (final d in _mockSecurityDeposits) {
        if (d.groupId == groupId) {
          fallbackMap[d.memberId] = d;
        }
      }
      return _guardRead('getGroupSecurityDeposits', e, fallbackMap);
    }
  }

  static Future<bool> refundDeposit({
    required String depositId,
    required String groupId,
    required String memberId,
    required double amount,
  }) async {
    final now = DateTime.now();

    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('security_deposits')
          .update({'status': 'refunded', 'updated_at': now.toIso8601String()})
          .eq('group_id', groupId)
          .eq('member_id', memberId);

      // Ledger entry
      await recordPayment(ChitPaymentRecord(
        id: 'refund_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        groupName: 'Chit Group Deposit Refund',
        cycle: 0,
        memberUsername: memberId,
        memberName: memberId,
        amount: amount,
        amountPaise: (amount * 100).toInt(),
        paymentMethod: 'TEST_REFUND',
        status: 'PAID',
        payeeVpa: '$memberId@upi',
        payeeName: memberId,
        createdAt: now,
        completedAt: now,
        notes: 'Test: Security deposit refunded to member',
      ));

      final idx = _mockSecurityDeposits.indexWhere((d) => d.groupId == groupId && d.memberId == memberId);
      if (idx != -1) {
        final existing = _mockSecurityDeposits[idx];
        _mockSecurityDeposits[idx] = SecurityDeposit(
          id: depositId,
          groupId: groupId,
          memberId: memberId,
          amount: amount,
          status: 'refunded',
          razorpayOrderId: existing.razorpayOrderId,
          razorpayPaymentId: existing.razorpayPaymentId,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Refunded security deposit for $memberId in $groupId');
      return true;
    } catch (e) {
      return _guardWrite(
        'refundDeposit',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }

  static Future<bool> forfeitDeposit({
    required String depositId,
    required String groupId,
    required String memberId,
    required double amount,
  }) async {
    final now = DateTime.now();

    try {
      final supaClient = client;
      if (supaClient == null) {
        throw Exception('Supabase client is not initialized.');
      }

      await supaClient
          .from('security_deposits')
          .update({'status': 'forfeited', 'updated_at': now.toIso8601String()})
          .eq('group_id', groupId)
          .eq('member_id', memberId);

      // Ledger entry for forfeit applied to missed contribution
      await recordPayment(ChitPaymentRecord(
        id: 'forfeit_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        groupName: 'Chit Group Deposit Forfeit',
        cycle: 0,
        memberUsername: memberId,
        memberName: memberId,
        amount: amount,
        amountPaise: (amount * 100).toInt(),
        paymentMethod: 'DEPOSIT_FORFEIT',
        status: 'PAID',
        payeeVpa: 'foreman@safechit',
        payeeName: 'Foreman Pool',
        createdAt: now,
        completedAt: now,
        notes: 'Test: Security deposit forfeited and applied to missed contribution',
      ));

      final idx = _mockSecurityDeposits.indexWhere((d) => d.groupId == groupId && d.memberId == memberId);
      if (idx != -1) {
        final existing = _mockSecurityDeposits[idx];
        _mockSecurityDeposits[idx] = SecurityDeposit(
          id: depositId,
          groupId: groupId,
          memberId: memberId,
          amount: amount,
          status: 'forfeited',
          razorpayOrderId: existing.razorpayOrderId,
          razorpayPaymentId: existing.razorpayPaymentId,
          createdAt: existing.createdAt,
          updatedAt: now,
        );
      }
      _clearError();
      debugPrint('✅ Supabase: Forfeited security deposit for $memberId in $groupId');
      return true;
    } catch (e) {
      return _guardWrite(
        'forfeitDeposit',
        e,
        hasFailureResult: true,
        failureResult: false,
      );
    }
  }
}
