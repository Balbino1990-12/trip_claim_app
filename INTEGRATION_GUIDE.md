# Trip Claim App - Integration Guide

## Features Implemented

### 1. **Environment Configuration** (`lib/config/app_config.dart`)
- Centralized API URL management
- Support for development, staging, and production environments
- Easy endpoint configuration

### 2. **API Service** (`lib/services/api_service.dart`)
- Structured API responses with generics
- Timeout handling (30 seconds)
- Network error detection
- Automatic Bearer token injection
- Single and batch image uploads
- GET requests for retrieving claims

### 3. **Local Storage Service** (`lib/services/local_storage_service.dart`)
**Features:**
- Cache trip claims locally
- Mark claims as synced/unsynced
- Retrieve unsynced claims
- Save/retrieve user phone and tokens
- Storage statistics
- Clear cache when needed

### 4. **Offline Sync Manager** (`lib/services/offline_sync_manager.dart`)
**Features:**
- Sync all pending claims at once
- Sync individual claims by index
- Get sync status and details
- Clear synced claims
- SyncResult class for structured responses

### 5. **Login Page Integration** (`lib/pages/login/login_page.dart`)
**Features:**
- API URL configuration (hidden by default)
- API Settings toggle button
- Auto-initializes with default API URL
- Token setting after successful login
- Loading state during login
- Error handling

### 6. **API Settings Page** (`lib/pages/settings/api_settings_page.dart`)
**Features:**
- Manage API URL dynamically
- Add/save/clear authentication tokens
- Reset to default configuration
- View current configuration
- Beautiful card-based UI

### 7. **Profile Page Enhancements** (`lib/pages/profile/profile_page.dart`)
**New Features:**
- API Settings button (navigates to API Settings page)
- Offline Claims button (shows claim statistics and pending items)
- Logout clears all local data
- Improved logout flow

### 8. **Trip Claim Page Integration** (`lib/pages/trip_claim/trip_claim_page.dart`)
**Features:**
- Offline claim caching on failure
- Automatic local storage when API is unavailable
- Proper error handling with fallback to local storage
- Uses stored user phone from local storage
- Progress bar with percentage for location capture

## How to Use

### Setup (One-time)

1. **Set API URL after app start:**
```dart
// In main.dart or app initialization
ApiService.setBaseUrl(AppConfig.getApiUrl());
```

2. **After successful login:**
```dart
// Store user phone
await LocalStorageService.saveUserPhone(userPhone);

// Store authentication token
ApiService.setAuthToken(loginToken);
await LocalStorageService.saveToken(loginToken);
```

3. **On logout:**
```dart
// Already handled in profile page
// Clears token and user phone
```

### Using Offline Features

1. **Check sync status:**
```dart
final status = await OfflineSyncManager.getSyncStatus();
print('Pending claims: ${status['unsyncedClaims']}');
```

2. **Sync all pending claims:**
```dart
final result = await OfflineSyncManager.syncAllClaims();
if (result.success) {
  print('All claims synced!');
} else {
  print('Sync failed: ${result.message}');
}
```

3. **Sync a single claim:**
```dart
final result = await OfflineSyncManager.syncClaimByIndex(0);
```

### API Settings Page

Access from Profile Page → API Settings

**Features:**
- View current API URL
- Change API URL for testing/deployment
- Add/remove authentication tokens
- Reset to default configuration

### Offline Claims View

Access from Profile Page → Offline Claims

**Shows:**
- Total number of claims
- Number of synced claims
- Number of pending claims
- List of unsynced claims
- "Sync Now" button (when offline claims exist)

## Dependencies Added

```yaml
dependencies:
  http: ^1.1.0              # HTTP requests
  shared_preferences: ^2.2.2 # Local storage
  geolocator: ^14.0.2        # Location services
  image_picker: ^1.2.1       # Image selection
  url_launcher: ^6.3.2       # URL opening
```

## File Structure

```
lib/
├── config/
│   └── app_config.dart              # Environment configuration
├── services/
│   ├── api_service.dart             # API communication
│   ├── local_storage_service.dart   # Local caching
│   └── offline_sync_manager.dart    # Offline sync logic
├── pages/
│   ├── login/
│   │   └── login_page.dart         # Login with API config
│   ├── profile/
│   │   └── profile_page.dart       # Profile with settings/offline
│   ├── settings/
│   │   └── api_settings_page.dart  # API configuration UI
│   └── trip_claim/
│       └── trip_claim_page.dart    # Trip claim with offline support
└── main.dart                         # App entry point
```

## Testing Offline Functionality

1. **Test Local Caching:**
   - Submit a claim when API is unavailable (turn off internet)
   - Claim will be saved locally
   - View in Profile → Offline Claims

2. **Test Sync:**
   - Turn internet back on
   - Go to Profile → Offline Claims → Sync Now
   - Or use `OfflineSyncManager.syncAllClaims()` in code

3. **Test API URL Change:**
   - Go to Login page → API Settings
   - Change the URL
   - Submit a claim to test with new URL

## Important Notes

⚠️ **Before Deployment:**
1. Update `AppConfig.productionApiUrl` with your actual API endpoint
2. Configure token refresh logic if tokens expire
3. Implement actual login API call (currently simulated)
4. Add proper error logging for production

## Future Enhancements

Possible improvements:
- Automatic sync when connection is restored
- Claim encryption in local storage
- Claim expiration (delete after X days)
- Retry backoff strategy for failed syncs
- Cloud backup for cached claims
