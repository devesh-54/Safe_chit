import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/member_risk.dart';
import '../../services/supabase_service.dart';

class EscrowControlsScreen extends StatefulWidget {
  final String? initialMemberId;
  final VoidCallback? onStateChanged;

  const EscrowControlsScreen({
    super.key,
    this.initialMemberId,
    this.onStateChanged,
  });

  @override
  State<EscrowControlsScreen> createState() => _EscrowControlsScreenState();
}

class _EscrowControlsScreenState extends State<EscrowControlsScreen> {
  List<ChitMemberRisk> _defaulters = [];
  bool _isLoading = true;
  String _selectedGroupId = 'group_1'; // Indiranagar Traders Chit default

  @override
  void initState() {
    super.initState();
    _loadDefaulters();
  }

  void _loadDefaulters() async {
    setState(() {
      _isLoading = true;
    });
    final members = await SupabaseService.getGroupMembers(_selectedGroupId);
    setState(() {
      // Filter for those with defaults or high risk (e.g. risk score > 40)
      _defaulters = members.where((m) => m.hasDefaulted || m.defaultRiskScore > 40).toList();
      _isLoading = false;
    });
  }

  void _triggerForfeiture(ChitMemberRisk member) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
              SizedBox(width: 8),
              Text(
                'Trigger Forfeiture?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to trigger forfeiture for ${member.name}?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action will:\n'
                '• Disqualify member from all future bidding auctions.\n'
                '• Freeze and lock their security deposit (₹20,000) in escrow.\n'
                '• Reallocate their chit portion or distribute liability to the host.\n'
                '• Mark default status permanently in credit scoring registries.',
                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF5A6E72)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A6E72))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                });
                await SupabaseService.triggerForfeiture(member.id);
                _loadDefaulters();
                if (widget.onStateChanged != null) {
                  widget.onStateChanged!();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔒 Forfeiture triggered and logged for ${member.name}.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Trigger Forfeiture'),
            ),
          ],
        );
      },
    );
  }

  void _showNoticeDialog(ChitMemberRisk member) {
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());
    final outstandingAmt = member.amountExposed > 0 ? member.amountExposed : 20000.0;
    final monthsOverdue = member.paymentTrend.contains('3x') ? 3 : (member.paymentTrend.contains('4x') ? 4 : 2);
    final secDeposit = 20000.0;

    final noticeText = 'FORMAL DEMAND NOTICE\n'
        '(Under Section 28 of the Chit Funds Act, 1982)\n\n'
        'To:\n'
        'Name: ${member.name}\n'
        'Phone: ${member.phone}\n'
        'Date: $today\n'
        'Chit Group: Koramangala Professional Chit (Group ID: group_1)\n'
        'Host Organizer: Authorized ChitGuard Host\n\n'
        'You are hereby notified that you have defaulted on your monthly contributions for the Chit Group.\n'
        'Outstanding Monthly Dues: ₹${outstandingAmt.toStringAsFixed(0)}\n'
        'Months Overdue: $monthsOverdue month(s)\n\n'
        'Under Section 28 of the Chit Funds Act, 1982, you are required to clear the outstanding dues of ₹${outstandingAmt.toStringAsFixed(0)} within 14 days of receipt of this notice.\n\n'
        'Failure to do so will result in the immediate forfeiture of your security deposit (₹${secDeposit.toStringAsFixed(0)}), removal from the chit group membership, and disqualification from bidding in all future auctions of this cycle. The remaining installments will be recovered through legal proceedings under Section 33 of the Act.\n\n'
        'For ChitGuard host/organizer,\n'
        'Digital Verification ID: CG-HOST-PASSPORT-48A';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Section 28 Default Notice',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF5A6E72)),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This demand notice is drafted in compliance with Section 28 of the Chit Funds Act, 1982. It acts as the final warning before security forfeiture.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5A6E72)),
                  ),
                  const SizedBox(height: 16),
                  // Document view
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7F2), // Cream Base
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          noticeText,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: noticeText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Legal notice text copied to clipboard!'),
                                backgroundColor: Color(0xFF0F4C81),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF0F4C81), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.copy, size: 18),
                              SizedBox(width: 8),
                              Text('Copy Text'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            setState(() {
                              _isLoading = true;
                            });
                            await SupabaseService.saveDefaultNotice(member.id, noticeText);
                            _loadDefaulters();
                            if (widget.onStateChanged != null) {
                              widget.onStateChanged!();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('📨 Notice dispatched to member via SMS & Email!'),
                                  backgroundColor: Color(0xFF007A87),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F4C81),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Send Notice'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Cream Base
      appBar: _onGroupCreatedWidgetCheck(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header & Escrow Summary Card
              _buildHeaderAndSummary(),
              const SizedBox(height: 24),

              const Text(
                'Defaulters & High-Risk Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F4C81),
                ),
              ),
              const SizedBox(height: 12),

              // Defaulters List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81)))
                    : _defaulters.isEmpty
                        ? _buildNoDefaultersView()
                        : ListView.builder(
                            itemCount: _defaulters.length,
                            itemBuilder: (context, index) {
                              final member = _defaulters[index];
                              return _buildDefaulterCard(member);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget? _onGroupCreatedWidgetCheck() {
    if (widget.onStateChanged == null) {
      return AppBar(
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        title: const Text('Member Defaulter & Escrow'),
        elevation: 0,
      );
    }
    return null;
  }

  Widget _buildHeaderAndSummary() {
    double totalOutstanding = _defaulters
        .where((m) => !m.forfeited)
        .fold(0.0, (sum, m) => sum + m.amountExposed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escrow & Default Controls',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF0F4C81)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Handle payment delinquencies, lock security deposits, and issue statutory default notices.',
          style: TextStyle(fontSize: 14, color: Color(0xFF5A6E72)),
        ),
        const SizedBox(height: 20),

        // Escrow Status Panel
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F4C81), Color(0xFF007A87)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F4C81).withOpacity(0.12),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL DEFAULT RISK OUTSTANDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF2ECE1),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '₹${totalOutstanding.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'ESCROW DEPOSITS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF2ECE1),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹1,00,000',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706), // Gold Accent
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoDefaultersView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, size: 36, color: Color(0xFF007A87)),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Clear! No Active Defaulters',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every member in Group 1 is current on installments.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5A6E72)),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaulterCard(ChitMemberRisk member) {
    Color riskColor = member.defaultRiskScore > 75
        ? const Color(0xFFDC2626) // Red
        : const Color(0xFFD97706); // Amber

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: member.forfeited ? const Color(0xFFCBD5E1) : riskColor.withOpacity(0.3),
          width: member.forfeited ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member Name & Risk Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2540),
                      decoration: member.forfeited ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.phone,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5A6E72)),
                  ),
                ],
              ),
              _buildStatusBadge(member),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFE2E8F0)),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OUTSTANDING DUES', style: TextStyle(fontSize: 10, color: Color(0xFF5A6E72), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${member.amountExposed.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2540)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PAYMENT TRACK', style: TextStyle(fontSize: 10, color: Color(0xFF5A6E72), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    member.paymentTrend,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AUCTION STATUS', style: TextStyle(fontSize: 10, color: Color(0xFF5A6E72), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    member.payoutPosition,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          if (!member.forfeited)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showNoticeDialog(member),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: member.defaultNoticeSent ? const Color(0xFF007A87) : const Color(0xFF0F4C81),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          member.defaultNoticeSent ? Icons.mark_email_read_rounded : Icons.description_outlined,
                          size: 16,
                          color: member.defaultNoticeSent ? const Color(0xFF007A87) : const Color(0xFF0F4C81),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.defaultNoticeSent ? 'Notice Dispatched' : 'Section 28 Notice',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: member.defaultNoticeSent ? const Color(0xFF007A87) : const Color(0xFF0F4C81),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _triggerForfeiture(member),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock_outline, size: 16),
                        SizedBox(width: 8),
                        Text('Trigger Forfeiture', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.lock_person_rounded, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Account forfeited. Locked deposit held in escrow. Legally flagged.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ChitMemberRisk member) {
    if (member.forfeited) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'FORFEITED',
          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    if (member.defaultNoticeSent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF007A87).withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF007A87), width: 1),
        ),
        child: const Text(
          'NOTICE SENT',
          style: TextStyle(fontSize: 10, color: Color(0xFF007A87), fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDC2626), width: 1),
      ),
      child: const Text(
        'DEFAULT OVERDUE',
        style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
      ),
    );
  }
}
