import 'dart:async';
import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class AccountSetupScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const AccountSetupScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();

  bool _showOtpField = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _isVerifyingEmail = false;

  Timer? _resendTimer;
  int _timerSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.state.mobileNumber;
    _emailController.text = widget.state.emailAddress;
    if (widget.state.mobileStatus == VerificationStatus.verified) {
      _showOtpField = false;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() {
      _timerSeconds = 30;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!context.mounted) {
        timer.cancel();
        return;
      }
      if (_timerSeconds == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _timerSeconds--;
        });
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length != 10) return;
    setState(() {
      _isSendingOtp = true;
    });
    widget.state.setMobileNumber(_phoneController.text);
    await widget.state.sendMobileOtp();
    if (!mounted) return;
    setState(() {
      _isSendingOtp = false;
      _showOtpField = true;
    });
    _startTimer();
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) return;
    setState(() {
      _isVerifyingOtp = true;
    });
    final success = await widget.state.verifyMobileOtp(_otpController.text);
    if (!mounted) return;
    setState(() {
      _isVerifyingOtp = false;
    });
    if (success) {
      setState(() {
        _showOtpField = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number verified successfully!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Try again with code 123456.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    setState(() {
      _isVerifyingEmail = true;
    });
    widget.state.setEmailAddress(email);
    final success = await widget.state.verifyEmail();
    if (!mounted) return;
    setState(() {
      _isVerifyingEmail = false;
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully!'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileVerified = widget.state.mobileStatus == VerificationStatus.verified;
    final isEmailVerified = widget.state.emailStatus == VerificationStatus.verified;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Setup',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Provide contact details. Verifying mobile & email secures communications and multi-factor alerts.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // MOBILE NUMBER INPUT CONTAINER
                    _buildSectionHeader(
                      title: 'Mobile Verification',
                      isVerified: isMobileVerified,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            enabled: !isMobileVerified && !_showOtpField,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              prefixText: '+91 ',
                              prefixStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0A2540),
                              ),
                              hintText: 'Enter 10-digit number',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: isMobileVerified ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {}); // refresh send button status
                            },
                          ),
                        ),
                        if (!isMobileVerified && !_showOtpField) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _phoneController.text.length == 10 && !_isSendingOtp ? _sendOtp : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4C81),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Send OTP'),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // OTP ENTRY BOX
                    if (_showOtpField && !isMobileVerified) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enter 6-Digit OTP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0A2540),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '••••••',
                                      counterText: '',
                                      hintStyle: const TextStyle(letterSpacing: 4),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                    ),
                                    onChanged: (val) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _otpController.text.length == 6 && !_isVerifyingOtp ? _verifyOtp : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF007A87),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isVerifyingOtp
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Verify'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _canResend
                                      ? 'Didn\'t receive code?'
                                      : 'Resend code in ${_timerSeconds}s',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _canResend ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                if (_canResend)
                                  TextButton(
                                    onPressed: _sendOtp,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        color: Color(0xFF0F4C81),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // EMAIL INPUT CONTAINER
                    _buildSectionHeader(
                      title: 'Email Verification',
                      isVerified: isEmailVerified,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !isEmailVerified,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your email address',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: isEmailVerified ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setState(() {}); // refresh email verify button status
                            },
                          ),
                        ),
                        if (!isEmailVerified) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _emailController.text.trim().contains('@') && !_isVerifyingEmail
                                  ? _verifyEmail
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4C81),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isVerifyingEmail
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Verify'),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 32),

                    // CONTINUE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isMobileVerified && isEmailVerified ? widget.onContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
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
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({required String title, required bool isVerified}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isVerified
              ? const Row(
                  key: ValueKey('verified'),
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : const Row(
                  key: ValueKey('pending'),
                  children: [
                    Icon(Icons.pending_actions_rounded, color: Color(0xFF64748B), size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Pending Verification',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
