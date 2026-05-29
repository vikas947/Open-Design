#!/bin/bash
set -euo pipefail

# Open Design — Startup Script
# Run this to start or restart the application

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/open-design"
NVM_DIR="$HOME/.nvm"

# Source nvm
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm use 24
fi

# Load .env
if [ -f "$APP_DIR/.env" ]; then
    set -a
    source "$APP_DIR/.env"
    set +a
fi

case "${1:-start}" in
    start)
        pm2 start "$APP_DIR/ecosystem.config.cjs"
        pm2 save
        echo "✅ open-design started"
        ;;
    stop)
        pm2 stop open-design
        echo "⏹️  open-design stopped"
        ;;
    restart)
        pm2 restart open-design
        echo "🔄 open-design restarted"
        ;;
    status)
        pm2 status open-design
        curl -s "$APP_DIR/.env" | grep OD_PORT | cut -d= -f2 || echo "7456"
        PORT=${OD_PORT:-7456}
        curl -s "http://127.0.0.1:$PORT/api/health" || echo "⚠️  Health check failed"
        ;;
    logs)
        pm2 logs open-design --lines "${2:-20}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
