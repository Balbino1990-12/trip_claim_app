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
    print('Parsing TechnicianTask: ID=${json['id']}, Value: ${json['images']}');
    return TechnicianTask(
      id: json['id']?.toString() ?? 'N/A',
      claimId: json['claimId']?.toString() ?? json['id']?.toString() ?? 'N/A',
      title:
          json['title']?.toString() ??
          json['description']?.toString() ??
          'Untitled Task',
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
    print('Extracting images from: $images');
    if (images is List) {
      for (var image in images) {
        if (image is String) {
          imagesList.add(image);
        } else if (image is Map) {
          final imageUrl =
              image['imageUrl']?.toString() ?? image['url']?.toString();
          if (imageUrl != null) {
            imagesList.add(imageUrl);
          }
        }
      }
    }
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

  /// Extract latitude from nested location object
  static double _extractLatitude(Map<String, dynamic> json) {
    try {
      print('Extracting latitude from: ${json['location']}');
      // Try nested location object first
      if (json['location'] != null && json['location'] is Map) {
        final location = json['location'] as Map<String, dynamic>;
        print('Location object: $location');
        if (location['latitude'] != null) {
          final lat = location['latitude'];
          if (lat is int) return lat.toDouble();
          if (lat is double) return lat;
        }
      }
      // Fallback to root level
      if (json['latitude'] != null) {
        final lat = json['latitude'];
        if (lat is int) return lat.toDouble();
        if (lat is double) return lat;
      }
      // Return default
      return 10.6899;
    } catch (e) {
      return 10.6899;
    }
  }

  /// Extract longitude from nested location object
  static double _extractLongitude(Map<String, dynamic> json) {
    try {
      // Try nested location object first
      if (json['location'] != null && json['location'] is Map) {
        final location = json['location'] as Map<String, dynamic>;
        print('Location object for longitude: $location');
        if (location['longitude'] != null) {
          final lng = location['longitude'];
          if (lng is int) return lng.toDouble();
          if (lng is double) return lng;
        }
      }
      // Fallback to root level
      if (json['longitude'] != null) {
        final lng = json['longitude'];
        if (lng is int) return lng.toDouble();
        if (lng is double) return lng;
      }
      // Return default
      return 77.1025;
    } catch (e) {
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
  }

  /// Check if user is authenticated
  static bool isAuthenticated() =>
      _bearerToken != null && _bearerToken!.isNotEmpty;

  /// Get technician statistics from API
  static Future<TechnicianStats> getTechnicianStats() async {
    try {
      if (!isAuthenticated()) {
        print('getTechnicianStats was called after login');
        return TechnicianStats.getDefault();
      }

      final url = '${ApiService.baseUrl}/technician/stats';
      print('Fetching technician stats from: $url');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          return TechnicianStats.fromJson(json);
        } catch (parseError) {
          print('Error parsing technician stats: $parseError');
          return TechnicianStats.getDefault();
        }
      } else if (response.statusCode == 404) {
        print('Technician stats endpoint not found, computing from claims');
        return _computeStatsFromClaims();
      } else if (response.statusCode == 401) {
        print('Unauthorized access to technician stats');
        return TechnicianStats.getDefault();
      } else {
        print('Failed to fetch technician stats: ${response.statusCode}');
        return _computeStatsFromClaims();
      }
    } on TimeoutException {
      print('Timeout fetching technician stats');
      return _computeStatsFromClaims();
    } catch (e) {
      print('Error fetching technician stats: $e');
      return TechnicianStats.getDefault();
    }
  }

  /// Compute stats by analyzing tasks
  static Future<TechnicianStats> _computeStatsFromClaims() async {
    try {
      // Get tasks using the same fallback method
      final tasks = await getAssignedTasks();

      if (tasks.isEmpty) {
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
        } else if (status == 'on-progress' || status == 'on progress') {
          inProgress++;
        } else if (status == 'completed' || status == 'solved') {
          completed++;
        }
      }

      final stats = TechnicianStats(
        pendingTasks: pending,
        inProgressTasks: inProgress,
        completedTasks: completed,
        rating: 4.8, // Default rating
        totalTasksToday: tasks.length,
      );

      return stats;
    } catch (e) {
      return TechnicianStats.getDefault();
    }
  }

  /// Get assigned tasks for technician from API
  /// Tries multiple endpoints and fallback methods
  static Future<List<TechnicianTask>> getAssignedTasks() async {
    try {
      if (!isAuthenticated()) {
        print('getAssignedTasks was called after login');
        return [];
      }

      final url = '${ApiService.baseUrl}/technician/tasks';
      print('Fetching tasks from: $url');

      try {
        final response = await http
            .get(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $_bearerToken',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 15));

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
                .map(
                  (item) =>
                      TechnicianTask.fromJson(item as Map<String, dynamic>),
                )
                .toList();
            return tasks;
          } catch (parseError) {
            print('Error parsing tasks: $parseError');
            return [];
          }
        } else if (response.statusCode == 404) {
          print('Technician tasks endpoint not found, trying claims endpoint');
          return _getTasksFromClaimsEndpoint();
        } else if (response.statusCode == 401) {
          print('Unauthorized - Token expired');
          return [];
        } else {
          print('Failed to fetch tasks, trying claims endpoint');
          return _getTasksFromClaimsEndpoint();
        }
      } on TimeoutException {
        print('Timeout fetching tasks, trying claims endpoint');
        return _getTasksFromClaimsEndpoint();
      }
    } catch (e) {
      print('Error in getAssignedTasks: $e');
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
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

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
              .map(
                (item) => TechnicianTask.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          return tasks;
        } catch (e) {
          return [];
        }
      } else if (response.statusCode == 404) {
        print('My claims endpoint not found, trying all claims endpoint');
        return _getTasksFromAllClaimsEndpoint();
      }
      return [];
    } catch (e) {
      print('Error in _getTasksFromClaimsEndpoint: $e');
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
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

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
                final status = (item is Map
                    ? item['status']?.toString().toLowerCase()
                    : '');
                return status != 'completed' && status != 'rejected';
              })
              .map(
                (item) => TechnicianTask.fromJson(item as Map<String, dynamic>),
              )
              .toList();

          return tasks;
        } catch (e) {
          return [];
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Update task status (complete, reject, etc.)
  static Future<bool> updateTaskStatus(String claimId, String newStatus) async {
    try {
      if (!isAuthenticated()) {
        return false;
      }

      final requestBody = jsonEncode({'status': newStatus});
      final response = await http
          .put(
            Uri.parse('${ApiService.baseUrl}/claims/$claimId/status'),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Request admin to re-open a rejected task (does not change status)
  static Future<bool> requestReopen(String claimId) async {
    try {
      if (!isAuthenticated()) {
        return false;
      }

      final url = '${ApiService.baseUrl}/claims/$claimId/request-reopen';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_bearerToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Upload a photo for a task
  static Future<bool> uploadTaskPhoto(String claimId, String photoPath) async {
    try {
      if (!isAuthenticated()) {
        return false;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/claims/$claimId/upload'),
      );

      request.headers['Authorization'] = 'Bearer $_bearerToken';
      request.files.add(await http.MultipartFile.fromPath('image', photoPath));

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
