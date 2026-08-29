# Implementation Plan: Jot? App Completion

## Overview

This plan converts the ten design areas into discrete, incremental coding tasks. Each task builds on the previous ones, ending with full integration. The implementation language is Dart/Flutter. Tasks are ordered so that foundational changes (model extensions, interface additions, schema migrations) land before the service and UI layers that depend on them.

## Tasks

- [x] 1. Fix mock generation and extend interfaces
  - [x] 1.1 Rewrite `test/unit/mock_generator_test.dart` to use interface types
    - Replace all concrete class imports (`LocalStorageService`, `SyncEngine`, `FirestoreService`, `AuthService`, `Connectivity`, `FlutterSecureStorage`, `GoogleSignIn`, `FirebaseAuth`, `User`, `UserMetadata`, `AuthCredential`) with interface imports (`ILocalStorageService`, `ISyncEngine`, `IRemoteStorageService`, `IAuthService`, `INoteService`)
    - Remove imports of `firebase_auth`, `google_sign_in`, `flutter_secure_storage`, and `connectivity_plus` from this file
    - Update `@GenerateMocks` annotation to list only the five interface types
    - _Requirements: 6.1, 6.2, 6.3, 6.6_

  - [x] 1.2 Extend `INoteService` with `searchNotes` signature
    - Add `Future<List<Note>> searchNotes(String userId, String query, {String? tag})` to `lib/services/i_note_service.dart`
    - _Requirements: 9.9_

  - [x] 1.3 Extend `ILocalStorageService` with todo CRUD signatures
    - Add `insertTodoList`, `updateTodoList`, `deleteTodoList`, and `getTodoListsForUser` method declarations to `lib/services/i_local_storage_service.dart`
    - Import `TodoList` from `../models/todo_model.dart`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 1.4 Extend `IRemoteStorageService` with image upload signatures
    - Add `Future<String> uploadImage(Uint8List bytes, String filename)` and `Future<String> getImageUrl(String fileId)` to `lib/services/i_remote_storage_service.dart`
    - Import `dart:typed_data`
    - _Requirements: 3.3, 3.4_

  - [ ]* 1.5 Run `flutter pub run build_runner build --delete-conflicting-outputs` and verify `mock_generator_test.mocks.dart` regenerates without errors
    - Confirm no "undefined class", "missing concrete implementation", or "type mismatch" errors
    - _Requirements: 6.4, 6.5_

- [x] 2. Extend the Note model with `imageIds`
  - [x] 2.1 Add `imageIds` field to `Note` in `lib/models/note_model.dart`
    - Add `final List<String> imageIds` field defaulting to `const []`
    - Update the constructor, `copyWith`, `toJson`, `fromJson`, `toSqlite`, and `fromSqlite` to include `imageIds` (JSON-encoded array in SQLite)
    - _Requirements: 3.11_

  - [ ]* 2.2 Write property test for `Note.imageIds` serialization round-trip (Property 2)
    - Add `glados: ^0.5.0` to `pubspec.yaml` dev_dependencies
    - Create `test/unit/models/note_model_test.dart`
    - Use `Glados<List<String>>()` to generate arbitrary `imageIds` lists (capped at 10)
    - Assert `Note.fromJson(note.toJson()).imageIds == note.imageIds` and the same for `fromSqlite(toSqlite())`
    - **Property 2: Note imageIds serialization round-trip**
    - **Validates: Requirements 3.11**
    - _Requirements: 3.11_

- [ ] 3. SQLite schema migration (version 7)
  - [x] 3.1 Add `imageIds` column migration and `todos` table to `LocalStorageService`
    - Bump database version to 7 in `lib/services/local_storage_service.dart`
    - In `onUpgrade`, add `ALTER TABLE notes ADD COLUMN imageIds TEXT` for `oldVersion < 7`
    - In `onCreate` and `onUpgrade` (version 7), create the `todos` table:
      ```sql
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        data TEXT NOT NULL,
        modifiedAt INTEGER NOT NULL
      );
      CREATE INDEX idx_todos_userId ON todos (userId);
      ```
    - _Requirements: 3.11, 8.8_

  - [x] 3.2 Implement todo CRUD methods on `LocalStorageService`
    - Implement `insertTodoList`, `updateTodoList`, `deleteTodoList`, and `getTodoListsForUser` in `lib/services/local_storage_service.dart`
    - Serialize `TodoList` to/from JSON for the `data` column; store `modifiedAt` as milliseconds since epoch
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.8_

- [x] 4. Harden Android Firebase Authentication in `AuthService`
  - [x] 4.1 Fix stale-credential cleanup in `_restoreMobileSessionStub`
    - When `FirebaseAuth.instance.currentUser` is null but a stored `user_id` exists, call `_clearStoredCredentials()` and emit `AuthStatus.unauthenticated` instead of falling back to stored credentials
    - _Requirements: 1.9_

  - [x] 4.2 Add `FirebaseAuth.instance.signOut()` to mobile `signOut` path
    - In `signOut()`, when `!_isDesktop`, call `fb_auth.FirebaseAuth.instance.signOut()` in addition to `GoogleSignIn().signOut()`
    - _Requirements: 1.10_

  - [x] 4.3 Wrap `FlutterSecureStorage` writes in try/catch in `_signInMobile`
    - Surround each `_storage.write(...)` call in `_signInMobile` with individual try/catch blocks that log the error via `debugPrint` and continue
    - Ensure `AuthStatus.authenticated` is still emitted even if storage writes fail
    - _Requirements: 1.11_

  - [x] 4.4 Fix `signInWithGmail` error handling for `FirebaseAuthException` and `GoogleSignIn` exceptions
    - Catch `fb_auth.FirebaseAuthException` separately and return `AuthResult(success: false, errorMessage: e.message)`
    - Catch cancellation (null `googleUser`) and return `AuthResult(success: false, errorMessage: "Sign-in cancelled")`
    - _Requirements: 1.5, 1.6, 1.7_

- [x] 5. Fix Windows executable launch stability in `main.dart`
  - [x] 5.1 Replace placeholder firedart API key with real key from `firebase_options.dart`
    - Replace `'AIzaSyBqNw3m9c8Z3qR7Y8X9Z0a1b2c3d4e5f6g'` with the actual `apiKey` from `DefaultFirebaseOptions.currentPlatform` (or a dedicated desktop options object)
    - _Requirements: 2.3_

  - [x] 5.2 Fix crash log path to use executable directory
    - In the `runZonedGuarded` error handler, replace `File('jot_crash.log')` with `File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}jot_crash.log')`
    - _Requirements: 2.4_

  - [x] 5.3 Wrap firedart initialization failure to continue in offline mode
    - The existing try/catch around `fd.FirebaseAuth.initialize` and `fd.Firestore.initialize` already catches and logs; verify it also writes to `jot_crash.log` on failure and does not rethrow
    - _Requirements: 2.7_

- [ ] 6. Implement `NoteService.searchNotes`
  - [ ] 6.1 Add `searchNotes` implementation to `NoteService`
    - Implement `searchNotes(String userId, String query, {String? tag})` in `lib/services/note_service.dart`
    - Fetch all notes via `_local.getAllNotes(userId)`, then filter in-memory: title, content, or any tag element contains `query` (case-insensitive); optionally filter by exact tag match
    - _Requirements: 9.9, 9.10, 9.11_

  - [ ]* 6.2 Write property tests for search correctness (Properties 8, 9, 10)
    - Create `test/unit/note_service_search_test.dart`
    - **Property 8: Search results are a subset of all notes** — for any non-empty query, every result also appears in `getAllNotes`
    - **Property 9: Search filter correctness** — every result has title/content/tag containing the query (case-insensitive); non-matching notes are excluded
    - **Property 10: Combined search and tag filter intersection** — every result satisfies both text and tag conditions simultaneously
    - Use `Glados2<List<Note>, String>()` with `assume(query.isNotEmpty)`
    - **Validates: Requirements 9.1, 9.6, 9.9, 9.10, 9.11**
    - _Requirements: 9.1, 9.6, 9.9, 9.10, 9.11_

- [ ] 7. Refactor `TodoService` to use SQLite persistence
  - [ ] 7.1 Update `TodoService.initialize` to accept `ILocalStorageService` and migrate from `SharedPreferences`
    - Change `initialize(String userId)` signature to `initialize(String userId, ILocalStorageService storage)` in `lib/services/todo_service.dart`
    - Store `_storage` reference; implement `_migrateFromSharedPreferences()` that reads `todos_<userId>` from `SharedPreferences`, writes each `TodoList` via `_storage.insertTodoList`, then deletes the key; catch and log individual item failures without aborting
    - Replace `_load()` to call `_storage.getTodoListsForUser(userId)` instead of `SharedPreferences`; on error, log and call `notifyListeners()` with empty list
    - _Requirements: 8.5, 8.6, 8.9, 8.10_

  - [ ] 7.2 Replace `_save()` with per-mutation SQLite calls and rollback on failure
    - Remove the `_save()` / `SharedPreferences` method
    - In each mutation method (`createList`, `updateList`, `deleteList`, `addItem`, `updateItem`, `toggleItem`, `deleteItem`, `clearCompleted`, `reorderItems`): snapshot the previous state, apply the in-memory change, call the appropriate `_storage` method, and on exception roll back to the snapshot, log the error, and call `notifyListeners()`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.7_

  - [ ] 7.3 Update `main.dart` to pass `ILocalStorageService` to `TodoService.initialize`
    - In the `ChangeNotifierProvider` for `TodoService` inside `_runApp`, pass `providers['localStorage']` as the second argument to `svc.initialize(user.uid, localStorage)`
    - _Requirements: 8.5_

  - [ ]* 7.4 Write property test for `TodoService` mutation rollback on storage failure (Property 6)
    - Create `test/unit/todo_service_test.dart`
    - Use a mock `ILocalStorageService` that throws on write calls
    - For each mutation type, assert the in-memory list is identical before and after the failed mutation
    - **Property 6: TodoService mutation rollback on storage failure**
    - **Validates: Requirements 8.7**
    - _Requirements: 8.7_

- [ ] 8. Implement notes search and tag filter UI in `ResponsiveNotesScreen`
  - [ ] 8.1 Add `_tagFilter` state and `_applyFilters` helper to `ResponsiveNotesScreen`
    - Add `String? _tagFilter` field to `_ResponsiveNotesScreenState`
    - Implement `_applyFilters(List<Note> notes)` that applies both `_searchQuery` and `_tagFilter` (case-insensitive substring for search; exact match for tag)
    - Replace the inline search filter in `_NotesListPane` and `_buildMobileLayout` with calls to `_applyFilters`
    - _Requirements: 9.1, 9.2, 9.6_

  - [ ] 8.2 Add `onTagTap` callback to `_NoteCard` and `_NoteListTile` and wire tag filter
    - Add `final void Function(String tag)? onTagTap` parameter to `_NoteCard` and `_NoteListTile`
    - In the tags `Wrap` inside each card, wrap each tag `Text` in a `GestureDetector` that calls `onTagTap`
    - In `_buildNotesView` and `_NotesListPane`, pass `onTagTap: (tag) => setState(() => _tagFilter = tag)`
    - _Requirements: 9.3_

  - [ ] 8.3 Add dismissible `FilterChip` row above the notes list when a tag filter is active
    - In both mobile and desktop layouts, render a `Wrap` containing a `FilterChip` with `label: Text('#$_tagFilter')` and `onDeleted: () => setState(() => _tagFilter = null)` when `_tagFilter != null`
    - _Requirements: 9.4, 9.5_

  - [ ] 8.4 Show "No notes match your search" empty state when filtered list is empty
    - In `_buildNotesView` and `_NotesListPane`, after applying filters, if the filtered list is empty and either `_searchQuery` or `_tagFilter` is non-null/non-empty, render a centered `Text('No notes match your search')` instead of the grid/list
    - _Requirements: 9.7_

- [ ] 9. Implement image attachments
  - [x] 9.1 Add `uploadImage` and `getImageUrl` to `TelegramService`
    - Implement `uploadImage(Uint8List bytes, String filename)` using `package:http` multipart POST to `https://api.telegram.org/bot{token}/sendPhoto` with `chat_id` and `photo` fields; parse `result.photo[-1].file_id` from the JSON response
    - Implement `getImageUrl(String fileId)` using `package:http` GET to `https://api.telegram.org/bot{token}/getFile?file_id={fileId}`; return `https://api.telegram.org/file/bot{token}/{file_path}`
    - _Requirements: 3.3, 3.4_

  - [ ] 9.2 Add image attachment button and upload flow to `NoteEditorScreen` toolbar
    - Add an attachment `IconButton` (icon: `Icons.attach_file_rounded`) to `_buildToolbar()`
    - On tap: call `ImagePicker().pickImage(source: ImageSource.gallery)` on desktop, or show a source dialog (camera/gallery) on mobile using `Platform.isAndroid`
    - Check file size ≤ 10 MB; if exceeded, show SnackBar "Image too large (max 10 MB)" and return
    - Show a `CircularProgressIndicator` overlay while uploading
    - On success: add the returned `file_id` to `_imageIds`, call `_autoSave()`, dismiss overlay
    - On failure: show SnackBar "Image upload failed: \<reason\>", dismiss overlay
    - _Requirements: 3.1, 3.2, 3.7, 3.10, 3.12_

  - [ ] 9.3 Display attached images inline in `NoteEditorScreen`
    - Add `List<String> _imageIds` state field initialized from `_currentNote?.imageIds ?? []`
    - In the note content area (below the text/checklist), render a `Wrap` of `Image.network(url)` widgets for each image ID, fetching URLs via `TelegramService.getImageUrl`
    - Use an `errorBuilder` on each `Image.network` that renders `Icon(Icons.broken_image)` when the URL fails to load
    - Cap display at 10 images
    - _Requirements: 3.5, 3.8, 3.9_

  - [ ] 9.4 Persist `imageIds` through `NoteService.createNote` and `NoteService.updateNote`
    - Add `List<String>? imageIds` parameter to `NoteService.createNote` and `NoteService.updateNote` (and their `INoteService` signatures)
    - Pass `imageIds` through to `Note` construction and `note.copyWith` respectively
    - _Requirements: 3.6_

  - [ ]* 9.5 Write property test for image attachment display completeness (Property 3)
    - Create `test/unit/image_attachment_test.dart`
    - Use a stub `TelegramService` that returns a valid URL for any file ID
    - For N in 1..10, construct a note with N image IDs and verify exactly N `Image.network` widgets appear in the pumped `NoteEditorScreen`
    - **Property 3: Image attachment display completeness**
    - **Validates: Requirements 3.8**
    - _Requirements: 3.8_

- [ ] 10. Write widget tests
  - [ ] 10.1 Create hand-written stub service implementations for widget tests
    - Create `test/widget/stubs.dart` with concrete stub classes: `StubAuthService implements IAuthService`, `StubNoteService implements INoteService`, `StubSyncEngine implements ISyncEngine`
    - `StubNoteService` returns a configurable list of `Note` objects from `getAllNotes` and `watchNotes`
    - `StubAuthService` returns a configurable `AuthResult` from `signInWithGmail` and a configurable `User?` from `getCurrentUser`
    - _Requirements: 4.6_

  - [ ] 10.2 Write `LoginScreen` widget test
    - Create `test/widget/login_screen_test.dart`
    - Pump `LoginScreen` wrapped in `MaterialApp` + `MultiProvider` with stub services
    - Find widget with text "Sign in with Google" and verify it is tappable (wrapped in `GestureDetector` or `InkWell`)
    - _Requirements: 4.1_

  - [ ] 10.3 Write `NoteEditorScreen` widget test
    - Create `test/widget/note_editor_screen_test.dart`
    - Pump `NoteEditorScreen` with stub services
    - Verify title `TextField`, content `TextField`, bold button, italic button, underline button, and image attachment button are all present
    - _Requirements: 4.2_

  - [ ] 10.4 Write `SyncIndicator` widget test (Properties 4 and 5)
    - Create `test/widget/sync_indicator_test.dart`
    - For each `SyncStatus` value, pump `SyncIndicator` with the corresponding `SyncState` and verify the correct icon is rendered
    - With `pendingChanges > 0` and `status != SyncStatus.syncing`, verify an orange circular badge is rendered
    - **Property 4: SyncIndicator icon correctness**
    - **Property 5: SyncIndicator pending-changes badge**
    - **Validates: Requirements 4.3, 4.5**
    - _Requirements: 4.3, 4.5_

  - [ ] 10.5 Write `ResponsiveNotesScreen` widget test
    - Create `test/widget/responsive_notes_screen_test.dart`
    - Configure `StubNoteService` with two mock `Note` objects; pump `ResponsiveNotesScreen`
    - Verify both note titles appear in the widget tree
    - Verify `FilterChip` appears when `_tagFilter` is set (simulate tag tap)
    - Verify "No notes match your search" text appears when filtered list is empty
    - _Requirements: 4.4, 9.4, 9.7_

- [ ] 11. Write integration tests
  - [ ] 11.1 Write auth flow integration tests
    - Create `test/integration/auth_flow_test.dart`
    - Use `@GenerateMocks` on interface types (from the fixed `mock_generator_test.mocks.dart`)
    - Test 1: mock `signIn()` returns `AuthResult(success: true)` → verify `ResponsiveNotesScreen` is present
    - Test 2: mock `signIn()` returns `AuthResult(success: false, errorMessage: "Test error")` → verify "Test error" text is present in `LoginScreen`
    - _Requirements: 5.1, 5.2_

  - [ ] 11.2 Write note creation flow integration test
    - Create `test/integration/note_creation_flow_test.dart`
    - Wire `NoteService` against an in-memory `ILocalStorageService` stub
    - Call `NoteService.createNote(note)`, pump `ResponsiveNotesScreen`, verify note title appears
    - _Requirements: 5.3_

  - [ ] 11.3 Write sync engine flow integration test
    - Create `test/integration/sync_engine_flow_test.dart`
    - Wire real `SyncEngine` against mock `ILocalStorageService` and `IRemoteStorageService`
    - Call `SyncEngine.syncNow(userId)` and verify `getNotesModifiedAfter` and `uploadNote` are each called at least once
    - _Requirements: 5.4, 5.5_

- [ ] 12. Write property tests for `ImportService` and `ViewModeProvider`
  - [ ] 12.1 Write property test for `ImportService` title transformation determinism (Property 11)
    - Create `test/unit/import_service_test.dart`
    - Extract `buildTitle(String filename)` as a static/testable method on `ImportService` (or test via the existing logic)
    - Use `Glados<String>()` to assert the result is always non-null and non-empty (falls back to "Untitled")
    - **Property 11: ImportService title transformation determinism**
    - **Validates: Requirements 10.9, 10.10**
    - _Requirements: 10.9, 10.10_

  - [ ] 12.2 Write property test for `ImportService` result count accuracy (Property 12)
    - In `test/unit/import_service_test.dart`, add a test using in-memory file stubs (k readable + m unreadable)
    - Use `Glados2<int, int>()` with `assume(k >= 0 && m >= 0 && k + m > 0)` to assert `result.imported == k` and `result.skipped == m`
    - **Property 12: ImportService result count accuracy**
    - **Validates: Requirements 10.6, 10.7**
    - _Requirements: 10.6, 10.7_

  - [ ] 12.3 Write property test for `ImportService` subfolder tagging (Property 13)
    - In `test/unit/import_service_test.dart`, use `Glados<String>()` for subfolder names
    - Assert that a file imported from a subfolder always has both `"imported"` and the subfolder name in its `tags`
    - **Property 13: ImportService subfolder tagging**
    - **Validates: Requirements 10.4**
    - _Requirements: 10.4_

  - [ ] 12.4 Write property test for `ViewModeProvider` persistence round-trip (Property 7)
    - Create `test/unit/view_mode_provider_test.dart`
    - Use `Glados<ViewMode>()` (or enumerate all three values) to assert that `setMode(mode)` followed by constructing a new `ViewModeProvider` restores the same mode
    - **Property 7: ViewModeProvider persistence round-trip**
    - **Validates: Requirements 7.7**
    - _Requirements: 7.7_

- [ ] 13. Checkpoint — Ensure all tests pass
  - Run `flutter test test/unit/`, `flutter test test/widget/`, and `flutter test test/integration/`
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 14. Final wiring and edge-case fixes
  - [ ] 14.1 Verify `ImportService` empty-file handling
    - Confirm that a file with zero bytes produces a `Note` with `content: ""` (not skipped); the existing `content.trim()` path already handles this, but add a unit test case to `import_service_test.dart` to lock it in
    - _Requirements: 10.11_

  - [ ] 14.2 Verify `ImportService` root-folder tagging (only `"imported"`, no subfolder tag)
    - Add a unit test case in `import_service_test.dart` for a file at the root of the import folder (no subfolder) and assert `tags == ["imported"]`
    - _Requirements: 10.5_

  - [ ] 14.3 Verify masonry grid defaults to "Tiles" on first install
    - Add a unit test in `view_mode_provider_test.dart` that constructs a `ViewModeProvider` with no stored preference and asserts `mode == ViewMode.grid`
    - _Requirements: 7.6, 7.8_

  - [ ] 14.4 Verify `NoteService.searchNotes` is wired into `ResponsiveNotesScreen` filter path
    - Confirm `_applyFilters` in `ResponsiveNotesScreen` delegates to `NoteService.searchNotes` (or replicates the same logic) so the desktop sidebar search and mobile search both use the same filter implementation
    - _Requirements: 9.8_

- [ ] 15. Final checkpoint — Ensure all tests pass
  - Run `flutter test` to execute the full test suite.
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Each task references specific requirements for traceability
- Property tests use `package:glados` (add `glados: ^0.5.0` to `pubspec.yaml` dev_dependencies before running them)
- The database version bump to 7 in task 3.1 covers both the `imageIds` column and the new `todos` table in a single migration
- `TodoService.initialize` signature change (task 7.1) requires updating the `main.dart` provider setup (task 7.3) in the same pass to avoid a compile error
- Widget tests use hand-written stubs (task 10.1) and do not require `build_runner`
- Integration tests use the Mockito-generated mocks from the fixed `mock_generator_test.mocks.dart` (task 1.1 + 1.5)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4"] },
    { "id": 1, "tasks": ["1.5", "2.1", "3.1", "4.1", "4.2", "4.3", "4.4", "5.1", "5.2", "5.3"] },
    { "id": 2, "tasks": ["2.2", "3.2", "6.1", "7.1", "9.1"] },
    { "id": 3, "tasks": ["6.2", "7.2", "7.4", "9.2", "9.4", "10.1"] },
    { "id": 4, "tasks": ["7.3", "8.1", "9.3", "9.5", "10.2", "10.3", "10.4", "12.1", "12.2", "12.3", "12.4"] },
    { "id": 5, "tasks": ["8.2", "8.3", "8.4", "10.5", "11.1", "11.2", "11.3"] },
    { "id": 6, "tasks": ["14.1", "14.2", "14.3", "14.4"] }
  ]
}
```
