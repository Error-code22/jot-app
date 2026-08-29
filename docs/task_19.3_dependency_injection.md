# Task 19.3: Dependency Injection Setup

## Overview

This document describes the dependency injection setup for the Jot? Flutter app using the Provider package. All services are properly configured and accessible throughout the widget tree.

## Implementation

### Provider Configuration

The app uses `MultiProvider` in `main.dart` to inject all services at the root level:

```dart
MultiProvider(
  providers: [
    Provider.value(value: authService),
    Provider.value(value: localStorage),
    Provider.value(value: firestoreService),
    Provider.value(value: syncEngine),
    Provider.value(value: noteService),
    StreamProvider.value(
      value: authService.authStateChanges,
      initialData: AuthState(
        status: authService.isAuthenticated() 
            ? AuthStatus.authenticated 
            : AuthStatus.unauthenticated,
        user: authService.getCurrentUser(),
      ),
    ),
  ],
  child: const JotApp(),
)
```

### Injected Services

The following services are available throughout the widget tree:

1. **AuthService** - Manages Gmail authentication via Firebase
   - Used in: LoginScreen, NotesListScreen, NoteEditorScreen
   - Access: `Provider.of<AuthService>(context, listen: false)`

2. **LocalStorageService** - Provides SQLite-based local persistence
   - Used internally by NoteService and SyncEngine
   - Access: `Provider.of<LocalStorageService>(context, listen: false)`

3. **FirestoreService** - Manages Firebase Firestore operations
   - Used internally by SyncEngine
   - Access: `Provider.of<FirestoreService>(context, listen: false)`

4. **SyncEngine** - Synchronizes notes between local and cloud storage
   - Used in: NotesListScreen
   - Access: `Provider.of<SyncEngine>(context, listen: false)`

5. **NoteService** - Manages note CRUD operations
   - Used in: NotesListScreen, NoteEditorScreen
   - Access: `Provider.of<NoteService>(context, listen: false)`

6. **AuthState** (Stream) - Provides reactive authentication state
   - Used in: JotApp (for routing decisions)
   - Access: `Provider.of<AuthState>(context)` (with listen: true for reactivity)

### Service Initialization

Services are initialized in `main()` before the app starts:

1. Firebase is initialized with platform-specific options
2. LocalStorageService is initialized (creates/opens SQLite database)
3. AuthService is initialized and attempts session restoration
4. FirestoreService is initialized
5. SyncEngine is initialized with dependencies
6. NoteService is initialized with dependencies
7. If user is authenticated, SyncEngine is started automatically

### Service Lifecycle Management

The app manages service lifecycle through auth state changes:

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

### Usage Examples

#### Accessing Services in Screens

```dart
// In LoginScreen
final authService = Provider.of<AuthService>(context, listen: false);
final result = await authService.signInWithGmail();

// In NotesListScreen
final noteService = Provider.of<NoteService>(context, listen: false);
final syncEngine = Provider.of<SyncEngine>(context, listen: false);

// In NoteEditorScreen
final noteService = Provider.of<NoteService>(context, listen: false);
await noteService.updateNote(noteId, title, content);
```

#### Listening to Auth State Changes

```dart
// In JotApp build method
final authState = Provider.of<AuthState>(context); // listen: true by default

return MaterialApp(
  routes: {
    '/': (context) => authState.isAuthenticated 
        ? const NotesListScreen() 
        : const LoginScreen(),
  },
);
```

## Service Dependencies

The services have the following dependency relationships:

```
NoteService
  ├── LocalStorageService
  └── SyncEngine
      ├── LocalStorageService
      └── FirestoreService

AuthService (independent)
```

All dependencies are properly injected through constructor parameters, ensuring:
- Testability (services can be mocked)
- Loose coupling (services depend on interfaces)
- Single responsibility (each service has a clear purpose)

## Services Not Yet Injected

The following services exist but are not currently injected because they're not used in the UI:

1. **ConfigService** - Manages IDE collaboration configuration
   - Will be injected when IDE collaboration features are implemented

2. **ProgressService** - Manages append-only progress tracking
   - Will be injected when progress tracking UI is implemented

These services can be added to the MultiProvider when needed:

```dart
Provider.value(value: configService),
Provider.value(value: progressService),
```

## Testing

Comprehensive widget tests verify the dependency injection setup:

- `test/widget/dependency_injection_test.dart`
  - Verifies all services are accessible via Provider
  - Verifies services maintain singleton behavior
  - Verifies services are accessible in nested widgets
  - Verifies AuthState stream provides initial data

All tests pass successfully, confirming the dependency injection is working correctly.

## Requirements Validation

This implementation satisfies the following requirements:

- **Requirement 1.1, 1.2, 1.3**: NoteService is injected and accessible for note CRUD operations
- **Requirement 2.1**: AuthService is injected and accessible for Gmail authentication
- **Requirement 3.1**: SyncEngine and FirestoreService are injected for cloud sync

## Best Practices

The implementation follows Flutter and Provider best practices:

1. **Provider.value** is used instead of Provider because services are created outside the widget tree
2. **listen: false** is used when accessing services for one-time operations (prevents unnecessary rebuilds)
3. **StreamProvider** is used for reactive auth state (automatically rebuilds dependent widgets)
4. Services are initialized before runApp() to ensure they're ready when the app starts
5. Error handling is implemented for service initialization failures
6. Service lifecycle is managed based on authentication state

## Conclusion

The dependency injection setup is complete and working correctly. All required services are properly injected and accessible throughout the widget tree. The implementation uses Provider effectively to manage service instances and provide reactive state updates where needed.
