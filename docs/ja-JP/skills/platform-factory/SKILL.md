---
name: platform-factory
description: Platform Factory（pf）CLI を使って、コンパイル済み実行ファイルから決定論的な OCI イメージ、SBOM/来歴（provenance）の証跡、堅牢化されたコンテナまたは microVM 実行を構築し、その freeze ロックを付属の Claude Code フックと同期させ続けます。プロジェクトに .platform-factory/ が存在する場合、ユーザーが pf/platform-factory（detect、plan、freeze、build、verify、run、launch）を実行または質問した場合、あるいは Docker デーモンなしで再現可能な OCI ビルドを求める場合に使用します。
metadata:
  origin: community
---

# Platform Factory

[Platform Factory](https://github.com/CYPT71/platform-factory)（`platform-factory`、エイリアス `pf`）は、コンパイル済み実行ファイルを決定論的な OCI イメージに変換し、ネイティブなサプライチェーン証跡（SBOM、来歴、署名、ポリシー）を付与し、その結果を堅牢化されたコンテナまたは KVM/HVF microVM として実行する、単一の Go バイナリです。コアのパスでは Docker デーモン、BuildKit、syft、cosign は不要です。既存のスタックに組み込んで使うものであり、Kubernetes、CI オーケストレーター、レジストリを置き換えるものではありません。

完全なリファレンス: プロジェクトの [CLI ガイド](https://github.com/CYPT71/platform-factory/blob/main/docs/cli-guide.md)。このスキルでは、エージェントが従うべきワークフローと、それを保護するガードフックを扱います。

## 有効化するタイミング

- リポジトリに `.platform-factory/` ディレクトリまたは `freeze.lock.json` がある。
- ユーザーが `pf` / `platform-factory` コマンドを実行している、またはそれについて質問している。
- タスクが、再現可能な OCI イメージのビルド、SBOM/来歴の証跡、またはレガシーや動的リンクのバイナリの microVM 実行である。
- Platform Factory プロジェクトで依存関係マニフェスト（`package-lock.json`、`go.sum`、`requirements.txt`、`Cargo.lock`、`pom.xml` など）を編集する。

## コアワークフロー

```bash
pf detect ./my-app        # ネイティブ実行ファイルの検査。JSON 出力
# ディレクトリ検出では、ロード済みの言語プラグインの検査コマンドが実行されます。
pf init --language node .    # pf.yaml を作成（言語プラグインのロードが必要: pf plugin load node）
pf plan                   # プロジェクトプラン (platform-factory.dev/project-plan/v1)
pf project freeze         # 依存関係を固定 -> .platform-factory/freeze.lock.json
pf build                  # 決定論的な OCI イメージ
pf verify .platform-factory/image   # 厳格なリリースゲート: ダイジェスト、diff_ids、プラットフォーム
pf run --runtime podman .platform-factory/image
pf diff                   # ビルドを比較
```

`pf launch --publish --yes` は、必要に応じて freeze を行い、ビルドし、検証し、**レジストリに公開してからワークロードを起動する**までを 1 ステップで行うため、外部へ公開する操作です（ルール 7 を参照）。`pf sbom PATH...` は、pf 単体で（外部ツールなしで）再現可能な SBOM を生成します。

### 重要なルール

1. **ビルドの前に freeze する。** 依存関係マニフェストを変更すると、`.platform-factory/freeze.lock.json` は古くなります。`pf project freeze` を実行してから `pf build` を実行してください。
2. **`pf verify` をゲートとして扱う。** `verify` が通るまでビルドは完了ではありません。
3. **ディレクトリ検出の前にプラグインを検査する。** ネイティブ実行ファイルの分類は対象を実行しませんが、ディレクトリ検出はロード済みの言語プラグインを呼び出します。`detect`、`plan`、`freeze`、`build` の前に、それらのプラグインとプロジェクトのコマンドを実行可能な設定としてレビューしてください。
4. **曖昧さはエラー。** ディレクトリが複数のエコシステムに一致する場合、`pf detect` は終了コード 2 で終了します。`--accept-ambiguous` は、ユーザーがその選択を確認した場合にのみ指定してください。
5. **ビルド入力に秘密情報を追加しない。** 入力はイメージとその証跡に含まれます。
6. **コールバックはオプトイン。** `pf` のフック（CLI/MCP コールバック）は、`PLATFORM_FACTORY_HOOKS_CONFIG` が明示的な絶対パスのファイルを指している場合にのみ実行されるため、クローンしたリポジトリが実行ファイルを有効化することはできません。
7. **実行はユーザーの認可の範囲内に収める。** 公開、デプロイ、起動、ワークロードの実行の前に、その対象、イメージ参照、影響を特定してください。その範囲についてすでに明示的な認可が与えられている場合はそれを再利用し、アクションがその範囲を超える場合にのみ確認します。認可された変更を行う前に、利用可能であれば `--dry-run` を使用してください。ユーザーが与えていない承認を回避するために `--yes` を追加してはいけません。

## 付属の Claude Code フック: freeze ガード

このプロジェクトは、ECC 自身のフックと並んで動作する Claude Code プラグイン [`platform-factory-guard`](https://github.com/CYPT71/platform-factory/tree/main/integrations/claude-code) を提供しています。

| イベント | トリガー | 動作 |
|-------|---------|----------|
| `PostToolUse` | 依存関係マニフェストに対する `Edit`/`Write`/`MultiEdit` | `pf project freeze` の実行を促します |
| `PreToolUse` | `pf build\|publish\|launch\|deploy` を実行する `Bash` | マニフェストが freeze ロックより新しい場合に警告し、`PF_GUARD_STRICT=1` の場合は拒否します |

このフックは `pf` を実行しません。`.platform-factory/` に加えて `pf.yaml` などのプロジェクト設定も認識し、ユーザーごとのプラグインディレクトリはプロジェクトマーカーとして無視します。エラー時は処理を止めず通過させる（フェイルオープン）設計です。`PF_GUARD=off` で無効化できます。

プラグインとしてインストールします（Node.js 18 以上が必要）:

```text
/plugin marketplace add CYPT71/platform-factory
/plugin install platform-factory-guard@platform-factory
```

## アンチパターン

```bash
# BAD: 依存関係を変更した直後にビルドする
npm install left-pad && pf build

# GOOD: 先にロックを更新する
npm install left-pad && pf project freeze && pf build && pf verify .platform-factory/image
```

- `pf verify` を省略してイメージを出荷する。
- 意図されたエコシステムを確認せずに、終了コード 2 を黙らせるために `--accept-ambiguous` を指定する。
- `pf project freeze` を再実行せずに `.platform-factory/freeze.lock.json` を手で編集する。
- レビューしていない `PLATFORM_FACTORY_HOOKS_CONFIG` ファイルを指定して `pf` を実行する。

## ベストプラクティス

- 可能な場合は実行ファイルを静的にビルドし（`CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w'`）、イメージを小さく再現可能に保つ。
- ワークロードの分離要件と利用可能なホストサポートに基づいて、コンテナか microVM かを選択する。この外部 CLI ガイドは ECC のサンドボックス階層を保証せず、ECC の機能/証跡ポリシーを置き換えるものでもない。
- オフラインのポリシーチェック（AI、データ、ゲートウェイ、Kubernetes、サプライチェーンの各アナライザー）には `pf extensions list` / `pf extensions analyze` を使用する。
- CI では `pf verify` を必須ステップとして実行し、SBOM と来歴をアーカイブする。

## 関連スキル

- `docker-patterns` - Dockerfile がまだ関わる場合のコンテナの規約
- `deployment-patterns` - ロールアウトとリリースの戦略
- `kubernetes-patterns` - 生成したイメージをクラスター上で実行する
- `security-review` - サプライチェーンと秘密情報の扱いのレビュー
