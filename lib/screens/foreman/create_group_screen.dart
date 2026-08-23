import 'dart:math';
import 'package:flutter/material.dart';
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
  String _schemeType = 'Bidding'; // 'Bidding' or 'Random Picking'
  bool _isPublic = true; // Listed in public discovery marketplace

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
      final codeNum = rand.nextInt(900000) + 100000; // 6-digit numeric code e.g. 849201
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
            ? 'Standard $_schemeType rules per Chit Funds Act 1982.'
            : _payoutRulesController.text.trim(),
        inviteCode: _generatedInviteCode,
        status: 'Active',
        currentCycle: 1,
        membersCount: _targetMembers,
        schemeType: _schemeType,
        isPublic: _isPublic,
      );

      await SupabaseService.createChitGroup(newGroup);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 "${newGroup.name}" created successfully as a $_schemeType Chit!'),
          backgroundColor: const Color(0xFF007A87),
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
          content: Text('Please generate the 6-digit Invite Code first.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthlyContribution = _totalPoolSize / _durationMonths;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Pure Crisp Off-White & Dark Blue Theme
      appBar: widget.onGroupCreated == null
          ? AppBar(
              title: const Text(
                'Create New Chit Group',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C81),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'CHIT GROUP SCHEME SETUP',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Configure Chit Scheme Type & Legal Agreement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose between Bidding or Random Picking systems and enforce digital agreements.',
                          style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Configuration Form Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Group Name Input
                        const Text(
                          'Chit Group Name',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Indiranagar Traders Chit A',
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a group name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // 2. Scheme Type Selector (Bidding vs Random Picking)
                        const Text(
                          'Chit Scheme Type (Payout Model)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _schemeType = 'Bidding'),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _schemeType == 'Bidding' ? const Color(0xFF0F4C81) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _schemeType == 'Bidding' ? const Color(0xFF0F4C81) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.gavel_rounded,
                                            color: _schemeType == 'Bidding' ? Colors.white : const Color(0xFF0F4C81),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Bidding System',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _schemeType == 'Bidding' ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Auctions per cycle. Lowest bidder wins monthly pool discount.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _schemeType == 'Bidding' ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _schemeType = 'Random Picking'),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _schemeType == 'Random Picking' ? const Color(0xFF0F4C81) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _schemeType == 'Random Picking' ? const Color(0xFF0F4C81) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.casino_rounded,
                                            color: _schemeType == 'Random Picking' ? Colors.white : const Color(0xFF0F4C81),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Random Picking',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _schemeType == 'Random Picking' ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Lucky draw / lot picking each cycle. Equal distribution probability.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _schemeType == 'Random Picking' ? const Color(0xFFE2E8F0) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 3. Public Listing Marketplace Switch
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.public_rounded, color: Color(0xFF007A87)),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('List in Public Marketplace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('Allow subscribers to search and discover this scheme publicly', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ],
                              ),
                              Switch(
                                value: _isPublic,
                                activeColor: const Color(0xFF0F4C81),
                                onChanged: (val) => setState(() => _isPublic = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 4. Total Pool Size Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Chit Pool (₹)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                            Text(
                              '₹${_totalPoolSize.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                            ),
                          ],
                        ),
                        Slider(
                          value: _totalPoolSize,
                          min: 100000,
                          max: 5000000,
                          divisions: 49,
                          activeColor: const Color(0xFF007A87),
                          onChanged: (val) => setState(() => _totalPoolSize = val),
                        ),
                        const SizedBox(height: 20),

                        // 5. Duration (Months) Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Duration (Months)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                            Text('$_durationMonths Months', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                          ],
                        ),
                        Slider(
                          value: _durationMonths.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 9,
                          activeColor: const Color(0xFF007A87),
                          onChanged: (val) => setState(() => _durationMonths = val.toInt()),
                        ),
                        const SizedBox(height: 20),

                        // 6. Number of Members (Capacity)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Number of Members (Capacity)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                            Text('$_targetMembers Members', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                          ],
                        ),
                        Slider(
                          value: _targetMembers.toDouble(),
                          min: 5,
                          max: 50,
                          divisions: 45,
                          activeColor: const Color(0xFF007A87),
                          onChanged: (val) => setState(() => _targetMembers = val.toInt()),
                        ),
                        const SizedBox(height: 20),

                        // 7. Security Deposit Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Security Deposit (₹)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                            Text('₹${_securityDeposit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD97706))),
                          ],
                        ),
                        Slider(
                          value: _securityDeposit,
                          min: 10000,
                          max: 200000,
                          divisions: 19,
                          activeColor: const Color(0xFF007A87),
                          onChanged: (val) => setState(() => _securityDeposit = val),
                        ),
                        const SizedBox(height: 24),

                        // Summary Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monthly Contribution / Member:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    '₹${monthlyContribution.toStringAsFixed(0)} / mo',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF007A87), fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Legal Framework:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const Text('Chit Funds Act 1982 (Sec 6 & 28)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F4C81))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // 8. Generate 6-Digit Code & QR Button
                        if (!_inviteGenerated)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _generateInvite,
                              icon: const Icon(Icons.vpn_key_rounded),
                              label: const Text('Generate 6-Digit Join Code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F4C81),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          )
                        else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Column(
                              children: [
                                const Text('6-DIGIT GROUP INVITE CODE', style: TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                const SizedBox(height: 6),
                                Text(_generatedInviteCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFF15803D))),
                                const SizedBox(height: 6),
                                Text('Scheme Type: $_schemeType • Public Marketplace: ${_isPublic ? "Yes" : "Private"}', style: const TextStyle(fontSize: 12, color: Color(0xFF166534))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveGroup,
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text('Launch Chit Group & Save to Supabase'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A87),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
