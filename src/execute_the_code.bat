@echo off
if not exist "..\dist\exe\hello_world.exe" (
    echo ERROR: Executable not found. Run clear_and_recompile.bat first.
    pause
    exit /b 1
)
cd /d "..\dist"
echo Running hello_world.exe...
exe\hello_world.exe  # e.g. "input.html" "media.jpg"
pause