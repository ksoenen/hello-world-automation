@echo off
echo Pulling latest from GitHub...
cd /d "c:\data\temp\hello_world"
git pull
if %ERRORLEVEL% neq 0 (
    echo Pull failed! Possible conflicts—resolve manually.
    pause
    exit /b 1
)
echo Latest files pulled!
pause