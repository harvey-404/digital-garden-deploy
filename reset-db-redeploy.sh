#!/bin/bash
# Reset Flyway history so V0 can rebuild schema (test data disposable).
set -euo pipefail
INSTALL_DIR="/opt/digital-garden"
cd "$INSTALL_DIR/deploy"
source .env

echo "=== [1/5] Reset database tables ==="
sudo docker compose --env-file .env exec -T mysql mysql -uroot -p"${DB_PASSWORD}" "${DB_NAME}" <<'SQL'
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS flyway_schema_history;
DROP TABLE IF EXISTS post_tag;
DROP TABLE IF EXISTS post_like;
DROP TABLE IF EXISTS comment;
DROP TABLE IF EXISTS post;
DROP TABLE IF EXISTS project;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS admin_user;
DROP TABLE IF EXISTS site_profile;
SET FOREIGN_KEY_CHECKS = 1;
SQL

echo "=== [2/5] Rebuild containers ==="
sudo docker compose --env-file .env up -d --build

echo "=== [3/5] Wait for health ==="
for i in $(seq 1 24); do
  if curl -sf http://localhost/api/health >/dev/null 2>&1; then
    echo "Health OK"
    break
  fi
  echo "Waiting... ($i/24)"
  sleep 5
done

echo "=== [4/5] Verify API ==="
curl -sf http://localhost/api/health
echo
curl -sf http://localhost/api/posts?page=0&size=1 | head -c 300
echo

echo "=== [5/5] Done ==="
