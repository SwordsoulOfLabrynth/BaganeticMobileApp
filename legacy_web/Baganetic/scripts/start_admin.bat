@echo off
echo 🏛️ Baganetic Admin System Startup
echo ==================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

REM Check if we're in the right directory
if not exist "admin_backend.py" (
    echo ❌ admin_backend.py not found in current directory
    echo Please run this script from the Baganetic project root
    pause
    exit /b 1
)

echo ✅ Python found
echo ✅ Admin files found
echo.

REM Start the admin system
echo 🚀 Starting Baganetic admin system...
python scripts/start_admin.py

pause
