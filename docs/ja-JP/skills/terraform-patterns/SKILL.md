---
name: terraform-patterns
description: プロジェクト構成、リモートステート、モジュール、変数、シークレット、安全な plan/apply ワークフロー、CI のための Terraform および OpenTofu のインフラストラクチャ・アズ・コードのパターン。.tf ファイルの作成やレビュー、モジュールや環境の構造化、バックエンドとステートロックの設定、plan のドリフト・ステート・プロバイダーエラーのデバッグ時に使用します。
metadata:
  origin: ECC
---

# Terraform パターン

レビュー可能で、再現性があり、安全に適用できるインフラストラクチャコードを書くための、本番グレードの Terraform（および OpenTofu）パターンです。

## 有効化するタイミング

- `.tf` または `.tfvars` ファイルの作成・レビュー
- リポジトリをモジュールと環境に構造化する
- リモートバックエンド、ステートロック、ステート移行の設定
- インフラストラクチャコードでの変数の受け渡しとシークレットの扱い
- CI での plan/apply 自動化のセットアップ
- 失敗した plan、ステートドリフト、ロックエラー、プロバイダーバージョンの競合のデバッグ
- リソースを破棄せずにリファクタリングする（`moved`、`import`）

## 使用するタイミング

> 上記の**有効化するタイミング**と同じです。このエイリアスはリポジトリのスキル形式の規約を満たすためのものです。Terraform または OpenTofu の設定を書く、レビューする、デバッグするときは、常にこのスキルを使用してください。

## 仕組み

このスキルは、タスク別に整理された**コピー＆ペースト可能なパターン**と**安全なコマンドワークフロー**を提供します。

1. **プロジェクト構成** - 環境は、再利用可能なモジュールを呼び出す薄いルートとして構成します。
2. **バージョンとプロバイダー** - Terraform とプロバイダーのバージョンを固定し、ロックファイルをコミットします。
3. **リモートステート** - 暗号化され、ロックされた、環境ごとのステートを使います。
4. **変数と出力** - 型付けされ検証された入力と、最小限の出力にします。
5. **シークレット** - 値をコードに含めず、ステートへの露出を意識します。
6. **リソース** - `count` より `for_each`、`lifecycle`、タグ付けを使います。
7. **モジュール** - 小さく、単一目的で、バージョン管理します。
8. **リファクタリング** - 破棄と再作成の代わりに `moved` と `import` ブロックを使います。
9. **安全なワークフローと CI** - plan を保存し、レビューしてから適用します。
10. **デバッグとアンチパターン** - よくあるエラーと避けるべきことを扱います。

例では具体性のために AWS を使用しています。この構造はどのプロバイダーにも当てはまります。

## 例

| タスク | 参照先 |
|------|---------|
| dev/staging/prod のレイアウト | [プロジェクト構成](#プロジェクト構成) |
| ロック付きリモートステート | [リモートステート](#リモートステート) |
| 検証付き変数 | [変数と出力](#変数と出力) |
| シークレットをステートとコードに含めない | [シークレット](#シークレット) |
| リソースを破棄せずに名前を変更する | [破棄せずにリファクタリングする](#破棄せずにリファクタリングする) |
| CI での plan/apply | [安全なワークフローと CI](#安全なワークフローと-ci) |
| ロックまたはドリフトのエラー | [デバッグ](#デバッグ) |

---

## プロジェクト構成

環境は薄いルートモジュールにとどめます。ロジックは再利用可能なモジュールに置きます。

```text
infra/
├── modules/
│   └── network/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── envs/
    ├── dev/
    │   ├── main.tf
    │   ├── backend.tf
    │   ├── providers.tf
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        ├── backend.tf
        ├── providers.tf
        └── terraform.tfvars
```

経験則:

- ステートは環境ごと、および影響範囲（blast radius）の境界ごと（ネットワーク、データ、アプリ）に 1 つにします。巨大な単一ステートは、すべての plan を遅くし、すべてのミスの影響を大きくします。
- 環境の違いは、コピー＆ペーストしたリソースではなく**入力**（`terraform.tfvars`）で表現します。
- 本番と非本番でステートと認証情報を分離する代わりに、ワークスペースを使用してはいけません。

## バージョンとプロバイダー

すべてを固定します。固定されていないプロバイダーは、実行のたびに挙動が変わります。

```hcl
# versions.tf
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}
```

```hcl
# providers.tf
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
```

- `.terraform.lock.hcl` をコミットします。プロバイダーのチェックサムが記録され、CI とチームメンバーが同一のプロバイダーをインストールできます。
- `.terraform/` ディレクトリや `*.tfstate` ファイルは**コミットしないでください**。
- アップグレードは意図的に行います。`terraform init -upgrade` を実行し、ロックファイルの差分をレビューしてから plan します。

## リモートステート

ローカルステートはチームでは機能せず、紛失しやすいものです。暗号化とロックを備えたリモートバックエンドを使用します。

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket       = "example-org-tfstate-prod"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3 ネイティブのロック（Terraform >= 1.10）
  }
}
```

古い Terraform バージョンでは、ロックに DynamoDB テーブルを使用します。
`use_lockfile = true` を次のものに置き換えます。

```hcl
dynamodb_table = "example-org-tfstate-lock"
```

バックエンドのルール:

- バックエンドブロックは変数を参照できません。環境ごとの値が必要な場合は、`-backend-config` または部分的な設定ファイルで値を渡します。
- バケットのバージョニングを有効にし、不正なステート書き込みから復旧できるようにします。
- ステートバケットへのパブリックアクセスをブロックし、読み取れるユーザーを制限します。ステートには機密値が含まれていることがよくあります。
- ロックエラーを回避するために `-lock=false` を使用してはいけません。[デバッグ](#デバッグ)を参照してください。

## 変数と出力

入力に型を付けて検証し、ミスが plan 時に失敗するようにします。

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "instance_count" {
  type        = number
  description = "Number of application instances."
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "instance_count must be between 1 and 20."
  }
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the service."
  default     = []
}
```

```hcl
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "db_password" {
  description = "Generated database password."
  value       = random_password.db.result
  sensitive   = true
}
```

- すべての変数と出力に `description` を付けます。モジュールは書かれる回数よりはるかに多く読まれます。
- `default` は、すべての環境で安全な場合にのみ指定します。必須の入力は、呼び出し側に判断を促します。
- 認証情報を含む出力には `sensitive = true` を付けます。ただし、これは CLI 出力で隠すだけであり、ステートには保存されることに注意してください。

## シークレット

Terraform のステートは、リソースの属性を平文で保存します。これには、渡したパスワードやキー、プロバイダーが生成したパスワードやキーも含まれます。

行うべきこと:

- シークレットを `.tf` やコミットされる `.tfvars` ファイルに含めません。実行時に `TF_VAR_*` 環境変数または CI のシークレットストアから供給します。
- Terraform で値を作成する代わりに、シークレットマネージャーに既に存在するシークレットを参照します。
- お使いの Terraform とプロバイダーのバージョンが対応している場合は、ephemeral 値と write-only 属性を使用し、値がステートに残らないようにします。
- ステートを保存時に暗号化し、読み取りアクセスを制限します。
- 長期間有効なアクセスキーではなく、短期間有効な認証情報（CI からの OIDC、引き受けたロール（assumed role））で認証します。

```hcl
# 値をコードで定義する代わりに、既存のシークレットを読み取る
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "prod/app/db-password"
}

resource "aws_db_instance" "app" {
  identifier = "app-${var.environment}"
  # ...
  password = data.aws_secretsmanager_secret_version.db.secret_string
}
```

> データソース経由でシークレットを読み取っても、値はステートに格納されます。いかなる場合も、ステートファイルを機密として扱ってください。

行ってはいけないこと:

- `provider` ブロックに認証情報をハードコードする。
- シークレットを含む `terraform.tfvars` ファイルをコミットする。`.gitignore` に追加します。
- 共有 CI ログで `terraform output -json` を使ってシークレットを出力する。

## リソース

### `count` より `for_each` を優先する

`count` はインデックスでリソースを識別します。リストの途中の項目を削除すると、それ以降のすべての項目のインデックスが 1 つずつ繰り上がるため、Terraform は意図した 1 つだけを削除するのではなく、後続のリソースを変更または置換し（最後の 1 つを破棄）する計画を立てます。

```hcl
# 脆弱: "b" を削除すると "c" が b のスロットに移動し、最後のインデックスが破棄される
resource "aws_iam_user" "bad" {
  count = length(var.users)
  name  = var.users[count.index]
}

# 安定: 各リソースは名前をキーとし、"b" を削除しても "b" だけが破棄される
resource "aws_iam_user" "good" {
  for_each = toset(var.users)
  name     = each.key
}
```

`count` は、単純なオン/オフの切り替えにのみ使用します。

```hcl
resource "aws_cloudwatch_log_group" "app" {
  count = var.enable_logging ? 1 : 0
  name  = "/app/${var.environment}"
}
```

### ライフサイクルガード

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "example-org-data-${var.environment}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_launch_template" "app" {
  # ...
  lifecycle {
    create_before_destroy = true
  }
}
```

- ステートフルなリソース（データベース、バケット、暗号化キー）への `prevent_destroy` は、誤った破棄を plan エラーに変えます。
- `prevent_destroy` は、設定に残っているリソースのみを保護します。リソースブロックを削除すると、Terraform はこの設定を認識できなくなり、実際のリソースを破棄する計画を立てます。リソースを破棄**せずに**管理対象から外すには、`removed` ブロックを使用します（Terraform >= 1.7）。

```hcl
removed {
  from = aws_s3_bucket.data

  lifecycle {
    destroy = false
  }
}
```
- `ignore_changes` はドリフトを隠します。使用は限定的にし、理由をコメントで残します。

### 安全なデフォルト

```hcl
resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

意図的に公開するエンドポイントを除き、`0.0.0.0/0` のインバウンドルールは避け、IAM ポリシーは必要な特定のアクションとリソースに限定します。

## モジュール

良いモジュールは、1 つのことだけを行い、小さなインターフェースを公開し、バージョン管理されています。

```hcl
module "network" {
  source = "../../modules/network"

  environment = var.environment
  cidr_block  = "10.20.0.0/16"
}

# レジストリまたは git のモジュール: バージョンまたは ref を固定する
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}
```

- レジストリモジュールは `version` で、git モジュールは `?ref=<tag>` で固定します。更新され続けるブランチを追跡してはいけません。
- 子モジュール内に `provider` ブロックを設定しません。`required_providers` を宣言し、ルートからプロバイダーを渡します。
- コンポジションを優先します。モジュールはすべてを自分で作成するのではなく、ID を入力として受け取ります。
- 単一のリソースをラップするだけで、引数を転送するだけのモジュールは作らないでください。

## 破棄せずにリファクタリングする

リソースの名前変更やモジュールへの移動は、破棄と作成の組み合わせとして計画されます。同じオブジェクトであることを Terraform に伝えます。

```hcl
# コード内でリソースの名前を変更: 既存のオブジェクトを維持する
moved {
  from = aws_instance.web
  to   = aws_instance.app
}

# 既存のリソースをステートに取り込む（Terraform >= 1.5）
import {
  to = aws_s3_bucket.legacy
  id = "example-org-legacy-bucket"
}
```

リファクタリング後は必ず plan を読みます。正しい `moved` ブロックは、破棄を伴わず "has moved" と表示されます。

`terraform state` コマンドは最後の手段としてのみ使用し、事前にバックアップを取り、ステートファイルを手動で編集してはいけません。

## 安全なワークフローと CI

ローカルでフォーマットと検証を行い、plan し、レビューして、**同じ** plan を適用します。

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform show tfplan          # 適用前にレビューする
# STOP: 次のコマンドの前に、レビュー済みの plan に対する明示的な人間の承認を得る
terraform apply tfplan         # レビューした内容をそのまま適用する
```

AI エージェントは、ユーザーの承認なしに `terraform apply` や `terraform destroy` を実行してはいけません。plan の要約を示し、ユーザーの承認を待ち、その後に初めて保存済みの plan を適用します。

`-out` を使う理由: 単独の `terraform apply` は再度 plan を行うため、実行される内容がレビューした内容と異なる可能性があります。

plan では次の点を確認します。

- ステートフルなリソースに対する `-/+`（置換）と `-`（破棄）の行
- 自分が行っていない変更（ドリフトまたはプロバイダーのアップグレードを示す）
- サマリー行の予期しない件数

### CI パイプラインの形

```yaml
# .github/workflows/terraform.yml（形のみ）
name: terraform
on:
  pull_request:
    paths: ["infra/**"]

permissions:
  id-token: write   # クラウドプロバイダーへの OIDC、キーを保存しない
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      # サードパーティのアクションは、移動可能なタグではなく完全なコミット SHA で固定する
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1
        with:
          terraform_version: 1.10.5 # required_version と use_lockfile（>= 1.10）を満たす必要がある
      - run: terraform fmt -check -recursive
        working-directory: infra/envs/dev
      - run: terraform init -input=false
        working-directory: infra/envs/dev
      - run: terraform validate
        working-directory: infra/envs/dev
      - run: terraform plan -input=false -out=tfplan
        working-directory: infra/envs/dev
```

- プルリクエストで `plan` を実行し、レビュー用に投稿します。`apply` は、承認後に保存済みの plan を使って main ブランチからのみ実行します。
- 自動化では `-input=false` を使用し、変数が不足している場合に停止せず失敗するようにします。
- プロバイダーが許す範囲で、plan ジョブには読み取り専用の認証情報を与え、apply 用のロールは分離します。
- apply の前に、ポリシーまたは静的解析のステップ（例: `tflint`、`checkov`、`trivy config`）の導入を検討します。

## デバッグ

| 症状 | 考えられる原因 | 対処 |
|---------|--------------|------------|
| `Error acquiring the state lock` | 別の実行がロックを保持している、または実行がクラッシュした | 実行中のものがないことを確認してから `terraform force-unlock <LOCK_ID>` を実行する。ロックを無効にしない。 |
| 自分が行っていない変更が plan に表示される | ドリフト、プロバイダーのアップグレード、またはデフォルト値の変更 | `terraform plan -refresh-only` でドリフトを確認する。ロックファイルの差分を確認する。 |
| `Provider produced inconsistent result` | プロバイダーのバグまたはバージョンの不一致 | プロバイダーを固定してアップグレードする。イシュートラッカーを確認する。 |
| `Cycle` エラー | 2 つのリソースが相互に依存している | 中間リソースでループを断ち切るか、冗長な参照を削除する。 |
| リソースが既に存在する | Terraform の外部で作成された | `import` ブロックを追加してから plan する。 |
| `for_each` の値が不明な値に依存している | キーが apply 後にのみ判明する属性に由来している | 静的な値をキーにするか、一度限りの例外として `-target` を使い 2 段階で apply する。 |
| 名前変更時に破棄と再作成が発生する | `moved` ブロックがない | `moved` ブロックを追加し、再度 plan する。 |

便利なコマンド:

```bash
terraform state list                    # 追跡されているもの
terraform state show aws_instance.app   # 1 つのリソースを調べる
terraform plan -refresh-only            # 変更を提案せずにドリフトを検出する
terraform providers                     # 使用中のプロバイダーとバージョン
TF_LOG=DEBUG terraform plan 2> debug.log   # 詳細ログ。シークレットを含む可能性がある
```

> `TF_LOG` の出力には認証情報が含まれる場合があります。内容を除去せずに issue や CI ログに貼り付けないでください。

## アンチパターン

| アンチパターン | 問題点 | 代わりに行うこと |
|--------------|--------------|---------|
| 保存済み plan なしの `terraform apply` | レビューした内容と異なるものが適用される | `plan -out`、レビュー、`apply tfplan` |
| 人間が関わるワークフローでの `-auto-approve` | 最後の安全チェックが失われる | レビュー済みの plan を適用するパイプラインに限定する |
| 共有インフラへのローカルステート | ステートの紛失、ロックなし | ロック付きのリモートバックエンド |
| すべてを含む巨大な単一ステート | plan が遅い、影響範囲が大きい | 環境とドメインで分割する |
| `.tf` やコミットされた `.tfvars` 内のシークレット | 認証情報の漏洩 | 実行時変数またはシークレットマネージャー |
| 固定されていないプロバイダーやモジュール | 実行ごとに予期しない変更が起きる | バージョン制約とロックファイル |
| 名前付きの要素のリストに対する `count` | インデックスのずれによる破棄 | 安定したキーを使う `for_each` |
| 日常的な `-target` の使用 | 依存関係をスキップし、ステートが不整合になる | 根本原因を修正する。一度限りの例外としてのみ使用する |
| ステートの手動編集 | ステートが破損する | `moved`、`import`、またはバックアップ付きの `terraform state` |
| 固着したロックを回避するためのロック無効化 | 同時書き込みでステートが破損する | 該当のロックを確認して `force-unlock` する |

## チェックリスト

PR を作成する前に:

- [ ] `terraform fmt -recursive` と `terraform validate` が成功する
- [ ] Terraform とプロバイダーのバージョンが固定され、`.terraform.lock.hcl` がコミットされている
- [ ] ステートがリモートで、暗号化され、ロックされている
- [ ] コード、`.tfvars`、`sensitive` でない出力にシークレットがない
- [ ] 不正な値が起こり得る箇所で、変数に型、説明、検証がある
- [ ] ステートフルなリソースに `prevent_destroy` があるか、ない場合は明示的な理由がある（また、削除には `destroy = false` の `removed` ブロックを使う）
- [ ] 保存済みの plan を適用する前に、人間が承認した
- [ ] plan を読み、予期しない破棄や置換がない
- [ ] リファクタリングに、破棄と再作成ではなく `moved` または `import` を使っている
- [ ] CI が、保存済みでレビュー済みの plan を適用する

## 関連スキル

- `kubernetes-patterns` - インフラが整った後のクラスターワークロード
- `docker-patterns` - Terraform が管理するインフラ上で動くコンテナイメージ
- `deployment-patterns` - リリースとロールアウトの戦略
- `security-review` - より広範なセキュリティチェックリスト
- `database-migrations` - スキーマ変更（インフラ変更とは別）
