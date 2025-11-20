import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'pin_setup_page.dart';
import 'pin_login_page.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late AnimationController _floatingController;
  late Animation<double> _logoAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    // Initialize animations
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));
    
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _logoController.forward();
    _backgroundController.repeat(reverse: true);
    _floatingController.repeat(reverse: true);
    
    // Check biometric availability
    _checkBiometricAvailability();
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _logoController.dispose();
    _backgroundController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Clear any previous error
    setState(() {
      _errorMessage = null;
    });

    // Validate inputs
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and password';
      });
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call API for email/password authentication
      final result = await AuthService.loginWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

        if (result['success']) {
          // Store user session
          await AuthService.storeUserSession(result['data']);
          
          // Check if PIN is already set up
          final pinSet = await AuthService.isPinSet();

      if (pinSet) {
        // PIN is already set, go to PIN login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinLoginPage()),
        );
      } else {
            // PIN not set, go to PIN setup (first time)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PinSetupPage()),
            );
          }
        } else {
          // Show error message inline
          setState(() {
            _errorMessage = result['message'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An error occurred: ${e.toString()}';
        });
      }
    }
  }

  // Add email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }



  Future<void> _faceIdLogin() async {
    if (!_isBiometricAvailable) {
      setState(() {
        _errorMessage = 'Biometric authentication is not available on this device';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get available biometrics
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      if (availableBiometrics.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No biometric authentication methods are enrolled';
        });
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
          // Check if PIN is already set up
          final pinSet = await AuthService.isPinSet();

          if (pinSet) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PinLoginPage()),
            );
          } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PinSetupPage()),
        );
          }
        } else {
          setState(() {
            _errorMessage = 'Biometric authentication failed';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Biometric authentication error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Container(
        height: MediaQuery.of(context).size.height,
        child: Stack(
              children: [
            // Animated background graphics
            _buildAnimatedBackgroundGraphics(),
          
          // Main content with responsive layout
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                            MediaQuery.of(context).padding.top - 
                            MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Animated logo and branding
                      _buildAnimatedLogoSection(),
                      
                      const SizedBox(height: 16),
                      
                      // Q-M-A-P-S icons row
                      _buildAnimatedMiddleGraphics(),
                      
                      const SizedBox(height: 16),
                      
                      // Email and Password Input Fields
                      _buildLoginForm(),
                      
                      // Error message display
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(),
                      ],
                      
                      const SizedBox(height: 30),
                      
                      // Action buttons
                      _buildActionButtons(),
                      
                      const SizedBox(height: 20),
                      
                      // Face ID section
                      _buildFaceIdSection(),
                      
                      const SizedBox(height: 20),
                      
                      // Debug button to clear all data (for testing)
                      if (true) // Set to false in production
                        TextButton(
                          onPressed: () async {
                            await AuthService.clearAllData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All session data cleared!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Clear All Data (Debug)',
                  style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      
                      // Spacer to push content to center when there's extra space
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
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

  Widget _buildLoginForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Email field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryRed),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Password field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryRed),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _errorMessage = null;
              });
            },
            child: Icon(
              Icons.close,
              color: Colors.red[600],
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogoSection() {
    return AnimatedBuilder(
      animation: _logoAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoAnimation.value,
          child: Column(
            children: [
              // QMAPS logo with text underneath
              Column(
                children: [
                  _buildQmapsLogo(),
                  Transform.translate(
                    offset: const Offset(0, -70),
                    child: const Text(
                      'Quality Management & Operations',
                      style: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQmapsLogo() {
    // Responsive logo size based on screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final logoSize = screenHeight < 600 ? 120.0 : 200.0;
    
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

  Widget _buildAnimatedMiddleGraphics() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate available width and adjust spacing
              final availableWidth = constraints.maxWidth;
              final cardWidth = 65.0;
              final totalCardsWidth = 5 * cardWidth;
              final availableSpace = availableWidth - totalCardsWidth;
              final spacing = availableSpace / 6; // 5 gaps between 6 positions
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Q-M-A-P-S system cards in a single line with spacing
                  Transform.translate(
                    offset: Offset(0, 5 * _floatingAnimation.value),
                    child: _buildFloatingCard(
                      icon: Icons.verified,
                      title: 'Quality',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -3 * _floatingAnimation.value),
                    child: _buildFloatingCard(
                      icon: Icons.monitor,
                      title: 'Monitoring',
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, 2 * _floatingAnimation.value),
                    child: _buildFloatingCard(
                      icon: Icons.analytics_outlined,
                      title: 'Analytics',
                      color: const Color(0xFF06B6D4),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, 4 * _floatingAnimation.value),
                    child: _buildFloatingCard(
                      icon: Icons.assignment,
                      title: 'Planning',
                      color: const Color(0xFF8B5CF6),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, -2 * _floatingAnimation.value),
                    child: _buildFloatingCard(
                      icon: Icons.settings_system_daydream,
                      title: 'System',
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFloatingCard({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive size based on available width
        final availableWidth = constraints.maxWidth;
        final cardSize = (availableWidth * 0.12).clamp(45.0, 60.0);
        final iconSize = (cardSize * 0.35).clamp(16.0, 20.0);
        final fontSize = (cardSize * 0.15).clamp(7.0, 10.0);
        
        return Container(
          width: cardSize,
          height: cardSize,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: iconSize,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return AnimatedBuilder(
      animation: _logoAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * _logoAnimation.value),
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: AppTheme.primaryGradientDecoration,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Access QMAPS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFaceIdSection() {
    // Hide Face ID section on first login - only show after PIN is set up
    return const SizedBox.shrink();
  }

  Widget _buildAnimatedBackgroundGraphics() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: AnimatedBackgroundPainter(_backgroundAnimation.value),
          ),
        );
      },
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

class AnimatedConnectionPainter extends CustomPainter {
  final double animationValue;

  AnimatedConnectionPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E40AF).withOpacity(0.3 * animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw connecting lines between floating cards
    final path = Path();
    path.moveTo(55, 55); // Quality card
    path.quadraticBezierTo(
      size.width * 0.5, 40 + (20 * animationValue),
      size.width - 55, 55, // Analytics card
    );
    path.moveTo(55, size.height - 55); // Compliance card
    path.quadraticBezierTo(
      size.width * 0.5, size.height * 0.5 + (10 * animationValue),
      size.width - 55, size.height - 55, // Operations card
    );

    canvas.drawPath(path, paint);
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
