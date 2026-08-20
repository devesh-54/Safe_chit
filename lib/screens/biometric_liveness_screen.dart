import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class BiometricLivenessScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const BiometricLivenessScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<BiometricLivenessScreen> createState() => _BiometricLivenessScreenState();
}

class _BiometricLivenessScreenState extends State<BiometricLivenessScreen> {
  bool _isCaptured = false;
  bool _isProcessing = false;
  String _currentPrompt = 'Align your face in the oval frame';

  final List<String> _promptsList = [
    'Align your face in the oval frame',
    'Now, blink slowly twice',
    'Perfect, hold still for capture...',
  ];
  int _promptIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.state.selfiePath != null) {
      _isCaptured = true;
    }
  }

  void _nextPrompt() {
    setState(() {
      if (_promptIndex < _promptsList.length - 1) {
        _promptIndex++;
        _currentPrompt = _promptsList[_promptIndex];
        widget.state.setLivenessPrompt(_currentPrompt);
      } else {
        _captureSelfie();
      }
    });
  }

  void _captureSelfie() {
    widget.state.setSelfiePath('captured_selfie_liveness.png');
    setState(() {
      _isCaptured = true;
    });
  }

  void _retakeSelfie() {
    widget.state.resetBiometrics();
    setState(() {
      _isCaptured = false;
      _promptIndex = 0;
      _currentPrompt = _promptsList[0];
    });
  }

  Future<void> _verifyLiveness() async {
    setState(() {
      _isProcessing = true;
    });

    await widget.state.confirmSelfieLiveness();

    if (!mounted) return;
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.biometricStatus;

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
                          'Selfie & Liveness',
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
                      'Ensure you are in a well-lit area. This prevents spoofing and confirms you are performing this registration yourself.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // CAMERA VIEWER AREA
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 3 / 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF334155), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Oval Overlay / Grid lines or Captured Image Mock
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: _isCaptured
                                        ? _buildCapturedPreview()
                                        : CustomPaint(
                                            painter: FaceScannerPainter(
                                              pulseValue: _promptIndex == 1 ? 1.0 : 0.0,
                                            ),
                                          ),
                                  ),
                                ),

                                // Instructions Header Banner
                                if (!_isCaptured)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline_rounded, color: Color(0xFF00B4D8), size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _currentPrompt,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Scanner alignment ring guides (when scanning)
                                if (!_isCaptured)
                                  const Positioned(
                                    bottom: 24,
                                    child: Text(
                                      'Position Face Inside Oval',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CAPTURE STATUS OR PROCESSING MESSAGES
                    if (_isProcessing) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F4C81),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Analyzing biometric liveness and face similarity...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (status == VerificationStatus.verified) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF059669)),
                            SizedBox(width: 12),
                            Text(
                              'Biometric liveness confirmed!',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ACTIONS BUTTON PANEL
                    if (!_isCaptured) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _nextPrompt,
                          icon: Icon(
                            _promptIndex == _promptsList.length - 1
                                ? Icons.camera_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            _promptIndex == _promptsList.length - 1
                                ? 'Capture Selfie'
                                : 'Next Liveness Step',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ] else if (status != VerificationStatus.verified) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _retakeSelfie,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retake'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _verifyLiveness,
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Confirm'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A87),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCapturedPreview() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Silhouette + photo preview indicator
            Icon(Icons.account_box_rounded, size: 200, color: Colors.white.withOpacity(0.2)),
            Positioned(
              bottom: 30,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Selfie Captured Ready',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceScannerPainter extends CustomPainter {
  final double pulseValue;

  FaceScannerPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw dark background mask outside the oval frame
    final ovalPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.70,
          height: size.height * 0.65,
        ),
      );

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlayPath = Path.combine(PathOperation.difference, bgPath, ovalPath);
    canvas.drawPath(overlayPath, paint);

    // Oval outline
    final outlinePaint = Paint()
      ..color = pulseValue > 0 ? const Color(0xFF00B4D8) : const Color(0xFF64748B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.70,
        height: size.height * 0.65,
      ),
      outlinePaint,
    );

    // Face alignment dots / guides
    final guidePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Eyeline marker
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.45),
      Offset(size.width * 0.8, size.height * 0.45),
      guidePaint,
    );

    // Center vertical alignment
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.5, size.height * 0.75),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
