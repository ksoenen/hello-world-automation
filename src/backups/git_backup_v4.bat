@echo off
setlocal enabledelayedexpansion

REM Check if script has run before by looking for the token file
if exist "c:\temp\github_pat.txt" (
    set "PREVIOUS_RUN=YES"
    echo Previous run detected - token file exists at c:\temp\github_pat.txt.
    set "GITHUB_PAT=c:\temp\github_pat.txt"
    for /f "delims=" %%a in ('type "c:\temp\github_pat.txt"') do set "token=%%a"
    if not "!token!"=="" (
        echo Token loaded from %GITHUB_PAT%: REDACTED
        set "GIT_TOKEN=!token!"
        echo [DEBUG] GIT_TOKEN set to: REDACTED
    ) else (
        echo Empty file at %GITHUB_PAT% - prompting for token.
        set /p token="Enter your GitHub PAT: "
        echo !token! > "%GITHUB_PAT%" 2>nul
        if errorlevel 1 (
            echo [ERROR] Failed to update token file at %GITHUB_PAT% - check permissions.
            pause
            exit /b 1
        )
        set "GIT_TOKEN=!token!"
        echo Token set and file updated!
    )
) else (
    set "PREVIOUS_RUN=NO"
    echo No previous run detected - setting up new environment.
    set "GITHUB_PAT=c:\temp\github_pat.txt"
    set /p token="Enter your GitHub PAT: "
    echo !token! > "c:\temp\github_pat.txt"
    if errorlevel 1 (
        echo [ERROR] Failed to create token file at c:\temp\github_pat.txt - check permissions.
        pause
        exit /b 1
    )
    set "GIT_TOKEN=!token!"
    echo Token set and file created!
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

REM Set local config in the repo to ensure it's applied
git config --local user.name "!user_name!"
git config --local user.email "!user_email!"
echo Local config set!

REM Clear Git credential cache using temp file
echo Clearing Git credential cache...
echo protocol=https > temp_cred.txt
echo host=github.com >> temp_cred.txt
git credential reject < temp_cred.txt
del temp_cred.txt
echo Credential cache cleared!

REM Set remote with token-embedded URL
echo Setting remote...
git remote remove origin 2>nul
set "remote_url=https://ksoenen:!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
git remote add origin "!remote_url!"
REM Debug: Verify remote URL (redacted token)
echo Current remote URL: https://ksoenen:REDACTED@github.com/ksoenen/hello-world-automation.git

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
    git add -A
    echo [DEBUG] Checking commit status...
    git commit -m "Backup run" -a >nul 2>&1
    if errorlevel 1 (
        echo [DEBUG] No changes or commit failed - skipping commit.
        echo No changes - skipping commit.
    ) else (
        echo [DEBUG] Commit successful - changes committed.
        echo Changes committed!
    )
)

REM Check upstream and handle push/pull logic with retry on remote failure
git rev-parse --abbrev-ref main@{upstream} 2>nul >nul
if errorlevel 1 (
    echo First push: Setting upstream...
    echo [DEBUG] Pushing with upstream set...
    git push --set-upstream "!remote_url!" || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        set "remote_url=https://ksoenen:!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
        git remote add origin "!remote_url!"
        git push --set-upstream "!remote_url!"
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
    git push "!remote_url!" || (
        echo [ERROR] Push failed - retrying remote setup...
        git remote remove origin 2>nul
        set "remote_url=https://ksoenen:!GIT_TOKEN!@github.com/ksoenen/hello-world-automation.git"
        git remote add origin "!remote_url!"
        git push "!remote_url!"
    )
)

if errorlevel 1 (
    echo Push failed - check token/connection.
    pause
    exit /b 1
)

REM Clean up temp files created during execution
if exist "temp_cred.txt" del "temp_cred.txt"

echo Backup complete!
pause
endlocal