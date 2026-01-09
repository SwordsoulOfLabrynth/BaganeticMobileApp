@echo off
echo.
echo ================================================
echo    🗑️  BAGANETIC UNINSTALLER
echo ================================================
echo.
echo This will remove Baganetic and optionally clean up dependencies.
echo.

set /p choice="Do you want to remove all generated files? (y/n): "
if /i "%choice%" neq "y" (
    echo Uninstall cancelled.
    pause
    exit /b 0
)

echo.
echo 🧹 Cleaning up Baganetic files...

REM Remove generated files
if exist ".env" del ".env"
if exist ".env.backup" del ".env.backup"
if exist "logs" rmdir /s /q "logs"
if exist "uploads" rmdir /s /q "uploads"
if exist "temp" rmdir /s /q "temp"
if exist ".installer" rmdir /s /s /q ".installer"
if exist "__pycache__" rmdir /s /q "__pycache__"

REM Remove Python cache files
for /d /r . %%d in (__pycache__) do @if exist "%%d" rmdir /s /q "%%d"
for /r . %%f in (*.pyc) do @if exist "%%f" del "%%f"

echo ✅ Generated files removed

echo.
set /p choice2="Do you want to remove Python packages? (y/n): "
if /i "%choice2%"=="y" (
    echo 🧹 Removing Python packages...
    pip uninstall -r requirements.txt -y 2>nul
    echo ✅ Python packages removed
)

echo.
set /p choice3="Do you want to remove Node.js packages? (y/n): "
if /i "%choice3%"=="y" (
    echo 🧹 Removing Node.js packages...
    if exist "node_modules" rmdir /s /q "node_modules"
    if exist "package-lock.json" del "package-lock.json"
    echo ✅ Node.js packages removed
)

echo.
set /p choice4="Do you want to remove MongoDB? (y/n): "
if /i "%choice4%"=="y" (
    echo 🧹 Removing MongoDB...
    net stop MongoDB 2>nul
    sc delete MongoDB 2>nul
    if exist "C:\Program Files\MongoDB" rmdir /s /q "C:\Program Files\MongoDB"
    if exist "C:\data" rmdir /s /q "C:\data"
    echo ✅ MongoDB removed
)

echo.
echo ================================================
echo    ✅ UNINSTALL COMPLETE!
echo ================================================
echo.
echo Baganetic has been removed from your system.
echo.
pause
