import 'package:flutter/material.dart';
import 'package:trip_claim_app/services/timeout_debug_service.dart';

class TimeoutTestScreen extends StatefulWidget {
  const TimeoutTestScreen({super.key});

  @override
  State<TimeoutTestScreen> createState() => _TimeoutTestScreenState();
}

class _TimeoutTestScreenState extends State<TimeoutTestScreen> {
  String _output = 'Tap a button to run tests...\n';
  bool _isRunning = false;

  void _log(String message) {
    setState(() {
      _output += '$message\n';
    });
    print(message); // Also print to console
  }

  Future<void> _runTest1() async {
    setState(() {
      _output = '';
      _isRunning = true;
    });

    _log('🧪 Running TEST 1: Plain POST (no images)');
    _log('This should be very fast (< 100ms)\n');

    await TimeoutDebugService.testPlainPost();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runTest2() async {
    setState(() {
      _output = '';
      _isRunning = true;
    });

    _log('🧪 Running TEST 2: Multipart with 10 KB image');
    _log('This should be fast (< 500ms)\n');

    await TimeoutDebugService.testSmallImageUpload();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runTest3() async {
    setState(() {
      _output = '';
      _isRunning = true;
    });

    _log('🧪 Running TEST 3: Multipart with 3 images');
    _log('This should take 1-2 seconds\n');

    await TimeoutDebugService.testMultipleImages();

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _output = '';
      _isRunning = true;
    });

    _log('🔍 Running ALL TESTS...\n');

    await TimeoutDebugService.runAllTests();

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Timeout Debug'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runTest1,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Test 1: Text Only'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runTest2,
                  icon: const Icon(Icons.image),
                  label: const Text('Test 2: Single Image'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runTest3,
                  icon: const Icon(Icons.collections),
                  label: const Text('Test 3: Multiple Images'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runAllTests,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run All Tests'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Output
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _output,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
