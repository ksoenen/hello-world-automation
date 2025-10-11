REM Check if script has run before by looking for the token file
if exist "c:\data\temp\github_pat.txt" (
    set "PREVIOUS_RUN=YES"
    echo Previous run detected - token file exists at c:\data\temp\github_pat.txt.
    set "GITHUB_PAT=c:\data\temp\github_pat.txt"
    REM Read token
    for /f "usebackq delims=" %%a in ("c:\data\temp\github_pat.txt") do set "token=%%a"
    if not "!token!"=="" (
        echo [DEBUG] Raw token (redacted): !token:~0,10!... (first 10 chars)
        echo Token loaded from %GITHUB_PAT%: REDACTED
        set "GIT_TOKEN=!token!"
        echo [DEBUG] GIT_TOKEN set to: REDACTED
    ) else (
        echo [ERROR] Empty or unreadable token in %GITHUB_PAT% - prompting for new token.
        set /p token="Enter your GitHub PAT: "
        REM Validate new token
        echo !token! | findstr /R "^[a-zA-Z0-9_-+.]*$" >nul
        if errorlevel 1 (
            echo [ERROR] Invalid token format - use only alphanumeric, -, _, ., +, =.
            pause
            exit /b 1
        )
        REM Write token without trailing newline or space
        >"c:\data\temp\github_pat.txt" (echo|set /p="!token!")
        if errorlevel 1 (
            echo [ERROR] Failed to update token file at %GITHUB_PAT% - check permissions.
            pause
            exit /b 1
        )
        set "GIT_TOKEN=!token!"
        echo Token set and file updated!
    )
) else (
    echo No previous run detected - setting up new environment.
    set "GITHUB_PAT=c:\data\temp\github_pat.txt"
    set /p token="Enter your GitHub PAT: "
    REM Validate new token
    echo !token! | findstr /R "^[a-zA-Z0-9_-+.]*$" >nul
    if errorlevel 1 (
        echo [ERROR] Invalid token format - use only alphanumeric, -, _, ., +, =.
        pause
        exit /b 1
    )
    REM Write token without trailing newline or space
    >"c:\data\temp\github_pat.txt" (echo|set /p="!token!")
    if errorlevel 1 (
        echo [ERROR] Failed to create token file at c:\data\temp\github_pat.txt - check permissions.
        pause
        exit /b 1
    )
    set "GIT_TOKEN=!token!"
    echo Token set and file created!
)