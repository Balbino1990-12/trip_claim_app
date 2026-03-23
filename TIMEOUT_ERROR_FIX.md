# Timeout Error Fix - Complete Troubleshooting Guide

**Error:** `TimeoutException after 0:00:30.000000: Future not completed`  
**Status:** Updated timeout to 60 seconds + enhanced diagnostics ✅

---

## 🔍 What This Error Means

The Flutter app is trying to fetch tasks from the backend but the HTTP request is timing out. The backend is either:
1. ❌ Not running
2. ❌ Not responding to requests
3. ❌ Responding very slowly (database query is slow)
4. ❌ Network connectivity issue

---

## ✅ What I've Fixed

1. **Increased timeout from 30 to 60 seconds** - Gives backend more time to respond
2. **Added better error messages** - Shows exactly what's wrong
3. **Added helpful debugging tips** - Guides you to the solution

---

## 🚀 Step-by-Step Troubleshooting

### Step 1: Check If Backend is Running

**From Terminal:**
```powershell
curl http://10.91.220.92:5000/api/health
```

**Expected Response:**
```
StatusCode        : 200
StatusDescription : OK
```

**If Connection Refused:**
- ❌ Backend is NOT running
- ✅ Solution: Start your Node.js/Express backend server

**If No Response (hangs):**
- ⚠️ Backend might be stuck
- ✅ Solution: Kill and restart the backend

---

### Step 2: Check Backend Is Responding to Auth

**From Terminal:**
```powershell
# Login to get token
$response = curl -X POST http://10.91.220.92:5000/api/login `
  -ContentType "application/json" `
  -Body '{"username":"Balbino","password":"password"}' | ConvertFrom-Json

$token = $response.token
Write-Host "Token: $token"
```

**Expected:**
```
Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**If Error or Timeout:**
- ❌ Backend login endpoint is not responding
- ✅ Check backend logs for errors

---

### Step 3: Test Tasks Endpoint Directly

**From Terminal:**
```powershell
# Get token first (from Step 2)
$token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Test tasks endpoint
$headers = @{
  "Authorization" = "Bearer $token"
}

curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers $headers
```

**Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "claim_001",
      "title": "Road damage assessment",
      ...
    }
  ]
}
```

**If Timeout (30+ seconds):**
- ⚠️ Backend is slow to respond
- Possible causes:
  - Database query is too slow
  - Backend is doing heavy processing
  - Network latency

**If Error:**
```
{"success": false, "message": "..."}
```
- Check backend logs for the error
- Verify technician user has tasks assigned

---

### Step 4: Monitor Network in Browser

1. **Open Flutter App and Login**
2. **Open Browser DevTools (F12)**
3. **Go to Network tab**
4. **Watch for request to `/api/technician/tasks`**

**Look for:**
- ✅ Status 200 → Success
- ❌ Status 404 → Endpoint doesn't exist
- ❌ Status 401 → Authentication failed
- ⏱️ Time > 30s → Timeout (now increased to 60s)

---

### Step 5: Check Backend Logs

**In your backend terminal, look for:**

```
--- GOOD SIGNS ---
✅ GET /api/technician/tasks 200 2ms
✅ Returning 5 tasks for user 1

--- BAD SIGNS ---
❌ GET /api/technician/tasks Timeout
❌ Database query took 45 seconds
❌ Error: Connection refused (database)
❌ Error: JWT token expired
```

---

## 🛠️ Solutions by Cause

### Solution 1: Backend Not Running

**Windows:**
```powershell
cd C:\path\to\backend
npm start
# Or
node server.js
```

**Mac/Linux:**
```bash
cd /path/to/backend
npm start
```

Wait for output like:
```
Server running on http://localhost:5000
```

---

### Solution 2: Backend Running But Slow

**Check Database:**
- Is database running?
- Are queries indexed properly?
- Too many records in tables?

**Quick Test:**
```bash
# In backend logs, you should see query time
# Look for: "Query executed in 234ms"
# If > 1 second, database is slow
```

**Fix:**
1. Add database indexes
2. Optimize queries
3. Reduce data in database

---

### Solution 3: Network Issue

**Test Network Connection:**
```powershell
# Check if connection is slow
Test-NetConnection -ComputerName 10.91.220.92 -Port 5000 -InformationLevel Detailed
```

**Expected:**
```
PingSucceeded : True
```

**If False:**
- Network connectivity issue
- Check firewall settings
- Check if IP/port correct

---

### Solution 4: Token Expiration

**Symptoms:**
- Backend returns 401 Unauthorized
- Logs show "Invalid token"

**Fix:**
1. Re-login in Flutter app
2. New token will be generated
3. Try again

---

## 📊 Configuration Changes Made

### In `lib/services/technician_service.dart`:

**BEFORE:**
```dart
.timeout(const Duration(seconds: 30));
```

**AFTER:**
```dart
.timeout(
  const Duration(seconds: 60),
  onTimeout: () {
    print('⏱️ REQUEST TIMEOUT: Backend did not respond within 60 seconds');
    print('💡 Possible causes:');
    print('   1. Backend is not running');
    print('   2. Backend is responding very slowly');
    print('   3. Network connectivity issue');
    print('   4. Database query is too slow');
    throw TimeoutException('Backend did not respond within 60 seconds');
  },
);
```

**Benefits:**
- ✅ 60 second timeout (was 30 seconds)
- ✅ Better error messages
- ✅ Diagnostic hints provided
- ✅ Same for both tasks and stats endpoints

---

## 🚨 Quick Fix Checklist

- [ ] Is backend running? → `curl http://10.91.220.92:5000/api/health`
- [ ] Can you login? → Test in Flutter app
- [ ] Can you hit tasks endpoint? → Use curl commands above
- [ ] Check backend logs for errors
- [ ] Verify JWT token is valid (re-login if needed)
- [ ] Check database is running
- [ ] Check network connectivity
- [ ] Try waiting for 60 seconds (new timeout)

---

## 📱 Testing in Flutter App

After starting backend:

1. **Start Flutter app:**
   ```powershell
   flutter run -d chrome
   ```

2. **Open browser console (F12)**

3. **Login as Balbino**

4. **Look for console logs:**

   **GOOD:**
   ```
   🚀 TECHNICIAN LANDING PAGE - INITIALIZING
   📊 === TECHNICIAN STATS REQUEST ===
   📥 Response Status: 200
   ✅ SUCCESS: Stats loaded successfully
   📋 === TECHNICIAN TASKS REQUEST ===
   ✅ Tasks loaded: count=5
   ```

   **BAD - Timeout:**
   ```
   ⏱️ REQUEST TIMEOUT: Backend did not respond within 60 seconds
   💡 Possible causes:
      1. Backend is not running
      2. Backend is responding very slowly
   ```

---

## 🔧 Advanced: If Still Timing Out After 60 Seconds

Your backend is VERY slow. Options:

### Option A: Increase Timeout More

In `lib/services/technician_service.dart`, change:
```dart
const Duration(seconds: 60)  // Change this number
```

To:
```dart
const Duration(seconds: 120)  // 2 minutes
```

### Option B: Optimize Backend

1. **Add database indexes:**
   ```sql
   CREATE INDEX idx_technician_id ON trip_claims(technician_id);
   ```

2. **Limit data returned:**
   ```javascript
   // In backend, add limit
   const tasks = await Task.find({technician_id}).limit(50);
   ```

3. **Cache results:**
   - Don't query database on every request
   - Cache for 5-10 seconds

---

## 📞 If Nothing Works

1. **Check backend logs** - Copy error message
2. **Verify database connection** - Can backend connect to DB?
3. **Check firewall** - Is port 5000 open?
4. **Restart everything** - Backend, database, app
5. **Check IP address** - Is `10.91.220.92:5000` correct?

---

## 🎯 Expected Next Result

After fixing:

✅ App loads without timeout  
✅ Console shows: `✅ Tasks loaded: count=X`  
✅ Dashboard displays task cards  
✅ Notification badge shows task count  
✅ Diagnostics panel shows: ✅ Connected, 📊 Tasks: 5

---

**Changes applied:** Timeout increased to 60 seconds + enhanced error messages  
**Status:** Ready to test 🚀
