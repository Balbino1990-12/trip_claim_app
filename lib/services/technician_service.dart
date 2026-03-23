import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'api_service.dart';

class TechnicianTask {
  final String id;
  final String claimId;
  final String title;
  final String description;
  final String location;
  final String status;
  final String priority;
  final DateTime? assignedDate;
  final String? clientName;
  final String? clientPhone;
  final double? latitude;
  final double? longitude;
  final List<String> images;

  TechnicianTask({
    required this.id,
    required this.claimId,
    required this.title,
    required this.description,
    required this.location,
    required this.status,
    required this.priority,
    this.assignedDate,
    this.clientName,
    this.clientPhone,
    this.latitude,
    this.longitude,
    this.images = const [],
  });

  factory TechnicianTask.fromJson(Map<String, dynamic> json) {
    print('? Task.fromJson - Has images: ${json.containsKey('images')}, Value: ${json['images']}');
    print('?? Task coordinates - Latitude: ${json['latitude']}, Longitude: ${json['longitude']}');
    print('?? Full task JSON keys: ${json.keys.toList()}');
    return TechnicianTask(
      id: json['id']?.toString() ?? 'N/A',
      claimId: json['claimId']?.toString() ?? json['id']?.toString() ?? 'N/A',
      title: json['title']?.toString() ?? json['description']?.toString() ?? 'Untitled Task',
      description: json['description']?.toString() ?? '',
      location: _extractLocation(json),
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      priority: _getPriority(json),
      assignedDate: _parseDate(json['assignedDate'] ?? json['createdAt']),
      clientName: _extractClientName(json),
      clientPhone: _extractClientPhone(json),
      latitude: _extractLatitude(json),
      longitude: _extractLongitude(json),
      images: _extractImages(json),
    );
  }

  /// Extract images from the JSON response
  static List<String> _extractImages(Map<String, dynamic> json) {
    List<String> imagesList = [];
    dynamic images = json['images'];
    print('?? _extractImages - Raw JSON keys: ${json.keys.toList()}');
    print('?? _extractImages called, raw images: $images (type: ${images.runtimeType})');
    if (images is List) {
      for (var image in images) {
        if (image is String) {
          imagesList.add(image);
        } else if (image is Map) {
          final imageUrl = image['imageUrl']?.toString() ?? image['url']?.toString();
          if (imageUrl != null) {
            imagesList.add(imageUrl);
          }
        }
      }
    }
    print('?? _extractImages result: $imagesList');
    return imagesList;
  }

  /// Extract location address from nested object
  static String _extractLocation(Map<String, dynamic> json) {
    // Try nested location object
    if (json['location'] != null && json['location'] is Map) {
      final location = json['location'] as Map<String, dynamic>;
      if (location['address'] != null) {
        return location['address'].toString();
      }
    }
    // Try root level
    if (json['address'] != null) {
      return json['address'].toString();
    }
    return 'Location not provided';
  }

  /// Extract client name from JSON
  static String? _extractClientName(Map<String, dynamic> json) {
    if (json.containsKey('clientName') && json['clientName'] != null) {
      return json['clientName'].toString();
    }
    if (json.containsKey('userName') && json['userName'] != null) {
      return json['userName'].toString();
    }
    if (json.containsKey('user') && json['user'] is Map) {
      final user = json['user'] as Map<String, dynamic>;
      if (user['name'] != null) return user['name'].toString();
    }
    return null;
  }

  /// Extract client phone from JSON
  static String? _extractClientPhone(Map<String, dynamic> json) {
    if (json.containsKey('clientPhone') && json['clientPhone'] != null) {
      return json['clientPhone'].toString();
    }
    if (json.containsKey('userPhone') && json['userPhone'] != null) {
      return json['userPhone'].toString();
    }
    if (json.containsKey('user') && json['user'] is Map) {
      final user = json['user'] as Map<String, dynamic>;
      if (user['phone'] != null) return user['phone'].toString();
    }
    return null;
  }

  /// Get priority level for display
  static String _getPriority(Map<String, dynamic> json) {
    final priority = json['priority']?.toString().toLowerCase() ?? 'medium';
    return priority;
  }

  /// Parse date from ISO string or timestamp
  static DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return null;
      }
    }
    if (dateValue is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Extract latitude from nested location object
  static double _extractLatitude(Map<String, dynamic> json) {
    try {
      print('🔍 _extractLatitude: Extracting from json');
      print('🔍 _extractLatitude: json.keys = ${json.keys.toList()}');
      print('🔍 _extractLatitude: json["location"] = ${json['location']}');
      
      // Try nested location object first
      if (json['location'] != null && json['location'] is Map) {
        final location = json['location'] as Map<String, dynamic>;
        print('🔍 _extractLatitude: location.keys = ${location.keys.toList()}');
        print('🔍 _extractLatitude: location["latitude"] = ${location['latitude']}');
        
        if (location['latitude'] != null) {
          final lat = location['latitude'];
          print('✅ _extractLatitude: Found nested latitude = $lat');
          if (lat is int) return lat.toDouble();
          if (lat is double) return lat;
        }
      }
      // Fallback to root level
      if (json['latitude'] != null) {
        final lat = json['latitude'];
        print('✅ _extractLatitude: Found root latitude = $lat');
        if (lat is int) return lat.toDouble();
        if (lat is double) return lat;
      }
      // Return default
      print('⚠️ _extractLatitude: Using default 10.6899');
      return 10.6899;
    } catch (e) {
      print('❌ _extractLatitude Exception: $e');
      return 10.6899;
    }
  }

  /// Extract longitude from nested location object
  static double _extractLongitude(Map<String, dynamic> json) {
    try {
      print('🔍 _extractLongitude: Extracting from json');
      print('🔍 _extractLongitude: json["location"] = ${json['location']}');
      
      // Try nested location object first
      if (json['location'] != null && json['location'] is Map) {
        final location = json['location'] as Map<String, dynamic>;
        print('🔍 _extractLongitude: location.keys = ${location.keys.toList()}');
        print('🔍 _extractLongitude: location["longitude"] = ${location['longitude']}');
        
        if (location['longitude'] != null) {
          final lng = location['longitude'];
          print('✅ _extractLongitude: Found nested longitude = $lng');
          if (lng is int) return lng.toDouble();
          if (lng is double) return lng;
        }
      }
      // Fallback to root level
      if (json['longitude'] != null) {
        final lng = json['longitude'];
        print('✅ _extractLongitude: Found root longitude = $lng');
        if (lng is int) return lng.toDouble();
        if (lng is double) return lng;
      }
      // Return default
      print('⚠️ _extractLongitude: Using default 77.1025');
      return 77.1025;
    } catch (e) {
      print('❌ _extractLongitude Exception: $e');
      return 77.1025;
    }
  }
}

class TechnicianStats {
  final int pendingTasks;
  final int completedTasks;
  final int inProgressTasks;
  final double rating;
  final int totalTasksToday;

  TechnicianStats({
    required this.pendingTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.rating,
    required this.totalTasksToday,
  });

  factory TechnicianStats.fromJson(Map<String, dynamic> json) {
    return TechnicianStats(
      pendingTasks: json['pendingTasks'] ?? 0,
      completedTasks: json['completedTasks'] ?? 0,
      inProgressTasks: json['inProgressTasks'] ?? 0,
      rating: (json['rating'] ?? 4.8).toDouble(),
      totalTasksToday: json['totalTasksToday'] ?? 0,
    );
  }

  /// Get default TechnicianStats (for error fallback)
  static TechnicianStats getDefault() {
    return TechnicianStats(
      pendingTasks: 0,
      completedTasks: 0,
      inProgressTasks: 0,
      rating: 4.8,
      totalTasksToday: 0,
    );
  }
}

class TechnicianService {
  static String? _bearerToken;

  /// Set the JWT authentication token for API requests
  static void setAuthToken(String token) {
    _bearerToken = token;
    ApiService.setAuthToken(token);
    print('✅ TechnicianService: Auth token set');
  }

  /// Check if user is authenticated
  static bool isAuthenticated() => _bearerToken != null && _bearerToken!.isNotEmpty;

  /// Get technician statistics from API
  static Future<TechnicianStats> getTechnicianStats() async {
    try {
      if (!isAuthenticated()) {
        print('❌ getTechnicianStats: Not authenticated - token is null or empty');
        print('❌ Please ensure TechnicianService.setAuthToken() was called after login');
        return TechnicianStats.getDefault();
      }

      final url = '${ApiService.baseUrl}/technician/stats';
      print('\n📡 getTechnicianStats: Fetching from $url');
      print('🔐 Using token: ${_bearerToken?.substring(0, 20)}...');

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $_bearerToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        print('📊 Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          try {
            final json = jsonDecode(response.body);
            print('✅ getTechnicianStats: Success');
            return TechnicianStats.fromJson(json);
          } catch (parseError) {
            print('❌ Error parsing stats response: $parseError');
            return TechnicianStats.getDefault();
          }
        } else if (response.statusCode == 404) {
          print('⚠️ /technician/stats endpoint not found (404)');
          print('   Attempting fallback: Computing stats from claims...');
          return _computeStatsFromClaims();
        } else if (response.statusCode == 401) {
          print('❌ getTechnicianStats: Unauthorized (401)');
          return TechnicianStats.getDefault();
        } else {
          print('❌ getTechnicianStats: HTTP ${response.statusCode}');
          return _computeStatsFromClaims();
        }
      } on TimeoutException {
        print('❌ getTechnicianStats: Request timeout');
        return _computeStatsFromClaims();
      }
    } catch (e) {
      print('❌ getTechnicianStats Exception: $e');
      return TechnicianStats.getDefault();
    }
  }

  /// Compute stats by analyzing tasks
  static Future<TechnicianStats> _computeStatsFromClaims() async {
    try {
      print('   📊 Computing stats from available tasks...');
      
      // Get tasks using the same fallback method
      final tasks = await getAssignedTasks();
      
      if (tasks.isEmpty) {
        print('   ⚠️ No tasks found - returning default stats');
        return TechnicianStats.getDefault();
      }
      
      // Count by status
      int pending = 0;
      int inProgress = 0;
      int completed = 0;
      
      for (final task in tasks) {
        final status = task.status.toLowerCase();
        if (status == 'pending') {
          pending++;
        } else if (status == 'on-progress' || status == 'on progress') inProgress++;
        else if (status == 'completed' || status == 'solved') completed++;
      }
      
      final stats = TechnicianStats(
        pendingTasks: pending,
        inProgressTasks: inProgress,
        completedTasks: completed,
        rating: 4.8, // Default rating
        totalTasksToday: tasks.length,
      );
      
      print('   ✅ Stats computed: ${stats.pendingTasks} pending, ${stats.inProgressTasks} in progress, ${stats.completedTasks} completed');
      return stats;
    } catch (e) {
      print('   ❌ Error computing stats: $e');
      return TechnicianStats.getDefault();
    }
  }

  /// Get assigned tasks for technician from API
  /// Tries multiple endpoints and fallback methods
  static Future<List<TechnicianTask>> getAssignedTasks() async {
    try {
      if (!isAuthenticated()) {
        print('❌ getAssignedTasks: Not authenticated - token is null or empty');
        print('❌ Please ensure TechnicianService.setAuthToken() was called after login');
        return [];
      }

      final url = '${ApiService.baseUrl}/technician/tasks';
      print('\n📡 getAssignedTasks: Attempting to fetch from $url');
      print('🔐 Using token: ${_bearerToken?.substring(0, 20)}...');

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $_bearerToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));

        print('📊 Response Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          try {
            final json = jsonDecode(response.body);
            
            // Handle different response formats
            List taskList = [];
            if (json is List) {
              taskList = json;
            } else if (json is Map && json.containsKey('data')) {
              taskList = json['data'] is List ? json['data'] : [];
            } else if (json is Map && json.containsKey('tasks')) {
              taskList = json['tasks'] is List ? json['tasks'] : [];
            }
            
            final tasks = taskList
                .map((item) => TechnicianTask.fromJson(item as Map<String, dynamic>))
                .toList();
            print('✅ getAssignedTasks: Success - ${tasks.length} tasks loaded');
            return tasks;
          } catch (parseError) {
            print('❌ Error parsing response JSON: $parseError');
            return [];
          }
        } else if (response.statusCode == 404) {
          print('⚠️ /technician/tasks endpoint not found (404)');
          print('   Attempting fallback: Using /claims endpoint instead...');
          return _getTasksFromClaimsEndpoint();
        } else if (response.statusCode == 401) {
          print('❌ getAssignedTasks: Unauthorized (401) - Token expired');
          return [];
        } else {
          print('❌ getAssignedTasks: HTTP ${response.statusCode}');
          return _getTasksFromClaimsEndpoint();
        }
      } on TimeoutException {
        print('❌ getAssignedTasks: Request timeout');
        return _getTasksFromClaimsEndpoint();
      }
    } catch (e) {
      print('❌ getAssignedTasks Exception: $e');
      return [];
    }
  }

  /// Fallback method: Get tasks from /claims endpoint
  static Future<List<TechnicianTask>> _getTasksFromClaimsEndpoint() async {
    try {
      if (!isAuthenticated()) {
        return [];
      }

      final url = '${ApiService.baseUrl}/claims/my-claims';
      print('   📡 Trying alternative endpoint: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          
          List taskList = [];
          if (json is List) {
            taskList = json;
          } else if (json is Map && json.containsKey('data')) {
            taskList = json['data'] is List ? json['data'] : [];
          } else if (json is Map && json.containsKey('claims')) {
            taskList = json['claims'] is List ? json['claims'] : [];
          }
          
          final tasks = taskList
              .map((item) => TechnicianTask.fromJson(item as Map<String, dynamic>))
              .toList();
          print('   ✅ Alternative endpoint success - ${tasks.length} tasks loaded');
          return tasks;
        } catch (e) {
          print('   ❌ Error parsing alternative endpoint: $e');
          return [];
        }
      } else if (response.statusCode == 404) {
        print('   ⚠️ Alternative endpoint also not found (404)');
        print('   📡 Trying: ${ApiService.baseUrl}/claims');
        return _getTasksFromAllClaimsEndpoint();
      }
      return [];
    } catch (e) {
      print('   ❌ Alternative endpoint failed: $e');
      return _getTasksFromAllClaimsEndpoint();
    }
  }

  /// Final fallback: Get all claims and filter by status
  static Future<List<TechnicianTask>> _getTasksFromAllClaimsEndpoint() async {
    try {
      if (!isAuthenticated()) {
        return [];
      }

      final url = '${ApiService.baseUrl}/claims';
      print('   📡 Trying generic endpoint: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          
          List taskList = [];
          if (json is List) {
            taskList = json;
          } else if (json is Map && json.containsKey('data')) {
            taskList = json['data'] is List ? json['data'] : [];
          } else if (json is Map && json.containsKey('claims')) {
            taskList = json['claims'] is List ? json['claims'] : [];
          }
          
          // Filter out completed tasks to show only active ones
          final tasks = taskList
              .where((item) {
                final status = (item is Map ? item['status']?.toString().toLowerCase() : '');
                return status != 'completed' && status != 'rejected';
              })
              .map((item) => TechnicianTask.fromJson(item as Map<String, dynamic>))
              .toList();
          
          print('   ✅ Generic endpoint success - ${tasks.length} active tasks loaded');
          return tasks;
        } catch (e) {
          print('   ❌ Error parsing generic endpoint: $e');
          return [];
        }
      }
      
      print('   ⚠️ No endpoints available - returning empty list');
      print('   Please ensure backend has one of: /technician/tasks, /claims/my-claims, or /claims');
      return [];
    } catch (e) {
      print('   ❌ Generic endpoint failed: $e');
      return [];
    }
  }

  /// Update task status (complete, reject, etc.)
  static Future<bool> updateTaskStatus(String claimId, String newStatus) async {
    try {
      if (!isAuthenticated()) {
        print('❌ updateTaskStatus: Not authenticated');
        return false;
      }

      print('📤 updateTaskStatus - Sending request:');
      print('   URL: ${ApiService.baseUrl}/claims/$claimId/status');
      print('   Method: PUT');
      print('   Claim ID: $claimId');
      print('   New Status: $newStatus');
      print('   Bearer Token: $_bearerToken');

      final requestBody = jsonEncode({'status': newStatus});
      print('   Request Body: $requestBody');

      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/claims/$claimId/status'),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 10));

      print('📥 updateTaskStatus - Response received:');
      print('   Status Code: ${response.statusCode}');
      print('   Headers: ${response.headers}');
      print('   Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ updateTaskStatus: Status updated to $newStatus for $claimId');
        return true;
      } else {
        print('❌ updateTaskStatus: HTTP ${response.statusCode}');
        print('   Error Details: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ updateTaskStatus Exception: $e');
      return false;
    }
  }

  /// Request admin to re-open a rejected task (does not change status)
  static Future<bool> requestReopen(String claimId) async {
    try {
      if (!isAuthenticated()) {
        print('❌ requestReopen: Not authenticated');
        return false;
      }

      final url = '${ApiService.baseUrl}/claims/$claimId/request-reopen';
      print('📤 requestReopen - Sending POST to $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📥 requestReopen - Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('✅ requestReopen: Request submitted');
        return true;
      }
      print('❌ requestReopen: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ requestReopen Exception: $e');
      return false;
    }
  }

  /// Upload a photo for a task
  static Future<bool> uploadTaskPhoto(String claimId, String photoPath) async {
    try {
      if (!isAuthenticated()) {
        print('❌ uploadTaskPhoto: Not authenticated');
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/claims/$claimId/upload'),
      );

      request.headers['Authorization'] = 'Bearer $_bearerToken';
      request.files.add(await http.MultipartFile.fromPath('image', photoPath));

      final response = await request.send().timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ uploadTaskPhoto: Photo uploaded for $claimId');
        return true;
      } else {
        print('❌ uploadTaskPhoto: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ uploadTaskPhoto Exception: $e');
      return false;
    }
  }

  /// Send an update message for a task
  static Future<bool> sendTaskUpdate(String claimId, String message) async {
    try {
      if (!isAuthenticated()) {
        print('❌ sendTaskUpdate: Not authenticated');
        return false;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/claims/$claimId/update'),
        headers: {
          'Authorization': 'Bearer $_bearerToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ sendTaskUpdate: Update sent for $claimId');
        return true;
      } else {
        print('❌ sendTaskUpdate: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ sendTaskUpdate Exception: $e');
      return false;
    }
  }
}
