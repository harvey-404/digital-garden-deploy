#!/bin/bash
# Digital Garden install for Aliyun China (no download.docker.com)
set -euo pipefail

INSTALL_DIR="/opt/digital-garden"
GITHUB="https://ghproxy.net/https://github.com/harvey-404"
GITHUB_FALLBACK="https://github.com/harvey-404"
PUBLIC_IP="${PUBLIC_IP:-101.37.33.184}"

echo "=== [1/6] Install Docker (apt, Aliyun mirror) ==="
apt-get update -y
apt-get install -y docker.io docker-compose-v2 git openssl curl
systemctl enable docker
systemctl start docker

mkdir -p /etc/docker
if [ ! -f /etc/docker/daemon.json ]; then
  cat > /etc/docker/daemon.json << 'EOF'
{
  "registry-mirrors": ["https://registry.cn-hangzhou.aliyuncs.com"]
}
EOF
  systemctl restart docker
fi

docker --version
docker compose version

echo "=== [2/6] Clone repositories ==="
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

clone_repo() {
  local name=$1
  if [ -d "$name/.git" ]; then
    echo "$name exists, skip"
    return
  fi
  git clone "${GITHUB}/${name}.git" || git clone "${GITHUB_FALLBACK}/${name}.git"
}

clone_repo "digital-garden-site-server"
clone_repo "digital-garden-site-web"
if [ -d deploy/.git ]; then
  echo "deploy exists, skip"
else
  git clone "${GITHUB}/digital-garden-deploy.git" deploy || git clone "${GITHUB_FALLBACK}/digital-garden-deploy.git" deploy
fi

echo "=== [3/6] Create .env ==="
cd "$INSTALL_DIR/deploy"
if [ ! -f .env ]; then
  DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
  JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
  ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 16)
  cat > .env << EOF
DB_NAME=digital_garden
DB_PASSWORD=${DB_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ADMIN_USERNAME=harvey
ADMIN_PASSWORD=${ADMIN_PASSWORD}
CORS_ORIGINS=http://${PUBLIC_IP}
EOF
else
  ADMIN_PASSWORD=$(grep ADMIN_PASSWORD .env | cut -d= -f2)
fi

echo "=== [4/6] Build and start (10-20 min) ==="
docker compose --env-file .env up -d --build

echo "=== [5/6] Wait for health ==="
for i in $(seq 1 12); do
  if curl -sf http://localhost/api/health >/dev/null 2>&1; then
    echo "Health OK"
    break
  fi
  echo "Waiting... ($i/12)"
  sleep 10
done

echo "=== [6/6] Status ==="
docker compose ps
curl -sf http://localhost/api/health || true

echo ""
echo "=========================================="
echo "  DONE"
echo "  Site:  http://${PUBLIC_IP}"
echo "  Admin: http://${PUBLIC_IP}/admin/login"
echo "  User:  harvey"
echo "  Pass:  ${ADMIN_PASSWORD}"
echo "=========================================="
