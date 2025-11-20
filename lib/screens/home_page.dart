import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import 'checklist/checklist_qr_scanner_page.dart';
import 'tasks/qr_scanner_page.dart';
import '../utils/route_observer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, RouteAware {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bgController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _userName = '';
  String _userEmail = '';
  int _pendingTasks = 0;
  int _completedTasks = 0;
  int _pendingTickets = 0;
  int _completedTickets = 0;
  int _totalTasks = 0;
  int _otherTasks = 0;
  int _totalTickets = 0;
  int _otherTickets = 0;
  final List<double> _ticketTrend = [30, 45, 38, 58, 65, 72, 60];
  final List<double> _taskTrend = [42, 53, 47, 63, 75, 68, 80];
  final List<String> _trendMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
  List<_LegendData> _ticketSegments = [];
  List<_LegendData> _taskSegments = [];
  
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
                'Add Checklist',
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
                _handleAddChecklist();
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
                _handleAddTask();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _handleAddChecklist() {
    // Navigate to QR scanner for checklist
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChecklistQRScannerPage(),
      ),
    );
  }
  
  void _handleAddTask() {
    // Navigate to QR scanner for task
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerPage(),
      ),
    );
  }

  Widget _buildReasonBadge(String title, String reason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            reason,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonutCard(String headline, List<_LegendData> segments) {
    if (segments.isEmpty) {
      return Container(
        height: 380,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text('No data'),
        ),
      );
    }

    final highest = segments.reduce((curr, next) => curr.value >= next.value ? curr : next);
    final lowest = segments.reduce((curr, next) => curr.value <= next.value ? curr : next);

    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            width: 140,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(140, 140),
                  painter: DonutChartPainter(
                    values: segments.map((segment) => segment.value).toList(),
                    colors: segments.map((segment) => segment.color).toList(),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${segments.fold<double>(0, (sum, segment) => sum + segment.value).toInt()}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend with counts
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: segments.map((segment) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: segment.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          segment.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${segment.value.toInt()}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      duration: const Duration(seconds: 10),
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
    _loadUserData();
    _loadSummaryData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService.getUserData();
    if (userData != null && mounted) {
      setState(() {
        _userName = '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'.trim();
        _userEmail = userData['email'] ?? '';
      });
    }
  }

  Future<void> _loadSummaryData() async {
    try {
      final tasksResult = await TaskService.getUserTasks();
      final ticketsResult = await TaskService.getUserTickets();

      print('Summary Data - Tasks Result: $tasksResult');
      print('Summary Data - Tickets Result: $ticketsResult');

      if (mounted) {
        setState(() {
          if (tasksResult['success']) {
            final tasks = List<Map<String, dynamic>>.from(tasksResult['data'] ?? []);
            print('Total tasks fetched: ${tasks.length}');
          _totalTasks = tasks.length;
            _pendingTasks = tasks
                .where((task) {
                  final status = task['status'];
                  return status != null &&
                      status['title'].toLowerCase() != 'completed' &&
                      status['title'].toLowerCase() != 'done' &&
                      status['title'].toLowerCase() != 'closed';
                })
                .length;
            _completedTasks = tasks
                .where((task) {
                  final status = task['status'];
                  return status != null &&
                      (status['title'].toLowerCase() == 'completed' ||
                          status['title'].toLowerCase() == 'done' ||
                          status['title'].toLowerCase() == 'closed');
                })
                .length;
          _otherTasks = _totalTasks - _pendingTasks - _completedTasks;
          if (_otherTasks < 0) _otherTasks = 0;
          print('Pending: $_pendingTasks, Completed: $_completedTasks, Other: $_otherTasks');
          } else {
            print('Tasks fetch failed: ${tasksResult['message']}');
          }

          if (ticketsResult['success']) {
            final tickets = List<Map<String, dynamic>>.from(ticketsResult['data'] ?? []);
            print('Total tickets fetched: ${tickets.length}');
          _totalTickets = tickets.length;
            _pendingTickets = tickets
                .where((ticket) {
                  final status = ticket['status'];
                  return status != null &&
                      status['title'].toLowerCase() != 'completed' &&
                      status['title'].toLowerCase() != 'done' &&
                      status['title'].toLowerCase() != 'closed';
                })
                .length;
            _completedTickets = tickets
                .where((ticket) {
                  final status = ticket['status'];
                  return status != null &&
                      (status['title'].toLowerCase() == 'completed' ||
                          status['title'].toLowerCase() == 'done' ||
                          status['title'].toLowerCase() == 'closed');
                })
                .length;
          _otherTickets = _totalTickets - _pendingTickets - _completedTickets;
          if (_otherTickets < 0) {
            _otherTickets = 0;
          }
          print('Pending Tickets: $_pendingTickets, Completed Tickets: $_completedTickets, Other: $_otherTickets');
          } else {
            print('Tickets fetch failed: ${ticketsResult['message']}');
          }
        _refreshDonutReport();
        });
      }
    } catch (e) {
      print('Error loading summary data: $e');
    }
  }

  void _refreshDonutReport() {
    print('_refreshDonutReport called');
    print('Tickets - Pending: $_pendingTickets, Completed: $_completedTickets, Other: $_otherTickets');
    print('Tasks - Pending: $_pendingTasks, Completed: $_completedTasks, Other: $_otherTasks');
    
    final createSegments = (String type, int pending, int completed, int other, Color accent) {
    final items = [
      _LegendData(label: '$type Pending', value: pending.toDouble(), color: accent),
      _LegendData(label: '$type Completed', value: completed.toDouble(), color: Colors.green),
      _LegendData(label: '$type Other', value: other.toDouble(), color: Colors.grey),
    ];
    final total = items.fold<double>(0, (sum, item) => sum + item.value);
    print('$type total: $total');
    if (total == 0) {
      print('No data for $type, creating placeholder segment');
      return [
        _LegendData(label: '$type - No data', value: 1, color: accent.withOpacity(0.3)),
      ];
    }
    return items;
    };

    _ticketSegments = createSegments('Tickets', _pendingTickets, _completedTickets, _otherTickets, const Color(0xFFF97316));
    _taskSegments = createSegments('Tasks', _pendingTasks, _completedTasks, _otherTasks, const Color(0xFF3B82F6));
    
    print('Ticket segments: ${_ticketSegments.map((s) => '${s.label}: ${s.value}').join(', ')}');
    print('Task segments: ${_taskSegments.map((s) => '${s.label}: ${s.value}').join(', ')}');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bgController.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadSummaryData();
  }

  Future<void> _logout(BuildContext context) async {
    // Clear all session data using AuthService
    await AuthService.logout();
    
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/');
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
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildHeaderSection(context),
                ),
                // Scrollable content below
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Welcome message and task summary
                                _buildWelcomeSection(),
                                const SizedBox(height: 24),
                                // Feature buttons grid
                                _buildFeatureButtonsGrid(),
                                const SizedBox(height: 24),
                                // Graph section
                                _buildGraphSection(),
                                const SizedBox(height: 24),
                                // User info section at bottom
                                _buildUserInfoSection(),
                                const SizedBox(height: 100), // Space for FAB
                              ],
                            ),
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
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')} ${_getMonthName(now.month)} ${now.year.toString().substring(2)}";
    final dayStr = _getDayName(now.weekday);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - Hamburger menu and date
          Row(
            children: [
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
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dayStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Right side - Notifications, logout and logo
          Row(
            children: [
              _buildHeaderIconButton(
                icon: Icons.notifications_outlined,
                onPressed: () {},
                badge: true,
              ),
              const SizedBox(width: 8),
              _buildHeaderIconButton(
                icon: Icons.logout,
            onPressed: () => _logout(context),
            tooltip: 'Logout',
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF1E40AF),
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool badge = false,
  }) {
    return Container(
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
      child: Stack(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.black87),
            onPressed: onPressed,
            tooltip: tooltip,
          ),
          if (badge)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        // Tasks and Tickets Summary Grid
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Tasks',
                pending: _pendingTasks,
                completed: _completedTasks,
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Tickets',
                pending: _pendingTickets,
                completed: _completedTickets,
                icon: Icons.confirmation_num_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int pending,
    required int completed,
    required IconData icon,
    required Color color,
  }) {
    final total = pending + completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and total in single line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Row(
            children: [
              Container(
                    padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                ),
                    child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                      fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
              // Total count on the right
          Text(
            total.toString(),
            style: TextStyle(
                  fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Pending and Completed breakdown - single line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    pending.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    completed.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E40AF),
              Color(0xFF3B82F6),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              // QMAPS Logo
              Container(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return CustomPaint(
                      painter: QmapsLogoPainter(),
                      size: const Size(100, 100),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome!',
                        style: TextStyle(
                  fontSize: 28,
                          fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Quality Management & Operations Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'You have successfully logged in.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildFeatureButtonsGrid() {
    return Column(
      children: [
        // First row - 3 cards
        Row(
          children: [
            Expanded(child: _buildModernFeatureCard(
              title: 'My Checklist',
              icon: Icons.assignment_turned_in,
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.pushNamed(context, '/checklists'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildModernFeatureCard(
              title: 'Tasks',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.pushNamed(context, '/tasks'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildModernFeatureCard(
              title: 'Tickets',
              icon: Icons.confirmation_num_outlined,
              color: const Color(0xFFF59E0B),
              onTap: () => Navigator.pushNamed(context, '/tickets'),
            )),
          ],
        ),
        const SizedBox(height: 12),
        // Second row - 3 cards
        Row(
          children: [
            Expanded(child: _buildModernFeatureCard(
              title: 'Checklists',
              icon: Icons.checklist_rounded,
              color: const Color(0xFF10B981),
              onTap: () => Navigator.pushNamed(context, '/checklists'),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildModernFeatureCard(
              title: 'Add New',
              icon: Icons.add_circle_outline,
              color: const Color(0xFF8B5CF6),
              onTap: _showAddMenu,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildModernFeatureCard(
              title: 'Report',
              icon: Icons.assessment,
              color: const Color(0xFFEF4444),
              onTap: () {},
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildModernFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
          ),
        ],
      ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
              width: 50,
              height: 50,
                  decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                size: 26,
                color: color,
                  ),
                ),
            const SizedBox(height: 12),
            Text(
                    title,
              style: TextStyle(
                fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
      childAspectRatio: 0.9,
                  children: [
                    _buildFeatureCard(
          icon: Icons.verified,
          title: 'Quality',
          subtitle: 'Quality management',
          color: Colors.green,
        ),
        _buildFeatureCard(
          icon: Icons.monitor,
          title: 'Monitoring',
          subtitle: 'System monitoring',
                      color: Colors.blue,
                    ),
                    _buildFeatureCard(
          icon: Icons.assignment,
          title: 'Planning',
          subtitle: 'Strategic planning',
          color: Colors.purple,
                    ),
                    _buildFeatureCard(
          icon: Icons.settings_system_daydream,
          title: 'System',
          subtitle: 'System management',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildGraphSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDonutCard('Tickets', _ticketSegments)),
            const SizedBox(width: 12),
            Expanded(child: _buildDonutCard('Tasks', _taskSegments)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPieChart({
    required String title,
    required Color primaryColor,
    required int pending,
    required int completed,
    required int other,
    required String totalLabel,
    required String noDataLabel,
  }) {
    final rawSegments = [
      _LegendData(label: 'Pending', value: pending.toDouble(), color: const Color(0xFFf97316)),
      _LegendData(label: 'Completed', value: completed.toDouble(), color: const Color(0xFF10b981)),
      _LegendData(label: 'Other', value: other.toDouble(), color: const Color(0xFF6366f1)),
    ];

    final total = rawSegments.fold<double>(0, (sum, data) => sum + data.value);
    final hasData = total > 0;
    final displaySegments = hasData
        ? rawSegments.where((segment) => segment.value > 0).toList()
        : [ _LegendData(label: 'No Data', value: 1.0, color: Colors.grey[300]!) ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
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
                    width: 8,
                    height: 8,
                decoration: BoxDecoration(
                  color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 180,
              child: CustomPaint(
                painter: PieChartPainter3D(
                  values: displaySegments.map((segment) => segment.value).toList(),
                  colors: displaySegments.map((segment) => segment.color).toList(),
                  depth: 16,
                ),
                child: Center(
                  child: hasData
                      ? Text(
                          totalLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          noDataLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: rawSegments.map((segment) {
              return _buildStatusLegend(segment.label, segment.color, segment.value.toInt());
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($value)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _showAddMenu,
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const CircleBorder(),
          child: const Icon(
            Icons.add,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _logout(context),
        icon: const Icon(Icons.logout),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
        ),
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E40AF).withOpacity(0.1),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E40AF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // User Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E40AF),
                  Color(0xFF3B82F6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E40AF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName.isNotEmpty ? _userName : 'Loading...',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail.isNotEmpty ? _userEmail : 'Loading...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildWaveChart({
    required String title,
    required List<double> data,
    required LinearGradient gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CustomPaint(
            painter: WaveChartPainter(
              data: data,
              color: gradient.colors.last,
            ),
            child: Container(),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularStats({
    required String headline,
    required int pending,
    required int completed,
    required int other,
    required Color primaryColor,
  }) {
    final total = pending + completed + other;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _CircularStat(
          label: 'Pending',
          value: pending,
          color: primaryColor,
          total: total,
        ),
        const SizedBox(height: 8),
        _CircularStat(
          label: 'Completed',
          value: completed,
          color: Colors.green,
          total: total,
        ),
        const SizedBox(height: 8),
        _CircularStat(
          label: 'Other',
          value: other,
          color: Colors.grey,
          total: total,
        ),
      ],
    );
  }


  Widget _buildBackgroundGraphics() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          return CustomPaint(
            painter: HomeBackgroundPainter(progress: _bgController.value),
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Feature tap handler
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: color[600],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeBackgroundPainter extends CustomPainter {
  final double progress; // 0..1

  HomeBackgroundPainter({this.progress = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E40AF).withOpacity(0.05)
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
    final paint2 = Paint()
      ..color = const Color(0xFF10B981).withOpacity(0.08 * pulsate)
      ..style = PaintingStyle.fill;

    final dx1 = size.width * (0.75 + 0.05 * math.sin(progress * 2 * math.pi));
    final dy1 = size.height * (0.18 + 0.03 * math.cos(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx1, dy1), 28 + 6 * pulsate, paint2);

    final dx2 = size.width * (0.25 + 0.04 * math.cos(progress * 2 * math.pi));
    final dy2 = size.height * (0.82 + 0.03 * math.sin(progress * 2 * math.pi));
    canvas.drawCircle(Offset(dx2, dy2), 22 + 6 * (1 - pulsate), paint2);

    // Soft moving gradient blobs
    final blobPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3B82F6).withOpacity(0.12),
          const Color(0xFF3B82F6).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * (0.4 + 0.1 * math.sin(progress * 2 * math.pi)),
            size.height * (0.35 + 0.05 * math.cos(progress * 2 * math.pi))),
        radius: 140,
      ));
    canvas.drawCircle(
      Offset(size.width * (0.4 + 0.1 * math.sin(progress * 2 * math.pi)),
          size.height * (0.35 + 0.05 * math.cos(progress * 2 * math.pi))),
      140,
      blobPaint,
    );
  }

  @override
  bool shouldRepaint(covariant HomeBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class QmapsLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;
    
    // Draw the main circular part of 'q' in teal
    final circlePaint = Paint()
      ..color = const Color(0xFF20B2AA) // Teal color
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, circlePaint);
    
    // Draw the ribbon-like tail of 'q'
    final ribbonPath = Path();
    ribbonPath.moveTo(center.dx + radius * 0.7, center.dy - radius * 0.3);
    ribbonPath.quadraticBezierTo(
      center.dx + radius * 1.5, center.dy - radius * 0.1,
      center.dx + radius * 1.2, center.dy + radius * 0.8,
    );
    ribbonPath.quadraticBezierTo(
      center.dx + radius * 0.8, center.dy + radius * 1.2,
      center.dx - radius * 0.2, center.dy + radius * 0.9,
    );
    
    // Top surface of ribbon (dark gray)
    final topRibbonPaint = Paint()
      ..color = const Color(0xFF4A5568) // Dark gray
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(ribbonPath, topRibbonPaint);
    
    // Bottom surface of ribbon (lighter blue)
    final bottomRibbonPath = Path();
    bottomRibbonPath.moveTo(center.dx + radius * 0.7, center.dy - radius * 0.2);
    bottomRibbonPath.quadraticBezierTo(
      center.dx + radius * 1.3, center.dy + radius * 0.1,
      center.dx + radius * 1.0, center.dy + radius * 0.9,
    );
    bottomRibbonPath.quadraticBezierTo(
      center.dx + radius * 0.6, center.dy + radius * 1.1,
      center.dx - radius * 0.1, center.dy + radius * 0.8,
    );
    
    final bottomRibbonPaint = Paint()
      ..color = const Color(0xFF63B3ED) // Lighter blue
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(bottomRibbonPath, bottomRibbonPaint);
    
    // Add some depth with shadows
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(center, radius + 2, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendData {
  final String label;
  final double value;
  final Color color;

  const _LegendData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class PieChartPainter3D extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double depth;

  const PieChartPainter3D({
    required this.values,
    required this.colors,
    this.depth = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalValue = values.fold<double>(0, (sum, value) => sum + (value < 0 ? 0 : value));
    if (totalValue <= 0 || values.isEmpty) {
      return;
    }

    final radius = math.min(size.width, size.height) / 2 - 16;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final shadowRect = rect.shift(Offset(0, depth));
    double startAngle = -math.pi / 2;

    final shadowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(0.15);

    canvas.drawArc(shadowRect, startAngle, math.pi * 2, true, shadowPaint);

    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value <= 0) {
        continue;
      }
      final sweepAngle = (value / totalValue) * math.pi * 2;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    final gradient = RadialGradient(
      center: const Alignment(-0.2, -0.2),
      radius: 1.2,
      colors: [
        Colors.white.withOpacity(0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.9],
    );
    final highlightPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, true, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant PieChartPainter3D oldDelegate) {
    if (oldDelegate.values.length != values.length || oldDelegate.depth != depth) {
      return true;
    }
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }
    return false;
  }
}

class DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  DonutChartPainter({
    required this.values,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('DonutChartPainter.paint called - values: $values, colors: $colors, size: $size');
    final total = values.fold<double>(0, (sum, value) => sum + (value < 0 ? 0 : value));
    print('DonutChartPainter total: $total');
    
    // Calculate dimensions - adjusted for smaller fixed size
    final strokeWidth = 18.0;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2 - 4;
    final center = Offset(size.width / 2, size.height / 2);
    
    if (total <= 0 || values.isEmpty) {
      print('DonutChartPainter: No data to paint, drawing placeholder');
      // Draw a placeholder gray circle when there's no data
      final placeholderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.grey[300]!;
      canvas.drawCircle(center, radius, placeholderPaint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -math.pi / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
      
    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value <= 0) continue;
      final sweepAngle = (value / total) * math.pi * 2;
      paint.color = colors[i % colors.length];
      print('DonutChartPainter: Drawing arc $i - value: $value, sweepAngle: $sweepAngle, color: ${paint.color}');
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

class _CircularStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final int total;

  const _CircularStat({
    required this.label,
    required this.value,
    required this.color,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = total > 0 ? value : 0;
    final percentage = total > 0 ? (value / total * 100).round() : 0;
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 2),
            Text(
              '$displayValue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

class WaveChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  const WaveChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce(math.max);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.9), color.withOpacity(0.1)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height);
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] / maxValue) * size.height;
      final controlX = x;
      final controlY = y - 20;
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        final prevX = ((i - 1) / (data.length - 1)) * size.width;
        final prevY = size.height - (data[i - 1] / maxValue) * size.height;
        final midX = (prevX + x) / 2;
        final midY = (prevY + y) / 2;
        path.quadraticBezierTo(midX, prevY - 20, x, y);
      }
    }
    path.lineTo(size.width, size.height);
    path.close();
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant WaveChartPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}
