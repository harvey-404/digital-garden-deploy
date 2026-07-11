#!/bin/bash
# 拉取最新代码并重新构建部署（在服务器 /opt/digital-garden 下执行）
set -euo pipefail

INSTALL_DIR="/opt/digital-garden"

echo "=== [1/4] Pull latest code ==="
cd "$INSTALL_DIR"
git -C digital-garden-site-server pull --ff-only
git -C digital-garden-site-web pull --ff-only
git -C deploy pull --ff-only

echo "=== [2/4] Rebuild and restart ==="
cd "$INSTALL_DIR/deploy"
docker compose --env-file .env up -d --build

echo "=== [3/4] Wait for health ==="
for i in $(seq 1 18); do
  if curl -sf http://localhost/api/health >/dev/null 2>&1; then
    echo "Health OK"
    break
  fi
  echo "Waiting... ($i/18)"
  sleep 10
done

echo "=== [4/4] Verify like API (slug) ==="
SLUG=$(curl -sf "http://localhost/api/posts?page=0&size=1" | grep -o '"slug":"[^"]*"' | head -1 | cut -d'"' -f4 || true)
if [ -n "$SLUG" ]; then
  CODE=$(curl -sf -o /tmp/like.json -w "%{http_code}" -X POST "http://localhost/api/posts/${SLUG}/like" \
    -H "Content-Type: application/json" \
    -d "{\"visitorId\":\"update-verify-$(date +%s)\"}" || echo "000")
  echo "POST /api/posts/${SLUG}/like -> HTTP ${CODE}"
  cat /tmp/like.json 2>/dev/null || true
  echo
fi

echo ""
echo "=== Update finished ==="
echo "Site:  http://$(curl -sf ifconfig.me 2>/dev/null || echo 'YOUR_IP')"
echo "Admin password: grep ADMIN_PASSWORD $INSTALL_DIR/deploy/.env"
