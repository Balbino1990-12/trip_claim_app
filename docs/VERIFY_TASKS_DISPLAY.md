# Complete Task Display Verification Guide

## 📋 System Architecture Verification

### ✅ Current Implementation Status

**Code Path:**
```
Login Page (sets JWT token)
    ↓ ApiService.setAuthToken() + TechnicianService.setAuthToken()
    ↓
Technician Landing Page (.initState())
    ↓ _loadTasks() → TechnicianService.getAssignedTasks()
    ↓
HTTP GET: /api/technician/tasks (with Bearer token)
    ↓
Parse Response: json['data'] array
    ↓
_TechnicianDashboard Widget (receives _tasksFuture)
    ↓
_TaskCard Widgets Display (title, location, status, priority)
```

### ✅ Code Components Status

1. **[Login Page](lib/pages/login/login_page.dart)** ✅
   - Sets JWT token: `ApiService.setAuthToken(token)`
   - Sets technician token: `TechnicianService.setAuthToken(token)`
   - Redirects to TechnicianLandingPage

2. **[Technician Landing Page](lib/pages/technician/technician_landing_page.dart)** ✅
   - initState() calls _loadTasks() 
   - _loadTasks() calls TechnicianService.getAssignedTasks()
   - Sets _tasksFuture which triggers FutureBuilder
   - Auto-refresh every 5 seconds via _startPeriodicRefresh()

3. **[Technician Service](lib/services/technician_service.dart)** ✅
   - getAssignedTasks() method: `GET $baseUrl/technician/tasks`
   - Includes JWT Bearer token via _getHeaders()
   - Parses response: `json['data']` array
   - Returns: List<TechnicianTask>

4. **[_TechnicianDashboard Widget](lib/pages/technician/technician_landing_page.dart#L1078)** ✅
   - FutureBuilder<List<TechnicianTask>> at Line 1078
   - Displays:
     - Loading spinner (while fetching)
     - Error message (if fetch fails)
     - "No tasks assigned today" (if empty array)
     - _TaskCard widgets (if tasks exist)

5. **[_TaskCard Widget](lib/pages/technician/technician_landing_page.dart)** ✅
   - Shows: title, location, claimId, status, priority
   - Color-coded status: Pending (orange), In-Progress (blue), Completed (green)

---

## 🧪 Step-by-Step Verification Checklist

### Step 0: Pre-Flight Checks

**Backend Status:**
```powershell
# Check if backend is running
curl http://10.91.220.92:5000/api/health

# Expected response:
# {"status": "ok", "timestamp": "..."}
```

**Expected Output:**
```
StatusCode        : 200
StatusDescription : OK
RawContent        : HTTP/1.1 200 OK
```

If backend is not running, **START IT FIRST** before proceeding!

---

### Step 1: Database Verification

**Check if Balbino exists:**
```sql
SELECT id, username, email FROM users WHERE username = 'Balbino';
```

Expected output:
```
id | username | email
---|----------|----------------
 1 | Balbino  | balbino@...
```

**Note the ID (e.g., `1`)** - you'll use this next.

---

### Step 2: Database Task Assignment

**Check if Balbino has any tasks assigned:**
```sql
-- Replace 1 with Balbino's actual ID
SELECT 
  id, customer_name, description, location, 
  status, priority, created_at 
FROM trip_claims 
WHERE technician_id = 1
LIMIT 5;
```

**If no results:** Tasks are not assigned to Balbino yet! Insert test data first.

---

### Step 3: Insert Test Tasks (if needed)

If no tasks were found in Step 2, run this SQL:

```sql
-- Insert 5 test tasks for Balbino (replace 1 with Balbino's ID)
INSERT INTO trip_claims 
  (id, technician_id, customer_name, description, location, status, priority, created_at, updated_at) 
VALUES
  ('claim_001', 1, 'John Doe', 'Road damage assessment', 'Main Street & 5th Ave', 'pending', 'high', NOW(), NOW()),
  ('claim_002', 1, 'Jane Smith', 'Pothole repair needed', 'Oak Road', 'pending', 'medium', NOW(), NOW()),
  ('claim_003', 1, 'Bob Johnson', 'Accident damage inspection', '123 Park Lane', 'on-progress', 'high', NOW(), NOW()),
  ('claim_004', 1, 'Alice Lee', 'Water damage claim', '456 River Road', 'pending', 'low', NOW(), NOW()),
  ('claim_005', 1, 'Charlie Brown', 'Completed claim review', '789 Oak Street', 'solved', 'low', NOW(), NOW());
```

**Verify insertion:**
```sql
SELECT COUNT(*) FROM trip_claims WHERE technician_id = 1;
-- Should return: 5
```

---

### Step 4: API Direct Test

**Get JWT Token:**
```powershell
$response = curl -X POST http://10.91.220.92:5000/api/login `
  -ContentType "application/json" `
  -Body '{"username":"Balbino","password":"password"}' | ConvertFrom-Json

$token = $response.token
Write-Host "JWT Token: $token"
```

**Fetch Tasks via API:**
```powershell
$headers = @{
  "Authorization" = "Bearer $token"
  "Content-Type" = "application/json"
}

$response = curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers $headers | ConvertFrom-Json

Write-Host "Full Response:"
$response | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "Task Count: $($response.data.Count)"
Write-Host "First Task: $($response.data[0])"
```

**Expected Response Structure:**
```json
{
  "success": true,
  "data": [
    {
      "id": "claim_001",
      "claimId": "claim_001",
      "title": "Road damage assessment",
      "description": "Road damage assessment",
      "location": "Main Street & 5th Ave",
      "status": "pending",
      "priority": "high",
      "customerName": "John Doe",
      "customerPhone": "...",
      "assignedDate": "2025-02-11T...",
      ...
    },
    ...
  ]
}
```

**If you see an empty array:**
```json
{
  "success": true,
  "data": []
}
```
→ Tasks are not in database OR not assigned to this technician! Run Step 3 first.

**If you see an error:**
```json
{
  "success": false,
  "message": "..."
}
```
→ Backend error. Check backend logs.

---

### Step 5: Flutter App Test

**Start the Flutter app:**
```powershell
cd "d:\2025\Trip Claim App\trip_claim_app"
flutter run -d chrome
```

**Wait for app to load** (can take 2-3 minutes first time)

**Open browser console (F12):**
- Press `F12` to open DevTools
- Go to "Console" tab
- Look for Dart/Flutter logs

**Login as Balbino:**
- Username: Balbino
- Password: password
- Click "Login"

**Wait and observe console logs:**

After login, watch the console for:
```
✅ === TECHNICIAN TASKS REQUEST ===
🔗 URL: http://10.91.220.92:5000/api/technician/tasks
🔐 Authenticated: true
📥 Response Status: 200
📋 Response is Map with keys: [success, data]
📊 Found tasks in json.data (5 items)
✅ Tasks loaded: count=5
📌 First task details:
   - ID: claim_001
   - Title: Road damage assessment
   - Status: pending
   - Client: John Doe
```

**Navigate to Technician Landing:**
- After login, app should redirect to Technician Landing Page
- If not, click on the profile or dashboard link

**View the Dashboard:**
- Scroll down to see "Today's Assigned Tasks" section
- Should see 5 task cards displayed
- Each card shows: Title, Location, Status, Priority

---

## 🔍 Troubleshooting

### Issue 1: App Shows "No tasks assigned today"

**Check 1: Are tasks in database?**
```sql
SELECT * FROM trip_claims WHERE technician_id = 1;
```
If empty → Insert test tasks (see Step 3)

**Check 2: Is API returning tasks?**
```powershell
# Test endpoint directly (follow Step 4)
curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers @{"Authorization" = "Bearer $token"}
```
If empty array → Tasks not assigned to this user in database

**Check 3: Is user logged in correctly?**
- Open browser console (F12)
- Look for: `🔐 Authenticated: true`
- If `false` → Token not being sent. Re-login.

**Check 4: Check diagnostics panel**
- Should show: ✅ Connected, 📊 Tasks: X
- If shows ⚠️ No tasks returned → See Check 1-3

### Issue 2: App Shows Loading Spinner Forever

**Check 1: Is backend running?**
```powershell
curl http://10.91.220.92:5000/api/health
```

**Check 2: Browser Network Tab**
- Press F12 → "Network" tab
- Reload page
- Look for request to `/api/technician/tasks`
- Check: Status code, Response content

**Check 3: API Request Timeout**
- If request takes >30 seconds, it times out
- Check if backend is responding slowly
- Look for backend logs

### Issue 3: App Shows Red Error Message

**Check Browser Console (F12):**
- Copy exact error message
- Common errors:
  - `401 Unauthorized` → Token not sent or invalid
  - `404 Not Found` → Endpoint doesn't exist
  - `500 Internal Server Error` → Backend error

**Typical Error Messages:**
```
❌ Failed to load tasks: 401 Unauthorized
→ Solution: Re-login, ensure token is set

❌ Failed to load tasks: 404 Not Found  
→ Solution: Check backend has endpoint /api/technician/tasks

❌ Error loading tasks: Exception: Network error
→ Solution: Check backend is running, correct IP address
```

### Issue 4: Authentication Token Not Being Sent

**Check login flow:**
1. Login page calls: `ApiService.setAuthToken(token)`
2. Login page calls: `TechnicianService.setAuthToken(token)`
3. Both must succeed before navigation

**Verify in browser console:**
- Look for: `🔐 Technician authentication status: true`
- If `false` → Check login page's token setting code

**Force re-login:**
- Open browser dev tools
- Clear all cookies and storage
- Try logging in again

---

## 📊 Debug Panel Reference

On the Technician Landing Page, there's a "Diagnostics Panel" showing real-time status:

```
┌─ Diagnostics Panel ────────────────────┐
│ API Endpoint: http://10.91.220.92:5000 │
│ ✅ Connected                           │
│ 📊 Tasks: 5  ⏳ Pending: 3             │
│ 🔄 Refresh (button)                    │
└────────────────────────────────────────┘
```

**What each indicator means:**

| Indicator | Meaning | Status |
|-----------|---------|--------|
| ✅ Connected | Backend is reachable | ✅ Good |
| ❌ Error | Backend error or API failed | ⛔ Problem |
| ⏳ Loading | Fetching from API | 🟡 Wait |
| 📊 Tasks: 5 | 5 tasks found | ✅ Good |
| 📊 Tasks: 0 | No tasks in database | ⛔ Problem |
| ⏳ Pending: 3 | 3 tasks have status "pending" | ℹ️ Info |

**Action buttons in Diagnostics Panel:**
- 🔄 Refresh: Manually fetch tasks again
- ⚙️ Settings: View configuration
- 📋 Details: See full error/debug info

---

## ✨ Expected End-to-End Flow

### When Everything Works:

```
1. User opens app
   ↓
2. User logs in as Balbino
   ↓ [Browser shows: Logging in... ✅ Login successful]
   ↓
3. App navigates to Technician Landing Page
   ↓ [Page shows loading spinner]
   ↓
4. Console logs: "✅ Tasks loaded: count=5"
   ↓
5. Dashboard displays:
   - Notification badge: [5]
   - Diagnostics Panel: ✅ Connected, 📊 Tasks: 5, ⏳ Pending: 3
   - Task Cards Section: 5 task cards visible
     ┌───────────────────────────────────┐
     │ Road damage assessment        high│
     │ Main Street & 5th Ave            │
     │ Status: pending  Claim: 001      │
     └───────────────────────────────────┘
     (+ 4 more cards...)
   ↓
6. Every 5 seconds: Console logs "🔄 Real-time refresh: Checking..."
   ↓
7. If new task assigned via backend → Notification toast appears
   ↓ Dashboard auto-refreshes to show new task
```

---

## 🚀 Quick Start

### If First Time Testing:

**1. Make sure backend is running:**
```powershell
# Test a simple curl
curl http://10.91.220.92:5000/api/health
```

**2. Insert test tasks for Balbino:**
```sql
-- Run the SQL from Step 3 above
```

**3. Start Flutter app:**
```powershell
cd "d:\2025\Trip Claim App\trip_claim_app"
flutter run -d chrome
```

**4. Login as Balbino:**
- Username: Balbino
- Password: password

**5. View dashboard:**
- Scroll to "Today's Assigned Tasks" section
- Should see 5 task cards

---

## 📝 What to Check If Tasks Don't Show

**Priority Order:**

1. **Is backend running?** → `curl http://10.91.220.92:5000/api/health`
2. **Does database have tasks?** → `SELECT * FROM trip_claims WHERE technician_id = 1`
3. **Can API return tasks?** → Direct curl test (Step 4)
4. **Is JWT token being sent?** → Browser console shows `Authenticated: true`
5. **Is FutureBuilder rendering?** → Check browser console for logs

If all 5 checks pass but still no tasks → **There's likely a data parsing issue**. Check browser console for: `Error loading tasks: Error: ...`

---

## 🎯 Summary

**Current Status:** ✅ **Ready for Testing**

All infrastructure is in place:
- ✅ Login page sets JWT token
- ✅ Landing page fetches tasks on init
- ✅ Dashboard has FutureBuilder to display tasks
- ✅ Task cards configured with all fields
- ✅ Auto-refresh every 5 seconds
- ✅ Error handling for all scenarios
- ✅ Diagnostics panel shows real-time status

**What's needed:**
1. ✅ Backend running
2. ✅ Test tasks inserted in database
3. ✅ User logged in
4. ✅ Navigate to dashboard

**Expected behavior:**
- Tasks should appear immediately after login
- Dashboard shows task count in notification badge
- Each task visible as a card with title, location, status, priority
- Tasks auto-refresh every 5 seconds
- New tasks appear in real-time via notification

