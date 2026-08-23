import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chit_group.dart';
import '../../services/supabase_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final VoidCallback? onGroupCreated;

  const CreateGroupScreen({
    super.key,
    this.onGroupCreated,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _payoutRulesController = TextEditingController();

  double _totalPoolSize = 1000000; // default ₹10 Lakhs
  int _durationMonths = 10; // default 10 months
  int _targetMembers = 10; // default 10 members
  double _securityDeposit = 25000; // default ₹25k
  
  bool _inviteGenerated = false;
  String _generatedInviteCode = '';

  @override
  void dispose() {
    _nameController.dispose();
    _payoutRulesController.dispose();
    super.dispose();
  }

  void _generateInvite() {
    if (_formKey.currentState!.validate()) {
      final rand = Random();
      final codeNum = rand.nextInt(900000) + 100000; // Produces 6-digit code e.g. 849201
      setState(() {
        _generatedInviteCode = '$codeNum';
        _inviteGenerated = true;
      });
    }
  }

  void _saveGroup() async {
    if (_formKey.currentState!.validate() && _inviteGenerated) {
      final monthlyCont = _totalPoolSize / _durationMonths;
      final newGroup = ChitGroup(
        id: 'group_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        totalPoolSize: _totalPoolSize,
        durationMonths: _durationMonths,
        monthlyContribution: monthlyCont,
        securityDeposit: _securityDeposit,
        payoutRules: _payoutRulesController.text.isEmpty
            ? 'Standard bidding. Minimum bid increment ₹1,000.'
            : _payoutRulesController.text.trim(),
        inviteCode: _generatedInviteCode,
        status: 'Active',
        currentCycle: 1,
        membersCount: _targetMembers,
      );

      await SupabaseService.createChitGroup(newGroup);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Chit Group successfully created and listed!'),
          backgroundColor: Color(0xFF007A87),
        ),
      );

      if (widget.onGroupCreated != null) {
        widget.onGroupCreated!();
      } else {
        Navigator.pop(context);
      }
    } else if (!_inviteGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate the Invite Code and QR Code first.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyContribution = _totalPoolSize / _durationMonths;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Cream Base
      appBar: widget.onGroupCreated == null
          ? AppBar(
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              title: const Text('Create Chit Group'),
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Screen Header
                    const Text(
                      'Launch a Protected Chit',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F4C81), // Primary Deep Teal
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set rules, calculate payouts, and invite members with legally structured default protection.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF5A6E72),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs Section Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Name Input
                          const Text(
                            'Chit Group Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F4C81),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Indiranagar Traders Chit A',
                              fillColor: Color(0xFFFAF7F2),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a group name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Total Pool Size Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Chit Pool (₹)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F4C81),
                                ),
                              ),
                              Text(
                                '₹${_totalPoolSize.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _totalPoolSize,
                            min: 100000,
                            max: 5000000,
                            divisions: 49,
                            activeColor: const Color(0xFF007A87),
                            inactiveColor: const Color(0xFFF2ECE1),
                            onChanged: (val) {
                              setState(() {
                                _totalPoolSize = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Duration Slider
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Duration (Months)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F4C81),
                                ),
                              ),
                              Text(
                                '$_durationMonths Months',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _durationMonths.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 9,
                            activeColor: const Color(0xFF007A87),
                            inactiveColor: const Color(0xFFF2ECE1),
                            onChanged: (val) {
                              setState(() {
                                _durationMonths = val.toInt();
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Target Number of Members
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Number of Members (Capacity)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F4C81),
                                ),
                              ),
                              Text(
                                '$_targetMembers Members',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _targetMembers.toDouble(),
                            min: 5,
                            max: 50,
                            divisions: 45,
                            activeColor: const Color(0xFF007A87),
                            inactiveColor: const Color(0xFFF2ECE1),
                            onChanged: (val) {
                              setState(() {
                                _targetMembers = val.toInt();
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Security Deposit
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Security Deposit (₹)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F4C81),
                                ),
                              ),
                              Text(
                                '₹${_securityDeposit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: _securityDeposit,
                            min: 10000,
                            max: 200000,
                            divisions: 19,
                            activeColor: const Color(0xFF007A87),
                            inactiveColor: const Color(0xFFF2ECE1),
                            onChanged: (val) {
                              setState(() {
                                _securityDeposit = val;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          // Payout Rules
                          const Text(
                            'Custom Payout & Bidding Rules',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F4C81),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _payoutRulesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Max discount 30%, Bid increment ₹2,000. Priority to non-payout members.',
                              fillColor: Color(0xFFFAF7F2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Live Calculation Panel (Glassmorphism / Sand highlight)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2ECE1), // Warm Sand
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Monthly Contribution',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5A6E72),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Per Member / Month',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF5A6E72),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${monthlyContribution.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F4C81),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Invite generation trigger button
                    if (!_inviteGenerated)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _generateInvite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007A87),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Generate Host Invite Code & QR',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    // Generated Invite Panel
                    if (_inviteGenerated) ...[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'SHARE HOST INVITE LINK',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5A6E72),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAF7F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    _generatedInviteCode,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F4C81),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.copy, color: Color(0xFF007A87)),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _generatedInviteCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Invite Code copied to clipboard!'),
                                        backgroundColor: Color(0xFF0F4C81),
                                      ),
                                    );
                                  },
                                  tooltip: 'Copy Code',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Visual Mock QR Code
                            CustomPaint(
                              size: const Size(180, 180),
                              painter: QRMockPainter(code: _generatedInviteCode),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Members scan this QR to auto-link identity, complete credit profiling, and sign the digital chit agreement.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5A6E72),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Save Group Action
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saveGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Activate Group & Save',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to draw a premium mock QR code containing the invite code
class QRMockPainter extends CustomPainter {
  final String code;

  QRMockPainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()
      ..color = const Color(0xFF0F4C81)
      ..style = PaintingStyle.fill;
      
    final paintGold = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.fill;

    // Draw borders & background
    final rectBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      rectBg,
      Paint()
        ..color = const Color(0xFFF2ECE1)
        ..style = PaintingStyle.fill,
    );

    // Draw three outer positioning anchor blocks (top-left, top-right, bottom-left)
    double anchorSize = 40.0;
    
    void drawAnchor(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, anchorSize, anchorSize), paintDark);
      canvas.drawRect(Rect.fromLTWH(x + 5, y + 5, anchorSize - 10, anchorSize - 10), Paint()..color = const Color(0xFFF2ECE1));
      canvas.drawRect(Rect.fromLTWH(x + 10, y + 10, anchorSize - 20, anchorSize - 20), paintDark);
    }

    drawAnchor(10, 10);
    drawAnchor(size.width - anchorSize - 10, 10);
    drawAnchor(10, size.height - anchorSize - 10);

    // Draw mock data modules/pixels
    final random = Random(code.hashCode);
    double pixelSize = 6.0;
    int cols = (size.width - 20) ~/ pixelSize;
    int rows = (size.height - 20) ~/ pixelSize;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        double px = 10 + c * pixelSize;
        double py = 10 + r * pixelSize;

        // Skip anchor block regions
        if ((r < anchorSize / pixelSize + 1 && c < anchorSize / pixelSize + 1) || // top-left
            (r < anchorSize / pixelSize + 1 && c > cols - anchorSize / pixelSize - 2) || // top-right
            (r > rows - anchorSize / pixelSize - 2 && c < anchorSize / pixelSize + 1)) { // bottom-left
          continue;
        }

        // Draw center logo area skip
        if (r > rows / 2 - 3 && r < rows / 2 + 3 && c > cols / 2 - 3 && c < cols / 2 + 3) {
          continue;
        }

        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(px, py, pixelSize - 1.5, pixelSize - 1.5),
            random.nextDouble() > 0.85 ? paintGold : paintDark,
          );
        }
      }
    }

    // Draw central shield icon container
    double logoSize = 36.0;
    double logoX = (size.width - logoSize) / 2;
    double logoY = (size.height - logoSize) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(logoX, logoY, logoSize, logoSize),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(logoX + 2, logoY + 2, logoSize - 4, logoSize - 4),
        const Radius.circular(6),
      ),
      Paint()
        ..color = const Color(0xFF0F4C81)
        ..style = PaintingStyle.fill,
    );

    // Draw mock tiny shield path inside center logo
    final shieldPath = Path()
      ..moveTo(size.width / 2, logoY + 8)
      ..lineTo(size.width / 2 + 8, logoY + 12)
      ..lineTo(size.width / 2 + 8, logoY + 20)
      ..quadraticBezierTo(size.width / 2 + 8, logoY + 28, size.width / 2, logoY + 30)
      ..quadraticBezierTo(size.width / 2 - 8, logoY + 28, size.width / 2 - 8, logoY + 20)
      ..lineTo(size.width / 2 - 8, logoY + 12)
      ..close();
    
    canvas.drawPath(shieldPath, Paint()..color = const Color(0xFFD97706));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
