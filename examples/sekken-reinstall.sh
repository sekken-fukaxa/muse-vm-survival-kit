#!/bin/bash
# せっけんのVM用ツール一式 再インストールスクリプト
# VMが入れ替わって apt 側の道具が消えたら、これを実行すると復旧する。
# 使い方: bash ~/workspace/tools/reinstall.sh
set -e

echo "== apt: OCR・文書変換・動画セット =="
# VM入替直後はランタイムの自動復旧(apt)がロックを握ることがあるので、空くまで待つ
for i in $(seq 1 40); do
  if flock -n /var/lib/apt/lists/lock -c true 2>/dev/null && flock -n /var/lib/dpkg/lock-frontend -c true 2>/dev/null; then
    break
  fi
  echo "aptロック待ち... ($i)"; sleep 30
done
# ミラーが不安定なことがあるのでリトライ付き。失敗したらもう一度実行すればよい
apt-get update -qq || true
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  -o Acquire::Retries=5 -o Acquire::http::Timeout=60 \
  tesseract-ocr tesseract-ocr-jpn tesseract-ocr-eng \
  pandoc qpdf imagemagick \
  mkvtoolnix mediainfo espeak-ng ocrmypdf p7zip-full graphviz inkscape fonts-noto-cjk-extra

echo "== tesseract 高精度データ (tessdata_best) =="
mkdir -p "$HOME/workspace/tools/tessdata"
if [ ! -s "$HOME/workspace/tools/tessdata/jpn.traineddata" ]; then
  curl -sL -o "$HOME/workspace/tools/tessdata/jpn.traineddata" \
    https://github.com/tesseract-ocr/tessdata_best/raw/main/jpn.traineddata
  curl -sL -o "$HOME/workspace/tools/tessdata/eng.traineddata" \
    https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata
  curl -sL -o "$HOME/workspace/tools/tessdata/jpn_vert.traineddata" \
    https://github.com/tesseract-ocr/tessdata_best/raw/main/jpn_vert.traineddata
  curl -sL -o "$HOME/workspace/tools/tessdata/osd.traineddata" \
    https://github.com/tesseract-ocr/tessdata_best/raw/main/osd.traineddata
fi

echo "== venv: yt-dlp / duckdb (~/workspace/tools/venv) =="
# venv はホーム内にあるので通常は残っている。無い場合だけ作り直す。
if [ ! -x "$HOME/workspace/tools/venv/bin/python" ]; then
  python3 -m venv "$HOME/workspace/tools/venv"
fi
"$HOME/workspace/tools/venv/bin/pip" install --quiet --upgrade yt-dlp duckdb \
  faster-whisper "av==16.1.0" auto-editor scenedetect moviepy \
  "sudachipy>=0.6.8" "sudachidict-core>=20240409" \
  vibrato zstandard neologdn polars scikit-learn wordcloud
# 注意: av は faster-whisper 1.2.1 と互換のある 16.1.0 に固定 (19.x は API 非互換)
ln -sf "$HOME/workspace/tools/venv/bin/yt-dlp" "$HOME/workspace/tools/bin/yt-dlp"
ln -sf "$HOME/workspace/tools/venv/bin/auto-editor" "$HOME/workspace/tools/bin/auto-editor"

# プロキシのCAを venv の certifi に追加 (無いと yt-dlp 等が SSL エラーになる)
if [ -f /run/hatch/egress-tls/hatch-egress-ca.pem ]; then
  CERT=$("$HOME/workspace/tools/venv/bin/python" -c "import certifi; print(certifi.where())")
  grep -q "hatch" "$CERT" 2>/dev/null || cat /run/hatch/egress-tls/hatch-egress-ca.pem >> "$CERT"
fi

# whisper small モデル (curl で取得。HFハブ経由が詰まる場合の確実な経路)
mkdir -p "$HOME/workspace/tools/whisper-models/small"
if [ ! -s "$HOME/workspace/tools/whisper-models/small/model.bin" ]; then
  for f in model.bin config.json tokenizer.json vocabulary.txt; do
    curl -sL -C - -o "$HOME/workspace/tools/whisper-models/small/$f" \
      "https://huggingface.co/Systran/faster-whisper-small/resolve/main/$f"
  done
fi

echo "== GitHub軽量セット: markitdown / ticker / rclone / argdown =="
# markitdown は依存競合回避のため専用 venv (本体 venv の moviepy と pillow 版数が衝突)
if [ ! -x "$HOME/workspace/tools/venv-markitdown/bin/python" ]; then
  python3 -m venv "$HOME/workspace/tools/venv-markitdown"
fi
"$HOME/workspace/tools/venv-markitdown/bin/pip" install --quiet "markitdown[pdf,docx,pptx,xlsx]"
ln -sf "$HOME/workspace/tools/venv-markitdown/bin/markitdown" "$HOME/workspace/tools/bin/markitdown"
# ticker (Goバイナリ)
if [ ! -x "$HOME/workspace/tools/bin/ticker" ]; then
  curl -sL "https://github.com/achannarasappa/ticker/releases/download/v5.3.0/ticker-5.3.0-linux-amd64.tar.gz" \
    | tar xz -C /tmp && install -m755 /tmp/ticker "$HOME/workspace/tools/bin/ticker"
fi
# rclone (Goバイナリ)
if [ ! -x "$HOME/workspace/tools/bin/rclone" ]; then
  curl -sL -o /tmp/rclone.zip "https://github.com/rclone/rclone/releases/download/v1.75.2/rclone-v1.75.2-linux-amd64.zip"
  "$HOME/workspace/tools/venv/bin/python" -c "
import zipfile
z = zipfile.ZipFile('/tmp/rclone.zip')
n = [x for x in z.namelist() if x.endswith('/rclone')][0]
open('$HOME/workspace/tools/bin/rclone','wb').write(z.read(n))"
  chmod +x "$HOME/workspace/tools/bin/rclone"
fi
# argdown (npm, tools/argdown にローカル導入)
if [ ! -e "$HOME/workspace/tools/argdown/node_modules/.bin/argdown" ]; then
  mkdir -p "$HOME/workspace/tools/argdown"
  (cd "$HOME/workspace/tools/argdown" && npm init -y >/dev/null 2>&1 && npm install @argdown/cli)
fi
ln -sf "$HOME/workspace/tools/argdown/node_modules/.bin/argdown" "$HOME/workspace/tools/bin/argdown"

echo "== VOICEVOX エンジン (ずんだもん等) =="
# 本体は ~/workspace/tools/voicevox に永続配置済み。無い場合だけ取得する (約1.8GB)
if [ ! -x "$HOME/workspace/tools/voicevox/linux-cpu-x64/run" ]; then
  command -v 7z >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y p7zip-full
  mkdir -p "$HOME/workspace/tools/voicevox"
  curl -sL -C - -o "$HOME/workspace/tools/voicevox/engine.7z.001" \
    "https://github.com/VOICEVOX/voicevox_engine/releases/download/0.26.0/voicevox_engine-linux-cpu-x64-0.26.0.7z.001"
  (cd "$HOME/workspace/tools/voicevox" && 7z x -y engine.7z.001 >/dev/null)
fi

echo "== AI臭チェックセット (textlint + natural-japanese) =="
# 本体は ~/workspace/tools/deai と ~/workspace/tools/natural-japanese に永続配置済み。
# node_modules が無い場合だけ入れ直す (バージョンは package-lock.json で固定)
if [ ! -x "$HOME/workspace/tools/deai/node_modules/.bin/textlint" ]; then
  (cd "$HOME/workspace/tools/deai" && npm ci --no-audit --no-fund || npm install --no-audit --no-fund)
fi
if [ ! -f "$HOME/workspace/tools/natural-japanese/skills/natural-japanese/scripts/lint.py" ]; then
  git clone --depth 1 https://github.com/coji/natural-japanese.git \
    "$HOME/workspace/tools/natural-japanese"
fi

echo "== 日本語テキスト解析セット (Vibrato辞書 / agrind / qsv) =="
# Vibrato用 IPADIC辞書 (永続配置済みなら何もしない)
if [ ! -s "$HOME/workspace/tools/vibrato-dict/ipadic-mecab-2_7_0/system.dic.zst" ]; then
  mkdir -p "$HOME/workspace/tools/vibrato-dict"
  curl -sL -o /tmp/ipadic.tar.xz \
    "https://github.com/daac-tools/vibrato/releases/download/v0.5.0/ipadic-mecab-2_7_0.tar.xz"
  tar --no-same-owner -xf /tmp/ipadic.tar.xz -C "$HOME/workspace/tools/vibrato-dict"
  rm -f /tmp/ipadic.tar.xz
fi
# angle-grinder (ログ集計バイナリ)
if [ ! -x "$HOME/workspace/tools/bin/agrind" ]; then
  curl -sL -o /tmp/agrind.tar.gz \
    "https://github.com/rcoh/angle-grinder/releases/download/v0.19.6/agrind-x86_64-unknown-linux-musl.tar.gz"
  tar xzf /tmp/agrind.tar.gz -C /tmp
  cp /tmp/agrind "$HOME/workspace/tools/bin/agrind" && chmod +x "$HOME/workspace/tools/bin/agrind"
  rm -f /tmp/agrind.tar.gz /tmp/agrind
fi
# qsv (CSVツールキット、musl版zipから qsv 本体だけ取り出す)
if [ ! -x "$HOME/workspace/tools/bin/qsv" ]; then
  curl -sL -o /tmp/qsv.zip \
    "https://github.com/dathere/qsv/releases/download/28.0.0/qsv-28.0.0-x86_64-unknown-linux-musl.zip"
  (cd /tmp && python3 -c "import zipfile; zipfile.ZipFile('qsv.zip').extract('qsv')" \
    && cp /tmp/qsv "$HOME/workspace/tools/bin/qsv" && chmod +x "$HOME/workspace/tools/bin/qsv")
  rm -f /tmp/qsv.zip /tmp/qsv
fi

echo "== 心理・自己探求セット (bigfive / oseti / ML-Ask / 尺度) =="
# oseti / pymlask (ML-Ask) / mecab-python3。emoji は bunkai 互換のため 1.7.0 に固定
"$HOME/workspace/tools/venv/bin/pip" install --quiet oseti pymlask mecab-python3 "emoji==1.7.0"
# MeCab用 IPADIC (UTF-8) 辞書: apt から一度だけ取得して tools 内に永続コピーする
if [ ! -d "$HOME/workspace/tools/mecab/dic-ipadic-utf8" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mecab-ipadic-utf8 || apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq mecab-ipadic-utf8
  mkdir -p "$HOME/workspace/tools/mecab"
  cp -r /var/lib/mecab/dic/ipadic-utf8 "$HOME/workspace/tools/mecab/dic-ipadic-utf8"
fi
printf 'dicdir = %s/workspace/tools/mecab/dic-ipadic-utf8\n' "$HOME" > "$HOME/workspace/tools/mecab/mecabrc"
# グラフ用日本語フォント (Noto Sans CJK JP)
mkdir -p "$HOME/workspace/tools/fonts"
if [ ! -s "$HOME/workspace/tools/fonts/NotoSansCJKjp-Regular.otf" ]; then
  curl -sL -o "$HOME/workspace/tools/fonts/NotoSansCJKjp-Regular.otf" \
    "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Regular.otf"
  curl -sL -o "$HOME/workspace/tools/fonts/NotoSansCJKjp-Bold.otf" \
    "https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/Japanese/NotoSansCJKjp-Bold.otf"
fi
# bigfive (IPIP-NEO-120 日本語): node_modules が無い場合だけ
if [ ! -d "$HOME/workspace/tools/bigfive/node_modules/@bigfive-org/questions" ]; then
  (cd "$HOME/workspace/tools/bigfive" && npm install --no-audit --no-fund)
fi

# (個人用メール CLI の節は、公開にあたり除去しました)

echo "== 推し5点セット (typst / restic / age / uv / gh / visidata) =="
# 単体バイナリは tools/bin に直接配置 (無い場合だけ取得)。バージョンは導入時点のものに固定
TB="$HOME/workspace/tools/bin"
if [ ! -x "$TB/typst" ]; then
  curl -sL https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz | tar -xJ -C /tmp
  cp /tmp/typst-x86_64-unknown-linux-musl/typst "$TB/typst"
fi
if [ ! -x "$TB/restic" ]; then
  curl -sL https://github.com/restic/restic/releases/download/v0.19.1/restic_0.19.1_linux_amd64.bz2 | bunzip2 -c > "$TB/restic"; chmod +x "$TB/restic"
fi
if [ ! -x "$TB/age" ]; then
  curl -sL https://github.com/FiloSottile/age/releases/download/v1.3.2/age-v1.3.2-linux-amd64.tar.gz | tar -xz -C /tmp
  cp /tmp/age/age /tmp/age/age-keygen "$TB/"
fi
if [ ! -x "$TB/uv" ]; then
  curl -sL https://github.com/astral-sh/uv/releases/download/0.13.7/uv-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C /tmp
  cp /tmp/uv-x86_64-unknown-linux-gnu/uv /tmp/uv-x86_64-unknown-linux-gnu/uvx "$TB/"
fi
if [ ! -x "$TB/gh" ]; then
  curl -sL https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_linux_amd64.tar.gz | tar -xz -C /tmp
  cp /tmp/gh_2.103.3_linux_amd64/bin/gh "$TB/gh"
fi
chmod +x "$TB/typst" "$TB/restic" "$TB/age" "$TB/age-keygen" "$TB/uv" "$TB/uvx" "$TB/gh" 2>/dev/null || true
# monolith (Webページを単一HTMLで保存する単体バイナリ)
if [ ! -x "$TB/monolith" ]; then
  curl -sL -o "$TB/monolith" https://github.com/Y2Z/monolith/releases/download/v2.12.0/monolith-cli-linux-x86_64; chmod +x "$TB/monolith"
fi
# VisiData は本体 venv へ (vd / visidata を tools/bin にリンク)
"$HOME/workspace/tools/venv/bin/pip" install -q visidata
ln -sf "$HOME/workspace/tools/venv/bin/vd" "$TB/vd"
ln -sf "$HOME/workspace/tools/venv/bin/visidata" "$TB/visidata"

echo "== 補助ブラウザ (Playwright + Chromium/Firefox) =="
# 専用 venv (venv-browser) とブラウザ本体 (tools/ms-playwright) は永続配置。無い場合だけ作る
if [ ! -x "$HOME/workspace/tools/venv-browser/bin/python" ]; then
  "$HOME/workspace/tools/bin/uv" venv "$HOME/workspace/tools/venv-browser"
  "$HOME/workspace/tools/bin/uv" pip install --python "$HOME/workspace/tools/venv-browser/bin/python" playwright
fi
if [ ! -d "$HOME/workspace/tools/ms-playwright" ]; then
  PLAYWRIGHT_BROWSERS_PATH="$HOME/workspace/tools/ms-playwright" "$HOME/workspace/tools/venv-browser/bin/python" -m playwright install chromium firefox
fi
# 注意: このVMの egress プロキシは Chromium が通れない (ERR_TUNNEL_CONNECTION_FAILED)。
# pw-get の既定エンジンは Firefox。Chromium はローカル描画専用。

echo "== 研究・執筆セット (harper / marp / pyzotero) =="
# harper-cli (オフライン英文法チェッカー、単体バイナリ)
if [ ! -x "$TB/harper-cli" ]; then
  curl -sL https://github.com/Automattic/harper/releases/download/v3.0.0/harper-cli-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C /tmp
  cp /tmp/harper-cli "$TB/harper-cli"; chmod +x "$TB/harper-cli"
fi
# marp (スライド生成、npmローカル導入。ラッパーは tools/bin/marp で手書き管理: CHROME_PATH 自動指定付き)
if [ ! -d "$HOME/workspace/tools/marp/node_modules" ]; then
  mkdir -p "$HOME/workspace/tools/marp" && cd "$HOME/workspace/tools/marp" && npm init -y >/dev/null 2>&1
  npm install --no-audit --no-fund @marp-team/marp-cli
  cd "$HOME"
fi
# pyzotero (Zotero Web API クライアント) は本体 venv へ。アカウントとAPIキーは別途必要
"$HOME/workspace/tools/venv/bin/pip" install -q pyzotero

echo "== デザイン用フォント (fonts-extra) =="
# apt に無い日本語書体を tools/fonts-extra に永続配置し、~/.local/share/fonts へリンクする
FE="$HOME/workspace/tools/fonts-extra"
mkdir -p "$FE" "$HOME/.local/share/fonts"
GF=https://github.com/google/fonts/raw/main/ofl
[ -f "$FE/BIZUDPGothic-Regular.ttf" ] || curl -sL -o "$FE/BIZUDPGothic-Regular.ttf" $GF/bizudpgothic/BIZUDPGothic-Regular.ttf
[ -f "$FE/BIZUDPGothic-Bold.ttf" ] || curl -sL -o "$FE/BIZUDPGothic-Bold.ttf" $GF/bizudpgothic/BIZUDPGothic-Bold.ttf
[ -f "$FE/MPLUSRounded1c-Regular.ttf" ] || curl -sL -o "$FE/MPLUSRounded1c-Regular.ttf" $GF/mplusrounded1c/MPLUSRounded1c-Regular.ttf
[ -f "$FE/MPLUSRounded1c-Bold.ttf" ] || curl -sL -o "$FE/MPLUSRounded1c-Bold.ttf" $GF/mplusrounded1c/MPLUSRounded1c-Bold.ttf
[ -f "$FE/ShipporiMincho-Regular.ttf" ] || curl -sL -o "$FE/ShipporiMincho-Regular.ttf" $GF/shipporimincho/ShipporiMincho-Regular.ttf
[ -f "$FE/ShipporiMincho-Bold.ttf" ] || curl -sL -o "$FE/ShipporiMincho-Bold.ttf" $GF/shipporimincho/ShipporiMincho-Bold.ttf
if [ ! -f "$FE/IPAexGothic.ttf" ]; then
  curl -sL -o /tmp/ipaex.zip https://moji.or.jp/wp-content/ipafont/IPAexfont/IPAexfont00401.zip
  (cd /tmp && unzip -o -q ipaex.zip && cp IPAexfont00401/ipaexg.ttf "$FE/IPAexGothic.ttf" && cp IPAexfont00401/ipaexm.ttf "$FE/IPAexMincho.ttf")
fi
ln -sf "$FE"/*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
fc-cache -f >/dev/null 2>&1 || true

echo "== バージョン確認 =="
tesseract --version | head -1
pandoc --version | head -1
qpdf --version | head -1
convert --version | head -1
"$HOME/workspace/tools/bin/yt-dlp" --version
"$HOME/workspace/tools/bin/duckdb" -c "select 'duckdb OK' as status;"
mkvmerge --version | head -1
"$HOME/workspace/tools/venv/bin/python" -c "import faster_whisper, moviepy, scenedetect; print('whisper/moviepy/scenedetect OK')"
echo "完了"
