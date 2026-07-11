#!/bin/bash
# 在阿里云 Workbench 中粘贴执行（一次性：开通本机 SSH + 拉代码重建）
set -euo pipefail

DEPLOY_PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINxeRBqayzOnNV6PxNNCTU4ZV9vkKM5/wa2cKJrsFGMb admin@DESKTOP-3TOTTY5'

echo "=== [1/2] Authorize local deploy key ==="
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
if ! grep -qF "$DEPLOY_PUBKEY" ~/.ssh/authorized_keys 2>/dev/null; then
  echo "$DEPLOY_PUBKEY" >> ~/.ssh/authorized_keys
  echo "Deploy key added."
else
  echo "Deploy key already present."
fi

echo "=== [2/2] Run update.sh ==="
curl -fsSL "https://ghproxy.net/https://raw.githubusercontent.com/harvey-404/digital-garden-deploy/master/update.sh" \
  | sudo bash
