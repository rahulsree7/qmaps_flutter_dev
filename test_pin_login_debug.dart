import 'package:flutter/material.dart';
import 'package:qmaps_flutter/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('=== PIN Login Debug Test ===\n');
  
  // Test 1: Check stored data
  print('Test 1: Checking stored data...');
  await AuthService.debugStoredData();
  print('');
  
  // Test 2: Check if PIN is set
  print('Test 2: Checking if PIN is set...');
  final pinSet = await AuthService.isPinSet();
  print('PIN is set: $pinSet');
  print('');
  
  // Test 3: Check if user is logged in
  print('Test 3: Checking if user is logged in...');
  final isLoggedIn = await AuthService.isLoggedIn();
  print('Is logged in: $isLoggedIn');
  print('');
  
  // Test 4: Check if token is expired
  print('Test 4: Checking if token is expired...');
  final isExpired = await AuthService.isTokenExpired();
  print('Token expired: $isExpired');
  print('');
  
  // Test 5: Check if user has valid session
  print('Test 5: Checking if user has valid session...');
  final hasValidSession = await AuthService.hasValidSession();
  print('Has valid session: $hasValidSession');
  print('');
  
  // Test 6: Get user data
  print('Test 6: Getting user data...');
  final userData = await AuthService.getUserData();
  if (userData != null) {
    print('User ID: ${userData['user_id']}');
    print('Email: ${userData['email']}');
    print('Username: ${userData['username']}');
    print('Token: ${userData['token']?.toString().substring(0, 20)}...');
    print('Expires at: ${userData['expires_at']}');
  } else {
    print('No user data found');
  }
  print('');
  
  print('=== Test Complete ===');
}

