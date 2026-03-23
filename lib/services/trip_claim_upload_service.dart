import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;

class UploadException implements Exception {
  final String message;
  final dynamic originalError;

  UploadException(this.message, [this.originalError]);

  @override
  String toString() => message;
}

class TripClaimUploadService {
  static String baseUrl = 'http://10.91.220.92:5000/api';
  static String? _authToken;

  // Upload configuration
  static const int maxRetries = 3;
  static const Duration initialRetryDelay = Duration(seconds: 3);
  static const Duration uploadTimeout = Duration(seconds: 300); // 5 minutes
  static const int maxImageFileSize = 5 * 1024 * 1024; // 5 MB per image
  static const int imageQuality = 85; // Compression quality (0-100)

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

  /// Compress image to reduce file size
  static Future<File> _compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('⚠️ Could not decode image, using original');
        return imageFile;
      }

      // Compress
      final compressed = img.encodeJpg(image, quality: imageQuality);

      // Save compressed
      final compressedFile = File('${imageFile.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressed);

      final originalSize = bytes.length / (1024 * 1024);
      final compressedSize = compressed.length / (1024 * 1024);
      print(
        '✓ Image compressed: ${originalSize.toStringAsFixed(2)}MB → ${compressedSize.toStringAsFixed(2)}MB',
      );

      return compressedFile;
    } catch (e) {
      print('⚠️ Compression failed, using original: $e');
      return imageFile;
    }
  }

  /// Upload trip claim with images, description, and location
  static Future<Map<String, dynamic>> uploadTripClaim({
    required List<File> imageFiles,
    required String description,
    required double? latitude,
    required double? longitude,
    Function(int, int)? onProgress,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print('\n📤 Uploading trip claim (attempt ${attempt + 1}/$maxRetries)');
        print(
          '📊 Images: ${imageFiles.length}, Description: ${description.length} chars',
        );
        print(
          '📍 Location: Lat=${latitude?.toStringAsFixed(4)}, Lon=${longitude?.toStringAsFixed(4)}',
        );

        final result = await _sendTripClaimRequest(
          imageFiles,
          description,
          latitude,
          longitude,
          onProgress,
        );

        print('✓ Trip claim uploaded successfully!');
        return result;
      } catch (e) {
        print('❌ Upload failed: $e');
        attempt++;

        if (attempt < maxRetries) {
          Duration delay = initialRetryDelay * attempt;
          print('⏳ Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        } else {
          throw UploadException(
            'Failed to upload trip claim after $maxRetries attempts: $e',
            e,
          );
        }
      }
    }

    throw UploadException('Upload failed after $maxRetries attempts');
  }

  /// Internal method to send trip claim request
  static Future<Map<String, dynamic>> _sendTripClaimRequest(
    List<File> imageFiles,
    String description,
    double? latitude,
    double? longitude,
    Function(int, int)? onProgress,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trip-claims'),
      );

      request.headers.addAll(_getHeaders(isMultipart: true));

      // Add description and location
      request.fields['description'] = description;
      
      // Combine latitude and longitude into location field
      if (latitude != null && longitude != null) {
        request.fields['location'] = '$latitude,$longitude';
      } else {
        request.fields['location'] = 'Not available';
      }

      // Add timestamp
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      // Compress and add images
      print('🖼️  Processing ${imageFiles.length} image(s)...');
      for (int i = 0; i < imageFiles.length; i++) {
        print('  Compressing image ${i + 1}/${imageFiles.length}...');

        final originalFile = imageFiles[i];
        final compressedFile = await _compressImage(originalFile);

        // Check final size
        final fileSize = await compressedFile.length();
        if (fileSize > maxImageFileSize) {
          throw UploadException(
            'Image ${i + 1} is too large (${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB, max 5MB)',
          );
        }

        final multipartFile = await http.MultipartFile.fromPath(
          'images',
          compressedFile.path,
          filename: 'image_$i.jpg',
        );
        request.files.add(multipartFile);
      }

      print('📡 Sending request to server...');

      // Send request with extended timeout
      var streamedResponse = await request.send().timeout(
        uploadTimeout,
        onTimeout: () {
          throw TimeoutException(
            'Upload timeout after ${uploadTimeout.inSeconds} seconds. '
            'Server is not responding. Check your connection.',
          );
        },
      );

      // Get response
      var response = await http.Response.fromStream(streamedResponse).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Response timeout - server took too long to respond',
          );
        },
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        print('✓ Server response: ${jsonResponse['message']}');
        return jsonResponse;
      } else if (response.statusCode == 408) {
        throw UploadException('Server timeout (408) - Request took too long');
      } else if (response.statusCode == 413) {
        throw UploadException('Payload too large (413) - Images are too big');
      } else if (response.statusCode == 503) {
        throw UploadException('Service unavailable (503) - Server is down');
      } else {
        final errorBody = _parseErrorResponse(response.body);
        throw UploadException(
          'Server error (${response.statusCode}): ${errorBody['message'] ?? response.body}',
        );
      }
    } on TimeoutException catch (e) {
      throw UploadException('⏱️  ${e.message!}');
    } on SocketException catch (e) {
      throw UploadException('🌐 Network error: ${e.message}', e);
    } on HandshakeException catch (e) {
      throw UploadException('🔒 SSL/Certificate error: ${e.message}', e);
    } catch (e) {
      throw UploadException('Unexpected error: $e', e);
    }
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
