import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class TimeoutDebugService {
  static String baseUrl = 'http://10.42.122.224:5000/api';

  /// Test 1: Plain POST with no images (fastest)
  static Future<void> testPlainPost() async {
    print('\n🧪 TEST 1: Plain POST (no images, text only)\n');

    try {
      final stopwatch = Stopwatch()..start();

      final response = await http.post(
        Uri.parse('$baseUrl/trip-claims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': 'Test',
          'latitude': 28.6139,
          'longitude': 77.2090,
        }),
      ).timeout(Duration(seconds: 15));

      stopwatch.stop();

      print('✅ Response time: ${stopwatch.elapsedMilliseconds}ms');
      print('Status: ${response.statusCode}');
      print('Response: ${response.body}\n');
    } catch (e) {
      print('❌ Failed: $e\n');
    }
  }

  /// Test 2: Multipart with 1 small image (10 KB)
  static Future<void> testSmallImageUpload() async {
    print('\n🧪 TEST 2: Multipart POST with 10 KB image\n');

    try {
      final testFile = await _createDummyImage(10 * 1024);
      final stopwatch = Stopwatch()..start();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trip-claims'),
      );

      request.fields['description'] = 'Test with image';
      request.fields['latitude'] = '28.6139';
      request.fields['longitude'] = '77.2090';

      request.files.add(
        await http.MultipartFile.fromPath('images', testFile.path),
      );

      var streamedResponse = await request.send().timeout(Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      stopwatch.stop();

      print('✅ Response time: ${stopwatch.elapsedMilliseconds}ms');
      print('Status: ${response.statusCode}');
      print('Response: ${response.body}\n');

      await testFile.delete();
    } catch (e) {
      print('❌ Failed: $e\n');
    }
  }

  /// Test 3: Multipart with 3 small images (30 KB total)
  static Future<void> testMultipleImages() async {
    print('\n🧪 TEST 3: Multipart POST with 3x 10 KB images\n');

    try {
      final files = [
        await _createDummyImage(10 * 1024),
        await _createDummyImage(10 * 1024),
        await _createDummyImage(10 * 1024),
      ];

      final stopwatch = Stopwatch()..start();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trip-claims'),
      );

      request.fields['description'] = 'Test with 3 images';
      request.fields['latitude'] = '28.6139';
      request.fields['longitude'] = '77.2090';

      for (final file in files) {
        request.files.add(
          await http.MultipartFile.fromPath('images', file.path),
        );
      }

      var streamedResponse = await request.send().timeout(Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      stopwatch.stop();

      print('✅ Response time: ${stopwatch.elapsedMilliseconds}ms');
      print('Status: ${response.statusCode}');
      print('Response: ${response.body}\n');

      for (final file in files) {
        await file.delete();
      }
    } catch (e) {
      print('❌ Failed: $e\n');
    }
  }

  /// Run all tests in sequence
  static Future<void> runAllTests() async {
    print('\n${'='*60}');
    print('🔍 TIMEOUT DEBUG - Running All Tests');
    print('='*60);

    await testPlainPost();
    await testSmallImageUpload();
    await testMultipleImages();

    print('='*60);
    print('📊 SUMMARY:');
    print('  If Test 1 works: Problem is multipart/images');
    print('  If Test 2 works: Problem is with multiple images or size');
    print('  If Test 3 fails: Backend is slow with multiple images');
    print('='*60 + '\n');
  }

  static Future<File> _createDummyImage(int sizeBytes) async {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/dummy_${DateTime.now().millisecondsSinceEpoch}.bin');
    await file.writeAsBytes(List<int>.generate(sizeBytes, (i) => i % 256));
    return file;
  }
}
