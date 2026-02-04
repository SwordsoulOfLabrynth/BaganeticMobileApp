@echo off
echo ========================================
echo Firestore Database Setup Helper
echo ========================================
echo.
echo Opening Firestore setup page in your browser...
echo.
start https://console.cloud.google.com/firestore/databases/create?project=baganetic-mobile
echo.
echo Browser opened! Follow these steps:
echo.
echo 1. Sign in with your Google account (if not already)
echo 2. Click "Create database"
echo 3. Choose "Start in test mode"
echo 4. Select location: us-central (or closest to you)
echo 5. Click "Enable"
echo.
echo Waiting for database creation (this takes 1-2 minutes)...
echo.
echo After creation, press any key to verify...
pause >nul
echo.
echo Verifying database...
firebase firestore:databases:list --project=baganetic-mobile
echo.
echo If you see "(default)" database listed above, setup is complete!
echo.
pause
