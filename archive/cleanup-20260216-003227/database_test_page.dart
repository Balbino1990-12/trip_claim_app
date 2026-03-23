import 'package:flutter/material.dart';
import '../../services/database_connection_test.dart';

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _results;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Connection Test'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '🔍 Database Connection Diagnostic',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This test will check:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text('• Local Storage (SharedPreferences)'),
                    Text('• Backend API Connectivity'),
                    Text('• Response Times'),
                    Text('• Trip Claims Endpoint'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Run Test Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runTest,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Running Test...' : 'Run Diagnostics'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),

            // Status Message
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('passed')
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  border: Border.all(
                    color: _statusMessage.contains('passed')
                        ? Colors.green
                        : Colors.orange,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('passed')
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),

            // Results
            if (_results != null) ...[
              const SizedBox(height: 20),
              _buildResultsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running diagnostics...';
      _results = null;
    });

    try {
      final results = await DatabaseConnectionTest.runFullDiagnostics();

      setState(() {
        _results = results;
        _isLoading = false;

        final allPassed = results['summary']['all_passed'] ?? false;
        _statusMessage = allPassed
            ? '✓ All tests passed! Your database connections are working.'
            : '⚠ Some tests failed. Check results below.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '✗ Error running tests: $e';
      });
    }
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Test Results:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Local Storage Results
        _buildTestCard(
          'Local Storage',
          _results!['local_storage'],
          Icons.storage,
        ),
        const SizedBox(height: 12),

        // Backend API Results
        _buildTestCard(
          'Backend API',
          _results!['backend_api'],
          Icons.cloud,
        ),
      ],
    );
  }

  Widget _buildTestCard(
    String title,
    Map<String, dynamic> data,
    IconData icon,
  ) {
    final status = data['status'] ?? data['overall_status'] ?? 'unknown';
    final isSuccess = status == 'connected' || status == 'passed';
    final color = isSuccess ? Colors.green : Colors.red;

    return Card(
      border: Border.all(color: color.withOpacity(0.3)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...data.entries
                .where((e) => e.key != 'status' && e.key != 'overall_status')
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            '${e.key}: ${e.value}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
