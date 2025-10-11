@echo off
setlocal enabledelayedexpansion

REM Check if script has run before by looking for the token file
if exist "c:\data\temp\github_pat.txt" (
    set "PREVIOUS_RUN=YES"
    echo Previous run detected - token file exists at c:\data\temp\github_pat.txt.
    set "GITHUB_PAT=c:\data\temp\github_pat.txt"
    for /f "delims=" %%a in ('type "c:\data\temp\github_pat.txt"') do set "token=%%a"
    if not "!token!"=="" (
        echo Token loaded from %GITHUB_PAT%: REDACTED
        set "GIT_TOKEN=!token!"
        echo [DEBUG] GIT_TOKEN set to: REDACTED
    ) else (
        echo Empty file at %GITHUB_PAT% - prompting for token.
        set /p token="Enter your GitHub PAT: "
        echo Checking directory for update...
        for %%i in ("%GITHUB_PAT%") do dir "%%~dpi" >nul 2>&1
        if errorlevel 1 (
            echo [ERROR] Directory not found or inaccessible for update: use 'dir' on the path manually to check.
            pause
            exit /b 1
        )
        <nul set /p dummy=!token! > "%GITHUB_PAT%" 2>nul
        if not exist "%GITHUB_PAT%" (
            echo [ERROR] Failed to update token file at %GITHUB_PAT% - check permissions or run as admin.
            pause
            exit /b 1
        )
        set "GIT_TOKEN=!token!"
        echo Token set and file updated!
    )
) else (
    set "PREVIOUS_RUN=NO"
    echo No previous run detected - setting up new environment.
    set "GITHUB_PAT=c:\data\temp\github_pat.txt"
    set /p token="Enter your GitHub PAT: "
    echo Checking directory for creation...
    for %%i in ("%GITHUB_PAT%") do dir "%%~dpi" >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Directory not found or inaccessible for creation: use 'dir' on the path manually to check.
        pause
        exit /b 1
    )
    <nul set /p dummy=!token! > "%GITHUB_PAT%" 2>nul
    if not exist "%GITHUB_PAT%" (
        echo [ERROR] Failed to create token file at c:\data\temp\github_pat.txt - check permissions or run as admin.
        pause
        exit /b 1
    )
    set "GIT_TOKEN=!token!"
    echo Token set and file created!
)

echo Starting automated Git backup...
cd /d "c:\data\temp\hello_world"

REM Self-init if no .git
if not exist ".git" (
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

REM Capture global config values (handles cases where no prompt occurred)
for /f "delims=" %%a in ('git config --global user.name') do set "user_name=%%a"
for /f "delims=" %%b in ('git config --global user.email') do set "user_email=%%b"

REM Set local config in the repo to ensure it's applied (using captured values)
git config --local user.name "!user_name!"
git config --local user.email "!user_email!"
echo Local config set!

REM Set remote with token-embedded URL
echo Setting remote...
git remote remove origin 2>nul
set "remote_url=https://!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
git remote add origin "!remote_url!"
REM Debug: Verify remote URL (redacted token)
echo Current remote URL: https://REDACTED@github.com/ksoenen/hello-world-automation.git

REM Check if repo exists and is accessible
echo [DEBUG] Checking if remote repo exists...
echo [DEBUG] Building curl command for repo check...
set "curl_cmd=curl -s -H ^"Authorization: Bearer !GIT_TOKEN!^" https://api.github.com/repos/ksoenen/hello-world-automation -o nul -w ^"%%{http_code}^""
echo [DEBUG] Curl command for check: !curl_cmd!
set "status="
for /f "delims=" %%i in ('!curl_cmd!') do set "status=%%i"
echo [DEBUG] Raw curl output captured: !status!
echo [DEBUG] Repo status with borders: [ !status! ]
if "!status!"=="404" (
    echo Repo not found - creating it...
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer !GIT_TOKEN!" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/user/repos -d "{\"name\":\"hello-world-automation\",\"private\":false}"
    if errorlevel 1 (
        echo Creation failed - check PAT.
        pause
        exit /b 1
    )
    echo Repo created!
    echo Staging initial changes...
    git add -A
    git commit -m "Initial commit" >nul 2>&1
    if errorlevel 1 (
        echo [WARNING] No files to commit after creation - empty directory.
    )
) else if "!status!"=="200" (
    echo Repo exists - proceeding.
)

REM Set .gitattributes for consistent line endings
echo Setting .gitattributes for consistent line endings...
echo * text=auto > .gitattributes

REM Stage and commit changes only for subsequent runs
if "!PREVIOUS_RUN!"=="YES" (
    echo Staging changes...
    git update-index --refresh >nul 2>&1
    git add -A
    echo [DEBUG] Verifying staged changes...
    git status --porcelain
    git diff --staged --quiet 2>nul
    if errorlevel 1 (
        git commit -m "Backup run"
        if errorlevel 1 (
            echo [DEBUG] Commit failed despite staged changes. Check output above.
            echo No changes to commit due to commit failure.
        ) else (
            echo [DEBUG] Commit successful - changes committed.
            echo Changes committed!
        )
    ) else (
        echo [DEBUG] No changes detected.
        echo No changes to commit.
    )
)

REM Check upstream and handle push/pull logic with retry on remote failure
git rev-parse --abbrev-ref main@{upstream} 2>nul >nul
if errorlevel 1 (
    echo Setting upstream branch: Setting upstream...
    echo [DEBUG] Pushing with upstream set...
    git push -u origin main || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        set "remote_url=https://!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
        git remote add origin "!remote_url!"
        git push -u origin main
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
    git push origin main || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        set "remote_url=https://!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
        git remote add origin "!remote_url!"
        git push origin main
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