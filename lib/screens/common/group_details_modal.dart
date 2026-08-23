import 'package:flutter/material.dart';
import '../../models/chit_group.dart';
import '../../models/member_risk.dart';
import '../../models/digital_agreement.dart';
import '../../services/supabase_service.dart';
import 'digital_agreement_modal.dart';

class GroupDetailsModal extends StatefulWidget {
  final ChitGroup group;
  final bool isForeman;
  final String currentUsername;

  const GroupDetailsModal({
    super.key,
    required this.group,
    required this.isForeman,
    required this.currentUsername,
  });

  @override
  State<GroupDetailsModal> createState() => _GroupDetailsModalState();
}

class _GroupDetailsModalState extends State<GroupDetailsModal> {
  List<ChitMemberRisk> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
  }

  void _loadGroupMembers() async {
    setState(() => _isLoading = true);
    final members = await SupabaseService.getGroupMembers(widget.group.id);
    setState(() {
      _members = members;
      _isLoading = false;
    });
  }

  void _openDigitalAgreement() async {
    final agreementText = DigitalAgreement.generateLegalAgreementText(
      groupName: widget.group.name,
      foremanName: widget.isForeman ? 'Rajesh Kumar (Foreman)' : 'Foreman Host',
      memberName: widget.isForeman ? 'Subscriber Member' : widget.currentUsername,
      poolAmount: widget.group.totalPoolSize,
      durationMonths: widget.group.durationMonths,
      monthlyContribution: widget.group.monthlyContribution,
      schemeType: widget.group.schemeType,
      securityDeposit: widget.group.securityDeposit,
    );

    var agreement = await SupabaseService.getDigitalAgreement(
      groupId: widget.group.id,
      memberUsername: widget.currentUsername,
    );

    agreement ??= DigitalAgreement(
      id: 'agreement_${widget.group.id}',
      groupId: widget.group.id,
      groupName: widget.group.name,
      foremanUsername: 'foreman_admin',
      foremanName: 'Rajesh Kumar (Foreman)',
      memberUsername: widget.currentUsername,
      memberName: widget.currentUsername,
      poolAmount: widget.group.totalPoolSize,
      durationMonths: widget.group.durationMonths,
      monthlyContribution: widget.group.monthlyContribution,
      schemeType: widget.group.schemeType,
      agreementText: agreementText,
      createdAt: DateTime.now(),
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => DigitalAgreementModal(
          agreement: agreement!,
          isForeman: widget.isForeman,
          onSigned: () {
            _loadGroupMembers();
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final progressPct = (g.currentCycle / g.durationMonths).clamp(0.0, 1.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        height: MediaQuery.of(context).size.height * 0.88,
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
                  child: Icon(
                    g.schemeType == 'Bidding' ? Icons.gavel_rounded : Icons.casino_rounded,
                    color: const Color(0xFF0F4C81),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '6-Digit Code: ${g.inviteCode} • ${g.city} • ${g.schemeType} System',
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
            const SizedBox(height: 20),

            // Mandated Monthly Schedule Banner (1st & 10th of every month)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F4C81),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHIT SCHEME MONTHLY TIMELINE & DUE DATES',
                    style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    g.schemeType == 'Bidding' ? Icons.gavel : Icons.casino,
                                    color: const Color(0xFFF59E0B),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Monthly Bidding / Draw', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('1st of Every Month', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const Text('Cycle auction starts at 10:00 AM IST', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.payment_rounded, color: Color(0xFF86EFAC), size: 16),
                                  SizedBox(width: 6),
                                  Text('Subscriber Due Date', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text('10th of Every Month', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const Text('Monthly installment deadline', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Financial Breakdown Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildFinancialTile(
                            title: 'TOTAL CHIT POOL',
                            value: '₹${g.totalPoolSize.toStringAsFixed(0)}',
                            color: const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialTile(
                            title: 'MONTHLY CONTRIB.',
                            value: '₹${g.monthlyContribution.toStringAsFixed(0)}/mo',
                            color: const Color(0xFF007A87),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildFinancialTile(
                            title: 'ESCROW DEPOSIT',
                            value: '₹${g.securityDeposit.toStringAsFixed(0)}',
                            color: const Color(0xFF0F4C81),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Progress Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Cycle Progress: Month ${g.currentCycle} of ${g.durationMonths}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              Text('${(progressPct * 100).toStringAsFixed(0)}% Completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF007A87))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progressPct,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F4C81)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Digital Agreement Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openDigitalAgreement,
                        icon: const Icon(Icons.gavel_rounded, color: Color(0xFF0F4C81)),
                        label: const Text('View & Sign Legally Binding Digital Agreement (Chit Funds Act 1982)', style: TextStyle(color: Color(0xFF0F4C81), fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F4C81), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Roster of Members
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subscribed Members Roster', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('${_members.length} Active Subscribers', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFF0F4C81))))
                    else if (_members.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text('No members subscribed yet. Share 6-digit code to invite members.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      )
                    else
                      Column(
                        children: _members.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 14,
                                backgroundColor: Color(0xFF0F4C81),
                                child: Icon(Icons.person, size: 14, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                              Text(m.payoutPosition, style: const TextStyle(fontSize: 11, color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Verified', style: TextStyle(color: Color(0xFF166534), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )).toList(),
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

  Widget _buildFinancialTile({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}
