@echo off
setlocal enabledelayedexpansion

REM Step 1: Get base project directory for whole file structure
set /p base_project_directory="Enter Base project DIRECTORY for whole file structure: "
ECHO You entered: %base_project_directory%

REM Step 2: Check if the directory exists, create it if not (handles paths with spaces via quotes)
IF NOT EXIST "%base_project_directory%\" mkdir "%base_project_directory%"

REM Step 3: Construct the full path variable (appends \ if needed, but assumes base_project_directory doesn't end with \)
SET "GITHUB_PAT=%base_project_directory%\github_pat.txt"

REM Step 4: Verify the new variable
ECHO Full path stored in GITHUB_PAT: %GITHUB_PAT%

REM Step 5: Set PREVIOUS_RUN based on file existence
set "PREVIOUS_RUN=NO"
if exist "%GITHUB_PAT%" set "PREVIOUS_RUN=YES"

REM Step 6: Initialize token empty
set "token="

REM Step 7: If file exists, try to load token
if exist "%GITHUB_PAT%" (
    for /f "delims=" %%a in ('type "%GITHUB_PAT%"') do set "token=%%a"
)

REM Step 8: If token is empty (file missing, empty, or failed load), prompt for it and write with error check
if "!token!"=="" (
    if "!PREVIOUS_RUN!"=="YES" (
        echo Empty file at %GITHUB_PAT% - prompting for token.
    ) else (
        echo No previous run detected - setting up new environment.
    )
    set /p token="Enter your GitHub PAT: "
    ECHO You entered: !token!
    set /p =!token! <nul > "%GITHUB_PAT%"
    if not exist "%GITHUB_PAT%" (
        echo [ERROR] Failed to create/update token file at %GITHUB_PAT% - check permissions or directory.
        pause
        exit /b 1
    )
    echo Token set and file created/updated!
) else (
    echo Token loaded from %GITHUB_PAT%: REDACTED
)

REM Step 9: Set GIT_TOKEN from token (common step)
set "GIT_TOKEN=!token!"
echo [DEBUG] GIT_TOKEN set to: REDACTED

REM Step 10: Display previous run status
if "!PREVIOUS_RUN!"=="YES" (
    echo Previous run detected - token file existed.
) else (
    echo No previous run detected - new setup.
)

echo Starting automated Git backup...
cd /d "c:\Temp\hello_world"

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