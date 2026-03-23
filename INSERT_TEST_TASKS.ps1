# =================================================================
# INSERT TEST TASKS - POWERSHELL HELPER
# =================================================================
# This script helps insert test tasks into the database
# Supports MySQL connection via command line
# 
# REQUIREMENTS:
#  - MySQL or MariaDB installed with mysql.exe in PATH
#  - Database credentials (hostname, username, password, database name)
# =================================================================

Write-Host ""
Write-Host "=================================================="
Write-Host "TEST TASKS INSERT HELPER"
Write-Host "=================================================="
Write-Host ""

# ⚙️  CONFIGURATION - UPDATE THESE
$DB_HOST = "localhost"           # Your database host
$DB_USER = "root"                # Database username
$DB_PASSWORD = "password"        # Database password
$DB_NAME = "trip_claim_app"      # Database name (or your actual DB name)
$TECHNICIAN_ID = 1               # Your technician ID (find this first!)

Write-Host "📋 Configuration:"
Write-Host "  Database Host: $DB_HOST"
Write-Host "  Database User: $DB_USER"
Write-Host "  Database Name: $DB_NAME"
Write-Host "  Technician ID: $TECHNICIAN_ID"
Write-Host ""

# ==================== STEP 1: TEST DATABASE CONNECTION ====================

Write-Host "🔍 Step 1: Testing Database Connection..."
Write-Host ""

$testQuery = "SELECT 1 as test;"

try {
    $output = & mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e $testQuery 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database connection successful!"
        Write-Host ""
    } else {
        Write-Host "❌ Database connection failed!"
        Write-Host "Error: $output"
        Write-Host ""
        Write-Host "💡 Fix: Check your database credentials and make sure MySQL is running"
        exit 1
    }
} catch {
    Write-Host "❌ MySQL command not found!"
    Write-Host "Error: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "💡 Fix: Install MySQL or add mysql.exe to your PATH"
    exit 1
}

# ==================== STEP 2: FIND TECHNICIAN ID ====================

Write-Host "🔎 Step 2: Finding Technician IDs in Database..."
Write-Host ""

$findTechnicianQuery = @"
SELECT id, username, user_type FROM users WHERE user_type = 'technician' LIMIT 10;
"@

try {
    $technicians = & mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e $findTechnicianQuery 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Available Technicians:"
        Write-Host $technicians
        Write-Host ""
        
        $userTechnicianId = Read-Host "Enter your Technician ID (or press Enter to use $TECHNICIAN_ID)"
        
        if ($userTechnicianId -ne "") {
            $TECHNICIAN_ID = $userTechnicianId
        }
        
        Write-Host "Using Technician ID: $TECHNICIAN_ID"
        Write-Host ""
    } else {
        Write-Host "⚠️  Could not fetch technician list, will use default ID: $TECHNICIAN_ID"
        Write-Host ""
    }
} catch {
    Write-Host "⚠️  Could not query technicians: $($_.Exception.Message)"
    Write-Host "Will use default ID: $TECHNICIAN_ID"
    Write-Host ""
}

# ==================== STEP 3: INSERT TEST TASKS ====================

Write-Host "➕ Step 3: Inserting Test Tasks..."
Write-Host ""

$insertQuery = @"
SET @TECHNICIAN_ID = $TECHNICIAN_ID;

INSERT INTO trip_claims (id, technician_id, customer_name, customer_phone, description, location, status, priority, created_at, updated_at) 
VALUES (CONCAT('test_', UUID()), @TECHNICIAN_ID, 'John Doe - Road Damage', '+1 (555) 123-4567', 'Assess and document road damage at intersection. Take photos and measurements.', 'Main Street & 5th Avenue, Downtown District', 'pending', 'high', NOW(), NOW());

INSERT INTO trip_claims (id, technician_id, customer_name, customer_phone, description, location, status, priority, created_at, updated_at) 
VALUES (CONCAT('test_', UUID()), @TECHNICIAN_ID, 'Jane Smith - Pothole Repair', '+1 (555) 987-6543', 'Fill pothole on residential street. Use appropriate asphalt mix.', 'Oak Road, Residential Zone', 'pending', 'medium', NOW(), NOW());

INSERT INTO trip_claims (id, technician_id, customer_name, customer_phone, description, location, status, priority, created_at, updated_at) 
VALUES (CONCAT('test_', UUID()), @TECHNICIAN_ID, 'Bob Wilson - Crack Sealing', '+1 (555) 456-7890', 'Seal cracks in parking lot. Clean area first, then apply sealant.', 'Shopping Center Parking Lot', 'pending', 'low', NOW(), NOW());

INSERT INTO trip_claims (id, technician_id, customer_name, customer_phone, description, location, status, priority, created_at, updated_at) 
VALUES (CONCAT('test_', UUID()), @TECHNICIAN_ID, 'Alice Johnson - Intersection Repair', '+1 (555) 234-5678', 'Complete intersection repair work. Continue from previous session.', 'Park Avenue & Central Street', 'on-progress', 'high', NOW(), NOW());

INSERT INTO trip_claims (id, technician_id, customer_name, customer_phone, description, location, status, priority, created_at, updated_at) 
VALUES (CONCAT('test_', UUID()), @TECHNICIAN_ID, 'Charlie Brown - Street Resurfacing', '+1 (555) 345-6789', 'Street resurfacing project completed successfully.', 'River Road', 'completed', 'high', DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY));
"@

try {
    $insertOutput = & mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e $insertQuery 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Test tasks inserted successfully!"
        Write-Host ""
    } else {
        Write-Host "❌ Failed to insert tasks!"
        Write-Host "Error: $insertOutput"
        exit 1
    }
} catch {
    Write-Host "❌ Error inserting tasks: $($_.Exception.Message)"
    exit 1
}

# ==================== STEP 4: VERIFY INSERTION ====================

Write-Host "✔️  Step 4: Verifying Insertion..."
Write-Host ""

$verifyQuery = @"
SELECT COUNT(*) as total_count FROM trip_claims WHERE technician_id = $TECHNICIAN_ID;
SELECT status, COUNT(*) as count FROM trip_claims WHERE technician_id = $TECHNICIAN_ID GROUP BY status;
SELECT customer_name, description, status FROM trip_claims WHERE technician_id = $TECHNICIAN_ID ORDER BY created_at DESC LIMIT 5;
"@

try {
    $verifyOutput = & mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e $verifyQuery 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Tasks Summary:"
        Write-Host $verifyOutput
        Write-Host ""
    }
} catch {
    Write-Host "⚠️  Could not verify: $($_.Exception.Message)"
}

# ==================== FINAL INSTRUCTIONS ====================

Write-Host "=================================================="
Write-Host "✅ TEST TASKS INSERTED SUCCESSFULLY!"
Write-Host "=================================================="
Write-Host ""
Write-Host "📱 Next Steps:"
Write-Host "1. Go back to Flutter app"
Write-Host "2. Press 'r' to hot reload (or restart if needed)"
Write-Host "3. Login as the technician"
Write-Host "4. Check the Technician Landing Page"
Write-Host "5. You should now see the test tasks!"
Write-Host ""
Write-Host "💡 If tasks still don't show:"
Write-Host "  - Press 'r' in Flutter to hot reload"
Write-Host "  - Check the Diagnostics Panel (should show task count > 0)"
Write-Host "  - Check browser console for errors (F12 → Console tab)"
Write-Host ""

