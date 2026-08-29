# Task 19.2: App Routing Implementation

## Overview

This task implements proper app routing to navigate between LoginScreen and NotesListScreen based on authentication state, fulfilling Requirement 2.5.

## Requirements Validated

- **Requirement 2.5**: When the Jot_App restarts, the Gmail_Auth shall automatically authenticate the user if credentials are valid

## Implementation Details

### Routing Configuration

The app routing is implemented in `lib/main.dart` using Flutter's `MaterialApp` with named routes:

```dart
MaterialApp(
  title: 'Jot?',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    useMaterial3: true,
  ),
  routes: {
    '/': (context) => authState.isAuthenticated 
        ? const NotesListScreen() 
        : const LoginScreen(),
    '/notes': (context) => const NotesListScreen(),
    '/login': (context) => const LoginScreen(),
  },
  initialRoute: '/',
)
```

### Key Features

1. **Dynamic Initial Route**: The home route (`/`) dynamically shows either `NotesListScreen` or `LoginScreen` based on the current authentication state from the `StreamProvider<AuthState>`.

2. **Authentication State Management**: 
   - Uses `StreamProvider` to provide authentication state throughout the widget tree
   - The `authStateChanges` stream from `AuthService` automatically updates the UI when auth state changes
   - Initial data is set based on the result of session restoration in `main()`

3. **Session Restoration**: 
   - On app startup, `authService.restoreSession()` is called to restore any previously saved credentials
   - If restoration succeeds, the user is automatically authenticated
   - The sync engine is started automatically for authenticated users

4. **Sync Engine Lifecycle Management**:
   - A listener is set up in `_JotAppState.initState()` to manage the sync engine lifecycle
   - When user signs in: sync engine starts automatically
   - When user signs out: sync engine stops automatically

### Navigation Flow

```
App Start
    ↓
Firebase Init
    ↓
Services Init
    ↓
Session Restoration (authService.restoreSession())
    ↓
    ├─→ Credentials Found & Valid → Authenticated
    │                                    ↓
    │                              Start Sync Engine
    │                                    ↓
    │                              Show NotesListScreen
    │
    └─→ No Credentials / Invalid → Unauthenticated
                                        ↓
                                   Show LoginScreen
```

### Route Definitions

- **`/` (Home)**: Dynamic route that shows the appropriate screen based on auth state
  - Authenticated: `NotesListScreen`
  - Unauthenticated: `LoginScreen`

- **`/notes`**: Direct route to `NotesListScreen` (used after successful login)

- **`/login`**: Direct route to `LoginScreen` (used after sign out)

### Authentication State Listener

The app sets up an authentication state listener in `_JotAppState` to manage the sync engine lifecycle:

```dart
void _setupAuthStateListener() {
  final authService = Provider.of<AuthService>(context, listen: false);
  final syncEngine = Provider.of<SyncEngine>(context, listen: false);

  authService.authStateChanges.listen((authState) async {
    if (authState.isAuthenticated && authState.user != null) {
      // User signed in - start sync engine
      await syncEngine.start(authState.user!.uid);
    } else {
      // User signed out - stop sync engine
      await syncEngine.stop();
    }
  });
}
```

## Testing

### Widget Tests

Created comprehensive widget tests in `test/widget/app_routing_test.dart`:

1. **Unauthenticated State Test**: Verifies that `LoginScreen` is shown when user is not authenticated
2. **Authenticated State Test**: Verifies that `NotesListScreen` is shown when user is authenticated
3. **Route Navigation Tests**: Verifies that named routes (`/notes`, `/login`) work correctly
4. **Initial Route Test**: Verifies that the initial route is `/` and shows the correct screen

All tests use mock services to isolate routing logic from actual service implementations.

### Test Results

```
✓ shows LoginScreen when user is not authenticated
✓ shows NotesListScreen when user is authenticated
✓ navigates to /notes route correctly
✓ navigates to /login route correctly
✓ initial route is / (home)
```

## Files Modified

- `lib/main.dart`: Already had routing implementation, verified it works correctly
- `test/widget/app_routing_test.dart`: Created comprehensive routing tests

## Integration with Other Components

### LoginScreen
- On successful authentication, navigates to `/notes` using `Navigator.of(context).pushReplacementNamed('/notes')`
- This triggers the auth state change, which updates the UI

### NotesListScreen
- On sign out, navigates to `/login` using `Navigator.of(context).pushReplacementNamed('/login')`
- Includes a check that redirects to login if user is null (defensive programming)

### AuthService
- Provides `authStateChanges` stream that the app listens to
- Implements `restoreSession()` for automatic authentication on app restart
- Session restoration happens before the app UI is built

## Verification

The routing implementation correctly satisfies Requirement 2.5:

✅ **Automatic Authentication**: When the app restarts, `authService.restoreSession()` is called, which attempts to restore credentials from secure storage. If valid credentials exist, the user is automatically authenticated.

✅ **Correct Initial Screen**: Based on the authentication state after session restoration, the app shows:
- `NotesListScreen` if authenticated (user has valid credentials)
- `LoginScreen` if unauthenticated (no credentials or invalid credentials)

✅ **Sync Engine Management**: The sync engine automatically starts when authenticated and stops when unauthenticated, ensuring proper synchronization lifecycle.

✅ **Reactive Navigation**: The app responds to authentication state changes in real-time through the `StreamProvider`, ensuring the UI always reflects the current auth state.

## Conclusion

Task 19.2 is complete. The app routing is properly configured to:
1. Show the correct initial screen based on authentication state
2. Support automatic authentication on app restart via session restoration
3. Navigate between screens based on user actions (login, logout)
4. Manage the sync engine lifecycle based on authentication state
5. Provide a seamless user experience across app restarts

The implementation is tested and verified to work correctly.
