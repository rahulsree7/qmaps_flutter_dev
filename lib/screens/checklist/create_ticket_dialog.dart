import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class CreateTicketDialog extends StatefulWidget {
  final Map<String, dynamic> question;
  final Map<String, dynamic> checklistData;
  final String location;
  final Function(Map<String, dynamic>) onCreateTicket;

  const CreateTicketDialog({
    super.key,
    required this.question,
    required this.checklistData,
    required this.location,
    required this.onCreateTicket,
  });

  @override
  State<CreateTicketDialog> createState() => _CreateTicketDialogState();
}

class _CreateTicketDialogState extends State<CreateTicketDialog> {
  final TextEditingController _discussionController = TextEditingController();
  List<int> _selectedInternalUsers = [];
  List<int> _selectedExternalUsers = [];
  int? _selectedPriorityId;
  int? _selectedStatusId;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  bool _showExternal = false;
  
  // User data
  List<Map<String, dynamic>> _internalUsers = [];
  List<Map<String, dynamic>> _externalUsers = [];
  List<Map<String, dynamic>> _priorities = [];
  List<Map<String, dynamic>> _statuses = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsersAndData();
  }

  Future<void> _loadUsersAndData() async {
    try {
      // Get question ID from the question data
      final questionId = widget.question['id'] as int?;
      
      print('Debug - Question data: ${widget.question}');
      print('Debug - Question ID: $questionId');
      
      if (questionId == null) {
        print('Debug - No question ID found, using fallback');
        // Try fallback method without question ID
        await _loadUsersFallback();
        return;
      }

      // Fetch question details and users
      print('Debug - Calling fetchQuestionDetails with ID: $questionId');
      final result = await AuthService.fetchQuestionDetails(questionId);
      print('Debug - fetchQuestionDetails result: $result');
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        
        setState(() {
          _internalUsers = List<Map<String, dynamic>>.from(data['internal_users'] ?? []);
          _externalUsers = List<Map<String, dynamic>>.from(data['external_users'] ?? []);
          _priorities = List<Map<String, dynamic>>.from(data['priorities'] ?? []);
          _statuses = List<Map<String, dynamic>>.from(data['statuses'] ?? []);
          _isLoadingUsers = false;
        });

        // Pre-select all internal users
        final internalUserIds = _internalUsers.map((user) => user['id'] as int).toList();
        setState(() {
          _selectedInternalUsers = internalUserIds;
        });
        print('Debug - Pre-selected internal users: $internalUserIds');

        // Pre-select all external users
        final externalUserIds = _externalUsers.map((user) => user['id'] as int).toList();
        setState(() {
          _selectedExternalUsers = externalUserIds;
        });
        print('Debug - Pre-selected external users: $externalUserIds');

        // Pre-select priority from question details
        final questionPriority = data['question_priority'] as Map<String, dynamic>?;
        if (questionPriority != null) {
          final priorityId = questionPriority['id'] as int?;
          if (priorityId != null) {
            setState(() {
              _selectedPriorityId = priorityId;
            });
          }
        }

        // Set default status to "Active" if available
        final activeStatus = _statuses.firstWhere(
          (s) => (s['title'] as String?)?.toLowerCase() == 'active',
          orElse: () => _statuses.isNotEmpty ? _statuses.first : <String, dynamic>{},
        );
        if (activeStatus.isNotEmpty) {
          setState(() {
            _selectedStatusId = activeStatus['id'] as int?;
          });
        }

        // Pre-populate discussion with question details
        final questionData = data['question'] as Map<String, dynamic>?;
        if (questionData != null) {
          final questionText = questionData['question'] as String? ?? '';
          final durationTime = questionData['duration_time'] as int?;
          final durationUnit = questionData['duration_unit'] as String?;
          
          String discussionText = 'Question: $questionText\n';
          if (durationTime != null && durationUnit != null) {
            discussionText += 'Duration: $durationTime $durationUnit\n';
          }
          discussionText += 'Issue: ';
          
          _discussionController.text = discussionText;
        }
      } else {
        print('Debug - Failed to load question details: ${result['message']}');
        print('Debug - Falling back to workspace-based method');
        // Try fallback method
        await _loadUsersFallback();
      }
    } catch (e) {
      print('Debug - Error loading question details: $e');
      // Try fallback method
      await _loadUsersFallback();
    }
  }

  Future<void> _loadUsersFallback() async {
    try {
      print('Debug - Trying fallback method (workspace-based)...');
      final result = await AuthService.fetchUsersFallback(); // Use direct fallback method
      print('Debug - Fallback result: $result');
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        
        setState(() {
          _internalUsers = List<Map<String, dynamic>>.from(data['internal_users'] ?? []);
          _externalUsers = List<Map<String, dynamic>>.from(data['external_users'] ?? []);
          _priorities = List<Map<String, dynamic>>.from(data['priorities'] ?? []);
          _statuses = List<Map<String, dynamic>>.from(data['statuses'] ?? []);
          _isLoadingUsers = false;
        });

        // Pre-select priority from question
        final priority = widget.question['priority'] as Map<String, dynamic>?;
        if (priority != null) {
          final priorityId = priority['id'] as int?;
          if (priorityId != null) {
            setState(() {
              _selectedPriorityId = priorityId;
            });
          }
        }

        // Pre-select all internal and external users to mirror backend logic
        final internalUserIds = _internalUsers.map((u) => u['id'] as int).toList();
        final externalUserIds = _externalUsers.map((u) => u['id'] as int).toList();
        setState(() {
          _selectedInternalUsers = internalUserIds;
          _selectedExternalUsers = externalUserIds;
        });

        // Set default status to "Active" if available
        final activeStatus = _statuses.firstWhere(
          (s) => (s['title'] as String?)?.toLowerCase() == 'active',
          orElse: () => _statuses.isNotEmpty ? _statuses.first : <String, dynamic>{},
        );
        if (activeStatus.isNotEmpty) {
          setState(() {
            _selectedStatusId = activeStatus['id'] as int?;
          });
        }
      } else {
        print('Debug - Fallback also failed: ${result['message']}');
        setState(() {
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      print('Debug - Error in fallback: $e');
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _discussionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 65, // compress ~35% while keeping clarity
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking images: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 65,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening camera: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _createTicket() {
    if (_discussionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter discussion details'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final ticketData = {
      'note': _discussionController.text.trim(),
      'internal_users': _selectedInternalUsers,
      'external_users': _selectedExternalUsers,
      'priority': _selectedPriorityId,
      'status': _selectedStatusId,
      'images': _selectedImages,
    };

    widget.onCreateTicket(ticketData);
  }

  @override
  Widget build(BuildContext context) {
    final checklist = widget.checklistData['checklist'] as Map<String, dynamic>?;
    final priorities = widget.checklistData['priorities'] as List<dynamic>? ?? [];
    final statuses = widget.checklistData['statuses'] as List<dynamic>? ?? [];
    
    final questionText = widget.question['question'] as String? ?? '';
    final priority = widget.question['priority'] as Map<String, dynamic>?;
    final priorityTitle = priority?['title'] as String? ?? 'Medium';
    
    // Calculate score and duration
    final score = widget.question['score']?.toString() ?? '0';
    final durationTime = widget.question['duration_time']?.toString() ?? '1';
    final durationUnit = widget.question['duration_unit']?.toString() ?? 'hour';

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.98,
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simple Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF3182CE),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_task, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Create Task/Ticket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question summary (simple)
                    Text(
                      questionText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildInfoItem('Priority', priorityTitle, Icons.flag),
                        _buildInfoItem('Score', '$score%', Icons.star),
                        _buildInfoItem('Time', '$durationTime $durationUnit', Icons.access_time),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Inputs
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // Internal Users (simple chips)
                          const Text('Internal users', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _buildSimpleUserSelector(
                            isInternal: true,
                            selectedUsers: _selectedInternalUsers,
                            onChanged: (users) => setState(() => _selectedInternalUsers = users),
                          ),
                          const SizedBox(height: 12),
                          // External Users (show by default if available, else toggle to add)
                          if (_externalUsers.isNotEmpty) ...[
                            const Text('External users', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            _buildSimpleUserSelector(
                              isInternal: false,
                              selectedUsers: _selectedExternalUsers,
                              onChanged: (users) => setState(() => _selectedExternalUsers = users),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => setState(() => _showExternal = !_showExternal),
                                  child: Text(_showExternal ? 'Hide external users' : 'Add external users'),
                                ),
                              ],
                            ),
                            if (_showExternal) ...[
                              _buildSimpleUserSelector(
                                isInternal: false,
                                selectedUsers: _selectedExternalUsers,
                                onChanged: (users) => setState(() => _selectedExternalUsers = users),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                          
                          // Priority and Status Section
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonFormField<int>(
                                        value: _selectedPriorityId,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        items: _priorities.map((priority) {
                                          return DropdownMenuItem<int>(
                                            value: priority['id'] as int,
                                            child: Text(
                                              priority['title'] as String? ?? '',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPriorityId = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: DropdownButtonFormField<int>(
                                        value: _selectedStatusId,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                        items: _statuses.map((status) {
                                          return DropdownMenuItem<int>(
                                            value: status['id'] as int,
                                            child: Text(
                                              status['title'] as String? ?? '',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedStatusId = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Discussion Section (kept primary)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Discussion *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextFormField(
                                  controller: _discussionController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16),
                                    hintText: 'Describe the issue or add additional details...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Images Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Images', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _captureImage,
                                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3182CE),
                                      elevation: 0,
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _pickImages,
                                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF3182CE),
                                      elevation: 0,
                                      side: BorderSide(color: Colors.grey.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                  if (_selectedImages.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text('${_selectedImages.length} selected', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_selectedImages.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(_selectedImages.length, (index) {
                                    final file = _selectedImages[index];
                                    return Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(file.path),
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: InkWell(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.6),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            
            // Modern Action Buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _createTicket,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3182CE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Ticket',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildUserSelector({
    required bool isInternal,
    required List<int> selectedUsers,
    required Function(List<int>) onChanged,
  }) {
    final users = isInternal ? _internalUsers : _externalUsers;
    final themeColor = isInternal ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final lightColor = isInternal ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
    
    if (_isLoadingUsers) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [lightColor, lightColor.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 12),
              Text(
                'Loading users...',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [lightColor, lightColor.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 32,
              color: themeColor.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'No ${isInternal ? 'internal' : 'external'} users available',
              style: TextStyle(
                color: themeColor.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightColor, lightColor.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: users.map((user) {
              final userId = user['id'] as int;
              final userName = user['name'] as String? ?? 'Unknown';
              final isSelected = selectedUsers.contains(userId);
              
              return GestureDetector(
                onTap: () {
                  final newSelectedUsers = List<int>.from(selectedUsers);
                  if (isSelected) {
                    newSelectedUsers.remove(userId);
                  } else {
                    newSelectedUsers.add(userId);
                  }
                  onChanged(newSelectedUsers);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected 
                        ? LinearGradient(
                            colors: [themeColor, themeColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey[50]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? themeColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected 
                        ? [
                            BoxShadow(
                              color: themeColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? themeColor : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: isSelected 
                            ? Icon(
                                Icons.check,
                                size: 12,
                                color: themeColor,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Simpler chips-based selector used in the simplified UI
  Widget _buildSimpleUserSelector({
    required bool isInternal,
    required List<int> selectedUsers,
    required Function(List<int>) onChanged,
  }) {
    final users = isInternal ? _internalUsers : _externalUsers;
    if (_isLoadingUsers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 24, child: LinearProgressIndicator()),
      );
    }
    if (users.isEmpty) {
      return Text('No ${isInternal ? 'internal' : 'external'} users available', style: TextStyle(color: Colors.grey[600]));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: users.map((user) {
        final userId = user['id'] as int;
        final userName = user['name'] as String? ?? 'Unknown';
        final isSelected = selectedUsers.contains(userId);
        return FilterChip(
          label: Text(userName),
          selected: isSelected,
          onSelected: (sel) {
            final next = List<int>.from(selectedUsers);
            if (sel) {
              if (!next.contains(userId)) next.add(userId);
            } else {
              next.remove(userId);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

