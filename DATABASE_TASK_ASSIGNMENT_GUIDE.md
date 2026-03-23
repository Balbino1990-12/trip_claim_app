# Database Task Assignment Diagnostic Guide

## 🔍 Issue: No Tasks Returned from Backend

When the diagnostics panel shows "✅ Connected" but "📊 Tasks: 0", the problem is likely in the database.

---

## ✅ Step 1: Verify Tasks Exist in Database

### MySQL Command to Check
```sql
-- First, check if trip_claims table exists and has data
SELECT COUNT(*) as total_tasks FROM trip_claims;

-- Check what technicians exist
SELECT ID, user_type FROM users WHERE user_type = 'technician';

-- Look for assigned tasks
SELECT id, technician_id, customer_name, status FROM trip_claims LIMIT 10;
```

---

## ✅ Step 2: Verify Your Logged-in Technician's ID

### From Flask/Django Backend Logs
When you log in, the backend creates a JWT token. Look for logs showing:
```
User logged in: id=123, user_type=technician
JWT Token created with user_id: 123
```

Note down your **Technician ID** (example: 123)

### From Database
```sql
-- Find your technician user
SELECT id FROM users WHERE username = 'your_username' AND user_type = 'technician';

-- Example: If your ID is 5, check tasks assigned to you
SELECT * FROM trip_claims WHERE technician_id = 5;
```

---

## ✅ Step 3: Create Test Tasks in Database

### If No Tasks Exist, Insert Some
```sql
-- Get a technician ID (replace 5 with your actual ID)
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  status,
  location,
  description,
  created_at,
  updated_at
) VALUES 
(
  'claim_test_001',
  5,
  'Test Customer',
  '+1234567890',
  'pending',
  'Main Street, City',
  'Test task - Road damage assessment',
  NOW(),
  NOW()
),
(
  'claim_test_002',
  5,
  'Another Customer',
  '+0987654321',
  'pending',
  'Oak Road, City',
  'Test task - Pothole repair',
  NOW(),
  NOW()
);

-- Verify they were inserted
SELECT * FROM trip_claims WHERE technician_id = 5;
```

---

## ✅ Step 4: Test the Backend Endpoint Directly

### Using PowerShell (Windows)
```powershell
# 1. First, login to get JWT token
$loginResponse = Invoke-WebRequest -Uri "http://your-backend:5000/api/login" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"username":"technician_user","password":"password"}'

$loginData = $loginResponse.Content | ConvertFrom-Json
$token = $loginData.token

# 2. Extract the token
$token

# 3. Now test the tasks endpoint
$headers = @{
  'Authorization' = "Bearer $token"
}

$response = Invoke-WebRequest -Uri "http://your-backend:5000/api/technician/tasks" `
  -Headers $headers `
  -Method GET

$response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

### Using cURL (macOS/Linux or Git Bash)
```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:5000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"technician_user","password":"password"}' | jq -r '.token')

echo "Token: $TOKEN"

# 2. Fetch tasks
curl -s -X GET http://localhost:5000/api/technician/tasks \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

---

## ✅ Step 5: Check JWT Token Claims

If tasks aren't returned even though they exist in the database, the JWT token might be wrong.

### Decode JWT Token
Go to **https://jwt.io/** and paste your token. Look for:
- `user_id` or `sub` field → Should match technician ID in database
- `user_type` field → Should be `"technician"`
- `exp` field → Should be in the future (not expired)

### Example Decoded JWT
```json
{
  "user_id": 5,
  "user_type": "technician",
  "username": "tech_user",
  "exp": 1745193600,  // Some future timestamp
  "iat": 1739470800
}
```

---

## ✅ Step 6: Check Backend Logs

### Look in Backend Logs For
```
📡 GET /api/technician/tasks
🔐 Token validation: SUCCESS
⚙️ Extracting user_id from token: 5
🔍 Querying tasks WHERE technician_id = 5
📊 Found 2 tasks
📤 Response sent: [task1, task2]
```

Or if there's an error:
```
❌ Authentication failed: Invalid token
❌ Token expired
❌ User ID not found in token
```

---

## 📋 Verification Checklist

- [ ] Tasks exist in `trip_claims` table
- [ ] Tasks have `technician_id` set to your technician's ID
- [ ] Tasks have status like `'pending'` (not blank/NULL)
- [ ] JWT token decodes correctly at jwt.io
- [ ] JWT token contains your technician ID
- [ ] JWT token is not expired
- [ ] Backend `/api/technician/tasks` endpoint returns data when tested with cURL
- [ ] Flutter app shows tasks after backend is fixed

---

## 🛠️ How to Fix

### If Tasks Exist But Still Not Showing:
1. **Stop Flutter app** (Press `q` in terminal)
2. **Check backend is running** at `http://your-backend:5000`
3. **Test endpoint with cURL** (Step 4 above)
4. **Check backend logs** for error messages
5. **Restart backend server**
6. **Hot Reload Flutter app** (Press `r` in Flutter terminal)

### If No Tasks in Database:
1. **Use SQL to insert test tasks** (Step 3 above)
2. Make sure to assign them to YOUR technician ID
3. Test backend endpoint
4. Hot Reload Flutter app

---

## 🚨 Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| "✅ Connected" but "📊 Tasks: 0" | No tasks assigned in DB | Insert test tasks with your technician_id |
| "❌ Error" in diagnostics | Token invalid or format wrong | Logout and login again |
| "⏳ Loading" forever | Backend endpoint timing out | Check backend is running |
| JWT shows different `user_id` | Backend using wrong ID source | Check backend token creation code |
| Tasks show in cURL but not Flutter | JSON parsing issue in client | Check Flutter console for error messages |

