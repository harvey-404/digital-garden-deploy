#!/bin/bash
# Digital Garden one-click install for Aliyun / Ubuntu
# Usage: curl -fsSL https://raw.githubusercontent.com/harvey-404/digital-garden-deploy/main/install.sh | bash

set -euo pipefail

INSTALL_DIR="/opt/digital-garden"
GITHUB="https://github.com/harvey-404"

echo "=== [1/5] Install Docker ==="
if ! command -v docker >/dev/null 2>&1; then
  apt-get update -y
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi
docker --version
docker compose version

echo "=== [2/5] Clone repositories ==="
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -d digital-garden-site-server/.git ]; then
  git clone "$GITHUB/digital-garden-site-server.git"
fi
if [ ! -d digital-garden-site-web/.git ]; then
  git clone "$GITHUB/digital-garden-site-web.git"
fi
if [ ! -d deploy/.git ]; then
  git clone "$GITHUB/digital-garden-deploy.git" deploy
fi

echo "=== [3/5] Create production .env ==="
cd "$INSTALL_DIR/deploy"
if [ ! -f .env ]; then
  DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
  JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
  ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
  PUBLIC_IP=$(curl -sf --max-time 5 ifconfig.me || curl -sf --max-time 5 ip.sb || echo "localhost")

  cat > .env << EOF
DB_NAME=digital_garden
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ADMIN_USERNAME=harvey
ADMIN_PASSWORD=${ADMIN_PASSWORD}
CORS_ORIGINS=http://${PUBLIC_IP}
EOF
  echo "Generated .env (credentials printed at end)"
else
  echo ".env already exists, skip generation"
  ADMIN_PASSWORD="(see existing .env ADMIN_PASSWORD)"
fi

echo "=== [4/5] Build and start (may take 10-15 min) ==="
docker compose --env-file .env up -d --build

echo "=== [5/5] Wait for health ==="
sleep 45
docker compose ps
curl -sf http://localhost/api/health && echo "" || echo "Health check pending, wait 1 min and retry: curl http://localhost/api/health"

echo ""
echo "=========================================="
echo "  Digital Garden deploy finished!"
echo "  Site:  http://${PUBLIC_IP}"
echo "  Admin: http://${PUBLIC_IP}/admin/login"
echo "  User:  harvey"
if [ -f .env ]; then
  echo "  Pass:  $(grep ADMIN_PASSWORD .env | cut -d= -f2)"
fi
echo "=========================================="
