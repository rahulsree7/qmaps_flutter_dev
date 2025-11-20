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
        
        // Add to completed score if answered
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
            setState(() {
              _checklistData = data['data'];
              _isLoading = false;
              
              // Pre-fill existing answers from backend
              if (_checklistData!['answers'] != null) {
                final answersData = _checklistData!['answers'];
                // Backend can return either array [] or object {}
                if (answersData is Map) {
                  final answers = answersData as Map<String, dynamic>;
                  print('Debug - Loading ${answers.length} answers from backend');
                  answers.forEach((key, value) {
                    final questionId = int.tryParse(key);
                    if (questionId != null && value != null) {
                      if (value is Map) {
                        // Store answers in lowercase for consistency
                        final answerValue = value['value']?.toString();
                        print('Debug - Backend answer for question $questionId: $answerValue');
                        _answers[questionId] = answerValue?.toLowerCase();
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
    
    // Check if checklist is completed
    final checklist = _checklistData?['checklist'] as Map<String, dynamic>?;
    final checklistStatus = checklist?['status'] as Map<String, dynamic>?;
    final statusTitle = checklistStatus?['title'] as String? ?? '';
    final isChecklistCompleted = statusTitle.toLowerCase().contains('completed') || 
                                 statusTitle.toLowerCase().contains('complete');
    
    // Question should be disabled if:
    // 1. Checklist is completed (regardless of ticket status), OR
    // 2. Checklist is not completed AND has a ticket AND ticket is not completed
    final shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    
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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header with step number and priority
            Row(
              children: [
                // Step number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3182CE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: priorityColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    priorityTitle.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Question text
            Text(
              questionText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Answer options based on question type
            if (questionType == 'radio' || questionType == 'yes_no')
              _buildDynamicOptions(questionId, questionOptions, shouldDisable, question)
            else if (questionType == 'checkbox')
              _buildCheckboxOptions(questionId, question)
            else if (questionType == 'text' || questionType == 'textarea')
              _buildTextInput(questionId)
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
    
    // If only 2-3 options, display in a row; otherwise use a column
    final displayInRow = options.length <= 3;
    
    return Container(
      decoration: BoxDecoration(
        color: disabled ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: disabled ? Colors.grey.shade300 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: displayInRow 
        ? Row(
            children: options.map((option) {
              final isSelected = _answers[questionId] == option.toLowerCase();
              return Expanded(
                child: InkWell(
                  onTap: disabled ? null : () async {
                    setState(() {
                      _answers[questionId] = option.toLowerCase();
                    });
                    
                    // Add smooth scrolling effect
                    await _scrollToNextQuestion(questionId);
                    
                    if (option.toLowerCase() == 'no') {
                      print('Debug - "No" selected for question (row): $questionId');
                      print('Debug - Question data (row): $question');
                      _showCreateTicketDialog(question);
                    } else {
                      _saveAnswer(questionId, option.toLowerCase());
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (disabled ? Colors.grey.shade200 : const Color(0xFF3182CE).withOpacity(0.1))
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected 
                          ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                          : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                                : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: isSelected 
                              ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                              : Colors.transparent,
                          ),
                          child: isSelected
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          option,
                          style: TextStyle(
                            color: disabled 
                              ? Colors.grey.shade500 
                              : (isSelected ? const Color(0xFF3182CE) : const Color(0xFF2D3748)),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          )
        : Column(
            children: options.map((option) {
              final isSelected = _answers[questionId] == option.toLowerCase();
              return InkWell(
                onTap: disabled ? null : () async {
                  setState(() {
                    _answers[questionId] = option.toLowerCase();
                  });
                  
                  // Add smooth scrolling effect
                  await _scrollToNextQuestion(questionId);
                  
                  if (option.toLowerCase() == 'no') {
                    print('Debug - "No" selected for question: $questionId');
                    print('Debug - Question data: $question');
                    _showCreateTicketDialog(question);
                  } else {
                    _saveAnswer(questionId, option.toLowerCase());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (disabled ? Colors.grey.shade200 : const Color(0xFF3182CE).withOpacity(0.1))
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected 
                        ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                        : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected 
                              ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                              : Colors.grey.shade400,
                            width: 2,
                          ),
                          color: isSelected 
                            ? (disabled ? Colors.grey : const Color(0xFF3182CE))
                            : Colors.transparent,
                        ),
                        child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option,
                        style: TextStyle(
                          color: disabled 
                            ? Colors.grey.shade500 
                            : (isSelected ? const Color(0xFF3182CE) : const Color(0xFF2D3748)),
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
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
    
    final checklist = _checklistData?['checklist'] as Map<String, dynamic>?;
    final checklistStatus = checklist?['status'] as Map<String, dynamic>?;
    final statusTitle = checklistStatus?['title'] as String? ?? '';
    final isChecklistCompleted = statusTitle.toLowerCase().contains('completed') || 
                                 statusTitle.toLowerCase().contains('complete');
    final shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    
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
            _answers[questionId] = value?.toLowerCase();
          });
        },
        onSubmitted: (value) {
          _saveAnswer(questionId, value.toLowerCase());
        },
      );
    }
    
    // Parse selected values (comma-separated string stored in _answers)
    final selectedValues = (_answers[questionId] ?? '').split(',').where((e) => e.isNotEmpty).toSet();
    
    return Column(
      children: options.map((option) {
        final optionLower = option.toLowerCase();
        return CheckboxListTile(
          title: Text(
            option,
            style: TextStyle(
              color: shouldDisable ? Colors.grey[500] : null,
              fontSize: 14,
            ),
          ),
          value: selectedValues.contains(optionLower),
          onChanged: shouldDisable ? null : (checked) {
            setState(() {
              if (checked == true) {
                selectedValues.add(optionLower);
              } else {
                selectedValues.remove(optionLower);
              }
              _answers[questionId] = selectedValues.join(',');
            });
            // Save answer after checkbox change
            _saveAnswer(questionId, selectedValues.join(','));
          },
          activeColor: shouldDisable ? Colors.grey : const Color(0xFF8B5CF6),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(int questionId) {
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
    
    final checklist = _checklistData?['checklist'] as Map<String, dynamic>?;
    final checklistStatus = checklist?['status'] as Map<String, dynamic>?;
    final statusTitle = checklistStatus?['title'] as String? ?? '';
    final isChecklistCompleted = statusTitle.toLowerCase().contains('completed') || 
                                 statusTitle.toLowerCase().contains('complete');
    final shouldDisable = isChecklistCompleted || (hasTicket && !isTicketCompleted);
    
    // Create or reuse TextEditingController for this question
    if (!_textControllers.containsKey(questionId)) {
      _textControllers[questionId] = TextEditingController(
        text: _answers[questionId] ?? '',
      );
      print('Debug - Created TextEditingController for question $questionId with initial value: "${_answers[questionId]}"');
    }
    
    return TextField(
      controller: _textControllers[questionId],
      enabled: !shouldDisable,
      decoration: InputDecoration(
        labelText: 'Your Answer',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      maxLines: 3,
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
    
    final location = '${workspace?['title'] ?? ''} • ${project?['title'] ?? ''}'.trim();
    final checklistTheme = theme?['title'] ?? 'N/A';
    final statusTitle = status?['title'] ?? 'N/A';
    final frequencyTitle = frequency?['title'] ?? 'N/A';
    final score = _calculateScore();
    
    // Calculate progress
    int totalQuestions = 0;
    int answeredQuestions = 0;
    
    final groups = theme?['groups'] as List<dynamic>? ?? [];
    final answersData = _checklistData!['answers'];
    
    for (var group in groups) {
      final groupData = group as Map<String, dynamic>;
      final questions = groupData['questions'] as List<dynamic>? ?? [];
      totalQuestions += questions.length;
      
      for (var question in questions) {
        final questionData = question as Map<String, dynamic>;
        final questionId = questionData['id'] as int;
        
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
        
        if (hasAnswer) answeredQuestions++;
      }
    }
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // First row: Location, Theme, Status
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Location', location, Icons.location_on),
              ),
              Expanded(
                child: _buildDetailItem('Checklist Theme', checklistTheme, Icons.list_alt),
              ),
              Expanded(
                child: _buildDetailItem('Status', statusTitle, Icons.info_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Second row: Progress, Score, Frequency
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Progress',
                  '$answeredQuestions/$totalQuestions',
                  Icons.trending_up,
                  valueColor: const Color(0xFF059669),
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Score',
                  '${score.toStringAsFixed(0)}/100(%)',
                  Icons.star,
                  valueColor: const Color(0xFFDC2626),
                ),
              ),
              Expanded(
                child: _buildDetailItem('Frequency', frequencyTitle, Icons.schedule),
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
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        // Calculate progress for this group
        int answeredInGroup = 0;
        int totalInGroup = questions.length;
        
        for (var question in questions) {
          final questionData = question as Map<String, dynamic>;
          final questionId = questionData['id'] as int;
          
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
          
          if (hasAnswer) answeredInGroup++;
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: borderColor,
          width: 1.5,
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Group Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: lightAccentColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.folder_open,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      
                      // Group Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$totalCount ${totalCount == 1 ? 'Question' : 'Questions'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Progress Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: lightAccentColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isComplete 
                                ? Icons.check_circle
                                : isInProgress
                                  ? Icons.hourglass_bottom
                                  : Icons.pending_actions,
                              color: accentColor,
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$answeredCount/$totalCount',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 10),
                      
                      // Expand/Collapse Icon
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[600],
                        size: 26,
                      ),
                    ],
                  ),
                  
                  // Progress Bar
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Accordion Content (Questions)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (int i = 0; i < questions.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: i < questions.length - 1 ? 16 : 0,
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
      appBar: AppBar(
        title: Text(
          widget.checklistTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[300],
            height: 1,
          ),
        ),
      ),
      body: _isLoading
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
    );
  }
}

