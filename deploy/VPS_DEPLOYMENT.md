# Open Design — VPS Deployment Guide

## Overview

Production deployment of **Open Design** (`nexu-io/open-design`) on Ubuntu VPS with PM2, Nginx, and SSL.

**Live URL:** `https://43.167.237.50`  
**Health check:** `https://43.167.237.50/api/health`  
**GitHub fork:** `https://github.com/vikas947/Open-Design`

---

## Architecture

```
Browser → Nginx (port 443/80, SSL termination)
              └──→ PM2 (open-design daemon, port 7456)
                       └── Node.js 24 + Express + SQLite
```

The daemon serves both the REST API and the static web build (`apps/web/out/`).

---

## 1. System Requirements

| Component | Version | Location |
|-----------|---------|----------|
| Node.js | 24.x | `/home/ubuntu/.nvm/versions/node/v24.16.0/bin/node` |
| pnpm | 10.33.2 | Corepack (via nvm) |
| PM2 | 7.x | npm global |
| Nginx | 1.24.0 | apt |
| OS | Ubuntu 22.04+ | |

---

## 2. Directory Structure

```
/opt/open-design/
├── apps/
│   ├── daemon/dist/          # Built daemon
│   ├── daemon/node_modules/  # Workspace package symlinks
│   └── web/out/              # Static web build
├── packages/                 # Workspace packages (src + dist)
├── node_modules/             # pnpm virtual store
├── .env                      # Environment variables (gitignored)
├── ecosystem.config.cjs      # PM2 configuration → deploy/pm2.config.cjs
├── logs/                     # PM2 output logs
├── pids/                     # PM2 PID files
├── .od/                      # Daemon runtime data (SQLite DB, artifacts)
├── pnpm-lock.yaml
└── pnpm-workspace.yaml
```

---

## 3. Deploy (First Time)

```bash
# 1. Clone
git clone https://github.com/vikas947/Open-Design.git /tmp/open-design
cd /tmp/open-design
git checkout deploy-vps

# 2. Use Node 24
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 24

# 3. Install & build
pnpm install
pnpm --filter @open-design/daemon build
pnpm --filter @open-design/web build

# 4. Deploy to /opt/open-design
sudo mkdir -p /opt/open-design
sudo chown ubuntu:ubuntu /opt/open-design
rsync -a . /opt/open-design/ --exclude=node_modules --exclude=.git
cp -r node_modules /opt/open-design/
cp -r apps/web/out /opt/open-design/apps/web/out

# 5. Rebuild native modules for Node 24
cd /opt/open-design
/home/ubuntu/.nvm/versions/node/v24.16.0/bin/npm rebuild better-sqlite3

# 6. Create .env
cat > /opt/open-design/.env << EOF
NODE_ENV=production
OD_BIND_HOST=0.0.0.0
OD_PORT=7456
OD_WEB_PORT=7456
# Generate with: openssl rand -hex 32
OD_API_TOKEN=$(openssl rand -hex 32)
OD_ALLOWED_ORIGINS=http://43.167.237.50,https://43.167.237.50,http://localhost:7456
EOF

# 7. Create directories
mkdir -p /opt/open-design/logs /opt/open-design/pids /opt/open-design/.od

# 8. Start via PM2
pm2 start /opt/open-design/ecosystem.config.cjs
pm2 save
pm2 startup  # Run the generated sudo command

# 9. Nginx
sudo cp deploy/nginx/open-design.conf /etc/nginx/sites-available/open-design
sudo ln -sf /etc/nginx/sites-available/open-design /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo nginx -s reload
```

---

## 4. Update (Code Changes)

```bash
cd /tmp/open-design
git pull origin deploy-vps
pnpm install
pnpm --filter @open-design/daemon build
pnpm --filter @open-design/web build

# Copy updated files
rsync -a . /opt/open-design/ --exclude=node_modules --exclude=.git
cp -r node_modules /opt/open-design/node_modules
cp -r apps/web/out /opt/open-design/apps/web/out

# Restart
pm2 restart open-design
pm2 logs open-design --lines 20
```

---

## 5. Rollback

```bash
# Quick rollback — redeploy previous git commit
cd /tmp/open-design
git log --oneline -5   # Find the commit before the problematic one
git checkout <previous-commit-hash>
# Then run the Update steps above

# OR — revert a specific commit
git revert <bad-commit-hash> --no-edit
# Then run Update steps
```

---

## 6. Monitoring & Logs

```bash
# PM2
pm2 status                     # Process list
pm2 logs open-design           # Tail logs
pm2 monit                      # Resource monitor
pm2 show open-design           # Detailed info

# Nginx
sudo nginx -t                  # Config test
sudo systemctl status nginx    # Service status
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Application health
curl -s https://43.167.237.50/api/health

# System
htop                           # Resource usage
df -h                          # Disk space
```

---

## 7. Common Troubleshooting

| Problem | Solution |
|---------|----------|
| Daemon won't start | Check logs: `pm2 logs open-design` |
| Port 7456 in use | `lsof -i :7456` then kill the process |
| `OD_API_TOKEN` error | Set it in `.env` or `ecosystem.config.cjs` |
| Nginx 502 Bad Gateway | Daemon isn't running → `pm2 start open-design` |
| SSL cert expired | `sudo certbot renew` (if using Let's Encrypt) |
| Native module error | `npm rebuild better-sqlite3` |

---

## 8. Production SSL (Let's Encrypt)

When you have a domain pointed to `43.167.237.50`:

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
sudo systemctl enable certbot.timer  # Auto-renewal
```

Then update `OD_ALLOWED_ORIGINS` in `ecosystem.config.cjs` to include `https://yourdomain.com`.

---

## 9. API Token

The daemon requires `OD_API_TOKEN` when binding to `0.0.0.0`. Generate one:

```bash
openssl rand -hex 32
```

This is set in:
- `/opt/open-design/.env` (source of truth)
- `/opt/open-design/ecosystem.config.cjs` (PM2 override)
