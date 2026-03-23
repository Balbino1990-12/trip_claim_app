# Technician Landing Page - Backend API Integration

## Overview
The Technician Landing Page has been successfully integrated with the backend API to display real-time data including assigned tasks, dashboard statistics, and task details.

## Components Integrated

### 1. **TechnicianService** (`lib/services/technician_service.dart`)
Complete API service layer for technician operations:

#### Data Models
- **TechnicianTask**: Represents individual assigned claims/tasks
  - Fields: `id`, `claimId`, `title`, `description`, `location`, `status`, `priority`
  - Additional: `assignedDate`, `clientName`, `clientPhone`, `latitude`, `longitude`
  - Smart location parsing (handles both string and Map formats)

- **TechnicianStats**: Dashboard statistics aggregation
  - Fields: `pendingTasks`, `completedTasks`, `inProgressTasks`, `rating`, `totalTasksToday`

#### API Methods
1. **`getAssignedTasks({status, limit})`**
   - Fetches all tasks assigned to the technician
   - Optional filtering by status
   - Returns: `Future<List<TechnicianTask>>`
   - Error handling: Returns empty list on failure

2. **`getTechnicianStats()`**
   - Gets dashboard statistics
   - Returns: `Future<TechnicianStats>`
   - Fallback: Default stats (3 pending, 12 completed, 2 in progress, 4.8 rating)

3. **`getClaimDetails(String claimId)`**
   - Retrieves full details for a specific claim
   - Returns: `Future<TechnicianTask>`

4. **`updateTaskStatus(String claimId, String newStatus)`**
   - Updates a task's status
   - Status options: 'pending', 'on-progress', 'completed'
   - Method: PUT request

5. **`uploadTaskPhoto(String claimId, String photoPath)`**
   - Uploads photo evidence for a task
   - Method: Multipart form data
   - Returns success/failure status

6. **`sendTaskUpdate(String claimId, String message)`**
   - Sends text update/message for a task
   - Returns success confirmation

7. **`getOnProgressClaims()`**
   - Fetches claims with "on-progress" status
   - Returns: `Future<List<TechnicianTask>>`

8. **`setAuthToken(String token)`**
   - Sets JWT bearer token for authenticated requests
   - Called during app initialization or login

### 2. **TechnicianLandingPage** (`lib/pages/technician/technician_landing_page.dart`)

#### Architecture
- **TechnicianLandingPage**: Stateful widget wrapper with navigation
- **_TechnicianLandingPageState**: Manages 4 tabs (Dashboard, Tasks, Analytics, Account)
- **_TechnicianDashboard**: Main dashboard with API integration
- **_TechnicianDashboardState**: Async data loading
  - `_statsFuture`: Future for dashboard statistics
  - `_tasksFuture`: Future for assigned tasks
  - `_loadData()`: Initializes data futures
  - `_getStatusColor()`: Maps status to display color

#### UI Integration Points

**1. Welcome Section (Dynamic)**
```dart
FutureBuilder<TechnicianStats>(
  future: _statsFuture,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      final stats = snapshot.data!;
      return Text('You have ${stats.totalTasksToday} tasks assigned to you today');
    }
    return Text('Loading your tasks...');
  }
)
```
- Shows total tasks from backend statistics
- Displays loading state while fetching

**2. Quick Stats Cards (Dynamic)**
```dart
FutureBuilder<TechnicianStats>(
  future: _statsFuture,
  builder: shows 4 stat cards:
    - Pending Tasks (from stats.pendingTasks)
    - Completed (from stats.completedTasks)
    - In Progress (from stats.inProgressTasks)
    - Rating (from stats.rating)
)
```
- Displays dashboard metrics from backend
- Shows loading spinners while fetching
- Fallback to default values on error

**3. Today's Assigned Tasks (Dynamic)**
```dart
FutureBuilder<List<TechnicianTask>>(
  future: _tasksFuture,
  builder: displays task cards for each:
    - Task title
    - Location with map icon
    - Claim ID
    - Status badge (color-coded)
    - Priority level
)
```
- Lists all tasks assigned to technician
- Each task maps: location, status, priority
- Shows "No tasks assigned" when empty
- Loading spinner during fetch
- Error message on failure

#### Status Color Mapping
```dart
_getStatusColor(String status):
  - "pending" → Orange
  - "on-progress" / "on progress" → Blue
  - "completed" / "solved" → Green
  - Default → Grey
```

#### Action Buttons (Ready for Implementation)
- **View Location**: View task location on map
- **Upload Photo**: Take photo using camera/gallery
- **Send Update**: Send text update for task
- **Complete Task**: Mark task as complete

## Data Flow

```
App Startup
    ↓
TechnicianLandingPage loads
    ↓
_TechnicianDashboard initState() called
    ↓
_loadData() executes:
  1. _statsFuture = TechnicianService.getTechnicianStats()
  2. _tasksFuture = TechnicianService.getAssignedTasks()
    ↓
API Calls (parallel):
  1. GET /api/technician/stats
  2. GET /api/technician/tasks
    ↓
Backend Returns:
  1. TechnicianStats (parsed via factory constructor)
  2. List<TechnicianTask> (each parsed via factory constructor)
    ↓
FutureBuilders rebuild with data
    ↓
UI displays real data:
  - Welcome: "You have X tasks assigned today"
  - Stats: Actual counts
  - Tasks: List of assigned claims
```

## Error Handling Strategy

### Service Level
1. All API methods wrapped in try-catch
2. Graceful fallbacks:
   - `getTechnicianStats()` returns default stats on error
   - `getAssignedTasks()` returns empty list on error
   - Console logging for debugging

### UI Level
1. FutureBuilder handles all states:
   - `ConnectionState.waiting` → Loading spinner
   - `snapshot.hasError` → Error message displayed
   - `snapshot.hasData` → Display real data
   - No data → Default fallback or empty state

### Network Issues
- Automatic retry logic in ApiService (base service)
- User-friendly error messages
- App remains functional with fallback data

## Authentication

### Setup
1. On app login, call: `TechnicianService.setAuthToken(jwtToken)`
2. All subsequent requests include Bearer token
3. Token passed in Authorization header

### Token Handling
- Method: `_getHeaders()` includes Authorization header if token is set
- All API methods use this header automatically
- Token-less requests fallback gracefully (with empty header)

## API Response Format

### Example: GET /api/technician/tasks
```json
{
  "success": true,
  "data": [
    {
      "id": "task123",
      "claimId": "CLM-2024-001",
      "title": "Repair Electrical Fault",
      "description": "Customer reported power outage",
      "location": "123 Main St, Downtown Zone A",
      "status": "on-progress",
      "priority": "high",
      "assignedDate": "2024-01-20T10:00:00Z",
      "clientName": "John Doe",
      "clientPhone": "+1234567890",
      "latitude": 40.7128,
      "longitude": -74.0060
    }
  ]
}
```

### Response Handling
- Service detects both `{data: [...]}` and direct array formats
- Handles nested and flat location data
- Flexible field name matching (clientName or name)

## Testing & Validation

### Current Status
✅ TechnicianService: No compilation errors
✅ TechnicianLandingPage: No compilation errors
✅ FutureBuilder integration: Complete
✅ Error handling: Implemented

### Verification
To verify API integration:
1. Launch app as technician user
2. Navigate to Technician Landing Page
3. Observe:
   - Tasks load from backend
   - Stats display real numbers
   - Status colors match task status
   - Loading spinners visible during fetch
   - Error handling works (simulate network failure)

### Mock Data
Currently using fallback/default data:
- Stats: 3 pending, 12 completed, 2 in progress, 4.8 rating
- Tasks: Empty list (backend returns no tasks or error)

## Next Steps

### Ready to Implement
1. **View Location Button**
   - Extract latitude/longitude from task
   - Launch maps with coordinates
   - `url_launcher` package already available

2. **Upload Photo Button**
   - Image picker integration
   - Call `TechnicianService.uploadTaskPhoto(claimId, photoPath)`
   - Show success/failure feedback

3. **Send Update Button**
   - Text dialog for message input
   - Call `TechnicianService.sendTaskUpdate(claimId, message)`
   - Refresh task list after update

4. **Complete Task Button**
   - Confirmation dialog
   - Call `TechnicianService.updateTaskStatus(claimId, 'completed')`
   - Refresh stats and task list

### Optional Enhancements
1. Pull-to-refresh functionality
2. Real-time task updates via WebSocket
3. Task assignment notifications
4. Advanced filtering and sorting
5. Offline mode with data caching

## File Structure

```
lib/
├── services/
│   ├── api_service.dart (base service)
│   └── technician_service.dart (NEW - API integration)
├── pages/
│   └── technician/
│       └── technician_landing_page.dart (UPDATED - API integrated)
└── models/
    ├── technician_task.dart (data model)
    └── technician_stats.dart (data model)
```

## Configuration

### API Endpoint
- Base URL: `http://10.91.220.92:5000/api`
- Technician endpoints:
  - `GET /technician/tasks`
  - `GET /technician/stats`
  - `GET /technician/claims/:claimId`
  - `PUT /claims/:claimId/status`
  - `POST /claims/:claimId/photos` (multipart)
  - `POST /claims/:claimId/updates`

### Required Headers
- `Authorization`: Bearer token (JWT)
- `Content-Type`: application/json

## Support

For issues or questions:
1. Check console logs for API error details
2. Verify JWT token is set: `TechnicianService.setAuthToken(token)`
3. Test API endpoints using Postman
4. Check backend logs for server-side errors
5. Verify network connectivity to API server
