-- =================================================================
-- FETCH ALL TASKS FOR BALBINO PINTO - SQL QUERIES
-- =================================================================
-- Copy and run these queries in your MySQL client
-- =================================================================

-- Step 1: Find Balbino's user ID
SELECT 'Step 1: Find User ID' as Step;
SELECT id, username, email, user_type FROM users WHERE username LIKE '%Balbino%' OR email LIKE '%balbino%' OR first_name LIKE '%Balbino%';

-- Step 2: Get all tasks for this technician
-- Replace 1 with the ID from Step 1
SELECT 'Step 2: All Tasks for Technician' as Step;
SELECT 
  id as 'Task ID',
  customer_name as 'Customer',
  description as 'Description',
  location as 'Location',
  status as 'Status',
  priority as 'Priority',
  created_at as 'Created',
  updated_at as 'Updated'
FROM trip_claims 
WHERE technician_id = 1
ORDER BY created_at DESC;

-- Step 3: Task count summary
SELECT 'Step 3: Task Summary' as Step;
SELECT 
  COUNT(*) as 'Total Tasks',
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as 'Pending',
  SUM(CASE WHEN status = 'on-progress' THEN 1 ELSE 0 END) as 'In Progress',
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as 'Completed'
FROM trip_claims 
WHERE technician_id = 1;

-- Step 4: All database users (to verify data exists)
SELECT 'Step 4: All Users in System' as Step;
SELECT id, username, email, user_type FROM users LIMIT 10;

-- Step 5: Check all trip_claims in database  
SELECT 'Step 5: All Trip Claims (top 20)' as Step;
SELECT id, technician_id, customer_name, status, created_at FROM trip_claims ORDER BY created_at DESC LIMIT 20;
