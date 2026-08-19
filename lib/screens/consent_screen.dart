import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class ConsentScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const ConsentScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checked = widget.state.hasConsented;
  }

  void _onCheckboxChanged(bool? value) {
    if (value != null) {
      setState(() {
        _checked = value;
      });
      widget.state.setConsent(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.consentStatus;

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
                          'KYC Consent',
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
                      'Please read the terms below carefully. Your consent is required to process and verify your information.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SCROLLABLE LEGAL TERMS CONTAINER
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    '1. Identity Verification Consent',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'I hereby authorize ChitGuard and its registered verification partners to verify my details (including PAN, Aadhaar, address and banking information) with the respective government bodies, credit information companies, and authorized registries for licensing and risk management purposes.',
                                    style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '2. Biometric and Selfie Data Processing',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'I consent to the collection, scanning, and processing of my selfie photograph to perform face-match algorithm tests against government databases. This verification ensures that I am opening my account in person and protects the system from digital identity theft or spoofing.',
                                    style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '3. Bank Verification Penny Drop',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'I authorize the verification system to perform a trial account name match (penny-drop validation) to confirm that the bank account provided is active and registered under my legal name.',
                                    style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '4. Security and Data Protection',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'All documents and metadata are fully encrypted in-transit and at-rest using military-grade AES-256 protocols. Your information will never be sold, leased, or distributed to third-party marketing companies, and will strictly remain accessible only under regulatory compliance rules of the Chit Funds Act, 1982.',
                                    style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CHECKBOX TILE
                    InkWell(
                      onTap: () => _onCheckboxChanged(!_checked),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          color: _checked ? const Color(0xFFF0FDF4) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _checked ? const Color(0xFFDCFCE7) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _checked,
                              activeColor: const Color(0xFF0F4C81),
                              onChanged: _onCheckboxChanged,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 10.0),
                                child: Text(
                                  'I consent to KYC verification and processing of my data as described in the agreement above.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CONTINUE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _checked ? widget.onContinue : null,
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
                          'Agree & Continue',
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
}
