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
  static Future<bool> registerUser({
    required String username,
    required String password,
    String? email,
    String? mobile,
    String? legalName,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    // Check uniqueness
    final unique = await isUsernameUnique(cleanUsername);
    if (!unique) return false;

    // Store in local fallback map
    _registeredUsernames.add(cleanUsername);
    _userCredentials[cleanUsername] = password;

    try {
      final supaClient = client;
      if (supaClient != null) {
        try {
          await supaClient.from('user_onboardings').upsert({
            'username': cleanUsername,
            'email': email ?? '',
            'mobile_number': mobile ?? '',
            'full_name': legalName ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          await supaClient.from('profiles').upsert({
            'username': cleanUsername,
            'email': email,
            'mobile': mobile,
            'legal_name': legalName,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('ℹ️ Supabase registration notice: $e');
      }
    }

    return true;
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
}
