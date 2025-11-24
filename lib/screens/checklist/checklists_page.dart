import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'checklist_detail_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../checklist/checklist_qr_scanner_page.dart';
import '../tasks/qr_scanner_page.dart';

class ChecklistsPage extends StatefulWidget {
  const ChecklistsPage({super.key});

  @override
  State<ChecklistsPage> createState() => _ChecklistsPageState();
}

class _ChecklistsPageState extends State<ChecklistsPage> with TickerProviderStateMixin {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  List<dynamic> _checklists = [];
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Accordion expansion states - default to all expanded
  final Map<String, bool> _expandedSections = {
    'ACTIVE': true,
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
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _load({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    
    // Debug: Check what's stored
    await AuthService.debugStoredData();
    
    final res = await AuthService.fetchChecklists();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _checklists = (res['data']['checklists'] as List?) ?? [];
        _loading = false;
        _refreshing = false;
      });
    } else {
      setState(() {
        _error = res['message'] ?? 'Failed to load checklists';
        _loading = false;
        _refreshing = false;
      });
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
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
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
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _load(isRefresh: true),
                              child: AnimatedBuilder(
                                animation: _fadeAnimation,
                                builder: (context, child) {
                                  return FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: SlideTransition(
                                      position: _slideAnimation,
                                      child: _buildContent(),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
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
            // Add Checklist option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3182CE).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: Color(0xFF3182CE),
                  size: 24,
                ),
              ),
              title: const Text(
                'Audit Store',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Create a new checklist',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChecklistQRScannerPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Add Task option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              title: const Text(
                'Add Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Create a new task',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QRScannerPage(),
                  ),
                );
              },
            ),
          ],
        ),
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
                    'Checklists',
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
    // Group checklists by status
    final Map<String, List<dynamic>> groupedChecklists = {
      'ACTIVE': [],
      'IN PROGRESS': [],
      'COMPLETED': [],
    };
    
    for (var checklist in _checklists) {
      final status = (checklist['status'] ?? '').toString().toUpperCase();
      if (groupedChecklists.containsKey(status)) {
        groupedChecklists[status]!.add(checklist);
      } else {
        // If status doesn't match, add to ACTIVE by default
        groupedChecklists['ACTIVE']!.add(checklist);
      }
    }
    
    // Define order: ACTIVE first, then IN PROGRESS, then COMPLETED
    final statusOrder = ['ACTIVE', 'IN PROGRESS', 'COMPLETED'];
    
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
                    'Showing ${_checklists.length} of ${_checklists.length} checklists',
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
                final items = groupedChecklists[status]!;
                
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
  
  Widget _buildAccordionSection(String status, List<dynamic> items) {
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
                          '${items.length} ${items.length == 1 ? 'checklist' : 'checklists'}',
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
                    child: _ChecklistCard(
                      item: item as Map<String, dynamic>,
                      onNavigateBack: () => _load(isRefresh: true),
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
      case 'ACTIVE':
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
      case 'ACTIVE':
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
            painter: ChecklistsBackgroundPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }
}

class _ChecklistCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onNavigateBack;
  const _ChecklistCard({required this.item, this.onNavigateBack});

  @override
  State<_ChecklistCard> createState() => _ChecklistCardState();
}

class _ChecklistCardState extends State<_ChecklistCard> {
  int _pendingTicketsCount = 0;
  bool _loadingTickets = false;
  Map<String, dynamic>? _adjustedProgress;

  @override
  void initState() {
    super.initState();
    _loadTicketsAndCalculateProgress();
  }

  Future<void> _loadTicketsAndCalculateProgress() async {
    setState(() {
      _loadingTickets = true;
    });

    try {
      final userData = await AuthService.getUserData();
      if (userData == null || userData['token'] == null) {
        return;
      }

      // Fetch checklist detail to get tickets and questions data
      final checklistId = widget.item['id'] as int;
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/api/auditor/checklists/$checklistId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${userData['token']}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final checklistData = data['data'];
          final tickets = checklistData['tickets'] as Map<String, dynamic>? ?? {};
          final answers = checklistData['answers'] as Map<String, dynamic>? ?? {};
          final checklist = checklistData['checklist'] as Map<String, dynamic>?;
          final theme = checklist?['theme'] as Map<String, dynamic>?;
          final groups = theme?['groups'] as List<dynamic>? ?? [];

          // Calculate pending tickets count (tickets that are not completed/resolved/closed)
          int pendingTickets = 0;
          int totalQuestions = 0;
          int answeredQuestions = 0;
          int lockedQuestions = 0;

          for (var group in groups) {
            final groupData = group as Map<String, dynamic>;
            final questions = groupData['questions'] as List<dynamic>? ?? [];

            for (var question in questions) {
              final questionData = question as Map<String, dynamic>;
              final questionId = questionData['id'] as int;
              totalQuestions++;

              // Check if question has an answer
              bool hasAnswer = false;
              if (answers.containsKey(questionId.toString())) {
                final answer = answers[questionId.toString()];
                if (answer != null && answer is Map) {
                  final value = answer['value'];
                  if (value != null && value.toString().isNotEmpty) {
                    hasAnswer = true;
                  }
                }
              }

              // Check if question is locked (has a ticket that's not completed)
              bool isLocked = false;
              if (tickets.containsKey(questionId.toString())) {
                final ticket = tickets[questionId.toString()] as Map<String, dynamic>?;
                final ticketStatus = ticket?['ticket_status'] as Map<String, dynamic>?;
                final ticketStatusTitle = ticketStatus?['title'] as String? ?? '';
                final isTicketCompleted = ticketStatusTitle.toLowerCase().contains('completed') ||
                    ticketStatusTitle.toLowerCase().contains('complete') ||
                    ticketStatusTitle.toLowerCase().contains('resolved') ||
                    ticketStatusTitle.toLowerCase().contains('closed');
                
                if (!isTicketCompleted) {
                  isLocked = true;
                  lockedQuestions++;
                  pendingTickets++;
                }
              }

              // Count as completed if it has an answer OR is locked (locked = completed for checklist completion)
              // This allows checklist to be marked as completed even if some questions are locked
              if (hasAnswer || isLocked) {
                answeredQuestions++;
              }
            }
          }

          // Calculate adjusted progress
          int adjustedAnswered = answeredQuestions; // This already includes locked questions
          int adjustedTotal = totalQuestions;
          int adjustedPercent = adjustedTotal > 0
              ? ((adjustedAnswered / adjustedTotal) * 100).round()
              : 0;

          // Determine status
          String adjustedStatus;
          if (adjustedTotal == 0) {
            adjustedStatus = 'No Questions';
          } else if (adjustedAnswered == 0) {
            adjustedStatus = 'Not Started';
          } else if (adjustedAnswered == adjustedTotal) {
            adjustedStatus = 'Completed';
          } else {
            adjustedStatus = 'In Progress';
          }

          if (mounted) {
            setState(() {
              _pendingTicketsCount = pendingTickets;
              _adjustedProgress = {
                'answered': adjustedAnswered,
                'total': adjustedTotal,
                'percent': adjustedPercent,
                'status': adjustedStatus,
                'answered_total': '$adjustedAnswered/$adjustedTotal',
              };
              _loadingTickets = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading tickets: $e');
      if (mounted) {
        setState(() {
          _loadingTickets = false;
        });
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'NOT STARTED':
        return const Color(0xFFF59E0B); // Orange
      case 'IN PROGRESS':
        return const Color(0xFF3B82F6); // Blue
      case 'COMPLETED':
        return const Color(0xFF10B981); // Green
      case 'NO QUESTIONS':
        return const Color(0xFF6B7280); // Grey
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use adjusted progress if available, otherwise use original
    final progress = _adjustedProgress ?? {
      'answered_total': widget.item['answered_total'] ?? '0/0',
      'percent': widget.item['percent'] ?? 0,
      'status': _calculateStatusFromItem(),
    };

    final answeredTotal = (progress['answered_total'] ?? '0/0').toString();
    final parts = answeredTotal.split('/');
    final answered = int.tryParse(parts[0]) ?? 0;
    final total = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    
    final actualStatus = progress['status'] as String? ?? _calculateStatusFromItem();
    final percent = (progress['percent'] as num?)?.toInt() ?? (widget.item['percent'] ?? 0) as int;
    final color = _statusColor(actualStatus);
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Navigate to detail page and wait for return
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistDetailPage(
                  checklistId: widget.item['id'] as int,
                  checklistTitle: (widget.item['title'] ?? 'Checklist').toString(),
                ),
              ),
            );
            
            // Refresh data when returning from detail page
            widget.onNavigateBack?.call();
            // Reload tickets and progress
            _loadTicketsAndCalculateProgress();
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and completion status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (widget.item['title'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        answeredTotal,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: -0.2,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                
                // Location with icon
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (widget.item['location'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey[600], 
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // First question and status
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.checklist_rounded, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (widget.item['first_question'] ?? '').toString(),
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          actualStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.w700, 
                            color: color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Progress bar with percentage
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (percent / 100.0).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          color: color,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Pending tickets display (if any)
                if (_pendingTicketsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 14,
                          color: const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_pendingTicketsCount ${_pendingTicketsCount == 1 ? 'pending ticket' : 'pending tickets'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Due and Next dates - more compact
                Row(
                  children: [
                    Expanded(
                      child: _buildDateChip(
                        Icons.calendar_today_rounded,
                        'Due',
                        (widget.item['due_date'] ?? '').toString(),
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDateChip(
                        Icons.schedule_rounded,
                        'Next',
                        (widget.item['next_time'] ?? '').toString(),
                        Colors.blue,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _calculateStatusFromItem() {
    final answeredTotal = (widget.item['answered_total'] ?? '0/0').toString();
    final parts = answeredTotal.split('/');
    final answered = int.tryParse(parts[0]) ?? 0;
    final total = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    
    if (total == 0) {
      return 'No Questions';
    } else if (answered == 0) {
      return 'Not Started';
    } else if (answered == total) {
      return 'Completed';
    } else {
      return 'In Progress';
    }
  }

  Widget _buildDateChip(IconData icon, String label, String date, Color color) {
    // Format date to be more compact
    final formattedDate = date.replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = formattedDate.split(',');
    final displayDate = parts.isNotEmpty ? parts[0] : formattedDate;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  displayDate,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChecklistsBackgroundPainter extends CustomPainter {
  final double progress; // 0..1

  ChecklistsBackgroundPainter({this.progress = 0});
  
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

    // Top circles - Purple (smaller)
    final paint5 = Paint()
      ..color = AppTheme.primaryPurple.withOpacity(0.12 * pulsate2)
      ..style = PaintingStyle.fill;
    final dx5 = size.width * (0.9 + 0.05 * math.cos(progress * 2 * math.pi));
    final dy5 = size.height * (0.15 + 0.05 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx5, dy5), 24 + 6 * pulsate2, paint5);

    // Top circles - Green (smaller)
    final paint6 = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.14 * pulsate)
      ..style = PaintingStyle.fill;
    final dx6 = size.width * (0.35 + 0.08 * math.sin(progress * 2 * math.pi));
    final dy6 = size.height * (0.22 + 0.04 * math.cos(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx6, dy6), 26 + 7 * pulsate, paint6);

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
  bool shouldRepaint(covariant ChecklistsBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// New page for displaying checklists filtered by location
class ChecklistsByLocationPage extends StatefulWidget {
  final String locationId;
  
  const ChecklistsByLocationPage({super.key, required this.locationId});

  @override
  State<ChecklistsByLocationPage> createState() => _ChecklistsByLocationPageState();
}

class _ChecklistsByLocationPageState extends State<ChecklistsByLocationPage> with TickerProviderStateMixin {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _locationName;
  List<dynamic> _checklists = [];
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final Map<String, bool> _expandedSections = {
    'ACTIVE': true,
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
    _load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _load({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    
    try {
      final userData = await AuthService.getUserData();
      if (userData == null || userData['token'] == null) {
        throw Exception('No authentication token found');
      }

      print('Loading checklists for location: ${widget.locationId}');

      // First, fetch location details to get the location name
      String? fetchedLocationName;
      try {
        // Try to fetch location by ID
        var locationUrl = '${AuthService.baseUrl}/api/locations/${widget.locationId}';
        print('Fetching location from: $locationUrl');
        
        final locationResponse = await http.get(
          Uri.parse(locationUrl),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${userData['token']}',
          },
        ).timeout(const Duration(seconds: 10));

        print('Location response status: ${locationResponse.statusCode}');
        print('Location response body: ${locationResponse.body}');

        if (locationResponse.statusCode == 200) {
          final locationData = jsonDecode(locationResponse.body);
          print('Location data: $locationData');
          
          if (locationData['success'] == true && locationData['data'] != null) {
            final data = locationData['data'];
            fetchedLocationName = data['title'] ?? 
                                 data['name'] ?? 
                                 data['location_id'];
            
            if (fetchedLocationName != null && fetchedLocationName!.isNotEmpty) {
              print('✓ Fetched location name: $fetchedLocationName');
            } else {
              print('✗ Location data had no title/name field');
              fetchedLocationName = null;
            }
          } else {
            print('✗ Location API returned success false or no data');
            fetchedLocationName = null;
          }
        } else {
          print('✗ Location fetch failed with status: ${locationResponse.statusCode}');
          fetchedLocationName = null;
        }
      } catch (e) {
        print('✗ Error fetching location details: $e');
        fetchedLocationName = null;
      }
      
      // If location name not found, it will be set from checklists response below
      print('Location name after API call: $fetchedLocationName');

      // Fetch checklists filtered by location_id from the API
      // The API now supports location_id parameter for filtering
      print('=== CHECKLIST FILTER DEBUG ===');
      print('widget.locationId: ${widget.locationId}');
      print('widget.locationId type: ${widget.locationId.runtimeType}');
      
      final Uri checklistUri = Uri.parse('${AuthService.baseUrl}/api/auditor/checklists')
          .replace(queryParameters: {'location_id': widget.locationId});
      
      print('Fetching from: $checklistUri');
      print('Query parameters: ${checklistUri.queryParameters}');
      
      final response = await http.get(
        checklistUri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${userData['token']}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final checklists = (data['data']['checklists'] as List?) ?? [];
          print('Checklists received from API for location ${widget.locationId}: ${checklists.length}');
          
          // If location name not fetched from API, try to get it from the first checklist's location field
          String? finalLocationName = fetchedLocationName;
          if (finalLocationName == null && checklists.isNotEmpty) {
            try {
              final firstChecklist = checklists.first as Map<String, dynamic>;
              print('First checklist data: $firstChecklist');
              
              // Try to get location from the checklist's location field (formatted as "WORKSPACE • PROJECT")
              final location = firstChecklist['location'];
              if (location != null && location.toString().isNotEmpty) {
                finalLocationName = location.toString();
                print('✓ Got location name from checklist location field: $finalLocationName');
              } else {
                // Fallback to project title
                final project = firstChecklist['project'] as Map<String, dynamic>?;
                if (project != null && project['title'] != null) {
                  finalLocationName = project['title'];
                  print('✓ Got location name from project title: $finalLocationName');
                }
              }
            } catch (e) {
              print('Could not extract location name from checklist: $e');
            }
          }
          
          setState(() {
            _checklists = checklists;
            // Use fetched location name, then from checklist location/project, fallback to locationId
            _locationName = finalLocationName ?? widget.locationId;
            print('Final location name: $_locationName');
            _loading = false;
            _refreshing = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load checklists');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading checklists: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
        _refreshing = false;
      });
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
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
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
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _load,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _checklists.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.checklist_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No checklists found for this location',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: () => _load(isRefresh: true),
                                  child: AnimatedBuilder(
                                    animation: _fadeAnimation,
                                    builder: (context, child) {
                                      return FadeTransition(
                                        opacity: _fadeAnimation,
                                        child: SlideTransition(
                                          position: _slideAnimation,
                                          child: _buildContent(),
                                        ),
                                      );
                                    },
                                  ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checklists',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_locationName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _locationName ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Group checklists by status
    final Map<String, List<dynamic>> groupedChecklists = {
      'ACTIVE': [],
      'IN PROGRESS': [],
      'COMPLETED': [],
    };
    
    for (var checklist in _checklists) {
      final status = (checklist['status'] ?? '').toString().toUpperCase();
      if (groupedChecklists.containsKey(status)) {
        groupedChecklists[status]!.add(checklist);
      } else {
        groupedChecklists['ACTIVE']!.add(checklist);
      }
    }
    
    final statusOrder = ['ACTIVE', 'IN PROGRESS', 'COMPLETED'];
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Showing count with refresh indicator
          Row(
            children: [
              Expanded(
                child: Text(
                  'Showing ${_checklists.length} of ${_checklists.length} checklists',
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
          const SizedBox(height: 16),
          // Accordion groups
          Expanded(
            child: ListView.builder(
              itemCount: statusOrder.length,
              itemBuilder: (context, index) {
                final status = statusOrder[index];
                final items = groupedChecklists[status]!;
                
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
  
  Widget _buildAccordionSection(String status, List<dynamic> items) {
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
                          '${items.length} ${items.length == 1 ? 'checklist' : 'checklists'}',
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
                    child: _ChecklistCard(
                      item: item as Map<String, dynamic>,
                      onNavigateBack: () => _load(isRefresh: true),
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
      case 'ACTIVE':
        return const Color(0xFFF59E0B);
      case 'IN PROGRESS':
        return const Color(0xFF3B82F6);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
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
            painter: ChecklistsBackgroundPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }
}
