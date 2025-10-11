@echo off
setlocal enabledelayedexpansion

REM Usage: diag_dir.bat [directory_path]
REM Default to c:\data\temp if no argument provided
set "TARGET_DIR=%~1"
if "%TARGET_DIR%"=="" set "TARGET_DIR=c:\data\temp"

echo Testing permissions for: %TARGET_DIR%
echo Log will be saved to: %TARGET_DIR%\permissions_test.log

REM Clear log if exists
if exist "%TARGET_DIR%\permissions_test.log" del "%TARGET_DIR%\permissions_test.log"

echo === Permissions Test for %TARGET_DIR% === > "%TARGET_DIR%\permissions_test.log" 2>&1
echo. >> "%TARGET_DIR%\permissions_test.log" 2>&1

echo 1. Ownership Check (using dir /q): >> "%TARGET_DIR%\permissions_test.log" 2>&1
dir /q "%TARGET_DIR%" | find "%TARGET_DIR%" >> "%TARGET_DIR%\permissions_test.log" 2>&1
echo. >> "%TARGET_DIR%\permissions_test.log" 2>&1

echo 2. Detailed Permissions (using icacls /t /c): >> "%TARGET_DIR%\permissions_test.log" 2>&1
icacls "%TARGET_DIR%" /t /c >> "%TARGET_DIR%\permissions_test.log" 2>&1
echo. >> "%TARGET_DIR%\permissions_test.log" 2>&1

echo 3. Read/Write Test: >> "%TARGET_DIR%\permissions_test.log" 2>&1
set "TEST_FILE=%TARGET_DIR%\test_write.txt"
echo Attempting to create test file: !TEST_FILE! >> "%TARGET_DIR%\permissions_test.log" 2>&1
> "!TEST_FILE!" echo This is a write test. 2>> "%TARGET_DIR%\permissions_test.log"
if errorlevel 1 (
    echo [FAIL] Cannot write to directory - no write permission. >> "%TARGET_DIR%\permissions_test.log" 2>&1
) else (
    echo [SUCCESS] File created - write permission OK. >> "%TARGET_DIR%\permissions_test.log" 2>&1
    echo Attempting to read test file: >> "%TARGET_DIR%\permissions_test.log" 2>&1
    type "!TEST_FILE!" >> "%TARGET_DIR%\permissions_test.log" 2>&1
    if errorlevel 1 (
        echo [FAIL] Cannot read file - no read permission. >> "%TARGET_DIR%\permissions_test.log" 2>&1
    ) else (
        echo [SUCCESS] File read - read permission OK. >> "%TARGET_DIR%\permissions_test.log" 2>&1
    )
    echo Deleting test file: >> "%TARGET_DIR%\permissions_test.log" 2>&1
    del "!TEST_FILE!" 2>> "%TARGET_DIR%\permissions_test.log"
    if errorlevel 1 (
        echo [FAIL] Cannot delete file - no delete permission (may need modify/full control). >> "%TARGET_DIR%\permissions_test.log" 2>&1
    ) else (
        echo [SUCCESS] File deleted - delete permission OK. >> "%TARGET_DIR%\permissions_test.log" 2>&1
    )
)

echo. >> "%TARGET_DIR%\permissions_test.log" 2>&1
echo === End of Test === >> "%TARGET_DIR%\permissions_test.log" 2>&1

if errorlevel 1 (
    echo [ERROR] Failed to write log file - likely permission issue on the directory.
) else (
    echo Test complete! Check the log file in %TARGET_DIR% for details.
    type "%TARGET_DIR%\permissions_test.log"
)

pause
endlocal