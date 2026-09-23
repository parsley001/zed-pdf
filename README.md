# zed-pdf

Zed のタブの中で PDF を読むための小さなツール。

PDF の各ページを PNG に変換し、それを並べた Markdown を生成して Zed で開きます。
Zed の Markdown プレビューはローカル画像をレンダリングするので、結果として
**連続スクロールの PDF ビューアが Zed のタブとして成立します**。

```
zed-pdf paper.pdf     # → Zed にタブが開く → cmd-shift-v でプレビュー
```

---

## なぜこんな回り道をするのか

Zed には PDF ビューアがなく、**拡張機能で追加することもできません**。

拡張 API が提供できるのは以下の 6 種類だけで、UI やビューアを足す口が存在しないためです。

- Languages / Debuggers / Themes / Icon Themes / Snippets / MCP Servers

Zed のメンテナ自身がこう述べています（[discussion #47094](https://github.com/zed-industries/zed/discussions/47094)）:

> I've asked colleagues about having a PDF preview in core, and met no support —
> hence it has to be indeed, either **an extension (not possible now, alas)** or,
> maybe later, someone reconsiders.

ネイティブ実装の PR（[#63603](https://github.com/zed-industries/zed/pull/63603)）も
2026-09-02 にクローズされており、当面は本体にも入りません。

一方で Markdown プレビューの画像レンダリングは動きます。そこに乗るのが本ツールの方針です。

---

## 必要なもの

| 依存 | 用途 | 導入 |
|---|---|---|
| [poppler](https://poppler.freedesktop.org/) | `pdftoppm` による PDF→PNG 変換 | `brew install poppler` |
| Zed の CLI | `zed` コマンド | Zed メニュー → `Install CLI` |

macOS 前提です（`stat -f`、`shasum` を使用）。

## インストール

```sh
./install.sh
```

`bin/zed-pdf` を `~/.local/bin` にシンボリックリンクし、必要なら `~/.zshrc` に
PATH を追記します。実体はこのリポジトリ側に残るので、編集すればそのまま反映されます。

---

## 使い方

```sh
zed-pdf <file.pdf> [--dpi N]   # 変換して Zed で開く
zed-pdf --clean                # 変換キャッシュを全消去
zed-pdf --help
```

タブが開いたら **`cmd-shift-v`** でプレビューに切り替えます。

### DPI

既定は 144dpi。細かい文字や細線が潰れる場合は上げてください。

```sh
zed-pdf paper.pdf --dpi 220
export ZED_PDF_DPI=220          # 既定値を変える
```

DPI を変えるとキャッシュは自動で作り直されます。

### 動作確認

```sh
zed-pdf examples/sample.pdf
```

検証用の 5 ページ PDF が入っています。

| ページ | 内容 |
|---|---|
| p.1 | 表紙・ベタ塗り・見出し |
| p.2 | フラット塗り / グラデーション / 0.25pt〜2.0pt のヘアライン |
| p.3 | 6pt〜18pt の文字サイズ階段 |
| p.4 | ベクター棒グラフ |
| p.5 | 12 行の表・色分け・ヘアライン罫線 |

**p.3 の 6〜7pt が読めて、p.2 の 0.25pt の線が消えていなければ DPI は足りています。**

`examples/sample.ps` が生成元の PostScript です。作り直す場合:

```sh
ps2pdf -dPDFSETTINGS=/prepress examples/sample.ps examples/sample.pdf
```

---

## 任意の Zed 設定

`~/.config/zed/settings.json`:

```json
"markdown_preview": {
  "limit_content_width": false
}
```

ページ画像がペイン幅いっぱいに表示されます。

`"open_markdown_files_in_preview": true` を足せば `cmd-shift-v` も不要になりますが、
**全 Markdown ファイルに効く**ので、Markdown を書く機会が多いなら入れないほうが無難です。

---

## 仕組みと注意点

```
paper.pdf
   │  pdftoppm -png -r <dpi>
   ▼
~/.cache/zed-pdf/<sha256(abspath)[:12]>/
   ├── page-1.png …
   ├── paper.md       ← ページを並べた Markdown
   └── .stamp         ← "<mtime>-<dpi>" キャッシュキー
   │  zed
   ▼
Zed のタブ → cmd-shift-v
```

### 画像リンクは相対パスでなければならない

Zed の `resolve_preview_image`（`crates/markdown_preview/src/markdown_preview_view.rs`）は
**先頭が `/` のパスをワークスペース相対として先に解釈します**。
そのため絶対パスで書くと解決に失敗し、画像が表示されません。
生成する Markdown は `![p1](page-1.png)` の形にしてあります。

### キャッシュ

元 PDF の mtime と DPI が変わらなければ再変換しません。2 回目以降は即座に開きます。

```sh
du -sh ~/.cache/zed-pdf     # 使用量
zed-pdf --clean             # 全消去
```

`ZED_PDF_CACHE` で置き場所を変えられます。

### 制約

- **テキストは選択・コピーできません。**画像だからです。
  本文が必要なら `pdftotext -layout paper.pdf paper.txt` を併用してください。
- **PDF 内リンクは機能しません。**同じ理由です。
- **ページ内検索はできません。**Zed の検索は Markdown ソース（画像リンクのみ）に当たります。
- 大きな PDF・高 DPI ではキャッシュが数十 MB 規模になります。
- 元 PDF を開いたまま `--clean` すると、Zed 側のタブが「ファイルが消えた」状態になります。

フォーム記入・注釈・署名など編集が要る場合は、素直に Preview.app を使ってください。
Zed 側からは Markdown 冒頭の `open in the system viewer` リンクを cmd-click すると飛べます。

---

## おまけ: Zed から既定アプリで開く

PDF に限らず、プロジェクトパネルで選択中のファイルを既定アプリに渡せます。
`~/.config/zed/keymap.json`:

```json
{
  "context": "ProjectPanel",
  "bindings": { "cmd-alt-shift-o": "project_panel::OpenWithSystem" }
}
```

`cmd-alt-shift-o` は Zed の既定キーマップと衝突しないことを確認済みです。

---

## 構成

```
zed-pdf/
├── README.md
├── install.sh          ~/.local/bin へのリンクと PATH 設定
├── bin/zed-pdf         本体
└── examples/
    ├── sample.pdf      検証用 5 ページ PDF
    └── sample.ps       その生成元 PostScript
```

## 参考

- [Developing Extensions — Zed Docs](https://zed.dev/docs/extensions/developing-extensions)
- [Native PDF Preview using pure Rust (Hayro) · Discussion #47094](https://github.com/zed-industries/zed/discussions/47094)
- [feat(image_viewer): native continuous PDF viewer · PR #63603](https://github.com/zed-industries/zed/pull/63603)
