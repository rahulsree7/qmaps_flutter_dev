import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import 'checklists_page.dart';

class ChecklistQRScannerPage extends StatefulWidget {
  const ChecklistQRScannerPage({super.key});

  @override
  State<ChecklistQRScannerPage> createState() => _ChecklistQRScannerPageState();
}

class _ChecklistQRScannerPageState extends State<ChecklistQRScannerPage> {
  late MobileScannerController _controller;
  
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _permissionDenied = false;
  String? _debugMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      print('Camera permission status: $status');
      
      if (status.isGranted) {
        setState(() {
          _hasPermission = true;
          _permissionDenied = false;
          _debugMessage = 'Camera permission granted';
        });
      } else if (status.isDenied) {
        final result = await Permission.camera.request();
        print('Camera permission request result: $result');
        setState(() {
          _hasPermission = result.isGranted;
          _permissionDenied = !result.isGranted;
          _debugMessage = 'Camera permission request: ${result.isDenied ? 'Denied' : 'Granted'}';
        });
      } else if (status.isPermanentlyDenied) {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _debugMessage = 'Camera permission permanently denied. Open app settings.';
        });
        openAppSettings();
      } else {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _debugMessage = 'Camera permission status unknown: $status';
        });
      }
    } catch (e) {
      print('Error checking camera permission: $e');
      setState(() {
        _debugMessage = 'Error: $e';
      });
    }
  }

  Future<void> _handleQRCode(String? code) async {
    if (code == null || _isProcessing) return;

    print('QR Code detected: $code');
    
    setState(() {
      _isProcessing = true;
      _debugMessage = 'Processing QR code: $code';
    });

    try {
      // Extract location ID from QR code
      // QR code format can be: LOC-47929 or location_id:LOC-47929
      String? locationId;
      
      final trimmedCode = code.trim();
      
      if (trimmedCode.contains(':')) {
        final parts = trimmedCode.split(':');
        if (parts.length > 1) {
          locationId = parts[1].trim();
          print('Extracted location ID from format: $locationId');
        }
      } else {
        locationId = trimmedCode;
        print('Extracted location ID directly: $locationId');
      }

      if (locationId == null || locationId.isEmpty) {
        _showError('Invalid QR code format. Expected: LOC-XXXXX or location_id:LOC-XXXXX. Got: $code');
        setState(() {
          _isProcessing = false;
          _debugMessage = 'Invalid format: $code';
        });
        return;
      }

      print('Valid location ID extracted: $locationId');
      
      // Stop scanner
      await _controller.stop();

      // Navigate to checklist list page filtered by location
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChecklistsByLocationPage(locationId: locationId!),
          ),
        );
      }
    } catch (e) {
      print('Error processing QR code: $e');
      _showError('Error processing QR code: ${e.toString()}');
      setState(() {
        _isProcessing = false;
        _debugMessage = 'Error: $e';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Location QR Code'),
          backgroundColor: const Color(0xFF8B5CF6),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _permissionDenied
                      ? 'Camera permission was denied. Please grant it in app settings.'
                      : 'Please grant camera permission to scan QR codes.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_debugMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Debug: $_debugMessage',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (_permissionDenied) {
                      openAppSettings();
                    } else {
                      await Permission.camera.request();
                      await _checkCameraPermission();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    _permissionDenied ? 'Open Settings' : 'Grant Permission',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Location QR Code'),
        backgroundColor: const Color(0xFF8B5CF6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _controller.stop();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              print('Barcodes detected: ${barcodes.length}');
              for (final barcode in barcodes) {
                print('Barcode value: ${barcode.rawValue}, Type: ${barcode.type}');
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue);
                  break;
                }
              }
            },
            errorBuilder: (context, error, child) {
              print('Scanner error: $error');
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Scan QR Code'),
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera Error: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Overlay with scanning area
          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Position Location QR Code within the frame',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isProcessing) ...[
                      const SizedBox(height: 12),
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Calculate scanning area (square in center)
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final scanArea = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Clear scanning area
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    canvas.drawRect(scanArea, clearPaint);

    // Draw border for scanning area
    final borderPaint = Paint()
      ..color = const Color(0xFF8B5CF6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw corners
    final cornerLength = 20.0;
    
    // Top-left
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      borderPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize - cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      borderPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left, top + scanAreaSize - cornerLength),
      borderPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
