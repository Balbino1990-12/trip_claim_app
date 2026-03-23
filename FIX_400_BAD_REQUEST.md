# 400 Bad Request Error - Diagnostic Guide

**Error:** `❌ Failed to load tasks: 400`  
**Cause:** Backend rejected the request but it reached the server  
**Status:** Fixable - need to identify the exact issue

---

## 🔍 Step 1: Check Console Output

When you see the error in browser console (F12), look for these details printed:

```
❌ Bad Request (400): Backend rejected the request
  URL: http://10.91.220.92:5000/api/technician/tasks
   Headers: {Content-Type: application/json, ...}
   Response: {"error": "..."}
```

**Copy the exact response message** - this tells us what's wrong.

---

## 🚀 Step 2: Test Different Endpoint Paths

Try these curl commands to find the correct endpoint:

### Option A: Current Path
```powershell
$token = "YOUR_JWT_TOKEN_HERE"
$headers = @{"Authorization" = "Bearer $token"}

# Current path (what we're trying)
curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers $headers

# Check status code and response
```

### Option B: Alternative Paths
If 400, try these alternatives:

```powershell
# Without /api prefix (if baseUrl already includes it)
curl -X GET http://10.91.220.92:5000/technician/tasks `
  -Headers $headers

# Different path
curl -X GET http://10.91.220.92:5000/api/tasks `
  -Headers $headers

# With /api/v1
curl -X GET http://10.91.220.92:5000/api/v1/technician/tasks `
  -Headers $headers

# Direct /tasks
curl -X GET http://10.91.220.92:5000/tasks `
  -Headers $headers
```

---

## 📝 Step 3: Common Causes of 400 Error

### **Cause 1: Wrong Endpoint Path**
❌ Backend doesn't have `/api/technician/tasks` endpoint

**Solution:**
- Check backend route definitions
- Find the correct path from backend documentation
- Update `getAssignedTasks()` method

### **Cause 2: Missing Query Parameters**
❌ Backend requires query parameters that we're not sending

**Solution:**
- Check backend route handler
- See if it needs: `?status=`, `?limit=`, `?technicianId=`, etc.

### **Cause 3: Wrong Request Body**
For GET requests this is unlikely, but if backend expects POST:

```dart
// Change from GET to POST
final response = await http.post(
  uri,
  headers: _getHeaders(),
  body: jsonEncode({}),
);
```

### **Cause 4: Missing Required Headers**
❌ Backend might require additional headers

**Solution:**
Check if need:
- `Accept: application/json`
- Custom headers like `X-API-Key`
- `X-User-ID`
- `X-Tenant-ID`

###**Cause 5: Token Format Wrong**
❌ Authorization header format incorrect

**Solution:**
Ensure header is exactly:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiI...
```
(with space between `Bearer` and token)

---

## 🔧 Step 4: Backend Investigation

### Check Backend Logs
Look for error message like:
```
GET /api/technician/tasks - 400
Error: ...
```

### Common Backend Errors:
- `"Invalid user ID"` → User not found
- `"Technician ID required"` → Need to extract from token
- `"Missing authorization"` → Token not reaching backend
- `"Route not found"` → Wrong endpoint path

---

## ✅ Step 5: Fix the Code

Once you identify the issue, update `lib/services/technician_service.dart`:

### If endpoint path is wrong:
```dart
// Line ~171
final uri = Uri.parse('$_baseUrl/THE_CORRECT_PATH').replace(
  queryParameters: queryParams.isNotEmpty ? queryParams : null,
);
```

### If need to add query parameters:
```dart
final queryParams = <String, String>{};
queryParams['status'] = status ?? 'all';
queryParams['limit'] = limit?.toString() ?? '50';
// Add any other required params
```

### If need additional headers:
```dart
static Map<String, String> _getHeaders() {
  final headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-Custom-Header': 'value',  // Add here
  };
  // ... rest of method
}
```

---

## 📊 Troubleshooting Flowchart

```
400 Error?
   ↓
Check console output for error message
   ↓
   ├─ If "route not found" → Endpoint path wrong
   │   └─ Try alternative paths (see Step 2)
   │
   ├─ If "parameter required" → Missing query param
   │   └─ Add required parameter to request
   │
   ├─ If "invalid token" → Authentication wrong
   │   └─ Check token is valid, not expired
   │
   ├─ If "invalid user" → User issues
   │   └─ Verify user exists and has role
   │
   └─ Other error → Check backend logs
       └─ See exact error message
```

---

## 🧪 Test Endpoint Directly

Before debugging code, test the endpoint works at all:

```powershell
# 1. Get valid token
$login = curl -X POST http://10.91.220.92:5000/api/login `
  -ContentType "application/json" `
  -Body '{"username":"Balbino","password":"password"}' | ConvertFrom-Json

$token = $login.token

# 2. Test various endpoints
"Testing /api/technician/tasks..." 
curl -X GET http://10.91.220.92:5000/api/technician/tasks `
  -Headers @{"Authorization" = "Bearer $token"} | ConvertTo-Json

"Testing /technician/tasks..."
curl -X GET http://10.91.220.92:5000/technician/tasks `
  -Headers @{"Authorization" = "Bearer $token"} | ConvertTo-Json

"Testing /api/tasks..."
curl -X GET http://10.91.220.92:5000/api/tasks `
  -Headers @{"Authorization" = "Bearer $token"} | ConvertTo-Json
```

---

## 💡 Quick Fixes to Try

### Fix 1: Check if Backend Path Includes `/api`
If backend routes are defined as `/api/technician/tasks`, then:
- Current code: `$_baseUrl/technician/tasks` → `http://.../api/technician/tasks` ✅

This is correct. If getting 400, issue is elsewhere.

### Fix 2: Try Without `/api` in Endpoint
Edit: `lib/services/technician_service.dart` line ~171

```dart
// BEFORE:
final uri = Uri.parse('$_baseUrl/technician/tasks')

// TRY:
final uri = Uri.parse('${ApiService.baseUrl.replaceAll('/api', '')}/api/technician/tasks')
```

### Fix 3: Add Debug to See Exact Error
```dart
print('📥 Response Body: ${response.body}');
try {
  final json = jsonDecode(response.body);
  print('Error details: $json');
} catch (e) {
  print('Response is not JSON: ${response.body}');
}
```

---

## 🆘 If Still Not Working

1. **Check backend is running**: `curl http://10.91.220.92:5000/api/health`
2. **Check backend route exists**: Search backend code for `/technician/tasks` or `/tasks`
3. **Check backend logs**: Look for 400 error details
4. **Try curl with same headers**: Ensure curl works, then we know code is wrong
5. **Check network**: Verify connection to backend

---

**Next Action:**
1. When you see the 400 error, copy the entire error message
2. Share it with me or check backend logs
3. I'll help identify the exact cause
4. Fix the endpoint path or parameters accordingly

