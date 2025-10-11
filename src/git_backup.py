import os
import git
from git import Repo, GitCommandError
import requests

# Define paths (adjust if needed)
TOKEN_PATH = "c:\\data\\temp\\github_pat.txt"
REPO_DIR = "c:\\data\\temp\\hello_world"
REPO_NAME = "hello-world-automation"
GITHUB_USERNAME = "ksoenen"  # Replace with your GitHub username if different
API_URL = f"https://api.github.com/repos/{GITHUB_USERNAME}/{REPO_NAME}"
USER_REPOS_URL = "https://api.github.com/user/repos"
GITIGNORE_CONTENT = """
build/
dist/
*.pyc
*.pyo
*.pyd
__pycache__/
"""

def main_menu():
    print("\nGit Backup Menu:")
    print("1. Run full backup (auto commit and push all changes)")
    print("2. View changes summary (no commit)")
    print("3. Exit")
    choice = input("Enter choice (1-3): ").strip()
    return choice

# Check if directory exists
if not os.path.exists(os.path.dirname(TOKEN_PATH)):
    print("[ERROR] Directory", os.path.dirname(TOKEN_PATH), "does not exist or is inaccessible. Create it manually.")
    input("Press any key to exit")
    exit(1)

# Load or prompt for PAT
previous_run = os.path.exists(TOKEN_PATH)
if previous_run:
    print("Previous run detected - token file exists at", TOKEN_PATH)
    with open(TOKEN_PATH, "r") as f:
        token = f.read().strip()
    if not token:
        token = input("Empty file at {} - Enter your GitHub PAT: ".format(TOKEN_PATH))
        with open(TOKEN_PATH, "w") as f:
            f.write(token)  # No trailing newline
        print("Token set and file updated!")
    else:
        print("Token loaded from {}: REDACTED".format(TOKEN_PATH))
else:
    print("No previous run detected - setting up new environment.")
    token = input("Enter your GitHub PAT: ")
    try:
        with open(TOKEN_PATH, "w") as f:
            f.write(token)  # No trailing newline
        print("Token set and file created!")
    except Exception as e:
        print("[ERROR] Failed to create token file at {} - check permissions: {}".format(TOKEN_PATH, e))
        input("Press any key to exit")
        exit(1)

git_token = token

print("Starting automated Git backup...")
os.chdir(REPO_DIR)

# Load or init repo
try:
    repo = Repo(REPO_DIR)
except git.exc.InvalidGitRepositoryError:
    print("Initializing Git repo...")
    repo = Repo.init(REPO_DIR)
    repo.git.branch("-M", "main")

# Add .gitignore if not present to exclude build/dist
if not os.path.exists(".gitignore"):
    with open(".gitignore", "w") as f:
        f.write(GITIGNORE_CONTENT)

# Auto-setup global config if unset
if not repo.config_reader("global").has_option("user", "name"):
    print("Git global config not set. Configure now.")
    user_name = input("Enter GitHub username (e.g., Ken Soenen): ")
    user_email = input("Enter GitHub email (e.g., ksoenen@example.com): ")
    repo.config_writer("global").set_value("user", "name", user_name).release()
    repo.config_writer("global").set_value("user", "email", user_email).release()
    print("Config set!")

# Capture global config and set local
user_name = repo.config_reader("global").get_value("user", "name")
user_email = repo.config_reader("global").get_value("user", "email")
repo.config_writer().set_value("user", "name", user_name).release()
repo.config_writer().set_value("user", "email", user_email).release()
print("Local config set!")

# Set remote with token-embedded URL
print("Setting remote...")
try:
    repo.remotes.origin.set_url(f"https://{git_token}@github.com/{GITHUB_USERNAME}/{REPO_NAME}.git")
except AttributeError:
    repo.create_remote("origin", url=f"https://{git_token}@github.com/{GITHUB_USERNAME}/{REPO_NAME}.git")
print("Current remote URL: https://REDACTED@github.com/{GITHUB_USERNAME}/{REPO_NAME}.git")

# Check if repo exists and is accessible
print("[DEBUG] Checking if remote repo exists...")
headers = {
    "Authorization": f"Bearer {git_token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
}
response = requests.get(API_URL, headers=headers)
status = response.status_code

if status == 404:
    print("Repo not found - creating it...")
    body = {
        "name": REPO_NAME,
        "private": False
    }
    create_response = requests.post(USER_REPOS_URL, headers=headers, json=body)
    if create_response.status_code != 201:
        print("Creation failed - check PAT:", create_response.text)
        input("Press any key to exit")
        exit(1)
    print("Repo created!")
elif status == 200:
    print("Repo exists - proceeding.")

# Set .gitattributes for consistent line endings
print("Setting .gitattributes for consistent line endings...")
with open(".gitattributes", "w") as f:
    f.write("* text=auto")

# Stage initial changes if new repo
if not previous_run:
    print("Staging initial changes...")
    repo.index.add("*")
    try:
        repo.index.commit("Initial commit")
    except GitCommandError as e:
        print("[WARNING] No files to commit after creation - empty directory:", e)

# Menu loop
while True:
    choice = main_menu()
    if choice == '1':
        # Full backup
        if previous_run:
            print("Staging changes...")
            repo.index.add("*")
            if repo.index.diff("HEAD"):
                print("[DEBUG] Changes detected:")
                print(repo.git.status("--porcelain"))
                apply_changes = input("Apply all changes? (y/n): ").strip().lower()
                if apply_changes == 'y':
                    repo.index.commit("Backup run")
                    print("Changes committed!")
                else:
                    print("Changes not applied - skipping commit.")
                    continue
            else:
                print("No changes to commit.")

        # Push/pull logic
        has_upstream = True
        try:
            repo.git.rev_parse("--abbrev-ref", "main@{upstream}")
        except GitCommandError:
            has_upstream = False

        if not has_upstream:
            print("Setting upstream...")
            try:
                repo.git.push("-u", "origin", "main")
            except GitCommandError as e:
                print("[ERROR] Push failed - retrying remote setup...")
                repo.delete_remote("origin")
                repo.create_remote("origin", url=f"https://{git_token}@github.com/{GITHUB_USERNAME}/{REPO_NAME}.git")
                repo.git.push("-u", "origin", "main")
        else:
            print("Subsequent push: Syncing changes...")
            repo.git.fetch("origin", "main")
            try:
                repo.git.pull("origin", "main")
            except GitCommandError as e:
                print("[WARNING] Pull failed - possible conflicts. Resolve manually:", e)
                input("Press any key to exit")
                exit(1)
            repo.git.push("origin", "main")

        print("Backup complete!")
    elif choice == '2':
        # View changes summary
        print("[DEBUG] Current changes summary:")
        print(repo.git.status("--porcelain"))
    elif choice == '3':
        break
    else:
        print("Invalid choice - try again.")

print("Exiting...")
input("Press any key to exit")