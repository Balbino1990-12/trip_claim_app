# PowerShell Script to Test Technician Tasks Endpoint
# This script will help diagnose why tasks aren't appearing

$BACKEND_URL = "http://10.91.220.92:5000/api"
$TECHNICIAN_PHONE = "your_technician_phone"  # Change this to your technician's phone
$PASSWORD = "your_password"  # Change this to your password

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Technician Tasks Diagnostic Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if backend is reachable
Write-Host "Step 1: Checking backend connectivity..." -ForegroundColor Yellow
try {
    $healthCheck = Invoke-WebRequest -Uri "$BACKEND_URL/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ Backend is reachable" -ForegroundColor Green
} catch {
    Write-Host "❌ Backend is NOT reachable at $BACKEND_URL" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible solutions:" -ForegroundColor Yellow
    Write-Host "   1. Check if backend is running"
    Write-Host "   2. Check if correct IP address is being used"
    Write-Host "   3. Check firewall/network connectivity"
    exit 1
}

Write-Host ""
Write-Host "Step 2: Logging in as technician..." -ForegroundColor Yellow

# Step 2: Login to get JWT token
try {
    $loginBody = @{
        identifier = $TECHNICIAN_PHONE
        password = $PASSWORD
    } | ConvertTo-Json

    Write-Host "   Phone: $TECHNICIAN_PHONE" -ForegroundColor Cyan
    Write-Host "   Sending login request..." -ForegroundColor Cyan

    $loginResponse = Invoke-WebRequest -Uri "$BACKEND_URL/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -TimeoutSec 10

    if ($loginResponse.StatusCode -eq 200) {
        $loginData = $loginResponse.Content | ConvertFrom-Json
        $token = $loginData.data.token
        
        if (-not $token) {
            Write-Host "❌ Login failed: No token returned" -ForegroundColor Red
            Write-Host "   Response: $($loginData)" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✅ Login successful" -ForegroundColor Green
        Write-Host "   Token: $($token.Substring(0, 20))..." -ForegroundColor Cyan
        
        # Extract technician ID if available
        if ($loginData.data.id) {
            Write-Host "   Technician ID: $($loginData.data.id)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "❌ Login failed with status $($loginResponse.StatusCode)" -ForegroundColor Red
        Write-Host "   Response: $($loginResponse.Content)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Login request failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Testing /technician/stats endpoint..." -ForegroundColor Yellow

# Step 3: Test stats endpoint
try {
    $statsResponse = Invoke-WebRequest -Uri "$BACKEND_URL/technician/stats" `
        -Method GET `
        -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } `
        -TimeoutSec 10

    if ($statsResponse.StatusCode -eq 200) {
        $statsData = $statsResponse.Content | ConvertFrom-Json
        Write-Host "✅ Stats endpoint working" -ForegroundColor Green
        Write-Host "   Pending Tasks: $($statsData.pendingTasks)" -ForegroundColor Cyan
        Write-Host "   Completed Tasks: $($statsData.completedTasks)" -ForegroundColor Cyan
        Write-Host "   In Progress Tasks: $($statsData.inProgressTasks)" -ForegroundColor Cyan
        Write-Host "   Rating: $($statsData.rating)" -ForegroundColor Cyan
    } else {
        Write-Host "❌ Stats endpoint returned $($statsResponse.StatusCode)" -ForegroundColor Red
        Write-Host "   Response: $($statsResponse.Content)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Stats endpoint failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 4: Testing /technician/tasks endpoint..." -ForegroundColor Yellow

# Step 4: Test tasks endpoint
try {
    $tasksResponse = Invoke-WebRequest -Uri "$BACKEND_URL/technician/tasks" `
        -Method GET `
        -Headers @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        } `
        -TimeoutSec 10

    if ($tasksResponse.StatusCode -eq 200) {
        $tasksData = $tasksResponse.Content | ConvertFrom-Json
        
        # Handle different response formats
        $taskList = $null
        if ($tasksData -is [System.Object[]] -or $tasksData -is [System.Array]) {
            $taskList = $tasksData
        } elseif ($tasksData.data -is [System.Object[]] -or $tasksData.data -is [System.Array]) {
            $taskList = $tasksData.data
        } elseif ($tasksData.tasks -is [System.Object[]] -or $tasksData.tasks -is [System.Array]) {
            $taskList = $tasksData.tasks
        }
        
        if ($taskList) {
            Write-Host "✅ Tasks endpoint working" -ForegroundColor Green
            Write-Host "   Total Tasks: $($taskList.Count)" -ForegroundColor Cyan
            
            if ($taskList.Count -gt 0) {
                Write-Host ""
                Write-Host "   Task Details:" -ForegroundColor Yellow
                for ($i = 0; $i -lt [Math]::Min(3, $taskList.Count); $i++) {
                    $task = $taskList[$i]
                    Write-Host "   Task $(($i+1)):" -ForegroundColor Cyan
                    Write-Host "      ID: $($task.id)" 
                    Write-Host "      Title: $($task.title)" 
                    Write-Host "      Status: $($task.status)" 
                    Write-Host "      Location: $($task.location)" 
                }
            } else {
                Write-Host "   ⚠️  NO TASKS RETURNED!" -ForegroundColor Yellow
                Write-Host "   This means:" -ForegroundColor Red
                Write-Host "      1. No tasks assigned to this technician in database"
                Write-Host "      2. All tasks may be completed/archived"
                Write-Host "      3. Check tasks table for this technician_id"
            }
        } else {
            Write-Host "❌ Unexpected response format" -ForegroundColor Red
            Write-Host "   Response: $($tasksResponse.Content)" -ForegroundColor Red
        }
    } elseif ($tasksResponse.StatusCode -eq 404) {
        Write-Host "❌ Tasks endpoint not found (404)" -ForegroundColor Red
        Write-Host "   Backend may not have /technician/tasks endpoint implemented" -ForegroundColor Red
    } elseif ($tasksResponse.StatusCode -eq 401) {
        Write-Host "❌ Unauthorized (401)" -ForegroundColor Red
        Write-Host "   Token may be invalid or expired" -ForegroundColor Red
    } else {
        Write-Host "❌ Tasks endpoint returned $($tasksResponse.StatusCode)" -ForegroundColor Red
        Write-Host "   Response: $($tasksResponse.Content)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Tasks endpoint failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Diagnostic Complete" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
