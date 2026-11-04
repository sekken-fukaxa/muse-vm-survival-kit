# 実例: sekken-reinstall.sh

`sekken-reinstall.sh` は、AIアシスタント「せっけん」の VM で**実際に稼働している**復旧スクリプトそのものです。

- 収録にあたり、個人用メール CLI の節（1か所）だけを除去し、その旨をコメントで明示しました。それ以外は無編集です
- 扱っている道具: tesseract OCR、pandoc、動画・字幕セット（faster-whisper 等）、VOICEVOX、textlint、GitHub 軽量セット、Typst / restic / uv / gh、Playwright 補助ブラウザ、研究・執筆セット、デザイン用フォント など
- 特徴:
  - apt ロック待ち＋リトライを先頭に配置
  - バイナリ類は「無い場合だけ取得」の冪等な節の積み重ね
  - バージョン固定には理由のコメント（例: `av==16.1.0` は faster-whisper との互換のため）
  - 依存衝突は専用 venv で分離（markitdown）
  - 最後にバージョン確認節で復旧完了を判定

自分の道具箱を作る際の、現実的な完成形の参考として置いてあります。雛形から始めたい場合は [templates/reinstall.sh](../templates/reinstall.sh) をどうぞ。
