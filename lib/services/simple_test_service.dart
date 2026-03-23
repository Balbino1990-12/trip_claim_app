import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class SimpleTestService {
  static String baseUrl = 'http://10.42.122.224:5000/api';

  /// Test sending just description and location (no images) to verify API works
  static Future<void> testSimpleSubmission() async {
    print('\n🧪 Testing simple submission (no images)...\n');

    try {
      print('📡 Sending data to $baseUrl/claims');
      print('Data: description + location only\n');

      final response = await http
          .post(
            Uri.parse('$baseUrl/claims'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'description': 'Test description from Flutter',
              'latitude': 28.6139,
              'longitude': 77.2090,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ SUCCESS! Basic submission works!\n');
      } else {
        print('❌ Server returned error ${response.statusCode}\n');
      }
    } on TimeoutException catch (e) {
      print('⏱️  TIMEOUT: $e\n');
      print('Backend is not responding. Check if it\'s running.\n');
    } on SocketException catch (e) {
      print('🌐 NETWORK ERROR: ${e.message}\n');
      print('Cannot connect to backend. Check IP and port.\n');
    } catch (e) {
      print('❌ ERROR: $e\n');
    }
  }

  /// Test with small image (50 KB)
  static Future<void> testWithSmallImage() async {
    print('\n🧪 Testing submission with small image (50 KB)...\n');

    try {
      final testFile = await _createTestImage(50 * 1024);
      print('📡 Sending request to $baseUrl/claims with image\n');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/claims'),
      );

      request.fields['description'] = 'Test with small image';
      request.fields['latitude'] = '28.6139';
      request.fields['longitude'] = '77.2090';
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      request.files.add(
        await http.MultipartFile.fromPath('images', testFile.path),
      );

      print('Uploading 50 KB image...');
      var streamedResponse = await request.send().timeout(
        Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Upload timed out after 60s'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}\n');

      await testFile.delete();

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ SUCCESS! Image upload works!\n');
      } else {
        print('❌ Server returned error ${response.statusCode}\n');
      }
    } on TimeoutException catch (e) {
      print('⏱️  TIMEOUT: $e\n');
      print(
        'Even small uploads timeout. Check backend database performance.\n',
      );
    } on SocketException catch (e) {
      print('🌐 NETWORK ERROR: ${e.message}\n');
    } catch (e) {
      print('❌ ERROR: $e\n');
    }
  }

  /// Test different endpoints to find the correct one
  static Future<void> testEndpoints() async {
    print('\n🧪 Testing different endpoint paths...\n');

    final endpoints = [
      '/claims',
      '/trip-claims',
      '/tripClaims',
      '/submit-claim',
      '/upload',
      '/api/claims',
    ];

    for (final endpoint in endpoints) {
      try {
        print('Testing: $baseUrl$endpoint');
        final response = await http
            .post(
              Uri.parse('$baseUrl$endpoint'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'test': true}),
            )
            .timeout(Duration(seconds: 5));

        if (response.statusCode == 404) {
          print('  ❌ Not found (404)\n');
        } else if (response.statusCode == 405) {
          print('  ⚠️  Method not allowed (405)\n');
        } else {
          print('  ✅ Endpoint exists (${response.statusCode})\n');
        }
      } catch (e) {
        print('  ❌ Error: $e\n');
      }
    }
  }

  static Future<File> _createTestImage(int sizeBytes) async {
    final tempDir = Directory.systemTemp;
    final testFile = File(
      '${tempDir.path}/test_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final data = List<int>.generate(sizeBytes, (i) => i % 256);
    await testFile.writeAsBytes(data);
    return testFile;
  }
}
