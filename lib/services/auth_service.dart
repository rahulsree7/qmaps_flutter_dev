import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://stageqmaps.aipopuli.com';

  //static const String baseUrl = 'http://127.0.0.1:8000';
  
  // Email/Password Login API
  static Future<Map<String, dynamic>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Debug - Login response data: $data');
        return {
          'success': true,
          'data': data,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Login failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Store user session after successful email/password login
  static Future<void> storeUserSession(Map<String, dynamic> userData) async {
    // Normalize: some APIs return { success, data: {...} } – store inner data
    final Map<String, dynamic> normalized =
        (userData['data'] is Map<String, dynamic>) ? Map<String, dynamic>.from(userData['data']) : userData;

    print('Debug - Storing normalized user data: $normalized');
    final prefs = await SharedPreferences.getInstance();
    
    // Check if there's a previous user stored
    final previousUserDataString = prefs.getString('userData');
    if (previousUserDataString != null) {
      try {
        final previousUserData = jsonDecode(previousUserDataString);
        final previousUserId = previousUserData['user']?['id'] ?? previousUserData['id'];
        final newUserId = normalized['user']?['id'] ?? normalized['id'];
        
        print('Debug - Previous user ID: $previousUserId');
        print('Debug - New user ID: $newUserId');
        
        // If different user, clear all previous user da ta including PIN
        if (previousUserId != null && newUserId != null && previousUserId != newUserId) {
          print('Debug - Different usehttps://www.facebook.com/share/17PfbZLN3x/?mibextid=wwXIfrr detected! Clearing previous user data and PIN');
          await clearAllData(); // Clear everything including PIN
        }
      } catch (e) {
        print('Debug - Error checking previous user: $e');
        // If we can't parse previous data, clear it to be safe
        await clearAllData();
      }
    }
    
    // Store new user session
    await prefs.setString('userData', jsonEncode(normalized));
    await prefs.setBool('isLoggedIn', true);
    await prefs.setBool('isFirstTimeLogin', true); // Mark as first time
    print('Debug - User session stored successfully');
  }

  // Mark PIN as set up
  static Future<void> markPinSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTimeLogin', false);
  }

  // Check if it's first time login
  static Future<bool> isFirstTimeLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstTimeLogin') ?? true;
  }

  // Store PIN
  static Future<void> storePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userPin', pin);
    
    // Also save PIN to database
    try {
      final userData = await getUserData();
      if (userData != null) {
        final token = await getAuthToken();
        if (token != null) {
          final response = await http.post(
            Uri.parse('$baseUrl/api/auth/save-pin'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pin': pin,
            }),
          );
          
          if (response.statusCode == 200) {
            print('Debug - PIN saved to database successfully');
          } else {
            print('Debug - Failed to save PIN to database: ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      print('Debug - Error saving PIN to database: $e');
    }
    
    print('Debug - PIN stored locally');
  }

  // Verify PIN and restore session if valid
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('userPin');
    
    print('Debug - verifyPin: Stored PIN exists: ${storedPin != null}');
    print('Debug - verifyPin: PIN match: ${storedPin == pin}');
    
    if (storedPin == pin) {
      // PIN is correct, restore the session
      await _restoreSessionAfterPinLogin();
      return true;
    }
    return false;
  }

  // Restore session after successful PIN login
  static Future<void> _restoreSessionAfterPinLogin() async {
    final prefs = await SharedPreferences.getInstance();
    
    print('Debug - Starting session restoration after PIN login');
    
    // Check if we have stored user data
    final userDataString = prefs.getString('userData');
    if (userDataString == null) {
      print('Debug - ❌ No stored user data found');
      await prefs.setBool('isLoggedIn', false);
      return;
    }
    
    try {
      final userData = jsonDecode(userDataString);
      print('Debug - User data found: ${userData.keys}');
      
      // Check if token exists
      final token = userData['token'];
      if (token == null) {
        print('Debug - ❌ No token in user data');
        await prefs.setBool('isLoggedIn', false);
        return;
      }
      
      print('Debug - Token found: ${token.toString().substring(0, min(20, token.toString().length))}...');
      
      // Check if token is expired based on stored expiry time
      final isExpired = await isTokenExpired();
      print('Debug - Token expired check: $isExpired');
      
      if (!isExpired) {
        // Token is not expired based on expiry time, just restore the session
        // We don't need to validate with server immediately after logout
        await prefs.setBool('isLoggedIn', true);
        print('Debug - ✅ Session restored after PIN login (token not expired)');
        return;
      } else {
        // Token is expired, try to refresh it
        print('Debug - Token expired, attempting to refresh...');
        final refreshed = await _refreshToken(userData);
        if (refreshed) {
          await prefs.setBool('isLoggedIn', true);
          print('Debug - ✅ Session restored with refreshed token');
          return;
        } else {
          print('Debug - ❌ Token refresh failed');
        }
      }
    } catch (e) {
      print('Debug - ❌ Error in session restoration: $e');
    }
    
    // If we reach here, we need to re-authenticate
    print('Debug - ❌ No valid session found, user needs to login again');
    await prefs.setBool('isLoggedIn', false);
  }

  // Attempt to refresh the token using the refresh endpoint
  static Future<bool> _refreshToken(Map<String, dynamic> userData) async {
    try {
      final token = userData['token'];
      if (token == null) {
        print('Debug - Token refresh: No token provided');
        return false;
      }
      
      print('Debug - Calling token refresh endpoint...');
      
      // Call the refresh token endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/refresh-token'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Debug - Token refresh response status: ${response.statusCode}');
      print('Debug - Token refresh response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update the token in stored user data
          final prefs = await SharedPreferences.getInstance();
          final updatedUserData = Map<String, dynamic>.from(userData);
          updatedUserData['token'] = data['data']['token'];
          updatedUserData['expires_at'] = data['data']['expires_at'];
          
          await prefs.setString('userData', jsonEncode(updatedUserData));
          print('Debug - ✅ Token refreshed successfully');
          print('Debug - New token: ${data['data']['token'].toString().substring(0, min(20, data['data']['token'].toString().length))}...');
          return true;
        } else {
          print('Debug - Token refresh response success=false: ${data['message']}');
        }
      } else {
        print('Debug - Token refresh failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Debug - ❌ Token refresh exception: $e');
    }
    
    return false;
  }

  // Validate token with server
  static Future<bool> _validateTokenWithServer(String token) async {
    try {
      print('Debug - Validating token with server...');
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      print('Debug - Token validation response status: ${response.statusCode}');
      print('Debug - Token validation response body: ${response.body}');
      
      final isValid = response.statusCode == 200;
      print('Debug - Token validation result: $isValid');
      return isValid;
    } catch (e) {
      print('Debug - ❌ Token validation exception: $e');
      return false;
    }
  }

  // Check if PIN is set
  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userPin') != null;
  }

  // Clear session data (logout) - but keep PIN and userData for future logins
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    // Don't remove userData - keep it for PIN login restoration
    // Don't remove userPin - keep it for future logins
    // Only set isLoggedIn to false for UI state, but keep session data intact
    await prefs.setBool('isLoggedIn', false);
    // Keep isFirstTimeLogin as false so user can use PIN next time
    await prefs.setBool('isFirstTimeLogin', false);
    print('Debug - Logout: UI state cleared but session data preserved for PIN login');
  }

  // Clear session when token expires - keep PIN but clear session
  static Future<void> clearExpiredSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.setBool('isLoggedIn', false);
    // Keep PIN and isFirstTimeLogin for PIN-based login
    print('Debug - Expired session cleared, PIN preserved for next login');
  }

  // Debug method to check all stored data
  static Future<void> debugStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    print('Debug - All stored keys: ${prefs.getKeys()}');
    print('Debug - isLoggedIn: ${prefs.getBool('isLoggedIn')}');
    print('Debug - isFirstTimeLogin: ${prefs.getBool('isFirstTimeLogin')}');
    print('Debug - userPin: ${prefs.getString('userPin')}');
    print('Debug - userData: ${prefs.getString('userData')}');
    
    // Additional debugging for PIN login flow
    final userData = await getUserData();
    if (userData != null) {
      print('Debug - Token: ${userData['token']?.toString().substring(0, 20)}...');
      print('Debug - Expires at: ${userData['expires_at']}');
      final isExpired = await isTokenExpired();
      print('Debug - Token expired: $isExpired');
    }
  }

  // Clear all session data completely (for testing)
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('Debug - All session data cleared completely');
  }

  // Complete logout - clear everything including PIN and userData
  static Future<void> completeLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('userPin');
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('isFirstTimeLogin', true);
    print('Debug - Complete logout - all data cleared');
  }

  // Get stored user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');
    print('Debug - Raw stored userData string: $userDataString');
    if (userDataString != null) {
      final decoded = jsonDecode(userDataString);
      print('Debug - Decoded userData: $decoded');
      return decoded;
    }
    return null;
  }

  // Helper: Retrieve auth token from stored user data (supports multiple shapes)
  static Future<String?> getAuthToken() async {
    final data = await getUserData();
    if (data == null) return null;
    if (data['token'] is String) return data['token'] as String; // normalized storage
    if (data['data'] is Map<String, dynamic> && data['data']['token'] is String) {
      return data['data']['token'] as String;
    }
    return null;
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // Check if token is expired
  static Future<bool> isTokenExpired() async {
    try {
      final userData = await getUserData();
      if (userData == null) return true;
      
      final expiresAt = userData['expires_at'];
      if (expiresAt == null) return true;
      
      final expiryDate = DateTime.parse(expiresAt);
      final now = DateTime.now();
      
      print('Debug - Token expires at: $expiryDate, Current time: $now');
      return now.isAfter(expiryDate);
    } catch (e) {
      print('Debug - Error checking token expiration: $e');
      return true;
    }
  }

  // Check if user has valid session (logged in and token not expired)
  static Future<bool> hasValidSession() async {
    final isLoggedInStatus = await isLoggedIn();
    if (!isLoggedInStatus) return false;
    
    final isExpired = await isTokenExpired();
    if (isExpired) {
      print('Debug - Token expired, clearing session but keeping PIN');
      await clearExpiredSession();
      return false;
    }
    
    return true;
  }

  // Check if user has valid session data (even if logged out locally)
  static Future<bool> hasValidSessionData() async {
    final userData = await getUserData();
    if (userData == null) return false;
    
    final isExpired = await isTokenExpired();
    if (isExpired) {
      print('Debug - Token expired in session data');
      return false;
    }
    
    return true;
  }

  // Fetch checklists
  static Future<Map<String, dynamic>> fetchChecklists() async {
    try {
      // Get token (supports both normalized and nested storage)
      final token = await getAuthToken();
      print('Debug - Using token: $token');
      
      if (token == null) {
        // Temporary: For testing, let's try to get a fresh token by logging in again
        print('Debug - No token found, attempting to get fresh token...');
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/auditor/checklists'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to load checklists',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Fetch users for ticket assignment
  static Future<Map<String, dynamic>> fetchUsersForTicket(int checklistId) async {
    try {
      final token = await getAuthToken();
      print('Debug - Using token: $token');
      
      if (token == null) {
        print('Debug - No token found, attempting to get fresh token...');
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      // Try the main endpoint first
      final response = await http.get(
        Uri.parse('$baseUrl/api/auditor/checklists/users?checklist_id=$checklistId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - Users response status: ${response.statusCode}');
      print('Debug - Users response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch users',
          };
        }
      } else if (response.statusCode == 404 || checklistId == 0) {
        // If checklist not found or using fallback, try fallback endpoint
        print('Debug - Checklist not found or using fallback, trying fallback endpoint...');
        return await _fetchUsersFallback(token);
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to fetch users',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Direct fallback method to fetch users without specific checklist
  static Future<Map<String, dynamic>> fetchUsersFallback() async {
    try {
      final token = await getAuthToken();
      print('Debug - Using token for fallback: $token');
      
      if (token == null) {
        print('Debug - No token found for fallback');
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      return await _fetchUsersFallback(token);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Fallback method to fetch users without specific checklist
  static Future<Map<String, dynamic>> _fetchUsersFallback(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auditor/checklists/users/fallback'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - Fallback response status: ${response.statusCode}');
      print('Debug - Fallback response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch users',
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to fetch users',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Fetch question details for ticket creation
  static Future<Map<String, dynamic>> fetchQuestionDetails(int questionId) async {
    try {
      final token = await getAuthToken();
      print('Debug - Using token for question details: $token');
      
      if (token == null) {
        print('Debug - No token found for question details');
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/auditor/checklists/question-details?question_id=$questionId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - Question details response status: ${response.statusCode}');
      print('Debug - Question details response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Failed to fetch question details',
          };
        }
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to fetch question details',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
