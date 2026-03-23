# Quick Diagnostic Flowchart

## ⏱️ If You See: TimeoutException after 30/60 seconds

**Error:** `Error fetching technician tasks: TimeoutException`

**Quick Fix:**
```powershell
# Run diagnostic script
.\diagnose_timeout.ps1

# Check if backend is running
curl http://10.91.220.241:5000/api/health

# Check backend logs for errors
```

**Most Common Causes:**
1. ❌ Backend not running → START IT
2. ❌ Backend very slow → Check database performance
3. ❌ Network issue → Verify IP/port correct

**Full Guide:** See [TIMEOUT_ERROR_FIX.md](TIMEOUT_ERROR_FIX.md)

---

## 🚀 Step 1: Run and Login
```
flutter run → Login as Technical User → Check redirect
```

### Expected Result:
✅ Redirected to Technician Landing Page

### If Not:
❌ Check console for: `Is Technician: false`
→ Add test user with `role='technician'` to backend

---

## 📡 Step 2: Check Console for API Responses
```
Watch console for these patterns after login:
```

### Pattern A: Dashboard Initializes
```
🚀 TECHNICIAN LANDING PAGE - INITIALIZING
🌐 API Service Base URL: http://...
🔐 Authentication Status: true
```
✅ If you see this → Go to Step 3

❌ If NOT → Backend URL not configured
→ Check ApiService.baseUrl matches your backend

---

## 📊 Step 3: Check API Response Status
```
Console will show:
📥 Response Status: ???
```

### Status 200 → Data should load ✅
- Check console for: `✅ SUCCESS: Stats loaded`
- If not → Response format wrong (see Step 4)

### Status 404 → Endpoints missing ❌
- Backend doesn't have endpoints
- Create these routes:
  ```javascript
  GET /api/technician/stats
  GET /api/technician/tasks
  ```

### Status 401 → Authentication failed ❌
- Token not being sent OR invalid
- Console should show: `🔑 Authorization header added`
- If missing → Token not set (see Step 5)

### Status 500 → Backend error ❌
- Check backend logs for actual error
- Common: Database connection, filtering logic

---

## 🔑 Step 4: Verify Authentication
```
Console will show one of:
```

### ✅ Auth Working
```
🔑 Authorization header added: Bearer eyJhbGc...
```
→ Token is being sent correctly
→ If still no data, problem is backend response format

### ❌ Auth Missing
```
⚠️ WARNING: No authentication token set!
```
→ Token not being set during login
→ Check: Does backend login response have `token` or `accessToken`?

---

## 📋 Step 5: Check Response Format

If Status 200 but no data loading, check response format:

### Expected Format:
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

### If Different:
Update [technician_service.dart](lib/services/technician_service.dart):
```dart
// Line ~228, in getTechnicianStats():
final statsData = json is Map ? json['YOUR_FIELD_NAME'] ?? json : json;
```

---

## 🎯 Most Common Fixes

### Issue: "Does not have endpoint"
**Quick Fix:**
```javascript
// Add to your Express backend:
app.get('/api/technician/stats', async (req, res) => {
  const user = req.user;
  const stats = await db.query(
    'SELECT COUNT(*) as pendingTasks FROM trip_claims WHERE technician_id = ? AND status = "pending"',
    [user.id]
  );
  res.json({ data: stats[0] });
});

app.get('/api/technician/tasks', async (req, res) => {
  const user = req.user;
  const tasks = await db.query(
    'SELECT * FROM trip_claims WHERE technician_id = ? ORDER BY created_at DESC',
    [user.id]
  );
  res.json({ data: tasks });
});
```

### Issue: "Token not being sent"
**Quick Fix:**
```dart
// In lib/pages/login/login_page.dart, after login:
final token = loginResponse.data!['token'] ?? loginResponse.data!['accessToken'];
if (token != null) {
  TechnicianService.setAuthToken(token);  // ← Make sure this line exists
}
```

### Issue: "Wrong response format"
**Quick Fix:**
Check console for actual response:
```
📥 Response Body: {"what_you_actually_get": ...}
```
Then update parsing logic in technician_service.dart

---

## ✅ Success Indicators

All of these should be true:

1. ✅ User redirects to Technician Landing Page
2. ✅ Console shows: `🔧 TECHNICIAN DASHBOARD - DATA LOAD INITIATED`
3. ✅ Console shows: `📥 Response Status: 200`
4. ✅ Console shows: `✅ SUCCESS: Stats loaded successfully`
5. ✅ Console shows: `✅ SUCCESS: Tasks loaded successfully`
6. ✅ Dashboard displays task count and statistics
7. ✅ Task list shows real assignments
8. ✅ No error messages in console

---

## 🔗 Console Emoji Key

| Emoji | Meaning |
|-------|---------|
| 🚀 | Initialization/Startup |
| 📡 | API Request/Response |
| 🔑 | Authentication |
| 📥 | Received data/Response |
| ✅ | Success |
| ❌ | Error |
| ⚠️ | Warning |
| 🔄 | Retry/Refresh |
| 🌐 | URL/Network |
| 📊 | Data details |
| 🔐 | Auth status |
| 🔧 | Configuration |

---

## 💬 Sample Discord/Slack Report

If asking for help, include:

```
Backend URL: http://192.168.1.100:5000
User Type: Technician

Console Output:
[paste relevant console lines with timestamps]

Current Behavior:
[what happens instead of data loading]

Have You:
- [ ] Verified backend is running?
- [ ] Checked endpoints exist?
- [ ] Tested with cURL?
- [ ] Checked backend logs?
```

---

## 🛠️ Emergency Debug: Add Response Dump

If stuck, add this to [technician_service.dart](lib/services/technician_service.dart):

```dart
// In getTechnicianStats(), add after Response Status log:
print('📥 FULL Response Body:');
print(response.body);
```

Then:
1. Run app
2. Copy full response from console
3. Use online JSON formatter to see structure
4. Compare with expected format in this guide

---

**Pro Tip:** Enable verbose logging for entire request/response:
Check out [DIAGNOSTICS_GUIDE.md](DIAGNOSTICS_GUIDE.md) for advanced troubleshooting.
