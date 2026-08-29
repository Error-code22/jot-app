# Requirements Document

## Introduction

Jot? is a cross-platform offline-first notes app for Android, Windows, Linux, and macOS built with Flutter. The architecture, data layer, sync engine, and most screens are already implemented. This spec covers the remaining gaps needed to bring the app to a fully functional, production-ready state: Android Firebase Auth, Windows launch stability, image attachments, widget and integration tests, masonry grid re-enablement, TodoService SQLite persistence, ImportService completeness, and notes search/filter.

## Glossary

- **App**: The Jot? Flutter application.
- **AuthService**: The service responsible for Google Sign-In and session management (`lib/services/auth_service.dart`).
- **NoteService**: The service providing note CRUD operations to the UI (`lib/services/note_service.dart`).
- **SyncEngine**: The bidirectional sync orchestrator between local SQLite and remote storage (`lib/services/sync_engine.dart`).
- **TodoService**: The ChangeNotifier managing todo lists and items (`lib/services/todo_service.dart`).
- **LocalStorageService**: The SQLite-backed local persistence service (`lib/services/local_storage_service.dart`).
- **TelegramService**: The remote content storage service using the Telegram Bot API (`lib/services/telegram_service.dart`).
- **ImportService**: The service that parses and imports `.txt` and `.md` files into notes (`lib/services/import_service.dart`).
- **ResponsiveNotesScreen**: The main notes list screen with adaptive desktop/mobile layout (`lib/screens/responsive_notes_screen.dart`).
- **NoteEditorScreen**: The note creation and editing screen (`lib/screens/note_editor_screen.dart`).
- **LoginScreen**: The Google Sign-In entry screen (`lib/screens/login_screen.dart`).
- **SyncIndicator**: The animated sync status widget in the app bar (`lib/widgets/sync_indicator.dart`).
- **MasonryGridView**: The staggered grid layout for the mobile notes list, provided by `flutter_staggered_grid_view`.
- **Note**: The core immutable note entity with fields for id, userId, title, content, type, tags, color, isPinned, isLocked, and telegramMessageId.
- **TodoList**: A named collection of TodoItems owned by a user.
- **TodoItem**: A single checklist entry within a TodoList.
- **ImageAttachment**: A binary image file associated with a Note, stored as a Telegram file upload.
- **Desktop**: Windows or Linux platform.
- **Mobile**: Android platform.
- **LWW**: Last-Write-Wins conflict resolution strategy based on `modifiedAt` timestamp.
- **FFI**: Foreign Function Interface, used by `sqflite_common_ffi` for SQLite on Desktop.
- **firedart**: The pure-Dart Firebase client used on Desktop in place of the native Firebase C++ SDK.
- **firebase_auth**: The native Firebase Auth Flutter plugin used on Mobile.
- **google_sign_in**: The Flutter plugin for Google Sign-In used on Mobile.
- **MockLocalStorageService**: A Mockito-generated mock of `ILocalStorageService` used in unit tests.
- **MockSyncEngine**: A Mockito-generated mock of `ISyncEngine` used in unit tests.

---

## Requirements

### Requirement 1: Android Firebase Authentication

**User Story:** As an Android user, I want to sign in with my Google account, so that my notes are synced to the cloud and accessible across devices.

#### Acceptance Criteria

1. WHEN the user taps "Sign in with Google" on Android, THE AuthService SHALL invoke `google_sign_in` to present the Google account picker.
2. WHEN the user selects a Google account, THE AuthService SHALL exchange the Google credential for a Firebase Auth session using `firebase_auth`.
3. WHEN Firebase Auth returns a valid user, THE AuthService SHALL persist the user's UID, email, display name, and ID token to `FlutterSecureStorage` under the keys `user_id`, `user_email`, `user_display_name`, and `google_id_token` respectively.
4. WHEN Firebase Auth returns a valid user, THE AuthService SHALL emit an `AuthState` with `AuthStatus.authenticated` and the populated `UserModel` on the `authStateChanges` stream.
5. IF the user cancels the Google account picker, THEN THE AuthService SHALL return an `AuthResult` with `success: false` and `errorMessage: "Sign-in cancelled"`.
6. IF `firebase_auth` throws a `FirebaseAuthException` during sign-in, THEN THE AuthService SHALL return an `AuthResult` with `success: false` and `errorMessage` set to the exception's `message` field.
7. IF `google_sign_in` throws any exception during sign-in, THEN THE AuthService SHALL return an `AuthResult` with `success: false` and `errorMessage` set to the exception's string representation.
8. WHEN the App cold-starts on Android and `FlutterSecureStorage` contains a non-empty `user_id` key, THE AuthService SHALL call `FirebaseAuth.instance.currentUser` and, if non-null, emit `AuthStatus.authenticated` without prompting the user to sign in again.
9. WHEN the App cold-starts on Android and `FirebaseAuth.instance.currentUser` is null despite a stored `user_id`, THE AuthService SHALL clear all stored credentials from `FlutterSecureStorage` and emit `AuthStatus.unauthenticated`.
10. WHEN the user signs out on Android, THE AuthService SHALL call `GoogleSignIn.signOut()` and `FirebaseAuth.instance.signOut()`, then delete all keys (`user_id`, `user_email`, `user_display_name`, `google_id_token`, `google_access_token`, `firebase_refresh_token`, `last_login`) from `FlutterSecureStorage`, then emit `AuthStatus.unauthenticated`.
11. IF `FlutterSecureStorage` throws during credential persistence, THEN THE AuthService SHALL log the error and still emit `AuthStatus.authenticated` so the user can use the app for the current session.

---

### Requirement 2: Windows Executable Launch Stability

**User Story:** As a Windows user, I want to launch the Jot? app by double-clicking the executable, so that I can use the app without needing a terminal.

#### Acceptance Criteria

1. WHEN the Windows release executable is launched by double-click, THE App SHALL start and display the loading indicator or the login/notes screen within 10 seconds without a silent crash.
2. WHEN the App starts on Windows, THE App SHALL call `sqfliteFfiInit()` and assign `databaseFactory = databaseFactoryFfi` before `runApp` is called.
3. WHEN the App starts on Windows, THE App SHALL call `fd.Firestore.initialize(projectId)` before any `FirestoreService` method is invoked.
4. IF an unhandled exception occurs during Windows startup (inside `runZonedGuarded`), THEN THE App SHALL append the ISO 8601 timestamp, error string, and stack trace to `jot_crash.log` in the same directory as the executable.
5. WHEN the Windows release build is assembled, THE release directory SHALL contain `sqlite3.dll`, `flutter_windows.dll`, and all plugin DLLs (`flutter_secure_storage_windows_plugin.dll`, `connectivity_plus_windows_plugin.dll`) alongside the executable.
6. THE App SHALL display a `CircularProgressIndicator` centered on a `Scaffold` while `_initializeServices` is executing, and replace it with the routed screen once the `Future` completes.
7. WHEN `firedart` initialization fails on Windows (e.g., invalid API key), THE App SHALL catch the exception, log it to `jot_crash.log`, and continue startup — the app SHALL remain usable in offline mode.

---

### Requirement 3: Image Attachments

**User Story:** As a user, I want to attach images to my notes, so that I can capture visual information alongside my text.

#### Acceptance Criteria

1. WHEN the user taps the image attachment button in the NoteEditorScreen toolbar, THE NoteEditorScreen SHALL invoke `image_picker` to present the image source selection (camera or gallery on Mobile; gallery only on Desktop).
2. WHEN the user selects an image, THE NoteEditorScreen SHALL display a `CircularProgressIndicator` overlay until the upload completes or fails, then dismiss it.
3. WHEN an image is selected and its file size is ≤ 10 MB, THE TelegramService SHALL upload the image file bytes to the configured Telegram chat using the Telegram Bot `sendPhoto` API method.
4. WHEN the Telegram upload succeeds, THE TelegramService SHALL return the Telegram `file_id` string from the largest available `PhotoSize` in the response.
5. WHEN the Telegram upload succeeds, THE NoteEditorScreen SHALL display the image inline within the note content area using the URL resolved from the Telegram Bot `getFile` API.
6. WHEN a note with image attachments is saved, THE NoteService SHALL persist the list of Telegram file IDs (up to 10 per note) as a JSON-encoded array in the Note's `imageIds` field.
7. IF the image upload fails, THEN THE NoteEditorScreen SHALL show a `SnackBar` with the message "Image upload failed: <reason>" and SHALL NOT add any file ID to the note.
8. WHEN a note with image attachments is opened, THE NoteEditorScreen SHALL display all attached images inline by fetching each image URL from the Telegram Bot `getFile` API using the stored file IDs, up to a maximum of 10 images.
9. IF the `getFile` API call fails for an image, THEN THE NoteEditorScreen SHALL display a broken-image placeholder icon for that attachment instead of crashing.
10. WHERE the platform is Desktop (Windows/Linux), THE NoteEditorScreen SHALL pass `ImageSource.gallery` to `image_picker` and SHALL NOT present the camera option.
11. THE Note model SHALL include an `imageIds` field of type `List<String>` serialized as a JSON array in both `toJson`/`fromJson` and `toSqlite`/`fromSqlite`, defaulting to an empty list.
12. IF the selected image file size exceeds 10 MB, THEN THE NoteEditorScreen SHALL show a `SnackBar` with the message "Image too large (max 10 MB)" and SHALL NOT initiate an upload.

---

### Requirement 4: Widget Tests

**User Story:** As a developer, I want widget tests for the core screens and widgets, so that UI regressions are caught automatically during development.

#### Acceptance Criteria

1. THE test suite SHALL contain a widget test for `LoginScreen` that finds a widget with the text "Sign in with Google" and verifies it is tappable (i.e., wrapped in a `GestureDetector` or `InkWell`).
2. THE test suite SHALL contain a widget test for `NoteEditorScreen` that verifies the title `TextField`, the content `TextField`, and the formatting toolbar buttons (bold, italic, underline, and the image attachment button) are all present in the widget tree.
3. THE test suite SHALL contain a widget test for `SyncIndicator` that, for each `SyncStatus` value (`idle`, `syncing`, `success`, `error`, `offline`), verifies the widget renders the expected icon: `idle`/`success` → `Icons.cloud_done_rounded`; `syncing` → `Icons.sync_rounded`; `error`/`offline` → `Icons.cloud_off_rounded`.
4. THE test suite SHALL contain a widget test for `ResponsiveNotesScreen` that provides a list of two mock `Note` objects via a stub `NoteService` stream and verifies both note titles appear in the widget tree.
5. WHEN `SyncIndicator` receives a `SyncState` with `pendingChanges > 0` and `status != SyncStatus.syncing`, THE SyncIndicator SHALL render an orange 6×6 dot badge overlaid on the icon.
6. THE widget tests SHALL inject mock/stub implementations of `AuthService`, `NoteService`, and `SyncEngine` as concrete subtypes via `Provider.value` so that screens can resolve them without real network or storage calls.
7. THE widget tests SHALL pass when run with `flutter test test/widget/` without a connected device or emulator.
8. THE widget test files SHALL be located in `test/widget/` following the naming convention `<screen_or_widget>_test.dart`.

---

### Requirement 5: Integration Tests

**User Story:** As a developer, I want integration tests for the auth and sync flows, so that end-to-end regressions in critical paths are caught automatically.

#### Acceptance Criteria

1. THE test suite SHALL contain an integration test that, after calling a mock `AuthService.signIn()` that returns `AuthResult(success: true)`, verifies that `ResponsiveNotesScreen` is present in the widget tree (i.e., `find.byType(ResponsiveNotesScreen)` succeeds).
2. THE test suite SHALL contain an integration test that, after calling a mock `AuthService.signIn()` that returns `AuthResult(success: false, errorMessage: "Test error")`, verifies that a widget containing the text "Test error" is present in the `LoginScreen` widget tree.
3. THE test suite SHALL contain an integration test that calls `NoteService.createNote(note)` on a stub `NoteService` backed by an in-memory `ILocalStorageService`, then pumps the `ResponsiveNotesScreen` widget, and verifies the note's title appears in the widget tree.
4. THE test suite SHALL contain an integration test that calls `SyncEngine.syncNow()` on a real `SyncEngine` instance wired to mock `ILocalStorageService` and `IRemoteStorageService`, and verifies that `ILocalStorageService.getNotesModifiedAfter` and `IRemoteStorageService.uploadNote` are each called at least once.
5. THE integration tests SHALL inject mock implementations of `ILocalStorageService`, `IRemoteStorageService`, and `IAuthService` (generated via `@GenerateMocks`) to avoid real network or storage calls.
6. THE integration tests SHALL be located in `test/integration/` and be runnable with `flutter test test/integration/`.

---

### Requirement 6: Mock Generation Fix

**User Story:** As a developer, I want all mock files to compile without errors, so that the test suite can be run cleanly.

#### Acceptance Criteria

1. THE `test/unit/mock_generator_test.dart` file SHALL use `@GenerateMocks` annotations that reference only `ILocalStorageService`, `ISyncEngine`, `IRemoteStorageService`, `IAuthService`, and `INoteService` — the interface types, not concrete classes.
2. THE `MockLocalStorageService` generated class SHALL implement every method declared in `ILocalStorageService` with no missing overrides.
3. THE `MockSyncEngine` generated class SHALL implement every method declared in `ISyncEngine` with no missing overrides.
4. WHEN `flutter pub run build_runner build --delete-conflicting-outputs` is run, THE `mock_generator_test.mocks.dart` file SHALL be regenerated without errors.
5. WHEN `flutter test test/unit/` is run, THE test runner SHALL not emit any "undefined class", "missing concrete implementation", or "type mismatch" errors originating from `mock_generator_test.mocks.dart`.
6. THE `@GenerateMocks` annotation file SHALL only import packages that are present in the `dependencies` or `dev_dependencies` section of `pubspec.yaml`.

---

### Requirement 7: Masonry Grid View Re-enablement

**User Story:** As a mobile user, I want to view my notes in a masonry grid layout, so that I can see more notes at a glance with varying content heights.

#### Acceptance Criteria

1. WHEN the user selects "Tiles" view mode in `ResponsiveNotesScreen`, THE ResponsiveNotesScreen SHALL render notes using `MasonryGridView.count` with `crossAxisCount: 2`.
2. WHILE the masonry grid view mode is active, THE ResponsiveNotesScreen SHALL display each note as a `NoteCard` widget showing the note's color, title, content preview (up to 6 lines with ellipsis overflow), and relative timestamp.
3. WHILE the masonry grid view mode is active and a note has a non-null `color` field, THE NoteCard SHALL render with that hex color as its background color.
4. WHILE the masonry grid view mode is active and a note has a null `color` field, THE NoteCard SHALL render with the theme's `colorScheme.surface` as its background color.
5. WHEN the masonry grid is active and the notes list is empty, THE ResponsiveNotesScreen SHALL display the empty state widget (not the grid).
6. WHEN the App is first installed and no `ViewModeProvider` preference is stored, THE ResponsiveNotesScreen SHALL default to the masonry grid ("Tiles") view mode.
7. WHEN the user switches view mode, THE ViewModeProvider SHALL persist the selected mode to `SharedPreferences` under the key `view_mode` and restore it on next launch.
8. IF `SharedPreferences` fails to read the stored view mode on launch, THE ResponsiveNotesScreen SHALL fall back to the masonry grid ("Tiles") view mode.

---

### Requirement 8: TodoService SQLite Persistence

**User Story:** As a user, I want my todo lists to be persisted to the local database, so that they survive app restarts and are available offline.

#### Acceptance Criteria

1. WHEN the user creates a `TodoList`, THE TodoService SHALL call `LocalStorageService.insertTodoList(todoList)` to persist the list to the `todos` SQLite table.
2. WHEN the user adds a `TodoItem` to a list, THE TodoService SHALL call `LocalStorageService.updateTodoList(todoList)` to update the persisted JSON in the `todos` table.
3. WHEN the user toggles a `TodoItem`'s completion state, THE TodoService SHALL call `LocalStorageService.updateTodoList(todoList)` to persist the updated state.
4. WHEN the user deletes a `TodoList`, THE TodoService SHALL call `LocalStorageService.deleteTodoList(id)` to remove the row from the `todos` table.
5. WHEN the App starts and a user is authenticated, THE TodoService SHALL call `LocalStorageService.getTodoListsForUser(userId)` and populate its in-memory list from the returned records, then call `notifyListeners()`.
6. IF `LocalStorageService.getTodoListsForUser` throws during startup, THEN THE TodoService SHALL log the error, leave the in-memory list empty, and call `notifyListeners()` so the UI renders an empty state rather than hanging.
7. IF any `LocalStorageService` write call throws during a todo mutation, THEN THE TodoService SHALL log the error and call `notifyListeners()` with the last known in-memory state (the mutation is rolled back in memory).
8. THE `LocalStorageService` SHALL provide a `todos` table created in the same `onCreate`/migration block as the `notes` table, with columns: `id` TEXT PRIMARY KEY, `userId` TEXT NOT NULL, `data` TEXT NOT NULL (JSON-encoded `TodoList`), `modifiedAt` INTEGER NOT NULL.
9. WHEN the App starts and `SharedPreferences` contains a key matching `todos_<userId>`, THE TodoService SHALL read that value, parse it as a list of `TodoList` objects, write each to the `todos` SQLite table via `LocalStorageService.insertTodoList`, then delete the `todos_<userId>` key from `SharedPreferences`.
10. IF the `SharedPreferences`-to-SQLite migration in criterion 9 fails for any individual `TodoList`, THEN THE TodoService SHALL skip that item, log the error, and continue migrating the remaining items.

---

### Requirement 9: Notes Search and Filter

**User Story:** As a user, I want to search and filter my notes by keyword or tag, so that I can quickly find the note I'm looking for.

#### Acceptance Criteria

1. WHEN the user types 1 or more characters in the search field in `ResponsiveNotesScreen`, THE ResponsiveNotesScreen SHALL filter the displayed notes to those whose title or content contains the search query (case-insensitive substring match).
2. WHEN the search query is cleared (field is empty), THE ResponsiveNotesScreen SHALL display all notes unfiltered.
3. WHEN the user taps a tag chip on a note card, THE ResponsiveNotesScreen SHALL filter the displayed notes to those whose `tags` list contains that exact tag string.
4. WHEN a tag filter is active, THE ResponsiveNotesScreen SHALL display a dismissible `FilterChip` showing the active tag label above the notes list.
5. WHEN the user dismisses the tag filter chip, THE ResponsiveNotesScreen SHALL clear the tag filter and display all notes (subject to any active search query).
6. WHEN both a search query and a tag filter are active, THE ResponsiveNotesScreen SHALL display only notes that satisfy both conditions simultaneously.
7. WHEN the filtered notes list is empty, THE ResponsiveNotesScreen SHALL display the text "No notes match your search" in place of the notes list.
8. THE search field SHALL be present in both the mobile single-pane layout and the desktop two-pane sidebar of `ResponsiveNotesScreen`.
9. THE NoteService SHALL provide a `searchNotes(String userId, String query, {String? tag})` method that returns notes from `LocalStorageService` whose title, content, or tags contain the query string (case-insensitive), optionally filtered to those containing the specified tag.
10. FOR ALL non-empty query strings `q` and user IDs `userId`, every note returned by `searchNotes(userId, q)` SHALL also be present in the list returned by `getAllNotes(userId)` — the search result set SHALL be a strict subset of the full notes list.
11. THE `NoteService.searchNotes` method SHALL include notes whose `tags` list contains the query string as a case-insensitive substring match, in addition to title and content matching.

---

### Requirement 10: ImportService Completeness

**User Story:** As a user, I want to import notes from `.txt` and `.md` files, so that I can migrate my existing notes into Jot?.

#### Acceptance Criteria

1. WHEN the user imports a `.txt` file, THE ImportService SHALL create a Note with the filename (minus extension) as the title and the file content as the body.
2. WHEN the user imports a `.md` file, THE ImportService SHALL create a Note with the filename (minus extension) as the title and the file content as the body.
3. WHEN the user imports a folder, THE ImportService SHALL recursively discover all `.txt`, `.md`, `.text`, and `.markdown` files within the folder and its subdirectories.
4. WHEN a file is imported from a subfolder, THE ImportService SHALL tag the resulting Note with both `"imported"` and the immediate parent subfolder's name as separate tags.
5. WHEN a file is imported from the root import folder (not a subfolder), THE ImportService SHALL tag the resulting Note with `"imported"` only.
6. IF a file cannot be read due to a permission error or encoding error, THEN THE ImportService SHALL increment the `skipped` count in the `ImportResult` and continue processing remaining files without throwing.
7. WHEN the import completes, THE ImportService SHALL return an `ImportResult` with `importedCount` set to the number of successfully created Notes and `skippedCount` set to the number of unreadable files.
8. WHEN the import completes, THE ImportScreen SHALL call `NoteService.refreshNotes(userId)` to trigger a UI update.
9. WHEN building a note title from a filename, THE ImportService SHALL apply the following transformations in order: (1) strip the file extension, (2) remove any trailing Samsung Notes date suffix matching the pattern `_\d{6}_\d{6}`, (3) remove any trailing duplicate number suffix matching the pattern `\s*\(\d+\)`.
10. IF the title is empty after all transformations in criterion 9, THEN THE ImportService SHALL use the string `"Untitled"` as the note title.
11. WHEN a file with valid UTF-8 content but zero bytes is imported, THE ImportService SHALL create a Note with an empty string body (not skip the file).
