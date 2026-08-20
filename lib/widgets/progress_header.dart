import 'package:flutter/material.dart';

class ProgressHeader extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final VoidCallback? onBackPressed;
  final VoidCallback? onSummaryPressed;
  final bool showSummaryIcon;

  const ProgressHeader({
    super.key,
    required this.currentStep,
    this.totalSteps = 9,
    this.onBackPressed,
    this.onSummaryPressed,
    this.showSummaryIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentStep / totalSteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              onBackPressed != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                        onPressed: onBackPressed,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    )
                  : const SizedBox(width: 40),
              Text(
                'Step $currentStep of $totalSteps',
                style: const TextStyle(
                  color: Color(0xFF475569), // slate 600
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              showSummaryIcon && onSummaryPressed != null
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.dashboard_customize_outlined,
                          size: 20,
                          color: Color(0xFF0F4C81),
                        ),
                        tooltip: 'Status Summary',
                        onPressed: onSummaryPressed,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    )
                  : const SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0), // slate 200
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    width: maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F4C81), Color(0xFF007A87)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
