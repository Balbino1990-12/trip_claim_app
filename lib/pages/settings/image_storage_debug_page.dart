import 'package:flutter/material.dart';
import '../../services/image_storage_service.dart';
import 'dart:io';

class ImageStorageDebugPage extends StatefulWidget {
  const ImageStorageDebugPage({super.key});

  @override
  State<ImageStorageDebugPage> createState() => _ImageStorageDebugPageState();
}

class _ImageStorageDebugPageState extends State<ImageStorageDebugPage> {
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ImageStorageService.getStorageStats();
  }

  void _refreshStats() {
    setState(() {
      _statsFuture = ImageStorageService.getStorageStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📂 Image Storage'),
        backgroundColor: const Color(0xFF0070BA),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final stats = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Storage Stats Card
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📊 Storage Statistics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0070BA),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatItem('Total Images',
                              '${stats['totalImages']} images'),
                          _buildStatItem('Pending Images',
                              '${stats['pendingImages']} images'),
                          _buildStatItem('Archived Images',
                              '${stats['archivedImages']} images'),
                          _buildStatItem('Storage Used',
                              '${stats['totalSizeInMB']} MB'),
                          const SizedBox(height: 8),
                          Text(
                            'Path: ${stats['storagePath']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pending Images Section
                  const Text(
                    '⏳ Pending Images (for new claims)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0070BA),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildImageGrid(ImageStorageService.getPendingImages()),
                  const SizedBox(height: 20),

                  // Archived Images Section
                  const Text(
                    '✅ Archived Images (submitted claims)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildImageGrid(ImageStorageService.getArchivedImages()),
                  const SizedBox(height: 20),

                  // Action Buttons
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: _refreshStats,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Clear Pending'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () => _showConfirmDialog(
                      'Clear Pending Images?',
                      'This will delete all pending images.',
                      ImageStorageService.clearPendingImages,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Clear All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _showConfirmDialog(
                      'Clear All Images?',
                      'This will delete all images permanently.',
                      ImageStorageService.clearAllImages,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0070BA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(Future<List<File>> imagesFuture) {
    return FutureBuilder<List<File>>(
      future: imagesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No images',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          );
        }

        final images = snapshot.data!;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                images[index],
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmDialog(
    String title,
    String message,
    Future<bool> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await action();
              if (mounted) {
                Navigator.pop(context);
                _refreshStats();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Action completed')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
