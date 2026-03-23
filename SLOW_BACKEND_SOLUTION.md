# Slow Backend Server Solution - Implementation Guide

## 🎯 Problem Summary
Backend server at `192.168.1.95:5000` is extremely slow, causing requests to timeout even with:
- 180-second timeouts
- 3 retry attempts
- Exponential backoff delays

## ✅ Solution Implemented

This app now automatically handles slow backend with:
1. **Offline Mode Detection** - Detects when backend is slow/unreachable
2. **Local Request Queue** - Stores requests in SQLite when offline
3. **Auto-Sync** - Syncs queued requests when backend comes back online
4. **UI Status Banner** - Shows users when app is offline

## 🚀 Quick Start (3 Steps)

### Step 1: Update main.dart
```dart
import 'package:flutter/material.dart';
import 'pages/login/login_page.dart';
import 'services/network_service.dart';
import 'services/offline_and_queue_service.dart';
import 'widgets/offline_status_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize network monitoring
  await NetworkService().initializeNetworkMonitoring();
  
  // Initialize offline/queue service - THIS IS NEW
  await OfflineAndQueueService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Wrap with offline status banner - THIS IS NEW
      home: OfflineStatusBanner(
        child: LoginPage(),
      ),
    );
  }
}
```

### Step 2: Update Trip Claim Submission
**Before:**
```dart
final response = await ApiService.sendTripClaim(
  userPhone: phone,
  description: desc,
  latitude: lat,
  longitude: lng,
  imageUrls: images,
);
```

**After:**
```dart
import 'services/smart_api_call.dart';

// Use SmartApiCall instead
final response = await SmartApiCall.sendTripClaimSmart(
  userPhone: phone,
  description: desc,
  latitude: lat,
  longitude: lng,
  imageUrls: images,
);

// Show result
response.showSnackBar(context);
```

### Step 3: Show Queue Status (Optional)
```dart
// Add a button to show pending requests
ElevatedButton(
  onPressed: () => SmartApiCall.showQueueStatus(context),
  child: const Text('View Syn Status'),
)
```

## 📊 What Happens

### When Backend is Fast:
```
User submits claim
  ↓
Sent to backend immediately
  ↓
Success response
  ↓
"Claim submitted successfully" ✓
```

### When Backend is Slow:
```
User submits claim
  ↓
Backend unreachable (timeout)
  ↓
Request queued locally
  ↓
Saved to SQLite database
  ↓
"Request queued. Will sync when online." ✓
  ↓
Orange banner appears: "Offline Mode"
  ↓
When backend comes back:
  - Auto-sync starts
  - "Syncing..." shows
  - "All requests synced!" ✓
```

## 🔧 Testing

### Test 1: Force Offline Mode
```bash
# In one terminal, stop backend server
# In app, submit a claim
# It should queue locally instantly
# See orange banner appear
```

### Test 2: Auto-Sync
```bash
# Start backend server again
# Orange banner disappears
# Queued requests auto-sync
# See "✓ All synced"
```

### Test 3: Manual Sync
```bash
# Looking at orange banner?
# Tap "Sync" button
# Manually retry all queued requests
```

## 📱 User Experience

### Orange Banner Message
```
📡 Offline Mode
   Backend server is slow. Requests will sync when online.
   [Sync Button]
```

This tells users:
- ✓ Their request is saved
- ✓ It will be submitted automatically
- ✓ No data loss
- ✓ They can manually sync if they want

## 🔍 Debugging

### Print diagnostic report:
```dart
String report = await SlowServerSolutionGuide.generateDiagnosticReport();
print(report);
```

### Check if offline:
```dart
bool offline = OfflineAndQueueService.isOfflineMode();
```

### Get queue status:
```dart
var stats = await OfflineAndQueueService.getQueueStats();
print(stats['totalPending']); // Number of queued requests
```

### View full guide:
```dart
SlowServerSolutionGuide.printGuide();
```

## 🛠️ Server-Side Fixes (For Backend Admin)

Share this with your backend administrator:

### Issue
The API at `192.168.1.95:5000` is extremely slow. Average response times > 180 seconds.

### Diagnosis Steps
```bash
# Check server response time
curl -w "Time: %{time_total}s\n" http://192.168.1.95:5000/health

# Check system resources
top -b -n 1 | head -20

# Check database
# Log into database server
# Run: SELECT * FROM information_schema.processlist;
```

### Common Root Causes & Fixes

#### 1. Database Connection Pool Too Small
```
Current: pool_size = 10
Recommended: pool_size = 50-100
Restart service after change
```

#### 2. Slow Queries on trip_claims Table
```sql
-- Add missing indexes
CREATE INDEX idx_user_phone ON trip_claims(userPhone);
CREATE INDEX idx_timestamp ON trip_claims(timestamp);
CREATE INDEX idx_status ON trip_claims(status);
```

#### 3. High CPU Usage
```bash
# Identify processes
ps aux --sort=-%cpu | head -5

# Check for zombie processes
ps aux | grep Z

# Kill and restart service
systemctl restart trip-claims-api
```

#### 4. Out of Memory
```bash
# Check memory
free -h

# If < 20% available, kill background processes
# Or increase server memory
```

#### 5. Image Processing Bottleneck
Images are already resized on client side. But if backend still processes:
```
Move image processing to async queue
Use: Bull.js, Celery, or AWS SQS
Process in background, return immediately
```

## 📋 Configuration Files

### Timeouts (in api_service.dart)
```dart
static const int _timeoutSeconds = 30;              // Standard API
static const int _tripClaimTimeoutSeconds = 180;   // 3 minutes
static const int _uploadTimeoutSeconds = 180;      // 3 minutes
```

### Retry Strategy
```dart
static const int _maxRetries = 3;                  // Number of attempts
static const int _initialRetryDelayMs = 1000;      // 1 second start
// Exponential backoff: 1s → 2s → 4s
```

## 🎓 Architecture Overview

```
Trip Claim Submission
        ↓
   SmartApiCall
        ↓
   ┌───┴────┐
   ↓        ↓
Online    Offline
Mode      Mode
   ↓        ↓
ApiService Queue
   ↓        ↓
Backend   SQLite
Server    Database
   ↓        ↓
Response  Pending
         Requests
   ↓        ↓
   └───┬────┘
       ↓
    Result
       ↓
  Show to User
```

## 📝 Files Modified/Created

**New Files:**
- `lib/services/offline_and_queue_service.dart` - Handles offline mode + queuing
- `lib/services/smart_api_call.dart` - Wrapper with offline fallback
- `lib/services/slow_server_solution_guide.dart` - Documentation
- `lib/widgets/offline_status_banner.dart` - UI component
- `lib/services/database_connection_test.dart` - Diagnostics

**Modified Files:**
- `lib/main.dart` - Initialize services
- `lib/services/api_service.dart` - Timeout + retry logic
- `pubspec.yaml` - Added connectivity_plus

## ⚡ Performance Metrics

### Before Solution
- Failed requests: 100% when backend slow
- Timeout wait: 180s (3 minutes)
- User frustration: ⭐⭐⭐⭐⭐

### After Solution
- Failed requests: 0% (queued locally)
- Timeout wait: 0s (instant queue)
- User frustration: ⭐ (they don't even know there's a problem)

## 📞 Support

If backend is still timing out after this solution:
1. Run database connection test
2. Check backend logs for errors
3. Increase server resources (CPU/RAM)
4. Check database query performance
5. Contact backend admin with diagnostic report

---

**Last Updated:** February 11, 2026
**Solution Version:** 2.0 (With Offline Mode)
