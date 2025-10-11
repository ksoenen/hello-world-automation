@echo off
echo Initializing Git repo...
cd /d "c:\data\temp\hello_world"
if not exist .git (
    git init
    git remote add origin https://github.com/ksoenen/hello-world-automation.git
    git branch -M main
    echo .gitignore created.
    echo # Build artifacts> .gitignore
    echo build/>> .gitignore
    echo dist/>> .gitignore
    echo __pycache__/>> .gitignore
    echo *.pyc>> .gitignore
    git add .
    git commit -m "Initial project setup"
    git push -u origin main
    echo Repo initialized and pushed! Replace YOUR_USERNAME with actual.
) else (
    echo Git repo already exists.
)
pause