import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class UploadException implements Exception {
  final String message;
  final dynamic originalError;

  UploadException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class ImageUploadService {
  static String baseUrl = 'http://10.42.122.224:5000/api';
  static String? _authToken;

  // Upload configuration
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 2);
  static const Duration uploadTimeout = Duration(seconds: 120); // 2 minutes for uploads
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static void clearAuthToken() {
    _authToken = null;
  }

  static Map<String, String> _getHeaders({bool isMultipart = false}) {
    final headers = <String, String>{};

    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }

    headers['Accept'] = 'application/json';

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    return headers;
  }

  /// Upload a single image with retry logic
  static Future<Map<String, dynamic>> uploadImageWithRetry(
    File imageFile, {
    Function(int, int)? onProgress,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        // Check file size
        int fileSize = await imageFile.length();
        if (fileSize > maxFileSize) {
          throw UploadException(
            'File size (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB) exceeds maximum allowed size (10 MB)',
          );
        }

        : ${imageFile.path}');

        final result = await _uploadImage(imageFile, onProgress: onProgress);
        return result;
      } on UploadException catch (e) {
        attempt++;

        if (attempt < maxRetries) {
          // Exponential backoff: 2s, 4s, 8s
          Duration delay = initialRetryDelay * (attempt);
          await Future.delayed(delay);
        } else {
          throw UploadException(
            'Failed to upload image after $maxRetries attempts: ${e.message}',
            e.originalError,
          );
        }
      }
    }

    throw UploadException('Upload failed after $maxRetries attempts');
  }

  /// Internal method to upload a single image
  static Future<Map<String, dynamic>> _uploadImage(
    File imageFile, {
    Function(int, int)? onProgress,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      request.headers.addAll(_getHeaders(isMultipart: true));

      // Add file to request
      var multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Send request with timeout
      var streamedResponse = await request.send().timeout(
        uploadTimeout,
        onTimeout: () {
          throw UploadException('Upload timeout after ${uploadTimeout.inSeconds} seconds');
        },
      );

      // Get response
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return jsonResponse;
      } else {
        final errorBody = _parseErrorResponse(response.body);
        throw UploadException(
          'Server error (${response.statusCode}): ${errorBody['message'] ?? response.statusCode}',
        );
      }
    } on TimeoutException {
      throw UploadException('Upload timeout - connection took too long');
    } on SocketException catch (e) {
      throw UploadException('Network error: ${e.message}', e);
    } on UploadException {
      rethrow;
    } catch (e) {
      throw UploadException('Unexpected error during upload: $e', e);
    }
  }

  /// Upload multiple images with retry logic
  static Future<UploadBatchResult> uploadImagesWithRetry(
    List<File> imageFiles, {
    Function(int, int)? onOverallProgress,
  }) async {
    final List<Map<String, dynamic>> uploadedImages = [];
    final List<String> failedFiles = [];
    final List<String> errors = [];

    int totalFiles = imageFiles.length;

    for (int i = 0; i < imageFiles.length; i++) {
      try {
        final result = await uploadImageWithRetry(
          imageFiles[i],
          onProgress: (sent, total) {
            if (onOverallProgress != null) {
              // Calculate overall progress
              int overallSent = (i * 100) + ((sent / total) * 100).toInt();
              int overallTotal = totalFiles * 100;
              onOverallProgress(overallSent, overallTotal);
            }
          },
        );

        uploadedImages.add(result);

        // Call overall progress callback
        if (onOverallProgress != null) {
          onOverallProgress((i + 1) * 100, totalFiles * 100);
        }
      } catch (e) {
        failedFiles.add(imageFiles[i].path);
        errors.add('${imageFiles[i].path}: $e');
        }
    }

    return UploadBatchResult(
      uploadedImages: uploadedImages,
      failedFiles: failedFiles,
      errors: errors,
      successCount: uploadedImages.length,
      failureCount: failedFiles.length,
    );
  }

  /// Helper to parse error responses
  static Map<String, dynamic> _parseErrorResponse(String responseBody) {
    try {
      return jsonDecode(responseBody);
    } catch (e) {
      return {'message': responseBody};
    }
  }
}

/// Result class for batch upload operations
class UploadBatchResult {
  final List<Map<String, dynamic>> uploadedImages;
  final List<String> failedFiles;
  final List<String> errors;
  final int successCount;
  final int failureCount;
  final int totalCount;

  UploadBatchResult({
    required this.uploadedImages,
    required this.failedFiles,
    required this.errors,
    required this.successCount,
    required this.failureCount,
  }) : totalCount = successCount + failureCount;

  bool get hasAnySuccess => successCount > 0;

  bool get hasAnyFailure => failureCount > 0;

  bool get isComplete => failureCount == 0;

  String get statusMessage {
    if (isComplete) {
      return 'All $totalCount images uploaded successfully';
    } else if (hasAnySuccess) {
      return '$successCount/$totalCount images uploaded successfully';
    } else {
      return 'Failed to upload all $totalCount images';
    }
  }

  @override
  String toString() => 'UploadBatchResult(success: $successCount, failed: $failureCount)';
}
