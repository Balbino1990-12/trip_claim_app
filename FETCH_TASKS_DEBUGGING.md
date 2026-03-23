# 🔍 Task Fetch Debugging Checklist

## Quick Diagnosis

When tasks don't appear in the technician dashboard, work through these checks **in order**:

---

## ✅ Check 1: Are Test Tasks in the Database?

### Run This SQL Query:
```sql
-- First, find your technician ID
SELECT id, username FROM users WHERE user_type = 'technician' LIMIT 5;

-- Then check for tasks (replace 1 with your technician ID)
SELECT id, customer_name, status FROM trip_claims 
WHERE technician_id = 1 
ORDER BY created_at DESC;
```

**Expected Result:** 
- ✅ Shows 5+ test tasks OR
- ❌ Shows 0 results

**If shows 0:**
- Test tasks haven't been inserted yet
- Run `INSERT_TEST_TASKS.sql` or `INSERT_TEST_TASKS.ps1`
- Then proceed to Check 2

**If shows 5+:**
- Tasks ARE in database
- Proceed to Check 2 to test backend endpoint

---

## ✅ Check 2: Is Backend Endpoint Working?

### Run This PowerShell Command:

```powershell
# Set your credentials
$token = "YOUR_JWT_TOKEN_HERE"  # Get this from browser DevTools
$backend = "http://10.91.220.92:5000"

# Test the endpoint
$headers = @{
    'Authorization' = "Bearer $token"
}

$response = Invoke-WebRequest -Uri "$backend/api/technician/tasks" `
    -Method GET `
    -Headers $headers

$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Expected Response:**
```json
{
  "success": true,
  "data": [
    { "id": "claim_001", "customer_name": "John Doe", "status": "pending", ... },
    { "id": "claim_002", "customer_name": "Jane Smith", "status": "pending", ... }
  ]
}
```

**If data is empty []:**
- Backend is working but returning no tasks
- Go to Check 3

**If you get 401 Unauthorized:**
- JWT token is invalid/expired
- Logout and login again
- Get new token from browser

**If you get 500 error:**
- Backend has a problem
- Check backend server logs

---

## ✅ Check 3: Is JWT Token Valid?

### Get Your Token:
1. Open Flutter app in browser (Chrome DevTools)
2. Open **F12 → Application → LocalStorage**
3. Find the value for `"token"` or `"authToken"`
4. Copy the full JWT token

### Decode Token at jwt.io:
1. Go to **https://jwt.io/**
2. Paste your token in the left "Encoded" box
3. Check the right side "Decoded" section
4. Look for `user_id` or `sub` field

**Example - Should look like:**
```json
{
  "user_id": 1,
  "user_type": "technician",
  "username": "technician_user",
  "exp": 1745193600,
  "iat": 1739470800
}
```

**If user_id is different from your database technician_id:**
- This is the problem!
- Tasks are assigned to a different technician ID
- Either create tasks for this user_id OR check login logic

**If token is expired (exp < current time):**
- Logout and login again to get fresh token

---

## ✅ Check 4: Check Flutter Console Logs

### Open Browser Console:
1. Flutter app should be running in Chrome
2. Press **F12** to open DevTools
3. Click **Console** tab
4. Look for messages like:

**Good Signs:**
```
✅ Technician auth token set: abc123... (length: 256)
🔗 URL: http://10.91.220.92:5000/api/technician/tasks
📥 Response Status: 200
📝 Parsed JSON: [...]
📊 Found tasks in json.data (3 items)
✅ Tasks loaded: count=3
```

**Bad Signs:**
```
❌ Error fetching technician tasks: Error: XHR failed
📥 Response Status: 401
❌ Failed to load tasks: 401
⚠️ No "data" or "tasks" array found in response
```

**To enable more detailed logging:**
1. Search console for `"=== TECHNICIAN"` to find task fetch logs
2. Scroll up to see all the debug output

---

## ✅ Check 5: Check Diagnostics Panel in App

### In the Technician Landing Page:

Look at the **🔧 Diagnostics** panel (should be visible on page):

```
📡 API Endpoint: http://10.91.220.92:5000/api/technician/tasks
🔐 Authentication: ✅ Active
✅ Connected
📊 Tasks: 0  ← This number should be > 0
⏳ Pending: 0
```

**If "Tasks: 0":**
- Either (a) no tasks in database for this tech, or
- (b) backend returned empty, or  
- (c) JWT token doesn't match correct technician

**If "Tasks: 5":**
- Good! Tasks ARE being fetched
- Problem might be in how they're being displayed

---

## 🛠️ Troubleshooting by Symptom

| Symptom | Check | Solution |
|---------|-------|----------|
| "Tasks: 0" in diagnostics | Checks 1, 2, 3 | Insert test tasks OR fix JWT token |
| "❌ Error" in diagnostics | Check 2 | Backend endpoint not working |
| "⏳ Loading" stays forever | Check 2 | Backend timeout or offline |
| "Tasks: 5" but not displayed | Check 4 | Frontend parsing/display issue |
| 401 Unauthorized error | Check 3 | Token expired, login again |
| Backend returns empty [] | Check 3 | Task tech_id doesn't match JWT |

---

## 🚀 Quick Fix Steps

### **Step A: If No Tasks in Database**
```powershell
# Run one of these:
cd "d:\2025\Trip Claim App\trip_claim_app"
.\INSERT_TEST_TASKS.ps1
# OR use INSERT_TEST_TASKS.sql in MySQL client
```

### **Step B: If Backend Returns Empty**
1. In MySQL, run:
   ```sql
   SELECT technician_id FROM users WHERE username = 'YOUR_USERNAME';
   ```
2. Insert tasks with that exact ID using INSERT_TEST_TASKS.sql

### **Step C: If Token Invalid**
1. Click logout in Flutter app
2. Log back in
3. Check console for new token
4. Test endpoint again with new token

### **Step D: Hot Reload Flutter**
1. Go to Flutter terminal
2. Press `r` for hot reload
3. Wait for refresh to complete
4. Check dashboard again

---

## 📋 Complete Diagnostic Workflow

```
1. Stop Flutter app (Press 'q' in terminal)
   
2. Check database:
   - Run SQL query from Check 1
   - Do you see 5 test tasks? YES → Continue / NO → Insert test tasks first
   
3. Get JWT token:
   - Start Flutter app
   - Login as technician
   - Get token from localStorage
   
4. Test backend:
   - Run PowerShell command from Check 2
   - Does response have data array with tasks? YES → Continue / NO → Backend issue
   
5. Decode token:
   - Go to jwt.io
   - Paste token
   - Does user_id match technician_id? YES → Continue / NO → Wrong user or login issue
   
6. Check console logs:
   - Press F12
   - Look at console output
   - Are there error messages? YES → Fix errors / NO → Proceed
   
7. Hot reload app:
   - Press 'r' in Flutter terminal
   - Check dashboard diagnostics panel
   - Should now show tasks!
```

---

## 🆘 If Still Not Working

Share these details with debugging info:

1. **Diagnostics panel shows:**
   - API Endpoint: `___________`
   - Authentication: ✅ or ❌
   - Tasks: `__` Pending: `__`

2. **Database check result:**
   - Total tasks for your technician: `__`

3. **Backend test result:**
   - Status code: `___`
   - Response has tasks: YES / NO

4. **JWT token shows:**
   - user_id: `__`
   - user_type: `__`

5. **Browser console shows:**
   - (copy any error messages)

With this info, we can pinpoint the exact issue!

