import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'create_ticket_dialog.dart';
import '../../theme/app_theme.dart';

class ChecklistDetailPage extends StatefulWidget {
  final int checklistId;
  final String checklistTitle;

  const ChecklistDetailPage({
    super.key,
    required this.checklistId,
    required this.checklistTitle,
  });

  @override
  State<ChecklistDetailPage> createState() => _ChecklistDetailPageState();
}

class _ChecklistDetailPageState extends State<ChecklistDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _checklistData;
  String? _error;
  Map<int, String?> _answers = {}; // question_id -> answer value
  Map<String, bool> _expandedGroups = {}; // group_id -> expanded state
  final ScrollController _scrollController = ScrollController();
  final Map<int, Timer?> _textSaveTimers = {}; // debounce timers per text question
  int _pendingSaveCount = 0; // Track pending saves
  final Map<int, TextEditingController> _textControllers = {}; // TextEditingController per text question
  
  // Score calculation
  double _calculateScore() {
    if (_checklistData == null) return 0.0;
    
    double totalPossibleScore = 0;
    double completedScore = 0;
    
    final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
    final theme = checklist?['theme'] as Map<String, dynamic>?;
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    final answersData = _checklistData!['answers'];
    
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        final questionId = questionData['id'] as int;
        final questionScore = (questionData['score'] as num?)?.toDouble() ?? 0.0;
        
        // Add to total possible score
        totalPossibleScore += questionScore;
        
        // Check if this question has been answered
        bool hasAnswer = false;
        
        // Check in pre-loaded answers
        if (answersData != null && answersData is Map) {
          final answers = answersData as Map<String, dynamic>;
          if (answers.containsKey(questionId.toString())) {
            final answer = answers[questionId.toString()];
            if (answer != null && answer is Map) {
              final value = answer['value'];
              if (value != null && value.toString().isNotEmpty) {
                hasAnswer = true;
              }
            }
          }
        }
        
        // Also check in current session answers
        if (!hasAnswer && _answers.containsKey(questionId)) {
          final value = _answers[questionId];
          if (value != null && value.isNotEmpty) {
            hasAnswer = true;
          }
        }
        
        // Check if question is locked (disabled) - locked questions count as completed
        bool isLocked = false;
        final isChecklistCompleted = _isChecklistCompleted();
        if (isChecklistCompleted) {
          // If checklist is completed, all questions are locked
          isLocked = true;
        } else {
          final ticketsData = _checklistData?['tickets'];
          if (ticketsData != null && ticketsData is Map) {
            final tickets = ticketsData as Map<String, dynamic>;
            if (tickets.containsKey(questionId.toString())) {
              final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
              final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
              final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
              final isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                                       ticketStatusTitle.toLowerCase().contains('complete') ||
                                       ticketStatusTitle.toLowerCase().contains('resolved') ||
                                       ticketStatusTitle.toLowerCase().contains('closed');
              // Question is locked if ticket exists and is not completed
              isLocked = !isTicketCompleted;
            }
          }
        }
        
        // Add to completed score if answered OR locked (locked = completed)
        if (hasAnswer || isLocked) {
          completedScore += questionScore;
        }
      }
    }
    
    // Calculate percentage
    if (totalPossibleScore > 0) {
      return (completedScore / totalPossibleScore) * 100;
    }
    
    return 0.0;
  }
  
  @override
  void initState() {
    super.initState();
    _loadChecklistDetail();
    _loadLocalAnswers(); // Load locally saved answers
  }
  
  /// Get checklist status from database (matching web logic)
  /// Returns the status title or null if not available
  String? _getChecklistStatus() {
    if (_checklistData == null) return null;
    final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
    final checklistStatus = checklist?['status'] as Map<String, dynamic>?;
    return checklistStatus?['title'] as String?;
  }
  
  /// Check if checklist is completed based on database status
  /// Matches web logic: only "Completed" status disables questions
  bool _isChecklistCompleted() {
    final statusTitle = _getChecklistStatus() ?? '';
    return statusTitle.toLowerCase().contains('completed') || 
           statusTitle.toLowerCase().contains('complete');
  }
  
  /// Load answers saved locally from SharedPreferences
  /// These override backend answers (unsaved changes take precedence)
  Future<void> _loadLocalAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'checklist_answers_${widget.checklistId}';
      final savedAnswersJson = prefs.getString(key);
      
      if (savedAnswersJson != null) {
        final savedAnswers = jsonDecode(savedAnswersJson) as Map<String, dynamic>;
        bool hasChanges = false;
        
        savedAnswers.forEach((key, value) {
          final questionId = int.tryParse(key);
          if (questionId != null && value != null) {
            final localAnswer = value as String?;
            // Check if local answer differs from what's in memory
            if (_answers[questionId] != localAnswer) {
              print('Debug - Restoring local answer for question $questionId: $localAnswer');
              _answers[questionId] = localAnswer;
              hasChanges = true;
            }
          }
        });
        
        // Trigger UI update if there were any changes
        if (hasChanges && mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Debug - Error loading local answers: $e');
    }
  }
  
  /// Save answers locally to SharedPreferences
  Future<void> _saveAnswersLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'checklist_answers_${widget.checklistId}';
      final answersMap = <String, String?>{};
      
      _answers.forEach((questionId, answer) {
        answersMap[questionId.toString()] = answer;
      });
      
      await prefs.setString(key, jsonEncode(answersMap));
      print('Debug - Saved answers locally for checklist ${widget.checklistId}');
    } catch (e) {
      print('Debug - Error saving local answers: $e');
    }
  }
  
  /// Clear locally saved answers (used when status becomes Active)
  Future<void> _clearLocalAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'checklist_answers_${widget.checklistId}';
      await prefs.remove(key);
      print('Debug - Cleared local answers for checklist ${widget.checklistId}');
    } catch (e) {
      print('Debug - Error clearing local answers: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    print('Debug - Dispose called, saving answers locally...');
    // Cancel any pending debounce timers FIRST before saving
    for (final timer in _textSaveTimers.values) {
      timer?.cancel();
    }
    _textSaveTimers.clear();
    
    // Dispose text controllers
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    
    // Save answers synchronously using a blocking approach
    _syncSaveAnswersLocally();
    
    print('Debug - Dispose completed');
    super.dispose();
  }
  
  /// Synchronous save to ensure completion before dispose
  void _syncSaveAnswersLocally() {
    try {
      print('Debug - Starting sync save of ${_answers.length} answers');
      SharedPreferences.getInstance().then((prefs) {
        final key = 'checklist_answers_${widget.checklistId}';
        final answersMap = <String, String?>{};
        
        _answers.forEach((questionId, answer) {
          print('Debug - Saving answer for question $questionId: $answer');
          answersMap[questionId.toString()] = answer;
        });
        
        prefs.setString(key, jsonEncode(answersMap)).then((_) {
          print('Debug - ✅ Successfully saved ${answersMap.length} answers locally for checklist ${widget.checklistId}');
        }).catchError((e) {
          print('Debug - ❌ Error saving answers: $e');
        });
      }).catchError((e) {
        print('Debug - ❌ Error getting SharedPreferences: $e');
      });
    } catch (e) {
      print('Debug - ❌ Sync save error: $e');
    }
  }

  Future<void> _loadChecklistDetail() async {
    print('Debug - _loadChecklistDetail started');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await AuthService.getUserData();
      if (userData == null || userData['token'] == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/auditor/checklists/${widget.checklistId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${userData['token']}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
            print('Debug - Backend loaded, current _answers before update: $_answers');
            print('Debug - Status data: ${data['data']['checklist']['status']}');
            print('Debug - Frequency data: ${data['data']['checklist']['frequency']}');
            setState(() {
              _checklistData = data['data'];
              _isLoading = false;
              
              // Check if status is Active
              final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
              final checklistStatus = checklist?['status'] as Map<String, dynamic>?;
              final statusTitle = checklistStatus?['title'] as String? ?? '';
              final isActive = statusTitle.toLowerCase().contains('active');
              
              if (isActive) {
                // If status is Active, clear all answers and input fields (ready for new input)
                print('Debug - Status is Active: Clearing all answers for fresh start');
                _answers.clear();
                _textControllers.forEach((key, controller) {
                  controller.clear();
                });
                // Clear local saved answers
                _clearLocalAnswers();
              } else {
                // Pre-fill existing answers from backend (matching web logic)
                if (_checklistData!['answers'] != null) {
                  final answersData = _checklistData!['answers'];
                  // Backend returns answers keyed by question_id (as Map/Object)
                  if (answersData is Map) {
                    final answers = answersData as Map<String, dynamic>;
                    print('Debug - Loading ${answers.length} answers from backend');
                    answers.forEach((key, answerObj) {
                      final questionId = int.tryParse(key);
                      if (questionId != null && answerObj != null) {
                        // Answer structure: { value: "...", score: ..., question_id: ..., ... }
                        // Match web logic: $answers[$question->id]->value ?? null
                        if (answerObj is Map) {
                          final answerValue = answerObj['value'];
                          // Use value as-is (no lowercase conversion) - matching web behavior
                          if (answerValue != null) {
                            print('Debug - Backend answer for question $questionId: $answerValue');
                            _answers[questionId] = answerValue.toString();
                            
                            // Update TextEditingController if it exists
                            if (_textControllers.containsKey(questionId)) {
                              _textControllers[questionId]?.text = answerValue.toString();
                            }
                          }
                        }
                      }
                    });
                  }
                  // If it's an array, it means no answers yet
                }
              }
              print('Debug - After backend load, _answers: $_answers');
            });
        } else {
          throw Exception(data['message'] ?? 'Failed to load checklist');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateTicketDialog(Map<String, dynamic> question) {
    if (_checklistData == null) return;

    print('Debug - _showCreateTicketDialog called with question: $question');
    print('Debug - Question ID: ${question['id']}');
    print('Debug - Question type: ${question.runtimeType}');

    final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
    final workspace = checklist?['workspace'] as Map<String, dynamic>?;
    final project = checklist?['project'] as Map<String, dynamic>?;
    final location = '${workspace?['title'] ?? ''} • ${project?['title'] ?? ''}'.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CreateTicketDialog(
        question: question,
        checklistData: _checklistData!,
        location: location,
        onCreateTicket: (ticketData) async {
          // Close the dialog
          Navigator.pop(context);
          
          // Save answer with ticket
          final questionId = question['id'] as int;
          await _saveAnswerWithTicket(questionId, 'no', ticketData);
        },
      ),
    );
  }

  Future<void> _saveAnswerWithTicket(int questionId, String value, Map<String, dynamic> ticketData) async {
    try {
      final userData = await AuthService.getUserData();
      if (userData == null || userData['token'] == null) {
        throw Exception('No authentication token found');
      }

      print('Debug - Saving answer with ticket: checklist=${widget.checklistId}, question=$questionId, value=$value');

      // Create multipart request for image upload
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/api/auditor/checklists/save-answer'),
      );

      // Add headers
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer ${userData['token']}',
      });

      // Add form fields
      request.fields['checklist_id'] = widget.checklistId.toString();
      request.fields['question_id'] = questionId.toString();
      request.fields['value'] = value;
      request.fields['create_ticket'] = '1';
      request.fields['note'] = ticketData['note'] as String? ?? '';

      // Set issue_created flag based on answer
      if (value.toLowerCase() == 'no') {
        request.fields['issue_created'] = '1';
      } else if (value.toLowerCase() == 'yes') {
        request.fields['issue_created'] = '0';
      }

      // Add priority and status
      if (ticketData['priority'] != null) {
        request.fields['priority'] = ticketData['priority'].toString();
      }
      if (ticketData['status'] != null) {
        request.fields['status'] = ticketData['status'].toString();
      }

      // Add internal and external users
      final internalUsers = ticketData['internal_users'] as List<int>? ?? [];
      final externalUsers = ticketData['external_users'] as List<int>? ?? [];
      
      for (int i = 0; i < internalUsers.length; i++) {
        request.fields['internal_users[$i]'] = internalUsers[i].toString();
      }
      for (int i = 0; i < externalUsers.length; i++) {
        request.fields['external_users[$i]'] = externalUsers[i].toString();
      }

      // Add images
      final images = ticketData['images'] as List<dynamic>? ?? [];
      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        if (image is XFile) {
          var file = await http.MultipartFile.fromPath(
            'images[$i]',
            image.path,
          );
          request.files.add(file);
        }
      }

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Debug - Save response status: ${response.statusCode}');
      print('Debug - Save response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ticket created successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Reload checklist detail to show ticket indicator
          await _loadChecklistDetail();
        } else {
          throw Exception(data['message'] ?? 'Failed to create ticket');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Debug - Error creating ticket: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveAnswer(int questionId, String value, {bool showSuccess = true}) async {
    try {
      _pendingSaveCount++;
      print('Debug - Pending saves increased to: $_pendingSaveCount');
      
      final userData = await AuthService.getUserData();
      if (userData == null || userData['token'] == null) {
        throw Exception('No authentication token found');
      }

      // Prepare the request body
      final body = <String, String>{
        'checklist_id': widget.checklistId.toString(),
        'question_id': questionId.toString(),
        'value': value,
      };

      // Set issue_created flag based on answer
      if (value.toLowerCase() == 'no') {
        body['issue_created'] = '1';
      } else if (value.toLowerCase() == 'yes') {
        body['issue_created'] = '0';
      }

      print('Debug - Saving answer: checklist=${widget.checklistId}, question=$questionId, value=$value');

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/api/auditor/checklists/save-answer'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${userData['token']}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      print('Debug - Save response status: ${response.statusCode}');
      print('Debug - Save response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save answer locally after successful backend save
          await _saveAnswersLocally();
          
          // Check if checklist was completed
          final checklistCompleted = data['data']?['checklist_completed'] == true;
          
          if (mounted && showSuccess) {
            if (checklistCompleted) {
              // Show completion message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All questions answered! Checklist marked as completed.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  duration: const Duration(seconds: 4),
                ),
              );
              
              // Navigate back to checklist list after a delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            } else {
              // Regular success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Answer saved successfully'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              
              // Update UI to recalculate score
              setState(() {});
            }
          }
          
          // If ticket was created, refresh the page to show ticket indicator
          if (data['data']?['ticket_created'] == true) {
            _loadChecklistDetail();
          } else {
            // Update UI to recalculate score
            setState(() {});
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to save answer');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Debug - Error saving answer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _pendingSaveCount--;
      print('Debug - Pending saves decreased to: $_pendingSaveCount');
    }
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionId = question['id'] as int;
    final questionText = question['question'] as String? ?? 'No question text';
    // Backend uses `field_type` for the input control type (e.g., 'text', 'checkbox', 'yes_no')
    final questionType = question['field_type'] as String? ?? 'radio';
    final questionOptions = question['options'] as String? ?? 'Yes,No';
    final priority = question['priority'];
    final priorityTitle = priority?['title'] as String? ?? 'medium';
    
    // Determine if question has a ticket and check its status
    // Backend can return either array [] or object {}
    bool hasTicket = false;
    bool isTicketCompleted = false;
    final ticketsData = _checklistData?['tickets'];
    if (ticketsData != null && ticketsData is Map) {
      final tickets = ticketsData as Map<String, dynamic>;
      hasTicket = tickets.containsKey(questionId.toString());
      
      // If ticket exists, check its status
      if (hasTicket) {
        final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
        final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
        final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
        isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                           ticketStatusTitle.toLowerCase().contains('complete') ||
                           ticketStatusTitle.toLowerCase().contains('resolved') ||
                           ticketStatusTitle.toLowerCase().contains('closed');
      }
    }
    
    // Check if checklist is completed (using helper method - matching web logic)
    final statusTitle = _getChecklistStatus() ?? '';
    final isChecklistCompleted = _isChecklistCompleted();
    final isActive = statusTitle.toLowerCase().contains('active');
    
    // Debug logging
    print('Debug - Checklist status check:');
    print('  - statusTitle: $statusTitle');
    print('  - isChecklistCompleted: $isChecklistCompleted');
    print('  - isActive: $isActive');
    print('  - hasTicket: $hasTicket');
    print('  - isTicketCompleted: $isTicketCompleted');
    
    // Question should be disabled if:
    // 1. Checklist status is "Completed" (matching web logic), OR
    // 2. Has a ticket AND ticket is not completed
    // IMPORTANT: If status is "Active", all inputs must be enabled (ready for input)
    // unless there's an incomplete ticket for this specific question
    bool shouldDisable;
    if (isActive) {
      // If status is Active, only disable if there's an incomplete ticket
      shouldDisable = hasTicket && !isTicketCompleted;
      print('  - Active status: inputs enabled (unless incomplete ticket)');
    } else {
      // For other statuses, disable if completed OR has incomplete ticket
      shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    }
    
    print('  - shouldDisable: $shouldDisable');
    
    Color priorityColor;
    switch (priorityTitle.toLowerCase()) {
      case 'high':
        priorityColor = const Color(0xFFE53E3E); // Red
        break;
      case 'medium':
        priorityColor = const Color(0xFFDD6B20); // Orange
        break;
      default:
        priorityColor = const Color(0xFF3182CE); // Blue
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header with step number and priority
            Row(
              children: [
                // Step number with gradient
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        priorityColor,
                        priorityColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: priorityColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Priority badge with modern styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        priorityColor.withOpacity(0.15),
                        priorityColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: priorityColor.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    priorityTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 18),
            
            // Question text with score percentage (matching web layout)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A202C),
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Score percentage badge (matching web)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(question['score'] as num?)?.toDouble() ?? 0.0}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Answer options based on question type
            if (questionType == 'radio' || questionType == 'yes_no')
              _buildDynamicOptions(questionId, questionOptions, shouldDisable, question)
            else if (questionType == 'checkbox')
              _buildCheckboxOptions(questionId, question)
            else if (questionType == 'text' || questionType == 'textarea')
              _buildTextInput(questionId, questionType)
            else
              _buildDynamicOptions(questionId, questionOptions, shouldDisable, question),
            
            // Show completion status if checklist is completed
            if (isChecklistCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Completed',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

            // Show disabled message if question is disabled
            if (shouldDisable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isChecklistCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isChecklistCompleted ? Colors.green.shade200 : Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChecklistCompleted ? Icons.check_circle_outline : Icons.lock_outline,
                      color: isChecklistCompleted ? Colors.green.shade600 : Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isChecklistCompleted 
                          ? 'This checklist has been completed. All questions are locked.'
                          : 'This question is locked because a ticket has been created. Contact your administrator to modify.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isChecklistCompleted ? Colors.green.shade700 : Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicOptions(int questionId, String optionsString, bool disabled, Map<String, dynamic> question) {
    // Parse comma-separated options
    final options = optionsString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    // Check if this is a Yes/No question for toggle switch
    final isYesNoQuestion = options.length == 2 && 
                           options.any((o) => o.toLowerCase() == 'yes') && 
                           options.any((o) => o.toLowerCase() == 'no');
    
    if (isYesNoQuestion) {
      // Use separate toggle buttons for Yes/No questions
      // Match web logic: compare case-insensitively but store as-is
      final currentAnswer = _answers[questionId]?.toString().trim().toLowerCase();
      final isYesSelected = currentAnswer == 'yes';
      final isNoSelected = currentAnswer == 'no';
      
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // YES Toggle Switch
          GestureDetector(
            onTap: disabled ? null : () async {
              // Toggle: if already selected, deselect it
              // Match web logic: store trimmed option value (not lowercase)
              final yesOption = options.firstWhere((o) => o.trim().toLowerCase() == 'yes', orElse: () => 'yes');
              final newAnswer = isYesSelected ? null : yesOption.trim();
              setState(() {
                if (newAnswer == null) {
                  _answers.remove(questionId);
                } else {
                  _answers[questionId] = newAnswer;
                }
              });
              
              if (newAnswer != null) {
                await _scrollToNextQuestion(questionId);
                _saveAnswer(questionId, newAnswer);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 90,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isYesSelected && !disabled
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      )
                    : null,
                color: !isYesSelected
                    ? (disabled ? Colors.grey.shade300 : Colors.grey.shade200)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // YES Label (positioned to avoid knob)
                  Positioned.fill(
                    child: Align(
                      alignment: isYesSelected ? Alignment.centerLeft : Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'YES',
                          style: TextStyle(
                            color: isYesSelected && !disabled
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Sliding Knob with checkmark
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: isYesSelected ? 90 - 36 : 3,
                    top: 3,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isYesSelected
                          ? const Icon(
                              Icons.check,
                              color: Color(0xFF10B981),
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 16),
          
          // NO Toggle Switch
          GestureDetector(
            onTap: disabled ? null : () async {
              // Toggle: if already selected, deselect it
              // Match web logic: store trimmed option value (not lowercase)
              final noOption = options.firstWhere((o) => o.trim().toLowerCase() == 'no', orElse: () => 'no');
              final newAnswer = isNoSelected ? null : noOption.trim();
              setState(() {
                if (newAnswer == null) {
                  _answers.remove(questionId);
                } else {
                  _answers[questionId] = newAnswer;
                }
              });
              
              if (newAnswer != null && newAnswer.trim().toLowerCase() == 'no') {
                await _scrollToNextQuestion(questionId);
                print('Debug - "No" selected for question: $questionId');
                print('Debug - Question data: $question');
                _showCreateTicketDialog(question);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 90,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: isNoSelected && !disabled
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      )
                    : null,
                color: !isNoSelected
                    ? (disabled ? Colors.grey.shade300 : Colors.grey.shade200)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // NO Label (positioned to avoid knob)
                  Positioned.fill(
                    child: Align(
                      alignment: isNoSelected ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          'NO',
                          style: TextStyle(
                            color: isNoSelected && !disabled
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Sliding Knob with checkmark
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: isNoSelected ? 3 : 90 - 36,
                    top: 3,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isNoSelected
                          ? const Icon(
                              Icons.close,
                              color: Color(0xFFEF4444),
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    
    // For other options, use the original button layout
    // Match web logic: compare case-insensitively, store trimmed value
    return Row(
      children: options.map((option) {
        final trimmedOption = option.trim();
        final currentAnswer = _answers[questionId]?.toString().trim();
        // Case-insensitive comparison (matching web: $answer == trim($opt))
        final isSelected = currentAnswer != null && 
                          currentAnswer.toLowerCase() == trimmedOption.toLowerCase();
        
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option != options.last ? 8 : 0,
            ),
            child: InkWell(
              onTap: disabled ? null : () async {
                // Store trimmed option value (matching web logic)
                setState(() {
                  _answers[questionId] = trimmedOption;
                });
                
                await _scrollToNextQuestion(questionId);
                
                if (trimmedOption.toLowerCase() == 'no') {
                  print('Debug - "No" selected for question (row): $questionId');
                  print('Debug - Question data (row): $question');
                  _showCreateTicketDialog(question);
                } else {
                  _saveAnswer(questionId, trimmedOption);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? (disabled ? Colors.grey.shade200 : const Color(0xFF3B82F6).withOpacity(0.1))
                      : (disabled ? Colors.grey.shade100 : Colors.grey.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                      ? (disabled ? Colors.grey : const Color(0xFF3B82F6))
                      : (disabled ? Colors.grey.shade300 : Colors.grey.shade300),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: disabled ? Colors.grey.shade600 : const Color(0xFF3B82F6),
                      ),
                    if (isSelected) const SizedBox(width: 8),
                    Text(
                      option,
                      style: TextStyle(
                        color: disabled 
                          ? Colors.grey.shade600 
                          : (isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade700),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Smooth scrolling effect when selecting options
  Future<void> _scrollToNextQuestion(int currentQuestionId) async {
    if (!_scrollController.hasClients) return;
    
    // Find the current question's position in the list
    final checklist = _checklistData?['checklist'] as Map<String, dynamic>?;
    final theme = checklist?['theme'] as Map<String, dynamic>?;
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    
    int currentQuestionIndex = -1;
    int totalQuestions = 0;
    
    // Find the current question index
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        final questionId = questionData['id'] as int;
        
        if (questionId == currentQuestionId) {
          currentQuestionIndex = totalQuestions;
          break;
        }
        totalQuestions++;
      }
      
      if (currentQuestionIndex != -1) break;
    }
    
    // If we found the current question and there's a next question
    if (currentQuestionIndex != -1 && currentQuestionIndex < totalQuestions - 1) {
      // Calculate scroll position for the next question
      // Each question card is approximately 200px in height
      final double questionHeight = 200.0;
      final double scrollOffset = (currentQuestionIndex + 1) * questionHeight;
      
      // Smooth scroll to the next question
      await _scrollController.animateTo(
        scrollOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildCheckboxOptions(int questionId, Map<String, dynamic> question) {
    // Check if question should be disabled
    bool hasTicket = false;
    bool isTicketCompleted = false;
    final ticketsData = _checklistData?['tickets'];
    if (ticketsData != null && ticketsData is Map) {
      final tickets = ticketsData as Map<String, dynamic>;
      hasTicket = tickets.containsKey(questionId.toString());
      
      // If ticket exists, check its status
      if (hasTicket) {
        final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
        final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
        final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
        isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                           ticketStatusTitle.toLowerCase().contains('complete') ||
                           ticketStatusTitle.toLowerCase().contains('resolved') ||
                           ticketStatusTitle.toLowerCase().contains('closed');
      }
    }
    
    // Use helper method for consistent status checking
    final statusTitle = _getChecklistStatus() ?? '';
    final isChecklistCompleted = _isChecklistCompleted();
    final isActive = statusTitle.toLowerCase().contains('active');
    
    // If status is Active, only disable if there's an incomplete ticket
    // Otherwise, disable if completed OR has incomplete ticket
    bool shouldDisable;
    if (isActive) {
      shouldDisable = hasTicket && !isTicketCompleted;
    } else {
      shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    }
    
    // Parse options from question data
    final optionsString = question['options'] as String? ?? '';
    final options = optionsString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    // If no options defined, fallback to text input
    if (options.isEmpty) {
      return TextField(
        enabled: !shouldDisable,
        decoration: InputDecoration(
          labelText: 'Answer',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onChanged: (value) {
          setState(() {
            // Store value as-is (trimmed) - matching web logic
            _answers[questionId] = value?.trim();
          });
        },
        onSubmitted: (value) {
          _saveAnswer(questionId, value.trim());
        },
      );
    }
    
    // Parse selected values (comma-separated string stored in _answers)
    // Match web logic: store trimmed values, compare case-insensitively
    final answerString = _answers[questionId]?.toString() ?? '';
    final selectedValuesList = answerString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final selectedValuesSet = selectedValuesList.map((e) => e.toLowerCase()).toSet();
    
    return Column(
      children: options.map((option) {
        final trimmedOption = option.trim();
        // Case-insensitive comparison (matching web logic)
        final isSelected = selectedValuesSet.contains(trimmedOption.toLowerCase());
        
        return CheckboxListTile(
          title: Text(
            option,
            style: TextStyle(
              color: shouldDisable ? Colors.grey[500] : null,
              fontSize: 14,
            ),
          ),
          value: isSelected,
          onChanged: shouldDisable ? null : (checked) {
            setState(() {
              final currentValues = List<String>.from(selectedValuesList);
              if (checked == true) {
                // Add trimmed option if not already present
                if (!currentValues.any((v) => v.toLowerCase() == trimmedOption.toLowerCase())) {
                  currentValues.add(trimmedOption);
                }
              } else {
                // Remove option (case-insensitive)
                currentValues.removeWhere((v) => v.toLowerCase() == trimmedOption.toLowerCase());
              }
              // Store as comma-separated string (matching web: implode(',', $processedValue))
              _answers[questionId] = currentValues.join(',');
            });
            // Save answer after checkbox change
            final currentValues = List<String>.from(selectedValuesList);
            if (checked == true) {
              if (!currentValues.any((v) => v.toLowerCase() == trimmedOption.toLowerCase())) {
                currentValues.add(trimmedOption);
              }
            } else {
              currentValues.removeWhere((v) => v.toLowerCase() == trimmedOption.toLowerCase());
            }
            _saveAnswer(questionId, currentValues.join(','));
          },
          activeColor: shouldDisable ? Colors.grey : const Color(0xFF8B5CF6),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(int questionId, String questionType) {
    // Check if question should be disabled
    bool hasTicket = false;
    bool isTicketCompleted = false;
    final ticketsData = _checklistData?['tickets'];
    if (ticketsData != null && ticketsData is Map) {
      final tickets = ticketsData as Map<String, dynamic>;
      hasTicket = tickets.containsKey(questionId.toString());
      
      // If ticket exists, check its status
      if (hasTicket) {
        final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
        final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
        final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
        isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                           ticketStatusTitle.toLowerCase().contains('complete') ||
                           ticketStatusTitle.toLowerCase().contains('resolved') ||
                           ticketStatusTitle.toLowerCase().contains('closed');
      }
    }
    
    // Use helper method for consistent status checking
    final statusTitle = _getChecklistStatus() ?? '';
    final isChecklistCompleted = _isChecklistCompleted();
    final isActive = statusTitle.toLowerCase().contains('active');
    
    // If status is Active, only disable if there's an incomplete ticket
    // Otherwise, disable if completed OR has incomplete ticket
    bool shouldDisable;
    if (isActive) {
      shouldDisable = hasTicket && !isTicketCompleted;
    } else {
      shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    }
    
    // Create or reuse TextEditingController for this question
    if (!_textControllers.containsKey(questionId)) {
      _textControllers[questionId] = TextEditingController(
        text: _answers[questionId] ?? '',
      );
      print('Debug - Created TextEditingController for question $questionId with initial value: "${_answers[questionId]}"');
    }
    
    // Matching web layout: Text field with save button on the right (no label above field)
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text field (left side, takes most space) - matching web's form-control styling
        Expanded(
          child: TextField(
            controller: _textControllers[questionId],
            enabled: !shouldDisable,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Color(0xFF374151),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: null, // No hint text in web view
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: questionType == 'textarea' ? 4 : 1,
            minLines: questionType == 'textarea' ? 3 : 1,
            onChanged: (value) {
              print('Debug - Text changed for question $questionId: "$value"');
              _answers[questionId] = value;
              // Debounce save to avoid excessive requests while typing
              _textSaveTimers[questionId]?.cancel();
              _textSaveTimers[questionId] = Timer(const Duration(milliseconds: 500), () {
                print('Debug - Debounce timer fired for question $questionId, saving: "${_answers[questionId]}"');
                _saveAnswer(questionId, _answers[questionId] ?? '', showSuccess: false);
              });
            },
            onSubmitted: (value) {
              // Immediate save when user submits from keyboard
              print('Debug - Text submitted for question $questionId: "$value"');
              _textSaveTimers[questionId]?.cancel();
              _saveAnswer(questionId, value, showSuccess: false);
            },
          ),
        ),
        // Save button (right side, matching web) - matching web's manual-save-btn styling
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: shouldDisable ? null : () {
              // Manual save button (matching web behavior)
              _textSaveTimers[questionId]?.cancel();
              final value = _textControllers[questionId]?.text ?? '';
              _answers[questionId] = value;
              _saveAnswer(questionId, value, showSuccess: true);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: shouldDisable 
                    ? Colors.grey.shade200 
                    : const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: shouldDisable 
                      ? Colors.grey.shade300 
                      : const Color(0xFF3B82F6),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.save_rounded,
                size: 18,
                color: shouldDisable ? Colors.grey.shade500 : Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsHeader() {
    if (_checklistData == null) return const SizedBox.shrink();
    
    final checklist = _checklistData!['checklist'] as Map<String, dynamic>;
    final project = checklist['project'] as Map<String, dynamic>?;
    final workspace = checklist['workspace'] as Map<String, dynamic>?;
    final theme = checklist['theme'] as Map<String, dynamic>?;
    final status = checklist['status'] as Map<String, dynamic>?;
    final frequency = checklist['frequency'] as Map<String, dynamic>?;
    
    final location = '${project?['title'] ?? ''}'.trim();
    final checklistTheme = theme?['title'] ?? 'N/A';
    final frequencyTitle = frequency?['title'] ?? 'N/A';
    final score = _calculateScore();
    
    // Use helper method to get status (matching web logic: $checklist->status->title)
    final statusTitle = _getChecklistStatus() ?? 'N/A';
    String displayStatus = statusTitle;
    Color statusColor;
    
    // Color coding based on database status (matching web)
    final statusLower = statusTitle.toLowerCase();
    if (statusLower.contains('completed') || statusLower.contains('complete')) {
      statusColor = const Color(0xFF10B981); // Green
    } else if (statusLower.contains('active')) {
      statusColor = const Color(0xFF3B82F6); // Blue
    } else if (statusLower.contains('progress')) {
      statusColor = const Color(0xFF3B82F6); // Blue
    } else {
      statusColor = Colors.grey;
    }
    
    // Calculate progress (including locked questions as completed)
    int totalQuestions = 0;
    int answeredQuestions = 0;
    
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    final answersData = _checklistData!['answers'];
    final ticketsData = _checklistData?['tickets'];
    final isChecklistCompleted = _isChecklistCompleted();
    
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      totalQuestions += questions.length;
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        final questionId = questionData['id'] as int;
        
        // Check if question has an answer
        bool hasAnswer = false;
        if (answersData != null && answersData is Map) {
          final answers = answersData as Map<String, dynamic>;
          if (answers.containsKey(questionId.toString())) {
            hasAnswer = true;
          }
        }
        if (!hasAnswer && _answers.containsKey(questionId)) {
          hasAnswer = true;
        }
        
        // Check if question is locked (disabled)
        bool isLocked = false;
        if (isChecklistCompleted) {
          // If checklist is completed, all questions are locked
          isLocked = true;
        } else if (ticketsData != null && ticketsData is Map) {
          final tickets = ticketsData as Map<String, dynamic>;
          if (tickets.containsKey(questionId.toString())) {
            final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
            final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
            final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
            final isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                                     ticketStatusTitle.toLowerCase().contains('complete') ||
                                     ticketStatusTitle.toLowerCase().contains('resolved') ||
                                     ticketStatusTitle.toLowerCase().contains('closed');
            // Question is locked if ticket exists and is not completed
            isLocked = !isTicketCompleted;
          }
        }
        
        // Count as answered if it has an answer OR is locked (locked = completed)
        if (hasAnswer || isLocked) {
          answeredQuestions++;
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // First row: Location, Theme, Status
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Location', location, Icons.location_on_outlined),
              ),
              Expanded(
                child: _buildDetailItem('Checklist Theme', checklistTheme, Icons.assignment_outlined),
              ),
              Expanded(
                child: _buildDetailItem('Status', displayStatus, Icons.info_outline, valueColor: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Progress, Score, Frequency
          Row(
            children: [
              Expanded(
                child: _buildProgressItem(
                  answeredQuestions,
                  totalQuestions,
                  isActive: statusLower.contains('active'),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Score',
                  '${score.toStringAsFixed(0)}/100(%)',
                  Icons.star_rounded,
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: _buildDetailItem('Frequency', frequencyTitle, Icons.schedule_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? Colors.black87,
            letterSpacing: -0.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
  
  Widget _buildProgressItem(int answeredQuestions, int totalQuestions, {required bool isActive}) {
    final progress = totalQuestions > 0 ? answeredQuestions / totalQuestions : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$answeredQuestions/$totalQuestions',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10B981),
            letterSpacing: -0.2,
          ),
        ),
        // Show progress bar when status is Active
        if (isActive) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)), // Blue for Active
              minHeight: 6,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuestionsSection() {
    if (_checklistData == null) return const SizedBox.shrink();

    final checklist = _checklistData!['checklist'] as Map<String, dynamic>;
    final theme = checklist['theme'] as Map<String, dynamic>?;
    
    if (theme == null) {
      return const Center(
        child: Text('No theme found for this checklist'),
      );
    }

    final groups = theme['groups'] as List<dynamic>? ?? [];
    
    if (groups.isEmpty) {
      return const Center(
        child: Text('No question groups found'),
      );
    }

    List<Widget> groupWidgets = [];
    int globalQuestionIndex = 0;

    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final groupId = groupData['id']?.toString() ?? groupData['title'] ?? 'group_$globalQuestionIndex';
      final groupTitle = groupData['title'] as String? ?? 'Untitled Group';
      final questions = groupData['questions'] as List<dynamic>? ?? [];

      if (questions.isNotEmpty) {
        // Calculate progress for this group (including locked questions as completed)
        int answeredInGroup = 0;
        int totalInGroup = questions.length;
        final ticketsData = _checklistData?['tickets'];
        final isChecklistCompleted = _isChecklistCompleted();
        
        for (var question in questions) {
          final questionData = question as Map<String, dynamic>;
          final questionId = questionData['id'] as int;
          
          // Check if question has an answer
          bool hasAnswer = false;
          final answersData = _checklistData!['answers'];
          if (answersData != null && answersData is Map) {
            final answers = answersData as Map<String, dynamic>;
            if (answers.containsKey(questionId.toString())) {
              hasAnswer = true;
            }
          }
          if (!hasAnswer && _answers.containsKey(questionId)) {
            hasAnswer = true;
          }
          
          // Check if question is locked (disabled)
          bool isLocked = false;
          if (isChecklistCompleted) {
            // If checklist is completed, all questions are locked
            isLocked = true;
          } else if (ticketsData != null && ticketsData is Map) {
            final tickets = ticketsData as Map<String, dynamic>;
            if (tickets.containsKey(questionId.toString())) {
              final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
              final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
              final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
              final isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                                       ticketStatusTitle.toLowerCase().contains('complete') ||
                                       ticketStatusTitle.toLowerCase().contains('resolved') ||
                                       ticketStatusTitle.toLowerCase().contains('closed');
              // Question is locked if ticket exists and is not completed
              isLocked = !isTicketCompleted;
            }
          }
          
          // Count as answered if it has an answer OR is locked (locked = completed)
          if (hasAnswer || isLocked) {
            answeredInGroup++;
          }
        }

        // Initialize expanded state for new groups
        if (!_expandedGroups.containsKey(groupId)) {
          // Collapse if completed, expand if in progress
          _expandedGroups[groupId] = answeredInGroup < totalInGroup;
        }

        groupWidgets.add(
          _buildGroupCard(
            groupId: groupId,
            groupTitle: groupTitle,
            questions: questions,
            startIndex: globalQuestionIndex,
            answeredCount: answeredInGroup,
            totalCount: totalInGroup,
          ),
        );

        globalQuestionIndex += questions.length;
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      children: groupWidgets,
    );
  }
  
  Widget _buildGroupCard({
    required String groupId,
    required String groupTitle,
    required List<dynamic> questions,
    required int startIndex,
    required int answeredCount,
    required int totalCount,
  }) {
    final isExpanded = _expandedGroups[groupId] ?? true;
    final progress = totalCount > 0 ? answeredCount / totalCount : 0.0;
    final isComplete = answeredCount == totalCount;
    final isInProgress = answeredCount > 0 && answeredCount < totalCount;
    
    // Determine colors based on status
    Color accentColor;
    Color lightAccentColor;
    Color borderColor;
    
    if (isComplete) {
      // Green for completed
      accentColor = const Color(0xFF10B981);
      lightAccentColor = const Color(0xFF10B981).withOpacity(0.1);
      borderColor = const Color(0xFF10B981).withOpacity(0.2);
    } else if (isInProgress) {
      // Orange for in progress
      accentColor = const Color(0xFFF59E0B);
      lightAccentColor = const Color(0xFFF59E0B).withOpacity(0.1);
      borderColor = const Color(0xFFF59E0B).withOpacity(0.2);
    } else {
      // Blue for not started
      accentColor = const Color(0xFF3B82F6);
      lightAccentColor = const Color(0xFF3B82F6).withOpacity(0.1);
      borderColor = Colors.grey.withOpacity(0.1);
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: lightAccentColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedGroups[groupId] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Group Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Group Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalCount ${totalCount == 1 ? 'Question' : 'Questions'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Progress Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isComplete 
                                ? Icons.check_circle_rounded
                                : isInProgress
                                  ? Icons.hourglass_bottom_rounded
                                  : Icons.pending_actions_rounded,
                              color: accentColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$answeredCount/$totalCount',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // Expand/Collapse Icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: accentColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  
                  // Progress Bar
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Accordion Content (Questions)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  for (int i = 0; i < questions.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i < questions.length - 1 ? 12 : 0,
                      ),
                      child: _buildQuestionCard(
                        questions[i] as Map<String, dynamic>,
                        startIndex + i,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            _buildCustomHeader(context),
            // Body content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading checklist',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadChecklistDetail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryPurple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _buildDetailsHeader(),
                            Expanded(
                              child: _buildQuestionsSection(),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Theme.of(context).colorScheme.background,
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Text(
              widget.checklistTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

