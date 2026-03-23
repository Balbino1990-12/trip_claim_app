# Auto-Sync Status Update Debugging Guide

## System Architecture
```
Technician App
    ↓
PUT /api/claims/:id/status
    ↓
Backend Database (Update Claim)
    ↓
Admin Dashboard (Auto-polls every 1 second)
    ↓
Display Updated Status
```

## Step-by-Step Testing

### 1. **Open Both Apps**
- Open Technician Landing Page
- Open Admin Dashboard (in web browser or another emulator/device)
- Make sure they're both connected to: `http://10.91.220.92:5000/api`

### 2. **Technician Side - Update Status**

**Expected Flow:**
```
Terminal Output:
═══════════════════════════════════════
🔄 Updating Claim Status
═══════════════════════════════════════
Claim ID: claim_001
New Status: completed
Base URL: http://10.91.220.92:5000/api

📍 Endpoint: PUT http://10.91.220.92:5000/api/claims/claim_001/status
📤 Request Body: {"status": "completed"}
🔐 Authorization: Bearer token set: true

✅ Backend Response:
   Status Code: 200
   Headers: {content-type: application/json, ...}
   Body: {"success":true,"message":"Trip claim status updated successfully",...}

✅ SUCCESS: Status updated successfully - Database persisted
   Status will sync to admin dashboard within 1 second
═══════════════════════════════════════
```

**What to look for in console logs:**
- ✅ Status Code: 200 (or 201, 202, 204) = SUCCESS
- ❌ Status Code: 400 = Bad Request (invalid status value)
- ❌ Status Code: 403 = Permission Denied
- ❌ Status Code: 404 = Claim not found
- ❌ Status Code: 401 = Not authorized (token issue)

### 3. **Admin Dashboard Side - Auto-Sync**

**Expected Flow:**
```
Terminal Output (appears every update):
🔄 [AUTO-SYNC] 2025-02-13 14:30:45 - Claims updated from backend (Filter: all)
   📋 claim_001 - Status: completed
   📋 claim_002 - Status: pending
   📋 claim_003 - Status: on-progress
```

**Visual Changes:**
- Claim card status changes within 1 second
- Status badge color updates (green = completed)
- If filtering by status: claim might move/disappear from view (if status changed from the filter)

---

## Troubleshooting

### Issue: "Response Code: 404" or "Claim not found"

**Probable Causes:**
1. **Claim doesn't exist** - Verify the claim ID exists in database
2. **Permission issue** - The claim might be owned by admin, not the technician
3. **User ID mismatch** - Backend check: `userId: req.userId` doesn't match claim ownership

**Solution:**
```sql
-- Check if claim exists and see who owns it
SELECT id, status, userId FROM trip_claims WHERE id = 'claim_001';

-- If userId doesn't match technician's ID, the update will fail
-- The backend needs to be updated to check assignedTechnicianId instead
```

---

### Issue: "Response Code: 400" - Bad Request

**Probable Cause:**
- Invalid status value sent

**Solution:**
- Verify only these status values are used:
  - `pending`
  - `on-progress` (not "in-progress")
  - `rejected`
  - `completed`

---

### Issue: Response Code 200 but Admin Dashboard NOT updating

**Probable Causes:**
1. **Backend not saving** - Response says success but database wasn't updated
2. **Admin dashboard not polling** - Check if auto-sync timer is running
3. **Claim ID mismatch** - Frontend and backend using different IDs

**Debug Steps:**
1. Check backend logs: Did the UPDATE query execute?
2. Check database directly: SELECT * FROM trip_claims WHERE id = 'claim_001'
3. Open browser console on admin dashboard - look for auto-sync logs

---

### Issue: Admin Dashboard shows loading spinner constantly

**Solution:**
- The full `_loadData()` includes a loading indicator
- This is normal but can be annoying
- The important syncing happens silently with `_silentRefreshClaims()` every 1 second
- Full `_loadData()` runs every 15 seconds for statistics

---

## Console Logs to Watch

### Technician App
```
📤 Sending status update...
   Claim ID: {id}
   New Status: {status}

✅ Backend Response:
   Status Code: ...
   Headers: ...
   Body: ...
```

### Admin Dashboard
```
✅ Admin Dashboard initialized with real-time sync (1-second polling)

🔄 [AUTO-SYNC] {timestamp} - Claims updated from backend (Filter: {filter})
   [Status Changed] {id}: {old} → {new}
```

---

## Quick Test Command (PowerShell)

```powershell
# Test the PUT endpoint directly
$claimId = "claim_001"
$token = "YOUR_JWT_TOKEN_HERE"

$response = Invoke-WebRequest -Method PUT `
   -Uri "http://10.91.220.92:5000/api/claims/$claimId/status" `
  -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} `
  -Body '{"status":"completed"}'

$response.StatusCode
$response.Content
```

---

## Complete Flow Verification Checklist

- [ ] Technician logged in with valid JWT token
- [ ] Admin dashboard accessed and loading claims
- [ ] Technician selects a task card
- [ ] Technician selects status "completed"
- [ ] Technician clicks "Save Status Update"
- [ ] **Console shows**: Status Code 200 response ✅
- [ ] **Admin dashboard**: Claim status updates within 1 second
- [ ] **Admin dashboard console**: Shows [AUTO-SYNC] log entry
- [ ] Status badge color changes to green (completed)

---

## Key Variables

| Variable | Value | Location |
|----------|-------|----------|
| Base URL | `http://10.91.220.92:5000/api` | ApiService.baseUrl |
| Status Endpoint | `PUT /api/claims/:id/status` | TechnicianService.updateTaskStatus() |
| Poll Interval | 1 second (1000 ms) | AdminDashboardPage._backgroundSyncTimer |
| Full Refresh | 15 seconds | AdminDashboardPage._autoRefreshTimer |
| Valid Statuses | pending, on-progress, rejected, completed | Backend validation |

---

## Next Steps if Still Not Working

1. **Enable detailed logging in backend** - Add console.log to PUT endpoint
2. **Verify claim ownership** - Check if `userId` field matches technician's ID
3. **Check network** - Verify both apps can reach `http://10.91.220.92:5000`
4. **Verify JWT token** - Ensure token is fresh and not expired
5. **Check backend logs** - Look for errors in backend console during status update

