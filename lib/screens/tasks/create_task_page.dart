import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/task_service.dart';

class CreateTaskPage extends StatefulWidget {
  final int locationId;

  const CreateTaskPage({super.key, required this.locationId});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  int? _selectedStatusId;
  int? _selectedPriorityId;
  List<int> _selectedBialUsers = [];
  List<int> _selectedConcessionareUsers = [];
  List<File> _selectedImages = [];
  DateTime? _startDate;
  DateTime? _dueDate;

  bool _isLoading = true;
  bool _isSubmitting = false;
  
  Map<String, dynamic>? _formData;
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    setState(() {
      _isLoading = true;
    });

    final result = await TaskService.getCreateData(widget.locationId);
    
    if (result['success']) {
      setState(() {
        _formData = result['data'];
        _locationName = _formData!['location']['title'] ?? '';
        _isLoading = false;
      });
      
      // Debug: Print form data structure
      print('Debug - Form data loaded:');
      print('Full formData keys: ${_formData!.keys.toList()}');
      
      final statusesList = _formData!['statuses'];
      final prioritiesList = _formData!['priorities'];
      final bialUsersList = _formData!['bial_users'];
      final concessionareUsersList = _formData!['concessionare_users'];
      
      print('Statuses type: ${statusesList.runtimeType}');
      print('Priorities type: ${prioritiesList.runtimeType}');
      print('BIAL Users type: ${bialUsersList.runtimeType}');
      print('Concessionaire Users type: ${concessionareUsersList.runtimeType}');
      
      print('Statuses count: ${statusesList is List ? statusesList.length : 'NOT A LIST'}');
      print('Priorities count: ${prioritiesList is List ? prioritiesList.length : 'NOT A LIST'}');
      print('BIAL Users count: ${bialUsersList is List ? bialUsersList.length : 'NOT A LIST'}');
      print('Concessionaire Users count: ${concessionareUsersList is List ? concessionareUsersList.length : 'NOT A LIST'}');
      
      if (statusesList is List && statusesList.isNotEmpty) {
        print('First status: ${statusesList[0]}');
        print('First status type: ${statusesList[0].runtimeType}');
        if (statusesList[0] is Map) {
          print('First status keys: ${(statusesList[0] as Map).keys.toList()}');
        }
      }
      if (prioritiesList is List && prioritiesList.isNotEmpty) {
        print('First priority: ${prioritiesList[0]}');
        print('First priority type: ${prioritiesList[0].runtimeType}');
        if (prioritiesList[0] is Map) {
          print('First priority keys: ${(prioritiesList[0] as Map).keys.toList()}');
        }
      }
      if (bialUsersList is List && bialUsersList.isNotEmpty) {
        print('BIAL Users list: $bialUsersList');
      } else {
        print('WARNING: BIAL Users list is empty or not a list');
      }
      if (concessionareUsersList is List && concessionareUsersList.isNotEmpty) {
        print('Concessionaire Users list: $concessionareUsersList');
      } else {
        print('WARNING: Concessionaire Users list is empty or not a list');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load form data'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _selectDate(DateTime? initialDate, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        final DateTime dateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );

        setState(() {
          if (isStartDate) {
            _startDate = dateTime;
          } else {
            _dueDate = dateTime;
          }
        });
      }
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      setState(() {
        final List<File> newImages = images.map((xFile) => File(xFile.path)).toList();
        if (_selectedImages.length + newImages.length <= 5) {
          _selectedImages.addAll(newImages);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You can only upload a maximum of 5 images'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required bool required,
    required IconData icon,
    required int? value,
    required List<dynamic> items,
    Function(int?)? onChanged,
    String? Function(int?)? validator,
    required int Function(dynamic) getItemId,
    required String Function(dynamic) getItemTitle,
    bool includeNone = false,
  }) {
    return Container(
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
      child: DropdownButtonFormField<int>(
        value: value,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: 'Select $label',
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF8B5CF6),
              size: 18,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF8B5CF6),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        isExpanded: true,
        items: [
          if (includeNone)
            const DropdownMenuItem<int>(
              value: null,
              child: Text('None'),
            ),
          if (items.isNotEmpty)
            ...items.map<DropdownMenuItem<int>>((item) {
              try {
                final itemId = getItemId(item);
                final itemTitle = getItemTitle(item);
                
                return DropdownMenuItem<int>(
                  value: itemId,
                  child: Text(itemTitle),
                );
              } catch (e) {
                print('Error creating dropdown item: $e');
                return const DropdownMenuItem<int>(
                  value: 0,
                  child: Text('Error'),
                );
              }
            })
          else
            const DropdownMenuItem<int>(
              value: -1,
              child: Text('No options available'),
              enabled: false,
            ),
        ],
        onChanged: items.isNotEmpty && onChanged != null ? onChanged : null,
        validator: validator,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8B5CF6),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? _formatDateTime(date) : 'Select date & time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey[400]!,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedStatusId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a status'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_startDate == null || _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and due dates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date must be after start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Convert images to base64
    List<String> base64Images = [];
    for (var imageFile in _selectedImages) {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      // Determine image type from extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'png' : 'jpeg';
      base64Images.add('data:image/$mimeType;base64,$base64String');
    }

    final taskData = {
      'title': _titleController.text.trim(),
      'status_id': _selectedStatusId,
      'priority_id': _selectedPriorityId,
      'start_date': _startDate!.toIso8601String().split('.')[0],
      'due_date': _dueDate!.toIso8601String().split('.')[0],
      'description': _descriptionController.text.trim(),
      'note': _noteController.text.trim(),
      'project_id': widget.locationId,
      'bial_users_id': _selectedBialUsers.isNotEmpty ? _selectedBialUsers : null,
      'concessionare_users_id': _selectedConcessionareUsers.isNotEmpty ? _selectedConcessionareUsers : null,
      'images': base64Images.isNotEmpty ? base64Images : null,
    };

    final result = await TaskService.createTask(taskData);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Task created successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to create task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _formData == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B5CF6).withOpacity(0.1),
                Colors.white,
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
        ),
      );
    }

    // Ensure we have the data before building dropdowns
    final statusesList = _formData!['statuses'];
    final prioritiesList = _formData!['priorities'];
    
    // Convert to proper List format
    final List<dynamic> statuses = statusesList is List ? List.from(statusesList) : [];
    final List<dynamic> priorities = prioritiesList is List ? List.from(prioritiesList) : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
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
            icon: const Icon(Icons.arrow_back, color: Color(0xFF8B5CF6)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Create Task',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location display with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B5CF6),
                      const Color(0xFF6D28D9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _locationName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              _buildSectionTitle('Task Details'),
              const SizedBox(height: 12),
              Container(
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
                child: TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter task title',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.title,
                        color: Color(0xFF8B5CF6),
                        size: 18,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Status and Priority row
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use column layout on smaller screens to prevent overflow
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        _buildDropdownField(
                          label: 'Status',
                          required: true,
                          icon: Icons.info_outline,
                          value: _selectedStatusId,
                          items: statuses,
                          onChanged: statuses.isNotEmpty
                              ? (value) {
                                  if (value != null && value != -1) {
                                    setState(() {
                                      _selectedStatusId = value;
                                    });
                                  }
                                }
                              : null,
                          validator: (value) {
                            if (value == null || value == -1) {
                              return 'Please select a status';
                            }
                            return null;
                          },
                          getItemId: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['id'] is int 
                                ? itemMap['id'] as int 
                                : (itemMap['id'] as num?)?.toInt() ?? 0;
                          },
                          getItemTitle: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['title']?.toString() ?? 'Unknown';
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Priority',
                          required: false,
                          icon: Icons.priority_high,
                          value: _selectedPriorityId,
                          items: priorities,
                          onChanged: (value) {
                            setState(() {
                              _selectedPriorityId = value;
                            });
                          },
                          includeNone: true,
                          getItemId: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['id'] is int 
                                ? itemMap['id'] as int 
                                : (itemMap['id'] as num?)?.toInt() ?? 0;
                          },
                          getItemTitle: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['title']?.toString() ?? 'Unknown';
                          },
                        ),
                      ],
                    );
                  }
                  
                  // Use row layout on larger screens
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          label: 'Status',
                          required: true,
                          icon: Icons.info_outline,
                          value: _selectedStatusId,
                          items: statuses,
                          onChanged: statuses.isNotEmpty
                              ? (value) {
                                  if (value != null && value != -1) {
                                    setState(() {
                                      _selectedStatusId = value;
                                    });
                                  }
                                }
                              : null,
                          validator: (value) {
                            if (value == null || value == -1) {
                              return 'Please select a status';
                            }
                            return null;
                          },
                          getItemId: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['id'] is int 
                                ? itemMap['id'] as int 
                                : (itemMap['id'] as num?)?.toInt() ?? 0;
                          },
                          getItemTitle: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['title']?.toString() ?? 'Unknown';
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownField(
                          label: 'Priority',
                          required: false,
                          icon: Icons.priority_high,
                          value: _selectedPriorityId,
                          items: priorities,
                          onChanged: (value) {
                            setState(() {
                              _selectedPriorityId = value;
                            });
                          },
                          includeNone: true,
                          getItemId: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['id'] is int 
                                ? itemMap['id'] as int 
                                : (itemMap['id'] as num?)?.toInt() ?? 0;
                          },
                          getItemTitle: (item) {
                            final itemMap = item is Map 
                                ? Map<String, dynamic>.from(item as Map) 
                                : <String, dynamic>{};
                            return itemMap['title']?.toString() ?? 'Unknown';
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Start Date and Due Date
              _buildSectionTitle('Schedule'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(
                      label: 'Start Date',
                      icon: Icons.calendar_today,
                      date: _startDate,
                      onTap: () => _selectDate(_startDate, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(
                      label: 'Due Date',
                      icon: Icons.event,
                      date: _dueDate,
                      onTap: () => _selectDate(_dueDate, false),
                    ),
                  ),
                ],
              ),

              // BIAL Users
              if ((_formData!['bial_users'] as List).isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Assign Users'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.people,
                              color: Color(0xFF8B5CF6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'BIAL Users',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (_formData!['bial_users'] as List).map((user) {
                          final isSelected = _selectedBialUsers.contains(user['id']);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedBialUsers.remove(user['id']);
                                } else {
                                  _selectedBialUsers.add(user['id']);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  else
                                    Icon(
                                      Icons.circle_outlined,
                                      color: Colors.grey[600],
                                      size: 16,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user['name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
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
                ),
              ],

              // Concessionare Users
              if ((_formData!['concessionare_users'] as List).isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.group,
                              color: Color(0xFF8B5CF6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Concessionare Users',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (_formData!['concessionare_users'] as List).map((user) {
                          final isSelected = _selectedConcessionareUsers.contains(user['id']);
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedConcessionareUsers.remove(user['id']);
                                } else {
                                  _selectedConcessionareUsers.add(user['id']);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF8B5CF6)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.grey[300]!,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  else
                                    Icon(
                                      Icons.circle_outlined,
                                      color: Colors.grey[600],
                                      size: 16,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    user['name'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
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
                ),
              ],

              // Images
              const SizedBox(height: 20),
              _buildSectionTitle('Attachments'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.image,
                              color: Color(0xFF8B5CF6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Task Images',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_selectedImages.length}/5',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectedImages.length < 5)
                      InkWell(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF8B5CF6),
                                const Color(0xFF6D28D9),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Images',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: List.generate(_selectedImages.length, (index) {
                          return Stack(
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImages[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              // Description
              const SizedBox(height: 20),
              _buildSectionTitle('Additional Information'),
              const SizedBox(height: 12),
              Container(
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
                child: TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter task description...',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: Color(0xFF8B5CF6),
                        size: 18,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Container(
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
                child: TextFormField(
                  controller: _noteController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Note',
                    hintText: 'Add any additional notes...',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.note,
                        color: Color(0xFF8B5CF6),
                        size: 18,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF8B5CF6),
                      const Color(0xFF6D28D9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_task,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Create Task',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

