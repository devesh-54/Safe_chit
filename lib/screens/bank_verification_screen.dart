import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class BankVerificationScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const BankVerificationScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<BankVerificationScreen> createState() => _BankVerificationScreenState();
}

class _BankVerificationScreenState extends State<BankVerificationScreen> {
  final _accountController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();

  bool _isLookingUp = false;
  String? _lookupError;
  bool _accountMismatch = false;

  @override
  void initState() {
    super.initState();
    _accountController.text = widget.state.bankAccountNumber;
    _confirmAccountController.text = widget.state.bankAccountNumber;
    _ifscController.text = widget.state.bankIfsc;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _checkIfscAndLookup(String val) async {
    final cleanIfsc = val.toUpperCase().trim();
    if (cleanIfsc.length == 11) {
      setState(() {
        _isLookingUp = true;
        _lookupError = null;
      });

      widget.state.setBankDetails(_accountController.text, cleanIfsc);
      final success = await widget.state.lookupIfsc(cleanIfsc);

      setState(() {
        _isLookingUp = false;
        if (!success) {
          _lookupError = 'Invalid IFSC code pattern. E.g. SBIN0001234 or HDFC0000104';
        }
      });
    } else {
      setState(() {
        _lookupError = null;
      });
    }
  }

  void _validateAccounts() {
    setState(() {
      _accountMismatch = _accountController.text.isNotEmpty &&
          _confirmAccountController.text.isNotEmpty &&
          _accountController.text != _confirmAccountController.text;
    });
    if (!_accountMismatch) {
      widget.state.setBankDetails(_accountController.text, _ifscController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.bankStatus;
    final isVerified = status == VerificationStatus.verified;
    final isHost = widget.state.role == UserRole.host;

    final canContinue = isVerified &&
        _accountController.text.isNotEmpty &&
        _accountController.text == _confirmAccountController.text &&
        !_accountMismatch;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bank Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        StatusBadge(status: status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Provide the account details for receiving prize payouts or chit payments. Real penny-drop testing verifies name match.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // BANK ACCOUNT NUMBER
                    const Text(
                      'Account Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountController,
                      keyboardType: TextInputType.number,
                      enabled: !isVerified,
                      obscureText: !isVerified,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter account number',
                        prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
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
                      onChanged: (val) => _validateAccounts(),
                    ),

                    const SizedBox(height: 20),

                    // CONFIRM ACCOUNT NUMBER
                    const Text(
                      'Confirm Account Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmAccountController,
                      keyboardType: TextInputType.number,
                      enabled: !isVerified,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Re-enter account number',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
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
                      onChanged: (val) => _validateAccounts(),
                    ),

                    if (_accountMismatch) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Account numbers do not match.',
                        style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // IFSC CODE
                    const Text(
                      'IFSC Code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ifscController,
                      maxLength: 11,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !isVerified,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'SBIN0001234',
                        prefixIcon: const Icon(Icons.code_rounded, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
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
                      onChanged: _checkIfscAndLookup,
                    ),

                    if (_isLookingUp) ...[
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4C81)),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Fetching branch details...',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ] else if (_lookupError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lookupError!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ] else if (isVerified) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.account_balance_rounded, color: Color(0xFF16A34A), size: 24),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.state.bankName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.state.bankBranch,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Color(0xFF16A34A), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified IFSC Lookup',
                                        style: TextStyle(
                                          color: Color(0xFF16A34A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],

                    /* 
                     * =========================================================================
                     * INSERTION POINT FOR HOST UPI ID & QR CODE COLLECTION
                     * =========================================================================
                     * 
                     * Since the Host UPI/QR collection screen will be built in a future prompt,
                     * this comment and layout location serves as the integration path.
                     * 
                     * To incorporate later:
                     * if (isHost) {
                     *   // Insert navigation or additional input block:
                     *   // _buildHostUpiQrSection() or route to HostUpiQrScreen.dart
                     * }
                     * =========================================================================
                     */

                    const Spacer(),
                    const SizedBox(height: 32),

                    // CONTINUE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: canContinue ? widget.onContinue : null,
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
                        child: Text(
                          isHost ? 'Continue (UPI Step Next - Planned)' : 'Continue',
                          style: const TextStyle(
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
}
