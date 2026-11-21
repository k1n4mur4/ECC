---
name: rails-security
description: Rails 7.1+ および 8.x アプリ向けの Ruby on Rails セキュリティプラクティス。本番環境の設定、認証、認可、Strong Parameters、SQL インジェクション、XSS と出力エスケープ、CSRF、ファイルアップロード、API セキュリティ、クレデンシャル、信頼できない境界、依存関係のスキャンを扱います。Rails の認証、認可、入力処理、アップロード、デプロイ設定をレビューまたは記述するときに使用します。
origin: community
---

# Rails セキュリティ

Ruby on Rails アプリケーション（Rails 7.1+ および 8.x）向けのセキュリティプラクティスです。Rails はほとんどの箇所でデフォルトで安全です。本番環境に到達する脆弱性は、保護を追加し忘れたことよりも、デフォルトの保護を無効にしたことに由来するのが通常です。このスキルは「どうやるか」を扱います。どの制御を選ぶかの判断については、Ruby セキュリティルール（このリポジトリの `rules/ruby/security.md`。`rules/ecc/ruby/security.md` としてインストールされます）を参照してください。

## 有効化するタイミング

- 認証、セッション、アカウント復旧を記述またはレビューするとき
- コントローラーまたはビューに認可チェックを追加するとき
- ユーザー入力、ファイルアップロード、Webhook ペイロードを処理するとき
- 本番環境向けに Rails アプリを設定するとき
- `config/`、`app/controllers/`、`Gemfile` に触れる PR をレビューするとき
- `html_safe`、`raw`、`Arel.sql`、または生の SQL 文字列を使用するとき

## 本番環境の設定

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.force_ssl = true
  # すべてのリクエストが HTTP を拒否またはリダイレクトするプロキシを経由する場合にのみ使用します。
  config.assume_ssl = true # TLS を終端するプロキシの背後にある場合

  # 想定外の Host ヘッダーを持つリクエストを拒否します。
  config.hosts << "example.com"
  config.hosts << /.*\.example\.com/

  config.action_dispatch.cookies_same_site_protection = :lax
  config.log_level = :info
end
```

機密性の高い値をログから除外します。

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += %i[
  passw secret token _key crypt salt certificate otp ssn cvv card_number
]
```

## 認証

Rails 8 には、パスワードリセットとメタデータ追跡を備えたセッションベースの認証を生成する認証ジェネレーターが付属しています。

```bash
bin/rails generate authentication
```

OAuth、MFA、confirmable、lockable、または複数モデルの認証が必要な場合は Devise を使用します。自前で認証を実装する場合は、`has_secure_password` が bcrypt によるハッシュ化を処理します。

```ruby
class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
```

`authenticate_by` は検索と検証を 1 回の呼び出しで行うため、ユーザーが存在しない場合とパスワードが誤っている場合で所要時間が同じになります。

```ruby
# 悪い例: 処理時間の差から、メールアドレスが存在するかどうかが分かってしまう
user = User.find_by(email: params[:email])
if user&.authenticate(params[:password])

# 良い例
user = User.authenticate_by(email: params[:email], password: params[:password])
```

サインイン時と、権限が変わるたびにセッションをローテーションします。

```ruby
class SessionsController < ApplicationController
  def create
    user = User.authenticate_by(email: params[:email], password: params[:password])
    return render :new, status: :unprocessable_entity unless user

    reset_session
    session[:user_id] = user.id
    redirect_to root_path
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end
```

### アカウント復旧

パスワードリセットトークンは、有効期限があり、1 回限りで、アカウントが存在するかどうかを明かさないものでなければなりません。モデルが生成する署名付きトークンは、この両方を満たします。

```ruby
class User < ApplicationRecord
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10) # パスワードが変更されるとトークンが無効になる
  end
end

user = User.find_by_token_for(:password_reset, params[:token])
```

アドレスが一致したかどうかにかかわらず、同じレスポンスを返します。

## 認可

認証は認可ではありません。レコードに触れるすべてのアクションで、現在のユーザーがそのレコードを操作してよいかをチェックする必要があります。

```ruby
# 悪い例: サインイン済みのユーザーなら誰でもすべての請求書を読み込める
@invoice = Invoice.find(params[:id])

# 良い例: 所有者を経由してスコープする
@invoice = current_user.invoices.find(params[:id])
```

所有権を超える判定には、ポリシーオブジェクト（Pundit、Action Policy、または CanCanCan）を使用します。

```ruby
class InvoicePolicy < ApplicationPolicy
  def update?
    user.admin? || record.user_id == user.id
  end
end

class InvoicesController < ApplicationController
  def update
    @invoice = Invoice.find(params[:id])
    authorize @invoice
    # ...
  end
end
```

フェイルクローズにします。各アクションが認可の呼び出しを忘れないことに頼るのではなく、認可が実行されたことを検証します。

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization

  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
end

# 公開アクションには認可すべきレコードがないため、明示的に除外します。
class SessionsController < ApplicationController
  skip_after_action :verify_authorized
end
```

## Strong Parameters とマスアサインメント

生の `params` をモデルに渡してはいけません。明示的なリストを permit します。

```ruby
# 悪い例: 細工されたリクエストで admin を設定できてしまう
User.new(params[:user])

# 良い例
def user_params
  params.require(:user).permit(:email, :name)
end
```

Rails 8 では `expect` が追加されました。これは、構造が不正な場合に空のハッシュを返す代わりに例外を発生させます。

```ruby
def user_params
  params.expect(user: [:email, :name])
end
```

`admin`、`role`、`user_id`、`account_id` などの属性は、リクエストデータで駆動される permit リストに決して含めてはいけません。これらはセッションまたは検証済みのポリシーから明示的に代入します。

## SQL インジェクション

Active Record はデフォルトでパラメータ化を行います。インジェクションは、文字列を手作業で組み立てたときに発生します。

```ruby
# 悪い例
User.where("email = '#{params[:email]}'")
Order.order("#{params[:sort]} #{params[:dir]}")

# 良い例
User.where(email: params[:email])
User.where("email = ?", params[:email])
```

`order`、`pluck`、`group`、`select` は生の SQL を受け付け、サニタイズされません。入力はエスケープするのではなく、許可リストで制限します。

```ruby
SORTABLE = { "created_at" => "created_at", "total" => "total" }.freeze
DIRECTIONS = { "asc" => "ASC", "desc" => "DESC" }.freeze

column = SORTABLE.fetch(params[:sort], "created_at")
direction = DIRECTIONS.fetch(params[:dir], "DESC")
Order.order(Arel.sql("#{column} #{direction}"))
```

`%` と `_` はワイルドカードなので、`LIKE` には専用のエスケープが必要です。

```ruby
term = User.sanitize_sql_like(params[:q])
User.where("name LIKE ?", "%#{term}%")
```

## XSS と出力エスケープ

ERB は、埋め込まれた値をデフォルトでエスケープします。エスケープを回避する記述はすべて、セキュリティ上慎重な扱いが必要です。

```erb
<%# 悪い例: 攻撃者が制御するマークアップをそのまま描画する %>
<%= @comment.body.html_safe %>
<%= raw @comment.body %>

<%# 良い例: エスケープされる %>
<%= @comment.body %>

<%# 良い例: フィールドが本当にリッチテキストである場合は、許可リストで制限したマークアップ %>
<%= sanitize @comment.body, tags: %w[p br strong em a], attributes: %w[href] %>
```

`html_safe` はサニタイズしません。文字列を「すでに安全」とマークしてエスケープを省略するだけです。自分で組み立てた文字列にのみ呼び出してください。

JavaScript に埋め込む場合は、HTML 用ではなく、それに対応したエスケープが必要です。

```erb
<script>
  const payload = <%= raw @data.to_json %>;              // 悪い例
  const payload = <%= raw json_escape(@data.to_json) %>; // 良い例
</script>
```

`link_to` の href は `javascript:` URL を受け付けるため、ユーザーが指定したリンクは検証します。

```ruby
uri = URI.parse(url) rescue nil
safe = uri.is_a?(URI::HTTP) # URI::HTTPS は URI::HTTP のサブクラス
```

Content Security Policy を設定します。

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    policy.object_src  :none
    policy.frame_ancestors :none
  end
end
```

## CSRF

Rails は新規アプリで CSRF 保護を有効にします。有効のままにし、クライアントを動かすためにアクションを除外してはいけません。

```ruby
# 悪い例: コントローラー内のすべてのアクションで保護が無効になる
skip_before_action :verify_authenticity_token
```

エンドポイントが本当にトークンを運べない場合（たとえばサードパーティの Webhook）は、別の方法（署名検証）で認証し、除外はそのアクションのみにスコープします。

`ActionController::API` を継承する API 専用コントローラーには Cookie セッションがないため、CSRF は適用されません。トークンまたはセッション Cookie を使う API には、引き続き CSRF 対策が必要です。

## ファイルアップロード

クライアントが送信する `content_type` は攻撃者が制御できる値であり、`blob.content_type` はその代わりにはなりません。Active Storage はこのカラムを `Marcel::MimeType.for` で導出しますが、これはクライアントが宣言した型をマジックバイト検出と並ぶ候補の 1 つとして扱い、バイト列がどの既知の型にも一致しない場合はそのまま保持します。そのため、`image/png` と宣言された不透明なバイト列は `image/png` として保存され、`identified?` も true になります。保存されたバイト列は自分で検査してください。

```ruby
module Uploads
  Rejected = Class.new(StandardError)

  MAGIC = {
    "application/pdf" => "%PDF-".b,
    "image/png" => "\x89PNG\r\n\x1a\n".b,
    "image/jpeg" => "\xFF\xD8\xFF".b
  }.freeze
  ALLOWED_EXTENSIONS = %w[.pdf .png .jpg .jpeg].freeze
  MAX_BYTES = 10.megabytes

  def self.verified!(blob)
    # フェイルクローズ: 存在しない、またはまだ保留中のオブジェクトは検査できない。
    raise Rejected, "could not be verified" unless blob.service.exist?(blob.key)
    raise Rejected, "is too large" if blob.byte_size > MAX_BYTES

    extension = File.extname(blob.filename.to_s).downcase
    raise Rejected, "extension not allowed" unless ALLOWED_EXTENSIONS.include?(extension)

    head = blob.service.download_chunk(blob.key, 0...8)
    raise Rejected, "type not allowed" unless MAGIC.any? { |_mime, magic| head.start_with?(magic) }

    blob
  end
end
```

このチェックはストレージから読み取るため、バイト列がすでに存在する場所で実行する必要があります。フォームアップロードは、モデルのバリデーションが実行される時点ではまだストレージにありません（Active Storage は保存時にアップロードします）。そのため、先に明示的にアップロードし、検証を通過したものだけをアタッチします。

```ruby
# フォームアップロード
blob = ActiveStorage::Blob.create_and_upload!(io: params[:file], filename: params[:file].original_filename)
document.file.attach(Uploads.verified!(blob))

# ダイレクトアップロード: クライアントがすでにオブジェクトを保存しているため、
# レコードがそれを指す前に検証する。
document.file.attach(Uploads.verified!(ActiveStorage::Blob.find_signed!(params[:file])))
```

プライベートなサービスにアタッチします。パブリックなバケットでは、上記のチェックにかかわらず、すべてのアップロードが誰でも読み取れる状態になります。

```ruby
has_one_attached :file, service: :private_documents
```

`rails_blob_url` と `url_for(attachment)` は有効期限のない安定した参照であり、有効期限の短いサービス URL にリダイレクトします。そのため、これらを持つ人は誰でもアクセスし続けられます。ユーザー単位のファイルは、リクエストごとに認可を行う自前のコントローラーから配信し、`config.active_storage.draw_routes = false` を設定します。これにより Active Storage のデフォルトルートがすべて削除されるため、ダイレクトアップロードを使うアプリには代替ルートが必要です。

```ruby
get "documents/:id/file", to: "document_files#show", as: :document_file
# Rails のダイレクトアップロードエンドポイントには、それ自体の認証がありません。この例では
# 自前実装のセッションサインインを使用しています。Devise や Rails 8 ジェネレーターの
# 場合は、それぞれの同等の仕組みを参照してください。
constraints ->(req) { req.session[:user_id].present? } do
  post "uploads", to: "active_storage/direct_uploads#create", as: :rails_direct_uploads
end

class DocumentPolicy < ApplicationPolicy
  def show?
    record.user_id == user.id
  end
end

class DocumentFilesController < ApplicationController
  def show
    document = current_user.documents.find(params[:id])
    authorize document, :show?
    redirect_to document.file.blob.url(expires_in: 5.minutes), allow_other_host: true
  end
end
```

ユーザーが指定したパスを `send_file` に埋め込んではいけません。

```ruby
# 悪い例: パストラバーサル
send_file Rails.root.join("storage", params[:name])
```

## API セキュリティ

認証および悪用されやすいその他のエンドポイントにはレート制限を設けます。Action Controller は Rails 7.2 から `rate_limit` を提供しています。7.1 の場合やアプリ全体のスロットリングには `rack-attack` を使用します。

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create
end
```

Webhook の署名は、定数時間の比較で検証します。

```ruby
class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    expected = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("WEBHOOK_SECRET"), request.raw_post)
    given = request.headers["X-Signature"].to_s

    unless ActiveSupport::SecurityUtils.secure_compare(expected, given)
      return head :unauthorized
    end

    event_id = JSON.parse(request.raw_post).fetch("id")
    delivery = WebhookDelivery.create_or_find_by!(provider: "billing", delivery_id: event_id)
    return head :ok if delivery.processed_at?

    ProcessWebhookJob.perform_later(delivery.id, request.raw_post)
    head :ok
  end
end
```

```ruby
add_index :webhook_deliveries, %i[provider delivery_id], unique: true
```

ジョブは完了時に `processed_at` を記録します。ジョブはリトライされるため、同じ理由で `perform` は冪等でなければなりません。署名された本文に安定した ID が含まれている必要があります。

CORS は狭く保ちます。認証情報とあわせて任意のオリジンを反映してはいけません。

```ruby
# 悪い例
origins "*"

# 良い例
origins "https://app.example.com"
```

レスポンスは明示的にシリアライズし、新しいカラムが漏れないようにします。

```ruby
# 悪い例: 後から追加されたものを含め、すべてのカラムを返してしまう
render json: @user

# 良い例
render json: @user.as_json(only: %i[id name created_at])
```

## シークレットとクレデンシャル

シークレットは、Rails クレデンシャル、環境変数、またはシークレットマネージャーに置きます。

```bash
bin/rails credentials:edit --environment production
```

`config/credentials/production.key` はバージョン管理から除外しておく必要があります。シークレットは `Rails.application.credentials` または `ENV.fetch` で読み取ります。`ENV[...]` は変数が存在しない場合に `nil` を返し、エラーにならずに黙って失敗します。

```ruby
# 悪い例
ENV["STRIPE_SECRET"]

# 良い例
Rails.application.credentials.dig(:stripe, :secret)
ENV.fetch("STRIPE_SECRET")
```

キーが一度でもコミットされた場合は、ローテーションしてください。コミットを削除しても、露出がなかったことにはなりません。

## 信頼できない境界

コントローラーの params だけが入口ではありません。ジョブの引数、Webhook ペイロード、Action Cable メッセージ、Turbo Stream のターゲットはすべて、外部からのデータを運びます。

- ジョブにはレコード ID を渡し、`perform` の中で再スコープします。キューに入ったジョブは、元のリクエストのセッションなしで実行されます。
- `ApplicationCable::Connection` と、各チャンネルの `subscribed` で認可します。
- ユーザー入力から Turbo Stream のターゲットを組み立ててはいけません。

```ruby
class ExportJob < ApplicationJob
  def perform(user_id, invoice_id)
    user = User.find(user_id)
    invoice = user.invoices.find(invoice_id) # スコープ済み。Invoice.find ではない
    # ...
  end
end
```

## 依存関係のスキャン

ロックファイルが変わったときと CI で、次を実行します。

```bash
bundle exec bundle-audit check --update
bundle exec brakeman --no-progress
```

Brakeman は上記のパターンを静的に検出します。新しい警告はブロッキングとして扱い、意図的な例外は、信頼度のしきい値を下げるのではなく、理由を添えて `config/brakeman.ignore` に記録します。

## 検証チェックリスト

- [ ] 本番環境で `force_ssl` と `config.hosts` が設定されている
- [ ] 機密性の高いパラメータがログからフィルタされている
- [ ] サインイン時と権限変更時にセッションがローテーションされている
- [ ] すべてのレコード検索が現在のユーザーにスコープされているか、ポリシーでチェックされている
- [ ] どの permit リストにも、ロール、所有権、アカウントのカラムが含まれていない
- [ ] 生の SQL 文字列の埋め込みがなく、`order` と `pluck` の入力が許可リストで制限されている
- [ ] すべての `html_safe` と `raw` がレビューされている
- [ ] CSRF の除外が、別の認証メカニズムを備えた特定のアクションにスコープされている
- [ ] アップロードが `blob.content_type` ではなく保存済みバイト列に対して検証され、オブジェクトが利用できない場合はフェイルクローズする
- [ ] 認証エンドポイントにレート制限があり、Webhook 署名が定数時間で比較されている
- [ ] バージョン管理にシークレットがなく、マスターキーが除外されている
- [ ] `bundle-audit` と `brakeman` がクリーンである

## 関連スキル

- `rails-patterns` — これらの制御が組み込まれるアーキテクチャパターン
- `security-review` — 言語横断のセキュアバイデフォルトなレビューパターン
- Ruby セキュリティルール（`rules/ruby/security.md`。`rules/ecc/ruby/security.md` としてインストールされます）
  — このスキルが実装する判断と使用ガイダンス
