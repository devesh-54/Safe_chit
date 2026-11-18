import 'package:flutter/material.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';

class DigitalAgreementModal extends StatefulWidget {
  final DigitalAgreement agreement;
  final bool isForeman;
  final VoidCallback onSigned;

  const DigitalAgreementModal({
    super.key,
    required this.agreement,
    required this.isForeman,
    required this.onSigned,
  });

  static Future<void> open({
    required BuildContext context,
    required DigitalAgreement agreement,
    required bool isForeman,
    required VoidCallback onSigned,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DigitalAgreementModal(
          agreement: agreement,
          isForeman: isForeman,
          onSigned: onSigned,
        ),
      ),
    );
  }

  @override
  State<DigitalAgreementModal> createState() => _DigitalAgreementModalState();
}

class _DigitalAgreementModalState extends State<DigitalAgreementModal> {
  bool _hasScrolledToBottom = false;
  bool _hasAcceptedTerms = false;
  bool _isSigning = false;
  final _signatureNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _signatureNameController.text =
        widget.isForeman ? widget.agreement.foremanName : widget.agreement.memberName;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        if (!_hasScrolledToBottom) {
          setState(() => _hasScrolledToBottom = true);
        }
      }
    });
  }

  @override
  void dispose() {
    _signatureNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _executeDigitalSignature() async {
    final typedName = _signatureNameController.text.trim();
    if (typedName.isEmpty || !_hasAcceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please read the terms, check the acceptance box, and type your legal name.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSigning = true);

    final signatureHash =
        'DIGITAL_SIG_${typedName.toUpperCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';

    final success = await SupabaseService.signDigitalAgreement(
      agreementId: widget.agreement.id,
      isForeman: widget.isForeman,
      signatureUrl: signatureHash,
    );

    if (mounted) {
      setState(() => _isSigning = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Agreement signed & recorded! Hash: $signatureHash'),
            backgroundColor: const Color(0xFF007A87),
          ),
        );
        widget.onSigned();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record digital signature. Please try again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ── Structured document builder (replaces raw monospace text) ─────────────

  /// Parse the agreement and render it as proper styled widgets.
  Widget _buildFormattedAgreement(DigitalAgreement ag) {
    final agreementDate = ag.createdAt;
    final formattedDate =
        '${agreementDate.day.toString().padLeft(2, '0')}/${agreementDate.month.toString().padLeft(2, '0')}/${agreementDate.year}';
    final pool = ag.poolAmount < 1000
        ? '₹${ag.poolAmount.toStringAsFixed(2)}'
        : '₹${ag.poolAmount.toStringAsFixed(0)}';
    final monthly = ag.monthlyContribution < 1000
        ? '₹${ag.monthlyContribution.toStringAsFixed(2)}'
        : '₹${ag.monthlyContribution.toStringAsFixed(0)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title block ──────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F4C81).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: Color(0xFF0F4C81), size: 28),
              ),
              const SizedBox(height: 10),
              const Text(
                'DIGITAL CHIT AGREEMENT',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
              const Text(
                'SUBSCRIBER UNDERTAKING',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Executed under Section 6 of the Chit Funds Act, 1982',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'Date of Execution: $formattedDate',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Parties ──────────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.people_alt_outlined,
          title: 'PARTIES TO THIS AGREEMENT',
          color: const Color(0xFF7C3AED),
          children: [
            _partyRow(
              label: 'FOREMAN (ORGANIZER)',
              name: ag.foremanName,
              sub: 'Chit Scheme: ${ag.groupName}',
              icon: Icons.manage_accounts_rounded,
              color: const Color(0xFF0F4C81),
            ),
            const SizedBox(height: 10),
            _partyRow(
              label: 'SUBSCRIBER (MEMBER)',
              name: ag.memberName,
              sub: '@${ag.memberUsername}',
              icon: Icons.person_rounded,
              color: const Color(0xFF059669),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Article I: Scheme specs ───────────────────────────────────────────
        _sectionCard(
          icon: Icons.article_outlined,
          title: 'ARTICLE I — CHIT SCHEME SPECIFICATIONS',
          color: const Color(0xFF0F4C81),
          children: [
            _specRow(Icons.savings_rounded, 'Total Chit Pool Amount', pool),
            _specRow(Icons.calendar_month_rounded, 'Scheme Duration',
                '${ag.durationMonths} Months'),
            _specRow(Icons.payments_rounded, 'Monthly Contribution per Subscriber', monthly),
            _specRow(Icons.gavel_rounded, 'Operation Mechanism', ag.schemeType),
            _specRow(Icons.lock_outline_rounded, 'Security Deposit',
                '27% of monthly contribution'),
            _specRow(Icons.star_rounded, 'Host Payout',
                'The host receives the month 2 payout'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Article II: Covenants & Default ─────────────────────────────────
        _sectionCard(
          icon: Icons.warning_amber_rounded,
          title: 'ARTICLE II — SUBSCRIBER COVENANTS & DEFAULT',
          color: const Color(0xFFB45309),
          children: [
            _bulletItem('Timely Installments: Subscriber agrees to remit $monthly on or before the 5th of every calendar month.'),
            _bulletItem('Default Interest & Penalty (Section 28, Chit Funds Act 1982): Any delayed installment attracts 18% per annum penalty interest.'),
            _bulletItem('Non-Prized Subscriber Default: Two consecutive missed cycles allows the Foreman to remove the subscriber and forfeit late penalties.'),
            _bulletItem('Prized Subscriber Default: All remaining installments become immediately due. The security deposit is forfeited. Legal recovery proceeds under BNS 2024 (Section 316 — Criminal Breach of Trust / Section 318 — Cheating).'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Article III: Foreman undertakings ────────────────────────────────
        _sectionCard(
          icon: Icons.verified_user_outlined,
          title: 'ARTICLE III — FOREMAN UNDERTAKINGS',
          color: const Color(0xFF059669),
          children: [
            _bulletItem('The Foreman guarantees safe custody and timely disbursement of chit funds to the winner of each cycle.'),
            _bulletItem('The Foreman maintains 100% indemnity for non-prized subscribers against defalcations by defaulted prized subscribers.'),
          ],
        ),
        const SizedBox(height: 14),

        // ── Article IV: Digital Signature binding ────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: const [
              Icon(Icons.draw_rounded, color: Color(0xFF64748B), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ARTICLE IV — DIGITAL SIGNATURE BINDING\n'
                  'By applying digital signatures, both parties confirm full acceptance under the Information Technology Act, 2000 and Section 6 of the Chit Funds Act, 1982.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyRow({
    required String label,
    required String name,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 0.5)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              Text(sub,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B))),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155))),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isAlreadySigned = widget.isForeman
        ? widget.agreement.foremanSigned
        : widget.agreement.memberSigned;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digital Chit Agreement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Chit Funds Act 1982 · ${widget.agreement.groupName}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFBAE6FD),
              ),
            ),
          ],
        ),
        actions: [
          if (isAlreadySigned)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF4ADE80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified_rounded, size: 14, color: Color(0xFF4ADE80)),
                  SizedBox(width: 4),
                  Text(
                    'Signed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Scrollable document body ───────────────────────────────────
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildFormattedAgreement(widget.agreement),
                    ),
                  ),
                ),
              ),
            ),

            // ── Footer: signature / signed badge ──────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: isAlreadySigned
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.verified_user_rounded,
                                  color: Color(0xFF166534), size: 22),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '✅ You have digitally signed this Chit Agreement.\nYour signature timestamp & legal hash are recorded.',
                                  style: TextStyle(
                                      color: Color(0xFF166534),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _hasAcceptedTerms,
                                  activeColor: const Color(0xFF0F4C81),
                                  onChanged: (val) => setState(
                                      () => _hasAcceptedTerms = val ?? false),
                                ),
                                const Expanded(
                                  child: Text(
                                    'I have read and fully accept all terms under the Chit Funds Act 1982 and BNS 2024.',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: _signatureNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Your Legal Name',
                                      hintText: widget.isForeman
                                          ? 'Foreman Full Name'
                                          : 'Subscriber Full Name',
                                      prefixIcon: const Icon(Icons.draw_rounded,
                                          color: Color(0xFF0F4C81)),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 12),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 6,
                                  child: ElevatedButton.icon(
                                    onPressed: (_isSigning || !_hasAcceptedTerms)
                                        ? null
                                        : _executeDigitalSignature,
                                    icon: _isSigning
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.verified_rounded),
                                    label: const Text(
                                      'Sign Agreement',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F4C81),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
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
          ],
        ),
      ),
    );
  }
}
