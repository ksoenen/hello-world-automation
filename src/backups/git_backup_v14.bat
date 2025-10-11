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

REM Capture global config values
for /f "delims=" %%a in ('git config --global user.name') do set "user_name=%%a"
for /f "delims=" %%b in ('git config --global user.email') do set "user_email=%%b"

REM Set local config in the repo
git config --local user.name "!user_name!"
git config --local user.email "!user_email!"
echo Local config set!

REM Escape special characters in GIT_TOKEN for safe URL usage
set "ESCAPED_TOKEN=!GIT_TOKEN!"
set "ESCAPED_TOKEN=!ESCAPED_TOKEN:%%=%%%%!"
set "ESCAPED_TOKEN=!ESCAPED_TOKEN:&=^&!"
set "ESCAPED_TOKEN=!ESCAPED_TOKEN:+=^+!"
set "ESCAPED_TOKEN=!ESCAPED_TOKEN:#=^#!"
set "ESCAPED_TOKEN=!ESCAPED_TOKEN:=^=!"

REM Set remote with escaped token in URL
echo Setting remote...
git remote remove origin 2>nul
set "remote_url=https://!ESCAPED_TOKEN!@github.com/ksoenen/hello-world-automation.git"
git remote add origin "!remote_url!"
echo [DEBUG] Constructed remote URL: https://REDACTED@github.com/ksoenen/hello-world-automation.git
echo [DEBUG] Raw remote URL (for verification): !remote_url!

REM Verify remote URL is set correctly
for /f "delims=" %%i in ('git remote get-url origin') do set "actual_url=%%i"
echo [DEBUG] Actual remote URL set in Git: !actual_url!

REM Check if repo exists and is accessible
echo [DEBUG] Checking if remote repo exists...
set "curl_cmd=curl -s -H ^"Authorization: Bearer !GIT_TOKEN!^" https://api.github.com/repos/ksoenen/hello-world-automation -o nul -w ^"%%{http_code}^""
echo [DEBUG] Curl command for check: curl -s -H "Authorization: Bearer REDACTED" https://api.github.com/repos/ksoenen/hello-world-automation -o nul -w "%%{http_code}"
set "status="
for /f "delims=" %%i in ('!curl_cmd!') do set "status=%%i"
echo [DEBUG] Raw curl output captured: !status!
if "!status!"=="404" (
    echo Repo not found - creating it...
    curl -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer !GIT_TOKEN!" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/user/repos -d "{\"name\":\"hello-world-automation\",\"private\":false}"
    if errorlevel 1 (
        echo [ERROR] Creation failed - check PAT or network.
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
) else (
    echo [ERROR] Unexpected repo status: !status!
    pause
    exit /b 1
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

REM Check upstream and handle push/pull logic
git rev-parse --abbrev-ref main@{upstream} 2>nul >nul
if errorlevel 1 (
    echo Setting upstream branch...
    echo [DEBUG] Pushing with upstream set...
    git push --set-upstream origin main 2>&1
    if errorlevel 1 (
        echo [ERROR] Push failed - retrying...
        git push --set-upstream origin main 2>&1
        if errorlevel 1 (
            echo [ERROR] Push failed again - check output above.
            echo [DEBUG] Attempting push with explicit URL for debugging...
            git push "!remote_url!" main 2>&1
            if errorlevel 1 (
                echo [ERROR] Explicit URL push failed - check output above.
                pause
                exit /b 1
            )
        )
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
    git push origin main 2>&1
    if errorlevel 1 (
        echo [ERROR] Push failed - retrying...
        git push origin main 2>&1
        if errorlevel 1 (
            echo [ERROR] Push failed again - check output above.
            echo [DEBUG] Attempting push with explicit URL for debugging...
            git push "!remote_url!" main 2>&1
            if errorlevel 1 (
                echo [ERROR] Explicit URL push failed - check output above.
                pause
                exit /b 1
            )
        )
    )
)

echo Backup complete!
pause
endlocal