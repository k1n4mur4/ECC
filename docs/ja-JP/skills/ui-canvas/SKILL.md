---
name: ui-canvas
description: UI コンポーネントのモックアップをローカルブラウザのキャンバスでプレビューし、人間が直接編集（移動、リサイズ、テキスト編集、削除、スタイル変更）したり、モバイル／デスクトップ／カスタムのビューポートを切り替えたり、動作をテストしたり、あなたとチャットしたり、Save and Finish をクリックしたりできるようにします。その後、エクスポートされた編集済みマークアップを本番用コンポーネントに仕上げます。見た目の変更を確認するためだけに、機能をコミットしたり再ビルドしたりする前に使用します。
metadata:
  origin: ECC
version: "1.0.0"
---

# UI Canvas

ユーザーインターフェース作業のための「承認してから作る」ループです。あなたがコンポーネントの簡易的で自己完結した HTML モックアップを書き、人間がそれをブラウザで開いてウェブサイトビルダーのように手で調整し、**Save and Finish** を押すと、実際のコードに反映すべき正確な結果があなたに渡されます。パディングを少し変えるだけのために、アプリ全体を再ビルドして再実行する必要はありません。

どんなコンポーネントでも対象になります。カード、サイドバー、モーダル、設定ペイン、単一のボタン状態、アニメーション、ページセクションなどです。どのハーネスでも使えます。ループは JSON を出力する CLI だからです。

サーバー、状態、フックは `plan-canvas` と共有しています（[lavish-axi](https://github.com/kunchenguid/lavish-axi)（@kunchenguid）に着想を得ています）。編集の規約は [VisBug](https://github.com/GoogleChromeLabs/ProjectVisBug) と [Onlook](https://github.com/onlook-dev/onlook) に倣っています。Enter/Shift+Enter でツリーを移動し、Delete で削除し、編集／インタラクトのモードを切り替えます。

## 使用するタイミング

- ユーザーが UI コンポーネントのリデザイン、リスタイル、または追加を求めていて、コミット、再実行、再ビルドの前にそれを見たいとき。
- フィードバックが視覚的なもの（「もっと詰めて」「それを上に移動して」「枠線を消して」）で、文字で伝えるより手で直すほうが速いとき。
- モバイルとデスクトップの両方が重要で、ユーザーがコンポーネントを正確なサイズで確認したいとき。
- ユーザーが `/ui-canvas`、プレビュー、モックアップ、「先に見せて」を求めたとき。

次の場合は使用しないでください。計画やドキュメントのレビュー（`/plan-canvas`）、実際のアプリの実行、リモート URL、1 ファイルのプレーンな HTML/CSS/JS としてレンダリングできないコンポーネント。キャンバスが配信するのはローカルファイルのみです。

## 仕組み

CLI は `ecc-ui-canvas` として呼び出します（`ecc-universal` パッケージの bin で、グローバルインストールまたはプラグインインストール後に PATH に入ります。`node "$CLAUDE_PLUGIN_ROOT/scripts/ui-canvas.js"` でも動作します）。`plan-canvas` と同じ、切り離されたループバック専用サーバー（`127.0.0.1:4517`）を実行し、アーティファクトのパスをキーとします。セッション ID はありません。

### 1. モックアップを書く

自己完結した `.html` ファイルを 1 つ書きます（例: `.claude/previews/<name>.html`、またはコンポーネントの隣）。マークアップ、`<style>` ブロック、およびコンポーネントの動作に必要な `<script>`（タブ、トグル、開閉、アニメーション）を含めます。ルールは次のとおりです。

- プロジェクトの実際のブランドトークン、フォント、コピー、現実的なデータを使います。既存の CSS またはテーマファイルを先に読み、パレットを勝手に作らないでください。
- 意味のある要素には `id` または特徴的なクラスを付けます。キャンバスは人間のすべての編集を CSS セレクターに対して記録します。安定した名前があれば、エクスポートがあなたのコードにきれいに対応づけられます。
- 本番に忠実に保ちます。同じブレークポイント、同じ `max-width`、同じ状態を使います。キャンバスは CSS ピクセル単位の実寸のビューポートサイズでレンダリングするため、メディアクエリはアプリ内とまったく同じように動作します。
- 兄弟アセット（画像、フォント）はファイルの隣に置いて相対パスで参照できます。`data:` URI やインライン SVG も使えます。
- コンポーネントに必要なものだけをインラインにします。モックアップはスケッチであり、アプリではありません。

### 2. 開いて待ち受ける

```bash
ecc-ui-canvas open .claude/previews/pricing-card.html --viewport desktop --title "Pricing card"
ecc-ui-canvas await .claude/previews/pricing-card.html   # バックグラウンドで実行し、実行したままにする
```

`--viewport` には `mobile`（393×852）、`desktop`（ウィンドウいっぱい）、`custom`、または `1024x768` のような正確な `WxH` を指定できます。ハーネスがフォアグラウンドコマンドに時間制限を設けている場合は、`await` をバックグラウンドで実行してください。中断された場合は再実行します。キューに入ったフィードバックが失われることはありません。実行中は、キャンバスに「<your harness> listening」と表示され、人間はあなたが接続していることがわかります。

### 3. 返ってきた内容を処理する

人間が操作すると、`await` が JSON を出力します。項目は次のとおりです。

```json
{ "kind": "chat", "text": "change this to dark gray in the brand colors",
  "anchor": { "selector": "#pricing-card", "tag": "article", "snippet": "Most popular Team plan…", "size": { "width": 720, "height": 388 } },
  "pendingEdits": ["resized img.art to 220px wide, 220px tall (was 260×260)", "removed button.btn.secondary"] }
```

- `chat` は依頼です。`anchor` は人間が送信時に選択していた要素で、`pendingEdits` は人間が行った、**まだあなたのファイルに入っていない**手編集の要約です。依頼された変更をモックアップファイルに加えてください。プレビューは 1 秒以内に再読み込みされ、保留中の編集がその上に再適用されるため、`pendingEdits` を自分でファイルに反映**しないでください**。これらはコンテキストであり、二重に適用すると配置がずれます。キャンバス上で返答し、次の 1 コマンドで待ち受けを続けます。

  ```bash
  ecc-ui-canvas await <file> --reply "Background is now var(--gray-800) from the brand tokens."
  ```

  ここでは速度が重要です。作業を始めたらすぐに `ecc-ui-canvas typing <file> --state thinking` を実行し、ファイルを編集してから返信してください。1 つのプロパティの変更であれば、依頼から再描画まで 2 秒未満が目標です。

```json
{ "id": "fb-123", "kind": "edits", "editCount": 3, "edits": [ { "kind": "resize", "selector": "img.art", "width": 220, "height": 220, "before": { "width": 260, "height": 260 } } ],
  "viewport": { "preset": "mobile", "width": 393, "height": 852 },
  "exportPath": "/abs/.claude/previews/pricing-card.apply-mf3k2x-9a1c.edited.html", "editsPath": "/abs/.claude/previews/pricing-card.apply-mf3k2x-9a1c.edits.json" }
```

- `edits` は、人間が **Apply to file** をクリックしたことを意味します。手編集を今すぐモックアップに書き込んでほしいという意思表示です。モックアップファイルを `exportPath` の内容で置き換えてください（人間が見ている DOM 全体で、インラインスタイルの変更を含みます）。乱雑なら整理して本物の CSS にし、自己完結を保ち、返信します。各 Apply は独自の `<name>.apply-<batch>.*` ペアを書き出すため、キューに入った以前のバッチは自身のスナップショットを保持します。キャンバスは、エクスポートされた正確なスナップショットを認識するか、取り込み済みのバッチをあなたが明示的に受領通知（acknowledge）するまで、送信済みの編集を表示し続けます。バッチを取り込んだら、そのフィードバック ID を `ecc-ui-canvas await <file> --ack fb-123 --reply "Applied the requested changes."` で受領通知してください。複数の ID はカンマ区切りで指定できます。以前の chat に答えている間は、キュー内のバッチを受領通知しないでください。エクスポートされたスナップショットの完全なコピーは自動的に認識されます。無関係なファイル保存は受領通知にはなりません。送信済みのバッチがファイルと一致しなくなった場合は、さらに変更を適用する前に解決してください。

```json
{ "kind": "finish", "editCount": 5, "edits": [ "…" ], "viewport": { "preset": "desktop", "width": 1412, "height": 806 },
  "exportPath": "…/pricing-card.edited.html", "editsPath": "…/pricing-card.edits.json" }
```

- `finish` は、人間が **Save and Finish** をクリックしたことを意味します。セッションは終了です（`sessionEnded: true`）。`exportPath` を読み、元のモックアップと差分を取り、`editsPath` を読んで各変更の意図を把握し、まったく同じ見た目を、完全な機能を備えた実際のコンポーネントで再現してください。実際のトークン、レスポンシブルール、アクセシブルなマークアップ、プロジェクトのフレームワークを使います。その後、リポジトリのルールに従ってコミットし、チャットで報告します。キャンバスを再度開かないでください。

`edits` に現れる編集の種類は次のとおりです。`text`（before/after、およびインラインマークアップが保持された場合は `htmlAfter`）、`resize`（border-box の px）、`move`（親セレクターとインデックスの from/to）、`nudge`（人間が Alt を押しながらのドラッグまたは矢印キーで適用した dx/dy の px オフセット。`position: relative` ではなく margin または配置に変換してください）、`remove`、`style`（`property`、計算済みの `before`、`after`。`after: null` はプロパティが削除されたことを意味し、border → none、box-shadow → none、padding → 0 とします）。`stale: true` が付いた編集は、あなたによる再読み込みの後に再適用できなかったものです。推測せず、ユーザーに尋ねてください。

### 4. 終了

`ecc-ui-canvas end <file>` は、あなたが開いたセッションのうち、もう不要になったものを閉じます。`{"status":"ended","endedBy":"user"}` は、人間が保存せずに閉じたことを意味します。ポーリングを止め、求められない限り再度開かないでください（`open --reopen`）。

## 人間にできること

編集モード（デフォルト）: クリックで選択でき、ホバーと選択のアウトラインとサイズバッジが表示されます。ダブルクリックでテキストを編集します。コーナーとエッジのハンドルでリサイズします（画像は Shift を押さない限り比率を保持します）。ドラッグすると、挿入マーカーとともに兄弟間または別のコンテナへ並べ替えます。Alt+ドラッグまたは矢印キーでナッジします（Shift で 10 px）。Delete または Backspace で削除します。Enter で最初の子へ、Shift+Enter で親へ、Tab で兄弟間を移動します。Cmd/Ctrl+Z と Shift+Cmd/Ctrl+Z でアンドゥとリドゥを行います。インスペクターには、選択した要素のパンくずリストと、グループ化されたスライダー行（サイズ、塗り、テキスト、スペーシング、ボーダー、エフェクト）が表示されます。スライダーをドラッグするか、値をダブルクリックして入力します（サニタイズされ、範囲内に収められ、矢印キーで増減します）。カラースウォッチをクリックすると、色相、彩度、明度、アルファのスライダーが開きます。16 進数フィールドは rgb() や色名も受け付けます。x ボタンでプロパティを解除します。

インタラクトモード（Cmd/Ctrl+I）: クリック、ホバー、キーボード操作がコンポーネントに届くため、タブ、トグル、アニメーションを実際のユーザーとまったく同じように試せます。一時停止ボタンで、アニメーションとトランジションを止めて確認できます。

ビューポートバー: デスクトップ（ステージいっぱい）、モバイル（デバイスフレーム付きの iPhone クラス 393×852）、または正確な幅×高さを選べます。回転ボタンで両者を入れ替えます。プレビューは、ステージが選択したサイズより小さい場合にのみ縮小され、拡大されることはないため、メディアクエリは正確に動作します。

## ルール

- コンポーネントごとに自己完結した `.html` ファイルを 1 つ用意します。Markdown は受け付けません。ドキュメントには `plan-canvas` を使ってください。
- 修正するにはアーティファクトファイルを編集します。キャンバスは保存時にライブリロードし、人間の保留中の編集、選択、スクロールを復元します。更新のために `open` を再実行しないでください。
- `chat` 項目の `pendingEdits` をファイルに適用しないでください。編集は、`edits` または `finish` のペイロードの `exportPath` からのみ適用します。
- セッションが開いている間は、ターミナルだけでなく、キャンバス上（`await --reply`）で返答してください。
- エクスポートされた `.edited.html` と `.edits.json` ファイル（Apply ごとの `.apply-<batch>.*` ペアを含む）はレビュー用のアーティファクトであり、本番コードではありません。リポジトリがプレビューを保持している場合を除き、コミットしないでください。モックアップを更新したら、`.apply-*` ペアを削除してください。
- サーバーはループバック専用で、30 分後にアイドルタイムアウトし（`ECC_PLAN_CANVAS_IDLE_MS`）、状態を `~/.claude/plan-canvas/`（`ECC_PLAN_CANVAS_STATE_DIR`）に保持します。`ECC_CANVAS_AGENT` は、ブラウザに表示される検出済みハーネス名を上書きします。

## 例

**コミット前のプレビュー付きリデザイン**

```bash
# user: "Make the pricing card friendlier, then show me before you commit."
# → write .claude/previews/pricing-card.html using tokens from src/styles/tokens.css
ecc-ui-canvas open .claude/previews/pricing-card.html --title "Pricing card"
ecc-ui-canvas await .claude/previews/pricing-card.html
# → {"status":"feedback","items":[{"kind":"chat","text":"change this to dark gray in the brand colors","anchor":{"selector":"#pricing-card",…},"pendingEdits":[…]}]}
ecc-ui-canvas typing .claude/previews/pricing-card.html --state thinking
# → edit the file: background: var(--gray-800)
ecc-ui-canvas await .claude/previews/pricing-card.html --reply "Card background is now --gray-800."
# → {"status":"feedback","sessionEnded":true,"items":[{"kind":"finish","editCount":5,"exportPath":"…/pricing-card.edited.html",…}]}
# → read the export, port the look into src/components/PricingCard.tsx, commit
```

**既存コンポーネントのモバイル確認**

```bash
ecc-ui-canvas open .claude/previews/sidebar.html --viewport mobile
ecc-ui-canvas await .claude/previews/sidebar.html
```

## アンチパターン

- 実際のアプリの URL を開くこと。キャンバスが配信するのは 1 つのローカルファイルです。代わりにコンポーネントをモックしてください。
- フレームワークのビルドステップでモックアップを作ること。プレーンな HTML はミリ秒でレンダリングされ、1 秒未満で再読み込みされます。それが要点です。
- `pendingEdits` を自分で再適用し、その後キャンバスがそれをもう一度適用するのを眺めること。
- `--timeout-ms` を使ってループでポーリングすること。素の `await` を実行したままにしてください。
- `chat` リクエストを放置すること。人間はプレビューを見ています。`typing --state thinking` で合図して、すぐに動いてください。
- `*.edited.html` や `*.edits.json` をコミットすること。
