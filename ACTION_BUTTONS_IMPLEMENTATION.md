# Action Buttons Implementation Guide

## Overview
The Technician Landing Page has four action buttons that need to be wired to the TechnicianService API methods. This guide provides implementation examples for each button.

## Button Locations
Located in `lib/pages/technician/technician_landing_page.dart` starting around line ~480-520.

## Implementation Examples

### 1. View Location Button

**Purpose**: Show task location on map

**Implementation**:
```dart
ElevatedButton.icon(
  onPressed: () async {
    // Get the first task for demo (in real app, select from active task)
    try {
      final tasks = await _tasksFuture;
      if (tasks.isNotEmpty && tasks.first.latitude != null && tasks.first.longitude != null) {
        final latitude = tasks.first.latitude!;
        final longitude = tasks.first.longitude!;
        
        // Launch Google Maps
        final String googleMapsUrl = 
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        
        if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
          await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  },
  icon: const Icon(Icons.location_on),
  label: const Text('View Location'),
  // ... style properties
)
```

**Required Import**:
```dart
import 'package:url_launcher/url_launcher.dart';
```

---

### 2. Upload Photo Button

**Purpose**: Capture or select image and upload as task evidence

**Implementation**:
```dart
ElevatedButton.icon(
  onPressed: () async {
    try {
      // Get first task for demo
      final tasks = await _tasksFuture;
      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks available')),
        );
        return;
      }
      
      final task = tasks.first;
      
      // Show options: Camera or Gallery
      showModalBottomSheet(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(ImageSource.camera, task.claimId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadImage(ImageSource.gallery, task.claimId);
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  },
  icon: const Icon(Icons.camera_alt),
  label: const Text('Upload Photo'),
  // ... style properties
)
```

**Helper Method** (add to _TechnicianDashboardState):
```dart
Future<void> _pickAndUploadImage(ImageSource source, String claimId) async {
  try {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image == null) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Uploading photo...'),
          ],
        ),
      ),
    );
    
    // Upload photo
    final success = await TechnicianService.uploadTaskPhoto(
      claimId,
      image.path,
    );
    
    Navigator.pop(context); // Close loading dialog
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully')),
      );
      setState(() => _loadData()); // Refresh tasks
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload photo')),
      );
    }
  } catch (e) {
    Navigator.pop(context); // Close loading dialog if open
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

**Required Imports**:
```dart
import 'package:image_picker/image_picker.dart';
```

**Note**: `image_picker` package is already in pubspec.yaml

---

### 3. Send Update Button

**Purpose**: Send text message/update for task

**Implementation**:
```dart
ElevatedButton.icon(
  onPressed: () async {
    try {
      final tasks = await _tasksFuture;
      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks available')),
        );
        return;
      }
      
      final task = tasks.first;
      final controller = TextEditingController();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send Task Update'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Claim: ${task.claimId}'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your update message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a message')),
                  );
                  return;
                }
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sending update...'),
                      ],
                    ),
                  ),
                );
                
                try {
                  final success = await TechnicianService.sendTaskUpdate(
                    task.claimId,
                    controller.text.trim(),
                  );
                  
                  Navigator.pop(context); // Close loading
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Update sent successfully')),
                    );
                    setState(() => _loadData());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to send update')),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  },
  icon: const Icon(Icons.message),
  label: const Text('Send Update'),
  // ... style properties
)
```

---

### 4. Complete Task Button

**Purpose**: Mark task as completed

**Implementation**:
```dart
ElevatedButton.icon(
  onPressed: () async {
    try {
      final tasks = await _tasksFuture;
      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks available')),
        );
        return;
      }
      
      final task = tasks.first;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Task?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Claim: ${task.claimId}'),
              const SizedBox(height: 8),
              Text('Title: ${task.title}'),
              const SizedBox(height: 16),
              const Text('Are you sure you want to mark this task as completed?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Completing task...'),
                      ],
                    ),
                  ),
                );
                
                try {
                  final success = await TechnicianService.updateTaskStatus(
                    task.claimId,
                    'completed',
                  );
                  
                  Navigator.pop(context); // Close loading
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task completed successfully')),
                    );
                    setState(() => _loadData());
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to complete task')),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  },
  icon: const Icon(Icons.check),
  label: const Text('Complete Task'),
  // ... style properties
)
```

---

## Implementation Tips

1. **Task Selection Strategy**
   - Current examples use `tasks.first` for demo
   - In production, tie buttons to specific task being viewed
   - Consider: Modal for task selection, or dedicated task detail page

2. **Loading States**
   - Show dialogs while API calls execute
   - Disable buttons during loading to prevent duplicate requests
   - Use `barrierDismissible: false` to prevent accidental dismissal

3. **Error Handling**
   - Catch all exceptions and show user-friendly messages
   - Log errors to console for debugging
   - Don't break UI on error (always close dialogs)

4. **User Feedback**
   - SnackBar for success/error messages
   - Dialogs for confirmations
   - Loading spinners for long operations

5. **Refresh After Action**
   - Call `setState(() => _loadData())` after successful operations
   - This refreshes both stats and task lists
   - User sees immediate feedback

## Testing Checklist

- [ ] View Location opens correct map coordinates
- [ ] Upload Photo accepts camera and gallery images
- [ ] Send Update sends message and refreshes list
- [ ] Complete Task marks task as completed
- [ ] Error handling shows user-friendly messages
- [ ] Loading states display correctly
- [ ] Task list refreshes after each action
- [ ] Stats update after task completion

## Common Issues & Solutions

**Issue**: "No tasks available" even though they exist
- **Solution**: Ensure `_tasksFuture` completed and has data

**Issue**: Photo upload fails
- **Solution**: Check file permissions, image size, network connection

**Issue**: Update message not appearing
- **Solution**: Verify backend endpoint, check API response format

**Issue**: Complete task doesn't refresh list
- **Solution**: Ensure `setState(() => _loadData())` is called after success

## Next: Task Detail Page (Optional)

For better UX, consider creating a dedicated task detail page:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TaskDetailPage(task: task),
  ),
);
```

This would allow viewing full task details and performing actions on that specific task.
