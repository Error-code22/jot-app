@ECHO OFF
TITLE Jot? - Android Build

REM Keep window open on any error
IF "%1"=="" (
    CMD /K "%~f0" RUNNING
    EXIT /B
)

COLOR 0B
ECHO ============================================================
ECHO  Jot? Android APK Build
ECHO ============================================================
ECHO.

SET FLUTTER_ROOT=C:\src\DevTools\flutter
SET FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat
SET DART_SDK=%FLUTTER_ROOT%\bin\cache\dart-sdk
SET SETUP_PS1=C:\src\jot_app\setup_dart_sdk.ps1
SET PATH=%FLUTTER_ROOT%\bin;C:\src\DevTools\Git\cmd;C:\src\DevTools\JDK\bin;%PATH%
SET JAVA_HOME=C:\src\DevTools\JDK

REM --- Fix PowerShell execution policy ---
ECHO [1/6] Fixing PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force"
ECHO Done.
ECHO.

REM --- Ensure Dart SDK is present ---
ECHO [2/6] Checking Dart SDK...
IF EXIST "%DART_SDK%\bin\dart.exe" (
    ECHO Dart SDK already present.
) ELSE (
    ECHO Dart SDK missing - downloading now (this may take a few minutes)...
    powershell -ExecutionPolicy Bypass -NoProfile -File "%SETUP_PS1%"
    IF %ERRORLEVEL% NEQ 0 (
        ECHO ERROR: Failed to set up Dart SDK.
        PAUSE
        EXIT /B 1
    )
)
ECHO.

REM --- Check google-services.json ---
ECHO [3/6] Checking Firebase config...
IF NOT EXIST "C:\src\jot_app\android\app\google-services.json" (
    ECHO.
    ECHO WARNING: android\app\google-services.json not found!
    ECHO          Firebase Auth will not work without this file.
    ECHO          Download from: https://console.firebase.google.com
    ECHO          Project: jot-notes-420cf
    ECHO          Place at: C:\src\jot_app\android\app\google-services.json
    ECHO.
    ECHO Press any key to continue anyway, or Ctrl+C to cancel...
    PAUSE > NUL
)
ECHO.

REM --- Verify Flutter ---
ECHO [4/6] Checking Flutter...
CALL "%FLUTTER%" --version
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Flutter check failed.
    PAUSE
    EXIT /B 1
)
ECHO.

REM --- Get dependencies ---
ECHO [5/6] Getting dependencies...
CALL "%FLUTTER%" pub get --verbose
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: flutter pub get failed.
    PAUSE
    EXIT /B 1
)
ECHO.

REM --- Generate launcher icons ---
ECHO Generating app launcher icons...
CALL "%FLUTTER%" pub run flutter_launcher_icons
ECHO.

REM --- Build Android APK ---
ECHO [6/6] Building Android APK (10-20 minutes)...
ECHO Output: build\app\outputs\flutter-apk\app-release.apk
ECHO.
CALL "%FLUTTER%" build apk --release --verbose
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Android build failed.
    ECHO Common fixes:
    ECHO   - Missing google-services.json in android\app\
    ECHO   - JDK not found at C:\src\DevTools\JDK
    PAUSE
    EXIT /B 1
)

ECHO.
ECHO ============================================================
ECHO  BUILD SUCCESSFUL!
ECHO  APK: C:\src\jot_app\build\app\outputs\flutter-apk\app-release.apk
ECHO ============================================================
ECHO.
explorer "C:\src\jot_app\build\app\outputs\flutter-apk"
PAUSE
