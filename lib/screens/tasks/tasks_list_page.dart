import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import 'task_detail_page.dart';

extension StringCapitalization on String {
  String capitalize() {
    return isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
  }
}

class TasksListPage extends StatefulWidget {
  const TasksListPage({super.key});

  @override
  State<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends State<TasksListPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _refreshing = false;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  String? _errorMessage;
  String _selectedFilter = 'all';
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Accordion expansion states - default to all expanded
  final Map<String, bool> _expandedSections = {
    'PENDING': true,
    'IN PROGRESS': true,
    'COMPLETED': true,
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bgController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    
    _fadeController.forward();
    _slideController.forward();
    _loadTasks();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    if (!isRefresh) {
      _fadeController.reset();
    }

    final result = await TaskService.getUserTasks();

    if (mounted) {
      if (result['success']) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _applyFilter();
          _isLoading = false;
          _refreshing = false;
        });
        if (!isRefresh) {
          _fadeController.forward();
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load tasks';
          _isLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredTasks = _tasks;
      } else if (_selectedFilter == 'pending') {
        _filteredTasks = _tasks.where((task) {
          final status = task['status'];
          return status != null &&
              status['title'].toLowerCase() != 'completed' &&
              status['title'].toLowerCase() != 'done' &&
              status['title'].toLowerCase() != 'closed';
        }).toList();
      } else if (_selectedFilter == 'completed') {
        _filteredTasks = _tasks.where((task) {
          final status = task['status'];
          return status != null &&
              (status['title'].toLowerCase() == 'completed' ||
                  status['title'].toLowerCase() == 'done' ||
                  status['title'].toLowerCase() == 'closed');
        }).toList();
      }
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final taskDate = DateTime(date.year, date.month, date.day);

      if (taskDate == today) {
        return 'Today';
      } else if (taskDate == yesterday) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'primary':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'danger':
        return Colors.red;
      case 'secondary':
        return Colors.grey;
      case 'info':
        return Colors.cyan;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          _buildBackgroundGraphics(),
          SafeArea(
            child: Column(
              children: [
                // Fixed header at the top
                _buildHeaderSection(),
                // Scrollable content below
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
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
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _loadTasks(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadTasks(isRefresh: true),
                              color: AppTheme.primaryPurple,
                              child: _filteredTasks.isEmpty
                                  ? _buildEmptyState()
                                  : _buildContent(),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Container(
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
                    onTap: () => Navigator.pushReplacementNamed(context, '/home'),
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
                    'My Tasks',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // Sort button
                GestureDetector(
                  onTap: () {
                    // TODO: Implement sort functionality
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sort by Title',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.grey[700]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    // Group tasks by status
    final Map<String, List<Map<String, dynamic>>> groupedTasks = {
      'PENDING': [],
      'IN PROGRESS': [],
      'COMPLETED': [],
    };
    
    for (var task in _filteredTasks) {
      final status = task['status'];
      String statusKey = 'PENDING';
      if (status != null) {
        final statusTitle = (status['title'] ?? '').toString().toUpperCase();
        if (statusTitle.contains('COMPLETED') || statusTitle.contains('DONE') || statusTitle.contains('CLOSED')) {
          statusKey = 'COMPLETED';
        } else if (statusTitle.contains('PROGRESS') || statusTitle.contains('IN PROGRESS')) {
          statusKey = 'IN PROGRESS';
        } else {
          statusKey = 'PENDING';
        }
      }
      groupedTasks[statusKey]!.add(task);
    }
    
    final statusOrder = ['PENDING', 'IN PROGRESS', 'COMPLETED'];
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Showing count with refresh indicator
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing ${_filteredTasks.length} of ${_tasks.length} tasks',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_refreshing)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Accordion groups
          Expanded(
            child: ListView.builder(
              itemCount: statusOrder.length,
              itemBuilder: (context, index) {
                final status = statusOrder[index];
                final items = groupedTasks[status]!;
                
                // Skip empty sections
                if (items.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return _buildAccordionSection(status, items);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionSection(String status, List<Map<String, dynamic>> items) {
    final isExpanded = _expandedSections[status] ?? true;
    final statusColor = _getStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Accordion header
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[status] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status title and count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${items.length} ${items.length == 1 ? 'task' : 'tasks'}',
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
                  // Expand/collapse icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Accordion content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskCard(
                      task: item,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFF59E0B); // Orange
      case 'IN PROGRESS':
        return const Color(0xFF3B82F6); // Blue
      case 'COMPLETED':
        return const Color(0xFF10B981); // Green
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.pending_actions;
      case 'IN PROGRESS':
        return Icons.timelapse;
      case 'COMPLETED':
        return Icons.check_circle;
      default:
        return Icons.list;
    }
  }

  Widget _buildBackgroundGraphics() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return CustomPaint(
            painter: TasksBackgroundPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      height: 24,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 24,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.task_alt,
                    size: 50,
                    color: const Color(0xFF8B5CF6).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _selectedFilter == 'all'
                      ? 'No tasks yet'
                      : _selectedFilter == 'completed'
                          ? 'No completed tasks'
                          : 'No pending tasks',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFilter == 'all'
                      ? 'All your tasks will appear here'
                      : _selectedFilter == 'completed'
                          ? 'Keep completing tasks to see them here!'
                          : 'All your tasks are completed! 🎉',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                if (_selectedFilter != 'all')
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton(
                      onPressed: () {
                        _selectedFilter = 'all';
                        _applyFilter();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('View All Tasks'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }



}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final status = task['status'];
    final priority = task['priority'];
    final isOverdue = _isOverdue(task['due_date']);
    final statusColor = _getStatusColorFromTask(status);
    
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailPage(taskId: task['id']),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with accent bar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task['title'] ?? 'Untitled Task',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Status and Priority chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status['title'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  if (priority != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorFromString(priority['color'] ?? 'primary').withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priority['title'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getColorFromString(priority['color'] ?? 'primary'),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Due date
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(task['due_date']),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              // Users avatars
              if ((task['users'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ..._buildUserAvatars(task),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primaryPurple),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColorFromTask(dynamic status) {
    if (status == null) return Colors.grey;
    final statusTitle = (status['title'] ?? '').toString().toUpperCase();
    if (statusTitle.contains('COMPLETED') || statusTitle.contains('DONE') || statusTitle.contains('CLOSED')) {
      return const Color(0xFF10B981);
    } else if (statusTitle.contains('PROGRESS') || statusTitle.contains('IN PROGRESS')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFFF59E0B);
  }

  bool _isOverdue(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return date.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final taskDate = DateTime(date.year, date.month, date.day);

      if (taskDate == today) {
        return 'Today';
      } else if (taskDate == yesterday) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'primary':
        return Colors.blue;
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'danger':
        return Colors.red;
      case 'secondary':
        return Colors.grey;
      case 'info':
        return Colors.cyan;
      default:
        return Colors.blue;
    }
  }

  List<Widget> _buildUserAvatars(Map<String, dynamic> task) {
    final users = (task['users'] as List?) ?? [];
    final displayCount = users.length > 3 ? 3 : users.length;
    final widgets = <Widget>[];

    for (int i = 0; i < displayCount; i++) {
      final user = users[i];
      final firstName = user['first_name'] ?? '';
      final lastName = user['last_name'] ?? '';
      final fullName = [firstName, lastName].where((n) => n.isNotEmpty).join(' ');
      final displayName = fullName.isNotEmpty ? fullName : 'Unknown User';
      final initial = firstName.isNotEmpty
          ? firstName.substring(0, 1).toUpperCase()
          : '?';

      widgets.add(
        Tooltip(
          message: displayName,
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            margin: EdgeInsets.only(left: i * 16.0),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryPurple.withOpacity(0.7 - (i * 0.15)),
                  const Color(0xFF3B82F6).withOpacity(0.7 - (i * 0.15)),
                ],
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (users.length > 3) {
      // Show remaining users count with tooltip
      final remainingUsers = users.skip(3).map((u) {
        final fn = u['first_name'] ?? '';
        final ln = u['last_name'] ?? '';
        return [fn, ln].where((n) => n.isNotEmpty).join(' ');
      }).where((n) => n.isNotEmpty).toList();
      final remainingNames = remainingUsers.join(', ');
      
      widgets.add(
        Tooltip(
          message: remainingNames.isNotEmpty ? remainingNames : '${users.length - 3} more users',
          waitDuration: const Duration(milliseconds: 500),
          child: Container(
            margin: EdgeInsets.only(left: 3 * 16.0),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.grey[300],
            ),
            child: Center(
              child: Text(
                '+${users.length - 3}',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

class TasksBackgroundPainter extends CustomPainter {
  final double progress;

  TasksBackgroundPainter({this.progress = 0});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryPurple.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    // Draw flowing background shapes
    final path = Path();
    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.2,
      size.width * 0.4, size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.6, size.height * 0.5,
      size.width * 0.8, size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width, size.height * 0.3,
      size.width, size.height,
    );
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Animated floating elements
    final pulsate = (0.5 + 0.5 * math.sin(progress * 2 * math.pi)).clamp(0.6, 1.0);
    final pulsate2 = (0.5 + 0.5 * math.cos(progress * 2 * math.pi)).clamp(0.6, 1.0);
    
    // Top circles - Green
    final paint2 = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.2 * pulsate)
      ..style = PaintingStyle.fill;

    final dx1 = size.width * (0.75 + 0.08 * math.sin(progress * 2 * math.pi));
    final dy1 = size.height * (0.18 + 0.05 * math.cos(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx1, dy1), 40 + 12 * pulsate, paint2);

    // Top circles - Purple
    final paint3 = Paint()
      ..color = AppTheme.primaryPurple.withOpacity(0.18 * pulsate2)
      ..style = PaintingStyle.fill;
    final dx3 = size.width * (0.15 + 0.07 * math.cos(progress * 2 * math.pi));
    final dy3 = size.height * (0.12 + 0.04 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx3, dy3), 32 + 10 * pulsate2, paint3);

    // Top circles - Teal
    final paint4 = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.15 * pulsate)
      ..style = PaintingStyle.fill;
    final dx4 = size.width * (0.55 + 0.09 * math.sin(progress * 2 * math.pi));
    final dy4 = size.height * (0.08 + 0.06 * math.cos(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx4, dy4), 28 + 8 * pulsate, paint4);

    // Bottom circles
    final dx2 = size.width * (0.25 + 0.06 * math.cos(progress * 2 * math.pi));
    final dy2 = size.height * (0.82 + 0.05 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx2, dy2), 35 + 10 * (1 - pulsate), paint2);

    // Middle floating circle
    final paint7 = Paint()
      ..color = AppTheme.primaryPurple.withOpacity(0.15 * pulsate)
      ..style = PaintingStyle.fill;
    final dx7 = size.width * (0.5 + 0.1 * math.cos(progress * 2 * math.pi));
    final dy7 = size.height * (0.6 + 0.08 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx7, dy7), 30 + 8 * pulsate, paint7);

    // Soft moving gradient blobs
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(0.25),
          AppTheme.primaryPurple.withOpacity(0.05),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * (0.4 + 0.15 * math.sin(progress * 2 * math.pi)),
            size.height * (0.35 + 0.08 * math.cos(progress * 2 * math.pi))),
        radius: 120,
      ));
    canvas.drawCircle(
      Offset(size.width * (0.4 + 0.15 * math.sin(progress * 2 * math.pi)),
          size.height * (0.35 + 0.08 * math.cos(progress * 2 * math.pi))),
      120,
      blobPaint,
    );

    // Additional gradient blob
    final blobPaint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF10B981).withOpacity(0.2),
          const Color(0xFF10B981).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * (0.7 + 0.12 * math.cos(progress * 2 * math.pi)),
            size.height * (0.65 + 0.1 * math.sin(progress * 2 * math.pi))),
        radius: 100,
      ));
    canvas.drawCircle(
      Offset(size.width * (0.7 + 0.12 * math.cos(progress * 2 * math.pi)),
          size.height * (0.65 + 0.1 * math.sin(progress * 2 * math.pi))),
      100,
      blobPaint2,
    );
  }

  @override
  bool shouldRepaint(covariant TasksBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
