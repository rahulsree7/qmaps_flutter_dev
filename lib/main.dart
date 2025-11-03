import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/pin_setup_page.dart';
import 'screens/auth/pin_login_page.dart';
import 'screens/home_page.dart';
import 'services/auth_service.dart';
import 'screens/checklist/checklists_page.dart';
import 'screens/tasks/qr_scanner_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QMAPS Flutter',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Force light theme to match emulator look consistently
      themeMode: ThemeMode.light,
      // Normalize text scaling across devices to keep UI consistent
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/pin-login': (context) => const PinLoginPage(),
        '/home': (context) => const HomePage(),
        '/checklists': (context) => const ChecklistsPage(),
        '/qr-scanner': (context) => const QRScannerPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _isFirstLogin = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final hasValidSession = await AuthService.hasValidSession();
    final isPinSet = await AuthService.isPinSet();
    final isFirstTimeLogin = await AuthService.isFirstTimeLogin();

    print('Debug - AuthWrapper: hasValidSession=$hasValidSession, isPinSet=$isPinSet, isFirstTimeLogin=$isFirstTimeLogin');

    if (mounted) {
      setState(() {
        _isLoggedIn = hasValidSession;
        _isFirstLogin = isFirstTimeLogin;
        _isLoading = false;
      });
    }
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

    print('Debug - AuthWrapper build: _isLoggedIn=$_isLoggedIn, _isFirstLogin=$_isFirstLogin');

    // If user has valid session, go to dashboard
    if (_isLoggedIn) {
      print('Debug - Going to dashboard (valid session)');
      return const HomePage();
    }

    // If PIN is set and it's not first time login, go to PIN login
    if (_isFirstLogin == false) {
      print('Debug - Going to PIN login page');
      return const PinLoginPage();
    }

    // If it's first login or no PIN set, go to email/password login
    print('Debug - Going to email/password login page');
    return const LoginPage();
  }
}
