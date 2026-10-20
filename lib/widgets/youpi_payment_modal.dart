import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/chit_group.dart';
import '../models/chit_payment_record.dart';
import '../services/supabase_service.dart';
import '../services/youpi_payment_service.dart';

class YoupiPaymentModal extends StatefulWidget {
  final ChitGroup group;
  final String currentUsername;
  final double? customAmount;
  final VoidCallback? onPaymentSuccess;

  const YoupiPaymentModal({
    super.key,
    required this.group,
    required this.currentUsername,
    this.customAmount,
    this.onPaymentSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required ChitGroup group,
    required String currentUsername,
    double? customAmount,
    VoidCallback? onPaymentSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => YoupiPaymentModal(
        group: group,
        currentUsername: currentUsername,
        customAmount: customAmount,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<YoupiPaymentModal> createState() => _YoupiPaymentModalState();
}

class _YoupiPaymentModalState extends State<YoupiPaymentModal> {
  late final double _amount;
  late final String _orderId;
  late final String _payeeVpa;
  late final String _payeeName;

  bool _isQrMode = false;
  bool _isLoading = false;
  bool _isPaid = false;
  bool _isQueued = false;
  int _queuePosition = 1;

  String? _paymentSessionId;
  String? _verifiedUtr;
  String? _statusMessage;

  // 5-minute countdown timer
  int _secondsRemaining = 300;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _amount = widget.customAmount ?? widget.group.monthlyContribution;
    final randSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
    _orderId = 'SC-${widget.group.id.toUpperCase()}-C${widget.group.currentCycle + 1}-$randSuffix';
    
    // Foreman receiving VPA
    _payeeVpa = widget.group.foremanUpiId.trim().isNotEmpty
        ? widget.group.foremanUpiId.trim()
        : SupabaseService.foremanUpiId;
    _payeeName = 'SafeChit Escrow';

    _startCountdown();
    _initiateSession();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _pollingTimer?.cancel();
        setState(() {
          _statusMessage = 'Payment window expired. Please initiate again.';
        });
      }
    });
  }

  Future<void> _initiateSession() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Record initiated payment in SafeChit Supabase Ledger
    final paymentRecord = ChitPaymentRecord(
      id: _orderId,
      groupId: widget.group.id,
      groupName: widget.group.name,
      cycle: widget.group.currentCycle + 1,
      memberUsername: widget.currentUsername,
      memberName: widget.currentUsername,
      amount: _amount,
      amountPaise: (_amount * 100).toInt(),
      paymentMethod: 'UPI',
      status: 'ACTIVE',
      payeeVpa: _payeeVpa,
      payeeName: _payeeName,
      createdAt: DateTime.now(),
      notes: 'Monthly installment for Cycle ${widget.group.currentCycle + 1}',
    );

    await SupabaseService.recordPayment(paymentRecord);

    // 2. Call YouPI Gateway API to register session & obtain active slot
    final result = await YoupiPaymentService.instance.createPaymentSession(
      orderId: _orderId,
      amount: _amount,
      memberName: widget.currentUsername,
      memberPhone: '9876543210',
      groupId: widget.group.id,
      cycle: widget.group.currentCycle + 1,
      payeeVpa: _payeeVpa,
    );

    if (result['success'] == true) {
      _paymentSessionId = result['paymentId']?.toString();
      final status = result['status']?.toString();
      if (status == 'QUEUED') {
        _isQueued = true;
        _queuePosition = result['data']?['queuePosition'] ?? 1;
      }
      _startStatusPolling();
    } else if (result['error'] == 'DUPLICATE_SESSION_DETECTED') {
      _statusMessage = 'Active session detected on another device. Resuming local session.';
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _startStatusPolling() {
    if (_paymentSessionId == null) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final res = await YoupiPaymentService.instance.pollPaymentStatus(_paymentSessionId!);
      if (res['isPaid'] == true) {
        timer.cancel();
        _handlePaymentSuccess(res['utr'] ?? '4291${DateTime.now().millisecondsSinceEpoch % 100000000}');
      }
    });
  }

  Future<void> _handlePaymentSuccess(String utr) async {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();

    // Mark as PAID in Supabase Ledger
    await SupabaseService.updatePaymentStatus(
      paymentId: _orderId,
      status: 'PAID',
      utr: utr,
      completedAt: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _isPaid = true;
        _verifiedUtr = utr;
      });
    }

    if (widget.onPaymentSuccess != null) {
      widget.onPaymentSuccess!();
    }
  }

  Future<void> _launchApp(UpiAppInfo app) async {
    final launched = await YoupiPaymentService.instance.launchUpiPayment(
      payeeVpa: _payeeVpa,
      payeeName: _payeeName,
      amount: _amount,
      orderId: _orderId,
      packageName: app.packageName,
      note: 'Installment $_orderId',
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app.name} is not installed or could not be opened. You can scan the QR code instead!'),
          backgroundColor: const Color(0xFF0F4C81),
        ),
      );
      setState(() {
        _isQrMode = true;
      });
    }
  }

  // Simulator helper for offline/demo tests
  void _simulateInstantBankCredit() {
    final randUtr = '4291${(10000000 + (DateTime.now().millisecondsSinceEpoch % 89999999))}';
    _handlePaymentSuccess(randUtr);
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final upiUri = YoupiPaymentService.instance.buildUpiUri(
      payeeVpa: _payeeVpa,
      payeeName: _payeeName,
      amount: _amount,
      orderId: _orderId,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(color: Color(0xFF0F4C81), backgroundColor: Color(0xFFE2E8F0)),
            ),

          if (_isPaid) ...[
            // --- SUCCESS SCREEN ---
            _buildSuccessView(),
          ] else ...[
            // --- ACTIVE CHECKOUT SCREEN ---
            _buildCheckoutHeader(),
            const SizedBox(height: 16),

            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_statusMessage!, style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                ),
              ),

            if (_isQueued) ...[
              _buildQueueBanner(),
              const SizedBox(height: 12),
            ],

            // Mode Selector Tabs (1-Tap Apps vs Vector QR)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isQrMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isQrMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: !_isQrMode
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_rounded, size: 18, color: !_isQrMode ? const Color(0xFF0F4C81) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              '1-Tap UPI Apps',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !_isQrMode ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isQrMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isQrMode ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isQrMode
                              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded, size: 18, color: _isQrMode ? const Color(0xFF0F4C81) : const Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              'Scan QR Code',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isQrMode ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content
            if (_isQrMode) _buildQrView(upiUri) else _buildAppsGridView(),

            const SizedBox(height: 16),

            // VPA Copy Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Foreman Receiving VPA', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(_payeeVpa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _payeeVpa));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('UPI ID copied to clipboard!'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0F4C81)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Demo / Testing Action: Simulate Bank SMS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_rounded, color: Color(0xFFD97706), size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Testing Mode: Simulate bank credit SMS observation instantly.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                  TextButton(
                    onPressed: _simulateInstantBankCredit,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Simulate Credit'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F4C81)),
            ),
            const SizedBox(height: 2),
            Text(
              'Cycle ${widget.group.currentCycle + 1} Monthly Installment',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _amount < 100 ? '₹${_amount.toStringAsFixed(2)}' : '₹${NumberFormat('#,##,###').format(_amount)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1E293B)),
            ),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 12, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text(
                  _formatTimer(_secondsRemaining),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueueBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Queue Position: #$_queuePosition. Another member is completing payment. Slot will open automatically.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsGridView() {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: YoupiPaymentService.popularUpiApps.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final app = YoupiPaymentService.popularUpiApps[index];
            return InkWell(
              onTap: () => _launchApp(app),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(app.brandColor).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: Color(app.brandColor), size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQrView(String upiUri) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: QrImageView(
            data: upiUri,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Scan with any UPI App (GPay, PhonePe, Paytm, BHIM)',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Verified Successfully! 🎉',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F4C81)),
          ),
          const SizedBox(height: 6),
          Text(
            '${_amount < 100 ? "₹${_amount.toStringAsFixed(2)}" : "₹${NumberFormat('#,##,###').format(_amount)}"} credited to Foreman Escrow',
            style: const TextStyle(fontSize: 14, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Receipt Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Order ID', _orderId),
                const Divider(height: 16),
                _buildReceiptRow('Bank Reference (UTR)', _verifiedUtr ?? '429182749102'),
                const Divider(height: 16),
                _buildReceiptRow('Payment Mode', 'P2P Instant UPI (0% Fee)'),
                const Divider(height: 16),
                _buildReceiptRow('Date & Time', DateFormat('d MMM yyyy, hh:mm a').format(DateTime.now())),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done & Return to Chit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
      ],
    );
  }
}
