import 'package:flutter/material.dart';
import 'lib/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== Testing Authentication Flow ===\n');
  
  // Test 1: Check if user is logged in
  print('1. Checking login status...');
  final isLoggedIn = await AuthService.isLoggedIn();
  print('   Is logged in: $isLoggedIn');
  
  // Test 2: Check if PIN is set
  print('\n2. Checking PIN status...');
  final isPinSet = await AuthService.isPinSet();
  print('   Is PIN set: $isPinSet');
  
  // Test 3: Check if we have valid session
  print('\n3. Checking session validity...');
  final hasValidSession = await AuthService.hasValidSession();
  print('   Has valid session: $hasValidSession');
  
  // Test 4: Get stored user data
  print('\n4. Checking stored user data...');
  final userData = await AuthService.getUserData();
  if (userData != null) {
    print('   User data found: ${userData.keys.join(', ')}');
    final token = await AuthService.getAuthToken();
    print('   Token available: ${token != null ? 'Yes (${token.substring(0, 20)}...)' : 'No'}');
  } else {
    print('   No user data found');
  }
  
  // Test 5: Debug all stored data
  print('\n5. All stored data:');
  await AuthService.debugStoredData();
  
  print('\n=== Test Complete ===');
}
