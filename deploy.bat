@echo off
echo ============================================
echo  TV Remote - Build and Deploy
echo ============================================

:: Set environment variables
set "NODE=%USERPROFILE%\node-v22.11.0-win-x64\node-v22.11.0-win-x64"
set "JAVA_HOME=%USERPROFILE%\OpenJDK21U-jdk_x64_windows_hotspot_21.0.12_8\jdk-21.0.12+8"
set "ANDROID_HOME=%USERPROFILE%\android-sdk"
set "PATH=%NODE%;%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;%PATH%"

cd /d "%USERPROFILE%\TVRemoteApp"

echo Step 1: Bump version...
powershell -ExecutionPolicy Bypass -File bump-version.ps1

echo Step 2: Sync Capacitor...
call npx.cmd cap sync android
echo Step 3: Build Debug APK...
cd android
set "JAVA_HOME=%USERPROFILE%\OpenJDK21U-jdk_x64_windows_hotspot_21.0.12_8\jdk-21.0.12+8"
set "ANDROID_HOME=%USERPROFILE%\android-sdk"
call gradlew.bat assembleDebug
cd ..

echo Step 4: Sign and rename APK...
powershell -ExecutionPolicy Bypass -File get-version.ps1
set /p VERSION=<version.tmp
del version.tmp
echo Version detected: %VERSION%
call "%ANDROID_HOME%\build-tools\34.0.0\apksigner.bat" sign --ks "%USERPROFILE%\TVRemoteApp\tvremote.keystore" --ks-key-alias tvremote --ks-pass pass:TVremote2026 --key-pass pass:TVremote2026 --out "android\app\build\outputs\apk\release\TVRemote-v%VERSION%.apk" "android\app\build\outputs\apk\release\app-release-unsigned.apk"
echo APK signed: TVRemote-v%VERSION%.apk

echo ============================================
echo  Done! Upload the APK to GitHub releases:
echo  android\app\build\outputs\apk\release\
echo ============================================
pause