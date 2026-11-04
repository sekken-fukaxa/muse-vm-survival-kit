#!/bin/bash
# egress プロキシの CA を、指定した venv の certifi バンドルに追記する (冪等)。
# Python 製ツールが CERTIFICATE_VERIFY_FAILED になるときの対処。
# 使い方: add-proxy-ca.sh <venv のパス>
set -eu
VENV="${1:?venv のパスを指定してください}"
CA="${HATCH_EGRESS_CA:-/run/hatch/egress-tls/hatch-egress-ca.pem}"
[ -f "$CA" ] || { echo "CA が見つかりません: $CA" >&2; exit 1; }
CERTIFI="$("$VENV/bin/python" -c 'import certifi; print(certifi.where())')"
if grep -q "hatch-egress" "$CERTIFI" 2>/dev/null || cmp -s <(tail -c "$(stat -c%s "$CA")" "$CERTIFI") "$CA"; then
  echo "追加済みです: $CERTIFI"
  exit 0
fi
{ echo "# hatch-egress proxy CA (added by add-proxy-ca.sh)"; cat "$CA"; } >> "$CERTIFI"
echo "CA を追加しました: $CERTIFI"
