import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';

class StatusBadge extends StatelessWidget {
  final VerificationStatus status;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color textColor;
    final String label;
    final IconData icon;

    switch (status) {
      case VerificationStatus.notStarted:
        backgroundColor = const Color(0xFFF1F5F9); // slate 100
        textColor = const Color(0xFF64748B); // slate 500
        label = 'Not Started';
        icon = Icons.radio_button_unchecked;
        break;
      case VerificationStatus.inProgress:
        backgroundColor = const Color(0xFFFEF3C7); // amber 100
        textColor = const Color(0xFFD97706); // amber 600
        label = 'Verifying...';
        icon = Icons.hourglass_top_rounded;
        break;
      case VerificationStatus.verified:
        backgroundColor = const Color(0xFFD1FAE5); // emerald 100
        textColor = const Color(0xFF059669); // emerald 600
        label = 'Verified';
        icon = Icons.check_circle_rounded;
        break;
      case VerificationStatus.failed:
        backgroundColor = const Color(0xFFFEE2E2); // red 100
        textColor = const Color(0xFFDC2626); // red 600
        label = 'Verification Failed';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
