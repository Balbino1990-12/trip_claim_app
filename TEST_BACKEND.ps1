# Backend Connectivity Test Script

$backendUrl = "http://10.91.220.92:5000"
$apiBase = "$backendUrl/api"

Write-Host "=== BACKEND CONNECTIVITY TEST ===" -ForegroundColor Cyan
Write-Host "`nTesting: $backendUrl" -ForegroundColor Yellow

# Test 1: Basic connectivity
Write-Host "`n[1] Testing basic connectivity to backend..." -ForegroundColor Green
try {
    $response = Invoke-WebRequest -Uri "$backendUrl/api/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Backend responding: Status $($response.StatusCode)" -ForegroundColor Green
    Write-Host "  Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Backend NOT responding: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Is backend running at $backendUrl?" -ForegroundColor Yellow
    Write-Host "  - Check firewall/network settings" -ForegroundColor Yellow
}

# Test 2: Login endpoint
Write-Host "`n[2] Testing login endpoint..." -ForegroundColor Green
try {
    $loginBody = @{
        phoneNumber = "1111111111"
        password = "1Anagara."
    } | ConvertTo-Json
    
    $loginResponse = Invoke-WebRequest -Uri "$apiBase/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -TimeoutSec 5 `
        -ErrorAction Stop
    
    Write-Host "✓ Login endpoint working: Status $($loginResponse.StatusCode)" -ForegroundColor Green
    $loginJson = $loginResponse.Content | ConvertFrom-Json
    if ($loginJson.token) {
        Write-Host "  Token received: $($loginJson.token.substring(0,20))..." -ForegroundColor Gray
        $token = $loginJson.token
    }
} catch {
    Write-Host "✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Tasks endpoint (if token obtained)
if ($token) {
    Write-Host "`n[3] Testing technician tasks endpoint..." -ForegroundColor Green
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $taskResponse = Invoke-WebRequest -Uri "$apiBase/technician/tasks" `
            -Headers $headers `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        Write-Host "✓ Tasks endpoint working: Status $($taskResponse.StatusCode)" -ForegroundColor Green
        $tasksJson = $taskResponse.Content | ConvertFrom-Json
        Write-Host "  Response type: $($tasksJson.GetType().Name)" -ForegroundColor Gray
        if ($tasksJson.data) {
            Write-Host "  Tasks in 'data': $($tasksJson.data.Count) items" -ForegroundColor Gray
        } elseif ($tasksJson -is [array]) {
            Write-Host "  Direct array: $($tasksJson.Count) items" -ForegroundColor Gray
        }
        Write-Host "  Full response: $($taskResponse.Content.substring(0,200))..." -ForegroundColor Gray
    } catch {
        Write-Host "✗ Tasks endpoint failed:" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        if ($_.ErrorDetails) {
            Write-Host "  Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
    }
}

# Test 4: Alternative endpoint paths
Write-Host "`n[4] Testing alternative endpoint paths..." -ForegroundColor Green
$altPaths = @(
    "/api/technician/tasks",
    "/api/tasks", 
    "/technician/tasks",
    "/tasks"
)

foreach ($path in $altPaths) {
    try {
        $testUrl = "$backendUrl$path"
        $testResponse = Invoke-WebRequest -Uri $testUrl `
            -Headers @{"Authorization" = "Bearer $token"} `
            -TimeoutSec 3 `
            -ErrorAction Stop
        Write-Host "  ✓ $path - Status $($testResponse.StatusCode)" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode
        if ($statusCode -eq 404) {
            Write-Host "  ✗ $path - NOT FOUND (404)" -ForegroundColor Yellow
        } elseif ($statusCode -eq 400) {
            Write-Host "  ✗ $path - BAD REQUEST (400)" -ForegroundColor Yellow
        } else {
            Write-Host "  ✗ $path - Status $statusCode" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== DIAGNOSIS COMPLETE ===" -ForegroundColor Cyan
Write-Host "If backend is not responding:" -ForegroundColor Yellow
Write-Host "1. Start the backend server" -ForegroundColor Yellow
Write-Host "2. Check backend logs for errors" -ForegroundColor Yellow
Write-Host "3. Verify database connection on backend" -ForegroundColor Yellow
Write-Host "4. Check if port 5000 is open" -ForegroundColor Yellow
