import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

class GovIdVerificationScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const GovIdVerificationScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<GovIdVerificationScreen> createState() => _GovIdVerificationScreenState();
}

class _GovIdVerificationScreenState extends State<GovIdVerificationScreen> {
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _aadhaarFocusNode = FocusNode();

  bool _isAadhaarFocused = false;
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _panController.text = widget.state.panNumber;
    
    // Set initially masked or plain value
    if (widget.state.aadhaarNumber.length == 12) {
      _aadhaarController.text = _maskAadhaar(widget.state.aadhaarNumber);
    } else {
      _aadhaarController.text = widget.state.aadhaarNumber;
    }

    _aadhaarFocusNode.addListener(_handleAadhaarFocusChange);
  }

  @override
  void dispose() {
    _panController.dispose();
    _aadhaarController.dispose();
    _aadhaarFocusNode.removeListener(_handleAadhaarFocusChange);
    _aadhaarFocusNode.dispose();
    super.dispose();
  }

  void _handleAadhaarFocusChange() {
    if (!context.mounted) return;
    setState(() {
      _isAadhaarFocused = _aadhaarFocusNode.hasFocus;
      if (_isAadhaarFocused) {
        // Show plain Aadhaar when focused for editing
        _aadhaarController.text = widget.state.aadhaarNumber;
      } else {
        // Mask Aadhaar when focus is lost
        if (widget.state.aadhaarNumber.length == 12) {
          _aadhaarController.text = _maskAadhaar(widget.state.aadhaarNumber);
        }
      }
    });
  }

  String _maskAadhaar(String rawAadhaar) {
    if (rawAadhaar.length != 12) return rawAadhaar;
    return '•••• •••• ${rawAadhaar.substring(8)}';
  }

  void _onAadhaarChanged(String val) {
    // Only accept numeric inputs
    final numericVal = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericVal.length <= 12) {
      widget.state.setAadhaarNumber(numericVal);
    }
  }

  Future<void> _pickDocumentImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos of documents.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      bool isGranted = false;
      if (await Permission.photos.request().isGranted) {
        isGranted = true;
      } else if (await Permission.storage.request().isGranted) {
        isGranted = true;
      } else {
        final statusPhotos = await Permission.photos.request();
        if (statusPhotos.isGranted) {
          isGranted = true;
        } else {
          final statusStorage = await Permission.storage.request();
          if (statusStorage.isGranted) {
            isGranted = true;
          }
        }
      }

      if (!isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo gallery permission is required to select documents.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          widget.state.setIdDocumentPath(file.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Document selected: ${file.name}'),
              backgroundColor: const Color(0xFF0F4C81),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _pickDocumentOption() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload ID Document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0F4C81)),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocumentImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF0F4C81)),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocumentImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _startVerification() async {
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final success = await widget.state.verifyGovernmentIds();

    if (!context.mounted) return;
    setState(() {
      _isVerifying = false;
      if (!success) {
        _errorMessage = 'Verification failed. Double check PAN format (e.g. ABCDE1234F), Aadhaar count (12 digits), and verify ID photo is uploaded.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.govIdStatus;
    final hasDocument = widget.state.idDocumentPath != null;

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
                          'Government ID',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        StatusBadge(status: status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We securely verify government identifiers with central registries (NSDL/UIDAI) for fraud reduction.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // PAN NUMBER
                    const Text(
                      'PAN Card Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _panController,
                      maxLength: 10,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                      enabled: status != VerificationStatus.verified && !_isVerifying,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'ABCDE1234F',
                        prefixIcon: const Icon(Icons.credit_card_rounded, color: Color(0xFF64748B)),
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
                        widget.state.setPanNumber(val);
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 20),

                    // AADHAAR NUMBER
                    const Text(
                      'Aadhaar Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aadhaarController,
                      focusNode: _aadhaarFocusNode,
                      maxLength: 12,
                      keyboardType: TextInputType.number,
                      enabled: status != VerificationStatus.verified && !_isVerifying,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: _isAadhaarFocused ? 2 : 1,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '12-digit number',
                        prefixIcon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF64748B)),
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
                      onChanged: _onAadhaarChanged,
                    ),

                    const SizedBox(height: 24),

                    // DOCUMENT UPLOAD COMPONENT
                    const Text(
                      'Upload Government ID Scan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                    onTap: status != VerificationStatus.verified && !_isVerifying ? _pickDocumentOption : null,
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 120,
                        decoration: BoxDecoration(
                          color: hasDocument ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasDocument ? const Color(0xFF0F4C81) : const Color(0xFFCBD5E1),
                            style: hasDocument ? BorderStyle.solid : BorderStyle.none,
                          ),
                        ),
                        child: hasDocument
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF0F4C81), size: 30),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.state.idDocumentPath!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            '1.4 MB • Complete Scan',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (status != VerificationStatus.verified)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                        onPressed: () {
                                          widget.state.setIdDocumentPath(null);
                                        },
                                      ),
                                  ],
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF64748B)),
                                    SizedBox(height: 6),
                                    Text(
                                      'Upload scan (JPEG/PNG/PDF)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Max size 5MB',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // VERIFICATION STATUS / INTERACTION BAR
                    if (_isVerifying) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0F4C81),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Verifying KYC credentials against UIDAI / NSDL databases...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == VerificationStatus.verified) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
                            SizedBox(width: 12),
                            Text(
                              'Identity validation successful!',
                              style: TextStyle(
                                color: Color(0xFF065F46),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),
                    const SizedBox(height: 32),

                    // ACTIONS
                    if (status != VerificationStatus.verified) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: widget.state.panNumber.isNotEmpty &&
                                  widget.state.aadhaarNumber.length == 12 &&
                                  hasDocument &&
                                  !_isVerifying
                              ? _startVerification
                              : null,
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
                            'Verify Documents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                    ]
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
