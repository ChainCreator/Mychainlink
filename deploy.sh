#!/bin/bash
# Deploy script for mychainlink
# Run this after I update the code

cd "$(dirname "$0")"

echo "🔥 Adding changes..."
git add .

echo "🔥 Committing..."
git commit -m "update $(date '+%Y-%m-%d %H:%M')"

echo "🔥 Pushing to GitHub..."
git push origin main

echo "✅ Done! Netlify will deploy in ~30 seconds."
