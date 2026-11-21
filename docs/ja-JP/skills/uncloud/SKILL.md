---
name: uncloud
description: Uncloud クラスターを管理するときに使用します。サービスのデプロイ、Caddy イングレスの設定、クラスター外デバイス向けの静的プロキシルートの追加、ポートの公開、スケーリング、ログの確認、`uc` CLI によるマシンやボリュームの管理が対象です。
metadata:
  origin: ECC
---

# Uncloud クラスター管理

`uc` CLI のリファレンスです。Docker コンテナ、WireGuard メッシュネットワーク、Caddy リバースプロキシを使った分散型セルフホスティングプラットフォームを扱います。

## 有効化するタイミング

Uncloud クラスターを扱うとき、特に次のような場合にこのスキルを使用します。
- `uc machine` でマシンをブートストラップする、またはクラスターに参加させる
- `uc deploy` で Compose ファイルからサービスをデプロイする
- Uncloud 経由で HTTP、HTTPS、TCP、UDP ポートを公開する
- `x-caddy`、`x-ports`、`--caddyfile` で Caddy イングレスを設定する
- LAN 上の外部デバイスをクラスターのプロキシ経由でルーティングする
- ログ、サービスの状態、ボリューム、DNS、マシンへの配置を確認する

## 仕組み

Uncloud は、WireGuard メッシュで接続されたピアマシン上で Docker サービスを実行します。各マシンは対等なクラスターメンバーであり、サービスはオーバーレイネットワーク上で通信し、Caddy はグローバルに動作して公開 HTTP/HTTPS トラフィックの TLS を終端します。Compose ファイルでは、イングレス、配置、Caddy 設定の自動生成のための Uncloud 拡張を使用できます。一方、`uc` CLI はイメージの配布、スケジューリング、スケーリング、ログ、クラスターの状態を扱います。

## 例

```bash
uc machine init user@host --name machine-1
uc service run --name web -p app.example.com:8080/https nginx:latest
uc deploy
```

## コアコンセプト

- **中央のコントロールプレーンは存在しない** — すべてのマシンは WireGuard で接続された対等なピアです
- **Caddy** は各マシン上でグローバルサービスとして動作し、Let's Encrypt から TLS を自動取得します
- **オーバーレイネットワーク** — サービスはデフォルトで `10.210.0.0/16` を介して通信し、メッシュ内では DNS が提供されます
- **Caddyfile は自動生成される** — 直接編集してはいけません。代わりに `x-caddy` / `--caddyfile` を使用します

---

## CLI クイックリファレンス

### マシン

| コマンド | 目的 |
|---------|---------|
| `uc machine init user@host` | 最初のマシン / 新しいクラスターをブートストラップ |
| `uc machine add user@host` | 既存のクラスターにマシンを参加させる |
| `uc machine ls` | マシンの一覧表示 |
| `uc machine update NAME --public-ip IP` | イングレス用のパブリック IP を更新 |
| `uc machine rm NAME` | マシンの削除 |

`init` の主なフラグ: `--name`, `--network 10.210.0.0/16`, `--no-caddy`, `--no-dns`, `--public-ip auto\|IP\|none`

### サービス

| コマンド | 目的 |
|---------|---------|
| `uc service ls` / `uc ls` | サービスの一覧表示 |
| `uc service run IMAGE` | 単一コンテナのサービスを実行 |
| `uc deploy` | `compose.yaml` からデプロイ |
| `uc deploy --no-build` | ビルドし直さず、プッシュ済みのイメージをデプロイ |
| `uc deploy --recreate` | サービスの再作成を強制 |
| `uc scale SERVICE N` | レプリカ数を設定 |
| `uc service logs SERVICE` | ログの表示 |
| `uc service exec SERVICE` | コンテナ内でシェルを実行 |
| `uc service inspect SERVICE` | 詳細情報 |
| `uc service rm SERVICE` | サービスの削除（名前付きボリュームは残る） |
| `uc ps` | クラスター全体のすべてのコンテナ |

### イメージ

```bash
uc image push myapp:latest                    # ローカルイメージをすべてのマシンにプッシュ
uc image push myapp:latest -m machine1,machine2  # 特定のマシンにプッシュ
uc images                                     # クラスター内のイメージを一覧表示
```

### ボリューム

```bash
uc volume ls                  # すべてのボリューム
uc volume ls -m machine1      # 特定のマシン上のボリューム
uc volume create NAME -m MACHINE
uc volume rm NAME
```

### Caddy

```bash
uc caddy config    # 現在生成されている Caddyfile を表示（読み取り専用）
uc caddy deploy    # クラスター全体に Caddy をデプロイ/アップグレード
```

### DNS とコンテキスト

```bash
uc dns show        # 予約済みの *.uncld.dev ドメインを表示
uc dns reserve     # 新しいドメインを予約
uc ctx ls          # クラスターコンテキストの一覧表示
uc ctx use prod    # コンテキストの切り替え
```

---

## ポートの公開

### HTTP/HTTPS（Caddy リバースプロキシ経由）

```
-p [hostname:]container_port[/protocol]
```

| 例 | 意味 |
|---------|---------|
| `-p 8080/https` | `service-name.cluster-domain` のホスト名が自動付与される HTTPS |
| `-p app.example.com:8080/https` | カスタムホスト名を使った HTTPS |
| `-p 8080/http` | HTTP のみ（TLS なし） |

### TCP/UDP（ホストにバインドされ、Caddy を経由しない）

```
-p [host_ip:]host_port:container_port[/protocol]@host
```

| 例 | 意味 |
|---------|---------|
| `-p 5432:5432@host` | すべてのインターフェースで TCP 5432 |
| `-p 127.0.0.1:5432:5432@host` | ループバックのみで TCP 5432 |
| `-p 53:5353/udp@host` | UDP |

---

## Compose ファイル拡張

Uncloud は Docker Compose に次の拡張を追加します。

### `x-ports` — ドメイン付きでポートを公開

```yaml
services:
  app:
    image: app:latest
    x-ports:
      - example.com:8000/https
      - www.example.com:8000/https
      - api.example.com:9000/https
```

### `x-caddy` — サービス用のカスタム Caddy 設定

```yaml
services:
  app:
    image: app:latest
    x-caddy: |
      example.com {
        redir https://www.example.com{uri} permanent
      }
      www.example.com {
        reverse_proxy {{upstreams 8000}} {
          import common_proxy
        }
        basic_auth /admin/* {
          admin $2a$14$...
        }
      }
```

`x-caddy` 内で使用できるテンプレート関数:
- `{{upstreams [service] [port]}}` — 正常なコンテナの IP
- `{{.Name}}` — サービス名
- `{{.Upstreams}}` — すべてのサービスから IP へのマップ

### `x-machines` — 配置制約

```yaml
services:
  db:
    image: postgres:18
    x-machines: db-machine          # 単一のマシン名
  app:
    image: app:latest
    x-machines:
      - machine-1
      - machine-2
```

### 複数サービスの完全な例

```yaml
services:
  api:
    build: ./api
    x-ports:
      - api.example.com:3000/https
    environment:
      DATABASE_URL: postgres://db:5432/mydb

  web:
    build: ./web
    x-ports:
      - example.com:8000/https
      - www.example.com:8000/https
    environment:
      API_URL: http://api:3000

  db:
    image: postgres:18
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    x-machines: db-machine

volumes:
  db-data:
```

---

## 外部（クラスター外）デバイスへのルーティング

実際のコンテナを動かさずに、外部デバイス（例: BMC、NAS、ルーターの管理画面）を Caddy 経由で公開するには、次の手順を実行します。

**1. Caddyfile スニペットを作成する**（例: `~/device.caddyfile`）:

```caddyfile
https://device.example.com {
    reverse_proxy https://192.168.1.x {
        transport http {
            tls_insecure_skip_verify   # 自己署名の BMC 証明書の場合に必要
        }
    }
    log
}
```

平文のアップストリームの場合: `reverse_proxy http://192.168.1.x:port`

**2. 何もしないコンテナを持つ名前付きサービスとして登録する:**

```bash
uc service run \
  --name device-bmc \
  --caddyfile ~/device.caddyfile \
  registry.k8s.io/pause:3.9
```

`pause` は何もしない最小限のコンテナです。何も実行しませんが、Caddyfile を紐付ける先となるサービスエントリを Uncloud に与えます。

**3. 確認する:**

```bash
uc caddy config   # device.example.com のブロックが表示されるはずです
```

> `--caddyfile` は、`@host` 以外の公開ポートと組み合わせることはできません。

**DNS のヒント:** ワイルドカードレコード（`*.yourdomain.com → cluster-public-ip`）を設定しておくと、新しいサブドメインはすぐに使えます。サービスごとに DNS を変更する必要はありません。

---

## サービス DNS（内部）

クラスター内のサービスは、名前で互いを解決します。

| DNS 名 | 解決先 |
|----------|------------|
| `service-name` | 正常な任意のコンテナ |
| `service-name.internal` | 同上 |
| `rr.service-name.internal` | ラウンドロビン |
| `nearest.service-name.internal` | 同じマシン上のコンテナを優先 |

---

## スケーリングとグローバルサービス

```bash
uc scale web 5    # 5 レプリカ（マシン間に分散）
uc scale web 1    # スケールダウン
```

```yaml
services:
  caddy:
    deploy:
      mode: global   # すべてのマシンに 1 つずつコンテナを配置
```

---

## イメージタグテンプレート（compose.yaml 内）

```yaml
image: myapp:{{gitdate "20060102"}}.{{gitsha 7}}
image: myapp:{{gitsha 7}}.${GITHUB_RUN_ID:-local}
```

| 関数 | 出力 |
|----------|--------|
| `{{gitsha N}}` | コミット SHA の先頭 N 文字 |
| `{{gitdate "format"}}` | Go 形式で表した Git コミット日 |
| `{{date "format"}}` | 現在の日付 |

---

## よく使うワークフロー

**ソースからデプロイする:**
```bash
uc deploy                          # ビルド + プッシュ + デプロイ
uc build --push && uc deploy --no-build   # 手順を分けて実行
```

**サービスを調査する:**
```bash
uc inspect web
uc logs -f web
uc logs --since 1h web
uc exec web                        # シェルを開く
uc exec web /bin/sh -c "env"       # 特定のコマンドを実行
```

**ゼロダウンタイムのデプロイ**は自動的に行われます。Uncloud はヘルスチェックを待ってから古いコンテナを終了します。

**強制的に再作成する:**
```bash
uc deploy --recreate
```

---

## よくある間違い

| 間違い | 対処 |
|---------|-----|
| Caddyfile を直接編集する | compose では `x-caddy`、`uc service run` では `--caddyfile` を使用する |
| 自己署名証明書の HTTPS アップストリームをプロキシする | `transport http { tls_insecure_skip_verify }` を追加する |
| `uc caddy config` にユーザー定義のブロックが表示されない | Caddy の管理ソケットに到達できない。`uc inspect caddy` と `uc logs caddy` を確認する |
| コンテナからクラスター外の LAN IP に到達できない | Caddy コンテナのホストが対象ネットワークへルーティングできるか確認する |
| `uc service rm` の後にボリュームが失われる | 名前付きボリュームは残る。自動的に削除されるのは匿名ボリュームのみ |
