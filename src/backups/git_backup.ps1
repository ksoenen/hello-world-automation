# PowerShell equivalent of the batch Git backup script
# Run as admin if permission issues persist

$ErrorActionPreference = "Stop"  # Make errors terminating for reliability

# Define paths (use consistent casing; adjust if needed)
$tokenPath = "c:\data\temp\github_pat.txt"
$repoDir = "c:\data\temp\hello_world"
$repoUrl = "https://github.com/ksoenen/hello-world-automation.git"

# Check if directory exists
if (-not (Test-Path -Path (Split-Path $tokenPath -Parent))) {
    Write-Host "[ERROR] Directory $(Split-Path $tokenPath -Parent) does not exist or is inaccessible. Create it manually."
    Read-Host -Prompt "Press any key to exit"
    exit 1
}

# Check for previous run via token file
$previousRun = Test-Path $tokenPath
if ($previousRun) {
    Write-Host "Previous run detected - token file exists at $tokenPath."
    $token = Get-Content $tokenPath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrEmpty($token)) {
        $token = Read-Host -Prompt "Empty file at $tokenPath - Enter your GitHub PAT"
        [System.IO.File]::WriteAllText($tokenPath, $token)  # No trailing newline
        Write-Host "Token set and file updated!"
    } else {
        Write-Host "Token loaded from ${tokenPath}: REDACTED"
    }
} else {
    Write-Host "No previous run detected - setting up new environment."
    $token = Read-Host -Prompt "Enter your GitHub PAT"
    try {
        [System.IO.File]::WriteAllText($tokenPath, $token)  # No trailing newline
        Write-Host "Token set and file created!"
    } catch {
        Write-Host "[ERROR] Failed to create token file at $tokenPath - check permissions: $($_.Exception.Message)"
        Read-Host -Prompt "Press any key to exit"
        exit 1
    }
}

$gitToken = $token

Write-Host "Starting automated Git backup..."
Set-Location -Path $repoDir -ErrorAction Stop

# Self-init if no .git
if (-not (Test-Path ".git")) {
    Write-Host "Initializing Git repo..."
    & git init 2>$null
    & git branch -M main 2>$null
}

# Auto-setup global config if unset
if (-not (& git config --global --get user.name 2>$null)) {
    Write-Host "Git global config not set. Configure now."
    $userName = Read-Host -Prompt "Enter GitHub username (e.g., Ken Soenen)"
    $userEmail = Read-Host -Prompt "Enter GitHub email (e.g., ksoenen@example.com)"
    & git config --global user.name $userName 2>$null
    & git config --global user.email $userEmail 2>$null
    Write-Host "Config set!"
}

# Capture global config values
$userName = & git config --global user.name 2>$null
$userEmail = & git config --global user.email 2>$null

# Set local config
& git config --local user.name $userName 2>$null
& git config --local user.email $userEmail 2>$null
Write-Host "Local config set!"

# Set remote with token-embedded URL
Write-Host "Setting remote..."
& git remote remove origin 2>$null
$remoteUrl = "https://$gitToken@github.com/ksoenen/hello-world-automation.git"
& git remote add origin $remoteUrl 2>$null
Write-Host "Current remote URL: https://REDACTED@github.com/ksoenen/hello-world-automation.git"

# Check if repo exists and is accessible
Write-Host "[DEBUG] Checking if remote repo exists..."
$headers = @{
    "Authorization" = "Bearer $gitToken"
    "Accept" = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
try {
    $response = Invoke-WebRequest -Uri "https://api.github.com/repos/ksoenen/hello-world-automation" -Headers $headers -Method Get
    $status = $response.StatusCode
} catch {
    $status = $_.Exception.Response.StatusCode.Value__
}

if ($status -eq 404) {
    Write-Host "Repo not found - creating it..."
    $body = @{
        name = "hello-world-automation"
        private = $false
    } | ConvertTo-Json
    try {
        Invoke-WebRequest -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json"
        Write-Host "Repo created!"
    } catch {
        Write-Host "Creation failed - check PAT: $($_.Exception.Message)"
        Read-Host -Prompt "Press any key to exit"
        exit 1
    }
} elseif ($status -eq 200) {
    Write-Host "Repo exists - proceeding."
}

# Set .gitattributes for consistent line endings (do this before staging to have something to commit if empty)
Write-Host "Setting .gitattributes for consistent line endings..."
"* text=auto" | Set-Content -Path ".gitattributes" -NoNewline

# Stage and commit initial changes if new repo
if (-not $previousRun) {
    Write-Host "Staging initial changes..."
    & git add -A 2>$null
    try {
        & git commit -m "Initial commit" 2>$null
    } catch {
        Write-Host "[WARNING] No additional files to commit after creation - repo may be empty besides .gitattributes."
    }
}

# Stage and commit changes only for subsequent runs
if ($previousRun) {
    Write-Host "Staging changes..."
    & git add -A 2>$null
    $changes = & git diff --staged 2>$null
    if ($changes) {
        & git commit -m "Backup run" 2>$null
        Write-Host "Changes committed!"
    } else {
        Write-Host "No changes to commit."
    }
}

# Check if upstream is set
$hasUpstream = $false
try {
    & git rev-parse --abbrev-ref @{u} 2>$null
    $hasUpstream = $true
} catch {
    # No upstream, proceed
}

if (-not $hasUpstream) {
    Write-Host "Setting upstream..."
    try {
        & git push -u origin main 2>$null
    } catch {
        Write-Host "[ERROR] Push failed - retrying remote setup..."
        & git remote remove origin 2>$null
        & git remote add origin $remoteUrl 2>$null
        & git push -u origin main 2>$null
    }
} else {
    Write-Host "Subsequent push: Syncing changes..."
    try {
        & git fetch origin main 2>$null
        & git pull origin main 2>$null
        & git push origin main 2>$null
    } catch {
        Write-Host "[WARNING] Sync failed - possible conflicts or empty remote. Resolve manually."
    }
}

Write-Host "Backup complete!"
Read-Host -Prompt "Press any key to exit"