# Task Endpoints Reference

## 📋 Overview

All endpoints require authentication via JWT token in the `Authorization` header:
```
Authorization: Bearer <your_jwt_token>
```

**Base URL:** `http://10.91.220.92:5000/api`

---

## 🔗 Endpoints

### 1. Get Assigned Tasks
**Fetch all tasks assigned to the logged-in technician**

```
GET /api/technician/tasks
```

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": [
    {
      "id": "claim_001",
      "claimId": "claim_001",
      "title": "Road Damage Assessment",
      "description": "Assess road damage at intersection",
      "location": "Main Street & 5th Ave",
      "status": "pending",
      "priority": "high",
      "assignedDate": "2025-02-13T10:00:00Z",
      "clientName": "John Doe",
      "clientPhone": "+1234567890",
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    {
      "id": "claim_002",
      "claimId": "claim_002",
      "title": "Pothole Repair",
      "description": "Fill pothole on residential street",
      "location": "Oak Road",
      "status": "pending",
      "priority": "medium",
      "assignedDate": "2025-02-13T11:00:00Z",
      "clientName": "Jane Smith",
      "clientPhone": "+0987654321",
      "latitude": 40.7580,
      "longitude": -73.9855
    }
  ]
}
```

**Query Parameters (Optional):**
```
status=pending        - Filter by status (pending, on-progress, completed)
limit=10             - Limit number of results
```

**Example with filters:**
```
GET /api/technician/tasks?status=pending&limit=5
```

**Error Responses:**
- `401` - Unauthorized (invalid/missing token)
- `404` - Endpoint not found
- `500` - Server error

---

### 2. Get Technician Statistics
**Fetch stats about tasks assigned to technician**

```
GET /api/technician/stats
```

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "pendingTasks": 2,
    "completedTasks": 15,
    "inProgressTasks": 1,
    "rating": 4.8,
    "totalTasksToday": 3
  }
}
```

---

### 3. Update Task Status
**Update the status of a specific task**

```
PUT /api/claims/:claimId/status
```

**Headers:**
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "status": "on-progress"
}
```

**Allowed Status Values:**
- `pending` - Task not started
- `on-progress` - Currently being worked on
- `completed` - Task finished
- `solved` - Alternative for completed

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Task status updated to on-progress",
  "data": {
    "taskId": "claim_001",
    "newStatus": "on-progress",
    "updatedAt": "2025-02-13T14:30:00Z"
  }
}
```

---

### 4. WebSocket - Real-time Notifications
**Connect to real-time notification stream**

```
ws://10.91.220.92:5000/ws/technician/notifications?token=<jwt_token>
```

**Connection:**
```
ws://your-backend:5000/ws/technician/notifications?token=eyJhbG...
```

**Incoming Messages:**
```json
{
  "id": "notification_123",
  "type": "task_assigned",
  "title": "New Task Assigned",
  "message": "Road damage assessment assigned to you",
  "data": {
    "taskId": "claim_001",
    "taskTitle": "Road Damage Assessment",
    "clientName": "John Doe",
    "location": "Main Street, City",
    "priority": "high",
    "status": "pending"
  },
  "pendingTaskCount": 2,
  "timestamp": "2025-02-13T14:30:00Z"
}
```

**Notification Types:**
- `task_assigned` - New task assigned
- `task_updated` - Task status changed
- `task_completed` - Task marked as complete
- `general` - General announcements

---

## 🧪 Testing Endpoints

### Using cURL

**1. Get Tasks:**
```bash
curl -X GET http://10.91.220.92:5000/api/technician/tasks \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json"
```

**2. Get Stats:**
```bash
curl -X GET http://10.91.220.92:5000/api/technician/stats \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

**3. Update Task Status:**
```bash
curl -X PUT http://10.91.220.92:5000/api/claims/claim_001/status \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"status": "on-progress"}'
```

### Using PowerShell

**See:** [TEST_API.ps1](TEST_API.ps1) or [FETCH_TASKS_ENDPOINT.ps1](FETCH_TASKS_ENDPOINT.ps1)

---

## 📊 Response Field Definitions

### Task Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique task identifier (same as claimId) |
| `claimId` | String | Claim ID (same as id) |
| `title` | String | Task title/description |
| `description` | String | Detailed task description |
| `location` | String | Task location/address |
| `status` | String | Current status (pending, on-progress, completed) |
| `priority` | String | Priority level (high, medium, low) |
| `assignedDate` | DateTime | When task was assigned |
| `clientName` | String | Customer/client name |
| `clientPhone` | String | Customer phone number |
| `latitude` | Number | GPS latitude (optional) |
| `longitude` | Number | GPS longitude (optional) |

### Stats Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `pendingTasks` | Integer | Count of pending tasks |
| `completedTasks` | Integer | Count of completed tasks |
| `inProgressTasks` | Integer | Count of in-progress tasks |
| `rating` | Float | Technician rating (0-5) |
| `totalTasksToday` | Integer | Tasks assigned today |

---

## 🔐 Authentication

### Get JWT Token

```
POST /api/login
Content-Type: application/json
```

**Request:**
```json
{
  "username": "Balbino",
  "password": "password"
}
```

**Response:**
```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "Balbino",
    "email": "balbino@example.com",
    "user_type": "technician"
  }
}
```

---

## ⚠️ Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Invalid/expired token | Login again to get fresh token |
| 404 Not Found | Wrong endpoint URL | Check endpoint path and method |
| Empty data array | No tasks assigned | Assign tasks in database or frontend |
| 500 Server Error | Backend error | Check backend logs |
| Token too short | Token not fully copied | Get full token from login response |

---

## 📁 Related Files

- [BACKEND_NOTIFICATIONS_SETUP.md](BACKEND_NOTIFICATIONS_SETUP.md) - Full backend implementation
- [TEST_API.ps1](TEST_API.ps1) - PowerShell test script
- [FETCH_TASKS_ENDPOINT.ps1](FETCH_TASKS_ENDPOINT.ps1) - Fetch script
- [QUERY_TASKS.sql](QUERY_TASKS.sql) - Database queries

