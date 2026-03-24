// ignore_for_file: avoid_print, deprecated_member_use, use_build_context_synchronously, prefer_null_aware_operators, unnecessary_non_null_assertion, unused_element, library_prefixes

import 'dart:async';
// Removed unused imports
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import '../../services/technician_service.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';

class TechnicianLandingPage extends StatefulWidget {
  const TechnicianLandingPage({super.key});

  @override
  State<TechnicianLandingPage> createState() => _TechnicianLandingPageState();
}

class _TechnicianLandingPageState extends State<TechnicianLandingPage> {
  int _selectedIndex = 0;
  List<Widget> _pages = [];
  Future<List<TechnicianTask>> _tasksFuture = Future.value([]);
  late NotificationService _notificationService;
  late StreamSubscription<NotificationMessage> _notificationSubscription;
  IO.Socket? _socket;
  List<TechnicianTask> _cachedTasks = [];
  bool _socketConnected = false;
  Timer? _fallbackTimer;
  static const Duration _fallbackInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService();
    _initializeNotifications();
    _initializeSocketIO();
    _loadTasks();
    _pages = [
      _TechnicianDashboard(
        tasksFuture: _tasksFuture,
        onRefresh: _loadTasks,
      ),
      const Center(child: Text('Assigned Tasks - Coming Soon')),
      const Center(child: Text('Analytics - Coming Soon')),
      const Center(child: Text('Account - Coming Soon')),
    ];
  }

  Future<void> _initializeSocketIO() async {
    try {
      // Connect to a single derived server URL (remove trailing /api)
      // Use a fixed socket server URL for reliable local testing (change if needed)
      const fixedSocketUrl = 'http://10.91.220.92:5000';
      final baseUrl = ApiService.baseUrl;
      final derived = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      // Prefer explicit fixedSocketUrl, otherwise derived from ApiService, then localhost
      final url = fixedSocketUrl.isNotEmpty ? fixedSocketUrl : (derived.isNotEmpty ? derived : 'http://localhost:5000');

      _socket = IO.io(
        url,
        <String, dynamic>{
          'autoConnect': true,
          'reconnection': true,
          'reconnectionDelay': 1000,
          'reconnectionDelayMax': 5000,
          'reconnectionAttempts': 5,
          'transports': ['websocket', 'polling'], // websocket preferred, polling as fallback
          'forceNew': true,
        },
      );

          // Attach shared handlers
      _socket?.on('connect', (_) {
        _socketConnected = true;
        _fallbackTimer?.cancel();
        });

          _socket?.on('claim:reopened', (data) {
            try {
              final cid = (data is Map) ? data['claimId']?.toString() ?? 'unknown' : data.toString();
              } catch (e) {
              }

            if (mounted) {
              // Show toast and update cache
              try {
                final claimId = (data is Map) ? data['claimId']?.toString() ?? 'unknown' : data.toString();
                final notification = NotificationMessage(
                  id: 'reopen_${DateTime.now().millisecondsSinceEpoch}',
                  type: 'task_reopened',
                  title: 'Task Reopened',
                  message: 'Task #$claimId was re-opened by admin',
                  data: {'claimId': claimId},
                  timestamp: DateTime.now(),
                );
                _showNotificationToast(notification);
              } catch (e) {
                }

              _handleTaskReopened(data);
            }
          });

          _socket?.on('notification:received', (data) {
            if (mounted) _handleBackendNotification(data);
          });

          _socket?.on('task:assigned', (data) {
            if (mounted) {
              _handleTaskAssigned(data);
            } else {
              }
          });

      _socket?.on('connect_error', (err) {
        _socketConnected = false;
        _startFallbackPolling();
      });

      _socket?.on('error', (err) {
        _socketConnected = false;
        _startFallbackPolling();
      });

      _socket?.on('disconnect', (_) {
        _socketConnected = false;
        _startFallbackPolling();
      });

      _socket?.on('reconnect', (attempt) {
        _socketConnected = true;
        _fallbackTimer?.cancel();
      });

      // Verbose: log any event received (useful for debugging connectivity/payloads)
      try {
        _socket?.onAny((event, data) {
          try {
            } catch (_) {}
        });
      } catch (_) {}

      // Allow a short grace period for connection; if not connected, start fallback polling
      await Future.delayed(const Duration(seconds: 2));
      if (!_socketConnected) {
        _startFallbackPolling();
      }
    } catch (e) {
      // ignore initialization errors
    }
  }

  void _startFallbackPolling() {
    if (_socketConnected) return;
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_fallbackInterval, (timer) {
      // Use an inner async closure to avoid making the Timer callback itself async
      () async {
        try {
          final latest = await TechnicianService.getAssignedTasks();
          for (final old in _cachedTasks) {
            if (old.status.toLowerCase() != 'rejected') continue;
            final matches = latest.where((t) => t.id == old.id || t.claimId == old.claimId).toList();
            if (matches.isEmpty) continue;
            final match = matches.first;
            if (match.id.isEmpty || match.status.toLowerCase() == 'rejected') continue;

            // Show immediate toast
            final notification = NotificationMessage(
              id: 'reopen_poll_${DateTime.now().millisecondsSinceEpoch}',
              type: 'task_reopened',
              title: 'Task Reopened',
              message: '${match.title} (#${match.claimId}) was re-opened by admin',
              data: {'claimId': match.claimId},
              timestamp: DateTime.now(),
            );
            if (mounted) _showNotificationToast(notification);

            // Update cache and pages
            if (mounted) {
              setState(() {
                final idx = _cachedTasks.indexWhere((t) => t.id == match.id || t.claimId == match.claimId);
                if (idx != -1) {
                  _cachedTasks[idx] = match;
                  _tasksFuture = Future.value(_cachedTasks);
                }
              });
            }
          }
        } catch (e) {
          // ignore polling errors
        }
      }();
    });
  }

  void _handleTaskReopened(dynamic data) {
    try {
      Map<String, dynamic> reopenData;
      if (data is Map) {
        reopenData = data.cast<String, dynamic>();
      } else {
        return;
      }

      final claimId = reopenData['claimId']?.toString();
      final newStatus = reopenData['newStatus'] != null
        ? reopenData['newStatus'].toString().toLowerCase()
        : null;
      final oldStatus = reopenData['oldStatus'] != null
        ? reopenData['oldStatus'].toString().toLowerCase()
        : null;

      // Only process if status changed to 'on-progress' (normal re-open scenario)
      if (newStatus == 'on-progress' && oldStatus == 'rejected' && claimId != null) {
        // Update cached task with new status
        if (_cachedTasks.isNotEmpty) {
          final idx = _cachedTasks.indexWhere((t) => t.id == claimId || t.claimId == claimId);
          if (idx != -1) {
            final oldTask = _cachedTasks[idx];
            final updatedTask = TechnicianTask(
              id: oldTask.id,
              claimId: oldTask.claimId,
              title: oldTask.title,
              description: oldTask.description,
              location: oldTask.location,
              status: newStatus!,
              priority: oldTask.priority,
              assignedDate: oldTask.assignedDate,
              clientName: oldTask.clientName,
              clientPhone: oldTask.clientPhone,
              latitude: oldTask.latitude,
              longitude: oldTask.longitude,
              images: oldTask.images,
            );
            setState(() {
              _cachedTasks[idx] = updatedTask;
              _tasksFuture = Future.value(_cachedTasks);
              // Recreate pages so updated future is passed down
              _pages = [
                _TechnicianDashboard(
                  tasksFuture: _tasksFuture,
                  onRefresh: _loadTasks,
                ),
                const Center(child: Text('Assigned Tasks - Coming Soon')),
                const Center(child: Text('Analytics - Coming Soon')),
                const Center(child: Text('Account - Coming Soon')),
              ];
            });

            // Emit notification through NotificationService
            _notificationService.sendReopenNotification(claimId, oldTask.title);
          }
        }

        // Show notification
        if (mounted) {
          _showReopenNotification(claimId!);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  void _handleBackendNotification(dynamic data) {
    try {
      Map<String, dynamic> notifData;
      if (data is Map) {
        notifData = data.cast<String, dynamic>();
      } else {
        return;
      }

      final notificationId = notifData['id']?.toString() ?? 'unknown';
      final type = notifData['type']?.toString() ?? 'general';
      final title = notifData['title']?.toString() ?? 'Notification';
      final message = notifData['message']?.toString() ?? '';
      final notificationPayload = notifData['data'] as Map<String, dynamic>? ?? {};

      // Create notification object
      final notification = NotificationMessage(
        id: notificationId,
        type: type,
        title: title,
        message: message,
        data: notificationPayload,
        timestamp: DateTime.now(),
      );

      // Show toast immediately
      _showNotificationToast(notification);

      // Also emit through NotificationService for badge updates
      _notificationService.emitNotification(notification);
    } catch (e) {
      // ignore
    }
  }

  void _handleTaskAssigned(dynamic data) {
    try {
      Map<String, dynamic> taskData;
      if (data is Map) {
        taskData = data.cast<String, dynamic>();
      } else {
        return;
      }

      final taskId = taskData['id']?.toString() ?? taskData['claimId']?.toString() ?? 'unknown';
      final taskTitle = taskData['title']?.toString() ?? 'New Task';
      final taskDescription = taskData['description']?.toString() ?? '';
      final location = taskData['location']?.toString() ?? '';

      // Create notification
      final notification = NotificationMessage(
        id: 'task_assigned_$taskId',
        type: 'task_assigned',
        title: 'New Task Assigned',
        message: '📋 $taskTitle is assigned to you${location.isNotEmpty ? ' - $location' : ''}',
        data: {'taskId': taskId, 'title': taskTitle, 'description': taskDescription},
        timestamp: DateTime.now(),
      );

      // Show toast immediately
      if (mounted) {
        _showNotificationToast(notification);
        } else {
        }

      // Emit through NotificationService for badge updates
      _notificationService.emitNotification(notification);

      // Refresh tasks to show the new assignment
      if (mounted) {
        _loadTasks();
      }
    } catch (e) {
      }
  }

  void _showReopenNotification(String claimId) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_open, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Task Reopened',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Task #$claimId is now available for work',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'on-progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  bool _canAcceptTask(String status) {
    final s = status.toLowerCase();
    // Treat any assigned/pending/new/unassigned status as eligible for accept
    if (s.contains('assign') || s.contains('pending') || s == 'new' || s.contains('unassigned')) return true;
    return false;
  }

  void _initializeNotifications() {
    try {
      // Start WebSocket connection in background without blocking
      _notificationService.connect();
      
      // Listen to notifications
      _notificationSubscription = _notificationService.notifications.listen(
        (notification) {
          _showNotificationToast(notification);
          if (mounted) {
            setState(() {
              _loadTasks();
            });
          }
        },
        onError: (error) {
          // Silently ignore errors
        },
        cancelOnError: false, // Keep listening even if errors occur
      );
    } catch (e) {
      // Silently ignore any initialization errors
    }
  }

  void _showNotificationToast(NotificationMessage notification) {
    if (!mounted) return;
    // Determine color and icon based on notification type
    Color backgroundColor = Colors.green[600]!;
    IconData? icon;
    
    switch (notification.type) {
      case 'task_reopened':
        backgroundColor = Colors.green[600]!;
        icon = Icons.lock_open;
        break;
      case 'task_assigned':
        backgroundColor = Colors.blue[600]!;
        icon = Icons.assignment_turned_in;
        break;
      case 'task_completed':
        backgroundColor = Colors.green[600]!;
        icon = Icons.check_circle;
        break;
      case 'task_updated':
        backgroundColor = Colors.orange[600]!;
        icon = Icons.refresh;
        break;
      default:
        backgroundColor = Colors.blue[600]!;
        icon = Icons.notifications;
    }

    // Build snackbar widget
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: notification.type == 'task_reopened' 
        ? const Duration(seconds: 6)
        : notification.type == 'task_assigned'
        ? const Duration(seconds: 8)  // Longer for task assignment
        : const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      // Position above bottom nav: large bottom margin
      margin: notification.type == 'task_assigned'
        ? const EdgeInsets.fromLTRB(16, 16, 16, 90)  // 90px from bottom to clear nav bar
        : const EdgeInsets.fromLTRB(16, 16, 16, 80),
      elevation: 8.0,  // Higher elevation to ensure visibility
      action: SnackBarAction(
        label: 'View',
        textColor: Colors.white,
        onPressed: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _loadTasks() {
    // Make this async to cache results and update pages only when data arrives
    () async {
      if (!mounted) return;
      try {
        final tasks = await TechnicianService.getAssignedTasks();
        if (!mounted) return;
        setState(() {
          _cachedTasks = tasks;
          _tasksFuture = Future.value(_cachedTasks);

          // Recreate pages so the dashboard receives the updated Future
          _pages = [
            _TechnicianDashboard(
              tasksFuture: _tasksFuture,
              onRefresh: _loadTasks,
            ),
            const Center(child: Text('Assigned Tasks - Coming Soon')),
            const Center(child: Text('Analytics - Coming Soon')),
            const Center(child: Text('Account - Coming Soon')),
          ];
        });
      } catch (e) {
        // On error, fallback to previous behavior: set the future without cache
        if (!mounted) return;
        setState(() {
          _tasksFuture = TechnicianService.getAssignedTasks();
        });
      }
    }();
  }
 
  @override
  void dispose() {
    try {
      _notificationSubscription.cancel();
    } catch (_) {}
    try {
      _socket?.disconnect();
      _socket = null;
    } catch (_) {}
    try {
      _fallbackTimer?.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: false,
        title: const Text(
          'Technician',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh tasks',
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              setState(() {
                _selectedIndex = 3; // open Account/Notifications placeholder
              });
            },
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: _pages.isNotEmpty ? _pages[_selectedIndex] : const SizedBox.shrink(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        elevation: 16,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF0070BA),
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard, size: 26),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment, size: 26),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics, size: 26),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 26),
            label: 'Account',
          ),
        ],
      ),
      // Debug floating button removed per user request
    );
  }
}

class _TechnicianDashboard extends StatefulWidget {
  final Future<List<TechnicianTask>> tasksFuture;
  final VoidCallback onRefresh;

  const _TechnicianDashboard({
    required this.tasksFuture,
    required this.onRefresh,
  });

  @override
  State<_TechnicianDashboard> createState() => _TechnicianDashboardState();
}

class _TechnicianDashboardState extends State<_TechnicianDashboard> {
  late Future<TechnicianStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_TechnicianDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Force rebuild when tasksFuture changes (from parent _loadTasks)
    if (oldWidget.tasksFuture != widget.tasksFuture) {
      setState(() {});
    }
  }

  void _loadData() {
    _statsFuture = TechnicianService.getTechnicianStats();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'on-progress':
      case 'on progress':
        return Colors.blue;
      case 'completed':
      case 'solved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        // Welcome Section
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0070BA).withValues(alpha: 0.95),
                      const Color(0xFF00C6FB).withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0070BA).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0070BA).withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 3,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<TechnicianStats>(
                      future: _statsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final stats = snapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You have ${stats.totalTasksToday} tasks assigned to you today',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                  height: 1.5,
                                ),
                              ),
                              if (stats.pendingTasks > 0) ...[const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.priority_high,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${stats.pendingTasks} require your attention',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        }
                        return Text(
                          'Loading your tasks...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Quick Overview Header
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0070BA), Color(0xFF00C6FB)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Stats Cards
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(
              child: FutureBuilder<TechnicianStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final stats = snapshot.data;
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(
                        title: 'Pending',
                        count: stats?.pendingTasks.toString() ?? '0',
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Completed',
                        count: stats?.completedTasks.toString() ?? '0',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      _StatCard(
                        title: 'In Progress',
                        count: stats?.inProgressTasks.toString() ?? '0',
                        icon: Icons.hourglass_bottom,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        title: 'Rating',
                        count: stats?.rating.toString() ?? '0',
                        icon: Icons.star,
                        color: Colors.amber,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        // Task Section Header
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16.0, 28.0, 16.0, 20.0),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<TechnicianTask>>(
              future: widget.tasksFuture,
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Tasks',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You have ${tasks.length} task${tasks.length != 1 ? 's' : ''} to handle',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0070BA).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF0070BA).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            '${tasks.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0070BA),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 2,
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0070BA), Color(0xFF00C6FB)],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        // Tasks List - Lazy Loaded
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverToBoxAdapter(
            child: FutureBuilder<List<TechnicianTask>>(
              future: widget.tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error loading tasks: ${snapshot.error}'),
                  );
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TaskCard(
                        key: ValueKey(task.id),
                        task: task,
                        statusColor: _getStatusColor(task.status),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        // Bottom padding
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 32.0),
          sliver: SliverToBoxAdapter(
            child: Container(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: Card(
          elevation: _isHovered ? 12 : 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  widget.color.withValues(alpha: 0.12),
                  widget.color.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Container with modern styling
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 32,
                    color: widget.color,
                  ),
                ),
                const SizedBox(height: 16),
                // Count - Primary Text
                Text(
                  widget.count,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: widget.color,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Title - Secondary Text
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.4,
                    height: 1.4,
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

class _TaskCard extends StatefulWidget {
  final TechnicianTask task;
  final Color statusColor;

  const _TaskCard({
    super.key,
    required this.task,
    required this.statusColor,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  String? _updatingStatus;
  // _selectedStatus removed - not used
  bool _isSavingTask = false;
  bool _isRequestingReopen = false;
  bool _isAccepting = false;
  late String _localStatus;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _localStatus = widget.task.status.toLowerCase();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController);
  }

  bool _isAcceptableStatus(String status) {
    final s = status.toLowerCase();
    // Show accept button for any status except completed and rejected
    return s != 'completed' && s != 'rejected' && s != 'on-progress';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update local status when the task data changes (e.g., from Socket.IO refresh)
    if (oldWidget.task.status != widget.task.status) {
      setState(() {
        _localStatus = widget.task.status.toLowerCase();
      });
    }
  }

  void _openMap(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) => MapModal(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  Future<void> _updateTaskStatus(String newStatus) async {
    if (_updatingStatus != null) return;

    setState(() {
      _updatingStatus = newStatus;
    });

    try {
      final success = await TechnicianService.updateTaskStatus(
        widget.task.claimId,
        newStatus,
      );

      if (success && mounted) {
        // Update local status so the UI reflects the blocked state without mutating the model
        setState(() {
          _localStatus = newStatus;
        });
        final statusName = _getStatusDisplayName(newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Status Updated',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Changed to $statusName',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {});
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Update Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Could not update to $newStatus',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      e.toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = null;
        });
      }
    }
  }

  String _getStatusDisplayName(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'on-progress' || lowerStatus == 'on progress') {
      return 'In Progress';
    }
    return status.replaceFirst(status[0], status[0].toUpperCase());
  }

  // Removed unused _handleStatusTap to clean analyzer warnings

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.statusColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                        if (_isExpanded) {
                          _animationController.forward();
                        } else {
                          _animationController.reverse();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: widget.statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.task.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '#${widget.task.claimId}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _localStatus,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedRotation(
                            turns: _expandAnimation.value,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.expand_more,
                              color: widget.statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Expanded Content
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: widget.statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            if (widget.task.description.isNotEmpty) ...[
                              Text(
                                'Description',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.task.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Location
                            if (widget.task.latitude != null &&
                                widget.task.longitude != null) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: widget.statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${widget.task.latitude}, ${widget.task.longitude}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _openMap(
                                        widget.task.latitude!,
                                        widget.task.longitude!,
                                      );
                                    },
                                    icon: const Icon(Icons.map, size: 16),
                                    label: const Text('View Map'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.statusColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            // Image Gallery
                            if (widget.task.images.isNotEmpty) ...[
                              Text(
                                'Task Images',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildImageGallery(),
                              const SizedBox(height: 16),
                            ],
                            // Status Update / Blocked Message
                            if (_localStatus.toLowerCase() == 'rejected')
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lock,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '🔒 Task Blocked',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'This task has been rejected. You need admin approval to continue working on it.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red.withValues(alpha: 0.8),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _isRequestingReopen ? null : _requestTaskReopen,
                                            icon: _isRequestingReopen
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Icon(Icons.lock_open, size: 18),
                                            label: Text(
                                              _isRequestingReopen ? 'Sending Request...' : 'Request Re-open',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Update Status',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildStatusButton('completed'),
                                        const SizedBox(width: 8),
                                        _buildStatusButton('rejected'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            // Accept button for pending/assigned tasks
                            if (_isAcceptableStatus(_localStatus))
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isAccepting ? null : _acceptTask,
                                      icon: _isAccepting
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.play_arrow, size: 18),
                                      label: Text(
                                        _isAccepting ? 'Accepting...' : 'Accept Task',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else if (_localStatus.toLowerCase() != 'rejected')
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isSavingTask ? null : _completeTask,
                                      icon: _isSavingTask
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.done_all, size: 18),
                                      label: Text(
                                        _isSavingTask ? 'Saving...' : 'Save Task',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: widget.statusColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusButton(String status) {
    final isUpdating = _updatingStatus == status;
    final displayName = _getStatusDisplayName(status);

    return ElevatedButton(
      onPressed: isUpdating
          ? null
          : () {
              _updateTaskStatus(status);
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.statusColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(displayName),
    );
  }

  Widget _buildImageGallery() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: widget.task.images.length,
        itemBuilder: (context, index) {
          final imageUrl = widget.task.images[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _viewImageFullscreen(imageUrl, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 30,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}/${widget.task.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _viewImageFullscreen(String imageUrl, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              color: Colors.black87,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 64,
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Image ${index + 1} of ${widget.task.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeTask() async {
    if (_isSavingTask) return;

    setState(() {
      _isSavingTask = true;
    });

    try {
      // Call the backend API to save/complete task
      final success = await TechnicianService.updateTaskStatus(
        widget.task.claimId,
        'completed',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Task Completed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Task #${widget.task.claimId} has been saved',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              _animationController.reverse();
            });
          }
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Save Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Could not save task #${widget.task.claimId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        e.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTask = false;
        });
      }
    }
  }

  Future<void> _acceptTask() async {
    if (_isAccepting) return;
    setState(() {
      _isAccepting = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      // Get current position
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final lat = pos.latitude;
      final lon = pos.longitude;

      // Log and show immediate feedback
      // Update backend status to 'on-progress' when technician accepts
      final success = await TechnicianService.updateTaskStatus(widget.task.claimId, 'on-progress');

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accepted task — starting now. Current location: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}')),
        );

        // Update local status
        setState(() {
          _localStatus = 'on-progress';
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept task')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _requestTaskReopen() async {
    if (_isRequestingReopen) return;

    setState(() {
      _isRequestingReopen = true;
    });

    try {
      // Call the backend API to request re-open (does NOT change status)
      final success = await TechnicianService.requestReopen(
        widget.task.claimId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Re-open Request Sent',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Admin will review and re-open task #${widget.task.claimId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Request Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Could not send re-open request for task #${widget.task.claimId}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Error',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        e.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingReopen = false;
        });
      }
    }
  }
}

// Additional helper classes
class MapModal extends StatefulWidget {
  final double latitude;
  final double longitude;

  const MapModal({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  @override
  State<MapModal> createState() => _MapModalState();
}

class _MapModalState extends State<MapModal> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.latitude, widget.longitude);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🗺️ Location Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '✕',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoRow(
                    label: 'Latitude',
                    value: widget.latitude.toStringAsFixed(6),
                  ),
                  const SizedBox(height: 8),
                  InfoRow(
                    label: 'Longitude',
                    value: widget.longitude.toStringAsFixed(6),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: position,
                      initialZoom: 15.0,
                      minZoom: 2.0,
                      maxZoom: 19.0,
                      interactionOptions: const InteractionOptions(
                        flags: ~InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.trip.claim.app',
                        tileProvider: NetworkTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: position,
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Location: ${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF667eea),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF667eea).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
