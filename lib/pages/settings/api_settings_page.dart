import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';

class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  late TextEditingController _apiUrlController;
  bool _showTokenField = false;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(text: AppConfig.getApiUrl());
    _tokenController = TextEditingController();
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _saveApiUrl() {
    if (_apiUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid API URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ApiService.setBaseUrl(_apiUrlController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API URL updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _saveToken() {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid token'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ApiService.setAuthToken(_tokenController.text);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _clearToken() {
    ApiService.clearAuthToken();
    _tokenController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _resetToDefault() {
    _apiUrlController.text = AppConfig.getApiUrl();
    ApiService.setBaseUrl(AppConfig.getApiUrl());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset to default API URL'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API URL Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.api,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'API Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Current API URL',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        hintText: 'Enter API server URL',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveApiUrl,
                            icon: const Icon(Icons.save),
                            label: const Text('Save URL'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _resetToDefault,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ℹ️ Default Configuration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Development: ${AppConfig.defaultApiUrl}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Production: ${AppConfig.productionApiUrl}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Token Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Authentication Token',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_showTokenField) ...[
                      const Text(
                        'Bearer Token (from login)',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tokenController,
                        decoration: InputDecoration(
                          hintText: 'Paste your bearer token here',
                          prefixIcon: const Icon(Icons.vpn_key),
                          suffixIcon: _tokenController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _tokenController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        obscureText: true,
                        maxLines: 3,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveToken,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Token'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearToken,
                              icon: const Icon(Icons.delete),
                              label: const Text('Clear'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showTokenField = true;
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Token'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Section
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• API URL is used to communicate with your backend server\n'
                      '• Bearer Token is automatically set after successful login\n'
                      '• You can manually set a token for testing purposes\n'
                      '• All changes are applied immediately',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                        height: 1.6,
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
