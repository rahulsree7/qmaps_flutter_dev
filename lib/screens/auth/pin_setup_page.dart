import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../home_page.dart';
import '../../services/auth_service.dart';

class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final List<String> _pin = [];
  bool _isConfirming = false;
  String _originalPin = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
  }

  Future<void> _checkExistingPin() async {
    final pinSet = await AuthService.isPinSet();
    if (pinSet) {
      // PIN already exists, go to dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin.add(digit);
      });
    }
  }

  void _removeDigit() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  void _clearPin() {
    setState(() {
      _pin.clear();
    });
  }

  Future<void> _processPin() async {
    if (_pin.length == 4) {
      if (!_isConfirming) {
        // First PIN entry
        setState(() {
          _originalPin = _pin.join('');
          _isConfirming = true;
          _pin.clear();
        });
      } else {
        // Confirming PIN
        final enteredPin = _pin.join('');
        if (enteredPin == _originalPin) {
          // PINs match, save to preferences using AuthService
          await AuthService.storePin(_originalPin);
          await AuthService.markPinSetup();

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          // PINs don't match, reset
          _showErrorDialog('PINs do not match. Please try again.');
          setState(() {
            _isConfirming = false;
            _originalPin = '';
            _pin.clear();
          });
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // Header
              Icon(
                Icons.security,
                size: isSmallScreen ? 60 : 80,
                color: Colors.blue[600],
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Set Up Your PIN',
                style: TextStyle(
                  fontSize: isSmallScreen ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Please enter your PIN again to confirm'
                    : 'Create a 4-digit PIN for secure access',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 24 : 48),

              // PIN Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length ? Colors.blue[600] : Colors.grey[300],
                    ),
                  );
                }),
              ),
              SizedBox(height: isSmallScreen ? 24 : 48),

              // Number Pad
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('1', isSmallScreen),
                      _buildNumberButton('2', isSmallScreen),
                      _buildNumberButton('3', isSmallScreen),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('4', isSmallScreen),
                      _buildNumberButton('5', isSmallScreen),
                      _buildNumberButton('6', isSmallScreen),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNumberButton('7', isSmallScreen),
                      _buildNumberButton('8', isSmallScreen),
                      _buildNumberButton('9', isSmallScreen),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: isSmallScreen ? 50 : 60, height: isSmallScreen ? 50 : 60), // Empty space
                      _buildNumberButton('0', isSmallScreen),
                      _buildActionButton(
                        icon: Icons.backspace,
                        onPressed: _removeDigit,
                        isSmallScreen: isSmallScreen,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 16 : 32),

              // Clear Button
              TextButton(
                onPressed: _clearPin,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 14 : 16,
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
    );
  }

  Widget _buildNumberButton(String number, bool isSmallScreen) {
    final buttonSize = isSmallScreen ? 50.0 : 60.0;
    final fontSize = isSmallScreen ? 20.0 : 24.0;
    
    return GestureDetector(
      onTap: () {
        _addDigit(number);
        if (_pin.length == 4) {
          _processPin();
        }
      },
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isSmallScreen = false,
  }) {
    final buttonSize = isSmallScreen ? 50.0 : 60.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
