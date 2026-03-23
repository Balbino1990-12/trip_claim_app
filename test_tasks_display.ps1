# Test Task Display End-to-End
# This script verifies that tasks are properly fetched and displayed

param(
    [string]$BackendUrl = "http://10.91.220.92:5000",
    [string]$Username = "Balbino",
    [string]$Password = "password",
    [switch]$InsertTestData = $false
)

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Task Display Verification Script" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Backend
Write-Host "STEP 1: Checking Backend Status..." -ForegroundColor Yellow
Write-Host "─" * 60

try {
    $healthResponse = Invoke-WebRequest -Uri "$BackendUrl/api/health" -ErrorAction Stop
    Write-Host "✅ Backend is running!" -ForegroundColor Green
    Write-Host "   Status: $($healthResponse.StatusCode)" -ForegroundColor Green
    $healthJson = $healthResponse.Content | ConvertFrom-Json
    Write-Host "   Response: $($healthJson | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "❌ Backend is NOT running!" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "CRITICAL: Start the backend at $BackendUrl before running this script" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Login and Get Token
Write-Host "STEP 2: Logging in as '$Username'..." -ForegroundColor Yellow
Write-Host "─" * 60

try {
    $loginBody = @{
        username = $Username
        password = $Password
    } | ConvertTo-Json

    $loginResponse = Invoke-WebRequest -Uri "$BackendUrl/api/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -ErrorAction Stop

    $loginJson = $loginResponse.Content | ConvertFrom-Json
    
    if ($loginJson.success) {
        $token = $loginJson.token
        Write-Host "✅ Login successful!" -ForegroundColor Green
        Write-Host "   Token: $($token.Substring(0, 20))..." -ForegroundColor Green
    } else {
        Write-Host "❌ Login failed: $($loginJson.message)" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Login request failed!" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Fetch Tasks
Write-Host "STEP 3: Fetching Tasks from /api/technician/tasks..." -ForegroundColor Yellow
Write-Host "─" * 60

try {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type" = "application/json"
    }

    $tasksResponse = Invoke-WebRequest -Uri "$BackendUrl/api/technician/tasks" `
        -Headers $headers `
        -ErrorAction Stop

    $tasksJson = $tasksResponse.Content | ConvertFrom-Json
    
    Write-Host "✅ Tasks endpoint responded!" -ForegroundColor Green
    Write-Host "   Status: $($tasksResponse.StatusCode)" -ForegroundColor Green
    
    if ($tasksJson.success) {
        $tasks = $tasksJson.data
        $taskCount = $tasks.Count
        
        Write-Host "   Tasks Count: $taskCount" -ForegroundColor Green
        
        if ($taskCount -eq 0) {
            Write-Host "   ⚠️  NO TASKS FOUND!" -ForegroundColor Yellow
            Write-Host "   This means:" -ForegroundColor Yellow
            Write-Host "   - Either no tasks are assigned in database" -ForegroundColor Yellow
            Write-Host "   - Or this user ID doesn't match tasks in database" -ForegroundColor Yellow
        } else {
            Write-Host "   📋 Tasks:" -ForegroundColor Green
            
            for ($i = 0; $i -lt [Math]::Min($taskCount, 3); $i++) {
                $task = $tasks[$i]
                Write-Host ""
                Write-Host "   Task $($i+1):" -ForegroundColor Cyan
                Write-Host "     - ID: $($task.id)" -ForegroundColor Gray
                Write-Host "     - Title: $($task.title)" -ForegroundColor Gray
                Write-Host "     - Location: $($task.location)" -ForegroundColor Gray
                Write-Host "     - Status: $($task.status)" -ForegroundColor Gray
                Write-Host "     - Priority: $($task.priority)" -ForegroundColor Gray
                Write-Host "     - Client: $($task.clientName)" -ForegroundColor Gray
            }
            
            if ($taskCount -gt 3) {
                Write-Host ""
                Write-Host "   ... and $($taskCount - 3) more tasks" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "❌ API returned error: $($tasksJson.message)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Failed to fetch tasks!" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
}

Write-Host ""

# Step 4: Display Full Response
Write-Host "STEP 4: Full API Response..." -ForegroundColor Yellow
Write-Host "─" * 60
Write-Host ($tasksJson | ConvertTo-Json -Depth 10) -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Verification Summary" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$summaryItems = @()
$summaryItems += @{Status = "✅"; Item = "Backend running"; Details = "$BackendUrl" }
$summaryItems += @{Status = "✅"; Item = "Login successful"; Details = "User: $Username" }
$summaryItems += @{Status = if ($taskCount -gt 0) { "✅" } else { "⚠️" }; Item = "Tasks fetched"; Details = "Count: $taskCount" }

foreach ($item in $summaryItems) {
    Write-Host "$($item.Status) $($item.Item)" -ForegroundColor (if ($item.Status -eq "✅") { "Green" } else { "Yellow" })
    Write-Host "   $($item.Details)" -ForegroundColor Gray
}

Write-Host ""

if ($taskCount -eq 0) {
    Write-Host "⚠️  NO TASKS FOUND - NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "─" * 60
    Write-Host ""
    Write-Host "1. Check if tasks exist in database:" -ForegroundColor Yellow
    Write-Host "   SELECT * FROM trip_claims WHERE technician_id = 1;" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. If no tasks, insert test data:" -ForegroundColor Yellow
    Write-Host "   INSERT INTO trip_claims (id, technician_id, customer_name, description," -ForegroundColor Gray
    Write-Host "   description, location, status, priority, created_at, updated_at)" -ForegroundColor Gray
    Write-Host "   VALUES ('test_001', 1, 'John Doe', 'Test task', 'Main St', 'pending', 'high', NOW(), NOW());" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Then run this script again" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "✅ READY FOR FRONTEND TESTING!" -ForegroundColor Green
    Write-Host "─" * 60
    Write-Host ""
    Write-Host "Tasks are available in the backend. Now you can:" -ForegroundColor Green
    Write-Host "1. Open the Flutter app (flutter run -d chrome)" -ForegroundColor Green
    Write-Host "2. Login as $Username" -ForegroundColor Green
    Write-Host "3. Navigate to Technician Landing Page" -ForegroundColor Green
    Write-Host "4. Tasks should appear in 'Today's Assigned Tasks' section" -ForegroundColor Green
    Write-Host "5. Each task shows as a card with title, location, status, priority" -ForegroundColor Green
    Write-Host ""
    Write-Host "If tasks don't appear on frontend:" -ForegroundColor Yellow
    Write-Host "- Open browser console (F12)" -ForegroundColor Yellow
    Write-Host "- Look for error messages starting with ❌" -ForegroundColor Yellow
    Write-Host "- Check if authentication token is being sent" -ForegroundColor Yellow
    Write-Host "- Check if response is being parsed correctly" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
