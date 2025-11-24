import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class CreateTicketPage extends StatefulWidget {
  final Map<String, dynamic> question;
  final Map<String, dynamic> checklistData;
  final String location;
  final Function(Map<String, dynamic>) onCreateTicket;

  const CreateTicketPage({
    super.key,
    required this.question,
    required this.checklistData,
    required this.location,
    required this.onCreateTicket,
  });

  @override
  State<CreateTicketPage> createState() => _CreateTicketPageState();
}

class _CreateTicketPageState extends State<CreateTicketPage> {
  final TextEditingController _discussionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
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
      final questionId = widget.question['id'] as int?;
      
      if (questionId == null) {
        await _loadUsersFallback();
        return;
      }

      final result = await AuthService.fetchQuestionDetails(questionId);
      
      if (result['success'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        
        print('Debug - Fetched question details');
        print('Debug - Internal users: ${data['internal_users']}');
        print('Debug - External users: ${data['external_users']}');
        print('Debug - All data keys: ${data.keys.toList()}');
        
        setState(() {
          _internalUsers = List<Map<String, dynamic>>.from(data['internal_users'] ?? []);
          _externalUsers = List<Map<String, dynamic>>.from(data['external_users'] ?? []);
          _priorities = List<Map<String, dynamic>>.from(data['priorities'] ?? []);
          _statuses = List<Map<String, dynamic>>.from(data['statuses'] ?? []);
          _isLoadingUsers = false;
        });

        print('Debug - Internal users loaded: ${_internalUsers.length}');
        print('Debug - External users loaded: ${_externalUsers.length}');

        final internalUserIds = _internalUsers.map((user) => user['id'] as int).toList();
        setState(() {
          _selectedInternalUsers = internalUserIds;
        });

        final externalUserIds = _externalUsers.map((user) => user['id'] as int).toList();
        setState(() {
          _selectedExternalUsers = externalUserIds;
        });

        final questionPriority = data['question_priority'] as Map<String, dynamic>?;
        if (questionPriority != null) {
          final priorityId = questionPriority['id'] as int?;
          if (priorityId != null) {
            setState(() {
              _selectedPriorityId = priorityId;
            });
          }
        }

        final questionStatus = data['question_status'] as Map<String, dynamic>?;
        if (questionStatus != null) {
          final statusId = questionStatus['id'] as int?;
          if (statusId != null) {
          setState(() {
              _selectedStatusId = statusId;
            });
          }
        } else {
          // Set default "Pending" status if no status is found
          final statuses = _statuses;
          for (var status in statuses) {
            if ((status['title'] as String?)?.toLowerCase() == 'pending' ||
                (status['slug'] as String?)?.toLowerCase() == 'pending') {
              setState(() {
                _selectedStatusId = status['id'] as int;
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading users: $e');
      await _loadUsersFallback();
    }
  }

  Future<void> _loadUsersFallback() async {
        setState(() {
          _isLoadingUsers = false;
    });
  }

  Future<void> _pickImages() async {
    // Show dialog to choose between camera and gallery
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              title: const Text(
                'Take Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Use camera to capture a photo',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Select photos from your gallery',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            // Multiple photos option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_photo_alternate,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              title: const Text(
                'Choose Multiple Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Select multiple photos from gallery',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      if (source == ImageSource.camera) {
        // Check camera permission
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Camera permission is required to take photos'),
                  backgroundColor: AppTheme.error,
                  action: SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () => openAppSettings(),
                  ),
                ),
              );
            }
            return;
          }
        }

        // Take photo from camera
        final XFile? image = await _picker.pickImage(source: ImageSource.camera);
        if (image != null && mounted) {
          setState(() {
            if (_selectedImages.length < 5) {
              _selectedImages.add(image);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Maximum 5 photos allowed'),
                  backgroundColor: AppTheme.error,
                ),
              );
            }
          });
        }
      } else {
        // Pick from gallery (single or multiple)
        // Check if we should pick multiple based on current count
        if (_selectedImages.length == 0) {
          // Allow multiple selection if no images selected
          final List<XFile> images = await _picker.pickMultiImage();
          if (images.isNotEmpty && mounted) {
            setState(() {
              final remainingSlots = 5 - _selectedImages.length;
              _selectedImages.addAll(images.take(remainingSlots));
              if (images.length > remainingSlots) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maximum 5 photos allowed. Some photos were not added.'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            });
          }
        } else {
          // Single image selection if some images already selected
          final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
          if (image != null && mounted) {
            setState(() {
              if (_selectedImages.length < 5) {
                _selectedImages.add(image);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Maximum 5 photos allowed'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppTheme.error,
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

  Future<void> _createTicket() async {
    if (_selectedPriorityId == null || _selectedStatusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select priority and status'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
    final ticketData = {
        'question_id': widget.question['id'],
        'priority_id': _selectedPriorityId,
        'status_id': _selectedStatusId,
        'discussion': _discussionController.text,
        'description': _descriptionController.text,
        'note': _noteController.text,
      'internal_users': _selectedInternalUsers,
      'external_users': _selectedExternalUsers,
    };

    widget.onCreateTicket(ticketData);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionText = widget.question['question'] as String? ?? 'Question';
    final priority = widget.question['priority'] as Map<String, dynamic>?;
    final priorityTitle = priority?['title'] as String? ?? 'Medium';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Create ticket',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title card
            Container(
              padding: const EdgeInsets.all(16),
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
              ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  const Text(
                    'Task title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                          const SizedBox(height: 8),
                  Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                                ),
                              ],
                            ),
                              ),
            const SizedBox(height: 16),
                          
            // Priority and Status in one row
                          Row(
                            children: [
                              Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButton<int>(
                          value: _selectedPriorityId,
                          isExpanded: true,
                          underline: const SizedBox(),
                                        items: _priorities.map((priority) {
                                          return DropdownMenuItem<int>(
                                            value: priority['id'] as int,
                                            child: Text(
                                              priority['title'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPriorityId = value;
                                          });
                                        },
                                    ),
                                  ],
                                ),
                              ),
                ),
                const SizedBox(width: 12),
                              Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButton<int>(
                          value: _selectedStatusId,
                          isExpanded: true,
                          underline: const SizedBox(),
                                        items: _statuses.map((status) {
                                          return DropdownMenuItem<int>(
                                            value: status['id'] as int,
                                            child: Text(
                                              status['title'] as String? ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedStatusId = value;
                                          });
                                        },
                                    ),
                                  ],
                    ),
                                ),
                              ),
                            ],
                          ),
            const SizedBox(height: 16),

            // Participants Preview Section
                              Container(
              padding: const EdgeInsets.all(16),
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Selected Users Avatars
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ..._internalUsers
                                .where((user) => _selectedInternalUsers.contains(user['id']))
                                .map((user) {
                              final userName = '${user['first_name'] ?? 'User'} ${user['last_name'] ?? ''}'.trim();
                              return Tooltip(
                                message: userName,
                                showDuration: const Duration(seconds: 2),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF3B82F6),
                                  child: Text(
                                    userName[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            ..._externalUsers
                                .where((user) => _selectedExternalUsers.contains(user['id']))
                                .map((user) {
                              final userName = '${user['first_name'] ?? 'User'} ${user['last_name'] ?? ''}'.trim();
                              return Tooltip(
                                message: userName,
                                showDuration: const Duration(seconds: 2),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFF59E0B),
                                  child: Text(
                                    userName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Add button
                            Tooltip(
                              message: 'Add participants',
                              showDuration: const Duration(seconds: 1),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showExternal = !_showExternal;
                                  });
                                },
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFE5E7EB),
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ),
                    ],
                  ),
                  // Expanded User Selection (if add button clicked)
                  if (_showExternal) ...[
                          const SizedBox(height: 16),
                    // BIAL Users
                    if (_internalUsers.isNotEmpty) ...[
                      const Text(
                        'BIAL Users',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                        children: _internalUsers.map((user) {
                          final userId = user['id'] as int;
                          final isSelected = _selectedInternalUsers.contains(userId);
                          final userName = '${user['first_name'] ?? 'User'} ${user['last_name'] ?? ''}'.trim();
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedInternalUsers.remove(userId);
                                } else {
                                  _selectedInternalUsers.add(userId);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFC7D1DB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Concessionaire Users
                    if (_externalUsers.isNotEmpty) ...[
                      const Text(
                        'Concessionaire Users',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                        children: _externalUsers.map((user) {
                          final userId = user['id'] as int;
                          final isSelected = _selectedExternalUsers.contains(userId);
                          final userName = '${user['first_name'] ?? 'User'} ${user['last_name'] ?? ''}'.trim();
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedExternalUsers.remove(userId);
                                } else {
                                  _selectedExternalUsers.add(userId);
                                }
                              });
                            },
                                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFC7D1DB),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                                    );
                        }).toList(),
                                ),
                            ],
                        ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            
            // Location card
            Container(
              padding: const EdgeInsets.all(16),
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 8),
                  Expanded(
                        child: Text(
                          widget.location.isNotEmpty ? widget.location : 'No location',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1F2937),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description card
            Container(
              padding: const EdgeInsets.all(16),
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                              style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add description...',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attachments/Images Section
            Container(
              padding: const EdgeInsets.all(16),
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
        ),
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.5,
                        ),
                      ),
              Text(
                        '${_selectedImages.length}/5',
                style: TextStyle(
                          fontSize: 12,
                  fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                ),
              ),
            ],
          ),
                  const SizedBox(height: 12),
                  if (_selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_selectedImages.length, (index) {
                          final image = _selectedImages[index];
      return Container(
                            width: 80,
                            height: 80,
        decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                            ),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(image.path),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
            ),
          ],
        ),
                          );
                        }),
                      ),
                    ),
                  if (_selectedImages.length < 5)
                    Row(
          children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFC7D1DB),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
            Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: Color(0xFF6B7280),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
            Text(
                                    'Add Photos',
              style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Create Ticket Button
            Container(
              width: double.infinity,
      decoration: BoxDecoration(
                gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3B82F6),
                    Color(0xFF2563EB),
                  ],
        ),
                borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _createTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_circle_outline, size: 18),
                          SizedBox(width: 8),
                      Text(
                            'Create ticket',
                        style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
          ),
            const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }
}
