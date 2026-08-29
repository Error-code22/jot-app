# Flutter Windows Desktop — Crash Fix Guide
## The Definitive Reference for Getting a Flutter Windows App Running

**Written after fixing Jot? app on April 16, 2026**
**Read this file at the start of any new Flutter Windows desktop project.**

---

## The Core Problem

Flutter Windows desktop apps crash silently on launch. No error dialog, no console output — just nothing. This guide documents every root cause encountered and exactly how to fix each one.

---

## Environment Setup (What Worked)

- **Flutter SDK:** Downloaded as a ZIP (1.7GB), extracted to `C:\DevTools\flutter`
- **Flutter version:** 3.41.6 stable
- **Visual Studio:** Community 2026 with "Desktop development with C++" workload
- **Android SDK:** `C:\DevTools\Android\Sdk`
- **Pub cache:** `C:\Users\{username}\AppData\Local\Pub\Cache` (default)

**IMPORTANT:** Only have ONE Flutter SDK on the machine. Having two (e.g. `C:\src\flutter` AND `C:\DevTools\flutter`) causes version mismatches. Delete the old one.

Run `flutter doctor` — all items must be green before proceeding.

---

## Problem 1: Firebase CMake Build Failure

### Symptom
```
CMake Error at flutter/ephemeral/.plugin_symlinks/firebase_core/windows/CMakeLists.txt:119
add_subdirectory given source "...extracted/firebase_cpp_sdk_windows" which is not an existing directory.
```

### Cause
`firebase_core`, `firebase_auth`, `cloud_firestore` are native Flutter plugins that try to download the Firebase C++ SDK (600MB+) during CMake configuration. The download fails or times out.

### Fix
Remove all native Firebase plugins from `pubspec.yaml` and replace with `firedart`:

```yaml
# REMOVE these:
# firebase_core: ^2.x.x
# firebase_auth: ^4.x.x
# cloud_firestore: ^4.x.x

# ADD this instead:
firedart: ^0.9.8
```

In your Dart code, replace all Firebase imports:
```dart
// Instead of: import 'package:firebase_core/firebase_core.dart';
// Instead of: import 'package:firebase_auth/firebase_auth.dart';
// Instead of: import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firedart/firedart.dart' as fd;
```

Initialize firedart in `main()`:
```dart
if (Platform.isWindows || Platform.isLinux) {
  fd.FirebaseAuth.initialize(apiKey, fd.VolatileStore());
  fd.Firestore.initialize(projectId);
}
```

---

## Problem 2: CMake Install Prefix — "Cannot create directory: C:/Program Files/app"

### Symptom
```
CMake Error at cmake_install.cmake:90 (file):
  file cannot create directory: C:/Program Files/jot_app. Maybe need administrative privileges.
```

### Cause
Flutter's `windows/CMakeLists.txt` has a conditional install prefix that falls back to the CMake default (`C:/Program Files/...`) instead of the build directory.

### Fix
In `windows/CMakeLists.txt`, force the install prefix:

```cmake
# Replace this:
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
endif()

# With this:
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Install path" FORCE)
```

---

## Problem 3: Missing sqlite3.dll — App Crashes on SQLite Operations

### Symptom
App crashes silently. `sqflite_common_ffi` cannot find sqlite3.

### Cause
`sqflite_common_ffi` on Windows requires `sqlite3.dll` next to the executable. The `sqlite3_flutter_libs` package that normally provides this hangs indefinitely during build (it tries to download a prebuilt binary).

### Fix
Download sqlite3.dll directly from the official SQLite website and bundle it manually:

```powershell
# Download official precompiled DLL
Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-dll-win-x64-3460100.zip" -OutFile "sqlite3.zip"
Expand-Archive sqlite3.zip -DestinationPath sqlite3_extracted
# Copy to windows/libs/
New-Item -ItemType Directory windows\libs
Copy-Item sqlite3_extracted\sqlite3.dll windows\libs\sqlite3.dll
```

Then in `windows/CMakeLists.txt` add:
```cmake
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/libs/sqlite3.dll"
  DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
```

Do NOT add `sqlite3_flutter_libs` to pubspec.yaml — it hangs the build indefinitely.

---

## Problem 4: App Crashes — "ICU context is not valid"

### Symptom
```
[FATAL:flutter/fml/icu_util.cc(97)] Check failed: context->IsValid().
Must be able to initialize the ICU context.
Tried: C:\path\to\install\data\icudtl.dat
```

### Cause
The Flutter engine looks for `icudtl.dat` inside the `data/` subfolder (relative to the exe), but the CMake install step puts it in the root install folder.

### Fix — Part A: Fix CMakeLists.txt
Change the `icudtl.dat` install destination from root to `data/`:

```cmake
# Change this:
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

# To this:
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  COMPONENT Runtime)
```

### Fix — Part B: Fix main.cpp
The app must set its working directory to the exe's folder AND use an absolute path for the data directory. Edit `windows/runner/main.cpp`:

```cpp
// Add this BEFORE flutter::DartProject project(...)
wchar_t exe_path[MAX_PATH];
GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
std::wstring exe_dir(exe_path);
exe_dir = exe_dir.substr(0, exe_dir.find_last_of(L"\\/"));
SetCurrentDirectoryW(exe_dir.c_str());

// Use absolute path instead of relative "data"
std::wstring data_path = exe_dir + L"\\data";
flutter::DartProject project(data_path);
```

### Fix — Part C: Install app.so and flutter_assets
Add these to `windows/CMakeLists.txt`:

```cmake
install(FILES "${AOT_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  COMPONENT Runtime
  OPTIONAL)

install(DIRECTORY "${PROJECT_BUILD_DIR}flutter_assets"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  COMPONENT Runtime
  OPTIONAL)
```

---

## Problem 5: Third-Party DLL Injection Crashes (RivaTuner / Windhawk)

### Symptom
```
Faulting module: flutter_windows.dll
Exception code: 0xc0000409 (STATUS_STACK_BUFFER_OVERRUN)
Fault offset: 0x011f5a99  (always the same)
```
Loaded modules in crash report include:
- `C:\Program Files (x86)\RivaTuner Statistics Server\RTSSHooks64.dll`
- `C:\Program Files\Windhawk\Engine\1.7.3\64\windhawk.dll`

### Cause
RivaTuner Statistics Server (RTSS) and Windhawk inject DLLs into every process. These hooks corrupt Flutter's engine memory, causing a deterministic crash at startup.

### Fix
1. Close MSI Afterburner and RivaTuner Statistics Server completely (system tray → Exit)
2. Close Windhawk completely (system tray → Exit)
3. OR add `jot_app.exe` to RTSS exclusion list: open RTSS → click `+` → find exe → set "Application detection level" to None

**This is the most common silent crash cause on gaming PCs.**

---

## Problem 6: Debug Build Runtime Mismatch

### Symptom
Debug build crashes with `0xc0000409`. Crash report shows:
```
LoadedModule[21]=C:\Windows\SYSTEM32\MSVCP140D.dll   (Debug runtime)
LoadedModule[22]=C:\Windows\SYSTEM32\VCRUNTIME140D.dll
```
But `flutter_windows.dll` is a Release build.

### Fix
Always use `--release` for testing the final exe:
```
flutter build windows --release
```
The debug build is only for `flutter run` hot reload development.

---

## Problem 7: flutter run — "log reader stopped unexpectedly"

### Symptom
```
√ Built build\windows\x64\runner\Debug\jot_app.exe
Error waiting for a debug connection: The log reader stopped unexpectedly
```

### Cause
The debug exe is missing required DLLs and the `data/` folder next to it.

### Fix
After the first `flutter build windows --debug`, manually copy the required files:

```powershell
$debugDir = "build\windows\x64\runner\Debug"

# Copy flutter engine DLL
Copy-Item "windows\flutter\ephemeral\flutter_windows.dll" "$debugDir\"

# Copy plugin DLLs
Get-ChildItem "build\windows\x64\plugins" -Recurse -Filter "*.dll" | 
  ForEach-Object { Copy-Item $_.FullName "$debugDir\" }

# Copy sqlite3.dll
Copy-Item "windows\libs\sqlite3.dll" "$debugDir\"

# Create data folder with required files
New-Item -ItemType Directory "$debugDir\data" -Force
Copy-Item "windows\flutter\ephemeral\icudtl.dat" "$debugDir\data\"
Copy-Item "build\flutter_assets" "$debugDir\data\flutter_assets" -Recurse
```

Then run `flutter run -d windows` again.

---

## Problem 8: CMake "TARGET not created in this directory"

### Symptom
```
CMake Error at CMakeLists.txt:96 (add_custom_command):
TARGET 'jot_app' was not created in this directory.
```

### Cause
`add_custom_command(TARGET ...)` must be in the same CMakeLists.txt where the target is defined. The `jot_app` target is defined in `windows/runner/CMakeLists.txt`, not the top-level `windows/CMakeLists.txt`.

### Fix
Move any `add_custom_command(TARGET ${BINARY_NAME} ...)` from `windows/CMakeLists.txt` to `windows/runner/CMakeLists.txt`.

---

## Problem 9: sqlite3_flutter_libs Hangs the Build

### Symptom
`flutter build windows` hangs indefinitely at "Building Windows application..." with no progress. No error, just stuck.

### Cause
`sqlite3_flutter_libs` uses a Dart native hook that downloads a prebuilt sqlite3 binary from the internet. If the download stalls, the entire build hangs with no timeout.

### Fix
Remove `sqlite3_flutter_libs` from pubspec.yaml entirely. Use the manual sqlite3.dll approach described in Problem 3.

---

## The Complete windows/CMakeLists.txt (Final Working Version)

```cmake
cmake_minimum_required(VERSION 3.14)
project(jot_app LANGUAGES CXX)

set(BINARY_NAME "jot_app")
cmake_policy(VERSION 3.14...3.25)

# ... (standard Flutter boilerplate) ...

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})
add_subdirectory("runner")
include(flutter/generated_plugins.cmake)

# CRITICAL: Force install prefix to build directory
set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install" CACHE PATH "Install path" FORCE)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)

# CRITICAL: icudtl.dat goes in data/ subfolder
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data" COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()

# CRITICAL: Bundle sqlite3.dll manually
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/libs/sqlite3.dll" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)

# CRITICAL: Install app.so and flutter_assets in data/
install(FILES "${AOT_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data" COMPONENT Runtime OPTIONAL)
install(DIRECTORY "${PROJECT_BUILD_DIR}flutter_assets" DESTINATION "${CMAKE_INSTALL_PREFIX}/data" COMPONENT Runtime OPTIONAL)
```

---

## The Complete windows/runner/main.cpp Changes

```cpp
// Add BEFORE flutter::DartProject project(...)
wchar_t exe_path[MAX_PATH];
GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
std::wstring exe_dir(exe_path);
exe_dir = exe_dir.substr(0, exe_dir.find_last_of(L"\\/"));
SetCurrentDirectoryW(exe_dir.c_str());

// Use absolute path to data directory
std::wstring data_path = exe_dir + L"\\data";
flutter::DartProject project(data_path);

// Change window title
if (!window.Create(L"Your App Name", origin, size)) {
```

---

## Quick Checklist for New Flutter Windows Projects

- [ ] Only one Flutter SDK on the machine
- [ ] `flutter doctor` shows all green
- [ ] No `firebase_core`/`firebase_auth`/`cloud_firestore` in pubspec (use `firedart`)
- [ ] No `sqlite3_flutter_libs` in pubspec (use manual sqlite3.dll)
- [ ] `windows/CMakeLists.txt` has forced install prefix
- [ ] `icudtl.dat` installs to `data/` not root
- [ ] `app.so` and `flutter_assets` install to `data/`
- [ ] `windows/runner/main.cpp` uses `GetModuleFileNameW` + absolute data path
- [ ] `windows/libs/sqlite3.dll` exists (downloaded from sqlite.org)
- [ ] RivaTuner / Windhawk closed before testing
- [ ] Always test with `--release` build, not debug

---

## How to Run Hot Reload (Development Mode)

```
cd C:\your\project
C:\DevTools\flutter\bin\flutter.bat run -d windows
```

First run takes ~2 minutes to build. After that:
- Press `r` = hot reload (instant UI update, keeps state)
- Press `R` = hot restart (full restart, clears state)  
- Press `q` = quit

After the first run, if it crashes, manually copy DLLs and data folder as described in Problem 7.
