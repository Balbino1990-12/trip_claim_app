# Rapid Timeout Diagnostic Script
# Run this to identify why requests are timing out

param(
    [string]$BackendUrl = "http://10.91.220.92:5000"
)

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Timeout Diagnostic Tool" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$allTestsPassed = $true

# Test 1: Backend Health
Write-Host "TEST 1: Backend Health Check" -ForegroundColor Yellow
Write-Host "─" * 60

try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/health" -TimeoutSec 10 -ErrorAction Stop
    $sw.Stop()
    
    Write-Host "✅ Backend is responding!" -ForegroundColor Green
    Write-Host "   Response Time: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
    
    if ($sw.ElapsedMilliseconds -gt 5000) {
        Write-Host "   ⚠️  Response isSLOW! (over 5 seconds)" -ForegroundColor Yellow
        $allTestsPassed = $false
    }
} catch {
    Write-Host "❌ Backend is NOT responding!" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUTION:" -ForegroundColor Yellow
    Write-Host "1. Start your backend server first" -ForegroundColor Yellow
    Write-Host "2. Verify it's running on $BackendUrl" -ForegroundColor Yellow
    Write-Host ""
    $allTestsPassed = $false
}

Write-Host ""

# Test 2: Login Endpoint
Write-Host "TEST 2: Login Endpoint" -ForegroundColor Yellow
Write-Host "─" * 60

try {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $loginBody = @{
        username = "Balbino"
        password = "password"
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -TimeoutSec 15 `
        -ErrorAction Stop
    
    $sw.Stop()
    $loginJson = $response.Content | ConvertFrom-Json
    
    if ($loginJson.token) {
        Write-Host "✅ Login successful!" -ForegroundColor Green
        Write-Host "   Response Time: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
        $token = $loginJson.token
        
        if ($sw.ElapsedMilliseconds -gt 5000) {
            Write-Host "   ⚠️  Response is SLOW! (over 5 seconds)" -ForegroundColor Yellow
            $allTestsPassed = $false
        }
    } else {
        Write-Host "❌ Login failed: $($loginJson.message)" -ForegroundColor Red
        $allTestsPassed = $false
    }
} catch {
    Write-Host "❌ Login endpoint error!" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -match "timeout") {
        Write-Host "   ⚠️  Even login is timing out!" -ForegroundColor Yellow
        Write-Host "   Your backend is VERY slow or not responding!" -ForegroundColor Yellow
    }
    
    $allTestsPassed = $false
}

Write-Host ""

# Test 3: Tasks Endpoint (the problematic one)
Write-Host "TEST 3: Tasks Endpoint (The One Timing Out)" -ForegroundColor Yellow
Write-Host "─" * 60

if ($token) {
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-WebRequest -Uri "$BackendUrl/api/technician/tasks" `
            -Headers $headers `
            -TimeoutSec 65 `
            -ErrorAction Stop
        
        $sw.Stop()
        $tasksJson = $response.Content | ConvertFrom-Json
        
        Write-Host "✅ Tasks endpoint responded!" -ForegroundColor Green
        Write-Host "   Response Time: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Green
        Write-Host "   Task Count: $($tasksJson.data.Count)" -ForegroundColor Green
        
        if ($sw.ElapsedMilliseconds -gt 10000) {
            Write-Host "   ⚠️  Response is VERY SLOW! (over 10 seconds)" -ForegroundColor Yellow
            Write-Host "   Likely cause: Database query is slow" -ForegroundColor Yellow
            $allTestsPassed = $false
        }
    } catch {
        Write-Host "❌ Tasks endpoint error!" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if ($_.Exception.Message -match "timeout") {
            Write-Host "   ⏱️  REQUEST TIMED OUT!" -ForegroundColor Red
            Write-Host "   Your backend/database is too slow to respond in time" -ForegroundColor Red
            Write-Host ""
            Write-Host "   Possible causes:" -ForegroundColor Yellow
            Write-Host "   1. Database query is very slow" -ForegroundColor Yellow
            Write-Host "   2. Too much data in database" -ForegroundColor Yellow
            Write-Host "   3. Database indexes missing" -ForegroundColor Yellow
            Write-Host "   4. Database connection is slow" -ForegroundColor Yellow
        }
        
        $allTestsPassed = $false
    }
} else {
    Write-Host "⏭️  Skipped (need valid token from login)" -ForegroundColor Gray
}

Write-Host ""

# Summary
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Diagnostic Summary" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($allTestsPassed) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your backend appears to be working correctly." -ForegroundColor Green
    Write-Host "If Flutter app is still timing out, check:" -ForegroundColor Green
    Write-Host "1. Network connectivity" -ForegroundColor Green
    Write-Host "2. JWT token validity" -ForegroundColor Green
    Write-Host "3. Backend logs for errors" -ForegroundColor Green
} else {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Review the errors above" -ForegroundColor Yellow
    Write-Host "2. Check backend logs" -ForegroundColor Yellow
    Write-Host "3. Check database connection" -ForegroundColor Yellow
    Write-Host "4. Verify network connectivity" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
