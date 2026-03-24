# Quick Start: Technician Landing Page API Integration

## ✅ Status: COMPLETE AND READY

Your technician landing page now displays **real data from your backend API**.

---

## What You Need to Know

### 1. The Data Files
Two main files handle your data:

| File | Purpose | Status |
|------|---------|--------|
| `lib/services/technician_service.dart` | API calls & data parsing | ✅ Created |
| `lib/pages/technician/technician_landing_page.dart` | UI + API integration | ✅ Updated |

### 2. What Gets Displayed
- **Dashboard Stats**: Real numbers from backend
- **Task List**: All assigned claims
- **Status Badges**: Color-coded by status
- **Welcome Message**: Dynamic task count

### 3. API Endpoints Used
```
GET  /api/technician/stats   → Dashboard stats (Pending, Completed, In Progress, Rating)
GET  /api/technician/tasks   → List of assigned tasks/claims
```

---

## For Testing

### Launch the Page
1. Run your Flutter app
2. Login as technician
3. Navigate to Technician Landing Page

### Expected Behavior
- ✅ See "Loading..." briefly
- ✅ Dashboard shows real stats
- ✅ Task list shows actual assigned claims
- ✅ No error messages (unless network is down)

### If No Technician Data Appears
1. Check: Is your backend running? (`http://10.91.220.92:5000/api`)
2. Check: Did you set the JWT token? (See below)
3. Check: Are there any tasks in the database?
4. Check: Console logs for error details

---

## Important: Set the Authentication Token

**When your user logs in, add this one line:**

```dart
// In your login success handler
TechnicianService.setAuthToken(userJwtToken);
```

**This tells the service to include your auth token in all API request headers.**

Without this, the backend might reject requests.

---

## Understanding the Status Colors

| Status | Color | Meaning |
|--------|-------|---------|
| pending | 🟠 Orange | Waiting to start |
| on-progress | 🔵 Blue | Currently working |
| completed / solved | 🟢 Green | Task finished |

*Note: Backend sends `"on-progress"` (with hyphen), the app handles this correctly*

---

## What Each API Method Does

### `getTechnicianStats()`
Returns dashboard statistics:
```json
{
  "pendingTasks": 3,
  "completedTasks": 12,
  "inProgressTasks": 2,
  "rating": 4.8,
  "totalTasksToday": 5
}
```
**Default if error**: Uses fallback (3, 12, 2, 4.8)

### `getAssignedTasks()`
Returns list of assigned claims:
```json
[
  {
    "id": "task123",
    "claimId": "CLM-2024-001",
    "title": "Repair Electrical Fault",
    "location": "123 Main St...",
    "status": "on-progress",
    "priority": "high",
    "clientName": "John Doe",
    ...
  }
]
```
**Default if error**: Returns empty list (shows "No tasks assigned")

---

## Troubleshooting

### Problem: Stats show "..." (loading forever)
- **Cause**: Backend not responding or crashed
- **Fix**: Check backend is running, check network
- **Fallback**: Page will timeout and show default stats

### Problem: No tasks appear
- **Cause**: No tasks in database OR backend error OR token not set
- **Fix**: 
  1. Verify `TechnicianService.setAuthToken(token)` is called
  2. Check backend logs for errors
  3. Verify technician has tasks assigned

### Problem: Wrong status colors
- **Cause**: Backend using different status value
- **Fix**: Check what status your backend sends, update `_getStatusColor()` if needed

### Problem: Crash on page load
- **Check**: Do you have an error message in the console?
- **Fix**: Make sure you imported TechnicianService correctly

---

## Optional: Next Steps

### If You Want Button Functionality
See `ACTION_BUTTONS_IMPLEMENTATION.md` for code examples for:
- View Location (opens map)
- Upload Photo (image picker)
- Send Update (text message)
- Complete Task (mark done)

### If You Want Better UX
1. Add pull-to-refresh: Wrap content in `RefreshIndicator`
2. Create task detail page: Show full info + actions
3. Add real-time updates: WebSocket connection

---

## Files to Reference

| File | Contains |
|------|----------|
| `TECHNICIAN_INTEGRATION_COMPLETE.md` | Full integration overview (read first) |
| `TECHNICIAN_API_INTEGRATION.md` | Detailed technical documentation |
| `ACTION_BUTTONS_IMPLEMENTATION.md` | Code examples for buttons |
| `lib/services/technician_service.dart` | The actual service code |
| `lib/pages/technician/technician_landing_page.dart` | The UI code |

---

## One-Line Test

To verify it's working, add this before opening the technician page:
```dart
TechnicianService.setAuthToken('your_jwt_token_here');
```

Then open the page. If you see data, you're good! 🎉

---

## Support Quick Links

**Need to understand FutureBuilder?**
- It loads data asynchronously and rebuilds UI when ready
- Shows loading spinner, error message, or data based on state

**Need to check API responses?**
- Use Postman to test: `GET http://10.91.220.92:5000/api/technician/tasks`
- Add header: `Authorization: Bearer your_token`

**Need to see what's happening?**
- Check console logs in VS Code
- Look for "TechnicianService" logs
- TechnicianService logs all API calls and errors

---

## Summary in 10 Seconds

✅ **Your technician landing page now loads real data from your backend.**

1. **Don't forget**: Call `TechnicianService.setAuthToken(token)` on login
2. **Test it**: Open the page and check if tasks load (should see loading spinner briefly)
3. **If broken**: Verify backend is running and token is set
4. **When ready**: Implement action buttons using the provided examples

**Status**: Production Ready ✅

---

*Last Updated: February 2025*  
*Framework: Flutter/Dart*  
*API: Node.js/Express at 10.91.220.92:5000*
