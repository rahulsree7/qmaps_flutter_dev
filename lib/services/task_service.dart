import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class TaskService {
  static const String baseUrl = AuthService.baseUrl;

  // Get authentication token
  static Future<String?> _getToken() async {
    // Use AuthService to get the token (it handles token storage correctly)
    return await AuthService.getAuthToken();
  }

  // Get location/project details by ID (for QR code scanning)
  static Future<Map<String, dynamic>> getLocation(int locationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks/location/$locationId'),
        headers: {
          'Content-Type': 'application/json',
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
      } else if (response.statusCode == 401) {
        // Unauthorized - token might be expired
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to fetch location',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get form data for creating a task (statuses, priorities, users)
  static Future<Map<String, dynamic>> getCreateData(int locationId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('Debug - TaskService.getCreateData: Fetching data for location $locationId');
      print('Debug - TaskService.getCreateData: Using token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks/create-data/$locationId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - TaskService.getCreateData: Response status: ${response.statusCode}');
      print('Debug - TaskService.getCreateData: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Debug - TaskService.getCreateData: Parsed data keys: ${data.keys.toList()}');
        if (data['data'] != null) {
          print('Debug - TaskService.getCreateData: Response data keys: ${(data['data'] as Map).keys.toList()}');
        }
        return {
          'success': true,
          'data': data['data'],
        };
      } else if (response.statusCode == 401) {
        // Unauthorized - token might be expired
        print('Debug - TaskService.getCreateData: 401 Unauthorized');
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.',
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          print('Debug - TaskService.getCreateData: Error response: $error');
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to fetch form data',
          };
        } catch (e) {
          print('Debug - TaskService.getCreateData: Could not parse error response');
          return {
            'success': false,
            'message': 'Failed to fetch form data (HTTP ${response.statusCode})',
          };
        }
      }
    } catch (e) {
      print('Debug - TaskService.getCreateData: Exception: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get all tasks assigned to the user
  static Future<Map<String, dynamic>> getUserTasks() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('Debug - TaskService.getUserTasks: Fetching user tasks');

      final response = await http.get(
        Uri.parse('$baseUrl/api/user/tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - TaskService.getUserTasks: Response status: ${response.statusCode}');
      print('Debug - TaskService.getUserTasks: Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Debug - TaskService.getUserTasks: Tasks count: ${data['count']}');
        return {
          'success': true,
          'data': data['data'] ?? [],
          'count': data['count'] ?? 0,
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.',
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to fetch tasks',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to fetch tasks (HTTP ${response.statusCode})',
          };
        }
      }
    } catch (e) {
      print('Debug - TaskService.getUserTasks: Exception: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Get task details by ID
  static Future<Map<String, dynamic>> getTaskDetails(int taskId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      print('Debug - TaskService.getTaskDetails: Fetching task $taskId');

      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks/$taskId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Debug - TaskService.getTaskDetails: Response status: ${response.statusCode}');
      print('Debug - TaskService.getTaskDetails: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else if (response.statusCode == 401) {
        // Unauthorized - token might be expired
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Task not found',
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          return {
            'success': false,
            'message': error['message'] ?? 'Failed to fetch task',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Failed to fetch task (HTTP ${response.statusCode})',
          };
        }
      }
    } catch (e) {
      print('Debug - TaskService.getTaskDetails: Exception: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // Create a new task
  static Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Not authenticated',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks/store'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Task created successfully',
          'data': data['data'],
        };
      } else if (response.statusCode == 401) {
        // Unauthorized - token might be expired
        return {
          'success': false,
          'message': 'Not authenticated. Please login again.',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to create task',
          'errors': error['errors'],
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

