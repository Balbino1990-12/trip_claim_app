import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class ConnectivityDiagnostics {
  static String baseUrl = 'http://10.42.122.224:5000/api';

  /// Test basic connectivity to the backend
  static Future<Map<String, dynamic>> testBackendConnection() async {
    print('\n🔍 Testing backend connectivity...\n');

    final results = <String, dynamic>{};

    // Test 1: DNS resolution
    try {
      print('1️⃣  Testing DNS resolution for 192.168.1.95...');
      final stopwatch = Stopwatch()..start();
      await InternetAddress.lookup('192.168.1.95');
      stopwatch.stop();
      results['dns_resolution'] = {
        'success': true,
        'time_ms': stopwatch.elapsedMilliseconds,
      };
      print('   ✓ DNS resolved in ${stopwatch.elapsedMilliseconds}ms\n');
    } catch (e) {
      results['dns_resolution'] = {'success': false, 'error': e.toString()};
      print('   ❌ DNS resolution failed: $e\n');
    }

    // Test 2: Basic TCP connection
    try {
      print('2️⃣  Testing TCP connection to 192.168.1.95:5000...');
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect('192.168.1.95', 5000,
          timeout: Duration(seconds: 5));
      stopwatch.stop();
      socket.close();
      results['tcp_connection'] = {
        'success': true,
        'time_ms': stopwatch.elapsedMilliseconds,
      };
      print('   ✓ TCP connected in ${stopwatch.elapsedMilliseconds}ms\n');
    } catch (e) {
      results['tcp_connection'] = {'success': false, 'error': e.toString()};
      print('   ❌ TCP connection failed: $e\n');
    }

    // Test 3: HTTP GET request (health check)
    try {
      print('3️⃣  Testing HTTP GET request to /health...');
      final stopwatch = Stopwatch()..start();
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(Duration(seconds: 10));
      stopwatch.stop();
      results['http_get'] = {
        'success': response.statusCode == 200,
        'status_code': response.statusCode,
        'time_ms': stopwatch.elapsedMilliseconds,
        'response_size': response.body.length,
      };
      print('   ✓ HTTP GET responded with ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      print('   Response size: ${response.body.length} bytes\n');
    } catch (e) {
      results['http_get'] = {'success': false, 'error': e.toString()};
      print('   ❌ HTTP GET failed: $e\n');
    }

    // Test 4: Multipart upload (small test file)
    try {
      print('4️⃣  Testing multipart upload with small test file...');
      final testFile = await _createTestFile(100 * 1024); // 100 KB
      final stopwatch = Stopwatch()..start();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('image', testFile.path));

      var streamedResponse = await request.send().timeout(Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      await testFile.delete();

      results['multipart_upload_100kb'] = {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'status_code': response.statusCode,
        'time_ms': stopwatch.elapsedMilliseconds,
        'speed_kbps': ((100 * 1000) / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(2),
      };
      print('   ✓ Multipart upload completed in ${stopwatch.elapsedMilliseconds}ms');
      print('   Upload speed: ${results['multipart_upload_100kb']['speed_kbps']} KB/s\n');
    } catch (e) {
      results['multipart_upload_100kb'] = {'success': false, 'error': e.toString()};
      print('   ❌ Multipart upload failed: $e\n');
    }

    // Test 5: Larger file upload (1 MB)
    try {
      print('5️⃣  Testing multipart upload with 1 MB file...');
      final testFile = await _createTestFile(1 * 1024 * 1024); // 1 MB
      final stopwatch = Stopwatch()..start();

      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('image', testFile.path));

      var streamedResponse = await request.send().timeout(Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);
      stopwatch.stop();

      await testFile.delete();

      results['multipart_upload_1mb'] = {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'status_code': response.statusCode,
        'time_ms': stopwatch.elapsedMilliseconds,
        'speed_kbps': ((1024 * 1000) / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(2),
      };
      print('   ✓ Multipart upload completed in ${stopwatch.elapsedMilliseconds}ms');
      print('   Upload speed: ${results['multipart_upload_1mb']['speed_kbps']} KB/s\n');
    } catch (e) {
      results['multipart_upload_1mb'] = {'success': false, 'error': e.toString()};
      print('   ❌ 1MB upload failed: $e\n');
    }

    // Print summary
    _printSummary(results);

    return results;
  }

  /// Create a test file for upload testing
  static Future<File> _createTestFile(int sizeBytes) async {
    final tempDir = Directory.systemTemp;
    final testFile = File('${tempDir.path}/test_upload_${DateTime.now().millisecondsSinceEpoch}.bin');
    
    // Create file with random data
    final data = List<int>.generate(sizeBytes, (i) => i % 256);
    await testFile.writeAsBytes(data);
    
    return testFile;
  }

  /// Print diagnostic summary
  static void _printSummary(Map<String, dynamic> results) {
    print('\n${'='*60}');
    print('📊 DIAGNOSTIC SUMMARY');
    print('='*60 + '\n');

    int passed = 0;
    int failed = 0;

    results.forEach((test, result) {
      final success = result['success'] ?? false;
      if (success) {
        passed++;
        print('✅ $test: PASS');
        if (result['time_ms'] != null) {
          print('   Time: ${result['time_ms']}ms');
        }
        if (result['speed_kbps'] != null) {
          print('   Speed: ${result['speed_kbps']} KB/s');
        }
      } else {
        failed++;
        print('❌ $test: FAIL');
        if (result['error'] != null) {
          print('   Error: ${result['error']}');
        }
      }
      print('---');
    });

    print('='*60);
    print('Results: $passed passed, $failed failed');
    print('='*60 + '\n');

    // Recommendations
    if (failed > 0) {
      print('⚠️  RECOMMENDATIONS:\n');
      if (results['dns_resolution']?['success'] == false) {
        print('• Check if 10.91.220.92 is the correct backend IP');
        print('• Verify network connectivity\n');
      }
      if (results['tcp_connection']?['success'] == false) {
        print('• Backend server at port 5000 may not be running');
        print('• Check firewall settings\n');
      }
      if (results['http_get']?['success'] == false) {
        print('• Backend server is not responding to HTTP requests');
        print('• Check backend logs\n');
      }
      if (results['multipart_upload_100kb']?['success'] == false) {
        print('• Backend upload endpoint may not be working');
        print('• Check /upload endpoint configuration\n');
      }
    } else {
      print('✅ ALL TESTS PASSED!\n');
      print('If you still experience timeouts during actual uploads:\n');
      print('• Your network speed may be slow (check KB/s above)');
      print('• Backend database operations may be slow');
      print('• Try reducing image quality further in TripClaimUploadService\n');
    }
  }
}
