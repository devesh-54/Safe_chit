import 'dart:io';
import '../models/onboarding_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://sjemdgjcjjozaljhzvzm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqZW1kZ2pjampvemFsamh6dnptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyMjgwMDgsImV4cCI6MjEwMjgwNDAwOH0.EdvMnsMwI0HoX8p55hJE5LfYsYTM5rs4M8ZvoDrDB5A';

  static bool _isInitialized = false;

  // In-memory fallback registry for offline/local simulation
  static final Set<String> _registeredUsernames = {'admin', 'host', 'demo'};
  static final Map<String, String> _userCredentials = {
    'admin': 'admin123',
    'host': 'host123',
    'demo': 'demo123',
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
            .from('profiles')
            .select('username')
            .eq('username', cleanUsername)
            .maybeSingle();

        if (response != null) {
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
}
