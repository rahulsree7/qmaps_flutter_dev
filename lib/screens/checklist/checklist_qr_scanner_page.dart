import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../location_filter_page.dart';
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
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  Future<void> _checkCameraPermission() async {
    try {
      // Check if permission handler is available
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
        try {
          await openAppSettings();
        } catch (e) {
          print('Error opening app settings: $e');
        }
      } else {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _debugMessage = 'Camera permission status unknown: $status';
        });
      }
    } catch (e) {
      print('Error checking camera permission: $e');
      // Handle MissingPluginException - plugin not registered
      if (e.toString().contains('MissingPluginException')) {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _debugMessage = 'Permission plugin not registered. Please rebuild the app:\n1. Stop the app\n2. Run: flutter clean\n3. Run: flutter pub get\n4. Rebuild the app';
        });
      } else {
        setState(() {
          _hasPermission = false;
          _permissionDenied = true;
          _debugMessage = 'Error: $e';
        });
      }
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

  void _startQRScanning() async {
    if (!_hasPermission) {
      await _checkCameraPermission();
      if (!mounted || !_hasPermission) return;
    }
    
    setState(() {
      _showScanner = true;
    });
  }

  Widget _buildHeaderSection() {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              shadowColor: Colors.black.withOpacity(0.05),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                splashColor: Colors.black.withOpacity(0.05),
                highlightColor: Colors.black.withOpacity(0.02),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                'Select Location',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerHeaderSection(String title) {
    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Back button
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              shadowColor: Colors.black.withOpacity(0.05),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  _controller.stop();
                  setState(() => _showScanner = false);
                },
                splashColor: Colors.black.withOpacity(0.05),
                highlightColor: Colors.black.withOpacity(0.02),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show QR or Filter options screen
    if (!_showScanner) {
      return Scaffold(
        backgroundColor: AppTheme.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Custom header matching checklist page style
              _buildHeaderSection(),
              // Content
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Filter/Select Card (moved to top)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final result = await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LocationFilterPage(sourceType: 'checklist'),
                                  ),
                                );
                                
                                if (result != null && mounted) {
                                  final location = result['location'];
                                  if (location != null) {
                                    print('Location filter result: $location');
                                    // Use project id (database ID) for filtering
                                    final projectId = location['id']?.toString();
                                    print('Extracted projectId: $projectId (type: ${projectId.runtimeType})');
                                    print('Location object keys: ${location.keys.toList()}');
                                    
                                    if (projectId != null && projectId.isNotEmpty) {
                                      print('Navigating to ChecklistsByLocationPage with projectId: $projectId');
                                      // Navigate to checklists page with selected location (using project ID)
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChecklistsByLocationPage(
                                            locationId: projectId,
                                          ),
                                        ),
                                      );
                                    } else {
                                      print('ERROR: Invalid project ID - projectId is null or empty');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Invalid location ID'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              splashColor: AppTheme.primaryPurple.withOpacity(0.1),
                              highlightColor: AppTheme.primaryPurple.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.filter_list,
                                        size: 48,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Filter & Select',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Browse and select location from a list',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // OR Divider
                        Row(
                          children: [
                            Expanded(child: Container(height: 1, color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(child: Container(height: 1, color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Scan QR Code Card (moved to bottom)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _startQRScanning,
                              borderRadius: BorderRadius.circular(16),
                              splashColor: AppTheme.primaryPurple.withOpacity(0.1),
                              highlightColor: AppTheme.primaryPurple.withOpacity(0.05),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryPurple.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.qr_code_2,
                                        size: 48,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Scan QR Code',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Use your camera to scan location QR codes',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
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

    // Show QR Scanner
    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: AppTheme.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Custom header
              _buildScannerHeaderSection('Scan Location QR Code'),
              // Content
              Expanded(
                child: Center(
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
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (_permissionDenied) {
                                    openAppSettings();
                                  } else {
                                    await Permission.camera.request();
                                    await _checkCameraPermission();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  foregroundColor: AppTheme.textLight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                child: Text(
                                  _permissionDenied ? 'Open Settings' : 'Grant Permission',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _showScanner = false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryPurple,
                                  side: BorderSide(
                                    color: AppTheme.primaryPurple,
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Go Back'),
                              ),
                            ),
                          ],
                        ),
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

    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            _buildScannerHeaderSection('Scan Location QR Code'),
            // Scanner content
            Expanded(
              child: Stack(
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
                backgroundColor: AppTheme.lightBackground,
                body: SafeArea(
                  child: Column(
                    children: [
                      _buildScannerHeaderSection('Scan QR Code'),
                      Expanded(
                        child: Center(
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
                        onPressed: () => setState(() => _showScanner = false),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                        ),
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
            ),
          ],
        ),
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
      ..color = AppTheme.primaryPurple
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
