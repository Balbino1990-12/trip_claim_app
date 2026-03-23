import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;

class UploadProgress {
  final int totalSteps;
  final int currentStep;
  final String message;
  final double percentProgress;

  UploadProgress({
    required this.totalSteps,
    required this.currentStep,
    required this.message,
    required this.percentProgress,
  });

  @override
  String toString() => '$message (${(percentProgress * 100).toStringAsFixed(0)}%)';
}

class OptimizedTripClaimUploadService {
  static String baseUrl = 'http://10.42.122.224:5000/api';
  static String? _authToken;

  // Configuration
  static const int maxRetries = 2;
  static const Duration uploadTimeout = Duration(seconds: 60); // Reduced from 300s
  static const int imageQuality = 75; // Reduced from 85 for faster compression

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static void clearAuthToken() {
    _authToken = null;
  }

  /// Upload with progress callback for UI updates
  static Future<Map<String, dynamic>> uploadTripClaimOptimized({
    required List<File> imageFiles,
    required String description,
    required double? latitude,
    required double? longitude,
    Function(UploadProgress)? onProgress,
  }) async {
    try {
      // Step 1: Compress images
      onProgress?.call(UploadProgress(
        totalSteps: 4,
        currentStep: 1,
        message: 'Compressing ${imageFiles.length} image(s)...',
        percentProgress: 0.1,
      ));

      final compressedFiles = <File>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final compressed = await _compressImageFast(imageFiles[i]);
        compressedFiles.add(compressed);

        final progress = 0.1 + ((i + 1) / imageFiles.length) * 0.2;
        onProgress?.call(UploadProgress(
          totalSteps: 4,
          currentStep: 1,
          message: 'Compressed ${i + 1}/${imageFiles.length} image(s)',
          percentProgress: progress,
        ));
      }

      // Step 2: Prepare request
      onProgress?.call(UploadProgress(
        totalSteps: 4,
        currentStep: 2,
        message: 'Preparing upload...',
        percentProgress: 0.35,
      ));

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trip-claims'),
      );

      request.headers.addAll(_getHeaders(isMultipart: true));
      request.fields['description'] = description;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) request.fields['longitude'] = longitude.toString();
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      // Add compressed images
      for (int i = 0; i < compressedFiles.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            compressedFiles[i].path,
            filename: 'image_$i.jpg',
          ),
        );
      }

      // Step 3: Send request
      onProgress?.call(UploadProgress(
        totalSteps: 4,
        currentStep: 3,
        message: 'Uploading to server...',
        percentProgress: 0.5,
      ));

      var streamedResponse = await request.send().timeout(
        uploadTimeout,
        onTimeout: () => throw TimeoutException(
          'Upload timeout. Check your internet connection.',
        ),
      );

      onProgress?.call(UploadProgress(
        totalSteps: 4,
        currentStep: 3,
        message: 'Uploading to server... (waiting for response)',
        percentProgress: 0.75,
      ));

      var response = await http.Response.fromStream(streamedResponse).timeout(
        Duration(seconds: 30),
      );

      // Step 4: Process response
      onProgress?.call(UploadProgress(
        totalSteps: 4,
        currentStep: 4,
        message: 'Processing response...',
        percentProgress: 0.95,
      ));

      // Cleanup compressed files
      for (final file in compressedFiles) {
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        
        onProgress?.call(UploadProgress(
          totalSteps: 4,
          currentStep: 4,
          message: 'Upload complete!',
          percentProgress: 1.0,
        ));

        return result;
      } else {
        throw UploadException(
          'Server error (${response.statusCode}): ${response.body}',
        );
      }
    } on TimeoutException catch (e) {
      throw UploadException('⏱️ Timeout: ${e.message}');
    } on SocketException catch (e) {
      throw UploadException('🌐 Network error: ${e.message}');
    } catch (e) {
      throw UploadException('Upload failed: $e');
    }
  }

  /// Fast image compression
  static Future<File> _compressImageFast(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      
      // Quick resize + compress
      final image = img.decodeImage(bytes);
      if (image == null) return imageFile;

      // Limit to max 1200px width (keeps aspect ratio)
      final resized = img.copyResize(
        image,
        width: 1200,
        height: (image.height * 1200 ~/ image.width),
      );

      final compressed = img.encodeJpg(resized, quality: imageQuality);
      
      final tempFile = File('${imageFile.path}_opt.jpg');
      await tempFile.writeAsBytes(compressed);

      return tempFile;
    } catch (e) {
      return imageFile;
    }
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
}

class UploadException implements Exception {
  final String message;

  UploadException(this.message);

  @override
  String toString() => message;
}
