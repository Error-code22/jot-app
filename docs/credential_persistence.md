# Credential Persistence Implementation

## Overview

Task 4.2 implements secure credential persistence using `flutter_secure_storage` to enable automatic session restoration on app restart, fulfilling requirements 2.4 and 2.5.

## Requirements

- **Requirement 2.4**: Store authentication credentials securely on the device
- **Requirement 2.5**: Automatically authenticate the user if credentials are valid when the app restarts
- **Requirement 2.6**: Clear stored credentials and local notes when user signs out

## Implementation Details

### Secure Storage

The implementation uses `flutter_secure_storage` which provides platform-specific secure storage:

- **iOS**: Keychain
- **Android**: KeyStore
- **Windows/Linux/macOS**: Platform-specific secure storage

### Stored Credentials

The following data is stored securely after successful authentication:

1. **google_access_token**: Google OAuth access token
2. **google_id_token**: Google OAuth ID token (used for Firebase authentication)
3. **user_id**: Firebase user ID (UID)
4. **user_email**: User's email address
5. **last_login**: Timestamp of last successful login

### Authentication Flow

#### Initial Sign-In

```
User clicks "Sign in with Google"
  ↓
Google Sign-In flow
  ↓
Receive access token & ID token
  ↓
Authenticate with Firebase
  ↓
Store credentials securely ← NEW
  ↓
User is authenticated
```

#### App Restart (Auto-Restore)

```
App starts
  ↓
Call authService.restoreSession() ← NEW
  ↓
Read stored credentials
  ↓
Credentials exist?
  ├─ Yes → Authenticate with Firebase using stored tokens
  │         ↓
  │         Success? → User is authenticated (no login screen)
  │         Failure? → Clear invalid credentials, show login screen
  │
  └─ No → Show login screen
```

#### Sign-Out

```
User clicks "Sign out"
  ↓
Sign out from Google
  ↓
Sign out from Firebase
  ↓
Clear stored credentials ← NEW
  ↓
Clear local notes ← NEW (Task 4.3)
  ↓
User is unauthenticated
```

## Code Changes

### 1. AuthService (`lib/services/auth_service.dart`)

**Added:**
- Storage key constants for credential persistence
- `restoreSession()` method for auto-authentication
- `_storeCredentials()` private method to securely store tokens
- `_clearStoredCredentials()` private method to remove stored tokens
- Optional `LocalStorageService` dependency for clearing notes on sign-out (Task 4.3)

**Modified:**
- `signInWithGmail()` now stores credentials after successful authentication
- `signOut()` now clears stored credentials and local notes (Task 4.3)

### 2. IAuthService Interface (`lib/services/i_auth_service.dart`)

**Added:**
- `restoreSession()` method signature

### 3. Main App (`lib/main.dart`)

**Modified:**
- Added `await authService.restoreSession()` call on app startup

## Testing

### Unit Tests

Created `test/unit/services/auth_service_credential_test.dart`:
- Verifies `restoreSession()` method exists
- Tests that `restoreSession()` returns false when no credentials are stored
- Verifies credential storage methods exist

### Integration Tests

Created `test/integration/credential_persistence_test.dart`:
- Verifies complete credential persistence workflow
- Tests authentication state methods
- Validates storage key structure
- Tests sign-out clears local notes (Task 4.3)
- Tests sign-out works without LocalStorageService (Task 4.3)

### Unit Tests for Sign-Out

Created `test/unit/services/auth_service_signout_test.dart`:
- Tests sign-out clears local notes when LocalStorageService is provided
- Tests sign-out works without error when LocalStorageService is not provided
- Tests sign-out is idempotent (can be called multiple times)

## Security Considerations

1. **Platform Security**: Uses platform-specific secure storage (Keychain, KeyStore)
2. **Token Expiration**: If stored tokens are expired or invalid, they are automatically cleared
3. **Sign-Out Cleanup**: All credentials and local notes are removed on sign-out for security
4. **Error Handling**: Failed restoration attempts clear invalid credentials
5. **Data Privacy**: Local notes are cleared on sign-out to prevent unauthorized access

## Usage Example

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize services
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();
  
  final authService = AuthService(localStorageService: localStorageService);
  
  // Attempt to restore session from stored credentials
  final restored = await authService.restoreSession();
  
  runApp(MyApp(isAuthenticated: restored));
}

// In login screen
final result = await authService.signInWithGmail();
if (result.success) {
  // Credentials are automatically stored
  // Navigate to home screen
}

// In settings screen
await authService.signOut();
// Credentials and local notes are automatically cleared
// Navigate to login screen
```

## Benefits

1. **Improved UX**: Users don't need to sign in every time they open the app
2. **Secure**: Uses platform-specific secure storage mechanisms
3. **Automatic**: No manual credential management required
4. **Robust**: Handles token expiration and invalid credentials gracefully

## Future Enhancements

1. **Token Refresh**: Implement automatic token refresh when access token expires
2. **Biometric Authentication**: Add optional biometric verification before restoring session
3. **Multiple Accounts**: Support storing credentials for multiple accounts
4. **Session Timeout**: Add configurable session timeout for enhanced security
