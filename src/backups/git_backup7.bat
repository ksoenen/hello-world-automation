@echo off
setlocal enabledelayedexpansion
echo Starting automated Git backup...
cd /d "c:\Temp\hello_world"

REM Self-init if no .git
if not exist .git (
    echo Initializing Git repo...
    git init
    git branch -M main
)

REM Auto-setup global config if unset
git config --global --get user.name 2>nul >nul
if errorlevel 1 (
    echo Git global config not set. Configure now.
    set /p user_name="Enter GitHub username (e.g., Ken Soenen): "
    set /p user_email="Enter GitHub email (e.g., ksoenen@example.com): "
    git config --global user.name "!user_name!"
    git config --global user.email "!user_email!"
    echo Config set!
)

REM Set local config in the repo to ensure it's applied
git config --local user.name "!user_name!"
git config --local user.email "!user_email!"
echo Local config set!

REM Check/set GITHUB_PAT env var as file path if not defined
if not defined GITHUB_PAT (
    echo GITHUB_PAT not defined. Setting to c:\temp\github_pat.txt...
    setx GITHUB_PAT "c:\temp\github_pat.txt" 2>nul
    set GITHUB_PAT=c:\temp\github_pat.txt
    echo GITHUB_PAT path set to !GITHUB_PAT! (system-wide via setx)
) else (
    echo GITHUB_PAT is defined (path: !GITHUB_PAT!). Validating...
    if not "!GITHUB_PAT!"=="c:\temp\github_pat.txt" (
        echo GITHUB_PAT path mismatch - resetting to c:\temp\github_pat.txt...
        setx GITHUB_PAT "c:\temp\github_pat.txt" 2>nul
        set GITHUB_PAT=c:\temp\github_pat.txt
        echo GITHUB_PAT path corrected!
    )
)

REM Read token from file at GITHUB_PAT path into temporary variable and set as env var
echo Checking file at %GITHUB_PAT% for token...
if exist "%GITHUB_PAT%" (
    for /f "delims=" %%a in ('type "%GITHUB_PAT%"') do set "token=%%a"
    if not "!token!"=="" (
        echo Token loaded from %GITHUB_PAT%: REDACTED
        set "GIT_TOKEN=!token!"
        echo [DEBUG] GIT_TOKEN set to: REDACTED
    ) else (
        echo Empty file at %GITHUB_PAT% - prompting for token.
        set /p token="Enter your GitHub PAT: "
        echo !token! > "%GITHUB_PAT%"
        set "GIT_TOKEN=!token!"
        echo Token set and file updated!
    )
) else (
    echo File at %GITHUB_PAT% not found - prompting for PAT and creating the file.
    set /p token="Enter your GitHub PAT: "
    echo !token! > "%GITHUB_PAT%"
    set "GIT_TOKEN=!token!"
    echo Token set and file created!
)

REM Clear Git credential cache using temp file
echo Clearing Git credential cache...
echo protocol=https > temp_cred.txt
echo host=github.com >> temp_cred.txt
git credential reject < temp_cred.txt
del temp_cred.txt
echo Credential cache cleared!

REM Set remote with standard URL and configure with credential helper
echo Setting remote...
git remote remove origin 2>nul
git remote add origin https://github.com/ksoenen/hello-world-automation.git 2>nul || git remote set-url origin https://github.com/ksoenen/hello-world-automation.git 2>nul
REM Debug: Verify remote URL
git remote -v

REM Check if repo exists and is accessible
echo Checking if repo exists and is accessible...
set "curl_cmd=curl -s -o nul -w ^"%%{http_code}^" -H ^"Authorization: Bearer !GIT_TOKEN!^" https://api.github.com/repos/ksoenen/hello-world-automation"
for /f "delims=" %%i in ('!curl_cmd!') do set "status=%%i"
if defined status (
    if "!status!"=="404" (
        echo Repo not found - creating it...
        curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer !GIT_TOKEN!" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/user/repos -d "{\"name\":\"hello-world-automation\",\"private\":false}"
        if errorlevel 1 (
            echo Creation failed - check PAT.
            pause
            exit /b 1
        )
        echo Repo created!
    ) else if "!status!"=="200" (
        echo Repo exists - proceeding.
    ) else (
        echo [ERROR] Repo check failed (status: !status!) - check PAT or network.
        pause
        exit /b 1
    )
) else (
    echo [ERROR] Failed to get repo status - check curl or network.
    pause
    exit /b 1
)

REM Set .gitattributes for consistent line endings
echo Setting .gitattributes for consistent line endings...
echo * text=auto > .gitattributes

REM Stage all changes explicitly
echo Staging changes...
git add -A

REM Commit if changes with debug
echo [DEBUG] Checking commit status...
git commit -m "Backup run" >nul 2>&1
if errorlevel 1 (
    echo [DEBUG] No changes or commit failed - skipping commit.
    echo No changes - skipping commit.
) else (
    echo [DEBUG] Commit successful - changes committed.
    echo Changes committed!
)

REM Check upstream and handle push/pull logic with retry on remote failure
git rev-parse --abbrev-ref main@{upstream} 2>nul >nul
if errorlevel 1 (
    echo First push: Setting upstream...
    echo [DEBUG] Pushing with upstream set...
    git push --set-upstream origin main || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        git remote add origin https://github.com/ksoenen/hello-world-automation.git
        git push --set-upstream origin main
    )
) else (
    echo Subsequent push: Syncing changes...
    echo [DEBUG] Fetching remote state...
    git fetch origin main 2>nul
    if errorlevel 0 (
        echo [DEBUG] Fetch succeeded - pulling changes...
        git pull origin main
        if errorlevel 1 (
            echo [WARNING] Pull failed - possible conflicts. Resolve manually.
            pause
            exit /b 1
        )
    )
    echo [DEBUG] Pushing updates...
    git push || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        git remote add origin https://github.com/ksoenen/hello-world-automation.git
        git push
    )
)

if errorlevel 1 (
    echo Push failed - check token/connection.
    pause
    exit /b 1
)
echo Backup complete!
pause
endlocal