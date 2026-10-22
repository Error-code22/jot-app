# Jot? — Project Guide & Handoff

> **Current release:** 2.4.0+4 · **Flutter:** 3.44 · **Last updated:** 2026-10-23
>
> This is the authoritative description of the app's current state. `ARCHITECTURE.md`
> describes the earlier Firestore + Telegram era and is kept for history only.

---

## 1. What is Jot?

A cross-platform notes app (Android, Windows, Linux, macOS; web is preview-only).
Users sign in with email/password (Supabase Auth), write text or interactive
checklist notes, attach images and voice recordings, lock private notes, and
everything syncs offline-first across devices.

**Core features (2.4.0):**
- Email/password sign-up & sign-in via Supabase Auth (forgot-password reset, session restore)
- Notes CRUD: text + checklist types, tags, colors, pin, **PIN + biometric lock**
- **Private previews**: hide note content/thumbnails per note or globally, and for locked notes
- **Voice notes**: record audio (`record`) and play it back (`audioplayers`), stored in the
  user's own Supabase Storage bucket — **no third-party transcription**
- Offline-first sync: local SQLite is the source of truth; `SyncEngine` pushes/pulls to
  Supabase with last-write-wins + a conflict dialog for major conflicts
- Realtime pull (Supabase Realtime) for live cross-device updates
- Image attachments: pick → compress (`flutter_image_compress`) → upload via the
  `image-proxy` Edge Function → Cloudinary (keys live only in the function)
- **Revocable share links**: a snapshot of a note is published to `shared_notes` and
  rendered as a public page by the `shared-note` Edge Function
- Todo lists with priorities, due dates, recurrence, and **optional reminders**
- **In-app updates**: full-screen update page with release notes, download progress,
  optional SHA-256 verification, and the Android system installer
- Backup/export (JSON/ZIP), import (.txt/.md/folders), grid/list/compact views,
  responsive two-pane layout, dark/light/system theme, adjustable editor font size
- Background sync scheduling (WorkManager) and local notifications

**Status:** `flutter analyze` clean · `flutter test` 199/199 passing · Windows release
build verified after the MSVC fix (see §9).

---

## 2. Tech stack

| Concern | Technology |
|---|---|
| UI | Flutter 3.44 (Material 3), `provider` state management |
| Backend | Supabase — Auth, Postgres, Storage, Realtime, Edge Functions |
| Edge functions | `image-proxy` (Cloudinary uploads, JWT required); `shared-note` (public, `verify_jwt = false`) |
| Local DB | SQLite via `sqflite` (mobile/macOS) / `sqflite_common_ffi` (Windows/Linux); `WebStorageService` (SharedPreferences) on web |
| Images | `image_picker` → `flutter_image_compress` → Cloudinary (via edge function) |
| Audio | `record` (AAC-LC in .m4a) + `audioplayers`; uploaded to the `note-audio` bucket |
| Biometrics | `local_auth` (Android `FlutterFragmentActivity`, iOS Face ID, Windows Hello) |
| Notifications | `flutter_local_notifications`, `home_widget`, `workmanager` (Android) |
| Versioning | `package_info_plus` surfaced through `AppInfo` |
| Updates | `http` + `crypto` (SHA-256) + `open_filex` (Android installer) |

Key packages: `supabase_flutter`, `provider`, `sqflite`, `connectivity_plus`,
`file_picker`, `uuid`, `crypto`, `http`, `intl`, `record`, `audioplayers`,
`local_auth`, `package_info_plus`, `open_filex`, `timezone`/`flutter_timezone`.

---

## 3. History

1. **Firebase + Telegram era** — Firestore + Telegram bot + Google Sign-In. Windows
   launch fixes (CMake install prefix, icudtl.dat path, CWD fix in `windows/runner/main.cpp`).
2. **Supabase migration** — backend replaced with Supabase; email/password auth;
   `lib/config.dart` holds the public anon key (security is via RLS).
3. **Finalization session** — removed dead Firebase/Telegram code, zero analyzer issues,
   rewrote the test suite for Supabase.
4. **2.4.0 release session (this update)** — biometric locks, private previews, voice
   notes, functional settings, todo reminders, working feedback links, revocable share
   links, and a full-screen GitHub/Supabase update flow. Backend migrations and Edge
   Functions deployed. Added the Windows MSVC build fix.

---

## 4. Repository layout (current)

```
lib/
├── main.dart                      # Bootstrap + provider wiring + auth lifecycle
├── config.dart                    # AppConfig: Supabase URL/anon key + githubReleasesRepo
├── core/
│   ├── app_info.dart              # Runtime version/package identity (package_info_plus)
│   ├── app_bootstrapper.dart      # Conditional import switcher (native vs web)
│   ├── app_bootstrapper_native.dart
│   └── app_bootstrapper_stub.dart
├── models/                        # Note, ChecklistItem, AuthState, User, SyncState,
│                                  # SyncResult, TodoItem/TodoList, ProgressEntry
├── services/
│   ├── i_*.dart                   # Abstract interfaces
│   ├── supabase_service.dart      # IAuthService + IRemoteStorageService
│   ├── local_storage_service.dart # SQLite CRUD, schema v8, soft deletes
│   ├── note_service.dart          # Note CRUD (writes local, triggers sync)
│   ├── sync_engine.dart           # Bidirectional sync + conflict resolution
│   ├── cloudinary_service.dart    # Image upload via edge function (+ Storage fallback)
│   ├── audio_service.dart         # Voice recording + note-audio upload
│   ├── biometric_service.dart     # local_auth wrapper (canUseDeviceAuth)
│   ├── app_settings.dart          # Persisted preferences (privacy, updates, biometrics)
│   ├── update_service.dart        # GitHub-first / Supabase-fallback release checks
│   ├── share_link_service.dart    # shared_notes snapshot create/list/revoke
│   ├── notification_service.dart  # Local notifications + reminders
│   ├── todo_service.dart, backup_service.dart, import_service*.dart, …
├── screens/                       # login, responsive_notes, note_editor, todo, settings,
│                                  # profile, feedback, import, support, terms, update_screen
├── widgets/                       # note cards, sync_indicator, jot_ui, conflict dialog
└── utils/                         # platform_theme, theme/view_mode providers,
                                   # adaptive_logo, markdown_renderer, conflict resolver

supabase/
├── migrations/001_create_notes_table.sql
├── migrations/002_create_feedback_table.sql
├── migrations/003_release_features.sql
├── migrations/004_release_manifest_metadata.sql
└── functions/image-proxy/ · functions/shared-note/

test/  unit/ · widget/ · integration/
android/ windows/ linux/ macos/ web/   # platform projects
public/                                 # logo.png (dark) + logo_light.png
```

---

## 5. Architecture

```
UI (screens/widgets)
  │  Provider<IAuthService> / NoteService / SyncEngine / TodoService / AppSettings …
  ▼
NoteService ──► SyncEngine ──► ConflictResolver (LWW + user-resolvable major conflicts)
  │                 │
  ▼                 ▼
LocalStorageService (SQLite)     SupabaseService (IRemoteStorageService)
                                    ├── Postgres `notes` (upsert/select/delete)
                                    ├── Storage `images` / `note-audio`
                                    └── Realtime stream (live pull)
```

- **Write-local-first:** every mutation hits SQLite first, then `unawaited(syncNow())`.
- **Sync cycle:** failed-op retry → pull (×3, exponential backoff) → push → state transition.
- **Failures surface:** remote methods rethrow so `SyncEngine` can retry (no false "synced").
- **Auth routing:** `StreamProvider<AuthState>` picks LoginScreen vs ResponsiveNotesScreen;
  `main.dart` starts/stops SyncEngine + scheduler on auth changes and runs the update check.
- **DI:** `AppBootstrapper.initialize()` builds every service into a map consumed by
  `MultiProvider` in `main.dart`.

---

## 6. Data model & backend

### SQLite `notes` (schema v8)
`id`, `userId`, `title`, `content` (plain text or JSON checklist array), `createdAt`,
`modifiedAt`, `isDeleted` (soft delete), `type` (text|checklist), `telegramMessageId`
(legacy, kept for migration compat), `tags` (JSON), `color`, `isPinned`, `isLocked`,
`pinHash`, `imageIds` (JSON of Cloudinary URLs / storage paths), **`audioIds`** (JSON),
**`hidePreview`**.

`Note.toSupabase()` / `Note.fromSupabase()` map camelCase ↔ snake_case.

### Supabase (live project `bvgtzjsnqhqyeyinbhdk`)
| Object | Purpose |
|---|---|
| `notes` | note rows, owner-scoped RLS, realtime enabled |
| `feedback` | bug reports / feature requests (owner-scoped) |
| `shared_notes` | revocable share snapshots (`token`, `snapshot`, `expires_at`, `revoked`) |
| `app_releases` | update manifest (`version`, `platform`, `notes`, `download_url`, `size_bytes`, `sha256`) |
| Storage `images` | note images (public read; authenticated insert/update/delete own) |
| Storage `note-audio` | voice notes (public read; authenticated insert/update/delete own) |

Migrations are tracked with the Supabase CLI. Migration `001` was applied by hand
originally and later marked applied with `supabase migration repair --status applied 001`.

---

## 7. Security notes

- `lib/config.dart` anon key is public by design; table access is RLS-scoped to `auth.uid() = user_id`.
- Cloudinary credentials exist **only** in the `image-proxy` function. The service-role key
  is never in the app.
- `shared-note` runs with `verify_jwt = false` but validates the unguessable token itself;
  it escapes all content, only embeds http(s) media URLs, and never returns the raw snapshot
  or the note's `pinHash`.
- PIN lock is a convenience feature with a weak hash — fine for local locking, not secrets.
  Biometrics are attempted first, PIN is the fallback.
- Audio is stored only in the user's own Supabase project; **no transcription provider is used**.
- Legacy Firebase API keys still exist in git history (from the pre-Supabase era). Firebase
  API keys are client-side identifiers, but the old Firebase projects should be deleted or
  restricted.

---

## 8. Update & release flow

`UpdateService.checkForUpdates()` tries sources in order:

1. **GitHub Releases** — `GET /repos/{owner}/{repo}/releases/latest` for
   `AppConfig.githubReleasesRepo`. Tag → version, body → notes, platform-matched asset
   (`.apk`, `.exe`/`.zip`, `.dmg`/`.zip`, `.AppImage`/`.deb`/`.tar.gz`), plus asset `size`
   and SHA-256 `digest`. Requires the repo/releases to be **public**.
2. **Supabase `app_releases`** — fallback manifest (read-only for clients).

If a newer version exists, `update_screen.dart` opens a full-screen page with the notes,
download size, a progress bar, **Cancel**, an integrity line, and "Not now". On Android the
APK is downloaded, its SHA-256 verified when published, and the system installer is opened.

---

## 9. Build & run

```powershell
flutter analyze
flutter test
flutter run -d windows

flutter build windows --release     # → build\windows\x64\runner\Release (complete bundle)
flutter build apk --release         # → build\app\outputs\flutter-apk\app-release.apk
```

The Windows **install prefix is the runner bundle directory** (`runner\Release`), matching
Flutter's template, so the plugin DLLs, `data\flutter_assets` and `data\app.so` land beside
`jot_app.exe`. Run the app from there (or via `flutter run -d windows`). An earlier version
of this project forced the prefix to a separate `build\windows\x64\install` folder, which is
why launching `runner\Release\jot_app.exe` used to fail with missing `*_plugin.dll` errors.

Windows: the built exe needs `sqlite3.dll` beside it (bundled via `windows/libs/` + the CMake
install rule) and the `data/` layout (icudtl.dat, flutter_assets, app.so). Do not run with
RivaTuner/MSI Afterburner or Windhawk — their DLL injection crashes Flutter.

**Windows build fix (MSVC 14.51 / Visual Studio 18):** `local_auth_windows 2.0.2` compiles
with `/await` + `<experimental/coroutine>`, which new MSVC turns into the hard error STL1011.
`windows/CMakeLists.txt` defines `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` to
suppress it until the plugin migrates to the C++20 coroutine headers.

Android: no Firebase config needed (`google-services.json` was removed with Firebase).
`MainActivity` extends `FlutterFragmentActivity` (required by `local_auth`). The manifest
requests `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`, `RECORD_AUDIO`,
and `REQUEST_INSTALL_PACKAGES`.

---

## 10. Known limitations / roadmap

- In-app updates need the GitHub repository to stay **public**; otherwise the Supabase
  manifest is used (publishing still works).
- iOS has not been built/verified from this Windows machine.
- Web is preview-only (SharedPreferences storage).
- PIN hash is weak by design (use biometrics for real protection).
- Legacy Firebase API keys remain in git history (revoke the old projects).
- Historic docs (`ARCHITECTURE.md`) are stale; this file supersedes them.

---

*End of handoff — regenerate this file when the architecture changes again.*
