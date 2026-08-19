import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class VerificationSummaryScreen extends StatelessWidget {
  final OnboardingState state;
  final VoidCallback onRestart;

  const VerificationSummaryScreen({
    super.key,
    required this.state,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final overall = state.overallStatus;
    
    Color overallColor;
    String overallTitle;
    String overallDesc;
    IconData overallIcon;

    switch (overall) {
      case VerificationStatus.verified:
        overallColor = const Color(0xFF059669); // Emerald 600
        overallTitle = 'Account Fully Verified';
        overallDesc = 'Your identity is validated. You have unlocked standard chit limits.';
        overallIcon = Icons.verified_user_rounded;
        break;
      case VerificationStatus.inProgress:
        overallColor = const Color(0xFFD97706); // Amber 600
        overallTitle = 'Verification Pending';
        overallDesc = 'Some identity items are currently being processed or require input.';
        overallIcon = Icons.security_rounded;
        break;
      case VerificationStatus.failed:
        overallColor = const Color(0xFFDC2626); // Red 600
        overallTitle = 'Verification Rejected';
        overallDesc = 'One or more identity items failed central registry validation checks.';
        overallIcon = Icons.gpp_bad_rounded;
        break;
      case VerificationStatus.notStarted:
        overallColor = const Color(0xFF64748B); // Slate 500
        overallTitle = 'Onboarding Not Complete';
        overallDesc = 'Please complete the registration steps to access ChitGuard.';
        overallIcon = Icons.shield_outlined;
        break;
    }

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
                      'Verification Status',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your verification passport is revisitable at any time under Settings > Verification Summary.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // OVERALL STATUS HERO CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: overallColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: overallColor.withOpacity(0.15), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: overallColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(overallIcon, size: 40, color: overallColor),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            overallTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: overallColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            overallDesc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          StatusBadge(status: overall),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'VERIFICATION CHECKLIST',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // CHECKLIST ITEMS
                    _buildChecklistItem(
                      title: 'Role Selection',
                      subtitle: state.role == UserRole.member ? 'Member selected' : 'Host (Foreman) selected',
                      status: state.role != null ? VerificationStatus.verified : VerificationStatus.notStarted,
                      icon: Icons.badge_outlined,
                    ),
                    _buildChecklistItem(
                      title: 'Mobile Verification',
                      subtitle: state.mobileNumber.isNotEmpty ? '+91 ${state.mobileNumber}' : 'Not verified',
                      status: state.mobileStatus,
                      icon: Icons.phone_android_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'Email Verification',
                      subtitle: state.emailAddress.isNotEmpty ? state.emailAddress : 'Not verified',
                      status: state.emailStatus,
                      icon: Icons.alternate_email_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'Personal Details',
                      subtitle: state.legalName.isNotEmpty ? state.legalName : 'Not completed',
                      status: state.identityStatus,
                      icon: Icons.face_retouching_natural_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'Government ID Lookup',
                      subtitle: state.panNumber.isNotEmpty ? 'PAN: ${state.panNumber}' : 'Not uploaded',
                      status: state.govIdStatus,
                      icon: Icons.credit_card_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'Biometric Face-match',
                      subtitle: state.selfiePath != null ? 'Liveness selfie recorded' : 'Not recorded',
                      status: state.biometricStatus,
                      icon: Icons.photo_camera_front_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'Address Verification',
                      subtitle: state.permAddress.isNotEmpty ? '${state.permCity}, ${state.permState}' : 'Not entered',
                      status: state.addressStatus,
                      icon: Icons.location_on_outlined,
                    ),
                    _buildChecklistItem(
                      title: 'Bank Verification',
                      subtitle: state.bankName.isNotEmpty ? '${state.bankName} • ${state.bankIfsc}' : 'Not linked',
                      status: state.bankStatus,
                      icon: Icons.account_balance_rounded,
                    ),
                    _buildChecklistItem(
                      title: 'KYC Legal Consent',
                      subtitle: state.hasConsented ? 'Authorized' : 'Pending agreement',
                      status: state.consentStatus,
                      icon: Icons.description_outlined,
                    ),

                    const SizedBox(height: 24),

                    // SECURITY COMPLIANCE NOTE
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF0F4C81), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Compliance audits are run periodically. Auto-checks confirm documents match central databases to ensure security.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 32),

                    // ACTIONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onRestart,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Start Over',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: overall == VerificationStatus.verified
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Onboarding complete! Mock project session ended.'),
                                        backgroundColor: Color(0xFF059669),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F4C81),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              disabledForegroundColor: const Color(0xFF94A3B8),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Go to Home',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required VerificationStatus status,
    required IconData icon,
  }) {
    Color checkColor;
    IconData checkIcon;

    switch (status) {
      case VerificationStatus.verified:
        checkColor = const Color(0xFF10B981); // Emerald
        checkIcon = Icons.check_circle_rounded;
        break;
      case VerificationStatus.inProgress:
        checkColor = const Color(0xFFF59E0B); // Amber
        checkIcon = Icons.hourglass_empty_rounded;
        break;
      case VerificationStatus.failed:
        checkColor = const Color(0xFFEF4444); // Red
        checkIcon = Icons.cancel_rounded;
        break;
      case VerificationStatus.notStarted:
        checkColor = const Color(0xFF94A3B8); // Slate 400
        checkIcon = Icons.radio_button_unchecked_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(checkIcon, color: checkColor, size: 22),
        ],
      ),
    );
  }
}
