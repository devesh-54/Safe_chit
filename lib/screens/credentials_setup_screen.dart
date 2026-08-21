import 'dart:async';
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../services/supabase_service.dart';

class CredentialsSetupScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const CredentialsSetupScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<CredentialsSetupScreen> createState() => _CredentialsSetupScreenState();
}

class _CredentialsSetupScreenState extends State<CredentialsSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Timer? _debounceTimer;

  bool _isCheckingUsername = false;
  bool _isUsernameUnique = false;
  String? _usernameErrorText;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.state.username.isNotEmpty) {
      _usernameController.text = widget.state.username;
      _checkUsername(widget.state.username);
    }
    if (widget.state.password.isNotEmpty) {
      _passwordController.text = widget.state.password;
      _confirmPasswordController.text = widget.state.password;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final cleanValue = value.trim();
    if (cleanValue.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameUnique = false;
        _usernameErrorText = 'Username must be at least 3 characters long.';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameErrorText = null;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _checkUsername(cleanValue);
    });
  }

  Future<void> _checkUsername(String username) async {
    final cleanUsername = username.trim();
    if (cleanUsername.length < 3) return;

    setState(() {
      _isCheckingUsername = true;
    });

    final isUnique = await SupabaseService.isUsernameUnique(cleanUsername);

    if (!mounted) return;

    setState(() {
      _isCheckingUsername = false;
      _isUsernameUnique = isUnique;
      if (!isUnique) {
        _usernameErrorText = 'This username is already taken on Supabase. Try another.';
      } else {
        _usernameErrorText = null;
      }
    });
  }

  double _calculatePasswordStrength() {
    final pass = _passwordController.text;
    if (pass.isEmpty) return 0.0;
    double strength = 0.0;
    if (pass.length >= 6) strength += 0.33;
    if (pass.length >= 8 && RegExp(r'[A-Z]').hasMatch(pass)) strength += 0.33;
    if (RegExp(r'[0-9!@#\$&*~]').hasMatch(pass)) strength += 0.34;
    return strength.clamp(0.0, 1.0);
  }

  Future<void> _handleSaveAndContinue() async {
    if (_formKey.currentState!.validate() && _isUsernameUnique) {
      setState(() {
        _isSaving = true;
      });

      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // Register with Supabase
      await SupabaseService.registerUser(
        username: username,
        password: password,
        state: widget.state,
      );

      if (!mounted) return;

      widget.state.setCredentials(username, password);

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username "$username" successfully registered on Supabase!'),
          backgroundColor: const Color(0xFF0F4C81),
        ),
      );

      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = _calculatePasswordStrength();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F4C81), Color(0xFF007A87)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260F4C81),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.key_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Step 10: Set Up Sign-In Credentials',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Choose a unique username and secure password to log in to ChitGuard',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username Label & Supabase Check Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Choose Unique Username',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A2540),
                            ),
                          ),
                          if (_isCheckingUsername)
                            Row(
                              children: const [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0F4C81),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Checking Supabase...',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF0F4C81)),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _usernameController,
                        onChanged: _onUsernameChanged,
                        decoration: InputDecoration(
                          hintText: 'e.g. rajesh_host99',
                          prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF64748B)),
                          suffixIcon: _isCheckingUsername
                              ? null
                              : (_isUsernameUnique
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : (_usernameController.text.trim().length >= 3
                                      ? const Icon(Icons.cancel, color: Colors.red)
                                      : null)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          if (!_isUsernameUnique) {
                            return _usernameErrorText ?? 'Username is already taken';
                          }
                          return null;
                        },
                      ),

                      // Username Status Feedback Banner
                      const SizedBox(height: 8),
                      if (_isUsernameUnique && _usernameController.text.trim().length >= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.verified, color: Colors.green, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Username is unique & verified on Supabase ✓',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_usernameErrorText != null)
                        Text(
                          _usernameErrorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),

                      const SizedBox(height: 24),

                      // Password Field
                      const Text(
                        'Create Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      // Password Strength Indicator
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: passwordStrength,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: passwordStrength < 0.4
                                    ? Colors.red
                                    : (passwordStrength < 0.7 ? Colors.amber : Colors.green),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              passwordStrength < 0.4
                                  ? 'Weak'
                                  : (passwordStrength < 0.7 ? 'Medium' : 'Strong'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: passwordStrength < 0.4
                                    ? Colors.red
                                    : (passwordStrength < 0.7 ? Colors.amber : Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Confirm Password Field
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A2540),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_reset_outlined, color: Color(0xFF64748B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      // Submit / Save Credentials Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_isSaving || !_isUsernameUnique) ? null : _handleSaveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Complete Registration & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
