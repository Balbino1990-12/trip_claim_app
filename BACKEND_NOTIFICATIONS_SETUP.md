# Backend Endpoints for Technician Notifications

This guide shows the backend (Node.js/Express) endpoints needed to send notifications to the technician landing page.

## 📋 Overview

The Flutter client expects:
1. **REST API** endpoints for fetching assigned tasks
2. **WebSocket** endpoint for real-time task notifications
3. Proper authentication using JWT tokens

---

## 🔌 WebSocket Endpoint

### Connection URL
```
ws://your-backend:port/ws/technician/notifications
```

### Authentication
Send JWT token in connection headers or query parameters:
```javascript
const wsUrl = 'ws://localhost:5000/ws/technician/notifications?token=' + jwtToken;
```

### Notification Message Format
When a task is assigned to a technician, send this JSON message through WebSocket:

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

### Notification Types
- `task_assigned` - New task assigned to technician
- `task_updated` - Existing task status changed
- `task_completed` - Task marked as completed
- `general` - General announcements

---

## 📡 REST API Endpoints (Existing)

### Get Assigned Tasks
```
GET /api/technician/tasks
Header: Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
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

### Get Technician Stats
```
GET /api/technician/stats
Header: Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
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

## 🚀 Express.js Implementation Example

### 1. WebSocket Setup

```javascript
// Install dependencies
// npm install ws express-ws

const express = require('express');
const expressWs = require('express-ws');
const jwt = require('jsonwebtoken');

const app = express();
expressWs(app);

// Store active connections per technician
const technicianConnections = new Map();

// WebSocket endpoint for technician notifications
app.ws('/ws/technician/notifications', (ws, req) => {
  const token = req.query.token;
  
  if (!token) {
    ws.close(1008, 'No token provided');
    return;
  }

  try {
    // Verify JWT token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const technicianId = decoded.id;
    
    console.log(`✅ Technician ${technicianId} connected to notifications`);
    
    // Store connection
    if (!technicianConnections.has(technicianId)) {
      technicianConnections.set(technicianId, []);
    }
    technicianConnections.get(technicianId).push(ws);

    // Handle incoming messages
    ws.on('message', (msg) => {
      console.log(`📬 Message from ${technicianId}: ${msg}`);
    });

    // Handle disconnect
    ws.on('close', () => {
      console.log(`🔌 Technician ${technicianId} disconnected`);
      const connections = technicianConnections.get(technicianId);
      if (connections) {
        connections = connections.filter(conn => conn !== ws);
        if (connections.length === 0) {
          technicianConnections.delete(technicianId);
        } else {
          technicianConnections.set(technicianId, connections);
        }
      }
    });

    // Handle errors
    ws.on('error', (error) => {
      console.error(`❌ WebSocket error for ${technicianId}:`, error);
    });

  } catch (error) {
    console.error('❌ Token verification failed:', error);
    ws.close(1008, 'Invalid token');
  }
});

// Helper function to send notification to technician
function sendNotificationToTechnician(technicianId, notification) {
  const connections = technicianConnections.get(technicianId);
  
  if (connections && connections.length > 0) {
    const message = JSON.stringify(notification);
    
    connections.forEach(ws => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
        console.log(`📤 Notification sent to technician ${technicianId}`);
      }
    });
  } else {
    console.log(`⚠️ No active connection for technician ${technicianId}`);
  }
}

module.exports = { sendNotificationToTechnician, technicianConnections };
```

### 2. Send Notification When Task is Assigned

```javascript
// When assigning a task to a technician
app.post('/api/tasks/assign', authenticateToken, async (req, res) => {
  try {
    const { taskId, technicianId, clientName, taskTitle, location, priority } = req.body;

    // 1. Update database - assign task to technician
    await db.query(
      'UPDATE trip_claims SET technician_id = ?, status = ? WHERE id = ?',
      [technicianId, 'pending', taskId]
    );

    // 2. Get pending task count for technician
    const [countResult] = await db.query(
      'SELECT COUNT(*) as pending FROM trip_claims WHERE technician_id = ? AND status = "pending"',
      [technicianId]
    );
    const pendingTaskCount = countResult[0].pending;

    // 3. Create notification object
    const notification = {
      id: `task_${taskId}_${Date.now()}`,
      type: 'task_assigned',
      title: 'New Task Assigned',
      message: `${taskTitle} assigned to you at ${location}`,
      data: {
        taskId,
        taskTitle,
        clientName,
        location,
        priority,
        status: 'pending'
      },
      pendingTaskCount,
      timestamp: new Date().toISOString()
    };

    // 4. Send notification via WebSocket
    const { sendNotificationToTechnician } = require('./websocket');
    sendNotificationToTechnician(technicianId, notification);

    res.json({
      success: true,
      message: 'Task assigned and notification sent',
      data: { taskId, technicianId, notification }
    });

  } catch (error) {
    console.error('❌ Error assigning task:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
```

### 3. Send Notification When Task Status Changes

```javascript
app.put('/api/claims/:claimId/status', authenticateToken, async (req, res) => {
  try {
    const { claimId } = req.params;
    const { status } = req.body;

    // Update task status
    await db.query(
      'UPDATE trip_claims SET status = ?, updated_at = NOW() WHERE id = ?',
      [status, claimId]
    );

    // Get task and technician details
    const [taskResult] = await db.query(
      'SELECT id, title, technician_id FROM trip_claims WHERE id = ?',
      [claimId]
    );

    if (taskResult.length === 0) {
      return res.status(404).json({ success: false, error: 'Task not found' });
    }

    const task = taskResult[0];
    const technicianId = task.technician_id;

    // Get updated pending count
    const [countResult] = await db.query(
      'SELECT COUNT(*) as pending FROM trip_claims WHERE technician_id = ? AND status = "pending"',
      [technicianId]
    );

    // Create notification
    const notification = {
      id: `status_${claimId}_${Date.now()}`,
      type: 'task_updated',
      title: `Task ${status === 'completed' ? 'Completed' : 'Updated'}`,
      message: `${task.title} is now ${status}`,
      data: {
        taskId: claimId,
        taskTitle: task.title,
        newStatus: status,
        timestamp: new Date().toISOString()
      },
      pendingTaskCount: countResult[0].pending,
      timestamp: new Date().toISOString()
    };

    // Send to technician via WebSocket
    const { sendNotificationToTechnician } = require('./websocket');
    sendNotificationToTechnician(technicianId, notification);

    res.json({
      success: true,
      message: `Task status updated to ${status} and notification sent`
    });

  } catch (error) {
    console.error('❌ Error updating task status:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});
```

---

## 💡 Complete Backend Server Example

```javascript
// server.js - Complete example
require('dotenv').config();
const express = require('express');
const expressWs = require('express-ws');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');

const app = express();
expressWs(app);

app.use(express.json());

// Database connection pool
const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Store active WebSocket connections
const technicianConnections = new Map();

// Middleware: Verify JWT token
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Invalid token' });
    req.user = user;
    next();
  });
}

// ==================== WebSocket Endpoint ====================
app.ws('/ws/technician/notifications', (ws, req) => {
  const token = req.query.token;

  if (!token) {
    ws.close(1008, 'No token provided');
    return;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const technicianId = decoded.id;

    console.log(`✅ Technician ${technicianId} connected`);

    if (!technicianConnections.has(technicianId)) {
      technicianConnections.set(technicianId, []);
    }
    technicianConnections.get(technicianId).push(ws);

    ws.on('message', (msg) => {
      console.log(`📬 Message from ${technicianId}: ${msg}`);
    });

    ws.on('close', () => {
      console.log(`🔌 Technician ${technicianId} disconnected`);
      const connections = technicianConnections.get(technicianId);
      if (connections) {
        const updated = connections.filter(conn => conn !== ws);
        if (updated.length === 0) {
          technicianConnections.delete(technicianId);
        } else {
          technicianConnections.set(technicianId, updated);
        }
      }
    });

    ws.on('error', (error) => {
      console.error(`❌ WebSocket error for ${technicianId}:`, error);
    });

  } catch (error) {
    console.error('❌ Token verification failed:', error);
    ws.close(1008, 'Invalid token');
  }
});

// ==================== REST API Endpoints ====================

// Get assigned tasks
app.get('/api/technician/tasks', authenticateToken, async (req, res) => {
  try {
    const technicianId = req.user.id;
    const conn = await pool.getConnection();

    const [tasks] = await conn.query(
      `SELECT id, id as claimId, description as title, description, 
              location, status, 'high' as priority, created_at as assignedDate,
              customer_name as clientName, customer_phone as clientPhone,
              NULL as latitude, NULL as longitude
       FROM trip_claims 
       WHERE technician_id = ? 
       ORDER BY created_at DESC`,
      [technicianId]
    );

    conn.release();

    res.json({
      success: true,
      data: tasks
    });

  } catch (error) {
    console.error('❌ Error fetching tasks:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get technician stats
app.get('/api/technician/stats', authenticateToken, async (req, res) => {
  try {
    const technicianId = req.user.id;
    const conn = await pool.getConnection();

    const [stats] = await conn.query(
      `SELECT 
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pendingTasks,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completedTasks,
        SUM(CASE WHEN status = 'on-progress' THEN 1 ELSE 0 END) as inProgressTasks,
        4.8 as rating,
        COUNT(*) as totalTasksToday
       FROM trip_claims 
       WHERE technician_id = ? AND DATE(created_at) = CURDATE()`,
      [technicianId]
    );

    conn.release();

    res.json({
      success: true,
      data: {
        pendingTasks: stats[0].pendingTasks || 0,
        completedTasks: stats[0].completedTasks || 0,
        inProgressTasks: stats[0].inProgressTasks || 0,
        rating: stats[0].rating || 4.8,
        totalTasksToday: stats[0].totalTasksToday || 0
      }
    });

  } catch (error) {
    console.error('❌ Error fetching stats:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Assign task to technician (Admin endpoint)
app.post('/api/tasks/assign', authenticateToken, async (req, res) => {
  try {
    const { taskId, technicianId, clientName, taskTitle, location, priority } = req.body;
    const conn = await pool.getConnection();

    // Update database
    await conn.query(
      'UPDATE trip_claims SET technician_id = ?, status = ? WHERE id = ?',
      [technicianId, 'pending', taskId]
    );

    // Get pending count
    const [countResult] = await conn.query(
      'SELECT COUNT(*) as pending FROM trip_claims WHERE technician_id = ? AND status = "pending"',
      [technicianId]
    );

    conn.release();

    const notification = {
      id: `task_${taskId}_${Date.now()}`,
      type: 'task_assigned',
      title: '🎯 New Task Assigned',
      message: `${taskTitle} assigned to you at ${location}`,
      data: {
        taskId,
        taskTitle,
        clientName,
        location,
        priority,
        status: 'pending'
      },
      pendingTaskCount: countResult[0].pending,
      timestamp: new Date().toISOString()
    };

    // Send via WebSocket
    const connections = technicianConnections.get(technicianId);
    if (connections && connections.length > 0) {
      connections.forEach(ws => {
        if (ws.readyState === require('ws').OPEN) {
          ws.send(JSON.stringify(notification));
          console.log(`📤 Notification sent to technician ${technicianId}`);
        }
      });
    }

    res.json({
      success: true,
      message: 'Task assigned and notification sent',
      data: { taskId, technicianId, notification }
    });

  } catch (error) {
    console.error('❌ Error assigning task:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Update task status
app.put('/api/claims/:claimId/status', authenticateToken, async (req, res) => {
  try {
    const { claimId } = req.params;
    const { status } = req.body;
    const conn = await pool.getConnection();

    // Update status
    await conn.query(
      'UPDATE trip_claims SET status = ?, updated_at = NOW() WHERE id = ?',
      [status, claimId]
    );

    // Get task info
    const [taskResult] = await conn.query(
      'SELECT id, description as title, technician_id FROM trip_claims WHERE id = ?',
      [claimId]
    );

    if (taskResult.length === 0) {
      conn.release();
      return res.status(404).json({ success: false, error: 'Task not found' });
    }

    const task = taskResult[0];
    const technicianId = task.technician_id;

    // Get updated pending count
    const [countResult] = await conn.query(
      'SELECT COUNT(*) as pending FROM trip_claims WHERE technician_id = ? AND status = "pending"',
      [technicianId]
    );

    conn.release();

    const notification = {
      id: `status_${claimId}_${Date.now()}`,
      type: 'task_updated',
      title: status === 'completed' ? '✅ Task Completed' : '🔄 Task Updated',
      message: `${task.title} is now ${status}`,
      data: {
        taskId: claimId,
        taskTitle: task.title,
        newStatus: status
      },
      pendingTaskCount: countResult[0].pending,
      timestamp: new Date().toISOString()
    };

    // Send via WebSocket
    const connections = technicianConnections.get(technicianId);
    if (connections && connections.length > 0) {
      connections.forEach(ws => {
        if (ws.readyState === require('ws').OPEN) {
          ws.send(JSON.stringify(notification));
        }
      });
    }

    res.json({
      success: true,
      message: `Task status updated to ${status}`
    });

  } catch (error) {
    console.error('❌ Error updating status:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 WebSocket available at ws://localhost:${PORT}/ws/technician/notifications`);
});
```

---

## 🔧 Environment Variables Needed

```bash
# .env file
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=password
DB_NAME=trip_claim_db
JWT_SECRET=your_jwt_secret_key
PORT=5000
```

---

## 📦 Required npm Packages

```bash
npm install express express-ws jwt mysql2/promise dotenv
```

---

## ✅ Testing the WebSocket Locally

```javascript
// test-ws.js - Test client
const WebSocket = require('ws');

const token = 'your_jwt_token_here';
const wsUrl = `ws://localhost:5000/ws/technician/notifications?token=${token}`;

const ws = new WebSocket(wsUrl);

ws.on('open', () => {
  console.log('✅ Connected to WebSocket');
});

ws.on('message', (data) => {
  const notification = JSON.parse(data);
  console.log('📬 Received notification:', notification);
});

ws.on('error', (error) => {
  console.error('❌ Error:', error);
});

ws.on('close', () => {
  console.log('🔌 Disconnected');
});

// Keep connection open
setTimeout(() => {
  ws.close();
  process.exit(0);
}, 60000);
```

Run with: `node test-ws.js`

---

## 🎯 Summary

The Flutter app now:
✅ Connects to WebSocket on page load
✅ Listens for real-time notifications
✅ Shows toast notification when task is assigned
✅ Updates pending task badge automatically
✅ Refreshes task list every 5 seconds as fallback
✅ Falls back to polling if WebSocket fails

Your backend needs to:
✅ Implement `/ws/technician/notifications` WebSocket endpoint
✅ Send notification JSON when task is assigned
✅ Include `pendingTaskCount` in notification
✅ Verify JWT token on connection
✅ Keep connections alive and send messages

---

## 🚀 Quick Start

1. Copy the `server.js` code above
2. Install dependencies: `npm install`
3. Set environment variables
4. Run: `node server.js`
5. Deploy Flutter app
6. Assign a task to a technician → Notification appears instantly!
