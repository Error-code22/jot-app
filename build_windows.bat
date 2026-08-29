@ECHO OFF
TITLE Jot? - Windows Build

REM Keep window open on any error
IF "%1"=="" (
    CMD /K "%~f0" RUNNING
    EXIT /B
)

COLOR 0A
ECHO ============================================================
ECHO  Jot? Windows Desktop Build
ECHO ============================================================
ECHO.

SET FLUTTER_ROOT=C:\src\DevTools\flutter
SET FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat
SET DART_SDK=%FLUTTER_ROOT%\bin\cache\dart-sdk
SET SETUP_PS1=C:\src\jot_app\setup_dart_sdk.ps1
SET PATH=%FLUTTER_ROOT%\bin;C:\src\DevTools\Git\cmd;C:\src\DevTools\JDK\bin;%PATH%

REM --- Fix PowerShell execution policy ---
ECHO [1/5] Fixing PowerShell execution policy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force"
ECHO Done.
ECHO.

REM --- Ensure Dart SDK is present ---
ECHO [2/5] Checking Dart SDK...
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

REM --- Verify Flutter ---
ECHO [3/5] Checking Flutter...
CALL "%FLUTTER%" --version
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Flutter check failed.
    PAUSE
    EXIT /B 1
)
ECHO.

REM --- Get dependencies ---
ECHO [4/5] Getting dependencies...
CALL "%FLUTTER%" pub get --verbose
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: flutter pub get failed.
    PAUSE
    EXIT /B 1
)
ECHO.

REM --- Build Windows release ---
ECHO [5/5] Building Windows release (5-15 minutes)...
ECHO Output: build\windows\x64\runner\Release\
ECHO.
CALL "%FLUTTER%" build windows --release --verbose
IF %ERRORLEVEL% NEQ 0 (
    ECHO ERROR: Windows build failed.
    PAUSE
    EXIT /B 1
)

ECHO.
ECHO ============================================================
ECHO  BUILD SUCCESSFUL!
ECHO  Output: C:\src\jot_app\build\windows\x64\runner\Release\
ECHO ============================================================
ECHO.
explorer "C:\src\jot_app\build\windows\x64\runner\Release"
PAUSE
