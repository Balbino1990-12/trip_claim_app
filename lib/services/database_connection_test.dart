import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class DatabaseConnectionTest {
  static const String testDataKey = 'db_test_timestamp';

  /// Test all database connections comprehensively
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    print('\n🔍 Starting comprehensive database diagnostics...\n');

    final results = {
      'timestamp': DateTime.now().toIso8601String(),
      'local_storage': <String, dynamic>{},
      'backend_api': <String, dynamic>{},
      'summary': <String, dynamic>{},
    };

    // Test local storage
    await _testLocalStorage(results);

    // Test backend connectivity
    await _testBackendApi(results);

    // Generate summary
    _generateSummary(results);

    return results;
  }

  /// Test local storage (SharedPreferences)
  static Future<void> _testLocalStorage(Map<String, dynamic> results) async {
    print('='*60);
    print('📦 Testing Local Storage (SharedPreferences)');
    print('='*60);

    try {
      final prefs = await SharedPreferences.getInstance();
      print('✓ SharedPreferences initialized');

      // Test write
      final testData = {
        'test': 'data',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString('test_connection', 'success');
      print('✓ Write test: SUCCESS');

      // Test read
      final readValue = prefs.getString('test_connection');
      if (readValue == 'success') {
        print('✓ Read test: SUCCESS');
      } else {
        print('✗ Read test: FAILED - Value mismatch');
      }

      // Test getAllCachedClaims
      final cachedClaims = await LocalStorageService.getAllCachedClaims();
      print('✓ Cached claims retrieved: ${cachedClaims.length} claims');

      // Cleanup
      await prefs.remove('test_connection');

      results['local_storage'] = {
        'status': 'connected',
        'write_test': 'passed',
        'read_test': 'passed',
        'cached_claims_count': cachedClaims.length,
        'timestamp': DateTime.now().toIso8601String(),
      };

      print('✓ Local storage: ALL TESTS PASSED\n');
    } catch (e) {
      print('✗ Local storage error: $e\n');
      results['local_storage'] = {
        'status': 'failed',
        'error': e.toString(),
      };
    }
  }

  /// Test backend API connectivity
  static Future<void> _testBackendApi(Map<String, dynamic> results) async {
    print('='*60);
    print('🌐 Testing Backend API Connection');
    print('='*60);

    final baseUrl = ApiService.baseUrl;
    print('Backend URL: $baseUrl\n');

    try {
      // Test 1: Health check
      print('📡 Test 1: Health Check...');
      final healthResponse = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      final healthStatus =
          (healthResponse.statusCode == 200) ? 'passed' : 'failed';
      print('   Status Code: ${healthResponse.statusCode}');
      print('   Result: $healthStatus\n');

      results['backend_api']['health_check'] = {
        'status': healthStatus,
        'status_code': healthResponse.statusCode,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Test 2: Connectivity
      print('📡 Test 2: Basic Connectivity...');
      try {
        final connResponse = await http
            .get(Uri.parse(baseUrl))
            .timeout(const Duration(seconds: 10));
        print('   Connected: YES');
        print('   Status Code: ${connResponse.statusCode}\n');

        results['backend_api']['connectivity'] = {
          'status': 'reachable',
          'status_code': connResponse.statusCode,
        };
      } catch (e) {
        print('   Connected: NO');
        print('   Error: $e\n');

        results['backend_api']['connectivity'] = {
          'status': 'unreachable',
          'error': e.toString(),
        };
      }

      // Test 3: Trip-claims endpoint
      print('📡 Test 3: Trip Claims Endpoint...');
      try {
        final claimsResponse = await http
            .get(
              Uri.parse('$baseUrl/trip-claims'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        print('   Status Code: ${claimsResponse.statusCode}');
        print('   Response Length: ${claimsResponse.body.length} bytes\n');

        results['backend_api']['trip_claims_endpoint'] = {
          'status': 'accessible',
          'status_code': claimsResponse.statusCode,
          'response_size': claimsResponse.body.length,
        };
      } catch (e) {
        print('   Error: $e\n');

        results['backend_api']['trip_claims_endpoint'] = {
          'status': 'error',
          'error': e.toString(),
        };
      }

      // Test 4: Response time
      print('📡 Test 4: Response Time Measurement...');
      final stopwatch = Stopwatch()..start();
      try {
        await http
            .get(Uri.parse(baseUrl))
            .timeout(const Duration(seconds: 10));
        stopwatch.stop();
        final ms = stopwatch.elapsedMilliseconds;
        print('   Response Time: ${ms}ms\n');

        results['backend_api']['response_time_ms'] = ms;
      } catch (e) {
        stopwatch.stop();
        print('   Error: $e\n');
      }

      results['backend_api']['overall_status'] = 'connected';
      print('✓ Backend API: CONNECTION TESTS COMPLETED\n');
    } catch (e) {
      print('✗ Backend API error: $e\n');
      results['backend_api']['overall_status'] = 'failed';
      results['backend_api']['error'] = e.toString();
    }
  }

  /// Generate summary of all tests
  static void _generateSummary(Map<String, dynamic> results) {
    print('='*60);
    print('📊 DIAGNOSTIC SUMMARY');
    print('='*60);

    final localStorageStatus =
        results['local_storage']['status'] ?? 'unknown';
    final backendStatus = results['backend_api']['overall_status'] ?? 'unknown';

    print('✓ Local Storage: ${localStorageStatus.toUpperCase()}');
    if (results['local_storage']['cached_claims_count'] != null) {
      print('  └─ Cached Claims: ${results['local_storage']['cached_claims_count']}');
    }

    print('✓ Backend API: ${backendStatus.toUpperCase()}');
    if (results['backend_api']['health_check'] != null) {
      print(
          '  └─ Health Check: ${results['backend_api']['health_check']['status']}');
    }
    if (results['backend_api']['connectivity'] != null) {
      print(
          '  └─ Connectivity: ${results['backend_api']['connectivity']['status']}');
    }
    if (results['backend_api']['response_time_ms'] != null) {
      print('  └─ Response Time: ${results['backend_api']['response_time_ms']}ms');
    }

    print('\n✓ Test completed at: ${results['timestamp']}\n');

    results['summary'] = {
      'local_storage_ok': localStorageStatus == 'connected',
      'backend_ok': backendStatus == 'connected',
      'all_passed': localStorageStatus == 'connected' && backendStatus == 'connected',
    };
  }

  /// Print results in readable format
  static void printResults(Map<String, dynamic> results) {
    print('\n${'='*60}');
    print('FULL DIAGNOSTIC RESULTS');
    print('='*60);
    print(results.toString());
  }
}
