---
name: deepseek-harness-setup
description: "DeepSeek Harness（DSH）に Everything Claude Code（ECC）をインストールして運用します。ネイティブなスキルルート（~/.dsh/skills、.agents/skills）、コマンドフック用の @deepseek-ai/dsh-hooks-claude-code ブリッジ、bare insert によるパッチのマウント、ジェネレーターの使い方、イベントサポートの制限、更新ワークフローを扱います。DeepSeek Harness に ECC をセットアップするとき、ECC フックを DSH プロファイルに組み込むとき、DSH セッションに ECC のスキルやフックが表示されない原因をデバッグするときに使用します。"
metadata:
  origin: community
---

# DeepSeek Harness セットアップ

DeepSeek Harness 上で ECC を実行します。完全なガイド: `docs/DEEPSEEK-HARNESS-GUIDE.md`。

## 使用タイミング

- DeepSeek Harness のインストールに ECC のスキルやフックを導入するとき。
- ECC のどの機能が DSH で動作し、どれが動作しないかを判断するとき。
- ECC のスキルが表示されない、または ECC のフックが発火しない DSH セッションをデバッグするとき。

## 仕組み

1. **スキルは変換不要です。** DSH はネイティブなスキルルートから `SKILL.md` のフロントマター
   （name/description）を読み取ります。ECC カタログを一度リンクします。

   ```bash
   ln -s /path/to/ECC/skills/<skill-name> ~/.dsh/skills/<skill-name>
   ```

   ルートの優先順位（プロジェクトの `.dsh` および `.agents` ルートが `~/.dsh` より優先されます）:
   より優先度の高いルートに同名のスキルが既に存在する場合は、リンクをスキップしてください。
   プレースホルダーは実際のスキル名に置き換えてください。山括弧はシェルの構文ではありません。

2. **フックはファーストパーティのブリッジを経由します。** 正規の ECC フックファイルから
   DSH 形式の設定を生成します。

   ```bash
   node scripts/dsh/generate-hooks-config.js --ecc-root /path/to/ECC --out ~/.dsh/ecc/hooks-dsh.json
   ```

   ジェネレーターはツール名のマッチャーを小文字化し、`CLAUDE_PLUGIN_ROOT`/`ECC_PLUGIN_ROOT`
   をインラインで前置し（ブリッジはプラグインルートをエクスポートしないため）、タイムアウトを保持し、
   DSH がブリッジできないイベント（`PreCompact`、`PostToolUseFailure`、`SessionEnd`）をスキップします。

3. **bare insert でマウントします。** `~/.dsh/profiles/<profile>/cordis.patch.yml` に記述します。

   ```yaml
   - insert:
       - id: ecc-hooks-claude-code
         name: "@deepseek-ai/dsh-hooks-claude-code"
         config:
           configPath: /absolute/path/to/hooks-dsh.json
   ```

   デバッグで苦労しやすい、経験して初めて分かるローダーのルールは次のとおりです。
   単独の `- id:` トップレベルエントリは黙って破棄されます。
   既存の非グループ id の配下への `insert` は「not a group」として拒否されます。
   ファーストパーティのプラグインパッケージはプロファイルの `package.json` へのエントリが不要です。

4. **compose で検証し、その後ライブで確認します。**

   ```bash
   cd ~/.dsh && dsh --profile web --dump-config > /tmp/dump.yml
   grep ecc-hooks /tmp/dump.yml
   ```

   ローダーがエントリを破棄または拒否しても、compose の終了ステータスは 0 のままです。
   これらの問題は stderr にのみ報告されます。エントリ id がダンプに現れ、stderr が空であることを
   確認してください。セッション最初の edit/write/bash で GateGuard による拒否がライブで発生すれば、
   ブリッジが有効になっていることを示す目に見えるシグナルです。

## 更新

`git pull` はリンクされたスキルに即座に反映されます。フック設定は同じジェネレーターコマンドで再生成してください。
ECC のチェックアウトを移動した場合は、再生成し（パスはすべてのフックコマンドに埋め込まれています）、スキルを再リンクしてください。

## 制限

| 機能 | DSH での状況 |
|---------|---------------|
| スキル | ネイティブに検出されます。ワークフローはホスト（DSH）に合わせた調整が必要な場合があります |
| フック | 7 つのブリッジイベントのうち 5 つで 23 個のコマンドフック |
| スラッシュコマンド | 利用不可（Claude Code の仕組みのため）。ワークフローはスキルでカバーされます |
| エージェント | ネイティブなディスパッチは未検証です。レビュー後にのみ正規のプロンプトガイダンスを使用してください |

ここで検証済みのセットアップは CLI/web プロファイルを対象としています。デスクトッププロファイルは、
インストール側が所有する別のランタイムを持つため、スキルの検出はそちらで別途検証する必要があります。
フックはレビュー済みの ECC チェックアウトからのみ生成してください。リンクされたチェックアウトがそれらのランタイムを提供します。
