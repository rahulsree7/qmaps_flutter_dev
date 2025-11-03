import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/auth_service.dart';
import 'checklist_detail_page.dart';
import '../../theme/app_theme.dart';

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

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
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
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          const Expanded(
            child: Text(
              'Checklists',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Sort button
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sort by Title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
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
      margin: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: isExpanded 
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    )
                  : BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(status),
                      color: statusColor,
                      size: 20,
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          '${items.length} ${items.length == 1 ? 'checklist' : 'checklists'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: statusColor,
                  ),
                ],
              ),
            ),
          ),
          // Accordion content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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

class _ChecklistCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onNavigateBack;
  const _ChecklistCard({required this.item, this.onNavigateBack});

  Color _statusColor(String status) {
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

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? '').toString();
    final color = _statusColor(status);
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // Navigate to detail page and wait for return
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChecklistDetailPage(
                  checklistId: item['id'] as int,
                  checklistTitle: (item['title'] ?? 'Checklist').toString(),
                ),
              ),
            );
            
            // Refresh data when returning from detail page
            onNavigateBack?.call();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and completion status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (item['title'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (item['answered_total'] ?? '').toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                
                // Location
                Text(
                  (item['location'] ?? '').toString(),
                  style: TextStyle(
                    fontSize: 13, 
                    color: Colors.grey[600], 
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                
                // First question and status
                Row(
                  children: [
                    const Icon(Icons.list_alt, size: 16, color: Colors.black54),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (item['first_question'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 14, 
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.w600, 
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Progress bar
                LinearProgressIndicator(
                  value: ((item['percent'] ?? 0) as num).toDouble() / 100.0,
                  backgroundColor: Colors.grey[200],
                  color: color,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                
                // Due and Next dates
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Due Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (item['due_date'] ?? '').toString().replaceFirst(' ', ', '),
                            style: const TextStyle(
                              fontSize: 12, 
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Time',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (item['next_time'] ?? '').toString().replaceFirst(' ', ', '),
                            style: const TextStyle(
                              fontSize: 12, 
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
}

class ChecklistsBackgroundPainter extends CustomPainter {
  final double progress; // 0..1

  ChecklistsBackgroundPainter({this.progress = 0});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryPurple.withOpacity(0.05)
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
          AppTheme.primaryPurple.withOpacity(0.12),
          AppTheme.primaryPurple.withOpacity(0.0),
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
  bool shouldRepaint(covariant ChecklistsBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
