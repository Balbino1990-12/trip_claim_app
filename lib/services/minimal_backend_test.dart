import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class MinimalBackendTest {
  static const String baseUrl = 'http://10.42.122.224:5000/api';

  /// Test 1: Simplest possible request - just ping
  static Future<void> testHealthCheck() async {
    print('\n🏥 TEST 1: Health Check\n');
    print('Sending GET to: $baseUrl/health\n');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(Duration(seconds: 10));
      stopwatch.stop();

      print('✅ Response: ${response.statusCode}');
      print('   Time: ${stopwatch.elapsedMilliseconds}ms');
      print('   Body: ${response.body}\n');
    } catch (e) {
      print('❌ Error: $e\n');
    }
  }

  /// Test 2: Direct POST without images
  static Future<void> testDirectPost() async {
    print('\n📤 TEST 2: Direct POST (no images, just JSON)\n');
    print('Sending POST to: $baseUrl/trip-claims\n');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse('$baseUrl/trip-claims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': 'Simple test',
          'latitude': 28.6,
          'longitude': 77.2,
        }),
      ).timeout(Duration(seconds: 15));
      stopwatch.stop();

      print('✅ Response: ${response.statusCode}');
      print('   Time: ${stopwatch.elapsedMilliseconds}ms');
      print('   Body: ${response.body}\n');
    } catch (e) {
      print('❌ Error: $e\n');
    }
  }

  /// Test 3: Check if backend is even listening
  static Future<void> testServerDown() async {
    print('\n🔍 TEST 3: Checking if backend is listening...\n');

    try {
      print('Attempting to connect to 10.42.122.224:5000...');
      final socket = await Socket.connect(
        '10.42.122.224',
        5000,
        timeout: Duration(seconds: 5),
      );
      socket.close();
      print('✅ Backend is LISTENING on port 5000\n');
    } catch (e) {
      print('❌ Backend is NOT responding:');
      print('   Error: $e');
      print('   The backend server may not be running!\n');
    }
  }

  /// Test with very long timeout
  static Future<void> testWithLongTimeout() async {
    print('\n⏱️  TEST 4: POST with 5 minute timeout\n');
    print('Sending POST with 300 second timeout...\n');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse('$baseUrl/trip-claims'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'description': 'Long timeout test',
          'latitude': 28.6,
          'longitude': 77.2,
        }),
      ).timeout(Duration(seconds: 300)); // 5 minutes
      stopwatch.stop();

      print('✅ Response: ${response.statusCode}');
      print('   Time: ${stopwatch.elapsedMilliseconds}ms (${stopwatch.elapsedMilliseconds ~/ 1000}s)');
      print('   Body: ${response.body}\n');
    } catch (e) {
      print('❌ Error: $e\n');
    }
  }

  static Future<void> runAllTests() async {
    print('\n${'='*60}');
    print('🔧 MINIMAL BACKEND TEST SUITE');
    print('='*60);

    await testServerDown();
    await testHealthCheck();
    await testDirectPost();
    await testWithLongTimeout();

    print('='*60);
    print('📋 INTERPRETATION:');
    print('  - If Test 3 fails: Backend not reachable (wrong IP?)');
    print('  - If Test 1 fails: Backend not responding');
    print('  - If Test 2 fails: POST endpoint broken');
    print('  - If Test 4 works: Backend is just slow');
    print('='*60 + '\n');
  }
}
