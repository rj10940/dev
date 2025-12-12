#!/bin/bash
# Quick Push Script - Automates pushing to GitHub

echo "🚀 Push to GitHub Script"
echo ""

# Check if remote exists
if git remote | grep -q "origin"; then
    echo "✅ Remote 'origin' already configured"
    git remote -v
    echo ""
    read -p "Push to existing remote? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        echo "Aborted."
        exit 0
    fi
else
    echo "❌ No remote configured"
    echo ""
    echo "Please add remote first:"
    echo ""
    echo "  git remote add origin git@github.com:YOUR-USERNAME/ods-deployment-system.git"
    echo ""
    echo "Or run:"
    read -p "Enter your GitHub repository URL (SSH or HTTPS): " repo_url
    
    if [ -z "$repo_url" ]; then
        echo "No URL provided. Aborted."
        exit 1
    fi
    
    git remote add origin "$repo_url"
    echo "✅ Remote added: $repo_url"
    echo ""
fi

# Check current branch
current_branch=$(git branch --show-current)
echo "📍 Current branch: $current_branch"
echo ""

# Rename to main if needed
if [ "$current_branch" != "main" ]; then
    read -p "Rename branch to 'main'? (y/n): " rename
    if [ "$rename" == "y" ]; then
        git branch -M main
        current_branch="main"
        echo "✅ Branch renamed to main"
    fi
fi

# Push
echo ""
echo "🚀 Pushing to origin/$current_branch..."
echo ""

if git push -u origin "$current_branch"; then
    echo ""
    echo "=============================================="
    echo "✅ Successfully pushed to GitHub!"
    echo "=============================================="
    echo ""
    echo "📍 Repository: $(git remote get-url origin)"
    echo "🌿 Branch: $current_branch"
    echo ""
    echo "🎯 Next steps:"
    echo "  1. Go to your GitHub repository"
    echo "  2. Navigate to 'Actions' tab"
    echo "  3. Click '🚀 Deploy ODS Frontend'"
    echo "  4. Click 'Run workflow'"
    echo "  5. Fill in deployment details"
    echo "  6. Click 'Run workflow' button"
    echo ""
    echo "⏰ Deployment takes ~5-10 minutes"
    echo "🌐 Access: https://YOUR-DEPLOYMENT.ods.rahuljoshi.info"
    echo ""
else
    echo ""
    echo "=============================================="
    echo "❌ Push failed!"
    echo "=============================================="
    echo ""
    echo "Common issues:"
    echo "  1. SSH key not configured"
    echo "  2. Wrong repository URL"
    echo "  3. No permission to push"
    echo ""
    echo "See PUSH_TO_GITHUB.md for detailed instructions"
    exit 1
fi

