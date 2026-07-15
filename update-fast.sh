#!/bin/bash
# Fast-fail deploy for Digital Garden on a small VPS.
# Usage (on server):
#   sudo bash /opt/digital-garden/deploy/update-fast.sh
#   sudo bash /opt/digital-garden/deploy/update-fast.sh server   # only API
#   sudo bash /opt/digital-garden/deploy/update-fast.sh web      # only frontend
#
# Design:
# - Probe GitHub / mirrors with short timeout; fail with clear next steps
# - Build server and web separately (avoids OOM on 2G RAM)
# - Never pipe whole build to `tail` (that hides progress until the end)

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/opt/digital-garden}"
TARGET="${1:-all}"  # all | server | web | check
CONNECT_SECS="${CONNECT_SECS:-8}"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

fail_guide() {
  red "=== FAST FAIL ==="
  red "$1"
  echo
  yellow "你应该怎么做（按当前网络选一条）："
  cat <<'EOF'
A) 你本机需要外网/VPN 时：先断开会干扰 SSH 的全局代理，再用下面本机命令只做「探测」：
     ssh -o ConnectTimeout=8 -o BatchMode=yes aliyun-dg "echo OK"

B) 服务器访问 GitHub/Maven/npm 慢或超时（国内轻量机常见）：
   1. 在「能稳定 SSH 的时刻」登录服务器
   2. 不要用: docker compose up -d --build （一次编两个，又慢又容易 OOM）
   3. 改用本脚本，或手工分步：
        cd /opt/digital-garden/deploy
        sudo docker compose up -d --build server
        sudo docker compose up -d --build web
   4. 长期方案：Dockerfile 配阿里云 Maven / npmmirror，或本机 build 镜像后 docker save/load

C) SSH 都连不上：到阿里云控制台用网页「远程连接 / Workbench」执行部署，或等网络恢复。

D) 只要热修静态前端：本机构建 scp dist 到容器（跳过 npm on server）——找我用「本机构建上传」流程。
EOF
  exit 1
}

probe() {
  local name="$1" url="$2"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" --connect-timeout "$CONNECT_SECS" --max-time "$CONNECT_SECS" "$url" || echo "000")
  echo "probe $name -> HTTP $code (${CONNECT_SECS}s budget)"
  if [ "$code" = "000" ]; then
    return 1
  fi
  return 0
}

echo "=== [0] Preflight (${CONNECT_SECS}s timeouts) ==="
free -h | head -2 || true
echo "target=$TARGET"

if ! probe github "https://github.com"; then
  fail_guide "服务器 ${CONNECT_SECS}s 内无法连上 GitHub（拉代码会失败或极慢）。"
fi
if ! probe npmmirror "https://registry.npmmirror.com"; then
  yellow "WARN: npmmirror 不通；若 web Dockerfile 用官方 npm，构建可能卡住。"
fi

if [ "$TARGET" = "check" ]; then
  green "Preflight OK"
  exit 0
fi

echo "=== [1] Sync git (ff-only) ==="
cd "$INSTALL_DIR"
git -C digital-garden-site-server fetch --depth 1 origin master
git -C digital-garden-site-server reset --hard origin/master
git -C digital-garden-site-web fetch --depth 1 origin master
git -C digital-garden-site-web reset --hard origin/master
echo "server=$(git -C digital-garden-site-server rev-parse --short HEAD)"
echo "web=$(git -C digital-garden-site-web rev-parse --short HEAD)"

cd "$INSTALL_DIR/deploy"

build_one() {
  local svc="$1"
  echo "=== [2] Build $svc (stream logs; do not pipe to tail) ==="
  # DOCKER_BUILDKIT reduces some rebuild cost; still heavy on cold cache
  DOCKER_BUILDKIT=1 docker compose --env-file .env build "$svc"
  docker compose --env-file .env up -d --no-deps "$svc"
}

case "$TARGET" in
  server) build_one server ;;
  web) build_one web ;;
  all)
    build_one server
    build_one web
    ;;
  *) fail_guide "未知参数: $TARGET（用 all|server|web|check）" ;;
esac

echo "=== [3] Health (90s max) ==="
ok=0
for i in $(seq 1 18); do
  if curl -sf --max-time 3 http://localhost/api/health >/dev/null 2>&1; then
    green "Health OK"
    ok=1
    break
  fi
  echo "waiting health... $i/18"
  sleep 5
done
if [ "$ok" != "1" ]; then
  red "Health still failing. Last server logs:"
  docker compose logs --tail 40 server || true
  fail_guide "容器已起来但 /api/health 不通，看上面日志。"
fi

curl -s --max-time 5 http://localhost/api/health || true
echo
green "=== Deploy finished ==="
echo "Site: http://$(curl -sf --max-time 3 ifconfig.me 2>/dev/null || echo YOUR_IP)"
