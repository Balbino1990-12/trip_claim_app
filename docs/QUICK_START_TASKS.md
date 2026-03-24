# ⚡ Quick Start - Task Display Verification

**Status:** ✅ Implementation Complete - Ready to Test

---

## 🚀 Quick Test (2 minutes)

### 1️⃣ Run Automated Test
```powershell
cd "d:\2025\Trip Claim App\trip_claim_app"
.\test_tasks_display.ps1
```

**Expected output:**
```
✅ Backend is running
✅ Login successful
✅ Tasks fetched: count=5
   Task 1: Road damage assessment (pending, high)
   Task 2: Pothole repair (pending, medium)
   ... and 3 more tasks
```

If you see this → **Go to Step 2**  
If you see errors → **Check [VERIFY_TASKS_DISPLAY.md](VERIFY_TASKS_DISPLAY.md)**

---

### 2️⃣ Start Flutter App
```powershell
cd "d:\2025\Trip Claim App\trip_claim_app"
flutter run -d chrome
```

Wait for: `Flutter run key commands.`

---

### 3️⃣ Login
- Username: `Balbino`
- Password: `password`

---

### 4️⃣ View Dashboard
- App automatically navigates to Technician Landing Page
- Scroll down to "Today's Assigned Tasks" section
- **Should see 5 task cards displayed** ✅

---

## ✅ What You Should See

### Header Section (Top)
```
🔧 EDTL Technician Service Portal     🔔 5
👋 Welcome back! Ready to help our customers?
```
Notice the badge showing `5` tasks assigned

### Main Dashboard (Below)
```
TODAY'S ASSIGNED TASKS

┌─────────────────────────────────────┐
│ Road Damage Assessment         high │
│ Main Street & 5th Ave         📍    │
│ Status: pending   Claim: 001        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Pothole Repair               medium │
│ Oak Road, Downtown            📍    │
│ Status: pending   Claim: 002        │
└─────────────────────────────────────┘

... (3 more tasks)
```

### Diagnostics Panel (Scroll down in dashboard)
```
✅ Connected
📊 Tasks: 5  ⏳ Pending: 3
```

---

## 🔴 If Tasks Don't Appear

### 1. Check Backend is Running
```powershell
curl http://10.91.220.92:5000/api/health
```
Should return: `{"status": "ok"}`

If error → **Start the backend first**

### 2. Check Database Has Tasks
Run in SQL client:
```sql
SELECT COUNT(*) FROM trip_claims WHERE technician_id = 1;
```

Should return: `5`

If 0 → **Run SQL to insert test tasks:**
```sql
-- See INSERT_TEST_TASKS_FOR_DISPLAY.sql
```

### 3. Open Browser Console (F12)
Look for error messages starting with ❌

Common errors:
- `401 Unauthorized` → Re-login
- `404 Not Found` → Backend endpoint missing
- `Connection refused` → Backend not running

---

## 📍 Key Files

| What | Where |
|------|-------|
| **Display Code** | [lib/pages/technician/technician_landing_page.dart#L1070](lib/pages/technician/technician_landing_page.dart#L1070) |
| **API Service** | [lib/services/technician_service.dart#L161](lib/services/technician_service.dart#L161) |
| **Test Script** | [test_tasks_display.ps1](test_tasks_display.ps1) |
| **Test Data SQL** | [INSERT_TEST_TASKS_FOR_DISPLAY.sql](INSERT_TEST_TASKS_FOR_DISPLAY.sql) |
| **Full Docs** | [VERIFY_TASKS_DISPLAY.md](VERIFY_TASKS_DISPLAY.md) |

---

## ✨ Expected Flow

```
1. Run test_tasks_display.ps1
   ↓ ✅ Confirms backend + API working
   
2. flutter run -d chrome
   ↓ ✅ App loads and compiles
   
3. Login as Balbino
   ↓ ✅ JWT token set
   
4. View dashboard
   ↓ ✅ Tasks appear on screen
   
5. Every 5 seconds: Auto-refresh
   ↓ ✅ Tasks are live
```

---

## 📊 Real-time Features

### Auto-Refresh
- Tasks refresh every 5 seconds automatically
- Check browser console: Look for `🔄 Real-time refresh...` logs

### Notification Badge
- Shows total task count (upper right: 🔔 5)
- Updates when new tasks are assigned

### Manual Refresh
- Click 🔄 button in Diagnostics Panel
- Tasks will reload immediately

---

## 💡 Pro Tips

### View Full Debug Info
Press F12 → Console tab → Scroll up  
Look for logs starting with `✅`, `❌`, `📌`

### Test API Directly
```powershell
# From test_tasks_display.ps1 output
curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers @{"Authorization" = "Bearer <token_from_login>"}
```

### Check Task Count Programmatically
```powershell
# Run test script
.\test_tasks_display.ps1 | Select-String "Tasks Count"
```

---

## ⏱️ Expected Times

| Step | Time | Status |
|------|------|--------|
| Run test_tasks_display.ps1 | <10s | ✅ Fast |
| flutter run first time | 2-3 min | ⏳ Normal |
| flutter run thereafter | 30-60s | ✅ Fast |
| Task fetch | <1s | ✅ Fast |
| Dashboard load | 1-2s | ✅ Normal |

---

## ❓ FAQ

**Q: Where do I insert test tasks?**  
A: Run `INSERT_TEST_TASKS_FOR_DISPLAY.sql` in your SQL client

**Q: How do I know if it worked?**  
A: You should see 5 task cards on the dashboard

**Q: Tasks appear but look wrong?**  
A: Check browser console (F12) for parsing errors

**Q: How often do tasks refresh?**  
A: Every 5 seconds automatically, or click refresh button

**Q: How do I test real-time notifications?**  
A: Update a task status in backend, watch dashboard for changes

---

## 🎯 Success Criteria

✅ Test script shows: Tasks fetched: count=5  
✅ App compiles without errors  
✅ Login succeeds  
✅ Dashboard shows "Today's Assigned Tasks" section  
✅ 5 task cards visible with correct data  
✅ Notification badge shows 🔔 5  
✅ Diagnostics panel shows ✅ Connected, 📊 Tasks: 5

---

## 🚨 Emergency Troubleshooting

**App won't compile:**
```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

**Chrome won't load:**
```powershell
flutter run -d chrome -v
# Kill any running Chrome instances
```

**Tasks still not appearing after all steps:**
1. Check browser console (F12) for error message
2. Copy error and check [VERIFY_TASKS_DISPLAY.md](VERIFY_TASKS_DISPLAY.md)
3. Follow troubleshooting step for your specific error

---

**All infrastructure is in place. Just test it! 🚀**

See [VERIFY_TASKS_DISPLAY.md](VERIFY_TASKS_DISPLAY.md) for detailed documentation.
