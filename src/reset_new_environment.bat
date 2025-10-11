@echo off
setlocal enabledelayedexpansion
echo Resetting environment for first-time git_backup.bat test...
echo This will automatically delete the remote repo, local .git, global Git config, GITHUB_PAT env var, and github_pat.txt.
pause
REM Read existing PAT from file if available for remote deletion
set "pat_file=c:\data\temp\github_pat.txt"
echo [DEBUG] Checking for PAT file at %pat_file%...
if exist "%pat_file%" (
    for /f "usebackq delims=" %%a in ("%pat_file%") do set "GITHUB_PAT=%%a"
    echo [DEBUG] PAT loaded from %pat_file%: REDACTED
) else (
    if defined GITHUB_PAT (
        echo [DEBUG] Using existing GITHUB_PAT from environment: REDACTED
    ) else (
        echo [ERROR] No PAT file or environment variable found - remote deletion aborted.
        pause
        exit /b 1
    )
)
REM Pre-check if repo exists with detailed debug
echo [DEBUG] Checking if remote repo exists...
echo [DEBUG] Building curl command for repo check...
set "curl_cmd=curl -s -H ^"Authorization: Bearer !GITHUB_PAT!^" https://api.github.com/repos/ksoenen/hello-world-automation -o nul -w ^"%%{http_code}^""
echo [DEBUG] Curl command for check: !curl_cmd!
set "repo_status="
for /f "delims=" %%i in ('!curl_cmd!') do set "repo_status=%%i"
echo [DEBUG] Raw curl output captured: !repo_status!
echo [DEBUG] Repo status with borders: [ !repo_status! ]
if "!repo_status!"=="404" (
    echo [DEBUG] Remote repo not found ^(status: !repo_status!^) - skipping deletion.
) else if "!repo_status!"=="200" (
    echo [DEBUG] Remote repo exists ^(status: !repo_status!^) - proceeding with deletion.
) else (
    echo [ERROR] Unexpected repo status: !repo_status! - aborting cleanup.
    pause
    exit /b 1
)
REM Attempt to delete remote repo via GitHub API
if "!repo_status!"=="200" (
    echo [DEBUG] Connecting to remote repo https://github.com/ksoenen/hello-world-automation for cleanup...
    echo [DEBUG] Building curl command for deletion...
    set "curl_cmd=curl -f -X DELETE -H ^"Authorization: Bearer !GITHUB_PAT!^" -H ^"Accept: application/vnd.github+json^" -H ^"X-GitHub-Api-Version: 2022-11-28^" https://api.github.com/repos/ksoenen/hello-world-automation"
    echo [DEBUG] Curl command for deletion: !curl_cmd!
    set "delete_output="
    for /f "delims=" %%j in ('!curl_cmd! 2^>^&1') do set "delete_output=%%j"
    if !errorlevel! equ 0 (
        echo [SUCCESS] Remote repo deleted successfully via API.
        REM Post-deletion verification
        echo [DEBUG] Verifying deletion...
        set "verify_cmd=curl -s -H ^"Authorization: Bearer !GITHUB_PAT!^" https://api.github.com/repos/ksoenen/hello-world-automation -o nul -w ^"%%{http_code}^""
        set "verify_status="
        for /f "delims=" %%k in ('!verify_cmd!') do set "verify_status=%%k"
        if "!verify_status!"=="404" (
            echo [SUCCESS] Verified: Repo no longer exists ^(status: !verify_status!^).
        ) else (
            echo [WARNING] Verification failed: Repo still exists ^(status: !verify_status!^).
        )
    ) else (
        echo [ERROR] Remote deletion via API failed. Error level: !errorlevel!
        echo [DEBUG] Curl output: !delete_output!
        echo [DEBUG] API call failed - verify PAT scopes ^(needs delete_repo^) and repo state.
        pause
        exit /b 1
    )
)
REM Delete github_pat.txt after remote cleanup
echo [DEBUG] Deleting %pat_file%...
del /q "%pat_file%" 2>nul
if exist "%pat_file%" (
    echo [ERROR] Failed to delete %pat_file% - manual deletion needed.
    pause
    exit /b 1
) else (
    echo [SUCCESS] github_pat.txt deleted.
)
REM Delete global Git config
echo [DEBUG] Deleting global Git config...
del /q %USERPROFILE%\.gitconfig 2>nul
echo [SUCCESS] Global Git config deleted.
REM Clear GITHUB_PAT env var (system-wide and current session)
echo [DEBUG] Clearing GITHUB_PAT env var...
setx GITHUB_PAT "" 2>nul
if errorlevel 0 (
    reg delete HKCU\Environment /F /V GITHUB_PAT 2>nul
    reg delete HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment /F /V GITHUB_PAT 2>nul
    echo [SUCCESS] GITHUB_PAT system-wide env var cleared.
) else (
    echo [WARNING] GITHUB_PAT system-wide clear failed - manual check may be needed.
)
set GITHUB_PAT=
echo [SUCCESS] GITHUB_PAT session env var cleared.
REM Delete local .git in project root
echo [DEBUG] Deleting local .git...
cd /d "c:\data\Temp\hello_world"
rmdir /s /q .git 2>nul
echo [SUCCESS] Local .git deleted.
echo [INFO] Reset complete! Spawning new Command Prompt window...
start cmd.exe
echo [INFO] New DOS window spawned. Close this old window.
pause
endlocal