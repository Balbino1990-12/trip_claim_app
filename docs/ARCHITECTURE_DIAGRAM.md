# Task Display Architecture - Visual Reference

## 🏗️ Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP (Frontend)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Login Page (lib/pages/login/login_page.dart)            │   │
│  │                                                          │   │
│  │ [Username] [Password] [Login Button]                    │   │
│  │                                                          │   │
│  │ On Success:                                             │   │
│  │   → ApiService.setAuthToken(token)                      │   │
│  │   → TechnicianService.setAuthToken(token)               │   │
│  │   → Navigate to TechnicianLandingPage                    │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Technician Landing Page (technician_landing_page.dart:25) │   │
│  │                                                          │   │
│  │ initState():                                             │   │
│  │   → _loadTasks()                                         │   │
│  │   → _startPeriodicRefresh() [every 5 seconds]           │   │
│  │                                                          │   │
│  │ void _loadTasks():                                       │   │
│  │   _tasksFuture = TechnicianService.getAssignedTasks()    │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ TechnicianService.getAssignedTasks()                     │   │
│  │ (lib/services/technician_service.dart:161)              │   │
│  │                                                          │   │
│  │ • Build URI: $baseUrl/technician/tasks                  │   │
│  │ • Add Header: Bearer $jwtToken                          │   │
│  │ • Method: HTTP GET                                       │   │
│  │ • Parse: response.json['data']                          │   │
│  │ • Return: List<TechnicianTask>                          │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
└─────────────────────┼───────────────────────────────────────────┘
                      │
                      │ HTTP Request (Bearer Token)
                      ↓
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND API (Node.js/Express)                 │
│                    http://10.91.220.92:5000                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ GET /api/technician/tasks                               │   │
│  │                                                          │   │
│  │ Headers:                                                │   │
│  │   Authorization: Bearer <JWT_TOKEN>                     │   │
│  │                                                          │   │
│  │ Validation:                                             │   │
│  │   1. Verify JWT token                                   │   │
│  │   2. Extract technician_id from token                   │   │
│  │   3. Query database                                     │   │
│  │                                                          │   │
│  │ Database Query:                                         │   │
│  │   SELECT * FROM trip_claims                             │   │
│  │   WHERE technician_id = <extracted_id>                  │   │
│  │                                                          │   │
│  │ Response:                                               │   │
│  │ {                                                        │   │
│  │   "success": true,                                       │   │
│  │   "data": [                                              │   │
│  │     {                                                     │   │
│  │       "id": "claim_001",                                │   │
│  │       "claimId": "claim_001",                           │   │
│  │       "title": "Road damage assessment",                │   │
│  │       "description": "Road damage assessment",         │   │
│  │       "location": "Main Street & 5th Ave",              │   │
│  │       "status": "pending",                             │   │
│  │       "priority": "high",                              │   │
│  │       "customerName": "John Doe",                       │   │
│  │       "customerPhone": "555-1234",                      │   │
│  │       "assignedDate": "2025-02-11T10:00:00Z"           │   │
│  │     },                                                   │   │
│  │     ... more tasks ...                                   │   │
│  │   ]                                                      │   │
│  │ }                                                        │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
└─────────────────────┼───────────────────────────────────────────┘
                      │
                      │ HTTP Response (JSON data)
                      ↓
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP (Frontend)                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Parse Response (TechnicianService)                       │   │
│  │                                                          │   │
│  │ • Extract tasks from json['data']                        │   │
│  │ • Map each task to TechnicianTask object                │   │
│  │ • Return List<TechnicianTask>                           │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ _TechnicianDashboard Widget                              │   │
│  │                                                          │   │
│  │ Constructor receives:                                    │   │
│  │   • tasksFuture: Future<List<TechnicianTask>>           │   │
│  │   • onRefresh: VoidCallback                             │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ _TechnicianDashboardState (Line 1078)                    │   │
│  │                                                          │   │
│  │ FutureBuilder<List<TechnicianTask>>(                    │   │
│  │   future: widget.tasksFuture,                           │   │
│  │   builder: (context, snapshot) {                        │   │
│  │     if (loading) → CircularProgressIndicator()          │   │
│  │     if (error) → Error message                          │   │
│  │     if (empty) → "No tasks assigned today"              │   │
│  │     if (hasData) → List of _TaskCard widgets            │   │
│  │   }                                                       │   │
│  │ )                                                        │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Individual _TaskCard Widget (Line 1137)                 │   │
│  │                                                          │   │
│  │ Displays:                                                │   │
│  │ ┌───────────────────────────────────────┐               │   │
│  │ │ Road Damage Assessment           high │               │   │
│  │ │ Main Street & 5th Ave           📍    │               │   │
│  │ │ Status: pending   Claim: 001         │               │   │
│  │ └───────────────────────────────────────┘               │   │
│  │                                                          │   │
│  │ Widget tree:                                            │   │
│  │   Container (padding, decoration)                       │   │
│  │     └─ Column                                            │   │
│  │       ├─ Row (Title + Priority badge)                   │   │
│  │       ├─ Row (Location)                                 │   │
│  │       └─ Row (Status + ClaimId)                         │   │
│  └────────────────┬─────────────────────────────────────────┘   │
│                   │                                               │
│                   ↓                                               │
│              DISPLAY ON SCREEN                                    │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Sequence

```
Time (T)          Event                          Component
─────────────────────────────────────────────────────────────────
T+0s     User clicks "Login"
           │
           ├─→ LoginPage.login()
           │
           └─→ ApiService.login("Balbino", "password")
                │
                ├─→ HTTP POST /api/login
                │
                └─→ Backend returns JWT token
                   │
                   ├─→ ApiService.setAuthToken(token)
                   ├─→ TechnicianService.setAuthToken(token)
                   │
                   └─→ Navigate to TechnicianLandingPage

T+3s     TechnicianLandingPage.initState()
           │
           ├─→ _loadTasks()
           │     │
           │     └─→ TechnicianService.getAssignedTasks()
           │          │
           │          ├─→ HTTP GET /api/technician/tasks
           │          │   (with Bearer token header)
           │          │
           │          ├─→ Backend validates token
           │          │
           │          ├─→ Database query:
           │          │   SELECT * FROM trip_claims
           │          │   WHERE technician_id = 1
           │          │
           │          ├─→ Backend returns JSON
           │          │   {"success": true, "data": [...]}
           │          │
           │          └─→ Parse to List<TechnicianTask>
           │
           ├─→ _startPeriodicRefresh() (Timer.periodic every 5s)
           │
           └─→ FutureBuilder renders tasks on screen

T+4s     Screen shows:
           • Loading spinner (still waiting)

T+5s     Tasks received:
           • Spinner disappears
           • 5 _TaskCard widgets appear
           • Notification badge shows: 🔔 5

T+10s    Auto-refresh triggered:
           └─→ _loadTasks() called again
              → New HTTP request to API
              → Dashboard updates with latest data

T+∞      User can manually refresh anytime:
           └─→ Click 🔄 Refresh button
              → Immediate task reload
```

---

## 📦 Data Structure

### Request
```
GET /api/technician/tasks HTTP/1.1
Host: 10.91.220.92:5000
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
```

### Response
```json
{
  "success": true,
  "data": [
    {
      "id": "claim_001",
      "claimId": "claim_001",
      "title": "Road damage assessment",
      "description": "Road damage assessment needed",
      "location": "Main Street & 5th Avenue",
      "status": "pending",
      "priority": "high",
      "customerName": "John Doe",
      "customerPhone": "555-1234",
      "assignedDate": "2025-02-11T10:00:00Z",
      "latitude": 40.7128,
      "longitude": -74.0060
    },
    ... more tasks ...
  ]
}
```

### Dart Model
```dart
class TechnicianTask {
  final String id;                    // "claim_001"
  final String claimId;               // "claim_001"
  final String title;                 // "Road damage assessment"
  final String description;           // "Road damage assessment needed"
  final String location;              // "Main Street & 5th Avenue"
  final String status;                // "pending", "in-progress", "completed"
  final String priority;              // "high", "medium", "low"
  final DateTime? assignedDate;       // DateTime object
  final String? clientName;           // "John Doe"
  final String? clientPhone;          // "555-1234"
  final double? latitude;             // 40.7128
  final double? longitude;            // -74.0060
}
```

---

## 🎨 UI Layout Structure

```
┌─────────────────────────────────────────────────┐
│ Technician Landing Page                         │
├─────────────────────────────────────────────────┤
│                                                 │
│ Header (Gradient Blue)                          │
│ ┌─────────────────────────────────────────────┐ │
│ │ 🔧 EDTL                         🔔 5        │ │ ← Notification badge
│ │ Technician Service Portal                   │ │    (shows task count)
│ │                                             │ │
│ │ 👋 Welcome back! Ready to help?             │ │
│ │ You have pending tasks waiting               │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Diagnostics Panel                               │
│ ┌─────────────────────────────────────────────┐ │
│ │ API Endpoint: http://10.91.220.92:5000      │ │
│ │ ✅ Connected                                │ │
│ │ 📊 Tasks: 5  ⏳ Pending: 3                  │ │
│ │ [🔄 Refresh]                                 │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Today's Assigned Tasks                          │
│ ┌─────────────────────────────────────────────┐ │
│ │ ┌───────────────────────────────────────┐   │ │ ← Task Card 1
│ │ │ Road Damage Assessment          high  │   │ │    (from API data)
│ │ │ Main Street & 5th Ave          📍    │   │ │
│ │ │ Status: pending  Claim: 001          │   │ │
│ │ └───────────────────────────────────────┘   │ │
│ │                                             │ │
│ │ ┌───────────────────────────────────────┐   │ │ ← Task Card 2
│ │ │ Pothole Repair                medium  │   │ │    (from API data)
│ │ │ Oak Road, Downtown            📍      │   │ │
│ │ │ Status: pending  Claim: 002          │   │ │
│ │ └───────────────────────────────────────┘   │ │
│ │                                             │ │
│ │ ┌───────────────────────────────────────┐   │ │ ← Task Card 3
│ │ │ Accident Damage Inspection      high  │   │ │    (from API data)
│ │ │ 123 Park Lane                 📍      │   │ │
│ │ │ Status: in-progress  Claim: 003      │   │ │
│ │ └───────────────────────────────────────┘   │ │
│ │                                             │ │
│ │ ... more cards ...                          │ │
│ └─────────────────────────────────────────────┘ │
│                                                 │
│ Quick Actions                                   │
│ [📍 View Location] [📸 Upload Photo]            │
│ [📞 Call Customer] [✅ Mark Complete]           │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 🔐 Authentication Flow

```
┌──────────────────────┐
│  Login Form          │
│  [Username field]    │
│  [Password field]    │
│  [Login button]      │
└──────────────┬───────┘
               │
               ↓
       ┌──────────────┐
       │ POST /login  │
       │ credentials  │
       └──────┬───────┘
              │
              ↓
    ┌─────────────────────┐
    │ Backend Validation  │
    │ • Hash password     │
    │ • Look up user      │
    │ • Verify match      │
    └─────────┬───────────┘
              │
              ↓
    ┌─────────────────────┐
    │ Generate JWT Token  │
    │ {                   │
    │   user_id: 1,       │
    │   username: Balbino │
    │   exp: 2025-02-11   │
    │ }                   │
    └─────────┬───────────┘
              │
              ↓
    ┌─────────────────────────┐
    │ Return JWT to Client    │
    │ Authorization header    │
    │ Authorization: Bearer.. │
    └────────────┬────────────┘
                 │
                 ↓
      ┌──────────────────────────┐
      │ Client Stores Token      │
      │ ApiService.setAuthToken  │
      │ TechnicianService.       │
      │   setAuthToken           │
      └────────────┬─────────────┘
                   │
                   ↓
      ┌──────────────────────────┐
      │ Later API Calls Include  │
      │ Authorization: Bearer <TOKEN>
      └────────────┬─────────────┘
                   │
                   ↓
      ┌──────────────────────────┐
      │ Backend Verifies Token   │
      │ • Decode JWT             │
      │ • Check signature        │
      │ • Verify expiration      │
      │ • Extract user_id        │
      └────────────┬─────────────┘
                   │
                   ↓
      ┌──────────────────────────┐
      │ Query Database Using     │
      │ user_id from JWT         │
      │ SELECT * FROM trip_claims│
      │ WHERE technician_id = 1  │
      └─────────────────────────┘
```

---

## ⏱️ Timing Diagram

```
Timeline Events:
─────────────────────────────────────────────────────────

T+0.0s   User opens app
         │
T+0.5s   Login page displays
         │
T+1.0s   User enters credentials and clicks "Login"
         │
         [Backend processes: 200-500ms]
         │
T+1.5s   JWT token received and stored
         │
T+1.6s   Navigate to TechnicianLandingPage
         │
T+1.7s   initState() called
         ├─ _loadTasks() starts
         ├─ _startPeriodicRefresh() starts
         │
         [API request: 50-500ms]
         │
T+2.2s   Response received from API
         │
T+2.3s   FutureBuilder updates state
         │
T+2.4s   Dashboard renders with task cards
         │
T+2.5s   User sees 5 task cards on screen ✅
         │
T+7.5s   Auto-refresh triggered (every 5s)
         │
         [New API request]
         │
T+8.0s   Dashboard updates with fresh data
         │
T+∞      User can manually refresh anytime
```

---

## 🔄 State Management Hierarchy

```
TechnicianLandingPage (StatefulWidget)
│
├─ State: _TechnicianLandingPageState
│  │
│  ├─ late Future<List<TechnicianTask>> _tasksFuture
│  │   (holds the API response, triggers FutureBuilder rebuild)
│  │
│  ├─ late Timer _refreshTimer
│  │   (refreshes _tasksFuture every 5 seconds)
│  │
│  ├─ void _loadTasks()
│  │   (calls TechnicianService.getAssignedTasks() and assigns to _tasksFuture)
│  │
│  ├─ void _startPeriodicRefresh()
│  │   (starts Timer.periodic to call _loadTasks() every 5 seconds)
│  │
│  └─ void initState()
│     (calls _loadTasks() and _startPeriodicRefresh())
│
├─ Widget: _TechnicianDashboard (receives _tasksFuture)
│  │
│  └─ State: _TechnicianDashboardState
│     │
│     ├─ future: widget.tasksFuture (from parent)
│     │
│     └─ FutureBuilder renders one of:
│        ├─ Loading spinner (while waiting)
│        ├─ Error text (if API error)
│        ├─ "No tasks" text (if empty array)
│        └─ List of _TaskCard widgets (if has data)
│           │
│           └─ _TaskCard (receives single task)
│              (displays title, location, status, priority, claimId)
```

---

This architecture ensures:
- ✅ Single source of truth (_tasksFuture in parent state)
- ✅ Automatic rebuilds when data changes (setState)
- ✅ Periodic refresh without user interaction (Timer)
- ✅ Proper error handling and loading states (FutureBuilder)
- ✅ Clean data flow from API to UI (unidirectional)

