# 🔒 Blocked Workflow Test Guide

## Overview
This guide tests the complete **Rejected Task Blocking Workflow** where:
1. Technician rejects a task
2. Task becomes **BLOCKED** (technician cannot work on it)
3. Technician requests admin permission to re-open
4. Admin re-opens task from dashboard
5. Task becomes unblocked and technician can work again

---

## Prerequisites
- ✅ Flutter build successful: `cd trip_claim_app && flutter build web`
- ✅ Backend running: `npm start` in `/backend`
- ✅ Admin dashboard loaded: http://localhost:3000/admin-dashboard
- ✅ Technician app running: http://localhost:3001

---

## Complete Workflow Test (5-10 minutes)

### Step 1: Technician Rejects a Task
**Action**: Open technician app, expand a task card, click **"Rejected"** button

**Expected Results**:
- ✅ Status button changes to "Rejected" (red button)
- ✅ Backend logs show: `[STATUS UPDATE] Request received... rejected`
- ✅ Backend logs show: `[BROADCAST] Status update sent to connected admins`

**Console Output** (Browser DevTools):
```
[INFO] Updating task status
   Claim ID: xxx
   New Status: rejected
[SUCCESS] Task status updated successfully
```

---

### Step 2: Verify Task is Blocked in Technician App
**Action**: Look at the task card after rejecting

**Expected Results**:
- ✅ Status update buttons ("Completed", "Rejected") are **HIDDEN**
- ✅ Red container appears with:
  - 🔒 Lock icon
  - `🔒 Task Blocked` heading
  - Message: "This task has been rejected. You need admin approval to continue working on it."
  - **Orange "Request Re-open" button** (NEW FEATURE!)

**Visual Confirmation**:
```
╭─ 🔒 Task Blocked ─────────────────────────╮
│                                           │
│ This task has been rejected. You need     │
│ admin approval to continue working on it. │
│                                           │
│ [🔓 Request Re-open Button]               │
╰───────────────────────────────────────────╯
```

---

### Step 3: Technician Requests Re-open
**Action**: Click the orange **"Request Re-open"** button

**Expected Results**:
- ✅ Button shows loading state: `"Sending Request..."`
- ✅ Button briefly becomes disabled
- ✅ Orange snackbar notification appears:
  - Title: "Re-open Request Sent"
  - Message: "Admin will review and re-open task #xxxxxxxx"

**Console Output**:
```
🔓 Requesting task re-open...
   Claim ID: xxx
   Current Status: rejected
✅ Re-open request sent successfully
```

---

### Step 4: Verify Admin Dashboard Shows Re-open Button
**Action**: Open admin dashboard (http://localhost:3000/admin-dashboard)

**Expected Results**:
- ✅ Go to **"📋 Trip Claims"** tab
- ✅ Find the rejected task (status badge shows "rejected" in red)
- ✅ In the Actions column, see **"🔓 Re-open"** button (instead of "Update")

**Table Row Example**:
```
User Phone    | Location | Images | Status   | Technical Name | Created   | Actions
9876543210    | 📍 View  | 📸 2   | rejected | Unassigned    | 01/15/25  | [View] [🔓 Re-open]
```

---

### Step 5: Admin Re-opens the Task
**Action**: Click the **"🔓 Re-open"** button on the rejected task

**Expected Results**:
- ✅ Confirmation dialog appears:
  - "🔓 Are you sure you want to re-open this rejected task?"
  - "The technician will be notified and can resume working on it."
  - Two buttons: "Cancel" and "OK"
- ✅ After clicking "OK":
  - Success alert: "✅ Task has been re-opened!\n\nThe technician will now be able to resume working on this task.\nThe task status has been changed to "pending"."
  - Task row refreshes
  - Status badge changes from "rejected" (red) to "pending" (orange)
  - Action button changes back to "Update"

**Backend Logs**:
```
🔓 [RE-OPEN] Request received for claim: xxx
   New Status: pending
   User ID: admin_user_id
   User Role: admin | Is Admin: true
   Current Status: rejected
   Updating to: pending
✅ [RE-OPEN] Saved to database: rejected → pending
📡 [BROADCAST] Sending re-open notification to X connected admins
✅ [BROADCAST] Re-open broadcasted: xxx (rejected → pending)
```

---

### Step 6: Verify Technician App Auto-Updates
**Action**: Switch back to technician app (don't refresh)

**Expected Results**:
- ✅ Task card status automatically updates to "pending"
- ✅ Blocked message is **GONE**
- ✅ Status update buttons appear again:
  - ✅ Green "Completed" button
  - ✅ Red "Rejected" button
- ✅ Task is now **UNBLOCKED** and technician can work again

**Visual Confirmation**:
```
BEFORE Re-open:
╭─ 🔒 Task Blocked ─────────────────────────╮
│ This task has been rejected...            │
│ [🔓 Request Re-open]                      │
╰───────────────────────────────────────────╯

AFTER Re-open:
╭─ Update Status ────────────────────────────╮
│ [✅ Completed]  [❌ Rejected]              │
╰───────────────────────────────────────────╯
```

---

### Step 7: Verify Technician Can Work on Task Again
**Action**: Click "Completed" button to mark task as done

**Expected Results**:
- ✅ Task status changes to "completed"
- ✅ Success notification appears
- ✅ Admin dashboard refreshes and shows "completed" status

**Console Output**:
```
✅ Task saved and marked as completed successfully
```

---

## Key Verification Points

### ✅ Blocking Logic Works
- [ ] Rejected status blocks task editing
- [ ] Blocked message displays correctly
- [ ] Only "Request Re-open" button available

### ✅ Re-open Request Works
- [ ] "Request Re-open" button is functional
- [ ] Admin sees "Re-open" button for rejected tasks
- [ ] Non-rejected tasks still show "Update" button

### ✅ Admin Re-open Works
- [ ] Status transitions: rejected → pending
- [ ] WebSocket broadcasts status change
- [ ] Technician app auto-updates

### ✅ Unblocking Works
- [ ] Blocked message disappears
- [ ] Blocked buttons reappear
- [ ] Technician can update status again

---

## Error Scenarios

### Scenario 1: Admin tries to re-open non-rejected task
**Expected**: Error message "Cannot re-open a task with status 'pending'. Only rejected tasks can be re-opened."

### Scenario 2: Technician tries to re-open (not authorized)
**Expected**: Backend returns 403 Forbidden

### Scenario 3: Task not found when re-opening
**Expected**: Error message "Trip claim not found"

---

## Backend Endpoints Reference

### Status Update (Technician or Admin)
```
PUT /api/admin/trip-claim/{claimId}/status
Body: { status: "pending" | "on-progress" | "rejected" | "completed" }
Response: { success: true, data: claim }
```

### Re-open Task (Admin only)
```
PUT /api/admin/trip-claim/{claimId}/reopen
Body: { status: "pending" }
Response: { success: true, data: claim, message: "Trip claim has been re-opened successfully" }
Authorization: Bearer token (admin/supervisor only)
```

---

## WebSocket Events

### Status Update Broadcast
```javascript
socket.on('claim:statusUpdated', (data) => {
  claimId: xxx
  oldStatus: "rejected"
  newStatus: "pending"
  claim: { full claim object }
})
```

---

## Troubleshooting

### Issue: Re-open button doesn't appear in admin dashboard
- **Check**: Refresh admin dashboard (Ctrl+F5)
- **Check**: Backend running and WebSocket connected
- **Check**: Task status is actually "rejected" (check database)
- **Log**: Open browser console and check for fetch errors

### Issue: Task doesn't unblock after admin re-opens
- **Check**: WebSocket is connected (look for `✅ [WEBSOCKET] Connected` in console)
- **Check**: Refresh technician app to see updated status
- **Check**: Backend logs show `[BROADCAST]` message

### Issue: "Request Re-open" button not working
- **Check**: Backend endpoint `/reopen` is implemented
- **Check**: Authorization token is valid
- **Check**: Task status is "rejected" before requesting re-open
- **Log**: Check browser console network tab for failed fetches

---

## Success Criteria ✅

The workflow is **COMPLETE** when:

1. ✅ Technician can reject a task
2. ✅ Task becomes blocked (no status update buttons)
3. ✅ Blocked message with "Request Re-open" button appears
4. ✅ Admin sees "Re-open" button (not "Update")
5. ✅ Admin can re-open the task with confirmation
6. ✅ Task status changes: rejected → pending
7. ✅ Technician app auto-updates without refresh
8. ✅ Blocked UI disappears from technician app
9. ✅ Technician can update task status again
10. ✅ All WebSocket broadcasts work correctly

---

## Implementation Files Modified

### Frontend (Technician App)
- [technician_landing_page.dart](lib/pages/technician/technician_landing_page.dart)
  - Added `_isRequestingReopen` state variable
  - Updated UI to show "Request Re-open" button when status is "rejected"
  - Implemented `_requestTaskReopen()` method

### Backend
- [admin.html](backend/public/admin.html)
  - Added conditional logic to show "🔓 Re-open" button for rejected tasks
  - Implemented `reopenTask(claimId)` function
  
- [routes/tripClaims.js](backend/routes/tripClaims.js)
  - Added `PUT /:id/reopen` endpoint
  - Validates admin authorization
  - Broadcasts status update via WebSocket
  - With comprehensive logging

---

## WebSocket Verification

### Connect to WebSocket in Browser Console
```javascript
const socket = io();
socket.on('claim:statusUpdated', (data) => {
  console.log('📌 Status update received:', data);
});
```

---

## Expected Workflow Sequence

```
Technician App    |    Backend API    |    Admin Dashboard    |    WebSocket
─────────────────────────────────────────────────────────────────────────────

[Click Rejected]  ──→  [PUT /status]
                          ↓
                    [Update DB]
                          ↓
                    [BROADCAST]  ──────→  [Receive Update]
                                                 ↓
                                          [Show Re-open btn]

                                        [Click Re-open]  ──→  [PUT /reopen]
                                                                   ↓
                                                            [Update DB]
                                                                   ↓
                                                            [BROADCAST]  ──→  [Receive Update]
                                                                                      ↓
                                                                            [Auto-update UI]
```

---

**Last Updated**: January 2025
**Status**: ✅ Ready for Testing
