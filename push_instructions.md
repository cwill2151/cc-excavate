# How to Push to GitHub with Personal Access Token

## Option 1: Use HTTPS with PAT in URL (Quick but less secure)
```bash
git remote set-url origin https://x@github.com/cwill2151/cc-excavate.git
git push origin main
```

## Option 2: Use Git Credential Manager (Recommended)
```bash
# Set the remote URL without the token
git remote set-url origin https://github.com/cwill2151/cc-excavate.git

# Push - Git will prompt for username and password
git push origin main
# Username: cwill2151
# Password: x (your PAT)
```

## Option 3: Use Environment Variable (For scripts)
```bash
# Windows Command Prompt
set GIT_ASKPASS=echo
set GIT_USERNAME=cwill2151
set GIT_PASSWORD=x
git push https://%GIT_USERNAME%:%GIT_PASSWORD%@github.com/cwill2151/cc-excavate.git main

# Windows PowerShell
$env:GIT_ASKPASS="echo"
$env:GIT_USERNAME="cwill2151"
$env:GIT_PASSWORD="x"
git push https://${env:GIT_USERNAME}:${env:GIT_PASSWORD}@github.com/cwill2151/cc-excavate.git main
```

## Option 4: Configure Git for This Repository Only
```bash
# Configure username for this repo only
git config user.name "cwill2151"
git config user.email "your-email@example.com"

# Store credentials for this repo
git config credential.helper store
git push origin main
# Enter username: cwill2151
# Enter password: x (your PAT)
```

## Option 5: Use SSH with Different Key
```bash
# Generate new SSH key for this account
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519_cwill2151

# Add to SSH agent
ssh-add ~/.ssh/id_ed25519_cwill2151

# Configure SSH config
echo "Host github-cwill2151
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_cwill2151" >> ~/.ssh/config

# Change remote URL
git remote set-url origin git@github-cwill2151:cwill2151/cc-excavate.git
git push origin main
```

## First Time Setup Commands
```bash
# Initialize git if not already done
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: Multi-turtle collaborative excavation system"

# Add remote
git remote add origin https://github.com/cwill2151/cc-excavate.git

# Push with PAT
git push -u origin main
# Username: cwill2151
# Password: x (your PAT)
```

## Notes:
- Replace 'x' with your actual PAT
- PAT needs 'repo' scope for pushing
- Option 2 is most secure as it doesn't expose the token in URLs
- After first push with credentials, Git can remember them