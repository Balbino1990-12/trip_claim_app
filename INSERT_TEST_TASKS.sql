-- =================================================================
-- INSERT TEST TASKS FOR TECHNICIAN
-- =================================================================
-- This script inserts test tasks into the trip_claims table
-- assigned to technician users so you can test the dashboard
-- 
-- ⚠️  IMPORTANT: 
--  1. Update TECHNICIAN_ID below with your actual technician ID
--  2. Run this in your MySQL database client
--  3. Verify tasks are inserted by running the SELECT queries below
-- =================================================================

-- ==================== STEP 1: FIND TECHNICIAN IDs ====================

-- 📍 Run this FIRST to find your technician ID:
SELECT id, username, user_type, created_at 
FROM users 
WHERE user_type = 'technician' 
LIMIT 10;

-- 📌 Remember: Use ONE of the IDs from above as TECHNICIAN_ID below

-- ==================== STEP 2: INSERT TEST TASKS ====================

-- 🔧 CUSTOMIZE THIS SECTION:
-- Replace 1 with your actual TECHNICIAN_ID from Step 1

SET @TECHNICIAN_ID = 1;  -- 👈 CHANGE THIS TO YOUR TECHNICIAN ID

-- Insert test task 1
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  description,
  location,
  status,
  priority,
  created_at,
  updated_at
) VALUES (
  CONCAT('test_', UUID()),
  @TECHNICIAN_ID,
  'John Doe - Road Damage',
  '+1 (555) 123-4567',
  'Assess and document road damage at intersection. Take photos and measurements.',
  'Main Street & 5th Avenue, Downtown District',
  'pending',
  'high',
  NOW(),
  NOW()
);

-- Insert test task 2
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  description,
  location,
  status,
  priority,
  created_at,
  updated_at
) VALUES (
  CONCAT('test_', UUID()),
  @TECHNICIAN_ID,
  'Jane Smith - Pothole Repair',
  '+1 (555) 987-6543',
  'Fill pothole on residential street. Use appropriate asphalt mix.',
  'Oak Road, Residential Zone',
  'pending',
  'medium',
  NOW(),
  NOW()
);

-- Insert test task 3
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  description,
  location,
  status,
  priority,
  created_at,
  updated_at
) VALUES (
  CONCAT('test_', UUID()),
  @TECHNICIAN_ID,
  'Bob Wilson - Crack Sealing',
  '+1 (555) 456-7890',
  'Seal cracks in parking lot. Clean area first, then apply sealant.',
  'Shopping Center Parking Lot',
  'pending',
  'low',
  NOW(),
  NOW()
);

-- Insert test task 4 (already in progress)
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  description,
  location,
  status,
  priority,
  created_at,
  updated_at
) VALUES (
  CONCAT('test_', UUID()),
  @TECHNICIAN_ID,
  'Alice Johnson - Intersection Repair',
  '+1 (555) 234-5678',
  'Complete intersection repair work. Continue from previous session.',
  'Park Avenue & Central Street',
  'on-progress',
  'high',
  NOW(),
  NOW()
);

-- Insert test task 5 (completed)
INSERT INTO trip_claims (
  id,
  technician_id,
  customer_name,
  customer_phone,
  description,
  location,
  status,
  priority,
  created_at,
  updated_at
) VALUES (
  CONCAT('test_', UUID()),
  @TECHNICIAN_ID,
  'Charlie Brown - Street Resurfacing',
  '+1 (555) 345-6789',
  'Street resurfacing project completed successfully.',
  'River Road',
  'completed',
  'high',
  DATE_SUB(NOW(), INTERVAL 2 DAY),
  DATE_SUB(NOW(), INTERVAL 1 DAY)
);

-- ==================== STEP 3: VERIFY INSERTION ====================

-- ✅ Run these to verify tasks were inserted:

-- Count tasks for this technician
SELECT COUNT(*) as total_tasks FROM trip_claims WHERE technician_id = @TECHNICIAN_ID;

-- View all inserted tasks
SELECT 
  id,
  customer_name,
  description,
  location,
  status,
  priority,
  created_at
FROM trip_claims 
WHERE technician_id = @TECHNICIAN_ID
ORDER BY created_at DESC;

-- View breakdown by status
SELECT 
  status,
  COUNT(*) as count
FROM trip_claims 
WHERE technician_id = @TECHNICIAN_ID
GROUP BY status;

-- ==================== STEP 4: DELETE TEST TASKS (IF NEEDED) ====================

-- ⚠️  Only run this if you want to clean up test tasks later:
-- DELETE FROM trip_claims WHERE technician_id = @TECHNICIAN_ID AND id LIKE 'test_%';

-- =================================================================
-- USAGE INSTRUCTIONS
-- =================================================================
-- 1. Open your MySQL client (MySQL Workbench, DBeaver, or mysql CLI)
-- 2. Connect to your database
-- 3. Copy and run the SELECT query from STEP 1 to find your technician ID
-- 4. Edit the line: SET @TECHNICIAN_ID = 1;  (replace 1 with your ID)
-- 5. Run STEP 2 to insert test tasks
-- 6. Run STEP 3 to verify they were inserted
-- 7. Hot reload Flutter app (press 'r' in terminal)
-- 8. Login as that technician and view the dashboard
-- 9. You should now see the test tasks!
-- =================================================================
