@echo off
echo Building APK...
cd android
call gradlew.bat assembleDebug
cd ..
echo Committing to GitHub...
git add -A
git commit -m "Update TV Remote app"
git push origin main
echo Done! Now upload the new APK to GitHub releases.
pause