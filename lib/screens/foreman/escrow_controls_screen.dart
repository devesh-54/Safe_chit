import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/member_risk.dart';
import '../../models/security_deposit.dart';
import '../../models/deposit_transaction.dart';
import '../../services/supabase_service.dart';
import '../../core/config/deposit_config.dart';

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
  List<ChitMemberRisk> _members = [];
  Map<String, SecurityDeposit> _depositsMap = {};
  List<DepositTransaction> _transactions = [];
  bool _isLoading = true;
  final String _selectedGroupId = 'group_1'; // Default group

  String _formatIndianCurrency(double val) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: val % 1 == 0 ? 0 : 2,
    ).format(val);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await SupabaseService.getGroupMembers(_selectedGroupId);
      final deposits = await SupabaseService.getGroupSecurityDeposits(_selectedGroupId);
      final txs = await SupabaseService.getDepositTransactions(groupId: _selectedGroupId);

      if (mounted) {
        setState(() {
          _members = members;
          _depositsMap = deposits;
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SecurityDeposit? _getDepositForMember(ChitMemberRisk member) {
    return _depositsMap[member.memberUsername] ??
        _depositsMap[member.id] ??
        _depositsMap.values
            .where((d) =>
                member.memberUsername.isNotEmpty &&
                d.memberId.toLowerCase() ==
                    member.memberUsername.toLowerCase())
            .firstOrNull;
  }

  void _handleRefund(SecurityDeposit dep, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Deposit?'),
        content: Text('Refund ${_formatIndianCurrency(dep.amount)} to @$memberName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
            child: const Text('Confirm Refund'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final success = await SupabaseService.refundDeposit(
      depositId: dep.id,
      groupId: dep.groupId,
      memberId: dep.memberId,
      amount: dep.amount,
    );

    _loadData();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Deposit refunded to @$memberName!' : 'Refund failed.'),
        backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
  }

  void _handleForfeit(SecurityDeposit dep, String memberName) async {
    final missedController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forfeit Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deposit Amount: ${_formatIndianCurrency(dep.amount)}'),
            const SizedBox(height: 12),
            TextField(
              controller: missedController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Missed contribution amount (optional)',
                hintText: 'e.g. 15000',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'If left blank, full deposit will be forfeited.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            child: const Text('Forfeit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final double? missed = double.tryParse(missedController.text.trim());

    setState(() => _isLoading = true);
    final result = await SupabaseService.forfeitDepositDetailed(
      depositId: dep.id,
      missedAmount: missed,
    );

    _loadData();
    if (!mounted) return;

    if (result['success'] == true) {
      final applied = (result['applied_amount'] as num?)?.toDouble() ?? dep.amount;
      final shortfall = (result['shortfall'] as num?)?.toDouble() ?? 0.0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Forfeiture Applied'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Applied Amount: ${_formatIndianCurrency(applied)}'),
              const SizedBox(height: 6),
              Text(
                'Shortfall: ${_formatIndianCurrency(shortfall)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: shortfall > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 6),
              Text('Reference: ${result['reference'] ?? 'N/A'}'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Forfeit failed: ${result['error'] ?? 'Server error'}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showNoticeDialog(ChitMemberRisk member) {
    final noticeText = '''
LEGAL DEMAND NOTICE
(Under Section 28 of Chit Funds Act, 1982)

TO: ${member.name.toUpperCase()}
PHONE: ${member.phone}

You are hereby notified that you have defaulted on your monthly installment commitments for Chit Group ${_selectedGroupId}.
Total outstanding exposure: ₹${member.amountExposed.toStringAsFixed(2)}.

You are granted a period of 14 days from the date of this receipt to regularize your account.
Failing which, your security deposit will be forfeited and your subscription terminated.

By order of Foreman / Recovery Cell
Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}
''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Section 28 Notice'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              noticeText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: noticeText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notice copied to clipboard!')),
              );
            },
            child: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.saveDefaultNotice(member.id, noticeText);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notice dispatched!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F4C81), foregroundColor: Colors.white),
            child: const Text('Send Notice'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRecorded = _depositsMap.values
        .where((d) => d.isHeld)
        .fold(0.0, (sum, d) => sum + d.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Deposit Control',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0F4C81),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Prototype Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: const Color(0xFFFEF3C7),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF92400E)),
                  SizedBox(width: 6),
                  Text(
                    'Prototype, no real money',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F4C81)))
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Total Deposits Recorded Panel
                            _buildSummaryCard(totalRecorded),
                            const SizedBox(height: 20),

                            // Members Deposit Roster Section
                            const Text(
                              'Member Deposit Statuses',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildMembersRoster(),

                            const SizedBox(height: 24),

                            // Deposit History Section
                            const Text(
                              'Deposit History (Audit Trail)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Immutable append-only server-stamped ledger entries',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 10),
                            _buildTransactionsList(),
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

  Widget _buildSummaryCard(double totalRecorded) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF007A87)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F4C81),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL DEPOSITS RECORDED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE2E8F0),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatIndianCurrency(totalRecorded),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Deposits recorded: ${_formatIndianCurrency(totalRecorded)} across active members',
            style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersRoster() {
    if (_members.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No members found for this chit group.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      children: _members.map((member) {
        final dep = _getDepositForMember(member);
        final status = dep?.displayStatus ?? 'Pending';
        final isRecorded = dep?.isHeld == true;

        Color statusColor;
        switch (status) {
          case 'Recorded':
            statusColor = const Color(0xFF16A34A);
            break;
          case 'Refunded':
            statusColor = const Color(0xFF2563EB);
            break;
          case 'Forfeited':
            statusColor = const Color(0xFFDC2626);
            break;
          default:
            statusColor = const Color(0xFFD97706);
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (member.memberUsername.isNotEmpty &&
                          member.memberUsername.toLowerCase() !=
                              member.name.toLowerCase()) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(@${member.memberUsername})',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deposit Amount: ${_formatIndianCurrency(dep?.amount ?? 0)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),

              // DevTools test actions: Refund & Forfeit
              if (kDevTools && isRecorded && dep != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleRefund(dep, member.name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Test Refund', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleForfeit(dep, member.name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Test Forfeit', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.description_outlined, size: 18),
                      tooltip: 'Notice',
                      onPressed: () => _showNoticeDialog(member),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'No deposit transactions recorded yet.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          final isSuccess = tx.isSuccess;
          final localTimeStr = DateFormat('dd MMM, hh:mm a').format(tx.localCreatedAt);

          IconData typeIcon;
          Color typeColor;
          String typeLabel;

          switch (tx.type) {
            case 'refund':
              typeIcon = Icons.assignment_return_rounded;
              typeColor = const Color(0xFF2563EB);
              typeLabel = 'Refund';
              break;
            case 'forfeit':
              typeIcon = Icons.gavel_rounded;
              typeColor = const Color(0xFFDC2626);
              typeLabel = 'Forfeit';
              break;
            case 'pay':
            default:
              typeIcon = Icons.arrow_downward_rounded;
              typeColor = const Color(0xFF16A34A);
              typeLabel = 'Pay Deposit';
              break;
          }

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: typeColor.withValues(alpha: 0.1),
              child: Icon(typeIcon, size: 16, color: typeColor),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$typeLabel • @${tx.memberId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  _formatIndianCurrency(tx.amount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSuccess ? const Color(0xFF0F172A) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tx.reference != null ? 'Ref: ${tx.reference}' : (tx.failureReason ?? 'Declined'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSuccess ? const Color(0xFF64748B) : const Color(0xFFDC2626),
                  ),
                ),
                Text(
                  localTimeStr,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
