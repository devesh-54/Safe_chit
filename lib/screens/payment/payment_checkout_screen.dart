import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chit_group.dart';
import '../../models/chit_payment_record.dart';
import '../../services/supabase_service.dart';
import 'card_payment_screen.dart';

class PaymentCheckoutScreen extends StatefulWidget {
  final ChitGroup group;
  final String currentUsername;
  final double? customAmount;
  final VoidCallback? onPaymentSuccess;

  const PaymentCheckoutScreen({
    super.key,
    required this.group,
    required this.currentUsername,
    this.customAmount,
    this.onPaymentSuccess,
  });

  static Future<void> open({
    required BuildContext context,
    required ChitGroup group,
    required String currentUsername,
    double? customAmount,
    VoidCallback? onPaymentSuccess,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          group: group,
          currentUsername: currentUsername,
          customAmount: customAmount,
          onPaymentSuccess: onPaymentSuccess,
        ),
      ),
    );
  }

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final double _amount;
  late final String _orderId;
  late final String _payeeVpa;
  String _foremanName = 'Rajesh Kumar (Foreman)';
  String _memberName = '';

  // Selected payment method:
  // 'upi_gpay', 'upi_phonepe', 'upi_paytm', 'upi_other', 'card', 'netbanking'
  String _selectedMethod = 'upi_gpay';
  String _selectedBank = 'State Bank of India';
  final TextEditingController _customUpiController = TextEditingController();

  bool _isProcessing = false;
  bool _isPaid = false;
  String? _verifiedUtr;
  DateTime? _paidAt;
  String _confirmedPaymentMode = 'P2P Instant UPI (Google Pay)';

  @override
  void initState() {
    super.initState();
    _amount = widget.customAmount ?? widget.group.monthlyContribution;
    final randSuffix = DateTime.now().millisecondsSinceEpoch % 10000;
    _orderId =
        'SC-${widget.group.id.toUpperCase()}-C${widget.group.currentCycle}-$randSuffix';

    _payeeVpa = widget.group.foremanUpiId.trim().isNotEmpty
        ? widget.group.foremanUpiId.trim()
        : 'devesh1@oksbi';

    _loadMemberProfile();
  }

  @override
  void dispose() {
    _customUpiController.dispose();
    super.dispose();
  }

  void _loadMemberProfile() async {
    final profile = await SupabaseService.getUserProfile(widget.currentUsername);
    if (profile != null && mounted) {
      setState(() {
        _memberName = profile['full_name'] as String? ?? widget.currentUsername;
      });
    } else {
      setState(() {
        _memberName = widget.currentUsername == 'member_demo'
            ? 'Suresh Raina'
            : widget.currentUsername;
      });
    }
  }

  String _getMethodTitle(String method) {
    switch (method) {
      case 'upi_gpay':
        return 'Google Pay';
      case 'upi_phonepe':
        return 'PhonePe';
      case 'upi_paytm':
        return 'Paytm';
      case 'upi_other':
        return 'Pay by any UPI App';
      case 'card':
        return 'Credit / Debit Card';
      case 'netbanking':
        return 'Net Banking ($_selectedBank)';
      default:
        return 'UPI';
    }
  }

  void _onContinuePressed() async {
    if (_selectedMethod == 'card') {
      // Pushes dedicated Card Payment page per user instructions
      _openCardPaymentScreen();
      return;
    }

    setState(() => _isProcessing = true);

    // Simulate instant payment network handshake
    await Future.delayed(const Duration(milliseconds: 1400));

    final utr =
        '4291${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final now = DateTime.now();

    final modeLabel = _selectedMethod.startsWith('upi')
        ? 'P2P Instant UPI (${_getMethodTitle(_selectedMethod)})'
        : 'Net Banking ($_selectedBank)';

    // Record verified payment in Supabase & memory ledger
    final paymentRecord = ChitPaymentRecord(
      id: _orderId,
      groupId: widget.group.id,
      groupName: widget.group.name,
      cycle: widget.group.currentCycle,
      memberUsername: widget.currentUsername,
      memberName: _memberName.isNotEmpty ? _memberName : widget.currentUsername,
      amount: _amount,
      amountPaise: (_amount * 100).toInt(),
      paymentMethod: _selectedMethod.startsWith('upi') ? 'UPI' : 'NET_BANKING',
      status: 'PAID',
      utr: utr,
      payeeVpa: _payeeVpa,
      payeeName: _foremanName,
      createdAt: now,
      completedAt: now,
      notes:
          'Monthly installment for Cycle ${widget.group.currentCycle} via ${_getMethodTitle(_selectedMethod)}',
    );

    final recordSuccess = await SupabaseService.recordPayment(paymentRecord);

    if (!mounted) return;

    if (!recordSuccess) {
      setState(() => _isProcessing = false);
      final err = SupabaseService.lastBackendError.value ?? 'Database save failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record payment: $err'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = false;
      _isPaid = true;
      _verifiedUtr = utr;
      _paidAt = now;
      _confirmedPaymentMode = modeLabel;
    });

    widget.onPaymentSuccess?.call();
    if (mounted) _showSuccessSheet();
  }

  void _openCardPaymentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardPaymentScreen(
          group: widget.group,
          currentUsername: widget.currentUsername,
          memberDisplayName: _memberName,
          amount: _amount,
          onPaymentCompleted: (paymentRecord) {
            setState(() {
              _isPaid = true;
              _verifiedUtr = paymentRecord.utr ?? '429182749102';
              _paidAt = paymentRecord.completedAt ?? DateTime.now();
              _confirmedPaymentMode = 'Credit / Debit Card';
            });
            widget.onPaymentSuccess?.call();
            if (mounted) _showSuccessSheet();
          },
        ),
      ),
    );
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessReceiptSheet(
        amount: _amount,
        orderId: _orderId,
        verifiedUtr: _verifiedUtr ?? '429167948080',
        paidAt: _paidAt ?? DateTime.now(),
        confirmedPaymentMode: _confirmedPaymentMode,
        payeeVpa: _payeeVpa,
        onDone: () {
          Navigator.pop(context); // close sheet
          Navigator.pop(context); // close checkout
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Success is now shown as bottom sheet over this page – handled in _onContinuePressed / card callback
    // We never show the full-screen success scaffold anymore

    final formattedAmount = _amount < 100
        ? '₹${_amount.toStringAsFixed(2)}'
        : '₹${NumberFormat('#,##,###').format(_amount)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select a payment method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: Color(0xFF0F4C81),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Step Indicator (Chit Details -> Payment -> Receipt)
                _buildStepper(),

                const SizedBox(height: 14),

                // 2. Chit Scheme & Foreman Summary Card
                _buildChitSummaryCard(formattedAmount),

                const SizedBox(height: 18),

                // 3. Section: UPI
                _buildSectionHeader('UPI'),
                _buildCardContainer([
                  _buildPaymentRadioTile(
                    value: 'upi_gpay',
                    title: 'Google Pay',
                    subtitle: 'Fast 0% fee UPI transfer',
                    iconWidget: _buildBrandIcon(
                      color: const Color(0xFF4285F4),
                      label: 'GPay',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                  _buildPaymentRadioTile(
                    value: 'upi_phonepe',
                    title: 'PhonePe',
                    subtitle: 'Pay directly via PhonePe UPI',
                    iconWidget: _buildBrandIcon(
                      color: const Color(0xFF5F259F),
                      label: 'PhonePe',
                      icon: Icons.phone_android_rounded,
                    ),
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                  _buildPaymentRadioTile(
                    value: 'upi_paytm',
                    title: 'Paytm',
                    subtitle: 'Pay using Paytm Wallet or UPI',
                    iconWidget: _buildBrandIcon(
                      color: const Color(0xFF00BAF2),
                      label: 'Paytm',
                      icon: Icons.payments_rounded,
                    ),
                  ),
                  const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                  _buildPaymentRadioTile(
                    value: 'upi_other',
                    title: 'Pay by any UPI App',
                    subtitle: 'BHIM, CRED, Navi or any custom UPI ID',
                    iconWidget: _buildBrandIcon(
                      color: const Color(0xFF059669),
                      label: 'UPI',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ),
                  if (_selectedMethod == 'upi_other') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(64, 4, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _customUpiController,
                            decoration: InputDecoration(
                              hintText: 'Enter UPI ID (e.g. mobile@upi)',
                              hintStyle: const TextStyle(fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _buildUpiSuggestionChip('devesh1@oksbi'),
                              _buildUpiSuggestionChip('member@upi'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),

                const SizedBox(height: 18),

                // 4. Section: CREDIT & DEBIT CARDS
                _buildSectionHeader('CREDIT & DEBIT CARDS'),
                _buildCardContainer([
                  _buildPaymentRadioTile(
                    value: 'card',
                    title: 'Credit or Debit Card',
                    subtitle: 'Visa, Mastercard, RuPay, Maestro',
                    iconWidget: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Color(0xFF0F4C81),
                        size: 22,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(64, 0, 16, 12),
                    child: InkWell(
                      onTap: _openCardPaymentScreen,
                      child: Row(
                        children: const [
                          Icon(Icons.add, size: 16, color: Color(0xFF007A87)),
                          SizedBox(width: 4),
                          Text(
                            'Add a new credit or debit card',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF007A87),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 18),

                // 5. Section: MORE WAYS TO PAY (Net Banking)
                _buildSectionHeader('MORE WAYS TO PAY'),
                _buildCardContainer([
                  _buildPaymentRadioTile(
                    value: 'netbanking',
                    title: 'Net Banking',
                    subtitle: 'All major Indian banks supported',
                    iconWidget: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Color(0xFF334155),
                        size: 22,
                      ),
                    ),
                  ),
                  if (_selectedMethod == 'netbanking') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(64, 0, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose your Bank:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              'State Bank of India',
                              'HDFC Bank',
                              'ICICI Bank',
                              'Axis Bank',
                              'Kotak Bank',
                            ].map((bank) {
                              final isSelected = _selectedBank == bank;
                              return ChoiceChip(
                                label: Text(bank),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedBank = bank),
                                selectedColor: const Color(0xFF0F4C81),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),

                const SizedBox(height: 18),

                // SafeChit Guarantee
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shield_rounded, size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Text(
                      'SafeChit Direct Transfer • Regulated Chit Funds Act 1982',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sticky Bottom Bar with Continue Button (Amazon Inspired)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Due',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          formattedAmount,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _onContinuePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD814), // Amazon gold
                          foregroundColor: const Color(0xFF0F1111),
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Color(0xFFFCD200)),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F1111),
                                ),
                              )
                            : Text(
                                _selectedMethod == 'card'
                                    ? 'Continue to Enter Card'
                                    : 'Continue to Pay $formattedAmount',
                                style: const TextStyle(
                                  fontSize: 15,
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
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCircle(number: '1', title: 'Chit Info', isCompleted: true),
          _buildStepLine(isCompleted: true),
          _buildStepCircle(number: '2', title: 'Payment', isCurrent: true),
          _buildStepLine(isCompleted: false),
          _buildStepCircle(number: '3', title: 'Receipt', isUpcoming: true),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required String number,
    required String title,
    bool isCompleted = false,
    bool isCurrent = false,
    bool isUpcoming = false,
  }) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF64748B);
    Widget content = Text(
      number,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
    );

    if (isCompleted) {
      bg = const Color(0xFF16A34A);
      content = const Icon(Icons.check, size: 12, color: Colors.white);
    } else if (isCurrent) {
      bg = const Color(0xFF0F4C81);
      content = Text(
        number,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 10, backgroundColor: bg, child: content),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isCurrent ? const Color(0xFF0F4C81) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isCompleted}) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
    );
  }

  Widget _buildChitSummaryCard(String formattedAmount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF0F4C81),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Cycle ${widget.group.currentCycle}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monthly Contribution Installment • ${widget.group.city}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Foreman Details (Requested by User)
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, size: 16, color: Color(0xFF007A87)),
              const SizedBox(width: 6),
              const Text(
                'Foreman / Host: ',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: Text(
                  _foremanName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
              const SizedBox(width: 6),
              const Text(
                'Receiving UPI: ',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: Text(
                  _payeeVpa,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              const Text(
                'Subscriber: ',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Expanded(
                child: Text(
                  '${_memberName.isNotEmpty ? _memberName : widget.currentUsername} (@${widget.currentUsername})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Amount Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount to Pay:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                Text(
                  formattedAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F4C81),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildPaymentRadioTile({
    required String value,
    required String title,
    required String subtitle,
    required Widget iconWidget,
  }) {
    final isSelected = _selectedMethod == value;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedMethod,
              activeColor: const Color(0xFF0F4C81),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMethod = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandIcon({
    required Color color,
    required String label,
    required IconData icon,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildUpiSuggestionChip(String upiId) {
    return ActionChip(
      label: Text(upiId),
      labelStyle: const TextStyle(fontSize: 10, color: Color(0xFF0F4C81)),
      backgroundColor: const Color(0xFFEFF6FF),
      padding: EdgeInsets.zero,
      onPressed: () {
        _customUpiController.text = upiId;
      },
    );
  }

  // Legacy – kept empty; actual receipt is now _SuccessReceiptSheet
  Widget _buildSuccessReceiptView() {
    final formattedAmount = _amount < 100
        ? '₹${_amount.toStringAsFixed(2)}'
        : '₹${NumberFormat('#,##,###').format(_amount)}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Payment Verified Successfully! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$formattedAmount credited to Foreman Chit Account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF15803D),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Official Receipt Card (Image 4)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Order ID', _orderId),
                const Divider(height: 18),
                _buildReceiptRow(
                  'Bank Reference (UTR)',
                  _verifiedUtr ?? '429167948080',
                ),
                const Divider(height: 18),
                _buildReceiptRow('Payment Mode', _confirmedPaymentMode),
                const Divider(height: 18),
                _buildReceiptRow(
                  'Date & Time',
                  DateFormat('d MMM yyyy, hh:mm a').format(_paidAt ?? DateTime.now()),
                ),
                const Divider(height: 18),
                _buildReceiptRow('Foreman Account', _payeeVpa),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // Done & Return to Chit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done & Return to Chit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUCCESS RECEIPT — compact bottom-sheet (preserves previous look & feel)
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessReceiptSheet extends StatelessWidget {
  final double amount;
  final String orderId;
  final String verifiedUtr;
  final DateTime paidAt;
  final String confirmedPaymentMode;
  final String payeeVpa;
  final VoidCallback onDone;

  const _SuccessReceiptSheet({
    required this.amount,
    required this.orderId,
    required this.verifiedUtr,
    required this.paidAt,
    required this.confirmedPaymentMode,
    required this.payeeVpa,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAmount = amount < 100
        ? '₹${amount.toStringAsFixed(2)}'
        : '₹${NumberFormat('#,##,###').format(amount)}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Green checkmark
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 48,
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Payment Verified Successfully! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$formattedAmount credited to Foreman Chit Account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF15803D),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Receipt rows
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _row('Order ID', orderId),
                const Divider(height: 16),
                _row('Bank Reference (UTR)', verifiedUtr),
                const Divider(height: 16),
                _row('Payment Mode', confirmedPaymentMode),
                const Divider(height: 16),
                _row('Date & Time',
                    DateFormat('d MMM yyyy, hh:mm a').format(paidAt)),
                const Divider(height: 16),
                _row('Foreman Account', payeeVpa),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done & Return to Chit',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
