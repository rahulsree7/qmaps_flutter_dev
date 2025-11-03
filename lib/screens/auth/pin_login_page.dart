import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../home_page.dart';
import '../../services/auth_service.dart';
import 'dart:math' as math;

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> with TickerProviderStateMixin {
  final List<String> _pin = [];
  int _attempts = 0;
  bool _isLoading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricAvailability();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _bgAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bgController,
      curve: Curves.linear,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _bgController.repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (mounted) {
        setState(() {
          _isBiometricAvailable = isAvailable && isDeviceSupported;
        });
      }
    } catch (e) {
      print('Error checking biometric availability: $e');
    }
  }

  void _addDigit(String digit) {
    if (_pin.length < 4 && !_isLoading) {
      setState(() {
        _pin.add(digit);
      });
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty && !_isLoading) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _clearPin() {
    if (!_isLoading) {
      setState(() {
        _pin.clear();
      });
    }
  }

  Future<void> _verifyPin() async {
    if (_pin.length == 4 && !_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Simulate verification delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify PIN using AuthService
      final isValidPin = await AuthService.verifyPin(_pin.join(''));

      if (isValidPin) {
        // PIN is correct, check if session was restored
        final hasValidSession = await AuthService.hasValidSession();
        
        if (hasValidSession) {
          // Session restored successfully, go to dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          // Session could not be restored, need to login again
          setState(() {
            _isLoading = false;
            _pin.clear();
          });
          
          _showErrorDialog(
            'Session expired. Please login with your email and password.',
            () async {
              // Clear session and go back to login page
              await AuthService.clearExpiredSession();
              Navigator.pop(context); // Close the dialog
              if (mounted) {
                // Use pushReplacementNamed to go to login page
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          );
        }
      } else {
        // PIN is incorrect
        setState(() {
          _attempts++;
          _isLoading = false;
          _pin.clear();
        });

        if (_attempts >= 3) {
          _showErrorDialog(
            'Too many failed attempts. Please login with your email and password.',
            () async {
              // Clear session and go back to login page
              await AuthService.clearExpiredSession();
              Navigator.pop(context); // Close the dialog
              if (mounted) {
                // Use pushReplacementNamed to go to login page
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          );
        } else {
          _showErrorDialog(
            'Incorrect PIN. ${3 - _attempts} attempts remaining.',
            () => Navigator.pop(context),
          );
        }
      }
    }
  }

  Future<void> _faceIdLogin() async {
    if (!_isBiometricAvailable) {
      _showErrorDialog(
        'Biometric authentication is not available on this device',
        () => Navigator.pop(context),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(
          'No biometric authentication methods are enrolled',
          () => Navigator.pop(context),
        );
        return;
      }

      // Authenticate with biometrics
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access QMAPS',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (authenticated) {
          // Biometric authentication successful, check if session is valid
          final hasValidSession = await AuthService.hasValidSession();
          
          if (hasValidSession) {
            // Session is valid, go to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else {
            // Session is not valid, need to login again
            _showErrorDialog(
              'Session expired. Please login with your email and password.',
              () async {
                // Clear session and go back to login page
                await AuthService.clearExpiredSession();
                Navigator.pop(context); // Close the dialog
                if (mounted) {
                  // Use pushReplacementNamed to go to login page
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            );
          }
        } else {
          _showErrorDialog(
            'Biometric authentication failed',
            () => Navigator.pop(context),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(
          'Biometric authentication error: ${e.toString()}',
          () => Navigator.pop(context),
        );
      }
    }
  }

  void _showErrorDialog(String message, VoidCallback onOk) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: onOk,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Same as login page
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: Stack(
          children: [
            // Animated background graphics (same as login page)
            _buildAnimatedBackgroundGraphics(),
            
            // Main content with responsive layout optimized for iPhone 16
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Animated logo and branding (same as login page)
                    _buildAnimatedLogoSection(),
                    
                    const SizedBox(height: 16),
                    
                    // PIN Input Section
                    _buildPinInputSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Face ID Section
                    if (_isBiometricAvailable && !_isLoading) _buildFaceIdSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Number Pad
                    if (!_isLoading) _buildNumberPad(),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    if (!_isLoading) _buildActionButtons(),
                    
                    // Add bottom padding to ensure content is not cut off
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
            ),
            
            // Loading overlay (same as login page)
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackgroundGraphics() {
    return AnimatedBuilder(
      animation: _bgAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: AnimatedBackgroundPainter(_bgAnimation.value),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedLogoSection() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fadeAnimation.value,
          child: Column(
            children: [
              // QMAPS logo with text underneath - fixed positioning
              Column(
                children: [
                  _buildQmapsLogo(),
                  const SizedBox(height: 16), // Add proper spacing
                  const Text(
                    'Quality Management & Operations',
                    style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // PIN Title
              const Text(
                'Enter Your PIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              
              // PIN Subtitle
              Text(
                'Enter your 4-digit PIN to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              
              // Failed attempts indicator
              if (_attempts > 0) ...[
                const SizedBox(height: 16),
                Text(
                  'Failed attempts: $_attempts/3',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildQmapsLogo() {
    // Responsive logo size based on screen height - optimized for iPhone 16
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = screenHeight < 700 ? 100.0 : (screenHeight < 800 ? 140.0 : 180.0);
    
    return Container(
      width: logoSize,
      height: logoSize,
      child: Image.asset(
        'assets/images/logo.png',
        width: logoSize,
        height: logoSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to custom painter if image not found
          return CustomPaint(
            painter: QmapsLogoPainter(),
            size: Size(logoSize, logoSize),
          );
        },
      ),
    );
  }


  Widget _buildPinInputSection() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length 
                        ? const Color(0xFF1E40AF) // Blue when filled
                        : Colors.transparent, // Transparent when empty
                    border: Border.all(
                      color: const Color(0xFF1E40AF), // Blue border
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaceIdSection() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: GestureDetector(
              onTap: _faceIdLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF1E40AF).withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fingerprint,
                      color: Color(0xFF1E40AF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Use Face ID',
                      style: TextStyle(
                        color: Color(0xFF1E40AF),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Widget _buildNumberPad() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('1'),
                    _buildNumberButton('2'),
                    _buildNumberButton('3'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('4'),
                    _buildNumberButton('5'),
                    _buildNumberButton('6'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumberButton('7'),
                    _buildNumberButton('8'),
                    _buildNumberButton('9'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 60), // Empty space
                    _buildNumberButton('0'),
                    _buildActionButton(
                      icon: Icons.backspace,
                      onPressed: _removeDigit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                TextButton(
                  onPressed: _clearPin,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(
                      color: Color(0xFF1E40AF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: () {
        _addDigit(number);
        if (_pin.length == 4) {
          _verifyPin();
        }
      },
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF1E40AF).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E40AF),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF1E40AF).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: const Color(0xFF1E40AF),
          ),
        ),
      ),
    );
  }
}

class AnimatedBackgroundPainter extends CustomPainter {
  final double animationValue;

  AnimatedBackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E40AF).withOpacity(0.05 + (0.1 * animationValue))
      ..style = PaintingStyle.fill;

    // Draw flowing quality management shapes
    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.2, size.height * (0.2 + 0.1 * animationValue),
      size.width * 0.4, size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.6, size.height * (0.5 - 0.1 * animationValue),
      size.width * 0.8, size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width, size.height * (0.3 + 0.1 * animationValue),
      size.width, size.height,
    );
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Add floating quality indicators
    final paint2 = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.1 + (0.05 * animationValue))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.2),
      30 + (10 * animationValue),
      paint2,
    );

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      25 + (5 * animationValue),
      paint2,
    );

    // Add data flow lines
    final paint3 = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final linePath = Path();
    linePath.moveTo(size.width * 0.1, size.height * 0.3);
    linePath.quadraticBezierTo(
      size.width * 0.5, size.height * (0.2 + 0.1 * animationValue),
      size.width * 0.9, size.height * 0.4,
    );
    canvas.drawPath(linePath, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class QmapsLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    
    // Draw the main circular part of 'q' in teal
    final circlePaint = Paint()
      ..color = const Color(0xFF20B2AA) // Teal color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, circlePaint);
    
    // Draw the ribbon-like tail of 'q'
    final ribbonPath = Path();
    ribbonPath.moveTo(center.dx + radius * 0.7, center.dy - radius * 0.3);
    ribbonPath.quadraticBezierTo(
      center.dx + radius * 1.5, center.dy - radius * 0.1,
      center.dx + radius * 1.2, center.dy + radius * 0.8,
    );
    ribbonPath.quadraticBezierTo(
      center.dx + radius * 0.8, center.dy + radius * 1.2,
      center.dx - radius * 0.2, center.dy + radius * 0.9,
    );
    
    // Top surface of ribbon (dark gray)
    final topRibbonPaint = Paint()
      ..color = const Color(0xFF4A5568) // Dark gray
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(ribbonPath, topRibbonPaint);
    
    // Bottom surface of ribbon (lighter blue)
    final bottomRibbonPath = Path();
    bottomRibbonPath.moveTo(center.dx + radius * 0.7, center.dy - radius * 0.2);
    bottomRibbonPath.quadraticBezierTo(
      center.dx + radius * 1.3, center.dy + radius * 0.1,
      center.dx + radius * 1.0, center.dy + radius * 0.9,
    );
    bottomRibbonPath.quadraticBezierTo(
      center.dx + radius * 0.6, center.dy + radius * 1.1,
      center.dx - radius * 0.1, center.dy + radius * 0.8,
    );
    
    final bottomRibbonPaint = Paint()
      ..color = const Color(0xFF63B3ED) // Lighter blue
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(bottomRibbonPath, bottomRibbonPaint);
    
    // Add some depth with shadows
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(center, radius + 2, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
