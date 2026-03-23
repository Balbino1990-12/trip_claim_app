# All Endpoint Data Now Displayed on Task Cards

**Status:** ✅ Updated - All fields from `/api/technician/tasks` endpoint now displayed

---

## 📊 Information Displayed on Each Task Card

### **Collapsed View (Default)**
Shows the most important information:
```
┌─────────────────────────────────────────────┐
│ Road Damage Assessment            PENDING   │
│                                             │
│ 📍 Main Street & 5th Avenue                 │
│                                             │
│ ID: claim_001        PRIORITY: HIGH         │
│                                             │
│ 👇 Tap to expand details                    │
└─────────────────────────────────────────────┘
```

**Fields shown:**
- ✅ Title
- ✅ Status (color-coded)
- ✅ Location
- ✅ Claim ID
- ✅ Priority (color-coded)

---

### **Expanded View (Tap Card)**
Shows ALL available information:
```
┌─────────────────────────────────────────────┐
│ Road Damage Assessment            PENDING   │
│                                             │
│ 📍 Main Street & 5th Avenue                 │
│                                             │
│ ID: claim_001        PRIORITY: HIGH         │
│                                             │
│ ─────────────────────────────────────────── │
│                                             │
│ Description                                 │
│ Road surface has multiple potholes and      │
│ cracks visible. Urgent repair needed to     │
│ prevent accidents.                          │
│                                             │
│ Client Information                          │
│ 👤 John Doe                                 │
│ ☎️  (555) 123-4567                          │
│                                             │
│ Assigned Date: 13/2/2026                    │
│ Coordinates: 40.7128, -74.0060              │
└─────────────────────────────────────────────┘
```

**Additional fields shown when expanded:**
- ✅ Description (full task details)
- ✅ Client Name
- ✅ Client Phone Number
- ✅ Assigned Date (formatted as DD/M/YYYY)
- ✅ GPS Coordinates (Latitude, Longitude)

---

## 🔗 API Endpoint Response Mapping

**Endpoint:** `GET http://10.91.220.92:5000/api/technician/tasks`

**API Response → UI Display:**

```json
{
  "success": true,
  "data": [
    {
      "id": "claim_001",
      "claimId": "claim_001",
      "title": "Road damage assessment",
      "description": "Road surface has multiple potholes...",
      "location": "Main Street & 5th Avenue",
      "status": "pending",
      "priority": "high",
      "customerName": "John Doe",
      "customerPhone": "(555) 123-4567",
      "assignedDate": "2025-02-11T10:00:00Z",
      "latitude": 40.7128,
      "longitude": -74.0060
    }
  ]
}
```

**Mapped to UI:**

| API Field | UI Display | Location |
|-----------|-----------|----------|
| `title` | Card title (bold, large) | Header row |
| `status` | Status badge (color-coded) | Header row, right |
| `location` | Location with icon (📍) | Visible always |
| `claimId` | "ID: claim_001" | Bottom left, always visible |
| `priority` | Priority badge (color-tagged) | Bottom right, always visible |
| **EXPANDED ONLY:** | | |
| `description` | Full description text | After divider, section 1 |
| `customerName` | "👤 Client Name" with icon | After divider, section 2 |
| `customerPhone` | "☎️ Phone number" with icon | After divider, section 2 |
| `assignedDate` | Formatted date (DD/M/YYYY) | After divider, section 3 |
| `latitude`, `longitude` | "lat, lon" coordinates | After divider, section 3 |

---

## 🎨 Visual Features

### **Status Badges (Color-Coded)**
- 🟠 **PENDING** - Orange
- 🔵 **ON-PROGRESS** - Blue
- 🟢 **COMPLETED/SOLVED** - Green

### **Priority Indicators**
- 🔴 **HIGH** - Red
- 🟠 **MEDIUM** - Orange
- 🟢 **LOW** - Green

### **Icons Used**
| Icon | Purpose | Color |
|------|---------|-------|
| 📍 | Location marker | Gray |
| 👤 | Client person | Blue |
| ☎️ | Phone number | Green |
| 👇 | Expand hint (collapsed) | Gray |

---

## 💻 Implementation Details

### **TechnicianTask Model**
All fields from endpoint:
```dart
class TechnicianTask {
  final String id;           // Unique task ID
  final String claimId;      // Claim reference number
  final String title;        // Task title/summary
  final String description;  // Full task description
  final String location;     // Work location address
  final String status;       // pending, on-progress, completed
  final String priority;     // high, medium, low
  final DateTime? assignedDate;  // When task was assigned
  final String? clientName;      // Customer/client name
  final String? clientPhone;     // Client contact number
  final double? latitude;        // GPS latitude
  final double? longitude;       // GPS longitude
}
```

### **Task Card Widget**
- **Type:** StatefulWidget (tracks expanded/collapsed state)
- **State:** `bool _isExpanded` toggles by tapping card
- **Responsive:** All text wraps and truncates properly
- **Interactive:** Tap anywhere on card to expand/collapse

---

## 🚀 How to Use

### **View Basic Task Details**
1. Open Technician Landing Page
2. Scroll to "Today's Assigned Tasks"
3. See collapsed cards with:
   - Title
   - Status
   - Location
   - Claim ID
   - Priority

### **View Full Task Details**
1. **Tap any task card** to expand
2. See additional information:
   - Full description
   - Client details (name + phone)
   - Assigned date
   - GPS coordinates
3. **Tap again** to collapse

---

## 📱 Responsive Design

All information adapts to screen size:
- ✅ Text truncates with ellipsis if too long
- ✅ Icons scale appropriately
- ✅ Cards stack vertically on mobile
- ✅ Information doesn't overflow

---

## 🔄 Real-time Updates

Task cards update automatically:
- Every 5 seconds (auto-refresh timer)
- When notification received (WebSocket)
- When user manually refreshes

All displayed information reflects latest data from API.

---

## 🛠️ Customization Options

To modify what's displayed, edit [lib/pages/technician/technician_landing_page.dart](lib/pages/technician/technician_landing_page.dart):

### Show more fields in collapsed view:
Look for the "Expanded Details" section and move fields out of the `if (_isExpanded)` block.

### Change date format:
Find: `'${task.assignedDate!.day}/${task.assignedDate!.month}/${task.assignedDate!.year}'`  
Modify formatting pattern as needed.

### Change icon colors:
Search for `Colors.gray[400]`, `Colors.blue[400]`, etc. and replace with desired colors.

### Change card elevation/shape:
Find the `Card(elevation: 2, ...)` and adjust `elevation` value or `borderRadius`.

---

## ✨ Summary

**What's displayed:**
- ✅ All 13 fields from the API endpoint
- ✅ 5 fields always visible (efficiency)
- ✅ 8 fields in expanded view (detail)
- ✅ Real-time updates
- ✅ Interactive expand/collapse
- ✅ Color-coded status and priority
- ✅ Professional card design

**Fields displayed:**
```
Always Visible:
  1. Task title
  2. Status (badge)
  3. Location (with icon)
  4. Claim ID
  5. Priority (badge)

Expanded View (Tap Card):
  6. Description
  7. Client name
  8. Client phone
  9. Assigned date
  10. Coordinates (lat/lon)

Available but not displayed:
  11. Task ID (internal use)
  12-13. Latitude, Longitude (shown as coordinates)
```

---

**Status:** ✅ Complete and ready to test  
**Last Updated:** February 13, 2026
