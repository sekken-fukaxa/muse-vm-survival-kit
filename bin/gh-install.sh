#!/bin/bash
# GitHub リリースから単体バイナリを冪等に導入する。
# 使い方: gh-install.sh <owner/repo> <tag> <asset-file-name> <install-name>
#   例: gh-install.sh typst/typst v0.15.1 typst-x86_64-unknown-linux-musl.tar.xz typst
# アーカイブ (.tar.gz / .tar.xz / .zip) なら展開し、同名または install-name の実行ファイルを探して
# ~/workspace/tools/bin/<install-name> に置く。素のバイナリ asset にも対応。
set -eu
REPO="${1:?owner/repo}"; TAG="${2:?tag}"; ASSET="${3:?asset name}"; NAME="${4:?install name}"
BIN="${TOOLS_BIN:-$HOME/workspace/tools/bin}"
mkdir -p "$BIN"
if [ -x "$BIN/$NAME" ]; then
  echo "導入済み: $BIN/$NAME"
  exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
echo "取得: $URL"
curl -sL -o "$TMP/asset" "$URL"
case "$ASSET" in
  *.tar.gz|*.tgz) tar -xzf "$TMP/asset" -C "$TMP" ;;
  *.tar.xz)       tar -xJf "$TMP/asset" -C "$TMP" ;;
  *.zip)          unzip -q -o "$TMP/asset" -d "$TMP" ;;
  *)              mv "$TMP/asset" "$TMP/$NAME" ;;
esac
FOUND="$(find "$TMP" -type f -name "$NAME" | head -1)"
[ -n "$FOUND" ] || { echo "アーカイブ内に $NAME が見つかりません" >&2; exit 1; }
cp "$FOUND" "$BIN/$NAME"; chmod +x "$BIN/$NAME"
echo "導入完了: $BIN/$NAME"
