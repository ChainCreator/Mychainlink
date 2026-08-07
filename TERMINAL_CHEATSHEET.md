# MyChainLink Terminal Cheat Sheet

## FINDING STUFF

```bash
# Where am I right now?
pwd

# List files in current folder
ls

# List files with details (size, date, permissions)
ls -la

# Find your mychainlink folder
find ~ -name "mychainlink" -type d 2>/dev/null

# Search for a file by name
find . -name "index.html"

# Search for text inside files
grep -r "function su()" .
grep -r "showConnects" .
```

## MOVING AROUND

```bash
# Go to home folder
cd ~

# Go to your project
cd ~/mychainlink

# Go up one folder
cd ..

# Go back to previous folder
cd -
```

## EDITING FILES

```bash
# Simple editor (easiest)
nano index.html
# Ctrl+O = save, Ctrl+X = exit, Arrow keys = move

# More powerful editor
vim index.html
# i = insert mode, Escape = command mode, :wq = save & quit

# Edit without opening editor (replace text)
sed -i 's/old-text/new-text/g' index.html

# Replace on a specific line
sed -i '47s/old/new/' index.html
```

## VIEWING FILES

```bash
# Show entire file
cat index.html

# Show first 20 lines
head -20 index.html

# Show last 20 lines
tail -20 index.html

# Show lines 100-120
sed -n '100,120p' index.html

# Show file with line numbers
cat -n index.html

# Search for something in a file
grep -n "function su" index.html
```

## GITHUB STUFF

```bash
# Check what's changed
git status

# See recent commits
git log --oneline -5

# Add your changes
git add index.html

# Or add everything
git add .

# Commit with a message
git commit -m "fixed the login button"

# Push to GitHub
git push origin main

# Pull latest from GitHub (if someone else changed it)
git pull origin main
```

## USEFUL ONE-LINERS

```bash
# Find which line contains a function
grep -n "function su()" index.html

# Count how many lines in a file
wc -l index.html

# Make a backup before editing
cp index.html index.html.backup

# Compare two files
diff index.html index.html.backup

# Show file size
ls -lh index.html
```
