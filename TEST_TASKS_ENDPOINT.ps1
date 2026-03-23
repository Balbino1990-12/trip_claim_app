# =================================================================
# TECHNICIAN TASKS BACKEND TEST SCRIPT
# =================================================================
# This script tests the /api/technician/tasks endpoint directly
# Run this in PowerShell to diagnose why tasks aren't showing
# =================================================================

# ⚙️ CONFIGURATION - UPDATE THESE VALUES
$BACKEND_URL = "http://10.91.220.92:5000"  # Your backend URL
$TECHNICIAN_USERNAME = "technician_user"   # Your technician username
$TECHNICIAN_PASSWORD = "password"           # Your technician password

Write-Host ""
Write-Host "=================================================="
Write-Host "TECHNICIAN TASKS BACKEND DIAGNOSTIC TEST"
Write-Host "=================================================="
Write-Host ""

# Step 1: Test Backend Connectivity
Write-Host "📡 Step 1: Testing Backend Connectivity..."
Write-Host "URL: $BACKEND_URL/api/health"

try {
    $healthResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/health" `
        -Method GET `
        -ErrorAction Stop `
        -TimeoutSec 5

    Write-Host "✅ Backend is running (Status: $($healthResponse.StatusCode))"
    Write-Host ""
} catch {
    Write-Host "❌ Backend is NOT responding!"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "💡 Fix: Make sure backend server is running at $BACKEND_URL"
    exit 1
}

# Step 2: Login and Get JWT Token
Write-Host "🔐 Step 2: Logging in as technician..."
Write-Host "URL: $BACKEND_URL/api/login"
Write-Host "Username: $TECHNICIAN_USERNAME"
Write-Host ""

try {
    $loginBody = @{
        username = $TECHNICIAN_USERNAME
        password = $TECHNICIAN_PASSWORD
    } | ConvertTo-Json

    $loginResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -ErrorAction Stop `
        -TimeoutSec 10

    $loginData = $loginResponse.Content | ConvertFrom-Json

    if ($loginData.token) {
        $token = $loginData.token
        $tokenPreview = $token.Substring(0, 30) + "..."
        Write-Host "✅ Login successful!"
        Write-Host "Token: $tokenPreview (length: $($token.Length))"
        Write-Host ""
    } else {
        Write-Host "❌ No token in response"
        Write-Host "Response: $($loginResponse.Content)"
        Write-Host ""
        exit 1
    }

} catch {
    Write-Host "❌ Login failed!"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "💡 Fix: Check username/password and make sure backend is running"
    exit 1
}

# Step 3: Test Tasks Endpoint
Write-Host "📋 Step 3: Fetching Tasks..."
Write-Host "URL: $BACKEND_URL/api/technician/tasks"
Write-Host "Authorization: Bearer $tokenPreview"
Write-Host ""

try {
    $headers = @{
        'Authorization' = "Bearer $token"
        'Content-Type' = 'application/json'
    }

    $tasksResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/technician/tasks" `
        -Method GET `
        -Headers $headers `
        -ErrorAction Stop `
        -TimeoutSec 10

    $tasksData = $tasksResponse.Content | ConvertFrom-Json

    Write-Host "✅ API Response Received (Status: $($tasksResponse.StatusCode))"
    Write-Host "Response Content:"
    Write-Host ""
    $tasksData | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""

    # Analyze Response
    if ($tasksData.data) {
        $taskCount = @($tasksData.data).Count
        Write-Host "✅ Tasks found: $taskCount"
        Write-Host ""

        if ($taskCount -gt 0) {
            Write-Host "📌 First Task Details:"
            $firstTask = $tasksData.data[0]
            Write-Host "   ID: $($firstTask.id)"
            Write-Host "   Title: $($firstTask.title)"
            Write-Host "   Status: $($firstTask.status)"
            Write-Host "   Client: $($firstTask.clientName)"
            Write-Host ""
        } else {
            Write-Host "⚠️  No tasks returned from backend!"
            Write-Host ""
            Write-Host "💡 Possible causes:"
            Write-Host "  1. No tasks assigned to this technician in database"
            Write-Host "  2. Tasks exist but technician_id doesn't match JWT"
            Write-Host "  3. Database query issue in backend"
            Write-Host ""
        }
    } else {
        Write-Host "❌ Unexpected response format"
        Write-Host "Expected 'data' field but got: $($tasksData | ConvertTo-Json)"
        Write-Host ""
    }

} catch {
    Write-Host "❌ Failed to fetch tasks!"
    Write-Host "Error: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)"
    
    if ($_.Exception.Response.StatusCode -eq "Unauthorized") {
        Write-Host ""
        Write-Host "💡 Fix: Token might be invalid or expired. Try logging in again."
    }

    exit 1
}

# Step 4: Test Stats Endpoint (for comparison)
Write-Host "📊 Step 4: Fetching Technician Stats (for comparison)..."
Write-Host "URL: $BACKEND_URL/api/technician/stats"
Write-Host ""

try {
    $statsResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/technician/stats" `
        -Method GET `
        -Headers $headers `
        -ErrorAction Stop `
        -TimeoutSec 10

    $statsData = $statsResponse.Content | ConvertFrom-Json

    Write-Host "✅ Stats Response:"
    $statsData | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host ""

} catch {
    Write-Host "⚠️  Could not fetch stats: $($_.Exception.Message)"
    Write-Host ""
}

# Summary
Write-Host "=================================================="
Write-Host "DIAGNOSTIC SUMMARY"
Write-Host "=================================================="
Write-Host ""

if ($taskCount -gt 0) {
    Write-Host "✅ BACKEND IS WORKING CORRECTLY"
    Write-Host "Tasks are being returned. If Flutter app still shows 0 tasks,"
    Write-Host "the issue is in the Flutter client code."
    Write-Host ""
} else {
    Write-Host "⚠️  BACKEND RETURNS EMPTY TASK LIST"
    Write-Host ""
    Write-Host "NEXT STEPS:"
    Write-Host "1. Check database: SELECT * FROM trip_claims WHERE technician_id = YOUR_ID"
    Write-Host "2. Verify tasks exist and have your technician_id"
    Write-Host "3. Insert test tasks if database is empty"
    Write-Host "4. See DATABASE_TASK_ASSIGNMENT_GUIDE.md for detailed steps"
    Write-Host ""
}

Write-Host "Done!"
