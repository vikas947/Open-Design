#!/bin/bash
set -euo pipefail

# Open Design — Update Script
# Pulls latest code, rebuilds, and restarts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/open-design"
APP_DIR="/opt/open-design"
NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use 24
fi

echo "📦 Updating Open Design..."
cd "$BUILD_DIR"

# Pull latest
git checkout deploy-vps
git pull origin deploy-vps
echo "✅ Code updated"

# Install and build
pnpm install
pnpm --filter @open-design/daemon build
pnpm --filter @open-design/web build
echo "✅ Build complete"

# Deploy to production dir
rsync -a . "$APP_DIR/" --exclude=node_modules --exclude=.git
cp -r node_modules "$APP_DIR/node_modules"
cp -r apps/web/out "$APP_DIR/apps/web/out"

# Rebuild native modules
npm rebuild better-sqlite3

# Restart
pm2 restart open-design
echo "✅ Update complete — open-design restarted"
pm2 logs open-design --lines 5
