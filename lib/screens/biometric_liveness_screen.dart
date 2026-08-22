import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/onboarding_state.dart';
import '../widgets/status_badge.dart';

enum LivenessUIState {
  notStarted,
  permissionRequired,
  initializingCamera,
  faceNotDetected,
  multipleFacesDetected,
  positionFace,
  performingLiveness,
  success,
  failed,
  cameraError,
}

class BiometricLivenessScreen extends StatefulWidget {
  final OnboardingState state;
  final VoidCallback onContinue;

  const BiometricLivenessScreen({
    super.key,
    required this.state,
    required this.onContinue,
  });

  @override
  State<BiometricLivenessScreen> createState() => _BiometricLivenessScreenState();
}

class _BiometricLivenessScreenState extends State<BiometricLivenessScreen> with WidgetsBindingObserver {
  LivenessUIState _uiState = LivenessUIState.notStarted;
  CameraController? _cameraController;
  CameraDescription? _frontCamera;
  
  FaceDetector? _faceDetector;
  bool _isDetecting = false;
  
  // State Machine Variables
  int _livenessStep = 1; // 1: Look straight, 2: Blink, 3: Turn left, 4: Turn right, 5: Smile
  String _stepInstruction = 'Align your face in the oval frame';
  
  // Detection tracking variables
  int _stableFrameCount = 0;
  bool _eyesClosedDetected = false;
  int _consecutiveSmiles = 0;
  int _consecutiveTurns = 0;
  
  String? _errorMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Google ML Kit Face Detector
    final options = FaceDetectorOptions(
      enableClassification: true, // For eyes/smile check
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopImageStreamAndDisposeCamera();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    // Handle background / foreground switching
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopImageStreamAndDisposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _checkPermissionAndInit();
    }
  }

  Future<void> _stopImageStreamAndDisposeCamera() async {
    if (_cameraController != null) {
      final tempController = _cameraController!;
      _cameraController = null; // Set to null synchronously to prevent draw race conditions
      try {
        if (tempController.value.isStreamingImages) {
          await tempController.stopImageStream();
        }
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }
      try {
        await tempController.dispose();
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
    }
  }

  Future<void> _checkPermissionAndInit() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _initializeCamera();
    } else {
      setState(() {
        _uiState = LivenessUIState.permissionRequired;
      });
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initializeCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _uiState = LivenessUIState.permissionRequired;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission permanently denied. Please enable it in Settings.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    } else {
      setState(() {
        _uiState = LivenessUIState.permissionRequired;
      });
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _uiState = LivenessUIState.initializingCamera;
      _errorMessage = null;
    });

    try {
      final cameras = await availableCameras();
      // Find front camera
      _frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        _frontCamera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _uiState = LivenessUIState.positionFace;
        _livenessStep = 1;
        _stepInstruction = 'Align your face in the oval frame';
      });

      // Start processing frames from the camera
      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      setState(() {
        _uiState = LivenessUIState.cameraError;
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  // Convert CameraImage frame into ML Kit InputImage and run detector
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isSuccess || _faceDetector == null || _frontCamera == null) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) {
        _isDetecting = false;
        return;
      }

      if (faces.isEmpty) {
        setState(() {
          _uiState = LivenessUIState.faceNotDetected;
          _stepInstruction = 'Align your face in the oval frame';
          _stableFrameCount = 0;
        });
      } else if (faces.length > 1) {
        setState(() {
          _uiState = LivenessUIState.multipleFacesDetected;
          _stepInstruction = 'Ensure only one face is visible';
          _stableFrameCount = 0;
        });
      } else {
        // Exactly one face detected
        final face = faces.first;
        _analyzeFaceLiveness(face, image.width, image.height);
      }
    } catch (e) {
      debugPrint('Error running face detection: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // State Machine logic matching user's requested steps
  void _analyzeFaceLiveness(Face face, int imgWidth, int imgHeight) {
    final boundingBox = face.boundingBox;
    
    // Check if face is centered and sufficiently large (close to camera)
    final faceWidthRatio = boundingBox.width / imgWidth;
    final isCloseEnough = faceWidthRatio > 0.28; // Face fills enough viewport

    if (!isCloseEnough) {
      setState(() {
        _uiState = LivenessUIState.positionFace;
        _stepInstruction = 'Move closer to the camera';
        _stableFrameCount = 0;
      });
      return;
    }

    setState(() {
      _uiState = LivenessUIState.performingLiveness;
    });

    switch (_livenessStep) {
      case 1:
        // Step 1: Look at the camera (Hold face centered and straight)
        _stepInstruction = 'Look straight at the camera';
        final headY = face.headEulerAngleY ?? 0;
        final headZ = face.headEulerAngleZ ?? 0;
        
        if (headY.abs() < 10 && headZ.abs() < 10) {
          _stableFrameCount++;
          if (_stableFrameCount >= 10) { // Stable for ~10 frames (~0.5s)
            setState(() {
              _livenessStep = 2;
              _stableFrameCount = 0;
              _eyesClosedDetected = false;
            });
          }
        } else {
          _stableFrameCount = 0;
        }
        break;

      case 2:
        // Step 2: Blink your eyes
        _stepInstruction = 'Blink your eyes';
        final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

        if (!_eyesClosedDetected) {
          // Detect closed eyes
          if (leftEyeOpen < 0.20 && rightEyeOpen < 0.20) {
            _eyesClosedDetected = true;
          }
        } else {
          // Detect opened eyes after closing
          if (leftEyeOpen > 0.70 && rightEyeOpen > 0.70) {
            setState(() {
              _livenessStep = 3;
              _consecutiveTurns = 0;
            });
          }
        }
        break;

      case 3:
        // Step 3: Turn head slightly left
        _stepInstruction = 'Turn your head slightly left';
        final headY = face.headEulerAngleY ?? 0; // Negative values usually indicate left rotation depending on mirror

        // Front camera mirror orientation check
        if (headY > 15) { 
          _consecutiveTurns++;
          if (_consecutiveTurns >= 5) {
            setState(() {
              _livenessStep = 4;
              _consecutiveTurns = 0;
            });
          }
        } else {
          if (_consecutiveTurns > 0) _consecutiveTurns--;
        }
        break;

      case 4:
        // Step 4: Turn head slightly right
        _stepInstruction = 'Turn your head slightly right';
        final headY = face.headEulerAngleY ?? 0;

        if (headY < -15) { 
          _consecutiveTurns++;
          if (_consecutiveTurns >= 5) {
            setState(() {
              _livenessStep = 5;
              _consecutiveSmiles = 0;
            });
          }
        } else {
          if (_consecutiveTurns > 0) _consecutiveTurns--;
        }
        break;

      case 5:
        // Step 5: Smile
        _stepInstruction = 'Smile for camera';
        final smileProb = face.smilingProbability ?? 0.0;

        if (smileProb > 0.70) {
          _consecutiveSmiles++;
          if (_consecutiveSmiles >= 6) {
            _completeVerificationSuccess();
          }
        } else {
          if (_consecutiveSmiles > 0) _consecutiveSmiles--;
        }
        break;
    }
  }

  // Completed all verification stages successfully
  Future<void> _completeVerificationSuccess() async {
    _isSuccess = true;
    
    // Set UI State to success immediately to remove CameraPreview from tree
    if (mounted) {
      setState(() {
        _uiState = LivenessUIState.success;
        _stepInstruction = 'Verification successful';
      });
    }

    await _stopImageStreamAndDisposeCamera();

    widget.state.setSelfiePath('liveness_selfie_complete.png');
    await widget.state.confirmSelfieLiveness();
  }

  // Convert CameraImage NV21/YUV to InputImage
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (_frontCamera == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    
    // Convert camera sensor orientation to InputImageRotation
    final rotation = _rotationFromSensorOrientation(_frontCamera!.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _rotationFromSensorOrientation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  void _restartVerification() {
    _isSuccess = false;
    _stableFrameCount = 0;
    _eyesClosedDetected = false;
    _consecutiveSmiles = 0;
    _consecutiveTurns = 0;
    _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.biometricStatus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Identity Check',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A2540),
                ),
              ),
              StatusBadge(status: status, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _uiState == LivenessUIState.success
                ? 'Your identity check is completed successfully.'
                : 'Follow the dynamic prompts below inside the circular camera guide to verify you are a real person.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),

          // CAMERA & INSTRUCTION VIEWER
          Expanded(
            child: Center(
              child: _buildCameraContainer(),
            ),
          ),
          const SizedBox(height: 20),

          // ACTIONS
          _buildActionPanel(),
        ],
      ),
    );
  }

  Widget _buildCameraContainer() {
    if (_uiState == LivenessUIState.permissionRequired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 54, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'Camera Access Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2540)),
            ),
            const SizedBox(height: 8),
            const Text(
              'We use your camera to confirm liveness. Please grant permission to continue identity setup.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Allow Camera'),
            ),
          ],
        ),
      );
    }

    if (_uiState == LivenessUIState.initializingCamera) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF0F4C81)),
          SizedBox(height: 16),
          Text(
            'Initializing camera stream...',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    if (_uiState == LivenessUIState.cameraError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 14),
            const Text(
              'Camera Load Error',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: _restartVerification,
              child: const Text('Retry Camera Initialization'),
            )
          ],
        ),
      );
    }

    if (_uiState == LivenessUIState.success) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Identity Verification Successful',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
            ),
            const SizedBox(height: 16),
            _buildCheckrow('Face detected'),
            _buildCheckrow('Liveness checks passed'),
            _buildCheckrow('Verification completed'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Text(
                'Member ID: CG-M00128 • Status: VERIFIED',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ),
          ],
        ),
      );
    }

    // ACTIVE CAMERA STREAM PREVIEW
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // Oval scanning guide overlay color based on tracking status
    Color scannerBorderColor = const Color(0xFFE2E8F0);
    if (_uiState == LivenessUIState.performingLiveness) {
      scannerBorderColor = const Color(0xFF007A87); // Deep Teal if liveness matches
    } else if (_uiState == LivenessUIState.positionFace) {
      scannerBorderColor = const Color(0xFF0F4C81); // Classic blue
    } else if (_uiState == LivenessUIState.faceNotDetected) {
      scannerBorderColor = const Color(0xFFEF4444); // Red
    }

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF334155), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Live camera preview
              CameraPreview(_cameraController!),

              // 2. Custom Painter oval guide overlay
              Positioned.fill(
                child: CustomPaint(
                  painter: LivenessOvalPainter(
                    borderColor: scannerBorderColor,
                  ),
                ),
              ),

              // 3. Dynamic instruction badge
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _stepInstruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (_uiState == LivenessUIState.performingLiveness) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Step $_livenessStep of 5',
                          style: const TextStyle(
                            color: Color(0xFF00B4D8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. Quick status overlay text at the bottom
              Positioned(
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _uiState == LivenessUIState.faceNotDetected
                        ? 'NO FACE DETECTED'
                        : _uiState == LivenessUIState.multipleFacesDetected
                            ? 'MULTIPLE FACES DETECTED'
                            : 'KEEP FACE IN FRAME',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckrow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    if (_uiState == LivenessUIState.success) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: widget.onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (_uiState == LivenessUIState.permissionRequired) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _restartVerification,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset Scanner'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ],
    );
  }
}

class LivenessOvalPainter extends CustomPainter {
  final Color borderColor;

  LivenessOvalPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    // Draw dark background mask outside the oval frame
    final ovalPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width * 0.70,
          height: size.height * 0.65,
        ),
      );

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final overlayPath = Path.combine(PathOperation.difference, bgPath, ovalPath);
    canvas.drawPath(overlayPath, paint);

    // Draw Oval border line
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.70,
        height: size.height * 0.65,
      ),
      borderPaint,
    );

    // Center/Alignment guidelines
    final guidePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.45),
      Offset(size.width * 0.75, size.height * 0.45),
      guidePaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.5, size.height * 0.75),
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant LivenessOvalPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor;
  }
}
