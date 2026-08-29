
# Jot? — Architecture & Developer Guide

> **Version:** 1.0.0+1 · **Flutter SDK:** ≥ 3.0.0 · **Last updated:** May 2026

A cross-platform notes app for Android, Windows, Linux, and macOS. Built with Flutter, backed by a hybrid Firestore + Telegram storage layer, and designed around an offline-first, service-abstracted architecture.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Layout](#2-repository-layout)
3. [Architecture Overview](#3-architecture-overview)
4. [Data Layer](#4-data-layer)
   - 4.1 [Note Model](#41-note-model)
   - 4.2 [LocalStorageService (SQLite)](#42-localstorageservice-sqlite)
   - 4.3 [WebStorageService (SharedPreferences)](#43-webstorageservice-sharedpreferences)
   - 4.4 [FirestoreService (Remote)](#44-firestoreservice-remote)
   - 4.5 [TelegramService (Remote Content)](#45-telegramservice-remote-content)
5. [Business Logic Layer](#5-business-logic-layer)
   - 5.1 [NoteService](#51-noteservice)
   - 5.2 [SyncEngine](#52-syncengine)
   - 5.3 [ConflictResolver](#53-conflictresolver)
   - 5.4 [AuthService](#54-authservice)
   - 5.5 [TodoService](#55-todoservice)
6. [Presentation Layer](#6-presentation-layer)
   - 6.1 [Screens](#61-screens)
   - 6.2 [Widgets](#62-widgets)
   - 6.3 [Platform Theming](#63-platform-theming)
7. [State Management](#7-state-management)
8. [Platform Specifics](#8-platform-specifics)
   - 8.1 [Android](#81-android)
   - 8.2 [Windows / Linux Desktop](#82-windows--linux-desktop)
   - 8.3 [macOS](#83-macos)
   - 8.4 [Web (Preview)](#84-web-preview)
9. [Dependency Injection & Interfaces](#9-dependency-injection--interfaces)
10. [Sync Protocol](#10-sync-protocol)
11. [Conflict Resolution](#11-conflict-resolution)
12. [Authentication Flow](#12-authentication-flow)
13. [Database Schema & Migrations](#13-database-schema--migrations)
14. [Error Handling Strategy](#14-error-handling-strategy)
15. [Testing Strategy](#15-testing-strategy)
16. [Dependencies Reference](#16-dependencies-reference)
17. [Known Issues & Roadmap](#17-known-issues--roadmap)
18. [Setup & Running Locally](#18-setup--running-locally)

---

## 1. Project Overview

Jot? is an offline-first, cross-platform notes application. The core design philosophy is:

- **Offline first** — every write goes to local SQLite immediately; sync happens in the background
- **Interface-driven** — every service is backed by an abstract interface, making the codebase fully testable and swappable
- **Platform-adaptive** — UI and storage backends adapt per platform (Android vs Desktop vs Web)
- **Hybrid cloud** — Firestore holds note metadata/index; Telegram holds note content (large payloads)

### Tech Stack

| Concern | Technology |
|---|---|
| UI Framework | Flutter 3.x (Material 3) |
| Local DB | SQLite via `sqflite` / `sqflite_common_ffi` |
| Cloud Index | Firebase Firestore via `firedart` (desktop) |
| Cloud Content | Telegram Bot API via `teledart` |
| Auth | Google Sign-In + `firedart` token store |
| State | `provider` package |
| Fonts | `google_fonts` (Outfit on Android, Inter on Desktop) |

---

## 2. Repository Layout

```
jot_app/
├── lib/
│   ├── main.dart                   # Bootstrap, DI wiring, app shell
│   ├── firebase_options.dart       # Mobile Firebase config (gitignored)
│   ├── firebase_options_stub.dart  # Desktop stub (no-op)
│   ├── models/
│   │   ├── note_model.dart         # Core Note entity + ChecklistItem
│   │   ├── auth_state.dart         # AuthState / AuthStatus enum
│   │   ├── user_model.dart         # Jot User value object
│   │   ├── sync_state.dart         # SyncState / SyncStatus enum
│   │   ├── sync_result.dart        # SyncResult value object
│   │   ├── todo_model.dart         # Todo item model
│   │   ├── progress_entry.dart     # Dev progress log entry
│   │   └── ide_config.dart         # Multi-IDE collaboration metadata
│   ├── services/
│   │   ├── i_*.dart                # Abstract interfaces for every service
│   │   ├── auth_service.dart       # Google Sign-In + session persistence
│   │   ├── windows_auth_service.dart # Desktop OAuth local-server flow
│   │   ├── local_storage_service.dart # SQLite CRUD
│   │   ├── web_storage_service.dart   # SharedPreferences fallback (web)
│   │   ├── firestore_service.dart     # Firestore abstraction (metadata)
│   │   ├── firestore_mobile.dart      # Mobile Firestore impl
│   │   ├── firestore_desktop.dart     # Firedart Firestore impl
│   │   ├── telegram_service.dart      # Telegram Bot content storage
│   │   ├── sync_engine.dart           # Bidirectional sync orchestrator
│   │   ├── note_service.dart          # Note CRUD API for UI
│   │   ├── todo_service.dart          # Todo CRUD
│   │   ├── config_service.dart        # Runtime config
│   │   ├── import_service.dart        # Note import logic
│   │   └── progress_service.dart      # Dev log service
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── responsive_notes_screen.dart  # Main notes list (adaptive layout)
│   │   ├── note_editor_screen.dart
│   │   ├── todo_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── import_screen.dart
│   │   ├── support_screen.dart
│   │   └── terms_screen.dart
│   ├── widgets/
│   │   ├── note_card.dart            # Mobile note card
│   │   ├── desktop_note_card.dart    # Desktop sidebar note card
│   │   ├── sync_indicator.dart       # Animated sync status badge
│   │   └── jot_ui.dart               # Glassmorphism / shared UI helpers
│   └── utils/
│       ├── platform_theme.dart       # Per-platform ThemeData
│       ├── theme_provider.dart       # Dark/light mode ChangeNotifier
│       ├── view_mode_provider.dart   # Grid/list toggle ChangeNotifier
│       ├── conflict_resolver.dart    # Last-write-wins conflict logic
│       ├── connectivity_monitor.dart # Network state wrapper
│       └── color_utils.dart          # Note color helpers
├── test/
│   ├── unit/                         # Pure Dart unit tests
│   ├── widget/                       # Flutter widget tests
│   └── integration/                  # End-to-end flow tests
├── android/                          # Android platform project
├── windows/                          # Windows platform project
├── linux/                            # Linux platform project
├── macos/                            # macOS platform project
├── web/                              # Web platform project
└── public/                           # Static assets (logo, images)
```

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  LoginScreen  ResponsiveNotesScreen  NoteEditorScreen   │
│  TodoScreen   SettingsScreen         ProfileScreen       │
│                                                          │
│  Widgets: NoteCard  DesktopNoteCard  SyncIndicator       │
└────────────────────────┬────────────────────────────────┘
                         │ Provider / ChangeNotifier
┌────────────────────────▼────────────────────────────────┐
│                  Business Logic Layer                    │
│                                                          │
│   NoteService ──► SyncEngine ──► ConflictResolver        │
│   AuthService                                            │
│   TodoService                                            │
│   ConfigService                                          │
└──────────┬──────────────────────────┬───────────────────┘
           │                          │
┌──────────▼──────────┐  ┌────────────▼──────────────────┐
│     Local Layer     │  │        Remote Layer            │
│                     │  │                                │
│  LocalStorageService│  │  FirestoreService (metadata)   │
│  (SQLite / FFI)     │  │  TelegramService (content)     │
│                     │  │                                │
│  WebStorageService  │  │  IRemoteStorageService         │
│  (SharedPrefs/web)  │  │  (interface, swappable)        │
└─────────────────────┘  └────────────────────────────────┘
```

Data always flows **write-local-first**. The `SyncEngine` runs in the background and reconciles local state with remote asynchronously.

---

## 4. Data Layer

### 4.1 Note Model

`lib/models/note_model.dart`

The `Note` class is an **immutable value object**. All mutations return a new instance via `copyWith`.

```dart
class Note {
  final String id;           // UUID v4
  final String userId;       // Firebase UID
  final String title;
  final String content;      // Plain text or JSON-encoded checklist
  final DateTime createdAt;
  final DateTime modifiedAt; // Used for conflict resolution
  final bool isDeleted;      // Soft-delete flag
  final NoteType type;       // text | checklist
  final String? telegramMessageId; // Remote content pointer
  final List<String> tags;
  final String? color;       // Hex color string
  final bool isPinned;
  final bool isLocked;
  final String? pinHash;     // Salted hash of user PIN
}
```

**Serialization:**
- `toJson()` / `fromJson()` — Firestore / Telegram (ISO 8601 timestamps)
- `toSqlite()` / `fromSqlite()` — SQLite (epoch milliseconds, booleans as 0/1, tags as JSON string)

**PIN hashing** uses a simple salted fold hash (`jot_pin_salt_<pin>`). It is intentionally lightweight — this is a local convenience lock, not a security boundary.

**`ChecklistItem`** is a companion class for checklist-type notes. The checklist is stored as a JSON-encoded array in `Note.content`.

---

### 4.2 LocalStorageService (SQLite)

`lib/services/local_storage_service.dart`

Implements `ILocalStorageService`. Uses `sqflite` on mobile/desktop and `sqflite_common_ffi` on Windows/Linux.

**Database:** `jot_app.db`, current schema version **6**.

**Key design decisions:**
- `insertNote` uses `ConflictAlgorithm.replace` — upsert semantics, safe for sync writes
- Deletes are **soft** by default (`isDeleted = 1`, `modifiedAt` updated) so the sync engine can propagate deletions to remote
- `hardDeleteNote` is only called after a soft-deleted note has been confirmed deleted on remote
- Notes are ordered `isPinned DESC, modifiedAt DESC` in `getAllNotes`
- `getNotesModifiedAfter(timestamp)` enables incremental sync — only changed notes are pushed

**Migrations** are additive-only (ALTER TABLE ADD COLUMN). Each version gate is independent so upgrades from any older version work correctly.

---

### 4.3 WebStorageService (SharedPreferences)

`lib/services/web_storage_service.dart`

A `SharedPreferences`-backed implementation of `ILocalStorageService` used when `kIsWeb == true`. Notes are serialized to JSON and stored under per-user keys. This is a preview/demo backend — not intended for production data volumes.

---

### 4.4 FirestoreService (Remote)

`lib/services/firestore_service.dart`

Implements `IRemoteStorageService`. Acts as the **metadata index** for notes — stores titles, IDs, timestamps, and `telegramMessageId` pointers. Full note content lives in Telegram.

- On **mobile**: delegates to `firestore_mobile.dart` (native Firebase SDK)
- On **desktop**: delegates to `firestore_desktop.dart` (firedart)

The split is handled via a factory/conditional pattern inside `FirestoreService`.

---

### 4.5 TelegramService (Remote Content)

`lib/services/telegram_service.dart`

Stores note body content as messages in a private Telegram channel. The bot token and chat ID are configured at build time (see `SESSION_PROGRESS.md` for credentials — keep these out of version control).

- Text notes → stored as Telegram text messages
- Future: binary attachments (images) → stored as Telegram file uploads

The `telegramMessageId` field on `Note` is the pointer back to the Telegram message. When a note is deleted, the corresponding Telegram message is also deleted.

---

## 5. Business Logic Layer

### 5.1 NoteService

`lib/services/note_service.dart`

The single entry point for all note operations from the UI. It owns the reactive stream layer.

```
UI calls NoteService
  → writes to LocalStorageService
  → emits update on per-user StreamController<List<Note>>
  → fires SyncEngine.syncNow() (unawaited — non-blocking)
```

**Stream per user:** `watchNotes(userId)` returns a broadcast stream. On first subscription it immediately emits the current note list. Subsequent emissions happen after any create/update/delete.

**Extra operations beyond CRUD:**
- `togglePin(note)` — flips `isPinned`, persists, emits
- `toggleLock(note, {pin})` — sets/clears `isLocked` + `pinHash`
- `refreshNotes(userId)` — force-emits current DB state (used after sync)

---

### 5.2 SyncEngine

`lib/services/sync_engine.dart`

The most complex service. Orchestrates bidirectional sync between local SQLite and the remote layer.

**Lifecycle:**
```
AuthService emits authenticated
  → SyncEngine.start(userId)
    → checks connectivity
    → subscribes to connectivity changes
    → subscribes to remote note stream (real-time push)

AuthService emits unauthenticated
  → SyncEngine.stop()
    → cancels all subscriptions
    → clears state
```

**Sync cycle (`syncNow`):**
```
1. Process failed-operations queue (retry previously failed notes)
2. Pull remote changes  (with retry, up to 3 attempts, exponential backoff)
3. Push local changes   (with retry, up to 3 attempts, exponential backoff)
4. Update SyncState stream
5. After 2s delay → transition back to idle
```

**Incremental push:** After the first successful sync, `_lastSyncTime` is set. Subsequent pushes only query notes modified after that timestamp via `getNotesModifiedAfter`, keeping push payloads small.

**Sync loop detection:** `_isInSyncLoop(noteId)` tracks per-note sync attempt timestamps. If a note has been attempted more than 3 times in 10 seconds, it is skipped to prevent thrashing.

**Failed operations queue:** Notes that fail to push are added to `_failedOperationsQueue`. They are retried at the start of the next `syncNow` call. The queue length is surfaced in `SyncState.pendingChanges` and shown in the UI via `SyncIndicator`.

**Real-time pull:** `_remote.watchNotes(userId)` provides a stream of remote note snapshots. When a remote update arrives outside of an active sync, `_handleRemoteUpdate` merges it into local storage using `ConflictResolver`.

**SyncState transitions:**

```
idle ──► syncing ──► success ──► idle (after 2s)
                 └──► error   ──► idle (after 2s)
offline (connectivity lost, no sync attempted)
```

---

### 5.3 ConflictResolver

`lib/utils/conflict_resolver.dart`

Implements `IConflictResolver`. Pure, stateless, deterministic.

**Strategy: Last-Write-Wins (LWW)**

```dart
if (local.modifiedAt > remote.modifiedAt) → keep local
if (remote.modifiedAt > local.modifiedAt) → keep remote
if equal timestamps                        → lexicographic note ID comparison (deterministic tiebreak)
```

The tiebreak on equal timestamps ensures that two devices that both modify a note at the exact same millisecond will always converge to the same winner, regardless of which device runs the resolver.

`hasConflict` returns true if any of: `modifiedAt`, `title`, `content`, or `isDeleted` differ between local and remote versions of the same note.

---

### 5.4 AuthService

`lib/services/auth_service.dart`

Implements `IAuthService`. Platform-branched internally.

**Desktop (Windows/Linux):**
- Sign-in delegates to `WindowsAuthService.signIn()` which runs a local HTTP server to capture the OAuth redirect
- Tokens (idToken, refreshToken, accessToken) are persisted to `FlutterSecureStorage`
- On app restart, `restoreSession()` reads stored tokens and re-injects them into `firedart`'s token provider

**Mobile (Android):**
- Currently stubbed — returns an error directing the developer to add `firebase_core`, `firebase_auth`, `cloud_firestore` to `pubspec.yaml`
- The stub exists because the current `pubspec.yaml` uses `firedart` instead of the native Firebase SDK to avoid CMake build issues on desktop

**Credential keys stored in secure storage:**

| Key | Value |
|---|---|
| `google_access_token` | OAuth access token |
| `google_id_token` | Firebase ID token |
| `firebase_refresh_token` | Firebase refresh token |
| `user_id` | Firebase UID |
| `user_email` | User email |
| `user_display_name` | Display name |
| `last_login` | ISO 8601 timestamp |

---

### 5.5 TodoService

`lib/services/todo_service.dart`

A `ChangeNotifier` that manages a list of `TodoItem` objects. Initialized with the current user's UID on login. Separate from `NoteService` — todos are a distinct feature with their own screen and model.

---

## 6. Presentation Layer

### 6.1 Screens

| Screen | File | Purpose |
|---|---|---|
| `LoginScreen` | `login_screen.dart` | Google Sign-In entry point |
| `ResponsiveNotesScreen` | `responsive_notes_screen.dart` | Main notes list, adaptive layout |
| `NoteEditorScreen` | `note_editor_screen.dart` | Create / edit a note |
| `TodoScreen` | `todo_screen.dart` | Checklist / todo management |
| `SettingsScreen` | `settings_screen.dart` | Theme toggle, preferences |
| `ProfileScreen` | `profile_screen.dart` | User info, sign-out |
| `ImportScreen` | `import_screen.dart` | Import notes from external sources |
| `SupportScreen` | `support_screen.dart` | Help / feedback |
| `TermsScreen` | `terms_screen.dart` | Terms of service |

**`ResponsiveNotesScreen` layout logic:**
```
Screen width ≥ 800px  →  Two-pane layout
  Left pane:  note list sidebar (DesktopNoteCard)
  Right pane: inline NoteEditorScreen

Screen width < 800px  →  Single-pane layout
  Full-screen note list (NoteCard in MasonryGridView)
  FAB navigates to NoteEditorScreen
```

**`NoteEditorScreen` features:**
- Distraction-free centered layout with `maxWidth` constraint
- Formatting toolbar (bold, italic, etc.)
- Word counter
- Subtle auto-save status indicator
- Delete confirmation dialog
- Checklist mode toggle

---

### 6.2 Widgets

**`NoteCard`** (`widgets/note_card.dart`)
Mobile masonry grid card. Shows title, content preview (first 100 chars), relative timestamp, color accent, pin/lock badges.

**`DesktopNoteCard`** (`widgets/desktop_note_card.dart`)
Compact sidebar card for the two-pane desktop layout. Shows title, preview (first 60 chars), selection highlight when active.

**`SyncIndicator`** (`widgets/sync_indicator.dart`)
Animated icon in the app bar showing current sync state:

| State | Icon | Color |
|---|---|---|
| `idle` | `cloud_done` | Grey |
| `syncing` | `sync` (rotating) | Blue |
| `success` | `cloud_done` | Green |
| `error` | `cloud_off` | Red |
| `offline` | `cloud_off` | Orange |

Shows a badge with `pendingChanges` count when > 0.

**`JotUI`** (`widgets/jot_ui.dart`)
Static utility class with helpers for glassmorphism effects, gradient backgrounds, and shared decoration patterns used across screens.

---

### 6.3 Platform Theming

`lib/utils/platform_theme.dart`

`PlatformTheme.getTheme(platform)` returns a fully configured `ThemeData` per platform:

| Platform | Font | Primary Color | Style Notes |
|---|---|---|---|
| Android | Outfit | Deep Purple `#673AB7` | Material 3, vibrant, rounded (r=20) |
| Windows | Inter | Blue `#2196F3` | Clean, moderate elevation, r=12 |
| Linux | Inter | Orange | Same as Windows, orange seed |
| macOS | Inter | Blue | Flat (elevation=0), r=10, transparent AppBar |
| Dark (all) | Inter | Purple `#9E7BFF` | Catppuccin-inspired dark surface `#181825` |

Dark theme is platform-agnostic — one dark theme serves all platforms.

---

## 7. State Management

The app uses `provider` with a mix of `ChangeNotifier` and `StreamProvider`.

**Provider tree (set up in `main.dart`):**

```
MultiProvider
├── ChangeNotifierProvider<ThemeProvider>      # dark/light mode
├── ChangeNotifierProvider<ViewModeProvider>   # grid/list toggle
├── ChangeNotifierProvider<TodoService>        # todo list state
├── Provider<AuthService>                      # auth (not reactive here)
├── Provider<ILocalStorageService>             # storage access
├── Provider<FirestoreService>                 # remote access
├── Provider<SyncEngine>                       # sync access
├── Provider<NoteService>                      # note operations
└── StreamProvider<AuthState>                  # reactive auth state
    └── source: AuthService.authStateChanges
```

**`AuthState`** is the primary routing signal. `JotApp.onGenerateRoute` reads it to decide between `LoginScreen` and `ResponsiveNotesScreen`.

**Notes reactivity:** Screens subscribe to `NoteService.watchNotes(userId)` which is a `Stream<List<Note>>`. This is consumed via `StreamBuilder` in the notes list screen.

---

## 8. Platform Specifics

### 8.1 Android

- Uses native `sqflite` (no FFI needed)
- Firebase Auth via native SDK (requires `google-services.json` in `android/app/`)
- Google Sign-In via `google_sign_in` package
- Material 3 theme with Deep Purple accent
- Launcher icon configured via `flutter_launcher_icons`

> **Current state:** Mobile Firebase Auth is stubbed. To enable, add `firebase_core`, `firebase_auth`, and `cloud_firestore` back to `pubspec.yaml` and implement `_signInMobile()` in `AuthService`.

---

### 8.2 Windows / Linux Desktop

- SQLite via `sqflite_common_ffi` — initialized with `sqfliteFfiInit()` before `runApp`
- Firebase via `firedart` — avoids the native C++ Firebase SDK and its CMake build complexity
- Auth via `WindowsAuthService` — spins up a local HTTP server on a loopback port to capture the Google OAuth redirect
- Tokens stored in Windows Credential Manager via `flutter_secure_storage`
- Session restored on cold start via `AuthService.restoreSession()`
- Crash logging to `jot_crash.log` next to the executable via `runZonedGuarded`

**Windows release assembly:**
The compiled output lives in `build/windows/runner/Release/`. A manually assembled `JotApp_Release/` folder on the Desktop contains the exe + required DLLs. See `SESSION_PROGRESS.md` for current launch issue status.

---

### 8.3 macOS

- Uses native `sqflite` (macOS is supported)
- Firebase via native SDK (requires `flutterfire configure`)
- Flat design theme, transparent AppBar

---

### 8.4 Web (Preview)

- `kIsWeb == true` → `WebStorageService` (SharedPreferences) replaces SQLite
- Firebase Auth not configured for web
- Intended as a read-only preview / demo mode

---

## 9. Dependency Injection & Interfaces

Every service has a corresponding interface in `lib/services/i_*.dart`:

| Interface | Concrete Implementation(s) |
|---|---|
| `ILocalStorageService` | `LocalStorageService`, `WebStorageService` |
| `IRemoteStorageService` | `FirestoreService` (wraps mobile/desktop impls) |
| `IAuthService` | `AuthService` |
| `INoteService` | `NoteService` |
| `ISyncEngine` | `SyncEngine` |
| `IConfigService` | `ConfigService` |
| `IProgressService` | `ProgressService` |
| `IConflictResolver` | `ConflictResolver` |
| `IConnectivityMonitor` | `ConnectivityMonitor` |

This pattern means:
1. Unit tests inject mock implementations without touching real storage or network
2. Swapping backends (e.g., replacing Telegram with S3) only requires a new `IRemoteStorageService` implementation
3. `SyncEngine` and `NoteService` are constructed with interfaces, not concrete types

**Wiring happens in `_initializeServices()` in `main.dart`** — a simple manual DI function that constructs and connects all services before `runApp`.

> Note: `NoteService` and `SyncEngine` currently accept `LocalStorageService` and `SyncEngine` as concrete types in some call sites (cast via `as dynamic`). This is a known rough edge — tracked in the roadmap.

---

## 10. Sync Protocol

```
Device A                    SyncEngine                   Remote (Firestore + Telegram)
   │                            │                                │
   │── createNote() ──────────► │                                │
   │                            │── insertNote() (local) ──────► SQLite
   │                            │── syncNow() (unawaited) ──────►│
   │                            │                                │
   │                            │◄── checkConnectivity() ────────│
   │                            │                                │
   │                            │── processFailedQueue() ────────│
   │                            │── pullRemoteChanges() ─────────►│
   │                            │◄── remoteNotes[] ──────────────│
   │                            │── resolveConflicts() ──────────│
   │                            │── pushLocalChanges() ──────────►│
   │                            │◄── updatedNote (telegramId) ───│
   │                            │── updateNote() (local) ────────►SQLite
   │                            │                                │
   │◄── SyncState.success ──────│                                │
```

**Connectivity-triggered sync:** When the device comes back online after being offline, `_handleConnectivityChange` fires `syncNow` automatically — no user action required.

**Real-time sync:** `_remote.watchNotes(userId)` provides a live stream. When another device pushes a change, Firestore notifies this device and `_handleRemoteUpdate` merges it immediately (skipped if a full sync is already in progress to avoid races).

---

## 11. Conflict Resolution

Full detail in [§5.3](#53-conflictresolver). Summary:

- **Strategy:** Last-Write-Wins on `modifiedAt`
- **Tiebreak:** Lexicographic note ID (deterministic across all devices)
- **Scope:** Per-note — no field-level merging
- **Delete propagation:** Soft-deleted notes are pushed to remote; remote deletes the content; local hard-deletes after confirmation

**Limitation:** LWW can lose data if two devices edit the same note offline simultaneously and both have the same `modifiedAt` millisecond. In practice this is extremely rare. A future improvement would be operational transforms or a CRDT-based merge.

---

## 12. Authentication Flow

### Desktop (Windows/Linux)

```
User clicks "Sign in with Google"
  → WindowsAuthService.signIn()
    → Opens system browser to Google OAuth URL
    → Starts local HTTP server on loopback (e.g. localhost:8080)
    → User completes Google sign-in in browser
    → Google redirects to localhost:8080?code=...
    → WindowsAuthService exchanges code for tokens via HTTP POST
    → Returns {uid, email, displayName, idToken, refreshToken, accessToken}
  → AuthService stores all tokens in FlutterSecureStorage
  → AuthService emits AuthState(authenticated)
  → SyncEngine.start(userId) called
```

### Session Restore (Desktop)

```
App cold start
  → _initializeServices()
    → AuthService.restoreSession()
      → reads userId from FlutterSecureStorage
      → reads idToken + refreshToken
      → re-injects into firedart token provider
      → emits AuthState(authenticated) if successful
```

### Sign Out

```
User taps Sign Out
  → AuthService.signOut()
    → GoogleSignIn.signOut() (mobile) or no-op (desktop)
    → clears all keys from FlutterSecureStorage
    → emits AuthState(unauthenticated)
    → SyncEngine.stop() called
    → Router navigates to LoginScreen
```

---

## 13. Database Schema & Migrations

**Table: `notes`** (SQLite, `jot_app.db`)

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID v4 |
| `userId` | TEXT NOT NULL | Firebase UID |
| `title` | TEXT NOT NULL | |
| `content` | TEXT NOT NULL | Plain text or JSON checklist |
| `createdAt` | INTEGER NOT NULL | Epoch milliseconds |
| `modifiedAt` | INTEGER NOT NULL | Epoch milliseconds |
| `isDeleted` | INTEGER NOT NULL DEFAULT 0 | 0=active, 1=soft-deleted |
| `remoteId` | TEXT | Legacy field (pre-Telegram) |
| `telegramMessageId` | TEXT | Telegram message pointer |
| `type` | TEXT NOT NULL DEFAULT 'text' | 'text' or 'checklist' |
| `tags` | TEXT | JSON-encoded string array |
| `color` | TEXT | Hex color string |
| `isPinned` | INTEGER NOT NULL DEFAULT 0 | 0/1 boolean |
| `isLocked` | INTEGER NOT NULL DEFAULT 0 | 0/1 boolean |
| `pinHash` | TEXT | Salted hash of user PIN |

**Index:** `idx_notes_userId ON notes(userId)`

**Migration history:**

| Version | Changes |
|---|---|
| 1 | Initial schema |
| 2 | Added `remoteId`, `telegramMessageId` |
| 3 | Added `type` |
| 4 | Added `tags`, `color` |
| 5 | Added `isPinned`, `isLocked` |
| 6 | Added `pinHash` |

---

## 14. Error Handling Strategy

**Startup errors:** `runZonedGuarded` wraps the entire app. Unhandled errors are written to `jot_crash.log` next to the executable. The UI shows a scrollable red error screen instead of a blank crash.

**Service initialization errors:** `_initializeServices()` is called inside a `FutureBuilder`. If it throws, the error + stack trace are displayed on screen — useful for diagnosing Firebase config issues.

**Sync errors:** Individual note push/pull failures are caught per-note. Failed notes go into `_failedOperationsQueue` and are retried on the next sync cycle. The `SyncState.errorMessage` field carries a human-readable description surfaced in the `SyncIndicator` tooltip.

**Retry policy:** `_retryOperation` wraps pull and push with up to 3 attempts and exponential backoff (1s → 2s → 4s, capped at 16s).

**Auth errors:** `AuthResult` carries a `success` bool and `errorMessage`. The `LoginScreen` displays the error message inline.

**Database errors:** SQLite operations are not individually try-caught at the service level — errors propagate up to the caller. `NoteService` methods are `async` so callers can catch if needed. This is an area for improvement.

**Non-fatal patterns:** Several catch blocks are intentionally empty or log-only (marked with comments). These cover cases like connectivity subscription errors and firedart token restore failures that should not crash the app.

---

## 15. Testing Strategy

### Unit Tests (`test/unit/`)

Pure Dart tests with no Flutter framework dependency. All services are tested against their interfaces using `mockito`-generated mocks.

| Test File | Coverage |
|---|---|
| `models/note_model_test.dart` | Serialization round-trips, `copyWith`, `hashPin`, `verifyPin` |
| `auth_service_test.dart` | Sign-in, sign-out, session restore, credential storage |
| `note_service_test.dart` | CRUD, stream emissions, pin/lock toggle |
| `sync_engine_test.dart` | Sync cycle, conflict handling, retry logic, queue |
| `local_storage_service_test.dart` | SQLite CRUD, soft/hard delete, incremental query |
| `utils/conflict_resolver_test.dart` | LWW logic, tiebreak, `hasConflict` |
| `utils/connectivity_monitor_test.dart` | Online/offline state transitions |
| `utils/platform_theme_test.dart` | Theme returned per platform |

**Mock generation:** Run `flutter pub run build_runner build` to regenerate `.mocks.dart` files after changing interfaces.

### Widget Tests (`test/widget/`)

Flutter widget tests using `flutter_test`. Pump widgets with mock providers.

| Test File | Coverage |
|---|---|
| `login_screen_test.dart` | Sign-in button, loading state, error display, navigation |
| `note_editor_screen_test.dart` | Field display, save indicator, delete dialog, validation |
| `sync_indicator_test.dart` | Icon per state, badge count, animation, tooltip |
| `responsive_layout_test.dart` | Two-pane at ≥800px, single-pane at <800px |

### Integration Tests (`test/integration/`)

End-to-end flow tests with in-memory SQLite (`sqflite_common_ffi`) and mock remote.

| Test File | Coverage |
|---|---|
| `auth_flow_test.dart` | Sign-in creates session, sign-out clears data, auth triggers sync lifecycle |
| `sync_flow_test.dart` | Create→sync, remote→local, conflict resolution, offline→online |

### Running Tests

```bash
# All tests
flutter test

# Unit only
flutter test test/unit

# Widget only
flutter test test/widget

# Single file
flutter test test/unit/models/note_model_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Property-Based Testing

The architecture is designed for PBT but the `test/property/` directory is not yet populated. Candidate properties:

- `Note.toJson()` then `Note.fromJson()` is identity for all valid inputs
- `Note.toSqlite()` then `Note.fromSqlite()` is identity for all valid inputs
- `ConflictResolver.resolveConflict(a, b)` is deterministic (same result regardless of call order when timestamps differ)
- `SyncEngine` converges to the same state regardless of push/pull ordering

---

## 16. Dependencies Reference

### Runtime

| Package | Version | Purpose |
|---|---|---|
| `firedart` | ^0.9.8 | Firestore + Firebase Auth for desktop (no native SDK) |
| `teledart` | ^0.6.1 | Telegram Bot API client |
| `google_sign_in` | ^6.3.0 | Google OAuth |
| `http` | ^1.6.0 | HTTP client (OAuth token exchange) |
| `sqflite` | ^2.3.0 | SQLite on mobile/macOS |
| `sqflite_common_ffi` | ^2.4.0+2 | SQLite on Windows/Linux via FFI |
| `path` | ^1.8.3 | File path utilities |
| `flutter_secure_storage` | ^9.2.2 | OS keychain / credential store |
| `uuid` | ^4.3.3 | UUID v4 generation |
| `connectivity_plus` | ^5.0.2 | Network connectivity detection |
| `provider` | ^6.1.1 | State management |
| `flutter_staggered_grid_view` | ^0.7.0 | Masonry grid layout |
| `google_fonts` | ^8.0.2 | Outfit + Inter fonts |
| `image_picker` | ^1.0.7 | Image attachment (infrastructure ready) |
| `shared_preferences` | ^2.2.2 | Web storage fallback |

### Dev

| Package | Version | Purpose |
|---|---|---|
| `flutter_lints` | ^6.0.0 | Lint rules |
| `mockito` | ^5.6.4 | Mock generation for tests |
| `build_runner` | ^2.13.1 | Code generation |
| `flutter_launcher_icons` | ^0.13.1 | App icon generation |

---

## 17. Known Issues & Roadmap

### Active Issues

| Issue | Status | Notes |
|---|---|---|
| Windows `.exe` not launching | 🔴 Open | Silent crash on double-click. Run from terminal to see error. Possible DLL mismatch or `app.so`/`app.dll` rename issue. |
| Mobile Firebase Auth stubbed | 🟡 Partial | `_signInMobile()` returns error. Needs `firebase_core` + `firebase_auth` added back to `pubspec.yaml`. |
| Widget/integration test mock issues | 🟡 Partial | Some test files have missing mock imports. Run `build_runner` to regenerate. |
| `as dynamic` casts in `main.dart` | 🟡 Tech debt | `NoteService` and `SyncEngine` constructed with concrete types cast to interface. Should use interfaces directly. |
| PIN hash is not cryptographically strong | 🟡 By design | Uses a simple fold hash. Sufficient for a local convenience lock, not a security boundary. |

### Roadmap

| Feature | Priority | Notes |
|---|---|---|
| Fix Windows launch crash | High | Debug with `jot_app.exe` from terminal |
| Re-enable mobile Firebase Auth | High | Add native Firebase packages back |
| Image attachments (Telegram upload) | Medium | Infrastructure exists, logic incomplete |
| Storage encryption (SQLCipher) | Medium | Task 24 — deferred, requires `sqlcipher_flutter` |
| Property-based tests | Medium | `test/property/` directory ready |
| CRDT-based conflict resolution | Low | Replace LWW for better multi-device offline support |
| Dark mode per-platform themes | Low | Currently one dark theme for all platforms |
| Accessibility audit | Low | WCAG compliance review needed |
| Web production backend | Low | `WebStorageService` is demo-only |

---

## 18. Setup & Running Locally

### Prerequisites

- Flutter SDK ≥ 3.0.0 (`flutter --version`)
- For Android: Android Studio + `google-services.json` from Firebase Console
- For Windows: Visual Studio 2022 with "Desktop development with C++" workload
- For macOS: Xcode 14+

### Install

```bash
git clone <repo>
cd jot_app
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Firebase Setup (Desktop)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication → Google Sign-In**
3. Enable **Firestore Database**
4. Copy your Web API key into `main.dart` → `fd.FirebaseAuth.initialize('<YOUR_API_KEY>', ...)`
5. Update `projectId` in `main.dart`

See `FIREBASE_SETUP.md` for detailed steps.

### Telegram Setup

1. Create a bot via [@BotFather](https://t.me/BotFather) and copy the token
2. Create a private channel and add the bot as admin
3. Get the channel chat ID (negative number, e.g. `-1003461886227`)
4. Update `TelegramService` with your bot token and chat ID

> ⚠️ Never commit bot tokens or API keys. Use environment variables or a local config file excluded from `.gitignore`.

### Run

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows

# Linux
flutter run -d linux

# macOS
flutter run -d macos

# Web (preview)
flutter run -d chrome
```

### Build Release

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

---

*This document was generated from source analysis of the Jot? codebase as of May 2026. Keep it updated as the architecture evolves.*
