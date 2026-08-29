# Jot? — Project Progress Log
## Session: April 16, 2026

---

## Project Overview

**App Name:** Jot?  
**Type:** Flutter Windows Desktop (+ Android) notes app  
**Project Path:** `C:\src\jot_app`  
**Flutter SDK:** `C:\DevTools\flutter` (v3.41.6 stable)  
**Firebase Project:** `jot-notes-420cf`  
**Owner:** reueldroner22@gmail.com

### Architecture
- **Local storage:** SQLite via `sqflite_common_ffi`
- **Cloud backend:** Hybrid — Firedart (Firestore) + Telegram bot for note content
- **Auth:** Google Sign-In (bypassed for Windows, local user for now)
- **State management:** Provider
- **UI:** Material 3, responsive (desktop two-pane + mobile single-pane)

---

## What Was Already Built (Before This Session)

Previous agents (Antigravity, Kiro) had built:
- Full project structure with all services
- `LocalStorageService` — SQLite CRUD with soft deletes
- `AuthService` — Google Sign-In + firedart session management
- `FirestoreService` — firedart-based Firestore operations
- `TelegramService` — stores note content as Telegram channel messages
- `SyncEngine` — coordinates local ↔ remote sync
- `NoteService` — note CRUD orchestration
- `ResponsiveNotesScreen` — premium two-pane desktop + masonry mobile layout
- `NoteEditorScreen` — distraction-free editor with checklist support
- `LoginScreen` — glassmorphism design with Google Sign-In button
- `PlatformTheme` — platform-specific themes (Android/Windows/Linux/macOS)
- `JotUI` — glassmorphism utilities
- Unit tests, widget tests, integration tests

**Problem:** The Windows build had never successfully launched. The `.exe` was manually assembled but crashed silently.

---

## What Was Accomplished This Session

### 1. Fixed the Build System

**Problem:** `flutter build windows` failed with Firebase CMake errors.  
**Root cause:** `firebase_core`, `firebase_auth`, `cloud_firestore` were still registered as native plugins in the old project at `C:\Users\Droner-Inventer\Desktop\Projects\flutter-projects\jot_app`. The new project at `C:\src\jot_app` was already clean.

**Fixed:**
- Confirmed `pubspec.yaml` has no native Firebase plugins (uses `firedart` instead)
- `windows/flutter/generated_plugins.cmake` confirmed clean (no firebase entries)
- Set up pub cache at `C:\DevTools\pub_cache`

### 2. Fixed CMake Install Prefix

**Problem:** Build succeeded but INSTALL step failed — tried to write to `C:/Program Files/jot_app`.  
**Fix:** Added `CACHE PATH "Install path" FORCE` to the install prefix in `windows/CMakeLists.txt`.

### 3. Fixed Missing sqlite3.dll

**Problem:** `sqlite3_flutter_libs` package hangs the build indefinitely (downloads from internet).  
**Fix:** 
- Removed `sqlite3_flutter_libs` from pubspec
- Downloaded `sqlite3.dll` directly from sqlite.org
- Placed at `windows/libs/sqlite3.dll`
- Added CMake install rule to bundle it

### 4. Fixed icudtl.dat Path (The Main Crash)

**Problem:** App crashed with `[FATAL] ICU context is not valid. Tried: .../data/icudtl.dat`  
**Root cause:** Flutter engine looks for `icudtl.dat` in the `data/` subfolder, but CMake was installing it to the root install folder.  
**Fix:**
- Changed CMake install destination for `icudtl.dat` from root to `data/`
- Added `app.so` and `flutter_assets` install rules to `data/`

### 5. Fixed Working Directory (Double-Click Launch)

**Problem:** App only worked when launched from terminal, not by double-clicking.  
**Root cause:** `flutter::DartProject project(L"data")` uses a relative path. When double-clicked, Windows sets CWD to the user's home folder, not the exe folder.  
**Fix:** Modified `windows/runner/main.cpp` to:
1. Get the exe's own directory using `GetModuleFileNameW`
2. Set CWD to that directory
3. Use absolute path for the data directory

### 6. Identified and Fixed Third-Party DLL Injection

**Problem:** App still crashed after all above fixes. Crash offset `0x011f5a99` in `flutter_windows.dll`.  
**Discovery:** Read the WER crash report at `C:\ProgramData\Microsoft\Windows\WER\ReportArchive\`. Found:
- `RTSSHooks64.dll` (RivaTuner Statistics Server) injecting into the process
- `windhawk.dll` (Windhawk) injecting into the process  
**Fix:** User closed RivaTuner/MSI Afterburner and Windhawk. Crash offset changed to `0x00f53959`.

### 7. Fixed Debug vs Release Runtime Mismatch

**Problem:** Debug build loaded `MSVCP140D.dll` (debug runtime) but `flutter_windows.dll` is a release build — incompatible.  
**Fix:** Switched to `flutter build windows --release` for all testing.

### 8. Got the App Running

After all fixes, the app launched successfully showing the login screen with the Jot? UI.

### 9. Switched to ResponsiveNotesScreen

**Problem:** App was routing to `NotesListScreen` (basic) instead of `ResponsiveNotesScreen` (premium).  
**Fix:** Updated routing in `main.dart` to use `ResponsiveNotesScreen`.

### 10. Fixed Window Title

Changed `windows/runner/main.cpp` window title from `L"jot_app"` to `L"Jot?"`.

### 11. Fixed App Logo

**Problem:** `public/logo.png` was 67 bytes (empty placeholder).  
**Fix:** Used PowerShell + System.Drawing to properly convert `Jot logo.jpeg` to a real PNG file (13KB).

### 12. Created Windows App Icon

Used PowerShell + System.Drawing to convert the Jot logo to a proper ICO file at `windows/runner/resources/app_icon.ico`.

### 13. Bypassed Login for Windows

Since Google Sign-In on Windows desktop requires OAuth redirect setup (not yet implemented), added a bypass in `AuthService`:
- `isAuthenticated()` returns `true` on Windows
- `getCurrentUser()` returns a local dummy user

### 14. Set Up Hot Reload (flutter run)

Fixed `flutter run -d windows` by:
- Fixing CMake `add_custom_command` placement (must be in runner/CMakeLists.txt, not top-level)
- Manually copying DLLs and data folder to debug runner directory
- App now supports hot reload — press `r` in terminal for instant UI updates

### 15. Added Profile Dropdown Menu

Added to top-right of app bar:
- Circle avatar icon
- Dropdown with: user name/email header, Profile, Settings, Sign out (red)

### 16. Added Dark Mode

Created:
- `lib/utils/theme_provider.dart` — `ChangeNotifier` with Light/Dark/System modes, persisted via `SharedPreferences`
- `lib/screens/settings_screen.dart` — Settings screen with Appearance section (Light/Dark/System tiles with checkmarks)
- Dark theme in `PlatformTheme.getDarkTheme()` — deep purple/dark blue color scheme
- Moon/sun toggle icon in app bar for instant dark/light switch
- Settings menu item navigates to full settings screen

---

## Current App State

### Working Features
- ✅ App launches by double-clicking the exe
- ✅ Desktop two-pane layout (sidebar + editor)
- ✅ Create, edit, delete notes (local SQLite storage)
- ✅ Checklist notes
- ✅ Auto-save with debounce
- ✅ Dark mode / Light mode toggle
- ✅ Settings screen with theme selection
- ✅ Profile dropdown menu
- ✅ Sync indicator
- ✅ Hot reload development mode

### Not Yet Implemented
- ❌ Google Sign-In on Windows (needs OAuth redirect/local server setup)
- ❌ Cloud sync (Firestore + Telegram) — sync engine disabled to prevent hangs
- ❌ Image attachments
- ❌ Profile screen
- ❌ Android build (not tested this session)

---

## File Structure of Key Changes This Session

```
windows/
  CMakeLists.txt          — Fixed install prefix, icudtl.dat path, sqlite3, data folder
  libs/
    sqlite3.dll           — Downloaded from sqlite.org (3.46.1)
  runner/
    main.cpp              — Fixed working directory + absolute data path + window title
    CMakeLists.txt        — Added post-build copy for hot reload
    resources/
      app_icon.ico        — Converted from Jot logo JPEG

lib/
  main.dart               — Added ThemeProvider, switched to ResponsiveNotesScreen
  utils/
    theme_provider.dart   — NEW: Dark/Light/System theme management
    platform_theme.dart   — Added getDarkTheme()
  screens/
    responsive_notes_screen.dart  — Added profile dropdown, dark mode toggle
    settings_screen.dart          — NEW: Settings screen with theme options

public/
  logo.png                — Fixed: properly converted from JPEG to PNG

docs/
  FLUTTER_WINDOWS_FIX_GUIDE.md   — NEW: Complete fix guide for future projects
  PROJECT_PROGRESS.md            — NEW: This file
```

---

## How to Build and Run

### Hot Reload (Development)
```
cd C:\src\jot_app
C:\DevTools\flutter\bin\flutter.bat run -d windows
```
Press `r` to reload, `R` to restart, `q` to quit.

**Note:** First time after a clean build, you may need to manually copy DLLs:
```powershell
$d = "build\windows\x64\runner\Debug"
Copy-Item "windows\flutter\ephemeral\flutter_windows.dll" "$d\"
Copy-Item "windows\libs\sqlite3.dll" "$d\"
Get-ChildItem "build\windows\x64\plugins" -Recurse -Filter "*.dll" | % { Copy-Item $_.FullName "$d\" }
New-Item -ItemType Directory "$d\data" -Force
Copy-Item "windows\flutter\ephemeral\icudtl.dat" "$d\data\"
Copy-Item "build\flutter_assets" "$d\data\flutter_assets" -Recurse
```

### Release Build
```
cd C:\src\jot_app
C:\DevTools\flutter\bin\flutter.bat build windows --release
```
Output at: `build\windows\x64\install\` — this is the distributable folder.

### Important: Before Running
- Close RivaTuner Statistics Server / MSI Afterburner
- Close Windhawk
- These inject DLLs that crash Flutter apps

---

## Next Steps (Recommended)

1. **Google Sign-In on Windows** — Implement OAuth2 with a local HTTP redirect server
2. **Cloud Sync** — Re-enable and test the SyncEngine with Firestore + Telegram
3. **Image Attachments** — Complete the image picker + Telegram upload flow
4. **Android Build** — Test and fix the Android APK build
5. **App Icon** — Generate proper multi-size ICO from the Jot logo
6. **Installer** — Create an MSIX or NSIS installer for distribution
