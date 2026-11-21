---
name: codehealth-mcp
description: CodeScene MCP によるリアルタイムの構造的 Code Health。編集前にレビューし、変更後にスコアの差分を検証し、コミットと PR をゲートします。コード品質のレビュー、リファクタリング、AI による変更でファイルが劣化していないかの確認、コミットや PR の前に使用します。
metadata:
  origin: community
---

# Code Health MCP (CodeScene)

AI 支援コーディングのための、構造的な保守性フィードバックです。スタイル/lint 系のスキル（`coding-standards`、`plankton-code-quality`）を補完し、**設計レベル**の健全性スコアとリグレッションゲートを提供します。

**上流:** [codescene-oss/codescene-mcp-server](https://github.com/codescene-oss/codescene-mcp-server)
**パッケージ:** `@codescene/codehealth-mcp`（npx 経由の stdio）

## セキュリティと境界

**オプトイン（ECC）:** `mcp-configs/mcp-servers.json` の `codescene` ブロックはテンプレートにすぎません。ECC プラグインのインストールでは、同梱の MCP サーバーは自動的に有効化されません。必要な場合にのみ、そのエントリを自分の設定にコピーしてください。ECC のインストール/同期時に `ECC_DISABLED_MCPS=codescene,...` で除外することもできます。

**認証情報:** トークンは同梱されていません。`CS_ACCESS_TOKEN` は自分で設定してください（上流リポジトリの [getting-a-personal-access-token.md](https://github.com/codescene-oss/codescene-mcp-server/blob/main/docs/getting-a-personal-access-token.md) を参照）。トークンをリポジトリにコミットしてはいけません。

**ツールが読み取る対象:** 呼び出されると、ツールは指定したローカルリポジトリ内のファイルと git の状態を分析します（渡したパスに加え、`analyze_change_set` ではブランチのコンテキスト）。ツールが自動で実行されることはありません。スタンドアロンモードについては、上流のプライバシードキュメントを参照してください: [codescene-mcp-server README](https://github.com/codescene-oss/codescene-mcp-server#frequently-asked-questions) と [CodeScene policies](https://codescene.com/policies)。シークレット、認証情報、分析対象にしたくないパスには、このスキルを使用しないでください。

**MCP が利用できない場合（オフライン、トークン不正、サーバークラッシュ）:** Code Health スコアを捏造してはいけません。チェックをスキップしたことをユーザーに伝えてください。続行するのは、ユーザーの明示的な承認がある場合のみです。MCP が停止している間は、ゲートとして lint/テスト/verification-loop を優先してください。サーバーが接続できたら、チェックを再開します。

## 使用タイミング

- ユーザーが**コード品質のレビュー**、ファイルの**リファクタリング**、または **AI の変更による保守性の劣化**の確認を求めたとき
- **ホットスポット**、レガシーモジュール、または不慣れなファイルを編集する前
- 保守性のセーフガードが必要な **コミット**や**プルリクエスト**の前
- エージェントが書いた大きな diff の後 — Code Health が後退していないことを検証する
- 構造的なチェックとして `verification-loop`、`tdd-workflow`、`/quality-gate` と組み合わせる（テスト/lint の代替ではありません）

## 有効化するタイミング

上記の**使用タイミング**と同じトリガーです — この見出しは、ECC がスキルを自動有効化するために使用します。

## 仕組み

### 1. MCP サーバーを接続する

`mcp-configs/mcp-servers.json` の `codescene` エントリを、使用しているハーネスの MCP 設定にコピーします。

**Claude Code**（`~/.claude.json` → `mcpServers`）:

```json
"codescene": {
  "command": "npx",
  "args": ["-y", "@codescene/codehealth-mcp"],
  "env": {
    "CS_ACCESS_TOKEN": "YOUR_CS_ACCESS_TOKEN_HERE"
  }
}
```

**プロジェクトスコープ:** 同じブロックをリポジトリルートの `.mcp.json` にマージします。

トークンの設定方法は上流リポジトリ（上記リンク）に記載されています。スタンドアロンモードでは、以下の 4 つのツールに対して有料の CodeScene プラットフォームアカウントは不要です。スコアに頼る前に、セッションを再起動し、`codescene` サーバーが接続されていることを確認してください。

### 2. スタンドアロンツールのみを呼び出す

| ツール | 使用タイミング |
|------|-------------|
| `code_health_review` | ファイルを変更する**前**の完全な構造分析 |
| `code_health_score` | 各変更後の簡易な数値スコア（差分チェック） |
| `pre_commit_code_health_safeguard` | Code Health のリグレッションを持ち込むコミットをブロックする |
| `analyze_change_set` | PR を開く**前**のブランチレベルのチェック |

プラットフォーム専用のツール（例: リポジトリ全体の技術的負債ホットスポット一覧）は呼び出さ**ない**でください。`delta_analysis` は参照**しない**でください — スタンドアロンでは利用できません。

### 3. スコアを解釈する（1〜10）

| 範囲 | 意味 | エージェントの振る舞い |
|-------|---------|----------------|
| **9.0–10.0** | グリーン — 健全 | 拡張しても比較的安全。ただし垂直スライスを優先する |
| **4.0–8.9** | イエロー — 負債あり | 慎重に進める。ついでのリファクタリングはしない |
| **1.0–3.9** | レッド — 深刻な負債 | 範囲を絞った変更のみ |

### 4. フィードバックループを回す

**ファイルに触れる前**

1. 対象パスに対して `code_health_review` を実行する。
2. ベースラインのスコアと、列挙されたコードスメルを記録する。
3. タスクに対応する最小の変更を計画する。

スコアに応じた範囲: **5 未満** — 最小限の diff のみ。**5〜7** — 広範なリファクタリングは行わない。**7 超** — リファクタリングしやすいが、各編集後に検証する。

**各変更の後**

1. 同じファイルに対して `code_health_score` を実行する。
2. `code_health_review` で得たベースラインと比較する。
3. スコアが**後退**した場合は、続行する前に修正する。開始時よりスコアが低いままタスクを完了としてはいけない。

**コミットのたびに** — リポジトリパスに対して `pre_commit_code_health_safeguard` を実行する。

**PR の前に** — ベースブランチ（例: `main`）に対して `analyze_change_set` を実行する。

## 例

### 例: Flask の保守性改善

`pallets/flask` で、スタンドアロンツールのみを使ったエージェントループです。

1. 対象モジュールに対して `code_health_review`（ベースライン **4.82**）
2. 列挙されたスメルに対処する的を絞ったリファクタリング
3. 各編集後に `code_health_score`
4. コミット前に `pre_commit_code_health_safeguard`
5. PR 前に `analyze_change_set`

結果: Code Health が **4.82 → 9.1**（無料のスタンドアロントークンのみ）。

### 例: AGENTS.md 強制ブロック

プロジェクトの `AGENTS.md` または `CLAUDE.md` に貼り付けます。

```md
## Code Health (CodeScene MCP)

Before modifying any file: run `code_health_review`, note score and issues.

- Score below 5: problematic range — scope changes narrowly.
- Score 5–7: warning range — no broad refactors.

After each change: run `code_health_score` to verify delta.

- If score regressed: fix before continuing; never declare done if score dropped.

Before every commit: run `pre_commit_code_health_safeguard`.

Before PR: run `analyze_change_set`.
```

### 例: アンチパターンと正しいループ

```markdown
# BAD: Edit first, check later
[large refactor without code_health_review]

# BAD: Ignore score drop
"Tests pass" → mark task done while Code Health decreased

# BAD: Broad refactor on red-score file (below 5)
Drive-by cleanup across the module

# GOOD: review → small change → score → commit safeguard → analyze_change_set
```

## ECC との組み合わせ

| ECC のスキル / フロー | Code Health MCP の役割 |
|------------------|----------------------|
| `coding-standards` | スタイル/命名。Code Health = 構造/複雑性 |
| `plankton-code-quality` | 書き込み時の lint/format。Code Health = 編集前後の構造ゲート |
| `verification-loop` / `/quality-gate` | 「完了」の前に構造的なリグレッションチェックを追加する |
| `security-review` | セキュリティと保守性 — 関連する場合は両方を使用する |
| `tdd-workflow` | テスト合格 ≠ 健全な設計 — リファクタリング後にスコアを確認する |

**コンテキストのヒント:** ECC は MCP の数を少なく保つことを推奨しています。本格的な編集を行うときは `codescene` を有効にし、不要なときは無効にしてください。

## 関連スキル

- `coding-standards` — ベースラインの規約
- `plankton-code-quality` — 書き込み時の lint/format フック
- `verification-loop` — ビルド/テスト/lint ゲート
- `tdd-workflow` — テストファースト開発
- `security-review` — セキュリティチェックリスト
- `documentation-lookup` — Context7 によるライブラリドキュメント（本スキルとは独立）
