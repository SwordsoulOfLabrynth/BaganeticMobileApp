@echo off
echo.
echo ================================================
echo    🏛️  BAGANETIC ONE-CLICK INSTALLER
echo ================================================
echo.
echo This installer will set up everything you need:
echo • Python packages and dependencies
echo • Node.js and npm packages  
echo • MongoDB database (with fallback mode)
echo • Environment configuration
echo • First-time database setup
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause >nul
echo.

REM Check if we're in the right directory
if not exist "app.py" (
    echo ❌ Error: app.py not found in current directory
    echo Please run this installer from the Baganetic project root folder
    echo.
    pause
    exit /b 1
)

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Python is not installed or not in PATH
    echo.
    echo Please install Python 3.8 or higher from:
    echo https://www.python.org/downloads/
    echo.
    echo Make sure to check "Add Python to PATH" during installation
    echo.
    pause
    exit /b 1
)

echo ✅ Python found
echo.

REM Run the Python setup script
echo 🚀 Starting automated setup...
python setup.py

if errorlevel 1 (
    echo.
    echo ❌ Setup failed! Please check the error messages above.
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================
echo    ✅ INSTALLATION COMPLETE!
echo ================================================
echo.
echo Your Baganetic application is ready to use!
echo.
echo Quick Start:
echo • Double-click START.bat to launch the application
echo • Or run: python scripts/start_all.py
echo.
echo Access URLs:
echo • Main App: http://localhost:5000
echo • Admin Panel: http://localhost:5002/admin
echo • AI Chatbot: http://localhost:5001
echo.
echo Admin Login:
echo • Username: admin
echo • Password: baganetic2025!
echo.
echo Press any key to launch the application now...
pause >nul

REM Launch the application
echo 🚀 Launching Baganetic...
call START.bat
