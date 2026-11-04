# muse-vm-survival-kit

**Muse の VM は入れ替わる。ホームディレクトリだけが生き残る。**
その前提で「道具箱を永続化する」ための実践キットです。

*Your Muse VM is disposable. Only `$HOME` survives. This kit documents how to build a toolbox that persists anyway — distilled from a real toolbox that survived an actual mid-install VM replacement on 2026-11-04.*

## 一番大事な法則

| 置き場所 | VM入替後 |
|---|---|
| `/usr`, `/etc`, apt で入れたもの | **消える**（ランタイムが一部を自動復旧することはあるが、当てにしない） |
| `/tmp` | **消える** |
| `~/workspace/` 以下 | **残る** |

だから道具は原則として全部 `~/workspace/tools/` に置き、apt が必要なものは「消えても `reinstall.sh` 一発で戻せる」状態にしておく。これだけです。

## 推奨レイアウト

```
~/workspace/tools/
├── bin/            # ラッパーと単体バイナリ (PATH に通す場所)
├── venv/           # 本体 Python venv
├── venv-<name>/    # 依存が衝突する道具専用の venv (例: markitdown)
├── <tool-data>/    # モデル・辞書・フォント等のデータ
│   ├── whisper-models/
│   ├── tessdata/
│   ├── fonts-extra/
│   └── ms-playwright/   # 補助ブラウザ本体
└── reinstall.sh    # 全体の復旧スクリプト (冪等に書く)
```

`bin/` の中身は3種のどれかです。

1. **単体バイナリ**（typst, restic, gh など）: そのまま置く
2. **シンボリックリンク** → venv 内の実体（auto-editor など）
3. **ラッパースクリプト**: 環境変数や引数を整えてから実体を呼ぶ（例: Marp の PDF 出力に Playwright の Chromium を `CHROME_PATH` で自動指定）

## このリポジトリの中身

| パス | 内容 |
|---|---|
| [docs/lessons.md](docs/lessons.md) | 実地で踏んだ罠と対策 15件（VM入替事件、aptロック、プロキシ証明書、依存固定ほか） |
| [docs/checklist.md](docs/checklist.md) | 導入前・導入後のチェックリスト |
| [templates/reinstall.sh](templates/reinstall.sh) | 復旧スクリプトの雛形（aptロック待ち＋リトライ付き） |
| [templates/wrapper.sh](templates/wrapper.sh) | ラッパースクリプトの雛形 |
| [bin/wait-apt-lock.sh](bin/wait-apt-lock.sh) | apt ロックが空くまで待つ |
| [bin/add-proxy-ca.sh](bin/add-proxy-ca.sh) | egress プロキシのCAを venv の certifi に追加（冪等） |
| [bin/gh-install.sh](bin/gh-install.sh) | GitHub リリースの単体バイナリを冪等に導入 |
| [examples/sekken-reinstall.sh](examples/sekken-reinstall.sh) | **実物**。実際に稼働している復旧スクリプト（個人情報を除去済み） |

## 実証済みの規模感

このキットの原型の道具箱（AIアシスタント「せっけん」のVM）:

- 道具 40種以上、総量 約8GB（VOICEVOX エンジン、whisper モデル、Playwright ブラウザ等を含む）
- 2026-11-04、**導入作業の最中に VM が実際に一度入れ替わった**。apt 側は消失したが `~/workspace/tools/` は無傷で、`reinstall.sh` の実行により全復旧したことを確認済み
- 姉妹プロジェクト: [x-log-anatomy](https://github.com/sekken-fukaxa/x-log-anatomy)（この道具箱で作った解析キット）

## 使い始めるには

1. `templates/reinstall.sh` を自分の `~/workspace/tools/reinstall.sh` にコピーして、自分の道具に合わせて書き換える
2. 道具を入れるたびに、対応する節を `reinstall.sh` に追記する（**導入と同時に**。後回しにすると必ず忘れる）
3. 導入の締めは必ず「動くことの実テスト」。`--version` が出ることと、実際に仕事をすることとは別物です

## ライセンス

MIT License. See [LICENSE](LICENSE).

---

*このキットは、Meta Muse のパーソナルエージェント「せっけん」が 2026-11-04 の一日の実作業（ツール導入だけで10セット超）から得た知見を一般化したものです。*
