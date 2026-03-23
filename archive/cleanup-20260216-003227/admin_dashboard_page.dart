import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/admin_websocket_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with WidgetsBindingObserver {
  List<dynamic> _allClaims = [];
  final Map<String, dynamic> _statistics = {};
  final bool _isLoading = false;
  final String _selectedStatus = 'all';
  final int _currentPage = 1;
  final int _totalPages  = 1;
  late Timer _autoRefreshTimer;
  late Timer _backgroundSyncTimer;
  AppLifecycleState? _lastLifecycleState;
  bool _wsConnected = false;
  
  final List<String> _statuses = ['all', 'pending', 'on-progress', 'rejected', 'completed'];

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize WebSocket for real-time updates
    _initializeWebSocket();
    
    // Aggressive background sync: Poll every 1 second for real-time updates
    // This ensures technician status changes are visible within 1 second in admin dashboard
    _backgroundSyncTimer = Timer.periodic(Duration(milliseconds: 1000), (_) {
      if (mounted) {
        _silentRefreshClaims();
      }
    });
    
    // Fallback full refresh: Every 15 seconds including statistics
    _autoRefreshTimer = Timer.periodic(Duration(seconds: 15), (_) {
      if (mounted) {
        _loadData();
      }
    });
    
    print('✅ Admin Dashboard initialized with real-time sync (1-second polling + WebSocket)');
    print('   Auto-sync will continue even when app is backgrounded');
  }

  /// Initialize WebSocket connection for real-time updates
  Future<void> _initializeWebSocket() async {
    try {
      final baseUrl = ApiService.baseUrl;
      print('🔗 Initializing WebSocket connection...');
      
      final success = await AdminWebSocketService.connect(
        baseUrl,
        _handleRealtimeStatusUpdate,
        onNewClaim: _handleNewClaim,
        onClaimsChanged: _handleClaimsChanged,
      );
      
      if (success && mounted) {
        setState(() => _wsConnected = true);
        print('✅ WebSocket connected - Real-time updates enabled');
      } else {
        print('⚠️ WebSocket connection failed - Falling back to polling');
      }
    } catch (e) {
      print('❌ WebSocket initialization error: $e');
    }
  }

  /// Handle real-time status update from WebSocket
  void _handleRealtimeStatusUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    final claimId = data['claimId'];
    final newStatus = data['newStatus'];
    final updatedClaim = data['claim'];

    print('⚡ [REALTIME] Updating claim $claimId to status: $newStatus');

    // Find and update the claim in the list
    setState(() {
      for (int i = 0; i < _allClaims.length; i++) {
        if (_allClaims[i]['id'] == claimId) {
          _allClaims[i]['status'] = newStatus;
          _allClaims[i] = updatedClaim; // Update entire claim with latest data
          print('   ✅ Claim updated in dashboard - Status: $newStatus');
          break;
        }
      }
    });

    // Trigger haptic feedback
    HapticFeedback.mediumImpact();
    
    // Show a toast/snackbar notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Claim updated: $claimId → $newStatus'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Handle new claim created in real-time
  void _handleNewClaim(dynamic claim) {
    if (!mounted) return;

    print('✨ [REALTIME] New claim received: ${claim['id']}');

    setState(() {
      _allClaims.insert(0, claim);
      // Update statistics
      _statistics['total'] = (_statistics['total'] ?? 0) + 1;
      _statistics['pending'] = (_statistics['pending'] ?? 0) + 1;
    });

    HapticFeedback.mediumImpact();
  }

  /// Handle claims changed event
  void _handleClaimsChanged(dynamic claims) {
    if (!mounted) return;

    print('📊 [REALTIME] Claims list updated: ${claims.length} claims');

    setState(() {
      _allClaims = List.from(claims);
    });
  }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground - force immediate sync
      print('📱 App resumed - forcing immediate sync of trip claims');
      _loadData();
      _silentRefreshClaims();
    } else if (state == AppLifecycleState.paused) {
      print('📱 App paused - background sync timers continue');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer.cancel();
    _backgroundSyncTimer.cancel();
    
    // Disconnect WebSocket
    AdminWebSocketService.disconnect();
    print('🔌 Admin Dashboard WebSocket disconnected');
    
    super.dispose();
  }

  /// Silent background refresh - updates claims without showing loading spinner
  Future<void> _silentRefreshClaims() async {
    try {
      // Always fetch without any filter to ensure we get all possible updates
      final response = await ApiService.getAdminAllClaims(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        page: _currentPage,
        limit: 10,
      ).timeout(Duration(seconds: 10));

      if (response['success'] == true && mounted) {
        final newClaims = response['data'] ?? [];
        
        // Check for changes
        if (_claimsChanged(_allClaims, newClaims)) {
          print('🔄 [AUTO-SYNC] ${DateTime.now().toString().split('.')[0]} - Trip Claims updated from backend (Filter: $_selectedStatus)');
          _printClaimsSnapshot(newClaims);
          
          // Update state immediately
          setState(() {
            _allClaims = newClaims;
            final pagination = response['pagination'] ?? {};
            _totalPages = pagination['pages'] ?? 1;
          });
        }
      } else if (response['success'] != true) {
        print('⚠️ Auto-sync API returned error: ${response['message']}');
      }
    } catch (e) {
      // Increment error counter, but for now just log
      print('⚠️ Background sync error (will retry in 1 second): $e');
    }
  }

  /// Print current claims snapshot for debugging
  void _printClaimsSnapshot(List<dynamic> claims) {
    for (var claim in claims) {
      final id = claim['id'] ?? 'unknown';
      final status = claim['status'] ?? 'unknown';
      final description = claim['description'] ?? claim['title'] ?? 'N/A';
      print('   📋 [$id] Status: $status - $description');
    }
  }

  /// Check if claims list has changed (diffing by status/id)
  bool _claimsChanged(List<dynamic> oldClaims, List<dynamic> newClaims) {
    if (oldClaims.length != newClaims.length) {
      print('   [Changed: Length] ${oldClaims.length} → ${newClaims.length}');
      return true;
    }
    
    for (int i = 0; i < oldClaims.length; i++) {
      final oldId = oldClaims[i]['id'];
      final newId = newClaims[i]['id'];
      final oldStatus = oldClaims[i]['status'];
      final newStatus = newClaims[i]['status'];
      
      if (oldStatus != newStatus) {
        print('   [✨ Status Changed] $oldId: $oldStatus → $newStatus');
        return true;
      }
      if (oldId != newId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load statistics
      final statsResponse = await ApiService.getAdminStatistics();
      if (statsResponse['success'] == true) {
        setState(() => _statistics = statsResponse['data'] ?? {});
      }

      // Load claims
      await _loadClaims();
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClaims() async {
    try {
      final response = await ApiService.getAdminAllClaims(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        page: _currentPage,
        limit: 10,
      );

      if (response['success'] == true) {
        setState(() {
          _allClaims = response['data'] ?? [];
          final pagination = response['pagination'] ?? {};
          _totalPages = pagination['pages'] ?? 1;
        });
      }
    } catch (e) {
      print('Error loading claims: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading claims: $e')),
      );
    }
  }

  void _changeStatus(String status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
    });
    _loadClaims();
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() => _currentPage--);
      _loadClaims();
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() => _currentPage++);
      _loadClaims();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        elevation: 0,
        backgroundColor: Color(0xFF1976D2),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Statistics Cards
                  _buildStatisticsSection(),
                  
                  SizedBox(height: 24),
                  
                  // Status Filter
                  _buildStatusFilter(),
                  
                  SizedBox(height: 16),
                  
                  // Claims List
                  _buildClaimsList(),
                  
                  SizedBox(height: 16),
                  
                  // Pagination
                  _buildPagination(),
                  
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      color: Color(0xFF1976D2),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildStatCard('Total Claims', '${_statistics['total'] ?? 0}', Colors.white),
              _buildStatCard('Pending', '${_statistics['pending'] ?? 0}', Colors.orange),
              _buildStatCard('Approved', '${_statistics['approved'] ?? 0}', Colors.green),
              _buildStatCard('Rejected', '${_statistics['rejected'] ?? 0}', Colors.red),
              _buildStatCard('Completed', '${_statistics['completed'] ?? 0}', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter by Status',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statuses
                  .map((status) => Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: _selectedStatus == status,
                          onSelected: (_) => _changeStatus(status),
                          backgroundColor: Colors.grey[200],
                          selectedColor: Color(0xFF1976D2),
                          labelStyle: TextStyle(
                            color: _selectedStatus == status ? Colors.white : Colors.black,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimsList() {
    if (_allClaims.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No claims found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _allClaims.length,
        itemBuilder: (context, index) {
          final claim = _allClaims[index];
          return _buildClaimCard(claim);
        },
      ),
    );
  }

  Widget _buildClaimCard(dynamic claim) {
    final status = claim['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final location = claim['location'] ?? 'N/A';
    final description = claim['description'] ?? 'No description';
    final userPhone = claim['userPhone'] ?? 'Unknown';
    final createdAt = claim['createdAt'] ?? '';
    final images = claim['images'] as List? ?? [];
    final imagesCount = images.length;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: GestureDetector(
          onTap: () {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      description.length > 40
                          ? '${description.substring(0, 40)}...'
                          : description,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Phone: $userPhone',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Location: $location',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Images: $imagesCount | ID: ${claim['id'].toString().substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Full ID', claim['id'] ?? 'N/A'),
                Divider(),
                _buildDetailRow('User Phone', userPhone),
                Divider(),
                _buildDetailRow('Location', location),
                Divider(),
                _buildDetailRow('Status', status.toUpperCase(), statusColor),
                Divider(),
                Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(description),
                if (claim['notes'] != null && claim['notes'].isNotEmpty) ...[
                  Divider(),
                  Text(
                    'Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(claim['notes']),
                ],
                if (claim['images'] != null && (claim['images'] as List).isNotEmpty) ...[
                  Divider(),
                  Text(
                    'Images: ${(claim['images'] as List).length}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                Divider(),
                _buildDetailRow('Created', _formatDate(createdAt)),
                Divider(),
                _buildDetailRow('Updated', _formatDate(claim['updatedAt'] ?? '')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: _currentPage > 1 ? _previousPage : null,
            icon: Icon(Icons.arrow_back),
            label: Text('Previous'),
          ),
          Text(
            'Page $_currentPage of $_totalPages',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ElevatedButton.icon(
            onPressed: _currentPage < _totalPages ? _nextPage : null,
            icon: Icon(Icons.arrow_forward),
            label: Text('Next'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'on-progress':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
