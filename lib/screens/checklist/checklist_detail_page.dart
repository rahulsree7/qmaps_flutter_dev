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
  bool _isScrolled = false; // Track scroll position for collapsed header
  
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
        
        // Check if question is locked (only when ticket is created, not based on completion)
        bool isLocked = false;
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
        
        // Add to completed score ONLY if answered (matching backend logic)
        // Locked questions don't count unless they also have answers
        if (hasAnswer) {
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
    
    // Add scroll listener to detect scrolling
    _scrollController.addListener(() {
      final isScrolled = _scrollController.offset > 50;
      if (isScrolled != _isScrolled) {
        setState(() {
          _isScrolled = isScrolled;
        });
      }
    });
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
  
  /// Get question data by question ID
  Map<String, dynamic>? _getQuestionData(int questionId) {
    if (_checklistData == null) return null;
    
    final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
    final theme = checklist?['theme'] as Map<String, dynamic>?;
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        if (questionData['id'] == questionId) {
          return questionData;
        }
      }
    }
    
    return null;
  }
  
  /// Get question score by question ID
  double? _getQuestionScore(int questionId) {
    final questionData = _getQuestionData(questionId);
    if (questionData != null) {
      return (questionData['score'] as num?)?.toDouble();
    }
    return null;
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
              
              // Check status from backend to determine if we should clear answers
              final checklist = _checklistData!['checklist'] as Map<String, dynamic>?;
              final theme = checklist?['theme'] as Map<String, dynamic>?;
                final answersData = _checklistData!['answers'];
              
              // Calculate progress to determine status (matching list page logic)
              int totalQuestions = 0;
              int answeredCount = 0;
              
              final groups = theme?['groups'] as List<dynamic>? ?? [];
              for (var group in groups) {
                final questions = group['questions'] as List<dynamic>? ?? [];
                totalQuestions += questions.length;
                
                if (answersData != null && answersData is Map) {
                  for (var question in questions) {
                    final questionId = question['id'] as int?;
                    if (questionId != null) {
                      final answerObj = answersData[questionId.toString()];
                      if (answerObj != null && answerObj is Map) {
                        final answerValue = answerObj['value'];
                        if (answerValue != null && answerValue.toString().trim().isNotEmpty) {
                          answeredCount++;
                        }
                      }
                    }
                  }
                }
              }
              
              // Determine status based on progress
              final isNotStarted = totalQuestions > 0 && answeredCount == 0;
              
              // If status is "Not Started", clear all answers and prepare for new input
              if (isNotStarted) {
                print('Debug - Status is "Not Started": Clearing all answers for fresh start');
                _answers.clear();
                _textControllers.forEach((key, controller) {
                  controller.clear();
                });
                // Clear local saved answers
                _clearLocalAnswers();
              } else {
                // Load existing answers from backend (preserve answers from database)
                if (answersData != null && answersData is Map) {
                  final answers = answersData as Map<String, dynamic>;
                  print('Debug - Loading ${answers.length} answers from backend');
                  answers.forEach((key, answerObj) {
                    final questionId = int.tryParse(key);
                    if (questionId != null && answerObj != null) {
                      // Answer structure: { value: "...", score: ..., question_id: ..., ... }
                      // Match web logic: $answers[$question->id]->value ?? null
                      if (answerObj is Map) {
                        final answerValue = answerObj['value'];
                        if (answerValue != null) {
                          final answerStr = answerValue.toString().trim();
                          print('Debug - Backend answer for question $questionId: $answerStr');
                          
                          // Find the matching question to get its options
                          String? normalizedAnswer = answerStr;
                          for (var group in groups) {
                            final questions = group['questions'] as List<dynamic>? ?? [];
                            for (var q in questions) {
                              if ((q['id'] as int?) == questionId) {
                                final questionOptions = (q['options'] as String? ?? 'Yes,No');
                                final options = questionOptions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                
                                // Find matching option (case-insensitive)
                                for (var option in options) {
                                  if (option.trim().toLowerCase() == answerStr.toLowerCase()) {
                                    normalizedAnswer = option.trim(); // Use the exact option format
                                    print('Debug - Normalized answer for question $questionId: $normalizedAnswer (from option: $option)');
                                    break;
                                  }
                                }
                                break;
                              }
                            }
                          }
                          
                          _answers[questionId] = normalizedAnswer;
                          
                          // Update TextEditingController if it exists
                          if (_textControllers.containsKey(questionId)) {
                            _textControllers[questionId]?.text = normalizedAnswer ?? '';
                          }
                        }
                      }
                    }
                  });
                }
                // If it's an array, it means no answers yet
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTicketPage(
        question: question,
        checklistData: _checklistData!,
        location: location,
        onCreateTicket: (ticketData) async {
          // Save answer with ticket
          final questionId = question['id'] as int;
          await _saveAnswerWithTicket(questionId, 'no', ticketData);
        },
      ),
      ),
    ).then((value) {
      // After returning from the page, reload checklist
      _loadChecklistDetail();
    });
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

      // Get question score (matching web logic: includes score in save request)
      final questionScore = _getQuestionScore(questionId);

      // Add form fields
      request.fields['checklist_id'] = widget.checklistId.toString();
      request.fields['question_id'] = questionId.toString();
      request.fields['value'] = value;
      request.fields['create_ticket'] = '1';
      request.fields['note'] = ticketData['note'] as String? ?? '';
      
      // Include score if available (matching web: score is sent in save request)
      if (questionScore != null) {
        request.fields['score'] = questionScore.toString();
        print('Debug - Including score in ticket save: $questionScore');
      } else {
        print('Debug - Warning: Question score not found for question $questionId');
      }

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

      // Get question score (matching web logic: includes score in save request)
      final questionScore = _getQuestionScore(questionId);

      // Prepare the request body
      final body = <String, String>{
        'checklist_id': widget.checklistId.toString(),
        'question_id': questionId.toString(),
        'value': value,
      };

      // Include score if available (matching web: score is sent in save request)
      if (questionScore != null) {
        body['score'] = questionScore.toString();
        print('Debug - Including score: $questionScore');
      } else {
        print('Debug - Warning: Question score not found for question $questionId');
      }

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
          // Update _checklistData with the new answer to reflect in progress calculation
          if (_checklistData != null && _checklistData!['answers'] != null) {
            final answersData = _checklistData!['answers'];
            if (answersData is Map) {
              final answers = answersData as Map<String, dynamic>;
              answers[questionId.toString()] = {
                'value': value,
                'question_id': questionId,
              };
            }
          }
          
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
              
              // Update UI to recalculate progress and score
              setState(() {});
            }
          }
          
          // If ticket was created, refresh the page to show ticket indicator
          if (data['data']?['ticket_created'] == true) {
            _loadChecklistDetail();
          } else {
            // Update UI to recalculate progress and score
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
    
    // Question should be disabled ONLY if:
    // Has a ticket AND ticket is not completed (when user selects "no")
    // Do NOT lock questions based on checklist completion status
    bool shouldDisable = hasTicket && !isTicketCompleted;
    
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
      margin: const EdgeInsets.only(bottom: 20),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First row: Step number, question text, and priority badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Step number with gradient
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        priorityColor,
                        priorityColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: priorityColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Question text
                Expanded(
                  child: Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A202C),
                      height: 1.4,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        priorityColor.withOpacity(0.15),
                        priorityColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: priorityColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    priorityTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Second row: Toggle options and score badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Answer options
                Expanded(
                  child: questionType == 'radio' || questionType == 'yes_no'
                      ? _buildDynamicOptions(questionId, questionOptions, shouldDisable, question)
                      : questionType == 'checkbox'
                          ? _buildCheckboxOptions(questionId, question)
                          : questionType == 'text' || questionType == 'textarea'
                              ? _buildTextInput(questionId, questionType)
                              : _buildDynamicOptions(questionId, questionOptions, shouldDisable, question),
                ),
                const SizedBox(width: 12),
                // Score percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
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
                        size: 10,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${(question['score'] as num?)?.toDouble() ?? 0.0}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              ),

            // Show disabled message if question is disabled (only when ticket is created)
            if (shouldDisable) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.orange.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ticket created',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
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
    
    // Check if this is a Yes/No/N/A question for toggle switch (matching second image design)
    final isToggleQuestion = options.length >= 2 && options.length <= 3 &&
                            (options.any((o) => o.toLowerCase() == 'yes') || 
                             options.any((o) => o.toLowerCase() == 'no') ||
                             options.any((o) => o.toLowerCase() == 'n/a' || o.toLowerCase() == 'na'));
    
    if (isToggleQuestion) {
      // Check if a ticket has been created for this question
      bool hasTicket = false;
      final ticketsData = _checklistData?['tickets'];
      if (ticketsData != null && ticketsData is Map) {
        final tickets = ticketsData as Map<String, dynamic>;
        if (tickets.containsKey(questionId.toString())) {
          final ticket = tickets[questionId.toString()];
          if (ticket != null && ticket is Map) {
            final ticketId = ticket['id'];
            hasTicket = ticketId != null;
          }
        }
      }
      
      // Match second image: Simple toggle switches with gray background, white handle on left, text on right
      // If question is disabled (locked with ticket), set "No" as the default answer
      if (disabled && !_answers.containsKey(questionId)) {
        _answers[questionId] = 'No';
      }
      final currentAnswer = _answers[questionId]?.toString().trim().toLowerCase();
      
      return Wrap(
        spacing: 12,
        runSpacing: 12,
            children: options.map((option) {
          final trimmedOption = option.trim();
          final optionLower = trimmedOption.toLowerCase();
          final isSelected = currentAnswer == optionLower;
          // Make "No" red if ticket is created
          final isNoWithTicket = optionLower == 'no' && hasTicket;
          
          return GestureDetector(
                  onTap: disabled ? null : () async {
              // Toggle: if already selected, deselect it
              final newAnswer = isSelected ? null : trimmedOption;
                    setState(() {
                if (newAnswer == null) {
                  _answers.remove(questionId);
                } else {
                  _answers[questionId] = newAnswer;
                }
              });
              
              if (newAnswer != null) {
                    await _scrollToNextQuestion(questionId);
                    
                if (optionLower == 'no') {
                  print('Debug - "No" selected for question: $questionId');
                  print('Debug - Question data: $question');
                      _showCreateTicketDialog(question);
                    } else {
                  _saveAnswer(questionId, newAnswer);
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 90,
              height: 32,
                    decoration: BoxDecoration(
                color: disabled 
                    ? Colors.grey.shade300 
                    : (isSelected 
                        ? (isNoWithTicket ? Colors.red : const Color(0xFF3B82F6)) // Red when "No" with ticket, blue otherwise
                        : (isNoWithTicket ? Colors.red.withOpacity(0.2) : Colors.grey.shade200)), // Red tint when "No" with ticket
                borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                  color: disabled
                      ? Colors.grey.shade400
                      : (isSelected 
                          ? (isNoWithTicket ? Colors.red : const Color(0xFF3B82F6)) // Red border when "No" with ticket
                          : (isNoWithTicket ? Colors.red : Colors.grey.shade300)), // Red border when "No" with ticket
                        width: isNoWithTicket ? 2 : 1,
                      ),
                    ),
              child: Stack(
                      children: [
                  // Text label - on left when selected, on right when not selected
                  Positioned.fill(
                    child: Align(
                      alignment: isSelected ? Alignment.centerLeft : Alignment.centerRight,
                      child: Padding(
                        padding: isSelected 
                            ? const EdgeInsets.only(left: 12.0)
                            : const EdgeInsets.only(right: 12.0),
                        child: Text(
                          trimmedOption.toUpperCase(),
                          style: TextStyle(
                            color: disabled
                                ? Colors.grey.shade600
                                : (isSelected 
                                    ? Colors.white 
                                    : (isNoWithTicket ? Colors.red : Colors.grey.shade700)), // Red text when "No" with ticket
                            fontSize: 11,
                            fontWeight: isNoWithTicket ? FontWeight.w700 : FontWeight.w600, // Bolder when ticket exists
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // White circular handle - on left when unselected, moves right when selected
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: isSelected ? 90 - 30 : 2, // Moves to right when selected
                    top: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    ),
                  ),
                ],
                  ),
                ),
              );
            }).toList(),
      );
    }
    
    // Check if a ticket has been created for this question
    bool hasTicket = false;
    final ticketsData = _checklistData?['tickets'];
    if (ticketsData != null && ticketsData is Map) {
      final tickets = ticketsData as Map<String, dynamic>;
      if (tickets.containsKey(questionId.toString())) {
        final ticket = tickets[questionId.toString()];
        if (ticket != null && ticket is Map) {
          final ticketId = ticket['id'];
          hasTicket = ticketId != null;
        }
      }
    }
    
    // For other options, use the original button layout
    // Match web logic: compare case-insensitively, store trimmed value
    return Row(
            children: options.map((option) {
        final trimmedOption = option.trim();
        final optionLower = trimmedOption.toLowerCase();
        final currentAnswer = _answers[questionId]?.toString().trim();
        // Case-insensitive comparison (matching web: $answer == trim($opt))
        final isSelected = currentAnswer != null && 
                          currentAnswer.toLowerCase() == optionLower;
        // Make "No" red if ticket is created
        final isNoWithTicket = optionLower == 'no' && hasTicket;
        
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
                      ? (disabled 
                          ? Colors.grey.shade200 
                          : (isNoWithTicket ? Colors.red.withOpacity(0.1) : const Color(0xFF3B82F6).withOpacity(0.1))) // Red background when "No" with ticket
                      : (disabled 
                          ? Colors.grey.shade100 
                          : (isNoWithTicket ? Colors.red.shade50 : Colors.grey.shade50)), // Red tint when "No" with ticket
                  borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                      ? (disabled 
                          ? Colors.grey 
                          : (isNoWithTicket ? Colors.red : const Color(0xFF3B82F6))) // Red border when "No" with ticket
                      : (disabled 
                          ? Colors.grey.shade300 
                          : (isNoWithTicket ? Colors.red.shade300 : Colors.grey.shade300)), // Red border when "No" with ticket
                    width: (isSelected || isNoWithTicket) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: disabled 
                          ? Colors.grey.shade600 
                          : (isNoWithTicket ? Colors.red : const Color(0xFF3B82F6)), // Red icon when "No" with ticket
                      ),
                    if (isSelected) const SizedBox(width: 8),
                      Text(
                        option,
                        style: TextStyle(
                          color: disabled 
                          ? Colors.grey.shade600 
                          : (isSelected 
                              ? (isNoWithTicket ? Colors.red : const Color(0xFF3B82F6)) // Red text when "No" with ticket
                              : (isNoWithTicket ? Colors.red.shade700 : Colors.grey.shade700)), // Red text when "No" with ticket
                          fontSize: 14,
                        fontWeight: (isSelected || isNoWithTicket) ? FontWeight.w700 : FontWeight.w600, // Bolder when ticket exists
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
    
    // Question should be disabled ONLY if:
    // Has a ticket AND ticket is not completed (when user selects "no")
    // Do NOT lock questions based on checklist completion status
    bool shouldDisable = hasTicket && !isTicketCompleted;
    
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
    
    // Question should be disabled ONLY if:
    // Has a ticket AND ticket is not completed (when user selects "no")
    // Do NOT lock questions based on checklist completion status
    bool shouldDisable = hasTicket && !isTicketCompleted;
    
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
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF374151),
              height: 1.4,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              padding: const EdgeInsets.all(8),
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
                size: 16,
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
            final answerObj = answers[questionId.toString()];
            if (answerObj != null && answerObj is Map) {
              final answerValue = answerObj['value'];
              hasAnswer = answerValue != null && answerValue.toString().trim().isNotEmpty;
            }
          }
        }
        if (!hasAnswer && _answers.containsKey(questionId)) {
          final localAnswer = _answers[questionId];
          hasAnswer = localAnswer != null && localAnswer.toString().trim().isNotEmpty;
        }
        
        // Check if question is locked (only when ticket is created, not based on completion)
        bool isLocked = false;
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
        
        // Count as completed if it has an answer OR is locked (locked = completed for checklist completion)
        // This allows checklist to be marked as completed even if some questions are locked
        if (hasAnswer || isLocked) {
          answeredQuestions++;
        }
      }
    }
    
    // Calculate status dynamically based on progress (matching list page logic)
    String displayStatus;
    Color statusColor;
    if (totalQuestions == 0) {
      displayStatus = 'No Questions';
      statusColor = const Color(0xFF6B7280); // Grey
    } else if (answeredQuestions == 0) {
      displayStatus = 'Not Started';
      statusColor = const Color(0xFFF59E0B); // Orange
    } else if (answeredQuestions == totalQuestions) {
      displayStatus = 'Completed';
      statusColor = const Color(0xFF10B981); // Green
    } else {
      displayStatus = 'In Progress';
      statusColor = const Color(0xFF3B82F6); // Blue
    }
    
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                flex: 1,
                child: _buildDetailItem('Location', location, Icons.location_on_outlined),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: 1,
                child: _buildDetailItem('Checklist Theme', checklistTheme, Icons.assignment_outlined),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: 1,
                child: _buildDetailItem('Status', displayStatus, Icons.info_outline, valueColor: statusColor, alignRight: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Progress, Score, Frequency
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildProgressItem(
                  answeredQuestions,
                  totalQuestions,
                  isActive: displayStatus == 'In Progress' || displayStatus == 'Not Started',
                ),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: 1,
                child: _buildDetailItem(
                  'Score',
                  '${score.toStringAsFixed(0)}/100(%)',
                  Icons.star_rounded,
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
              const Spacer(flex: 1),
              Expanded(
                flex: 1,
                child: _buildDetailItem('Frequency', frequencyTitle, Icons.schedule_rounded, alignRight: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCollapsedHeader() {
    if (_checklistData == null) return const SizedBox.shrink();
    
    final checklist = _checklistData!['checklist'] as Map<String, dynamic>;
    final project = checklist['project'] as Map<String, dynamic>?;
    final theme = checklist['theme'] as Map<String, dynamic>?;
    
    final location = '${project?['title'] ?? ''}'.trim();
    final score = _calculateScore();
    
    // Calculate progress
    int totalQuestions = 0;
    int answeredQuestions = 0;
    
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    final answersData = _checklistData!['answers'];
    final ticketsData = _checklistData?['tickets'];
    final isChecklistCompleted = _isChecklistCompleted();
    
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        final questionId = questionData['id'] as int?;
        if (questionId == null) continue;
        
        totalQuestions++;
        
        bool hasAnswer = false;
        if (answersData != null && answersData is Map) {
          final answerObj = answersData[questionId.toString()];
          if (answerObj != null && answerObj is Map) {
            final answerValue = answerObj['value'];
            hasAnswer = answerValue != null && answerValue.toString().trim().isNotEmpty;
          }
        }
        if (!hasAnswer && _answers.containsKey(questionId)) {
          final localAnswer = _answers[questionId];
          hasAnswer = localAnswer != null && localAnswer.toString().trim().isNotEmpty;
        }
        
        // Check if question is locked (only when ticket is created, not based on completion)
        bool isLocked = false;
        if (ticketsData != null && ticketsData is Map) {
          final ticket = ticketsData[questionId.toString()];
          if (ticket != null && ticket is Map) {
            final ticketStatus = ticket['ticket_status'] as Map<String, dynamic>?;
            final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
            final isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') || 
                                    ticketStatusTitle.toLowerCase().contains('complete') ||
                                    ticketStatusTitle.toLowerCase().contains('resolved') ||
                                    ticketStatusTitle.toLowerCase().contains('closed');
            isLocked = !isTicketCompleted;
          }
        }
        
        // Count as completed if it has an answer OR is locked (locked = completed for checklist completion)
        if (hasAnswer || isLocked) {
          answeredQuestions++;
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildDetailItem('Location', location, Icons.location_on_outlined),
          ),
          const Spacer(flex: 1),
          Expanded(
            flex: 1,
            child: _buildProgressItem(
              answeredQuestions,
              totalQuestions,
              isActive: true,
            ),
          ),
          const Spacer(flex: 1),
          Expanded(
            flex: 1,
            child: _buildDetailItem(
              'Score',
              '${score.toStringAsFixed(0)}/100(%)',
              Icons.star_rounded,
              valueColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailItem(String label, String value, IconData icon, {Color? valueColor, bool alignRight = false}) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
  
  Widget _buildProgressItem(int answeredQuestions, int totalQuestions, {required bool isActive}) {
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
        int ticketCountInGroup = 0; // Count of non-completed tickets in this group
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
          
          // Check if question is locked (only when ticket is created, not based on completion)
          bool isLocked = false;
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
              
              // Count non-completed tickets for the badge
              if (!isTicketCompleted) {
                ticketCountInGroup++;
              }
            }
          }
          
          // Count as completed if it has an answer OR is locked (locked = completed for checklist completion)
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
            ticketCount: ticketCountInGroup,
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
    required int ticketCount,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                      
                      // Ticket Count Badge (only show if there are tickets)
                      if (ticketCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.support_agent_rounded,
                                color: const Color(0xFFEF4444),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$ticketCount',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
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
                        bottom: i < questions.length - 1 ? 20 : 0,
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
                            // Show collapsed header when scrolling, full header when at top
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isScrolled 
                                ? _buildCollapsedHeader()
                                : _buildDetailsHeader(),
                            ),
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
                widget.checklistTitle,
                style: const TextStyle(
                  fontSize: 15,
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
      ),
    );
  }
}

