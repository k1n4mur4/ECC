---
name: ito-compute
description: ライブのGPU在庫を照会し、認証済みのItô固定レートRFQを送信し、RFQや調達の状況を確認し、デバイス資格情報を失効させ、別途インストールした正規CLIを通じて明示的に制御されたノード適格性検証を実行します。ユーザーがH100/H200の容量を探す、固定の計算レートを依頼する、Itôの計算ステータスを確認する、GPUノードを検証する、Itôへのアクセスを失効させる、GPU計算リソースをレンタルまたは購入するといった依頼をし、サポートされる範囲の説明が必要な場合に使用します。
---

# Itô Compute

正規のItô compute CLIまたはMCPサーバーを使用します。ECCは、独自のクライアント、ローカルシミュレーション、予約、ワークロードランナー、推論サーバーを実装しません。ECC自体はブラウザ自動操作を一切行いません。

## 正規のローカルパッケージをインストールする

`ito-compute-cli` は現在未公開です。`npx`、`npm exec`、未検証のパッケージを使わず、正規リポジトリからビルドしてください。

```sh
git clone https://github.com/Ito-Markets/ito-cloud-runtime.git
cd ito-cloud-runtime/cli/ito-compute-cli
npm ci
npm run check
```

`ECC_ITO_CLI_EXECUTABLE` に、ビルド済みエントリの明示的な絶対パスを設定します。

```text
/absolute/path/to/ito-cloud-runtime/cli/ito-compute-cli/dist/bin/ito.js
```

ECCは、この資格情報を扱うクライアントを `PATH` から検出することはありません。`ecc ito login` はデバイス認可を実行し、`ITO_API_KEY` を引き継ぐことはありません。検証専用の `auth`、および `find` と `status` は、設定されている場合に `ITO_API_KEY` を直接転送します。`ITO_AUTH_MODE=legacy` は不要です。キーやトークンを、引数、追跡対象ファイル、MCPの結果、ログ、チャットに含めないでください。

## CLIワークフロー

1. 最初の操作の前に `ecc ito login` を実行します。ECCはこれを正規CLIのデバイス認可に委譲し、デフォルトでItôの検証ページを開き、デバイストークンをmacOSキーチェーンに保存します。ページへの遷移を抑止するには `ecc ito login --no-browser` を使用します。ECC自体はブラウザ自動操作を一切行いません。呼び出し元のエージェントがサインイン済みブラウザでの手順を完了できない場合は、正確なコマンドをユーザーに渡してください。承認が完了したら元のタスクに戻り、`ecc ito auth` を続けます。
   デバイストークンはデフォルトでmacOSキーチェーンを使用します。ファイルトークンへのフォールバックは明示的な指定が必要で、そのディレクトリとトークンファイルは所有者のみアクセス可能（0700および0600）に保つ必要があります。
2. `ecc ito auth` を実行して既存の資格情報を検証します。ログインを開始することはなく、`--no-browser` は拒否されます。
3. `ecc ito find` の前に、RFQを送信するための明示的な購入者の権限を取得します。
   - `gpu`、`count`、整数の `days`、`max-rate`、`nodes`、`gpus-per-node`、`storage-tb`、`start-window`、`form-factor`、`contract-type`、`fabric`、`region`、および分割充足（split-fill）の判断を必須とします。
   - `count == nodes * gpus-per-node` を必須とし、トポロジーを推測で導出してはいけません。
   - `any` は、購入者がファブリックまたはリージョンを問わないことを明示的に受け入れた場合にのみ使用します。
   - `--allow-split` を省略した場合は false を意味します。
4. ライブのRFQコマンドを実行します。

   ```sh
   ecc ito find \
     --gpu h200 \
     --count 8 \
     --nodes 1 \
     --gpus-per-node 8 \
     --days 30 \
     --storage-tb 1 \
     --start-window 2099-08-15 \
     --max-rate 3.00 \
     --form-factor bare_metal \
     --contract-type reservation \
     --fabric infiniband \
     --region us-east-1
   ```

5. `ecc ito status` を実行して、RFQと調達注文を確認します。
   通信失敗で結果が不明確な場合は、`find` を繰り返す前にステータスを確認してください。
6. 見積もりの準備ができ、購入者が明示的に承認した場合は、それを承諾します。

   ```sh
   ecc ito accept rfq_<ticket-id>
   ```

   これはチケットを人間によるレビューのためにデスクへ回送します。資金の移動や容量の予約は行いません。購入者の明示的な権限なしに承諾してはいけません。
7. ユーザーがこのデバイスの失効を明示的に求めた場合にのみ `ecc ito logout` を実行します。
   リモートでの失効に失敗した場合、正規CLIはオペレーターが再試行できるようにローカルの資格情報を保持します。その代わりとしてトークンを手動で削除してはいけません。

在庫価格は参考値です。RFQは予約済みの容量ではありません。正規の結果に null でない確定見積もり（firm quote）が含まれる場合にのみ、そのレートを固定とみなしてください。

## ライブノード適格性検証

`ecc ito evals` は、別途インストールされた `sixtytwo-cli==0.3.33` に対する、正規CLIの限定的なライブアダプターを公開します。ECCを通じたローカルフィクスチャの実行は公開しません。
これを呼び出す前に、以下のすべてを必須とします。

- 指定したノードに接続することへのオペレーターの認可
- `ITO_ENABLE_SIXTYTWO_LIVE=1`
- `--live-sixtytwo`
- 明示的なノードリスト
- `sixtytwo.yaml` を含む、既存の絶対パスの設定ディレクトリ

```sh
ecc ito evals \
  --cluster clu_prod_example \
  --live-sixtytwo \
  --nodes gpu-01,gpu-02 \
  --config-dir /absolute/path/to/qualification-config
```

正規アダプターが実行できるのは、固定されたバージョンチェックと、明示的に指定したノードに対する `sixtytwo test --full` のみです。リソースのレンタル、起動、復旧、修復、リセット、購入、注文はできません。ECCは `ITO_API_KEY` やモデル／クラウドの資格情報をノード適格性検証に転送しません。

## MCPワークフロー

正規パッケージをビルドし、絶対パスでstdioサーバーを設定します。

```json
{
  "mcpServers": {
    "ito-compute": {
      "command": "node",
      "args": [
        "/absolute/path/to/ito-cloud-runtime/cli/ito-compute-cli/dist/bin/ito-mcp.js"
      ]
    }
  }
}
```

サーバーが公開するのは以下のみです。

- `ito_auth`
- `ito_find`
- `ito_status`
- `ito_accept`

`ito_auth` は既存の資格情報を検証するもので、デバイスログインは開始しません。`ito_auth` を使用し、購入者の明示的な権限と必須の制約条件をすべて収集し、`ito_find` を呼び出し、必要に応じて `ito_status` でポーリングします。見積もりの準備ができ、購入者が明示的に承認した場合は、チケットIDを指定して `ito_accept` を呼び出します。デスクの見積もりは通常、デスクが確認するまでは参考値であり拘束力はありません。結果には `quote_class` が含まれます。

## レンタルまたは購入のセマンティクス

`find` はRFQを送信し、確定見積もりを返すことがありますが、レンタル、購入、予約、プロビジョニング、資金移動は行いません。`accept` は見積もりを人間によるレビューのためにデスクへ回送しますが、資金の移動や容量の予約は行いません。`status` は読み取り中心ですが、プロバイダーのエンドポイントが既存の調達注文を照合（reconcile）することがあります。ECCのヘルプにある受動的なダッシュボードリンクは、ユーザーが操作する別のWebルートです。CLIに存在しない機能の代替として、これを開いたり操作したりしてはいけません。

## サポートされない操作

サポートされるクライアントの範囲では、見積もりのロック、容量の予約、ワークロードの実行、推論の提供はできません。`accept` はデスクへの引き継ぎであり、購入ではありません。MCPサーバーは適格性検証を公開しません。上記の明示的なCLIコマンドを使用してください。追加のツールや購入経路を作り出してはいけません。ローカルCLIが存在しない場合やライブ操作が失敗した場合に、ブラウザやフィクスチャで代用してはいけません。不足している機能を報告して、そこで停止してください。
