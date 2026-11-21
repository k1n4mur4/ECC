---
name: skill-host-compat
description: スキル PR を出す前に、ECC スキルのフロントマターが Codex/Cursor で安全か、また Claude 専用の置換が残っていないかを lint します。
origin: ECC
---

# スキルのホスト互換性

スキル PR を開く前に、CI が使うものと同じホスト互換性ゲートを `skills/` に対して実行します。
このチェックは Codex と Cursor 向けのコピーを対象としており、Claude 専用のランタイム品質を対象とするものではありません。

## 有効化するタイミング

- `skills/` 配下のスキルを追加または編集するとき
- スキルを `.agents/skills/` または `.cursor/skills/` にコピーするとき
- レビューで、スキルを Codex や Cursor にインストールしても安全かどうかを尋ねられたとき
- CI が `validate-skill-host-compat.js` の指摘を報告したとき

## コアコンセプト

正規のスキルは `skills/` にあります。Codex は `.agents/skills/` を読み込みます。Cursor はより小さな
`.cursor/skills/` のサブセットを読み込みます。CONTRIBUTING では、この同期は手動であると記載されています。

`validate-skills.js` が確認するのは、`SKILL.md` が存在することと、`name` /
`description` が使用可能な YAML であることだけです。`tests/ci/codex-skill-surface.test.js` が
見るのは `.agents/skills/` のみです。このスクリプトは、ツリー間をまたぐゲートです。

1. Codex/Cursor 向けプロジェクション（Codex/Cursor 向けに生成されたコピー）の実行可能な `bash` / `sh` / `zsh` フェンス内にある Claude 専用の置換
   （`${CLAUDE_SESSION_ID}`、`${CLAUDE_SKILL_DIR}`、`${CLAUDE_PLUGIN_ROOT}`、
   `${CLAUDE_PROJECT_DIR}`、`$ARGUMENTS`）は失敗になります。Codex はこれらのトークンを
   リテラルのテキストとして残します。Codex 向けコピーでは、`${CLAUDE_PROJECT_DIR}` を
   `$(pwd)` または明示的なパスに書き換えてください。
2. Codex 向けコピーで使用できるのは `name`、`description`、`metadata`、`license`、
   `allowed-tools` のみです。`origin: ECC` は正規の `skills/` コピーには残せますが、
   Codex 向けコピーでは削除する必要があります。
3. `agents/openai.yaml` に記載され、かつ `skills/` ディレクトリを持つスキルは、
   `.agents/skills/<name>/` を持つ必要があります。Cursor 向けコピーは任意ですが、存在する場合は
   `name:` がディレクトリ名と一致しなければなりません。
4. CONTRIBUTING のチェックリスト項目（When to Activate、Anti-Patterns、name が
   ディレクトリ名と一致すること、500/800 行の上限）は警告になります。失敗扱いになるのは
   `--strict-checklist` を指定した場合のみです。

`validate-skills.js` のフロントマターに関する WARN のデフォルトは変更されません（#1663）。

## コード例

リポジトリのルートから実行します。

```bash
node scripts/ci/validate-skill-host-compat.js
```

失敗させずに件数を出力します。

```bash
node scripts/ci/validate-skill-host-compat.js --inventory
```

チェックリストの警告を失敗に格上げします。

```bash
node scripts/ci/validate-skill-host-compat.js --strict-checklist
```

スラッシュコマンド:

```
/skill-host-compat
/skill-host-compat --inventory
```

## アンチパターン

Codex と Cursor のプロジェクションでは、実行可能ブロック内の Claude 専用の置換を解決しなければなりません。Claude スコープの正規の例は引き続き有効です。POSIX の `$1` と `${1}` パラメータは曖昧であり、このゲートで失敗にするのではなくレビューが必要です。
次のフェンスは禁止されているパターンです。

```bash
echo "${CLAUDE_SESSION_ID}"
ls "${CLAUDE_SKILL_DIR}"
node "${CLAUDE_PLUGIN_ROOT}/scripts/setup.js" $ARGUMENTS
cd "${CLAUDE_PROJECT_DIR}"
```

`.agents/skills/` 配下の Codex 向けコピーに `version:` や `origin:` を追加しないでください。
`validate-skills.js` が通ったことをもって Codex で安全だとみなさないでください。
`skills/` のすべてのエントリに Cursor 向けコピーを要求しないでください。

## ベストプラクティス

- CONTRIBUTING のテンプレートが求める場合は、正規コピーの `origin: ECC` を維持します。
- Codex 向けコピーでは `origin`、`version`、`argument-hint` を削除します。
- bash フェンスには、ホストに依存しないコマンド（`npx`、`ecc`、または解決済みのルート）を示します。
  Codex 向けコピーでは `${CLAUDE_PROJECT_DIR}` を `$(pwd)` または明示的なパスに書き換えます。
  正規の手順には有効な Claude スコープの形式を残し、ホスト変数は、配布先の Codex/Cursor 向けコピー側で解決します。
- 変更が新しいスキルである場合は、`npm test` の前にこのスクリプトを実行します。
- ツリーを失敗させずにチェックリスト警告の量を確認するには、`--inventory` を使います。

## 関連スキル

- `skill-comply` — ランタイムの振る舞いトレースであり、ホスト移植性は対象外
- `skill-stocktake` — インストール済みの `~/.claude/skills` の総合的な監査
- `skill-scout` — 新しいスキルを作成する前に既存のスキルを検索
