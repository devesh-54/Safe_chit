import 'package:flutter/material.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';

class DigitalAgreementModal extends StatefulWidget {
  final DigitalAgreement agreement;
  final bool isForeman; // true if signed by Foreman, false if by Member
  final VoidCallback onSigned;

  const DigitalAgreementModal({
    super.key,
    required this.agreement,
    required this.isForeman,
    required this.onSigned,
  });

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
    _signatureNameController.text = widget.isForeman 
        ? widget.agreement.foremanName 
        : widget.agreement.memberName;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 20) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
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
          content: Text('Please read terms, check acceptance box, and type your legal signature name.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _isSigning = true;
    });

    final signatureHash = "DIGITAL_SIG_${typedName.toUpperCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}";

    final success = await SupabaseService.signDigitalAgreement(
      agreementId: widget.agreement.id,
      isForeman: widget.isForeman,
      signatureUrl: signatureHash,
    );

    if (mounted) {
      setState(() {
        _isSigning = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Digital Agreement legally signed & recorded! Hash: $signatureHash'),
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

  @override
  Widget build(BuildContext context) {
    final isAlreadySigned = widget.isForeman 
        ? widget.agreement.foremanSigned 
        : widget.agreement.memberSigned;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 750),
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C81).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: Color(0xFF0F4C81), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Legally Binding Digital Agreement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Chit Funds Act 1982 & BNS 2024 Compliant • ${widget.agreement.groupName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF007A87), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Agreement Text Container
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: SelectableText(
                      widget.agreement.agreementText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Signature Status & Execution Box
            if (isAlreadySigned)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_user_rounded, color: Color(0xFF166534), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✅ You have digitally signed this Chit Agreement. Your signature timestamp & legal hash are recorded.',
                        style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Acceptance Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _hasAcceptedTerms,
                        activeColor: const Color(0xFF0F4C81),
                        onChanged: (val) {
                          setState(() {
                            _hasAcceptedTerms = val ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I have read and fully accept the Chit Funds Act 1982 terms, Section 28 penalty rules, and default forfeiture consequences.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: _signatureNameController,
                          decoration: InputDecoration(
                            labelText: 'Type Legal Signature Name',
                            hintText: widget.isForeman ? 'Foreman Full Name' : 'Subscriber Full Name',
                            prefixIcon: const Icon(Icons.draw_rounded, color: Color(0xFF0F4C81)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          onPressed: (_isSigning || !_hasAcceptedTerms) ? null : _executeDigitalSignature,
                          icon: _isSigning
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.verified_rounded),
                          label: const Text(
                            'Digitally Sign Agreement',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
