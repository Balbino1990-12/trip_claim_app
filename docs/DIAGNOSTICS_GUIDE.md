# Technician Dashboard Data Fetch Diagnostics Guide

## Overview
This guide helps diagnose why the Technician Landing Page is not fetching real data from the backend. Comprehensive logging has been added to help identify the exact point of failure.

## 🚀 Quick Start: Running Diagnostics

### Step 1: Run the Application
```bash
flutter run
```

### Step 2: Login as Technical/Technician User
- Use credentials that have a user type containing "technician" or "technical"
- Check the backend response user fields: `role`, `userType`, `type`, or `department`

### Step 3: Monitor Console Output
Open the Flutter console/terminal and watch for diagnostic log entries.

---

## 📡 Expected Log Flow

When you successfully login as a technician, you should see this sequence in the console:

### Phase 1: Login Processing
```
🔐 ✓ Login successful, syncing token to services...
✅ Technician auth token set: ...TOKEN_PREVIEW... (length: XXX)
🔐 Technician authentication status: true
✓ Token synced to all services

👤 User Type Detection:
   - Is Technician: true
   - User Data: {...}

🚀 Redirecting to Technician Landing Page...
```

### Phase 2: Dashboard Initialization
```
🚀 ═══════════════════════════════════
🚀 TECHNICIAN LANDING PAGE - INITIALIZING
🚀 ═══════════════════════════════════
⏰ Time: 2025-02-13 14:30:45.123456
🌐 API Service Base URL: http://your-backend:port/api
🔐 Authentication Status: true
🚀 ═══════════════════════════════════
```

### Phase 3: Data Loading Initiation
```
════════════════════════════════════════════════════════════
🔧 TECHNICIAN DASHBOARD - DATA LOAD INITIATED
════════════════════════════════════════════════════════════
⏰ Timestamp: 2025-02-13 14:30:45.654321
🌐 API Base URL: http://your-backend:port/api
🔗 Stats Endpoint: http://your-backend:port/api/technician/stats
🔗 Tasks Endpoint: http://your-backend:port/api/technician/tasks
🔐 Technician Service authenticated: true
════════════════════════════════════════════════════════════
```

### Phase 4: API Requests

#### Stats Request:
```
📡 === TECHNICIAN STATS REQUEST ===
🔗 URL: http://your-backend:port/api/technician/stats
🔐 Authenticated: true
🔑 Authorization header added: Bearer ...TOKEN_PREVIEW...
🔑 Token length: XXX characters
📥 Response Status: 200
📥 Response Body: {"data":{"pendingTasks":5,...}}

✅ SUCCESS: Stats loaded successfully
   - Pending Tasks: 5
   - Completed Tasks: 12
   - In Progress Tasks: 2
   - Rating: 4.8
   - Total Today: 5
```

#### Tasks Request:
```
📡 === TECHNICIAN TASKS REQUEST ===
🔗 URL: http://your-backend:port/api/technician/tasks
🔐 Authenticated: true
🔑 Authorization header added: Bearer ...TOKEN_PREVIEW...
🔑 Token length: XXX characters
📥 Response Status: 200
📥 Response Body: {"data":[{"id":"1","title":"Task 1",...}]}
📊 Found tasks in json.data (3 items)

✅ SUCCESS: Tasks loaded successfully
   - Task Count: 3
   - First Task: Task 1
   - Status: pending
```

---

## 🔍 Troubleshooting Guide

### Issue 1: User NOT Redirecting to Technician Page
**Console Shows:**
```
👤 User Type Detection:
   - Is Technician: false
```

**Solution:**
- Check that your backend user response includes one of:
  - `role: "technician"` or `role: "technical"`
  - `userType: "technician"` or `userType: "technical"`
  - `type: "technician"` or `type: "technical"`
  - `department: "technician"` or `department: "technical"`
- Values are case-insensitive
- Check [login_page.dart](lib/pages/login/login_page.dart#L240) for the `_isTechnicalUser()` method

---

### Issue 2: Authentication Token Not Set
**Console Shows:**
```
⚠️ WARNING: No authentication token set! API requests may fail with 401.
⚠️ Make sure TechnicianService.setAuthToken() was called during login.
```

**or**

```
🔐 Technician authentication status: false
```

**Solution:**
1. Verify backend returns `token` or `accessToken` field in login response
2. Check that `/lib/pages/login/login_page.dart` line 156 extracts the token correctly
3. Add debug print to see what the backend returned:
   ```dart
   print('Token from backend: ${loginResponse.data}');
   ```

---

### Issue 3: Dashboard Shows But Data Not Loading (Most Common)
**Console Shows:**
```
🔧 TECHNICIAN DASHBOARD - DATA LOAD INITIATED
...
📡 === TECHNICIAN STATS REQUEST ===
🔗 URL: http://your-backend:port/api/technician/stats
...
(No success or error log follows)
```

**Most Likely Causes:**

#### 3a: 404 Error - Endpoint Doesn't Exist
**Console Shows:**
```
📥 Response Status: 404
```

**Solution:**
- Backend doesn't have the endpoint `/api/technician/stats` or `/api/technician/tasks`
- Check your Express routes for these endpoints:
  ```javascript
  app.get('/api/technician/stats', authMiddleware, getTechnicianStats);
  app.get('/api/technician/tasks', authMiddleware, getTechnicianTasks);
  ```

#### 3b: 401 Error - Unauthorized
**Console Shows:**
```
📥 Response Status: 401
```

**Solution:**
- Authorization header not being sent OR token is invalid
- Check logs show: `🔑 Authorization header added: Bearer ...`
- If yes → Token format issue, check backend auth middleware
- If no → Token not set, see Issue #2 above

#### 3c: 500 Error - Backend Error
**Console Shows:**
```
📥 Response Status: 500
📥 Response Body: {"error":"..."}
```

**Solution:**
- Backend is throwing an error processing the request
- Check server logs for the actual error
- Common issues:
  - Database connection failure
  - Filtering by wrong technician ID
  - SQL query error

#### 3d: Connection Timeout
**Console Shows:**
```
❌ Error fetching technician tasks: TimeoutException after 0:00:30.000000
```

**Solution:**
- Backend not reachable at the configured URL
- Verify:
  - Backend is running
  - URL is correct: `http://your-backend:port/api`
  - Network connectivity
  - Firewall/proxy issues

---

### Issue 4: Response Format Error
**Console Shows:**
```
❌ ERROR Loading Stats: type '_InternalLinkedHashMap<String, dynamic>' is not a subtype of type 'Map<String, dynamic>'
```

**Solution:**
- Backend returning unexpected JSON structure
- Check response format matches expected:
  ```json
  {
    "data": {
      "pendingTasks": 5,
      "completedTasks": 12,
      "inProgressTasks": 2,
      "rating": 4.8,
      "totalTasksToday": 5
    }
  }
  ```
- Update [technician_service.dart](lib/services/technician_service.dart) to handle your format

---

## 🔧 Diagnostic UI Features

### Top Debug Info Bar
Shows at the top of the dashboard:
- **API:** Exact URL being used
- **Auth:** Authentication status (✓ Active or ✗ Inactive)
- **Time:** Current time for correlation with logs

### Refresh Button
- Click to manually retry data fetch
- Logs: `🔄 Manual refresh triggered by user`
- Helps identify if issue is intermittent

---

## 📋 Pre-Flight Checklist

Before running diagnostics, verify:

- [ ] Backend is running at the configured URL
- [ ] Backend has endpoints:
  - `/api/technician/stats`
  - `/api/technician/tasks`
- [ ] Both endpoints have authentication middleware
- [ ] Backend returns JWT-valid token on login
- [ ] Database tables exist and have data for test technician
- [ ] Test technician has `role='technician'` (or similar field)
- [ ] Test technician has assigned tasks in database

---

## 🛠️ Manual Testing with cURL

If logs show endpoints are correct but data isn't loading, test directly:

```bash
# First, login to get token
curl -X POST http://your-backend:port/api/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"+1234567890","password":"password"}'

# Extract token from response, then test stats endpoint
curl -X GET http://your-backend:port/api/technician/stats \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json"

# Test tasks endpoint
curl -X GET http://your-backend:port/api/technician/tasks \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json"
```

Both should return 200 with JSON data.

---

## 📊 Log Files Locations

### iOS
```
Console.app → Filter "flutter" or "dart"
```

### Android
```
adb logcat | grep flutter
```

### Web
```
F12 → Console tab
```

### macOS/Linux
```
Terminal where `flutter run` was executed
```

---

## 🔗 Related Files

- [Login Page](lib/pages/login/login_page.dart) - User type detection & token setup
- [Technician Service](lib/services/technician_service.dart) - API calls & auth
- [Technician Landing Page](lib/pages/technician/technician_landing_page.dart) - UI & data display
- [API Service](lib/services/api_service.dart) - Base HTTP client

---

## 💡 Advanced: Enabling More Verbose Logging

Edit [technician_service.dart](lib/services/technician_service.dart) to add response body full logging:

```dart
// Line ~235: In getTechnicianStats(), replace Response Body line with:
print('📥 Full Response Body: ${response.body}');
```

This helps see the complete response for format debugging.

---

## ✅ Success Indicators

When everything is working correctly:

1. ✅ User redirects to TechnicianLandingPage after login
2. ✅ Console shows "✅ SUCCESS:" logs for both stats and tasks
3. ✅ Dashboard displays:
   - Task count and assignments
   - Stats cards with pending/completed counts
   - Task list with real data
4. ✅ No 401, 404, or error logs
5. ✅ Manual refresh button works and updates data

---

## Questions & Support

If diagnostics aren't clear, collect:
1. Full console output from login through data load
2. Backend URL being used (from UI debug info)
3. Backend logs showing the incoming requests
4. Response from manual cURL tests
5. Database query to verify test technician has assigned tasks

Then cross-reference this guide with your specific setup.
