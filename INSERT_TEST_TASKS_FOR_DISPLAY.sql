-- Test Tasks for Technician Dashboard Display
-- Run this SQL to insert test tasks for Balbino (user_id = 1)

-- First, check if Balbino exists
-- SELECT id FROM users WHERE username = 'Balbino';
-- If this returns no results, create the user first

-- Insert 5 test tasks
INSERT INTO trip_claims 
  (id, technician_id, customer_name, description, location, status, priority, created_at, updated_at) 
VALUES
  (
    'claim_001',
    1,
    'John Doe',
    'Road damage assessment needed',
    'Main Street & 5th Avenue',
    'pending',
    'high',
    NOW(),
    NOW()
  ),
  (
    'claim_002',
    1,
    'Jane Smith',
    'Pothole repair in parking area',
    'Oak Road, Downtown',
    'pending',
    'medium',
    NOW(),
    NOW()
  ),
  (
    'claim_003',
    1,
    'Bob Johnson',
    'Accident damage inspection',
    '123 Park Lane, Residential Zone',
    'on-progress',
    'high',
    NOW(),
    NOW()
  ),
  (
    'claim_004',
    1,
    'Alice Lee',
    'Water damage from recent storm',
    '456 River Road',
    'pending',
    'low',
    NOW(),
    NOW()
  ),
  (
    'claim_005',
    1,
    'Charlie Brown',
    'Previously completed claim for review',
    '789 Oak Street',
    'completed',
    'low',
    NOW(),
    NOW()
  );

-- Verify insertion
SELECT 
  COUNT(*) as total_tasks,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_tasks,
  SUM(CASE WHEN status = 'on-progress' THEN 1 ELSE 0 END) as in_progress_tasks,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_tasks
FROM trip_claims 
WHERE technician_id = 1;

-- View all tasks
SELECT 
  id, customer_name, description, location, 
  status, priority, created_at 
FROM trip_claims 
WHERE technician_id = 1
ORDER BY created_at DESC;
