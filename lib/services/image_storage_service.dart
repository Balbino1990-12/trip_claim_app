import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  // Directory names for organizing images
  static const String _tripClaimsDir = 'trip_claims_images';
  static const String _pendingDir = 'pending'; // Images for claims not yet sent
  static const String _archivedDir = 'archived'; // Images for submitted claims

  /// Get the base directory for storing images
  static Future<Directory> _getBaseDirectory() async {
    if (Platform.isAndroid) {
      // For Android: Use app cache directory
      return await getTemporaryDirectory();
    } else if (Platform.isIOS) {
      // For iOS: Use app documents directory
      return await getApplicationDocumentsDirectory();
    } else {
      // Fallback for other platforms
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Initialize folder structure for image storage
  static Future<bool> initializeStorageFolders() async {
    try {
      final baseDir = await _getBaseDirectory();
      final tripClaimsPath = '${baseDir.path}/$_tripClaimsDir';
      final pendingPath = '$tripClaimsPath/$_pendingDir';
      final archivedPath = '$tripClaimsPath/$_archivedDir';

      // Create directories if they don't exist
      await Directory(tripClaimsPath).create(recursive: true);
      await Directory(pendingPath).create(recursive: true);
      await Directory(archivedPath).create(recursive: true);

      print('✓ Image storage folders initialized at: $tripClaimsPath');
      return true;
    } catch (e) {
      print('✗ Error initializing storage folders: $e');
      return false;
    }
  }

  /// Save image to pending folder (for claims not yet submitted)
  /// Returns the saved file path
  static Future<String?> savePendingImage(File imageFile) async {
    try {
      await initializeStorageFolders();

      final baseDir = await _getBaseDirectory();
      final pendingPath = '${baseDir.path}/$_tripClaimsDir/$_pendingDir';

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final filename = 'img_pending_$timestamp.$extension';
      final savedPath = '$pendingPath/$filename';

      // Copy image to pending folder
      final savedFile = await imageFile.copy(savedPath);

      print('✓ Image saved to pending: $savedPath');
      return savedFile.path;
    } catch (e) {
      print('✗ Error saving pending image: $e');
      return null;
    }
  }

  /// Save multiple images to pending folder
  static Future<List<String>> savePendingImages(List<File> imageFiles) async {
    try {
      await initializeStorageFolders();

      final savedPaths = <String>[];

      for (final imageFile in imageFiles) {
        final savedPath = await savePendingImage(imageFile);
        if (savedPath != null) {
          savedPaths.add(savedPath);
        }
      }

      print('✓ Saved ${savedPaths.length} images to pending folder');
      return savedPaths;
    } catch (e) {
      print('✗ Error saving pending images: $e');
      return [];
    }
  }

  /// Move images from pending to archived (after successful submission)
  static Future<bool> archiveClaimImages(List<String> imagePaths) async {
    try {
      final baseDir = await _getBaseDirectory();
      final archivedPath = '${baseDir.path}/$_tripClaimsDir/$_archivedDir';

      for (final imagePath in imagePaths) {
        if (imagePath.contains(_pendingDir)) {
          final file = File(imagePath);
          if (await file.exists()) {
            // Generate new filename for archived image
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final extension = imagePath.split('.').last;
            final filename = 'img_archived_$timestamp.$extension';
            final archivedFilePath = '$archivedPath/$filename';

            // Move file from pending to archived
            await file.rename(archivedFilePath);
            print('✓ Image archived: $archivedFilePath');
          }
        }
      }

      return true;
    } catch (e) {
      print('✗ Error archiving images: $e');
      return false;
    }
  }

  /// Delete pending images (if user cancels)
  static Future<bool> deletePendingImages(List<String> imagePaths) async {
    try {
      for (final imagePath in imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          print('✓ Deleted pending image: $imagePath');
        }
      }
      return true;
    } catch (e) {
      print('✗ Error deleting pending images: $e');
      return false;
    }
  }

  /// Get all pending images
  static Future<List<File>> getPendingImages() async {
    try {
      final baseDir = await _getBaseDirectory();
      final pendingPath = '${baseDir.path}/$_tripClaimsDir/$_pendingDir';

      final directory = Directory(pendingPath);
      if (!await directory.exists()) {
        return [];
      }

      final imageFiles = directory.listSync().whereType<File>().where((file) {
        final ext = file.path.split('.').last.toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      }).toList();

      print('✓ Found ${imageFiles.length} pending images');
      return imageFiles;
    } catch (e) {
      print('✗ Error getting pending images: $e');
      return [];
    }
  }

  /// Get all archived images
  static Future<List<File>> getArchivedImages() async {
    try {
      final baseDir = await _getBaseDirectory();
      final archivedPath = '${baseDir.path}/$_tripClaimsDir/$_archivedDir';

      final directory = Directory(archivedPath);
      if (!await directory.exists()) {
        return [];
      }

      final imageFiles = directory.listSync().whereType<File>().where((file) {
        final ext = file.path.split('.').last.toLowerCase();
        return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      }).toList();

      print('✓ Found ${imageFiles.length} archived images');
      return imageFiles;
    } catch (e) {
      print('✗ Error getting archived images: $e');
      return [];
    }
  }

  /// Get storage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final baseDir = await _getBaseDirectory();
      final tripClaimsPath = '${baseDir.path}/$_tripClaimsDir';

      final directory = Directory(tripClaimsPath);
      if (!await directory.exists()) {
        return {
          'totalSize': 0,
          'pendingImages': 0,
          'archivedImages': 0,
          'totalImages': 0,
        };
      }

      final pendingImages = await getPendingImages();
      final archivedImages = await getArchivedImages();

      int totalSize = 0;
      for (final image in [...pendingImages, ...archivedImages]) {
        totalSize += await image.length();
      }

      return {
        'totalSize': totalSize,
        'totalSizeInMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'pendingImages': pendingImages.length,
        'archivedImages': archivedImages.length,
        'totalImages': pendingImages.length + archivedImages.length,
        'storagePath': tripClaimsPath,
      };
    } catch (e) {
      print('✗ Error getting storage stats: $e');
      return {
        'totalSize': 0,
        'pendingImages': 0,
        'archivedImages': 0,
        'totalImages': 0,
      };
    }
  }

  /// Clear all pending images
  static Future<bool> clearPendingImages() async {
    try {
      final pendingImages = await getPendingImages();
      return await deletePendingImages(
        pendingImages.map((f) => f.path).toList(),
      );
    } catch (e) {
      print('✗ Error clearing pending images: $e');
      return false;
    }
  }

  /// Clear all archived images
  static Future<bool> clearArchivedImages() async {
    try {
      final baseDir = await _getBaseDirectory();
      final archivedPath = '${baseDir.path}/$_tripClaimsDir/$_archivedDir';

      final directory = Directory(archivedPath);
      if (await directory.exists()) {
        final files = directory.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
        print('✓ Cleared all archived images');
      }
      return true;
    } catch (e) {
      print('✗ Error clearing archived images: $e');
      return false;
    }
  }

  /// Clear all images (both pending and archived)
  static Future<bool> clearAllImages() async {
    try {
      await clearPendingImages();
      await clearArchivedImages();
      print('✓ Cleared all images');
      return true;
    } catch (e) {
      print('✗ Error clearing all images: $e');
      return false;
    }
  }
}
