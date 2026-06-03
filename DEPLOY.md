# MyChainLink Auto-Deploy Setup

## The Goal
Every time I update `index.html` here, you push to GitHub and Netlify auto-deploys.

## Step 1: Create a GitHub Repo
1. Go to https://github.com/new
2. Name it `mychainlink` (or whatever you want)
3. **Do NOT** initialize with README/.gitignore (we already have those)
4. Click **Create repository**
5. Copy the URL (it looks like `https://github.com/YOURNAME/mychainlink.git`)

## Step 2: Connect This Code to GitHub
Run this in the terminal (replace YOURNAME with your GitHub username):

```bash
cd /root/.openclaw/workspace/mychainlink
git remote add origin https://github.com/YOURNAME/mychainlink.git
git branch -M main
git push -u origin main
```

It will ask for your GitHub username and password/token.

## Step 3: Connect Netlify to GitHub
1. Go to https://app.netlify.com
2. Click your site (`mychainlink.ca`)
3. Go to **Site settings** → **Build & deploy** → **Continuous deployment**
4. Click **Link to a different repository**
5. Select **GitHub**, authorize it, pick your `mychainlink` repo
6. Set build command: **(leave empty)**
7. Set publish directory: `/` (or `.`)
8. Click **Deploy site**

## Step 4: Done
From now on, every time I update the code, you just run:

```bash
cd /root/.openclaw/workspace/mychainlink
git add .
git commit -m "update"
git push
```

Netlify will auto-deploy in ~30 seconds.

## Quick Update Script (Optional)
I can also create a one-liner for you to run whenever I make changes.
