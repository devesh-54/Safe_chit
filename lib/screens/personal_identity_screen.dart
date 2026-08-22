import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/onboarding_state.dart';
import '../widgets/premium_date_picker.dart';

class PersonalIdentityScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const PersonalIdentityScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<PersonalIdentityScreen> createState() => _PersonalIdentityScreenState();
}

class _PersonalIdentityScreenState extends State<PersonalIdentityScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDob;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.state.legalName;
    _selectedDob = widget.state.dob;
    _selectedGender = widget.state.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    // Allow users at least 18 years old to join ChitGuard
    final initialDate = DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(now.year - 100);
    final lastDate = DateTime(now.year - 18, now.month, now.day);

    final DateTime? picked = await showPremiumDatePicker(
      context: context,
      initialDate: _selectedDob ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != _selectedDob) {
      if (!context.mounted) return;
      setState(() {
        _selectedDob = picked;
      });
      _updateState();
    }
  }

  void _updateState() {
    widget.state.setPersonalIdentity(
      name: _nameController.text.trim(),
      dateOfBirth: _selectedDob,
      selectGender: _selectedGender,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = widget.state.isPersonalIdentityValid();

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Details',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A2540),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter details exactly as they appear on your government-issued identity documents to ensure successful verification.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // LEGAL NAME
                    const Text(
                      'Full Legal Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'As printed on PAN / Aadhaar',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        _updateState();
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    // DATE OF BIRTH
                    const Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Color(0xFF64748B), size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDob == null
                                  ? 'Select date of birth'
                                  : DateFormat('dd MMMM yyyy').format(_selectedDob!),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _selectedDob == null ? FontWeight.w400 : FontWeight.w600,
                                color: _selectedDob == null ? const Color(0xFF94A3B8) : const Color(0xFF0A2540),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // GENDER (OPTIONAL)
                    const Row(
                      children: [
                        Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                       items: ['Male', 'Female']
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(
                                  label,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ))
                          .toList(),
                      decoration: InputDecoration(
                        hintText: 'Select gender',
                        prefixIcon: const Icon(Icons.wc_rounded, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                        _updateState();
                      },
                    ),

                    const Spacer(),
                    const SizedBox(height: 32),

                    // CONTINUE BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isValid ? widget.onContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F4C81),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
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
        );
      },
    );
  }
}
