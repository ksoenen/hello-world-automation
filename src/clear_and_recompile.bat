@echo off
echo Clearing build artifacts...
if exist "c:\\temp\\hello_world\build" rmdir /s /q "c:\\temp\\hello_world\build"
if exist "c:\\temp\\hello_world\dist\exe" rmdir /s /q "c:\\temp\\hello_world\dist\exe"
if exist "c:\\temp\\hello_world\dist\output" rmdir /s /q "c:\\temp\\hello_world\dist\output"
if exist "c:\\temp\\hello_world\src\hello_world_updated.spec" del "c:\\temp\\hello_world\src\hello_world_updated.spec"
echo.
echo Recompiling hello_world.exe...
pyinstaller --onefile --collect-submodules  --distpath "..\dist\exe" --workpath "..\build" ".\hello_world.py"
if %%ERRORLEVEL%% neq 0 (
    echo.
    echo ERROR: Build failed! Check the output above.
    pause
    exit /b 1
)
echo.
echo Build complete! New exe is in c:\\temp\\hello_world\dist\exe\hello_world.exe
pause