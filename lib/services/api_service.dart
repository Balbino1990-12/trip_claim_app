import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int? statusCode;
  final dynamic error;

  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    this.statusCode,
    this.error,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'] as dynamic,
      message: json['message'] ?? 'Unknown error',
      statusCode: json['statusCode'],
    );
  }
}

class ApiService {
  static String baseUrl =
      'http://10.91.220.92:5000/api'; // Backend API endpoint
  static String? _authToken;
  static String? _technicianId; // Store technician ID from login response
  static const int _timeoutSeconds = 30;
  static const int _tripClaimTimeoutSeconds = 180; // 3 minutes for slow servers
  static const int _uploadTimeoutSeconds = 180; // 3 minutes for uploads
  static const int _maxRetries = 3;
  static const int _initialRetryDelayMs = 1000; // Start with 1 second

  // HTTP client with connection pooling
  static final http.Client _httpClient = http.Client();

  /// Set base URL dynamically (automatically called when network changes)
  /// This is used by NetworkService to update the API endpoint when switching networks
  static void setBaseUrl(String url) {
    if (baseUrl != url) {
      baseUrl = url;
      print('📡 API Base URL changed to: $url');
    }
  }

  /// Retry a request with exponential backoff
  static Future<http.Response> _retryableRequest(
    Future<http.Response> Function() request,
    Duration timeout, {
    required String requestName,
  }) async {
    int retryCount = 0;
    Duration retryDelay = Duration(milliseconds: _initialRetryDelayMs);

    while (retryCount < _maxRetries) {
      try {
        print('📤 Attempt ${retryCount + 1}/$_maxRetries for $requestName...');
        final response = await request().timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            'Request timeout after ${timeout.inSeconds}s',
          ),
        );
        return response;
      } on TimeoutException {
        retryCount++;
        if (retryCount >= _maxRetries) {
          print('✗ $requestName failed after $_maxRetries attempts (timeout)');
          rethrow;
        }
        print('⏳ Timeout - retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
        // Exponential backoff: double the delay for next retry
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
      } on SocketException {
        retryCount++;
        if (retryCount >= _maxRetries) {
          print('✗ $requestName failed after $_maxRetries attempts (socket error)');
          rethrow;
        }
        print('⏳ Socket error - retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
        retryDelay = Duration(milliseconds: retryDelay.inMilliseconds * 2);
      }
    }

    throw Exception('Max retries exceeded for $requestName');
  }

  // Set authentication token (call this after successful login)
  static void setAuthToken(String token) {
    _authToken = token;
  }

  // Set technician ID (call this after successful login)
  static void setTechnicianId(String? id) {
    _technicianId = id;
    if (id != null) {
      print('Technician ID set: $id');
    }
  }

  // Get technician ID
  static String? getTechnicianId() {
    return _technicianId;
  }

  // Clear authentication token (call this on logout)
  static void clearAuthToken() {
    _authToken = null;
    _technicianId = null;
  }

  /// Check if backend server is reachable
  static Future<bool> isBackendReachable() async {
    try {
      print('🔍 Checking backend connectivity...');
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: _getHeaders(),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Health check timeout'),
          );

      bool isReachable = response.statusCode == 200;
      print(isReachable
          ? '✓ Backend is reachable'
          : '✗ Backend returned status: ${response.statusCode}');
      return isReachable;
    } catch (e) {
      print('✗ Backend unreachable: $e');
      print('📡 Ensure backend is running at: $baseUrl');
      return false;
    }
  }

  /// Get current API configuration (useful for debugging)
  static Map<String, dynamic> getApiConfig() {
    return {
      'baseUrl': baseUrl,
      'hasAuthToken': _authToken != null,
      'timeoutSeconds': _timeoutSeconds,
      'tripClaimTimeoutSeconds': _tripClaimTimeoutSeconds,
      'uploadTimeoutSeconds': _uploadTimeoutSeconds,
      'maxRetries': _maxRetries,
      'initialRetryDelayMs': _initialRetryDelayMs,
      'notes': 'Timeouts are increased for slow servers. Retries use exponential backoff.',
    };
  }

  /// Print performance and timeout diagnostics
  static void printDiagnostics() {
    print('\n${'='*60}');
    print('🔧 API SERVICE CONFIGURATION');
    print('='*60);
    print('Base URL: $baseUrl');
    print('Standard Timeout: ${_timeoutSeconds}s');
    print('Trip Claim Timeout: ${_tripClaimTimeoutSeconds}s');
    print('Upload Timeout: ${_uploadTimeoutSeconds}s');
    print('Max Retries: $_maxRetries');
    print('Initial Retry Delay: ${_initialRetryDelayMs}ms');
    print('\nRetry Strategy: Exponential Backoff');
    print('├─ Attempt 1: ${_initialRetryDelayMs}ms delay');
    print('├─ Attempt 2: ${_initialRetryDelayMs * 2}ms delay');
    print('├─ Attempt 3: ${_initialRetryDelayMs * 4}ms delay');
    print('└─ After 3 attempts → Failure\n');
    print('='*60 + '\n');
  }

  /// Login with phone number and password - returns authentication token
  static Future<ApiResponse<Map<String, dynamic>>> login({
    required String identifier, // phone number
    required String password,
  }) async {
    try {
      print('🔐 Attempting login for phone: $identifier');
      print('📡 API Base URL: $baseUrl');
      print('📡 Full Login URL: $baseUrl/auth/login');
      print('📱 Phone field: $identifier');
      print('🔑 Password field: $password');
      
      final requestBody = {
        'phoneNumber': identifier,  // Changed from 'phone' to 'phoneNumber'
        'password': password,
      };
      print('📤 Request body: $requestBody');

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _getHeaders(),
            body: jsonEncode(requestBody),
          )
          .timeout(
            Duration(seconds: _timeoutSeconds),
            onTimeout: () => throw TimeoutException(
              'Login request timeout after ${_timeoutSeconds}s',
            ),
          );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        print('✓ Login successful');

        // Extract token from response
        final token = jsonResponse['token'] ?? jsonResponse['accessToken'];
        if (token != null) {
          setAuthToken(token);
          print('✓ Authentication token set');
        }

        // Extract technician ID from user object
        final userId = jsonResponse['user']?['id'];
        if (userId != null) {
          setTechnicianId(userId);
        }

        final responseData = jsonResponse is Map<String, dynamic>
            ? jsonResponse
            : {'message': response.body} as Map<String, dynamic>;

        return ApiResponse(
          success: true,
          data: responseData,
          message: 'Login successful',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        // Try alternative endpoint if main one fails
        print('⚠️  Login endpoint failed with 400/401, trying alternative endpoint...');
        
        // Try /login instead of /auth/login
        final altResponse = await _httpClient
            .post(
              Uri.parse('$baseUrl/login'),
              headers: _getHeaders(),
              body: jsonEncode(requestBody),
            )
            .timeout(
              Duration(seconds: _timeoutSeconds),
            );

        print('📥 Alternative endpoint status: ${altResponse.statusCode}');
        print('📥 Alternative response body: ${altResponse.body}');

        if (altResponse.statusCode == 200 || altResponse.statusCode == 201) {
          final jsonResponse = jsonDecode(altResponse.body);
          final token = jsonResponse['token'] ?? jsonResponse['accessToken'];
          if (token != null) {
            setAuthToken(token);
          }
          return ApiResponse(
            success: true,
            data: jsonResponse is Map<String, dynamic> ? jsonResponse : {},
            message: 'Login successful',
            statusCode: altResponse.statusCode,
          );
        }

        final errorBody = _parseErrorResponse(response.body);
        print('✗ Login failed: ${response.statusCode}');
        print('Error details: $errorBody');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Login failed. Invalid credentials.',
          statusCode: response.statusCode,
          error: errorBody,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        print('✗ Login failed: ${response.statusCode}');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Login failed. Invalid credentials.',
          statusCode: response.statusCode,
          error: errorBody,
        );
      }
    } on TimeoutException catch (e) {
      print('✗ Login timeout: ${e.message}');
      return ApiResponse(
        success: false,
        message: 'Login request timed out. Backend server is not responding.',
        error: e,
      );
    } on SocketException catch (e) {
      print('✗ Network error during login: ${e.message}');
      return ApiResponse(
        success: false,
        message: 'Network error. Cannot reach backend at $baseUrl',
        error: e,
      );
    } catch (e) {
      print('✗ Unexpected login error: $e');
      return ApiResponse(
        success: false,
        message: 'An unexpected error occurred during login',
        error: e,
      );
    }
  }

  // Get headers with authentication
  static Map<String, String> _getHeaders({bool isMultipart = false}) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  // Send trip claim data with embedded base64 images
  static Future<ApiResponse<Map<String, dynamic>>> sendTripClaim({
    required String userPhone,
    required String description,
    required double latitude,
    required double longitude,
    required List<String> imageUrls,
    List<File>? imageFiles,
  }) async {
    try {
      print('📤 Sending trip claim to: $baseUrl/claims');
      print('📤 Phone: $userPhone, Image URLs: ${imageUrls.length}, Image Files: ${imageFiles?.length ?? 0}');
      
      // Convert image files to base64 if provided
      List<String> base64Images = [];
      if (imageFiles != null && imageFiles.isNotEmpty) {
        print('🖼️  Encoding ${imageFiles.length} images to base64...');
        for (int i = 0; i < imageFiles.length; i++) {
          try {
            final bytes = await imageFiles[i].readAsBytes();
            final base64 = base64Encode(bytes);
            base64Images.add(base64);
            print('   ✓ Image ${i+1} encoded (${bytes.length} bytes)');
          } catch (e) {
            print('   ✗ Failed to encode image ${i+1}: $e');
          }
        }
      }
      
      // Combine image URLs and base64 images
      final allImages = [...imageUrls, ...base64Images];
      
      // Prepare data
      final requestBody = {
        'userPhone': userPhone,
        'description': description,
        'location': '$latitude,$longitude',
        'latitude': latitude,
        'longitude': longitude,
        'images': allImages,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Debug: Show payload size
      final payloadJson = jsonEncode(requestBody);
      final payloadSize = payloadJson.length;
      print('📋 Payload size: ${(payloadSize / 1024).toStringAsFixed(2)} KB');
      print('📋 Request body starts with: ${payloadJson.substring(0, min(payloadJson.length, 200))}...');

      final response = await _retryableRequest(
        () => _httpClient.post(
          Uri.parse('$baseUrl/claims'),
          headers: _getHeaders(),
          body: payloadJson,
        ),
        Duration(seconds: _tripClaimTimeoutSeconds),
        requestName: 'Trip Claim',
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('✅ Trip claim sent successfully');
        print('📥 Backend response: ${response.body.substring(0, min(response.body.length, 200))}');
        final responseData = jsonResponse is Map<String, dynamic>
            ? jsonResponse
            : {'message': response.body} as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: responseData,
          message: 'Trip claim submitted successfully',
          statusCode: response.statusCode,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        print('❌ Failed to send trip claim: ${response.statusCode}');
        print('📥 Backend response: ${response.body}');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Failed to submit claim',
          statusCode: response.statusCode,
          error: errorBody,
        );
      }
    } on TimeoutException catch (e) {
      print('✗ Timeout error after all retries: ${e.message}');
      print('💡 Suggestion: Backend server is very slow. Ask your sysadmin to check server performance.');
      print('💡 Suggestion: Consider increasing serverTimeout on backend to handle slow connections.');
      return ApiResponse(
        success: false,
        message: 'Request timeout after multiple retries (${_tripClaimTimeoutSeconds}s each). '
            'Backend server is very slow to respond. Please check server performance or try again later.',
        error: e,
      );
    } on SocketException catch (e) {
      print('✗ Network error: ${e.message}');
      print('📡 Cannot reach $baseUrl. Check if backend is running.');
      return ApiResponse(
        success: false,
        message: 'Network error. Backend server is unreachable at $baseUrl',
        error: e,
      );
    } catch (e) {
      print('✗ Unexpected error: $e');
      return ApiResponse(
        success: false,
        message: 'An unexpected error occurred',
        error: e,
      );
    }
  }

  // Upload single image - NOTE: If backend doesn't have /upload endpoint,
  // use uploadImagesWithTripClaim() instead to send images with the trip claim
  static Future<ApiResponse<Map<String, dynamic>>> uploadImage(
    File imageFile,
  ) async {
    // Try multiple common image upload endpoints
    final endpointPaths = [
      '/upload',           // POST /api/upload
      '/images',           // POST /api/images
      '/images/upload',    // POST /api/images/upload
      '/file/upload',      // POST /api/file/upload
    ];
    
    print('📸 Uploading image: ${imageFile.path}');
    print('   Attempting to upload to one of: ${endpointPaths.join(", ")}');

    for (var endpoint in endpointPaths) {
      try {
        final uploadUrl = '$baseUrl$endpoint';
        print('\n🔍 Trying endpoint: $uploadUrl');

        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.headers.addAll(_getHeaders(isMultipart: true));
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );

        var response = await request.send().timeout(
          Duration(seconds: _uploadTimeoutSeconds),
          onTimeout: () => throw TimeoutException(
            'Upload timeout after ${_uploadTimeoutSeconds}s',
          ),
        );

        final responseData = await response.stream.bytesToString();
        print('   → HTTP ${response.statusCode}');
        print('   → Response: ${responseData.substring(0, min(responseData.length, 250))}${responseData.length > 250 ? '...' : ''}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final jsonResponse = jsonDecode(responseData);
          print('✅ Image uploaded successfully to $endpoint');
          
          final responseMap = jsonResponse is Map<String, dynamic> ? jsonResponse : null;
          
          if (responseMap != null) {
            print('📋 Response fields: ${responseMap.keys.toList()}');
          }
          
          // Extract URL from response
          String? imageUrl;
          if (responseMap != null) {
            final possibleFields = ['imageUrl', 'url', 'path', 'file_path', 'filePath', 
                                   'fileUrl', 'uploadUrl', 'image_url', 'image', 'filename'];
            for (var field in possibleFields) {
              imageUrl = responseMap[field];
              if (imageUrl != null && imageUrl.toString().isNotEmpty) {
                print('✓ Image URL from "$field": $imageUrl');
                break;
              }
            }
          }
          
          return ApiResponse(
            success: true,
            data: responseMap,
            message: 'Image uploaded successfully',
            statusCode: response.statusCode,
          );
        }
        // If not 200/201, try next endpoint
        print('   ✗ Got HTTP ${response.statusCode}, trying next endpoint...');
      } catch (e) {
        print('   ✗ Exception: $e');
        continue;
      }
    }
    
    // Fallback: Try base64 JSON upload (more universal)
    print('\n📝 Multipart failed, trying base64 JSON upload...');
    try {
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final fileName = imageFile.path.split('/').last;
      
      final jsonPayload = {
        'image': base64Image,
        'filename': fileName,
        'content_type': 'image/jpeg',
      };
      
      final response = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: _getHeaders(isMultipart: false),
        body: jsonEncode(jsonPayload),
      ).timeout(Duration(seconds: _uploadTimeoutSeconds));
      
      print('   → HTTP ${response.statusCode}');
      print('   → Response: ${response.body.substring(0, min(response.body.length, 250))}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        print('✅ Image uploaded via base64');
        
        return ApiResponse(
          success: true,
          data: jsonResponse is Map<String, dynamic> ? jsonResponse : {'image': base64Image},
          message: 'Image uploaded as base64',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('   ✗ Base64 upload failed: $e');
    }
    
    // All methods failed - proceed without images
    print('\n⚠️  Image upload not supported');
    print('   Proceeding to submit claim without images...');
    
    return ApiResponse(
      success: false,
      message: 'Image upload not supported - claim will be submitted without images',
      statusCode: 501,
    );
  }

  // Upload multiple images
  static Future<ApiResponse<List<dynamic>>> uploadImages(
    List<File> imageFiles,
  ) async {
    List<Map<String, dynamic>> uploadedImages = [];
    List<String> errors = [];

    print('📤 Starting image upload process for ${imageFiles.length} images');

    for (int i = 0; i < imageFiles.length; i++) {
      print('📸 Uploading image ${i + 1}/${imageFiles.length}...');
      final result = await uploadImage(imageFiles[i]);

      if (result.success && result.data != null) {
        print('✅ Image ${i + 1} uploaded: ${result.data}');
        uploadedImages.add(result.data!);
      } else {
        print('❌ Image ${i + 1} failed: ${result.message}');
        errors.add('Image ${i + 1}: ${result.message}');
      }
    }

    print('📊 Upload Summary: ${uploadedImages.length}/${imageFiles.length} successful');

    if (uploadedImages.isNotEmpty) {
      return ApiResponse(
        success: true,
        data: uploadedImages,
        message: uploadedImages.length == imageFiles.length
            ? 'All ${uploadedImages.length} images uploaded successfully'
            : 'Uploaded ${uploadedImages.length}/${imageFiles.length} images',
      );
    } else {
      return ApiResponse(
        success: false,
        message: 'Failed to upload images: ${errors.join(', ')}',
        error: errors,
      );
    }
  }

  // Get user claims (example GET request)
  static Future<ApiResponse<List<dynamic>>> getUserClaims() async {
    try {
        final response = await http
          .get(Uri.parse('$baseUrl/claims'), headers: _getHeaders())
          .timeout(
            const Duration(seconds: _timeoutSeconds),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] ?? [];
        print('✓ Claims fetched successfully');
        return ApiResponse(
          success: true,
          data: data is List ? data : [data],
          message: 'Claims fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        print('✗ Failed to fetch claims: ${response.statusCode}');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Failed to fetch claims',
          statusCode: response.statusCode,
          error: errorBody,
        );
      }
    } catch (e) {
      print('✗ Error fetching claims: $e');
      return ApiResponse(
        success: false,
        message: 'Error fetching claims',
        error: e,
      );
    }
  }

  // Get all registered users
  static Future<ApiResponse<List<dynamic>>> getAllUsers() async {
    try {
      print('📡 Fetching all registered users...');
      final response = await http
          .get(Uri.parse('$baseUrl/users'), headers: _getHeaders())
          .timeout(
            const Duration(seconds: _timeoutSeconds),
            onTimeout: () => throw TimeoutException('Request timeout'),
          );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'] ?? jsonResponse;
        print('✓ Users fetched successfully (${data is List ? data.length : 1} users)');
        return ApiResponse(
          success: true,
          data: data is List ? data : [data],
          message: 'Users fetched successfully',
          statusCode: response.statusCode,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        print('✗ Failed to fetch users: ${response.statusCode}');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Failed to fetch users',
          statusCode: response.statusCode,
          error: errorBody,
        );
      }
    } catch (e) {
      print('✗ Error fetching users: $e');
      return ApiResponse(
        success: false,
        message: 'Error fetching users',
        error: e,
      );
    }
  }

  // Register user
  static Future<ApiResponse<Map<String, dynamic>>> registerUser({
    required String meterNumber,
    required String phoneNumber,
    required String otp,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _getHeaders(),
            body: jsonEncode({
              'meterNumber': meterNumber,
              'phoneNumber': phoneNumber,
              'otp': otp,
              'password': password,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(
            const Duration(seconds: _timeoutSeconds),
            onTimeout: () => throw TimeoutException(
              'Request timeout after ${_timeoutSeconds}s',
            ),
          );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('✓ User registered successfully');
        final responseData = jsonResponse is Map<String, dynamic>
            ? jsonResponse
            : {'message': response.body} as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: responseData,
          message: 'Registration successful',
          statusCode: response.statusCode,
        );
      } else {
        final errorBody = _parseErrorResponse(response.body);
        print('✗ Registration failed: ${response.statusCode}');
        return ApiResponse(
          success: false,
          message: errorBody['message'] ?? 'Registration failed',
          statusCode: response.statusCode,
          error: errorBody,
        );
      }
    } on TimeoutException catch (e) {
      print('✗ Timeout error: ${e.message}');
      return ApiResponse(
        success: false,
        message: 'Request timeout. Please check your connection and try again.',
        error: e,
      );
    } on SocketException catch (e) {
      print('✗ Network error: ${e.message}');
      return ApiResponse(
        success: false,
        message: 'Network error. Please check your internet connection.',
        error: e,
      );
    } catch (e) {
      print('✗ Unexpected error: $e');
      return ApiResponse(
        success: false,
        message: 'An unexpected error occurred',
        error: e,
      );
    }
  }

  // Get user's trip claims (authenticated endpoint)
  static Future<Map<String, dynamic>> getUserTripClaims({
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      print('\n📡 [USER API] Fetching your trip claims...');
      print('🔑 Auth Token: ${_authToken != null ? 'Bearer ${_authToken!.substring(0, 20)}...' : 'MISSING - User must be logged in!'}');
      
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }

        final uri = Uri.parse('$baseUrl/claims')
          .replace(queryParameters: queryParams);

      print('📡 Requesting: $uri');

      final response = await http
          .get(
            uri,
            headers: _getHeaders(),
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      print('✓ HTTP Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          
          // Check for error flags in successful response
          if (data.containsKey('error') && data['error'] != null) {
            print('⚠️ Error flag in 200 response: ${data['error']}');
            return {
              'success': false,
              'message': data['message'] ?? data['error'].toString() ?? 'Request returned an error',
              'statusCode': 200,
              'error': data['error'],
            };
          }
          
          // Check if data exists
          if (!data.containsKey('data')) {
            print('⚠️ No data field in response');
          }
          
          print('✓ Fetched ${(data['data'] as List?)?.length ?? 0} claims');
          
          // Ensure success field is present
          data['success'] = true;
          return data;
        } catch (parseError) {
          print('✗ Error parsing JSON: $parseError');
          return {
            'success': false,
            'message': 'Invalid response format: $parseError',
            'statusCode': 200,
            'rawResponse': response.body,
          };
        }
      } else if (response.statusCode == 401) {
        print('✗ Unauthorized (401) - Token may be expired or invalid');
        return {
          'success': false,
          'message': 'Unauthorized - Please login again',
          'statusCode': 401,
          'error': 'Your session has expired. Please log out and login again.',
        };
      } else if (response.statusCode == 403) {
        print('✗ Forbidden (403) - User does not have access');
        return {
          'success': false,
          'message': 'Access Denied - You do not have permission to view these claims',
          'statusCode': 403,
          'error': response.body,
        };
      } else if (response.statusCode == 404) {
        print('✗ Not Found (404) - Endpoint may not exist');
        return {
          'success': false,
          'message': 'Endpoint not found - Backend API configuration issue',
          'statusCode': 404,
          'error': 'The /trip-claims endpoint is not available on the backend',
        };
      } else {
        print('✗ Failed with status ${response.statusCode}');
        return {
          'success': false,
          'message': 'Failed to fetch claims: HTTP ${response.statusCode}',
          'statusCode': response.statusCode,
          'error': response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body,
        };
      }
    } catch (e) {
      print('✗ Exception: $e');
      return {
        'success': false,
        'message': 'Error fetching claims: $e',
        'error': '$e',
      };
    }
  }

  // Get all trip claims (Admin endpoint)
  static Future<Map<String, dynamic>> getAdminAllClaims({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      print('\n📡 [ADMIN API] Fetching Trip Claims for Admin Dashboard');
      print('   Endpoint: /trip-claims/admin/all-claims');
      print('   Status Filter: ${status ?? "all"}');
      print('   Page: $page, Limit: $limit');
      print('   Auth Token: ${_authToken != null ? "✅ SET (${_authToken!.substring(0, 20)}...)" : "❌ NOT SET"}');
      
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status != 'all') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/trip-claims/admin/all-claims')
          .replace(queryParameters: queryParams);
      
      print('   Full URL: $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_authToken ?? ''}',
            },
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      print('   Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final claimCount = data['data']?.length ?? 0;
        print('   ✅ Fetched $claimCount claims successfully');
        
        // Debug: Show first few claims
        if (data['data'] != null && data['data'].isNotEmpty) {
          print('   Sample claims:');
          for (int i = 0; i < (claimCount > 3 ? 3 : claimCount); i++) {
            final claim = data['data'][i];
            print('      • ${claim['id']} - Status: ${claim['status']}');
          }
        }
        
        return data;
      } else {
        print('   ❌ Failed with status ${response.statusCode}');
        print('   Response: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to fetch claims',
        };
      }
    } catch (e) {
      print('   ❌ Exception: $e');
      return {
        'success': false,
        'message': 'Error fetching claims: $e',
      };
    }
  }

  // Get admin statistics
  static Future<Map<String, dynamic>> getAdminStatistics() async {
    try {
      print('\n📊 [ADMIN API] Fetching statistics...');

      final response = await http
          .get(
            Uri.parse('$baseUrl/trip-claims/admin/statistics'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_authToken ?? ''}',
            },
          )
          .timeout(Duration(seconds: _timeoutSeconds));

      print('✓ Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        // Remove totalAmount from response
        if (data['data'] != null && data['data'] is Map) {
          data['data'].remove('totalAmount');
        }
        print('✓ Statistics loaded');
        return data;
      } else {
        print('✗ Failed: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to fetch statistics',
        };
      }
    } catch (e) {
      print('✗ Error: $e');
      return {
        'success': false,
        'message': 'Error fetching statistics: $e',
      };
    }
  }
  
  // Get technician details by ID
  static Future<Map<String, dynamic>?> getTechnicianById(String technicianId) async {
    try {
      print('📡 [TECHNICIAN API] Fetching technician ID: $technicianId');
      
      // Try different endpoint patterns
      final endpoints = [
        '$baseUrl/technicians/$technicianId',
        '$baseUrl/technical/$technicianId',
        '$baseUrl/users/$technicianId?role=technician',
        '$baseUrl/staff/$technicianId',
      ];
      
      for (final endpoint in endpoints) {
        try {
          print('   Trying: $endpoint');
          final response = await http
              .get(
                Uri.parse(endpoint),
                headers: _getHeaders(),
              )
              .timeout(Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('   ✅ Success! Status: ${response.statusCode}');
            
            // Extract data from various response formats
            if (data is Map && data.containsKey('data')) {
              return Map<String, dynamic>.from(data['data'] as Map);
            } else if (data is Map && data.containsKey('success') && data['success'] == true) {
              return Map<String, dynamic>.from(data);
            } else if (data is Map) {
              return Map<String, dynamic>.from(data);
            }
          } else {
            print('   ℹ️ Status: ${response.statusCode}');
          }
        } catch (e) {
          print('   ❌ Endpoint failed: $e');
        }
      }
      
      print('⚠️ Could not fetch technician from any endpoint');
      return null;
    } catch (e) {
      print('❌ Exception in getTechnicianById: $e');
      return null;
    }
  }

  // Helper to parse error responses
  static Map<String, dynamic> _parseErrorResponse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      return {'message': responseBody};
    }
  }
}
