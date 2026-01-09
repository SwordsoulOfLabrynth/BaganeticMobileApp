@echo off
echo.
echo ================================================
echo    🏛️  BAGANETIC QUICK LAUNCHER
echo ================================================
echo.

REM Check if setup was completed
if not exist ".env" (
    echo ❌ Setup not completed!
    echo.
    echo Please run setup.bat first to install dependencies.
    echo.
    pause
    exit /b 1
)

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please run setup.bat to install Python
    echo.
    pause
    exit /b 1
)

echo ✅ Environment ready
echo 🚀 Starting Baganetic services...
echo.

REM Start the application
python scripts/start_all.py

REM Open browser after a short delay
echo.
echo 🌐 Opening browser...
timeout /t 3 /nobreak >nul
start http://localhost:5000

echo.
echo ================================================
echo    ✅ BAGANETIC IS RUNNING!
echo ================================================
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
echo Press any key to close this window...
pause >nul
