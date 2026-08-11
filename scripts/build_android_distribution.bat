@echo off
setlocal
cd /d "%~dp0.."

where fvm >nul 2>nul
if %errorlevel%==0 (
  set "FLUTTER_CMD=fvm flutter"
) else (
  set "FLUTTER_CMD=flutter"
)

set "AI_BUILD_DEFINES="
if exist "config\dart_defines.local.env" (
  set "AI_BUILD_DEFINES=--dart-define-from-file=config/dart_defines.local.env"
  echo Including local AI configuration in this build.
) else (
  echo No local AI configuration found. The assistant will remain disabled.
)

echo Building a universal release APK for every supported Android CPU...
call %FLUTTER_CMD% build apk --release --target-platform android-arm,android-arm64,android-x64 %AI_BUILD_DEFINES%
if errorlevel 1 goto :failed

echo Building smaller CPU-specific release APKs...
call %FLUTTER_CMD% build apk --release --split-per-abi %AI_BUILD_DEFINES%
if errorlevel 1 goto :failed

echo.
echo Done.
echo Share app-release.apk when you do not know the recipient's device CPU.
echo Share app-arm64-v8a-release.apk for almost all modern Android phones.
echo Share app-armeabi-v7a-release.apk for older 32-bit Android phones.
echo Share app-x86_64-release.apk only for x86_64 emulators.
echo Files: build\app\outputs\flutter-apk\
goto :end

:failed
echo Android distribution build failed. Review the Flutter output above.
exit /b 1

:end
endlocal
