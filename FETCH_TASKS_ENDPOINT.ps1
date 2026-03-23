# =================================================================
# FETCH TASKS FROM BACKEND ENDPOINT
# =================================================================

Write-Host ""
Write-Host "=================================================="
Write-Host "FETCH TASKS FROM BACKEND ENDPOINT"
Write-Host "=================================================="
Write-Host ""

# ⚙️  CONFIGURATION
$BACKEND_URL = "http://10.91.220.92:5000"
$TECHNICIAN_USERNAME = "Balbino"  # or whatever username
$TECHNICIAN_PASSWORD = "password"

Write-Host "Configuration:"
Write-Host "  Backend: $BACKEND_URL"
Write-Host "  Username: $TECHNICIAN_USERNAME"
Write-Host ""

# ==================== STEP 1: TEST BACKEND CONNECTION ====================

Write-Host "Step 1: Testing Backend Connection..."

try {
    $response = Invoke-WebRequest -Uri "$BACKEND_URL/api/health" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ Backend is running"
    Write-Host ""
} catch {
    Write-Host "❌ Backend is not responding at $BACKEND_URL"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    exit 1
}

# ==================== STEP 2: LOGIN AND GET TOKEN ====================

Write-Host "Step 2: Logging in to get JWT token..."

$loginBody = @{
    username = $TECHNICIAN_USERNAME
    password = $TECHNICIAN_PASSWORD
} | ConvertTo-Json

try {
    $loginResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -TimeoutSec 10 `
        -ErrorAction Stop

    $loginData = $loginResponse.Content | ConvertFrom-Json
    
    if ($loginData.token) {
        $token = $loginData.token
        $tokenPreview = if ($token.Length -gt 30) { $token.Substring(0, 30) + "..." } else { $token }
        Write-Host "✅ Login successful"
        Write-Host "   Token: $tokenPreview"
        Write-Host ""
    } else {
        Write-Host "❌ No token in login response"
        Write-Host "Response: $($loginResponse.Content)"
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host "❌ Login failed"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    exit 1
}

# ==================== STEP 3: FETCH TASKS ====================

Write-Host "Step 3: Fetching tasks from endpoint..."
Write-Host "URL: $BACKEND_URL/api/technician/tasks"
Write-Host ""

$headers = @{
    'Authorization' = "Bearer $token"
    'Content-Type' = 'application/json'
}

try {
    $tasksResponse = Invoke-WebRequest -Uri "$BACKEND_URL/api/technician/tasks" `
        -Method GET `
        -Headers $headers `
        -TimeoutSec 15 `
        -ErrorAction Stop

    Write-Host "✅ Response received (Status: $($tasksResponse.StatusCode))"
    Write-Host ""
    
    $tasksData = $tasksResponse.Content | ConvertFrom-Json
    
    Write-Host "Response Data:"
    Write-Host "═════════════════════════════════════════════════════════"
    $tasksData | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host "═════════════════════════════════════════════════════════"
    Write-Host ""
    
    # Analyze the response
    if ($tasksData.data) {
        $taskCount = @($tasksData.data).Count
        Write-Host "✅ Tasks Found: $taskCount"
        Write-Host ""
        
        if ($taskCount -gt 0) {
            Write-Host "📋 Task Details:"
            foreach ($i in 0..([Math]::Min(5, $taskCount - 1))) {
                $task = $tasksData.data[$i]
                Write-Host ""
                Write-Host "Task $($i + 1):"
                Write-Host "  - ID: $($task.id)"
                Write-Host "  - Title: $($task.title)"
                Write-Host "  - Description: $($task.description)"
                Write-Host "  - Status: $($task.status)"
                Write-Host "  - Priority: $($task.priority)"
                Write-Host "  - Location: $($task.location)"
                Write-Host "  - Customer: $($task.clientName)"
                Write-Host "  - Phone: $($task.clientPhone)"
                Write-Host "  - Created: $($task.assignedDate)"
            }
            Write-Host ""
        } else {
            Write-Host "⚠️  No tasks returned from backend"
            Write-Host ""
        }
    } else {
        Write-Host "⚠️  Unexpected response format"
        Write-Host "Expected 'data' field in response"
        Write-Host ""
    }

} catch {
    if ($_.Exception.Response.StatusCode -eq "Unauthorized") {
        Write-Host "❌ Authentication failed (401 Unauthorized)"
        Write-Host "The token may be invalid or expired"
    } else {
        Write-Host "❌ Error fetching tasks"
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)"
        Write-Host "Error: $($_.Exception.Message)"
    }
    Write-Host ""
    exit 1
}

# ==================== SUMMARY ====================

Write-Host "=================================================="
Write-Host "✅ FETCH COMPLETE"
Write-Host "=================================================="
