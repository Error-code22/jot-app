# Design Document: Jot? App Completion

## Overview

Jot? is a cross-platform offline-first notes app built with Flutter 3.x, targeting Android, Windows, Linux, and macOS. The core architecture — models, services, screens, widgets, provider state management, SQLite local storage, and a Firestore+Telegram hybrid cloud sync engine — is already implemented. This design covers the ten remaining gaps needed to bring the app to a production-ready state.

### Scope of Work

| # | Area | Status |
|---|------|--------|
| 1 | Android Firebase Authentication | Partially implemented — mobile sign-in path exists but needs hardening |
| 2 | Windows Executable Launch Stability | Crash on double-click; FFI and firedart init order needs fixing |
| 3 | Image Attachments | Not implemented — model, service, and UI all need additions |
| 4 | Widget Tests | Empty `test/widget/` directory |
| 5 | Integration Tests | Empty `test/integration/` directory |
| 6 | Mock Generation Fix | `@GenerateMocks` references concrete classes instead of interfaces |
| 7 | Masonry Grid View | Already wired in `_buildNotesView`; needs verification and search integration |
| 8 | TodoService SQLite Persistence | Currently uses `SharedPreferences`; needs migration to SQLite |
| 9 | Notes Search and Filter | Search exists in desktop sidebar only; tag filter and `searchNotes` API missing |
| 10 | ImportService Completeness | Core logic exists; `refreshNotes` callback and edge cases need attention |


---

## Architecture

The app follows a layered architecture with clear separation between UI, business logic, and data:

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  Screens (LoginScreen, ResponsiveNotesScreen,               │
│           NoteEditorScreen, TodoScreen, ImportScreen)       │
│  Widgets (SyncIndicator, NoteCard, JotUI)                   │
└────────────────────────┬────────────────────────────────────┘
                         │ Provider (ChangeNotifier / StreamProvider)
┌────────────────────────▼────────────────────────────────────┐
│                    Service Layer                             │
│  AuthService  NoteService  TodoService  ImportService       │
│  SyncEngine   TelegramService  FirestoreService             │
└──────┬──────────────┬──────────────────────────────────────┘
       │              │
┌──────▼──────┐  ┌────▼──────────────────────────────────────┐
│  Auth       │  │           Data Layer                       │
│  Firebase   │  │  LocalStorageService (SQLite via sqflite)  │
│  (mobile)   │  │  WebStorageService (web stub)              │
│  firedart   │  └────────────────────────────────────────────┘
│  (desktop)  │
└─────────────┘
```

### Platform Branching Strategy

The app uses compile-time platform checks (`Platform.isAndroid`, `Platform.isWindows`, `Platform.isLinux`) and conditional imports to select the correct Firebase backend:

- **Android**: `firebase_auth` + `cloud_firestore` (native C++ SDK via Flutter plugin)
- **Windows/Linux**: `firedart` (pure-Dart Firebase client) + `sqflite_common_ffi` (SQLite via FFI)
- **macOS**: `firebase_auth` + `cloud_firestore` (same as Android path)


---

## Components and Interfaces

### 1. Android Firebase Authentication

**Affected file:** `lib/services/auth_service.dart`

The existing `_signInMobile()` path is mostly correct. The gaps are:

- `restoreSession()` on mobile must call `FirebaseAuth.instance.signOut()` when `currentUser` is null but a stored `user_id` exists (stale credential cleanup — Req 1.9).
- `signOut()` on mobile must call `FirebaseAuth.instance.signOut()` in addition to `GoogleSignIn.signOut()` (Req 1.10).
- `FlutterSecureStorage` write failures must be caught and logged without blocking the auth success path (Req 1.11).

```dart
// Pseudocode for hardened restoreSession (mobile path)
Future<bool> _restoreMobileSession() async {
  final fbUser = FirebaseAuth.instance.currentUser;
  if (fbUser != null) {
    _currentUser = _userFromFirebase(fbUser);
    _emit(AuthStatus.authenticated);
    return true;
  }
  final storedId = await _storage.read(key: _keyUserId);
  if (storedId != null) {
    // Firebase session expired — clear stale credentials
    await _clearStoredCredentials();
    _emit(AuthStatus.unauthenticated);
  }
  return false;
}
```

### 2. Windows Executable Launch Stability

**Affected file:** `lib/main.dart`

The current `main()` already wraps startup in `runZonedGuarded` and calls `sqfliteFfiInit()`. The remaining issues are:

- The `firedart` API key in `main.dart` is a placeholder (`AIzaSyBqNw3m9c8Z3qR7Y8X9Z0a1b2c3d4e5f6g`). It must be replaced with the real key from `firebase_options.dart` or a config file.
- The `jot_crash.log` write path must use `Platform.resolvedExecutable` parent directory, not the current working directory, so it works when launched by double-click.
- The `CircularProgressIndicator` loading state is already implemented via `FutureBuilder` in `_runApp()`.

```dart
// Correct crash log path for Windows double-click launch
final exeDir = File(Platform.resolvedExecutable).parent.path;
final logFile = File('$exeDir${Platform.pathSeparator}jot_crash.log');
```


### 3. Image Attachments

**Affected files:** `lib/models/note_model.dart`, `lib/services/telegram_service.dart`, `lib/screens/note_editor_screen.dart`

#### 3a. Note Model Extension

Add `imageIds` field to `Note`:

```dart
class Note {
  // ... existing fields ...
  final List<String> imageIds; // Telegram file_id strings, max 10

  // toJson / fromJson: 'imageIds': imageIds
  // toSqlite: 'imageIds': jsonEncode(imageIds)
  // fromSqlite: parse JSON array, default to []
}
```

The SQLite schema needs a migration to add the `imageIds TEXT` column (version 7).

#### 3b. TelegramService Image Upload

Add `uploadImage` and `getImageUrl` methods to `TelegramService` (and `IRemoteStorageService`):

```dart
// Upload image bytes, return Telegram file_id
Future<String> uploadImage(Uint8List bytes, String filename) async {
  // POST multipart/form-data to https://api.telegram.org/bot{token}/sendPhoto
  // Parse response: result.photo[-1].file_id (largest PhotoSize)
}

// Resolve file_id to a download URL
Future<String> getImageUrl(String fileId) async {
  // GET https://api.telegram.org/bot{token}/getFile?file_id={fileId}
  // Return https://api.telegram.org/file/bot{token}/{file_path}
}
```

The Telegram Bot API `sendPhoto` endpoint accepts `multipart/form-data` with `chat_id` and `photo` fields. The `teledart` package does not expose `sendPhoto` with raw bytes directly, so this will use `package:http` for the multipart POST.

#### 3c. NoteEditorScreen UI

Add an image attachment button to the toolbar. The flow:

1. User taps attachment icon → `image_picker` opens (gallery on desktop, gallery+camera on mobile).
2. File size check: if > 10 MB, show SnackBar and abort.
3. Show `CircularProgressIndicator` overlay.
4. Call `TelegramService.uploadImage()`.
5. On success: add `file_id` to `_imageIds` list, call `_autoSave()`, dismiss overlay.
6. On failure: show SnackBar with error, dismiss overlay.
7. Images are displayed inline using `Image.network(url)` with an error builder for broken images.

```
NoteEditorScreen toolbar:
[checklist toggle] | [bold] [italic] [underline] [strikethrough] | [heading] [bullet] [numbered] | [📎 image] | [word count]
```


### 4 & 5. Widget and Integration Tests

**New files:** `test/widget/*.dart`, `test/integration/*.dart`

All tests inject dependencies via `Provider.value` using stub/mock implementations. No real network or storage calls are made.

#### Widget Test Structure

```
test/widget/
  login_screen_test.dart          — Req 4.1
  note_editor_screen_test.dart    — Req 4.2
  sync_indicator_test.dart        — Req 4.3, 4.5
  responsive_notes_screen_test.dart — Req 4.4
```

Each test file wraps the widget under test in a `MaterialApp` + `MultiProvider` with stub services. Stubs are hand-written concrete subclasses of the interface types (not Mockito mocks) to avoid build_runner dependency in widget tests.

#### Integration Test Structure

```
test/integration/
  auth_flow_test.dart             — Req 5.1, 5.2
  note_creation_flow_test.dart    — Req 5.3
  sync_engine_flow_test.dart      — Req 5.4
```

Integration tests use `@GenerateMocks` on the interface types and wire real service implementations against mock storage/remote backends.

### 6. Mock Generation Fix

**Affected file:** `test/unit/mock_generator_test.dart`

Replace all concrete class references with interface references:

```dart
@GenerateMocks([
  ILocalStorageService,   // was: LocalStorageService
  ISyncEngine,            // was: SyncEngine
  IRemoteStorageService,  // was: FirestoreService
  IAuthService,           // was: AuthService
  INoteService,           // new
])
void main() {}
```

Remove imports of `firebase_auth`, `google_sign_in`, `flutter_secure_storage`, and `connectivity_plus` from this file — those are not interface types and should not be mocked here.

### 7. Masonry Grid View

**Affected file:** `lib/screens/responsive_notes_screen.dart`

The `MasonryGridView.count` call is already present in `_buildNotesView`. The remaining work:

- Add tag-tap callback to `_NoteCard` so tapping a tag chip sets the active tag filter (Req 9.3).
- Ensure the mobile layout passes the `_tagFilter` state down to `_buildNotesView` for filtering.
- The `ViewModeProvider` already persists to `SharedPreferences` under `view_mode`.


### 8. TodoService SQLite Persistence

**Affected files:** `lib/services/todo_service.dart`, `lib/services/local_storage_service.dart`, `lib/services/i_local_storage_service.dart`

#### 8a. Schema Addition

Add a `todos` table to `LocalStorageService` in the same `onCreate` block as `notes`, and add a migration for existing databases (version 7, alongside the `imageIds` column):

```sql
CREATE TABLE todos (
  id         TEXT PRIMARY KEY,
  userId     TEXT NOT NULL,
  data       TEXT NOT NULL,   -- JSON-encoded TodoList
  modifiedAt INTEGER NOT NULL
);
CREATE INDEX idx_todos_userId ON todos (userId);
```

#### 8b. ILocalStorageService Extension

Add four new methods to the interface:

```dart
Future<void> insertTodoList(TodoList list);
Future<void> updateTodoList(TodoList list);
Future<void> deleteTodoList(String id);
Future<List<TodoList>> getTodoListsForUser(String userId);
```

#### 8c. TodoService Refactor

Replace `SharedPreferences` persistence with `LocalStorageService` calls. The `initialize()` method gains a `ILocalStorageService` parameter:

```dart
Future<void> initialize(String userId, ILocalStorageService storage) async {
  _userId = userId;
  _storage = storage;
  await _migrateFromSharedPreferences(); // one-time migration
  await _load();
}
```

The migration reads `todos_<userId>` from `SharedPreferences`, writes each `TodoList` to SQLite, then deletes the key. Individual migration failures are caught and logged without aborting the rest.

All mutation methods (`createList`, `addItem`, `toggleItem`, `deleteItem`, etc.) are wrapped in try/catch: on storage failure, the in-memory mutation is rolled back and `notifyListeners()` is called with the previous state.

### 9. Notes Search and Filter

**Affected files:** `lib/services/note_service.dart`, `lib/services/i_note_service.dart`, `lib/services/local_storage_service.dart`, `lib/services/i_local_storage_service.dart`, `lib/screens/responsive_notes_screen.dart`

#### 9a. NoteService.searchNotes

Add to `INoteService` and `NoteService`:

```dart
Future<List<Note>> searchNotes(String userId, String query, {String? tag}) async {
  final all = await _local.getAllNotes(userId);
  final q = query.toLowerCase();
  return all.where((n) {
    final matchesQuery = q.isEmpty ||
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q) ||
        n.tags.any((t) => t.toLowerCase().contains(q));
    final matchesTag = tag == null || n.tags.contains(tag);
    return matchesQuery && matchesTag;
  }).toList();
}
```

This is a pure in-memory filter over the already-loaded notes list, so no new SQL query is needed.

#### 9b. ResponsiveNotesScreen State

Add `_tagFilter` state variable. The notes list is filtered by applying both `_searchQuery` and `_tagFilter` before rendering. A `FilterChip` row appears above the notes list when `_tagFilter` is non-null.

```dart
String _searchQuery = '';
String? _tagFilter;

List<Note> _applyFilters(List<Note> notes) {
  return notes.where((n) {
    final q = _searchQuery.toLowerCase();
    final matchesSearch = q.isEmpty ||
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q) ||
        n.tags.any((t) => t.toLowerCase().contains(q));
    final matchesTag = _tagFilter == null || n.tags.contains(_tagFilter);
    return matchesSearch && matchesTag;
  }).toList();
}
```

The tag filter is set by tapping a tag chip on a `_NoteCard`. The `_NoteCard` widget gains an `onTagTap` callback.


### 10. ImportService Completeness

**Affected files:** `lib/services/import_service.dart`, `lib/screens/import_screen.dart`

The core `ImportService` logic is already correct. The remaining gaps:

- `ImportScreen` must call `NoteService.refreshNotes(userId)` after a successful import to trigger a stream update (Req 10.8).
- The title transformation regex is already implemented; verify the order matches the spec: (1) strip extension, (2) remove `_\d{6}_\d{6}` suffix, (3) remove `\s*\(\d+\)` suffix.
- Empty files (zero bytes) must produce a note with empty content, not be skipped (Req 10.11). The current implementation calls `content.trim()` which returns `""` for empty files — this is correct, but the `if (title.isEmpty && content.isEmpty)` guard in `_autoSave` must not apply to imported notes (they are inserted directly, not via the editor).

---

## Data Models

### Note (extended)

```dart
class Note {
  final String id;
  final String userId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final bool isDeleted;
  final NoteType type;           // text | checklist
  final String? telegramMessageId;
  final List<String> tags;
  final String? color;           // hex string e.g. "#FFCDD2"
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;
  final List<String> imageIds;   // NEW: Telegram file_id list, max 10
}
```

**SQLite schema change (version 7):**
```sql
ALTER TABLE notes ADD COLUMN imageIds TEXT;  -- JSON array, default '[]'
ALTER TABLE todos ... (new table, see §8a)
```

### TodoList / TodoItem

No model changes needed. The `TodoList.toJson()` / `fromJson()` methods already exist and will be used for the `data` column in the `todos` table.

### ILocalStorageService (extended)

```dart
// New methods for todos
Future<void> insertTodoList(TodoList list);
Future<void> updateTodoList(TodoList list);
Future<void> deleteTodoList(String id);
Future<List<TodoList>> getTodoListsForUser(String userId);
```

### IRemoteStorageService (extended)

```dart
// New methods for image attachments
Future<String> uploadImage(Uint8List bytes, String filename);
Future<String> getImageUrl(String fileId);
```

### INoteService (extended)

```dart
// New search method
Future<List<Note>> searchNotes(String userId, String query, {String? tag});
```


---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Auth credential persistence completeness

*For any* valid Firebase user object (with any uid, email, displayName, and idToken), when `AuthService.signInWithGmail()` succeeds on Android, all four fields (`user_id`, `user_email`, `user_display_name`, `google_id_token`) SHALL be written to `FlutterSecureStorage`.

**Validates: Requirements 1.3**

---

### Property 2: Note imageIds serialization round-trip

*For any* `Note` with any `imageIds` list (including empty list and lists up to 10 elements), serializing via `toJson()` then deserializing via `fromJson()` SHALL produce a `Note` with an equal `imageIds` list. The same round-trip SHALL hold for `toSqlite()` / `fromSqlite()`.

**Validates: Requirements 3.11**

---

### Property 3: Image attachment display completeness

*For any* note with N image IDs (where 1 ≤ N ≤ 10), opening the note in `NoteEditorScreen` with a mock `TelegramService` that returns a valid URL for each file ID SHALL result in exactly N image widgets being rendered in the content area.

**Validates: Requirements 3.8**

---

### Property 4: SyncIndicator icon correctness

*For any* `SyncStatus` value, `SyncIndicator` SHALL render the icon that matches the following mapping: `idle` → `cloud_done_rounded`; `success` → `cloud_done_rounded`; `syncing` → `sync_rounded`; `error` → `cloud_off_rounded`; `offline` → `cloud_off_rounded`.

**Validates: Requirements 4.3**

---

### Property 5: SyncIndicator pending-changes badge

*For any* `SyncState` where `pendingChanges > 0` and `status != SyncStatus.syncing`, `SyncIndicator` SHALL render an orange circular badge alongside the icon.

**Validates: Requirements 4.5**

---

### Property 6: TodoService mutation rollback on storage failure

*For any* todo mutation operation (createList, addItem, toggleItem, deleteItem, updateItem), if the corresponding `LocalStorageService` write call throws an exception, the `TodoService` in-memory list SHALL remain identical to its state before the mutation was attempted.

**Validates: Requirements 8.7**

---

### Property 7: ViewModeProvider persistence round-trip

*For any* `ViewMode` value, calling `ViewModeProvider.setMode(mode)` and then constructing a new `ViewModeProvider` instance (which calls `_load()`) SHALL restore the same `ViewMode` value.

**Validates: Requirements 7.7**

---

### Property 8: Search results are a subset of all notes

*For any* non-empty query string `q` and user ID `userId`, every note returned by `NoteService.searchNotes(userId, q)` SHALL also appear in the list returned by `NoteService.getAllNotes(userId)`.

**Validates: Requirements 9.10**

---

### Property 9: Search filter correctness

*For any* non-empty query string `q` and any list of notes, every note returned by `searchNotes(userId, q)` SHALL have its `title`, `content`, or at least one element of its `tags` list contain `q` as a case-insensitive substring. Notes that do not satisfy this condition SHALL NOT appear in the results.

**Validates: Requirements 9.1, 9.9, 9.11**

---

### Property 10: Combined search and tag filter intersection

*For any* non-empty query string `q` and tag string `t`, every note returned by `searchNotes(userId, q, tag: t)` SHALL satisfy both the text search condition (title/content/tags contain `q`) AND the tag condition (`tags` contains `t` exactly).

**Validates: Requirements 9.6**

---

### Property 11: ImportService title transformation determinism

*For any* filename string, the `ImportService` title transformation (strip extension → remove Samsung date suffix → remove duplicate number suffix → fallback to "Untitled") SHALL produce a deterministic, non-null result. If the result after all transformations is empty, it SHALL equal `"Untitled"`.

**Validates: Requirements 10.9, 10.10**

---

### Property 12: ImportService result count accuracy

*For any* set of files where `k` files are readable and `m` files are unreadable, `ImportService.importFiles()` SHALL return an `ImportResult` where `imported == k` and `skipped == m`, and SHALL NOT throw an exception.

**Validates: Requirements 10.6, 10.7**

---

### Property 13: ImportService subfolder tagging

*For any* file located in a subfolder of the import root, the resulting `Note` SHALL have both `"imported"` and the immediate parent subfolder's name as elements of its `tags` list.

**Validates: Requirements 10.4**


---

## Error Handling

### Authentication Errors

| Scenario | Handling |
|----------|----------|
| User cancels Google account picker | Return `AuthResult(success: false, errorMessage: "Sign-in cancelled")` |
| `FirebaseAuthException` during sign-in | Return `AuthResult(success: false, errorMessage: exception.message)` |
| `GoogleSignIn` throws | Return `AuthResult(success: false, errorMessage: e.toString())` |
| `FlutterSecureStorage` write fails | Log error, continue — emit `AuthStatus.authenticated` for current session |
| Stale `user_id` in storage (Firebase session expired) | Clear all stored credentials, emit `AuthStatus.unauthenticated` |

### Windows Startup Errors

| Scenario | Handling |
|----------|----------|
| `firedart` init fails (bad API key) | Catch, log to `jot_crash.log`, continue in offline mode |
| Unhandled exception in `runZonedGuarded` | Append timestamp + error + stack to `jot_crash.log` next to executable |
| `_initializeServices` throws | `FutureBuilder` shows error text with the exception message |

### Image Attachment Errors

| Scenario | Handling |
|----------|----------|
| Image > 10 MB | SnackBar: "Image too large (max 10 MB)", no upload |
| Telegram `sendPhoto` fails | SnackBar: "Image upload failed: \<reason\>", no file_id added |
| `getFile` API fails for stored image | Show broken-image placeholder icon (`Icons.broken_image`) |
| `image_picker` throws or returns null | Silently dismiss overlay, no action |

### TodoService Errors

| Scenario | Handling |
|----------|----------|
| `getTodoListsForUser` throws on startup | Log error, leave list empty, call `notifyListeners()` |
| Any write call throws during mutation | Roll back in-memory change, log error, call `notifyListeners()` |
| SharedPreferences migration fails for one item | Log error, skip that item, continue migrating remaining items |

### ImportService Errors

| Scenario | Handling |
|----------|----------|
| File read fails (permission/encoding) | Increment `skipped`, continue processing |
| Folder not found | Return `ImportResult(success: false, message: "Folder not found: ...")` |
| No supported files found | Return `ImportResult(success: false, message: "No supported files found")` |

### Sync Errors

The existing `SyncEngine` already handles connectivity loss, retry with exponential backoff (1s, 2s, 4s, max 16s), and a failed-operations queue. No changes needed.


---

## Testing Strategy

### Property-Based Testing Library

The project uses **`package:test`** (via `flutter_test`) for all tests. For property-based testing, add **`package:fast_check`** (a Dart PBT library) or use **`package:glados`** (another Dart PBT library). Given the existing Dart/Flutter ecosystem, **`package:glados`** is recommended — it integrates cleanly with `flutter_test` and provides generators for primitive types, lists, and custom types.

Add to `pubspec.yaml` dev_dependencies:
```yaml
glados: ^0.5.0
```

Each property test runs a minimum of **100 iterations** and is tagged with a comment referencing the design property number.

---

### Unit Tests (existing + new)

**Location:** `test/unit/`

| File | Tests |
|------|-------|
| `mock_generator_test.dart` | Fixed `@GenerateMocks` on interface types |
| `note_service_test.dart` | Existing tests + `searchNotes` tests |
| `auth_service_test.dart` | Existing tests + mobile sign-in hardening |
| `import_service_test.dart` | Title transformation, file counting, subfolder tagging |
| `todo_service_test.dart` | SQLite persistence, migration, rollback |
| `models/note_model_test.dart` | `imageIds` round-trip (property test) |

---

### Property-Based Tests

**Location:** `test/unit/` (co-located with unit tests)

#### Property 2: Note imageIds serialization round-trip
```dart
// Feature: jot-app-completion, Property 2: Note imageIds serialization round-trip
Glados<List<String>>().test('imageIds round-trip via JSON', (imageIds) {
  final note = Note(id: 'x', userId: 'u', title: 't', content: 'c',
      createdAt: DateTime.now(), modifiedAt: DateTime.now(),
      imageIds: imageIds.take(10).toList());
  final restored = Note.fromJson(note.toJson());
  expect(restored.imageIds, equals(note.imageIds));
});
```

#### Property 8 & 9: Search results subset and correctness
```dart
// Feature: jot-app-completion, Property 8 & 9: Search results subset and correctness
Glados2<List<Note>, String>().test('search results are subset with correct matches', (notes, query) {
  assume(query.isNotEmpty);
  final all = notes;
  final results = applySearchFilter(all, query);
  // Subset property
  for (final r in results) { expect(all, contains(r)); }
  // Correctness property
  final q = query.toLowerCase();
  for (final r in results) {
    expect(
      r.title.toLowerCase().contains(q) ||
      r.content.toLowerCase().contains(q) ||
      r.tags.any((t) => t.toLowerCase().contains(q)),
      isTrue,
    );
  }
});
```

#### Property 11: ImportService title transformation
```dart
// Feature: jot-app-completion, Property 11: ImportService title transformation determinism
Glados<String>().test('title transformation is deterministic and non-null', (filename) {
  final title = ImportService.buildTitle(filename);
  expect(title, isNotNull);
  expect(title, isNotEmpty); // "Untitled" fallback ensures non-empty
});
```

#### Property 12: ImportService result count accuracy
```dart
// Feature: jot-app-completion, Property 12: ImportService result count accuracy
// Uses in-memory file stubs: k readable + m unreadable
Glados2<int, int>().test('imported + skipped = total files', (k, m) {
  assume(k >= 0 && m >= 0 && k + m > 0);
  final result = runImportWithKReadableMUnreadable(k, m);
  expect(result.imported, equals(k));
  expect(result.skipped, equals(m));
});
```

---

### Widget Tests

**Location:** `test/widget/`

```
login_screen_test.dart
  - finds "Sign in with Google" text
  - verifies button is tappable

note_editor_screen_test.dart
  - finds title TextField
  - finds content TextField
  - finds bold, italic, underline toolbar buttons
  - finds image attachment button

sync_indicator_test.dart
  - for each SyncStatus: verifies correct icon (Property 4)
  - with pendingChanges > 0 and non-syncing: verifies orange dot (Property 5)

responsive_notes_screen_test.dart
  - with 2 mock notes: verifies both titles appear
  - with active tag filter: verifies FilterChip is shown
  - with empty filtered list: verifies "No notes match your search"
```

All widget tests use hand-written stub implementations of `IAuthService`, `INoteService`, and `ISyncEngine` injected via `Provider.value`. No `build_runner` dependency is needed for widget tests.

---

### Integration Tests

**Location:** `test/integration/`

```
auth_flow_test.dart
  - mock signIn success → ResponsiveNotesScreen is present
  - mock signIn failure → error message shown in LoginScreen

note_creation_flow_test.dart
  - createNote on in-memory storage → title appears in ResponsiveNotesScreen

sync_engine_flow_test.dart
  - real SyncEngine + mock storage/remote → getNotesModifiedAfter and uploadNote called
```

Integration tests use `@GenerateMocks([ILocalStorageService, IRemoteStorageService, IAuthService, INoteService, ISyncEngine])` from the fixed `mock_generator_test.dart`.

---

### Test Execution

```bash
# Unit tests
flutter test test/unit/

# Widget tests (no device needed)
flutter test test/widget/

# Integration tests
flutter test test/integration/

# All tests
flutter test
```

