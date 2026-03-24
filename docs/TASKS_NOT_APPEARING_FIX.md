# Why Tasks Aren't Appearing - Troubleshooting Guide

## 🔴 Problem Summary
Tasks are assigned to technicians in the testing interface, but the technician landing page shows "No tasks assigned" even though you've assigned many.

---

## 🔍 Step 1: Run Diagnostics

### Option A: Using PowerShell Script (Recommended)
Run the diagnostic script I created:
```powershell
cd "d:\2025\Trip Claim App\trip_claim_app"
.\TEST_TECHNICIAN_TASKS.ps1
```

**Before running, edit the script:**
- Change `$TECHNICIAN_PHONE` to your technician's phone number
- Change `$PASSWORD` to the technician's password

### What the script will tell you:
1. ✅ If backend is reachable
2. ✅ If login works
3. ✅ If `/technician/stats` endpoint returns data
4. ✅ If `/technician/tasks` endpoint returns data
5. ✅ How many tasks are in the response

---

## 🎯 Possible Issues & Solutions

### Issue 1: "Backend is NOT reachable"
**Problem**: The app can't connect to the backend API

**Solutions**:
- [ ] Check backend is running: `http://10.91.220.92:5000/api`
- [ ] Check if IP address `10.91.220.92` is correct (might be different in your network)
- [ ] Check firewall isn't blocking the connection
- [ ] Check Windows Firewall allows the app to access network

**To fix**: Edit `lib/config/app_config.dart` and change the IP to your actual backend server IP

---

### Issue 2: "Login failed"
**Problem**: Technician username/password is incorrect or backend login endpoint has issues

**Solutions**:
- [ ] Verify correct phone number and password
- [ ] Check backend login endpoint is working: `POST /api/auth/login`
- [ ] Check backend returns a JWT token

---

### Issue 3: "Stats endpoint working BUT Tasks endpoint returns 404"
**Problem**: Backend doesn't have `/technician/tasks` endpoint implemented

**Solution**: Backend needs to implement this endpoint. It should:
- Accept GET request with Authorization header
- Return list of tasks assigned to the logged-in technician
- Expected response format:
```json
[
  {
    "id": "task_123",
    "claimId": "claim_001",
    "title": "Road Damage Assessment",
    "description": "Pothole on Main Street",
    "location": "Main Street, Downtown",
    "status": "pending",
    "priority": "high",
    "latitude": 10.6899,
    "longitude": 77.1025
  }
]
```

---

### Issue 4: "Tasks endpoint returns 401 (Unauthorized)"
**Problem**: JWT token is invalid or expired

**Solutions**:
- [ ] Login again to get a fresh token
- [ ] Check token is being set correctly in TechnicianService
- [ ] Check backend validates the token correctly

---

### Issue 5: "Tasks endpoint returns 200 BUT NO TASKS in response"
**Problem**: Endpoint works, but no tasks are assigned to this technician in the database

**This is the most likely issue!**

Check database for tasks:
```sql
-- View all technicians
SELECT id, user_type, username FROM users WHERE user_type = 'technician';

-- Check tasks assigned to a specific technician (replace ID with your technician's ID)
SELECT * FROM trip_claims WHERE technician_id = 5;

-- If no tasks, insert test tasks
INSERT INTO trip_claims (
  id, technician_id, customer_name, customer_phone, 
  status, location, description, created_at, updated_at
) VALUES 
(
  'TEST_001', 
  5,  -- Replace with your technician ID
  'Test Customer',
  '+1234567890',
  'pending',
  'Main Street, Downtown',
  'Test task - Road assessment',
  NOW(),
  NOW()
);
```

---

## 📋 Debug Checklist

### In the APP Console Logs

After login, when the page loads, look for logs like:

✅ **Good logs** (tasks will appear):
```
📡 getTechnicianStats: Fetching from http://10.91.220.92:5000/api/technician/stats
🔐 Using token: eyJhbGciOiJIUzI1...
📊 Response Status: 200
✅ getTechnicianStats: Success - 5 pending tasks
📡 getAssignedTasks: Fetching from http://10.91.220.92:5000/api/technician/tasks
📊 Response Status: 200
✅ getAssignedTasks: Success - 3 tasks loaded
```

❌ **Bad logs** (indicates problem):
```
❌ getAssignedTasks: Not authenticated - token is null or empty
❌ getAssignedTasks: HTTP 404
❌ getAssignedTasks: HTTP 401
⚠️ No tasks returned
```

### View Console Logs in Flutter
1. Open VS Code terminal in your Flutter project
2. Run: `flutter run` (on your device/emulator)
3. Look at the terminal output while the page loads
4. Look for `❌` or `✅` messages starting with `getAssignedTasks` or `getTechnicianStats`

---

## 🚀 Common Fixes

### Fix 1: Ensure Token is Set After Login
The token MUST be set in `TechnicianService` after login.

Check in `lib/pages/login/login_page.dart` line ~145:
```dart
TechnicianService.setAuthToken(token);  // This line MUST execute
```

If this line is missing, add it!

### Fix 2: Check Backend Response Format
Backend might be returning tasks in different formats. I've added support for:
- Direct array: `[{...}, {...}]`
- With data wrapper: `{ "data": [{...}] }`
- With tasks wrapper: `{ "tasks": [{...}] }`

If your backend uses different format, let me know!

### Fix 3: Insert Test Tasks
If database has no tasks assigned:
```sql
-- Get your technician ID first
SELECT id FROM users WHERE user_type = 'technician' LIMIT 1;

-- Use that ID to insert test tasks
INSERT INTO trip_claims (
  id, technician_id, customer_name, customer_phone, 
  status, location, description, created_at, updated_at
) VALUES 
('test_001', YOUR_TECH_ID, 'Test', '1234567890', 'pending', 'Location', 'Test', NOW(), NOW());
```

---

## 📞 Still Not Working?

1. ✅ Run `TEST_TECHNICIAN_TASKS.ps1` and share the output
2. ✅ Share the console logs from Flutter (look for `❌` errors)
3. ✅ Check your backend logs for errors
4. ✅ Verify tasks exist in database for this technician

---

## Summary

**Most likely cause**: No tasks are assigned to the logged-in technician in the database.

**Next step**: 
1. Run the diagnostic script
2. Check if tasks endpoint returns any tasks
3. If not, check database for tasks assigned to your technician
4. If no tasks, insert test tasks as shown above
5. Tasks should appear on next login!
