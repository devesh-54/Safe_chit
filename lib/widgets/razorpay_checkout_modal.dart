import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../services/supabase_service.dart';

/// Razorpay Checkout Modal for SafeChit Security Deposits in TEST mode.
/// Offers Netbanking (mock bank page with Success & Failure),
/// UPI (test ID success@razorpay / failure@razorpay), and Cards.
class RazorpayCheckoutModal extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String memberId;
  final double amount;
  final VoidCallback onDepositSuccess;

  const RazorpayCheckoutModal({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.memberId,
    required this.amount,
    required this.onDepositSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required String groupId,
    required String groupName,
    required String memberId,
    required double amount,
    required VoidCallback onDepositSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RazorpayCheckoutModal(
        groupId: groupId,
        groupName: groupName,
        memberId: memberId,
        amount: amount,
        onDepositSuccess: onDepositSuccess,
      ),
    );
  }

  @override
  State<RazorpayCheckoutModal> createState() => _RazorpayCheckoutModalState();
}

class _RazorpayCheckoutModalState extends State<RazorpayCheckoutModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Razorpay? _razorpay;

  bool _isProcessing = false;
  String? _orderId;
  String? _depositId;

  // Form controllers
  final TextEditingController _upiController =
      TextEditingController(text: 'success@razorpay');
  final TextEditingController _cardNoController =
      TextEditingController(text: '4111 1111 1111 1111');
  final TextEditingController _cardExpiryController =
      TextEditingController(text: '12/28');
  final TextEditingController _cardCvvController =
      TextEditingController(text: '123');

  String _selectedBank = 'State Bank of India';
  final List<Map<String, String>> _banks = [
    {'name': 'State Bank of India', 'code': 'SBIN'},
    {'name': 'HDFC Bank', 'code': 'HDFC'},
    {'name': 'ICICI Bank', 'code': 'ICIC'},
    {'name': 'Axis Bank', 'code': 'UTIB'},
    {'name': 'Kotak Mahindra Bank', 'code': 'KKBK'},
    {'name': 'Punjab National Bank', 'code': 'PUNB'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initNativeRazorpayIfSupported();
    _initOrder();
  }

  void _initNativeRazorpayIfSupported() {
    // razorpay_flutter plugin only supports Android and iOS native hosts
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          _razorpay = Razorpay();
          _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleNativePaymentSuccess);
          _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handleNativePaymentError);
          _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleNativeExternalWallet);
        }
      } catch (_) {}
    }
  }

  void _initOrder() async {
    setState(() => _isProcessing = true);
    final orderRes = await SupabaseService.createDepositOrder(
      groupId: widget.groupId,
      memberId: widget.memberId,
      amount: widget.amount,
    );
    if (mounted) {
      setState(() {
        _orderId = orderRes['orderId'] as String?;
        _depositId = orderRes['depositId'] as String?;
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _upiController.dispose();
    _cardNoController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _razorpay?.clear();
    super.dispose();
  }

  void _handleNativePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'pay_${DateTime.now().millisecondsSinceEpoch}';
    final signature = response.signature ?? 'test_sig_$paymentId';
    await _finalizeVerification(
      paymentId: paymentId,
      signature: signature,
      method: 'Razorpay SDK',
    );
  }

  void _handleNativePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message ?? "User cancelled"}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _handleNativeExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External Wallet: ${response.walletName}'),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    }
  }

  Future<void> _finalizeVerification({
    required String paymentId,
    required String signature,
    required String method,
  }) async {
    setState(() => _isProcessing = true);

    final success = await SupabaseService.verifyDepositSignature(
      depositId: _depositId ?? 'dep_${DateTime.now().millisecondsSinceEpoch}',
      orderId: _orderId ?? 'order_test_${DateTime.now().millisecondsSinceEpoch}',
      paymentId: paymentId,
      signature: signature,
      groupId: widget.groupId,
      memberId: widget.memberId,
      amount: widget.amount,
    );

    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        widget.onDepositSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Security deposit of ₹${widget.amount.toStringAsFixed(0)} held successfully via $method!',
            ),
            backgroundColor: const Color(0xFF166534),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Signature verification failed. Deposit remains pending.'),
            backgroundColor: Color(0xFF991B1B),
          ),
        );
      }
    }
  }

  // --- 1. NET BANKING SIMULATION ---
  void _processNetBanking() {
    final bank = _selectedBank;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.account_balance_rounded, color: Color(0xFF0F4C81)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$bank — Mock Gateway',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF0F4C81)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Simulating Net Banking payment of ₹${widget.amount.toStringAsFixed(0)} to SafeChit Escrow.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This is Razorpay\'s simulated Net Banking page. Choose an action to complete the test flow:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Net Banking payment declined by user (mock failure).'),
                  backgroundColor: Color(0xFF991B1B),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF991B1B)),
            child: const Text('Failure (Mock Reject)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final paymentId = 'pay_nb_${DateTime.now().millisecondsSinceEpoch}';
              _finalizeVerification(
                paymentId: paymentId,
                signature: 'test_sig_$paymentId',
                method: 'Net Banking ($bank)',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
            ),
            child: const Text('Success (Mock Authorize)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- 2. UPI SIMULATION ---
  void _processUpi() {
    final upiId = _upiController.text.trim();
    if (upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a test UPI ID')),
      );
      return;
    }

    if (upiId.toLowerCase().contains('failure')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ UPI Payment Failed: Transaction rejected by test bank (failure@razorpay).'),
          backgroundColor: Color(0xFF991B1B),
        ),
      );
      return;
    }

    final paymentId = 'pay_upi_${DateTime.now().millisecondsSinceEpoch}';
    _finalizeVerification(
      paymentId: paymentId,
      signature: 'test_sig_$paymentId',
      method: 'UPI ($upiId)',
    );
  }

  // --- 3. CARD SIMULATION ---
  void _processCard() {
    final cardNo = _cardNoController.text.replaceAll(' ', '').trim();
    if (cardNo.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid card number')),
      );
      return;
    }

    final paymentId = 'pay_card_${DateTime.now().millisecondsSinceEpoch}';
    _finalizeVerification(
      paymentId: paymentId,
      signature: 'test_sig_$paymentId',
      method: 'Card (Razorpay Test)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header with Test Mode Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Razorpay Checkout',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        widget.groupName,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${widget.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F4C81),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PROMINENT TEST MODE BANNER (Mandatory)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_rounded, color: Color(0xFF92400E), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Test mode, no real money will be charged.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs: Netbanking | UPI | Cards
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF0F4C81),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Net Banking'),
                  Tab(text: 'UPI'),
                  Tab(text: 'Cards'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            SizedBox(
              height: 230,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNetBankingTab(),
                  _buildUpiTab(),
                  _buildCardsTab(),
                ],
              ),
            ),

            if (_isProcessing) ...[
              const SizedBox(height: 12),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F4C81)),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Communicating with Razorpay Bridge...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNetBankingTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Bank (Mock Authorization):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBank,
              items: _banks.map((b) {
                return DropdownMenuItem<String>(
                  value: b['name']!,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 16, color: Color(0xFF0F4C81)),
                      const SizedBox(width: 8),
                      Text(b['name']!, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedBank = val);
              },
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processNetBanking,
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: Text('Open $_selectedBank Mock Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpiTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter Test UPI ID:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _upiController,
          decoration: InputDecoration(
            hintText: 'success@razorpay',
            prefixIcon: const Icon(Icons.alternate_email, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ActionChip(
              label: const Text('success@razorpay', style: TextStyle(fontSize: 10)),
              backgroundColor: const Color(0xFFDCFCE7),
              onPressed: () => _upiController.text = 'success@razorpay',
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Text('failure@razorpay', style: TextStyle(fontSize: 10)),
              backgroundColor: const Color(0xFFFEE2E2),
              onPressed: () => _upiController.text = 'failure@razorpay',
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processUpi,
            icon: const Icon(Icons.flash_on_rounded, size: 18),
            label: Text('Pay ₹${widget.amount.toStringAsFixed(0)} via UPI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cardNoController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Test Card Number',
            prefixIcon: const Icon(Icons.credit_card, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _cardExpiryController,
                decoration: InputDecoration(
                  labelText: 'Expiry',
                  hintText: 'MM/YY',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _cardCvvController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '123',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _processCard,
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text('Pay ₹${widget.amount.toStringAsFixed(0)} via Card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
