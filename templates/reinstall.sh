#!/bin/bash
# reinstall.sh 雛形 — ~/workspace/tools/reinstall.sh にコピーして使う。
# 原則: 冪等 (何度実行しても壊れない)。apt 側の復旧 + 永続側の不足分の補充。
set -u
TOOLS="$HOME/workspace/tools"
BIN="$TOOLS/bin"
mkdir -p "$BIN"

echo "== apt ロック待ち =="
# ランタイムの自動復旧が apt を掴んでいることがある。失敗ではなく待機が正解。
for i in $(seq 1 40); do
  if flock -n /var/lib/apt/lists/lock -c true 2>/dev/null && flock -n /var/lib/dpkg/lock-frontend -c true 2>/dev/null; then
    break
  fi
  echo "aptロック待ち... ($i)"; sleep 30
done

echo "== apt パッケージ =="
# ミラーが不安定なことがあるのでリトライ付き
apt-get update -qq || true
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  -o Acquire::Retries=5 -o Acquire::http::Timeout=60 \
  package-a package-b   # ← 自分の道具に置き換える

echo "== 単体バイナリ (GitHub リリース) =="
# 例: bin/gh-install.sh owner/repo vX.Y.Z asset-name.tar.gz dest-name
# [ -x "$BIN/example" ] || { curl -sL <url> | tar -xz -C /tmp && cp /tmp/example "$BIN/"; }

echo "== Python venv =="
# venv はホーム内にあるので通常は残っている。無い場合だけ作り直す。
# [ -d "$TOOLS/venv" ] || python3 -m venv "$TOOLS/venv"
# "$TOOLS/venv/bin/pip" install -q package==1.2.3   # ← バージョン固定と理由をコメントに

echo "== プロキシ CA (必要な venv に) =="
# bin/add-proxy-ca.sh "$TOOLS/venv"

echo "== バージョン確認 =="
# ここが全部通ることが復旧完了の定義。--version だけでなく実機能の最小確認を混ぜる。
echo "完了"
