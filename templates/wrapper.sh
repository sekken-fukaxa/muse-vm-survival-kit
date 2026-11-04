#!/bin/bash
# ラッパーの雛形 — 環境変数や前提を吸収してから実体を呼ぶ。
# 例: Marp の PDF 出力には Chromium の場所 (CHROME_PATH) が必要なので、
#     Playwright の Chromium を自動で探して渡す。
if [ -z "${CHROME_PATH:-}" ]; then
  for c in "$HOME"/workspace/tools/ms-playwright/chromium-*/chrome-linux64/chrome; do
    [ -x "$c" ] && export CHROME_PATH="$c" && break
  done
fi
exec "$HOME/workspace/tools/<tool>/path/to/real-binary" "$@"
