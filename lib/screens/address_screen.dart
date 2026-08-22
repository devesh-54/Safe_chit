import 'package:flutter/material.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class AddressScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const AddressScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _permAddressController = TextEditingController();
  final _permCityController = TextEditingController();
  String? _permState;
  final _permPinController = TextEditingController();

  bool _isSame = true;

  final _currAddressController = TextEditingController();
  final _currCityController = TextEditingController();
  String? _currState;
  final _currPinController = TextEditingController();

  final List<String> _indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
    'Chandigarh',
    'Jammu & Kashmir',
    'Puducherry',
  ];

  @override
  void initState() {
    super.initState();
    _permAddressController.text = widget.state.permAddress;
    _permCityController.text = widget.state.permCity;
    _permState = widget.state.permState.isNotEmpty ? widget.state.permState : null;
    _permPinController.text = widget.state.permPinCode;

    _isSame = widget.state.isCurrentSameAsPermanent;

    _currAddressController.text = widget.state.currAddress;
    _currCityController.text = widget.state.currCity;
    _currState = widget.state.currState.isNotEmpty ? widget.state.currState : null;
    _currPinController.text = widget.state.currPinCode;
  }

  @override
  void dispose() {
    _permAddressController.dispose();
    _permCityController.dispose();
    _permPinController.dispose();
    _currAddressController.dispose();
    _currCityController.dispose();
    _currPinController.dispose();
    super.dispose();
  }

  void _updateAddressState() {
    // Write perm address to state
    widget.state.setPermanentAddress(
      address: _permAddressController.text.trim(),
      city: _permCityController.text.trim(),
      state: _permState ?? '',
      pinCode: _permPinController.text.trim(),
    );

    // Apply same-as toggle
    widget.state.setSameAsPermanent(_isSame);

    if (!_isSame) {
      widget.state.setCurrentAddress(
        address: _currAddressController.text.trim(),
        city: _currCityController.text.trim(),
        state: _currState ?? '',
        pinCode: _currPinController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.addressStatus;
    final isValid = widget.state.isAddressValid();

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Address Details',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A2540),
                          ),
                        ),
                        StatusBadge(status: status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please provide your current and permanent addresses. Physical audits may be conducted for high-value funds.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF334155),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // PERMANENT ADDRESS SECTION
                    const Text(
                      'PERMANENT ADDRESS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F4C81),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAddressFields(
                      addressController: _permAddressController,
                      cityController: _permCityController,
                      selectedState: _permState,
                      pinController: _permPinController,
                      onStateChanged: (val) {
                        setState(() {
                          _permState = val;
                        });
                        _updateAddressState();
                      },
                      onChanged: (val) {
                        _updateAddressState();
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 24),

                    // SAME AS PERMANENT TOGGLE Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Current address is same as permanent',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0A2540),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isSame,
                            activeThumbColor: const Color(0xFF0F4C81),
                            activeTrackColor: const Color(0xFF0F4C81).withValues(alpha: 0.5),
                            onChanged: (val) {
                              setState(() {
                                _isSame = val;
                                if (_isSame) {
                                  // Sync values
                                  _currAddressController.text = _permAddressController.text;
                                  _currCityController.text = _permCityController.text;
                                  _currState = _permState;
                                  _currPinController.text = _permPinController.text;
                                } else {
                                  // Clear
                                  _currAddressController.clear();
                                  _currCityController.clear();
                                  _currState = null;
                                  _currPinController.clear();
                                }
                              });
                              _updateAddressState();
                            },
                          ),
                        ],
                      ),
                    ),

                    // CURRENT ADDRESS SECTION (Rendered if toggle is off)
                    if (!_isSame) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'CURRENT ADDRESS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF007A87),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAddressFields(
                        addressController: _currAddressController,
                        cityController: _currCityController,
                        selectedState: _currState,
                        pinController: _currPinController,
                        onStateChanged: (val) {
                          setState(() {
                            _currState = val;
                          });
                          _updateAddressState();
                        },
                        onChanged: (val) {
                          _updateAddressState();
                          setState(() {});
                        },
                      ),
                    ],

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

  Widget _buildAddressFields({
    required TextEditingController addressController,
    required TextEditingController cityController,
    required String? selectedState,
    required TextEditingController pinController,
    required ValueChanged<String?> onStateChanged,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-line Address line 1
        TextFormField(
          controller: addressController,
          maxLines: 2,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Street details, building number, locality',
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
            ),
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // City
            Expanded(
              child: TextFormField(
                controller: cityController,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'City',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 12),
            // Pin Code
            Expanded(
              child: TextFormField(
                controller: pinController,
                maxLength: 6,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'PIN Code',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
                  ),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // State dropdown
        DropdownButtonFormField<String>(
          value: selectedState,
          style: const TextStyle(fontSize: 15, color: Color(0xFF0A2540), fontWeight: FontWeight.w600),
          items: _indianStates
              .map((stateName) => DropdownMenuItem(
                    value: stateName,
                    child: Text(stateName),
                  ))
              .toList(),
          decoration: InputDecoration(
            hintText: 'Select State',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: Color(0xFF0F4C81), width: 1.8),
            ),
          ),
          onChanged: onStateChanged,
        ),
      ],
    );
  }
}
