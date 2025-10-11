@echo off
setlocal enabledelayedexpansion
echo Starting verification of reset process...
echo ------------------------------------

REM Change to the project root directory
cd /d c:\data\temp\hello_world
echo Current directory: %CD%
echo.

REM Check if local .git directory exists (should not exist if deleted)
echo Checking for local .git directory...
dir .git 2>&1
if errorlevel 1 (
    echo [SUCCESS] No .git directory found - deletion confirmed.
) else (
    echo [WARNING] .git directory still exists!
)
echo.

REM Check if github_pat.txt exists (should not exist if deleted)
echo Checking for github_pat.txt...
dir c:\data\temp\github_pat.txt 2>&1
if errorlevel 1 (
    echo [SUCCESS] No github_pat.txt found - deletion confirmed.
) else (
    echo [WARNING] github_pat.txt still exists!
)
echo.

REM Check global Git config (should be empty or error if deleted)
echo Checking global Git config...
git config --global --list 2>&1
if errorlevel 1 (
    echo [SUCCESS] No global Git config found - deletion confirmed.
) else (
    echo [WARNING] Global Git config still exists!
)
echo.

REM Check GITHUB_PAT environment variable (should be empty)
echo Checking GITHUB_PAT environment variable...
echo Current GITHUB_PAT value: [%GITHUB_PAT%]
if not defined GITHUB_PAT (
    echo [SUCCESS] GITHUB_PAT is not set - cleared successfully.
) else (
    echo [WARNING] GITHUB_PAT is still set to: !GITHUB_PAT!
)
echo.

REM Check remote repo status (should return 404 if deleted)
echo [DEBUG] Checking if remote repo exists...
echo [DEBUG] Building curl command for repo check...
set "verify_cmd=curl -s -o nul -w ^"%%{http_code}^" https://github.com/ksoenen/hello-world-automation"
echo [DEBUG] Curl command for check: !verify_cmd!
set "verify_status="
for /f "delims=" %%k in ('!verify_cmd!') do set "verify_status=%%k"
echo [DEBUG] Raw curl output captured: !verify_status!
echo [DEBUG] Repo status with borders: [ !verify_status! ]
if "!verify_status!"=="404" (
    echo [SUCCESS] Remote repo no longer exists ^(status: !verify_status!^) - deletion confirmed.
) else if "!verify_status!"=="200" (
    echo [WARNING] Remote repo still exists ^(status: !verify_status!^)!
) else (
    echo [WARNING] Could not determine remote repo status ^(status: !verify_status!^) - curl may not be installed or accessible.
)
echo.
echo Verification complete. Review the output above.
pause