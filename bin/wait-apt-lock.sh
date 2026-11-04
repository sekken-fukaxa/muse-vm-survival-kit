#!/bin/bash
# apt のロック (lists / dpkg-frontend) が両方空くまで待つ。
# 使い方: wait-apt-lock.sh [最大試行回数] [間隔秒]   既定: 40回 × 30秒
set -u
TRIES="${1:-40}"; INTERVAL="${2:-30}"
for i in $(seq 1 "$TRIES"); do
  if flock -n /var/lib/apt/lists/lock -c true 2>/dev/null && flock -n /var/lib/dpkg/lock-frontend -c true 2>/dev/null; then
    echo "apt ロックは空いています"
    exit 0
  fi
  echo "aptロック待ち... ($i/$TRIES)"
  sleep "$INTERVAL"
done
echo "タイムアウト: ロックが空きませんでした" >&2
exit 1
