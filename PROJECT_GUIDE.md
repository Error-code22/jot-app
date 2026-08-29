# Jot? — Project Guide & Handoff

> Written 2026-08-26 during the finalization session. This file is the authoritative
> description of the CURRENT state of the app (post-Supabase migration). Older docs
> (`ARCHITECTURE.md`, `SESSION_PROGRESS.md`, `ERRORS.md`) describe the earlier
> Firebase + Telegram era and are kept only for history.

---

## 1. What is Jot?

A cross-platform notes app (Android, Windows, Linux, macOS; web is preview-only).
Users sign in with email/password (Supabase Auth), write notes (text or interactive
checklists), attach images, and everything syncs across devices offline-first.

**Core features (current):**
- Email/password sign-up & sign-in via Supabase Auth (session restore on launch)
- Notes CRUD: text + checklist note types, tags, colors, pin, PIN-lock
- Offline-first sync: local SQLite is the source of truth; background SyncEngine
  pushes/pulls to Supabase with last-write-wins conflict resolution (+ user-resolvable
  conflict dialog for "major" conflicts)
- Realtime pull (Supabase Realtime) so changes from other devices appear live
- Image attachments: pick → compress (`flutter_image_compress`) → upload via
  Supabase Edge Function `image-proxy` → Cloudinary (keys live ONLY in the edge
  function, never in the app)
- Import .txt/.md files or folders (desktop)
- Todo lists (separate feature from notes, local storage)
- Dark/light/system theme, grid/list/compact view modes, adjustable editor font size
- Responsive layout: two-pane ≥800px, single-pane masonry below
- Background sync scheduling (WorkManager/`sync_scheduler.dart`)
- Backup service (`backup_service.dart` — local backup/restore)

---

## 2. Tech stack

| Concern | Technology |
|---|---|
| UI | Flutter 3.44 (Material 3), `provider` state management |
| Backend | Supabase — Auth, Postgres (`notes` table), Storage (`images` bucket), Realtime, Edge Functions |
| Edge function | `supabase/functions/image-proxy/` — receives image upload, forwards to Cloudinary |
| Local DB | SQLite via `sqflite` (mobile/macOS) / `sqflite_common_ffi` (Windows/Linux); `WebStorageService` (SharedPreferences) on web |
| Images | `image_picker` → `flutter_image_compress` → Cloudinary (via edge function) |
| Notifications | `flutter_local_notifications`, `home_widget`, `workmanager` (Android) |
| Auth session | Managed by `supabase_flutter` (persisted by the SDK on each platform) |

Key packages: `supabase_flutter ^2.3` (resolves to 2.16), `provider`, `sqflite`,
`connectivity_plus`, `file_picker`, `uuid`, `google_fonts`, `http`, `intl`.

---

## 3. History (why the repo looks the way it does)

1. **Firebase + Telegram era** — original backend was Firestore (metadata) +
   Telegram bot (note content) + Google Sign-In. Windows launch was fixed (CMake
   install prefix, icudtl.dat path, CWD fix in `windows/runner/main.cpp`).
2. **Supabase migration** — backend was replaced with Supabase (schema:
   `supabase/migrations/001_create_notes_table.sql`, RLS policies, realtime).
   Auth switched to email/password. `lib/config.dart` holds the Supabase URL +
   anon (publishable) key — the anon key is public by design, security is via RLS.
3. **Finalization session (this handoff)** — removed all dead Firebase/Telegram
   code, cleaned the analyzer to zero issues in `lib/`, switched screens to depend
   on the `IAuthService` interface instead of the concrete `SupabaseService`, and
   rewrote the broken test suite for the Supabase stack. Status at time of writing:
   - ✅ `lib/` analyzes with **no issues**
   - ✅ Dead files deleted: `firestore_*`, `telegram_service`, `windows_auth_service*`,
     `auth_service` (old Firebase impl), `fb_auth_stub`, `firebase_options.dart.bak`,
     plus root junk (`firestore.rules`, `firebase.json`, `ndk.zip`, `$flutterRoot/`, …)
   - ⏳ Tests being rewritten (widget/integration/unit) — see §8
   - ⏳ Mocks regenerated via `dart run build_runner build`
   - ⏳ `flutter test`, `flutter build windows --release`, `flutter build apk`

---

## 4. Repository layout (current)

```
lib/
├── main.dart                      # Bootstrap + provider wiring + routes
├── config.dart                    # AppConfig: Supabase URL + publishable (anon) key
├── core/
│   ├── app_bootstrapper.dart      # conditional import switcher (native vs web)
│   ├── app_bootstrapper_native.dart  # sqflite FFI init (Windows/Linux/macOS)
│   └── app_bootstrapper_stub.dart    # web stub (WebStorageService)
├── models/                        # Note, ChecklistItem, AuthState, User, SyncState,
│                                  # SyncResult, TodoItem/TodoList, IDEConfig, ProgressEntry
├── services/
│   ├── i_*.dart                   # abstract interfaces (IAuthService, ILocalStorageService,
│   │                              # IRemoteStorageService, INoteService, ISyncEngine, …)
│   ├── supabase_service.dart      # implements IAuthService + IRemoteStorageService
│   ├── local_storage_service.dart # SQLite CRUD, schema v7, soft deletes
│   ├── web_storage_service.dart   # web fallback (SharedPreferences)
│   ├── note_service.dart          # note CRUD API for UI (writes local, triggers sync)
│   ├── sync_engine.dart           # bidirectional sync + conflict detection/resolution
│   ├── sync_scheduler.dart        # periodic background sync
│   ├── cloudinary_service.dart    # image upload via edge function
│   ├── image_compress_service.dart# image compression before upload
│   ├── backup_service.dart        # local backup/restore
│   ├── todo_service.dart          # todo lists (ChangeNotifier)
│   ├── import_service*.dart       # txt/md import (io/stub conditional split)
│   └── (config_service, progress_service — dev-tooling services)
├── screens/                       # login, responsive_notes, note_editor, todo,
│                                  # settings, profile, import, support, terms, notes_list
├── widgets/                       # note_card, desktop_note_card, sync_indicator,
│                                  # jot_ui (glassmorphism helpers), drawing_canvas,
│                                  # conflict_resolver_dialog
└── utils/                         # platform_theme, theme_provider, view_mode_provider,
                                   # conflict_resolver, connectivity_monitor, color_utils

supabase/
├── migrations/001_create_notes_table.sql   # notes schema + RLS + realtime + storage
└── functions/image-proxy/                  # Cloudinary upload edge function

test/
├── unit/           # note_service, sync_engine, local_storage, import, models, utils
├── widget/         # login, note_editor, responsive_notes, sync_indicator + stubs.dart
└── integration/    # auth flow, note creation flow, sync engine flow

android/ windows/ linux/ macos/ web/   # platform projects
public/             # logo.png + images/
docs/               # per-task implementation notes (historic)
```

---

## 5. Architecture

```
UI (screens/widgets)
  │  Provider<IAuthService> / NoteService / SyncEngine / TodoService / ThemeProvider …
  ▼
NoteService ──► SyncEngine ──► ConflictResolver (LWW + user-resolvable major conflicts)
  │                 │
  ▼                 ▼
LocalStorageService (SQLite)     SupabaseService (IRemoteStorageService)
                                    ├── Postgres `notes` (upsert/select/delete)
                                    ├── Storage `images` (uploadBinary/getPublicUrl)
                                    └── Realtime stream (watchNotes → live pull)
```

- **Write-local-first:** every mutation hits SQLite first, then `unawaited(syncNow())`.
- **Sync cycle:** failed-op queue retry → pull (retry ×3, exp. backoff) → push →
  state transition syncing → success/error → idle.
- **Conflicts:** minor differences auto-resolve LWW (newest `modifiedAt`, ID tiebreak);
  "major" (title+content changed >20%) queue a `SyncConflict` and raise the
  `conflict_resolver_dialog.dart` UI (keep local / keep remote / merge).
- **Auth routing:** `StreamProvider<AuthState>` drives `/` → LoginScreen vs
  ResponsiveNotesScreen. `main.dart` wires `_setupAuthStateListener` to start/stop
  SyncEngine + SyncScheduler on auth changes.
- **DI:** manual — `AppBootstrapper.initialize()` builds every service and returns a
  map consumed by `MultiProvider` in `main.dart`.

## 6. Data model (notes)

SQLite table `notes` (schema version 7) and Supabase `notes` table (snake_case):
`id` (uuid), `userId`, `title`, `content` (plain text or JSON checklist array),
`createdAt`, `modifiedAt`, `isDeleted` (soft delete), `type` (text|checklist),
`telegramMessageId` (legacy column, kept for migration compat), `tags` (JSON),
`color` (hex), `isPinned`, `isLocked`, `pinHash` (lightweight hash, NOT a security
boundary), `imageIds` (JSON of Cloudinary public IDs).

`Note.toSupabase()` / `Note.fromSupabase()` map camelCase ↔ snake_case.

## 7. Security notes

- `lib/config.dart` anon key is public by design; all table access is RLS-scoped to
  `auth.uid() = user_id`.
- Cloudinary credentials exist ONLY in the edge function (`image-proxy`).
- The edge function requires a Supabase auth token (`Authorization: Bearer …`).
- PIN lock is a convenience feature with a weak hash — fine for local locking, not
  for secrets.
- Supabase keys/URL are currently embedded in `lib/config.dart` (this is standard for
  the anon key); the service-role key must never be added to the app.

## 8. Finalization checklist (this session)

Remaining steps in order:
1. Rewrite `test/integration/auth_flow_test.dart` (email/password flow, IAuthService)
2. Rewrite `test/unit/` auth/main tests for Supabase (`supabase_service_test.dart`,
   `config_test.dart`); delete Firebase-era `auth_service_test.dart`, `main_test.dart`
3. `dart run build_runner build --delete-conflicting-outputs` (regenerates `.mocks.dart`
   for `note_service_test`, `sync_engine_test`, `connectivity_monitor_test`,
   `sync_engine_flow_test`)
4. `flutter analyze` — expect 0 issues
5. `flutter test` — expect all green
6. `flutter build windows --release` — output `build/windows/x64/install/`
7. `flutter build apk --release` — output `build/app/outputs/flutter-apk/app-release.apk`
8. Update `README.md` (it still describes Firebase)
9. Delete or archive historic docs (`ARCHITECTURE.md`, `SESSION_PROGRESS.md`,
   `ERRORS.md`, `FIREBASE_SETUP.md` already gone) — decision pending

## 9. Build & run

```powershell
# Analyze / test
flutter analyze
flutter test
flutter test test/unit      # unit only
flutter test test/widget    # widget only

# Regenerate mockito mocks (after changing interfaces)
dart run build_runner build --delete-conflicting-outputs

# Run on Windows (hot reload: press r)
flutter run -d windows

# Release builds
flutter build windows --release     # → build\windows\x64\install\
flutter build apk --release         # → build\app\outputs\flutter-apk\app-release.apk
```

Windows gotchas (from history): the exe needs `sqlite3.dll` beside it (bundled via
`windows/libs/` + CMake install rule), `data/` layout (icudtl.dat, flutter_assets)
is fixed in `windows/CMakeLists.txt`, CWD fix in `windows/runner/main.cpp`. Do not
run with RivaTuner/MSI Afterburner or Windhawk — their DLL injection crashes Flutter.

Android needs `google-services.json`? **No** — Firebase was removed. Supabase needs
no platform config files; the app uses the embedded URL/key from `config.dart`.
(There is a legacy `android/app/` folder — re-verify build before shipping.)

## 10. Known limitations / roadmap

- `signInWithGmail()` returns "not configured" — OAuth (Google) login not wired for
  Supabase yet (would use `signInWithOAuth` + deep link setup)
- `SupabaseService` no longer holds a reference to `ILocalStorageService` (sync logic
  lives fully in `SyncEngine`); screens depend on `IAuthService`
- Web is preview-only (SharedPreferences storage)
- PIN hash is weak by design
- Historic docs are stale (this file supersedes them)

---

*End of handoff — regenerate this file if the architecture changes again.*
