import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/task_service.dart';
import '../../theme/app_theme.dart';
import 'ticket_detail_page.dart';
import '../../widgets/bottom_navigation_bar.dart';
import '../checklist/checklist_qr_scanner_page.dart';
import '../tasks/qr_scanner_page.dart';

extension StringCapitalization on String {
  String capitalize() {
    return isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
  }
}

class TicketsListPage extends StatefulWidget {
  const TicketsListPage({super.key});

  @override
  State<TicketsListPage> createState() => _TicketsListPageState();
}

class _TicketsListPageState extends State<TicketsListPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _refreshing = false;
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
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
    _loadTickets();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets({bool isRefresh = false}) async {
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

    final result = await TaskService.getUserTickets();

    if (mounted) {
      if (result['success']) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(result['data'] ?? []);
          _applyFilter();
          _isLoading = false;
          _refreshing = false;
        });
        if (!isRefresh) {
          _fadeController.forward();
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load tickets';
          _isLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredTickets = _tickets;
      } else if (_selectedFilter == 'pending') {
        _filteredTickets = _tickets.where((ticket) {
          final status = ticket['status'];
          return status != null &&
              status['title'].toLowerCase() != 'completed' &&
              status['title'].toLowerCase() != 'done' &&
              status['title'].toLowerCase() != 'closed';
        }).toList();
      } else if (_selectedFilter == 'completed') {
        _filteredTickets = _tickets.where((ticket) {
          final status = ticket['status'];
          return status != null &&
              (status['title'].toLowerCase() == 'completed' ||
                  status['title'].toLowerCase() == 'done' ||
                  status['title'].toLowerCase() == 'closed');
        }).toList();
      }
    });
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
                                    onPressed: () => _loadTickets(),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadTickets(isRefresh: true),
                              color: AppTheme.primaryPurple,
                              child: _filteredTickets.isEmpty
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
                    'Tickets',
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
    // Group tickets by status
    final Map<String, List<Map<String, dynamic>>> groupedTickets = {
      'PENDING': [],
      'IN PROGRESS': [],
      'COMPLETED': [],
    };
    
    for (var ticket in _filteredTickets) {
      final status = ticket['status'];
      String statusKey = 'PENDING';
      if (status != null) {
        final statusTitle = (status['title'] ?? '').toString().toUpperCase();
        if (statusTitle.contains('COMPLETED') || statusTitle.contains('DONE') || statusTitle.contains('CLOSED') || statusTitle.contains('RESOLVED')) {
          statusKey = 'COMPLETED';
        } else if (statusTitle.contains('PROGRESS') || statusTitle.contains('IN PROGRESS')) {
          statusKey = 'IN PROGRESS';
        } else {
          statusKey = 'PENDING';
        }
      }
      groupedTickets[statusKey]!.add(ticket);
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
                    'Showing ${_filteredTickets.length} of ${_tickets.length} tickets',
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
                final items = groupedTickets[status]!;
                
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
                          '${items.length} ${items.length == 1 ? 'ticket' : 'tickets'}',
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
                    child: _TicketCard(
                      ticket: item,
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
            painter: TicketsBackgroundPainter(progress: _bgController.value),
          );
        },
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
              onPressed: _loadTickets,
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
                  Icons.confirmation_num_outlined,
                  size: 50,
                  color: const Color(0xFF8B5CF6).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _selectedFilter == 'all'
                    ? 'No tickets yet'
                    : _selectedFilter == 'completed'
                        ? 'No completed tickets'
                        : 'No pending tickets',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilter == 'all'
                    ? 'All your tickets will appear here'
                    : _selectedFilter == 'completed'
                        ? 'Keep resolving tickets to see them here!'
                        : 'All your tickets are completed! 🎉',
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
                      setState(() {
                        _selectedFilter = 'all';
                        _applyFilter();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('View All Tickets'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTicketCard(
      BuildContext context, Map<String, dynamic> ticket, int index) {
    final status = ticket['status'];
    final priority = ticket['priority'];
    final checklist = ticket['checklist'];

    return AnimatedOpacity(
      opacity: 1.0,
      duration: Duration(milliseconds: 300 + (index * 50)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return TicketDetailPage(ticketId: ticket['id']);
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutCubic;
                    var tween = Tween(begin: begin, end: end)
                        .chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row with left accent bar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getColorFromString(
                              status?['color'] ?? 'primary'),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket['title'] ?? 'Untitled Ticket',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (checklist != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6)
                                        .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    checklist['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFF8B5CF6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.confirmation_num_rounded,
                          size: 16,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Status, Priority and info chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getColorFromString(status['color'])
                                    .withOpacity(0.12),
                                _getColorFromString(status['color'])
                                    .withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getColorFromString(status['color'])
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            status['title'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _getColorFromString(status['color']),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      if (priority != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getColorFromString(priority['color'])
                                    .withOpacity(0.12),
                                _getColorFromString(priority['color'])
                                    .withOpacity(0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getColorFromString(priority['color'])
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            priority['title'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color:
                                  _getColorFromString(priority['color']),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.12),
                              Colors.blue.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 12,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Bottom - Users and arrow
                  if ((ticket['users'] as List?)?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 32,
                              child: Stack(
                                children: [
                                  ..._buildUserAvatars(ticket),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildUserAvatars(Map<String, dynamic> ticket) {
    final users = (ticket['users'] as List?) ?? [];
    final displayCount = users.length > 3 ? 3 : users.length;
    final widgets = <Widget>[];

    for (int i = 0; i < displayCount; i++) {
      final user = users[i];
      final firstName = user['first_name'] ?? '';
      final initial = firstName.isNotEmpty
          ? firstName.substring(0, 1).toUpperCase()
          : '?';

      widgets.add(
        Positioned(
          left: i * 16.0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.7 - (i * 0.15)),
                  const Color(0xFF3B82F6).withOpacity(0.7 - (i * 0.15)),
                ],
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 12,
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
      widgets.add(
        Positioned(
          left: 3 * 16.0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              color: Colors.grey[300],
            ),
            child: Center(
              child: Text(
                '+${users.length - 3}',
                style: const TextStyle(
                  fontSize: 10,
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

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'];
    final priority = ticket['priority'];
    final checklist = ticket['checklist'];
    final statusColor = _getStatusColorFromTicket(status);
    
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
              builder: (context) => TicketDetailPage(ticketId: ticket['id']),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['title'] ?? 'Untitled Ticket',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (checklist != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              checklist['title'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryPurple,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
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
              
              // Users avatars
              if ((ticket['users'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    ..._buildUserAvatars(ticket),
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

  Color _getStatusColorFromTicket(dynamic status) {
    if (status == null) return Colors.grey;
    final statusTitle = (status['title'] ?? '').toString().toUpperCase();
    if (statusTitle.contains('COMPLETED') || statusTitle.contains('DONE') || statusTitle.contains('CLOSED') || statusTitle.contains('RESOLVED')) {
      return const Color(0xFF10B981);
    } else if (statusTitle.contains('PROGRESS') || statusTitle.contains('IN PROGRESS')) {
      return const Color(0xFF3B82F6);
    }
    return const Color(0xFFF59E0B);
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

  List<Widget> _buildUserAvatars(Map<String, dynamic> ticket) {
    final users = (ticket['users'] as List?) ?? [];
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

class TicketsBackgroundPainter extends CustomPainter {
  final double progress;

  TicketsBackgroundPainter({this.progress = 0});
  
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
  bool shouldRepaint(covariant TicketsBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

