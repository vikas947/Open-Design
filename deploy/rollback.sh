#!/bin/bash
set -euo pipefail

# Open Design — Rollback Script
# Rolls back to a previous deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/open-design"

echo "🔙 Open Design Rollback"
echo ""
echo "Recent commits:"
cd "$BUILD_DIR"
git log --oneline -10 --decorate
echo ""
read -rp "Enter commit hash to rollback to: " COMMIT

if [ -z "$COMMIT" ]; then
    echo "❌ No commit specified. Aborting."
    exit 1
fi

echo "🔄 Rolling back to $COMMIT..."
git checkout "$COMMIT"
echo "✅ Rolled back to $COMMIT"

# Now rebuild and redeploy
exec "$SCRIPT_DIR/update.sh"
