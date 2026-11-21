---
name: rails-patterns
description: Rails 7.1+ および 8.x アプリ向けの Ruby on Rails フレームワークパターン。ディレクトリ規約、サービスオブジェクトによる薄いコントローラー、フォームオブジェクト、クエリオブジェクト、慣用的な ActiveRecord、バックグラウンドジョブ、ViewComponent、Hotwire、Rails 8 の Solid スタックを扱います。Rails アプリ、コントローラー、モデル、サービス、ジョブ、ビューを構築またはレビューするときに使用します。
origin: community
---

# Rails パターン

モダンな Ruby on Rails アプリケーション（Rails 7.1+ および 8.x）向けのフレームワークパターンです。Rails は設計思想として強い意見を持つフレームワークであり、ここで紹介するのは、モデル数が 50 を超えても保守性を保てるアプリのためにコミュニティが行き着いたパターンです。このスキルは「どのように」を扱います。「何を」「いつ」（どのパターンを選ぶかの判断）については、Ruby パターンルール、つまりこのリポジトリの `rules/ruby/patterns.md`（`rules/ecc/ruby/patterns.md` としてインストールされます）を参照してください。

## 有効化するタイミング

- Rails アプリケーション（フルスタック、API 専用、またはハイブリッド）を構築するとき
- `app/` または `config/` に触れる PR をレビューするとき
- モデル、コントローラー、サービス、ジョブを生成するとき
- コントローラーのアクションが約 10 行を超えたとき
- モデルファイルが約 200 行を超えたとき
- ActiveRecord のクエリがコントローラーやビューに現れ始めたとき

## コアコンセプト

### ディレクトリ規約

Rails アプリは予測可能な構造に従います。ディレクトリは気軽にではなく、意図的に追加してください。

```
app/
  models/         ActiveRecord モデル。データに近い永続化とドメインロジック。
  controllers/    HTTP リクエストの処理。薄い調整のみ。
  views/          ERB テンプレート。ビジネスロジックなし。
  components/     ViewComponent クラス。テストが必要なビューロジック。
  services/       サービスオブジェクト。複数ステップのビジネス処理。
  forms/          フォームオブジェクト。複数モデルにまたがる複雑なフォーム処理。
  queries/        クエリオブジェクト。再利用可能で合成可能な ActiveRecord クエリ。
  jobs/           バックグラウンドジョブ。Solid Queue、Sidekiq、GoodJob による非同期処理。
  mailers/        ActionMailer クラス。
  helpers/        ビューヘルパー。ごく小さな表示ロジックのみ。
  policies/       認可ポリシー（Pundit を使う場合）。任意。
  channels/       WebSocket 処理のための ActionCable チャネル。
```

`app/lib/`、`app/utils/`、`app/managers/` は避けてください。上記のディレクトリに収まらないものがある場合、たいていは新しいディレクトリを作るのではなく設計を見直す必要があります。本当に汎用的なコードは `lib/` に置きます。

### 薄いコントローラー

コントローラーはリクエストを受け取り、適切なオブジェクトに委譲し、レスポンスをレンダリングします。ビジネスロジックは別の場所に置きます。（Ruby パターンルールに従い、コントローラーが複数の責務を負い始めたらサービスオブジェクトに抽出します。）

### サービスオブジェクト

単一モデルの保存を超えるビジネス操作のデフォルトの選択肢です。一貫性を保つための規約は次のとおりです。

- サフィックス（`InvoiceCreator`）ではなく、ドメインで名前空間を切ります（`Invoices::Create`）。
- クラスメソッド `.call` がインスタンスの `#call` に委譲します。
- 真偽値や素のレコードではなく Result オブジェクトを返し、呼び出し側が成功、エラー、対象レコードで分岐できるようにします。
- 複数レコードへの書き込みはトランザクションで包みます。
- 各サービスは単一目的に保ちます（`Invoices::Create`、`Invoices::MarkPaid`）。`Invoices::Manager` のようなものは作りません。

### フォームオブジェクト

フォームが複数のモデルにまたがる場合や、カラムに対応しないフィールドがある場合は、ネスト属性（nested attributes）や不適切なモデル上の仮想属性ではなく、フォームオブジェクトを使います。ビューからはモデルのように振る舞い（`form_with model: @form`）つつ、レコードをきれいに組み合わせられます。

### クエリオブジェクト

複数のコントローラーやサービスで再利用される ActiveRecord クエリ、またはスコープでは複雑すぎるクエリは、スコープを入力として受け取るクエリオブジェクトに抽出し、合成できるようにします。経験則として、チェーンされた条件が 3 つを超える、またはパラメーターを取り始めたスコープは、クエリオブジェクトにすべきです。

### バックグラウンドジョブ

遅い処理はすべてオフロードします。（Ruby パターンルールに従い、スループットが控えめな新規 Rails 8 プロジェクトには Solid Queue、成熟した可観測性や高スループットが必要な場合、または既存の Redis がある場合は Sidekiq を使います。）アダプターに関係なく、レコードではなく ID を渡し、`perform` を冪等にし、`retry_on`/`discard_on` を明示的に設定してください。

### パーシャルより ViewComponent

条件付きレンダリングがある、引数が 2 つを超える、または 3 か所を超えて再利用されるビューロジックには、ViewComponent を優先します。コンポーネントは単独でテストでき、インターフェースが明示されます。深い条件ロジックを持つパーシャルは負債になります。

### Hotwire: Turbo と Stimulus

Rails のデフォルトのフロントエンドスタックです。（Ruby パターンルールに従い、サーバーレンダリングのアプリでは Hotwire を優先し、インタラクションの複雑さがクライアント側の領域を正当化する場合にのみ React/Vue を選びます。）部分的なページ更新には Turbo Frames、サーバー駆動の更新には Turbo Streams、マークアップの隣に置く小さなクライアント側の振る舞いには Stimulus を使います。

### Rails 8 の Solid スタック

Rails 8 は、以前は Redis を必要としていたものについて、データベースをバックエンドとするデフォルトを同梱しています。Solid Queue（ジョブ）、Solid Cache（キャッシュ）、Solid Cable（ActionCable）です。トレードオフは、インフラコンポーネントが 1 つ減る代わりにデータベース負荷が増えることです。スループットが控えめな場合には適していますが、大規模では引き続き Redis が優位です。Kamal はデフォルトの Docker ベースのデプロイツールです。

## コード例

### サービスオブジェクトを使った薄いコントローラー

```ruby
# Bad: コントローラーにビジネスロジックがある
class InvoicesController < ApplicationController
  def create
    @invoice = Invoice.new(invoice_params)
    @invoice.user = current_user
    @invoice.line_items.build(invoice_params[:line_items])
    @invoice.tax_total = TaxCalculator.new(@invoice).calculate
    @invoice.total = @invoice.line_items.sum(&:amount) + @invoice.tax_total

    if @invoice.save
      InvoiceMailer.created(@invoice).deliver_later
      AccountingExportJob.perform_later(@invoice.id)
      redirect_to @invoice, notice: "Invoice created"
    else
      render :new
    end
  end
end

# Good: コントローラーは調整のみ行い、サービスが処理を行う
class InvoicesController < ApplicationController
  def create
    result = Invoices::Create.call(params: invoice_params, user: current_user)

    if result.success?
      redirect_to result.invoice, notice: "Invoice created"
    else
      @invoice = result.invoice
      render :new, status: :unprocessable_entity
    end
  end
end
```

### サービスオブジェクト

```ruby
# app/services/invoices/create.rb
module Invoices
  class Create
    # Struct を使うと、Rails 7.1 がサポートするすべての Ruby で動作します。
    # Ruby 3.2 以降では、`Data.define(:success?, :invoice, :errors)` の方が
    # 簡潔なイミュータブルの代替手段です。
    Result = Struct.new(:success, :invoice, :errors, keyword_init: true) do
      def success?
        success
      end
    end

    def self.call(params:, user:)
      new(params: params, user: user).call
    end

    def initialize(params:, user:)
      @params = params
      @user = user
    end

    def call
      invoice = build_invoice
      ApplicationRecord.transaction do
        invoice.save!
      end
      begin
        send_notifications(invoice)
      rescue StandardError => e
        Rails.logger.error("Notification dispatch failed for invoice #{invoice.id}: #{e.message}")
      end
      Result.new(success: true, invoice: invoice, errors: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, invoice: e.record, errors: e.record.errors)
    end

    private

    attr_reader :params, :user

    def build_invoice
      invoice = user.invoices.new(params.except(:line_items))
      invoice.line_items.build(params[:line_items])
      invoice.tax_total = TaxCalculator.call(invoice)
      invoice.total = invoice.line_items.sum(&:amount) + invoice.tax_total
      invoice
    end

    def send_notifications(invoice)
      InvoiceMailer.created(invoice).deliver_later
      AccountingExportJob.perform_later(invoice.id)
    end
  end
end
```

### フォームオブジェクト

```ruby
# app/forms/signup_form.rb
class SignupForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :email, :string
  attribute :password, :string
  attribute :company_name, :string
  attribute :terms_accepted, :boolean

  validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP
  validates :password, presence: true, length: { minimum: 12 }
  validates :company_name, presence: true
  validates :terms_accepted, acceptance: true

  attr_reader :user, :company

  def save
    return false unless valid?

    ApplicationRecord.transaction do
      @company = Company.create!(name: company_name)
      @user = @company.users.create!(email: email, password: password, role: :owner)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.merge!(e.record.errors)
    false
  end
end
```

### クエリオブジェクト

```ruby
# app/queries/invoices/overdue.rb
module Invoices
  class Overdue
    def self.call(scope: Invoice.all, as_of: Time.current)
      new(scope: scope, as_of: as_of).call
    end

    def initialize(scope:, as_of:)
      @scope = scope
      @as_of = as_of
    end

    def call
      scope
        .where(status: :sent)
        .where(due_date: ..as_of)
        .where.not(id: paid_invoice_ids)
        .includes(:customer, :line_items)
    end

    private

    attr_reader :scope, :as_of

    def paid_invoice_ids
      Payment.where(created_at: ..as_of).pluck(:invoice_id)
    end
  end
end
```

クエリオブジェクトはスコープを受け取るため、合成できます: `Invoices::Overdue.call(scope: current_user.invoices)`。

### N+1 の防止

```ruby
# Bad: ビューで post.author.name を呼ぶと N+1 になる
@posts = Post.published

# Good: eager load する
@posts = Post.published.includes(:author)
```

`includes` は preload と eager_load のどちらを使うかを Rails に選ばせます。別々のクエリにしたい場合は `preload` を、関連で絞り込む際に JOIN を使いたい場合は `eager_load` を強制してください。Rails 6.1 以降、`strict_loading` は意図しない遅延ロードで例外を発生させます。

### カウンターキャッシュ

```ruby
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end
```

```ruby
add_column :posts, :comments_count, :integer, default: 0, null: false
```

`post.comments_count` は `COUNT(*)` ではなくカラムの読み取りになります。この例は新しいテーブルを前提としています。すでに行があるテーブルにカウンターキャッシュを追加するにはバックフィルが必要ですが、ここでは対象外です。

### バックグラウンドジョブの形

レコードではなくレコード ID を渡します。リトライによって配信は at-least-once になるため、外部サービスを呼び出すジョブは冪等でなければなりません。そうでないと、リモート呼び出しが成功した後に一時的な失敗が起きた場合、次の試行で効果が重複します。

```ruby
class AccountingExportJob < ApplicationJob
  queue_as :exports

  retry_on AccountingApi::TransientError, wait: :polynomially_longer, attempts: 5
  discard_on AccountingApi::PermanentError

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)
    export = AccountingExport.create_or_find_by!(
      invoice: invoice,
      idempotency_key: "invoice-export-#{invoice.id}-#{invoice.updated_at.to_i}"
    )
    return if export.completed_at?

    receipt = AccountingApi.export(invoice, idempotency_key: export.idempotency_key)
    export.update!(completed_at: Time.current, external_id: receipt.id)
  end
end
```

```ruby
add_index :accounting_exports, :idempotency_key, unique: true
```

安全性を支えているのはユニークインデックスです。2 つの試行が競合した場合、データベースが 2 番目の挿入を拒否し、Active Record がその衝突を呼び出しの内部で解決して既存の行を返します。これはジョブ単位のリトライなしで行われます。上の `retry_on` がカバーするのは `AccountingApi::TransientError` のみです。このガードはリモート呼び出しの前の区間をカバーし、`idempotency_key` を API まで渡すことでその後の区間をカバーします。そのため、API 呼び出しと `update!` の間でクラッシュしても、エクスポートは 1 件に収束します。

### ViewComponent

```ruby
# app/components/invoice_status_badge_component.rb
class InvoiceStatusBadgeComponent < ViewComponent::Base
  STATUS_CLASSES = {
    draft: "bg-gray-100 text-gray-800",
    sent: "bg-blue-100 text-blue-800",
    paid: "bg-green-100 text-green-800",
    overdue: "bg-red-100 text-red-800"
  }.freeze

  def initialize(invoice:)
    @invoice = invoice
  end

  def call
    tag.span(@invoice.status.humanize, class: "rounded-full px-2 py-1 text-sm #{status_class}")
  end

  private

  def status_class
    STATUS_CLASSES.fetch(@invoice.status.to_sym, "bg-gray-100")
  end
end
```

```erb
<%= render InvoiceStatusBadgeComponent.new(invoice: @invoice) %>
```

### Hotwire

```erb
<%# Turbo Frame: Edit をクリックすると、このフレームだけが置き換わる %>
<%= turbo_frame_tag "invoice_#{@invoice.id}" do %>
  <div class="invoice">
    <%= link_to "Edit", edit_invoice_path(@invoice) %>
  </div>
<% end %>
```

```erb
<%# Turbo Stream: app/views/comments/create.turbo_stream.erb %>
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.update "comment_form", partial: "form", locals: { comment: Comment.new } %>
```

```javascript
// app/javascript/controllers/copy_to_clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)
  }
}
```

### 許容されるコールバックと許容されないコールバック

```ruby
# 許容される: 純粋なデータの正規化
class User < ApplicationRecord
  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end

# 代わりにサービスへ移す: コールバックに副作用が隠れている
# class User < ApplicationRecord
#   after_create :send_welcome_email  # 回避しにくく、テストしにくい
# end
```

### 良い concern と悪い concern

```ruby
# Good: 真に横断的で、無関係なモデル間で再利用できる
# app/models/concerns/soft_deletable.rb
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  def soft_delete! = update!(deleted_at: Time.current)
  def restore! = update!(deleted_at: nil)
end

# Bad: 1 つのモデルだけが使う「concern」で、そのモデルに属するロジックを保持している
# app/models/concerns/invoice_calculations.rb
module InvoiceCalculations
  extend ActiveSupport::Concern

  def calculate_total
    line_items.sum(&:amount) + tax_total
  end
end
# これを include するのは Invoice だけです。横断的ではなく、Invoice 自身のロジックを
# 「薄い」モデルに見せかけるためにモジュールへ隠しているだけです。Invoice に戻してください。
```

1 つのクラスだけが使う concern は、単にコードを別の場所へ移しているだけです。そのコードはそのクラスに置くべきです。concern は、少なくとも 2 つの無関係なモデルにまたがって再利用できるものであるべきです。

## アンチパターン

### ゴッドコントローラー（God controllers）

約 80 行を超えるコントローラーは、責務を負いすぎています。アクションを複数のコントローラーに分割するか、サービスに抽出してください。

### 30 以上のメソッドを持つ肥大化したモデル

モデルは自身のデータについて知っているべきです。他のモデルを調整したり、通知を送ったり、ワークフローを統括したりするメソッドは、サービスに属します。

### コールバックチェーン

`after_save :update_cache, :send_notifications, :enqueue_export` は、デバッグの悪夢の始まりです。それらを明示的に実行するサービスに移してください。

### 複雑なフォームでのネスト属性

`accepts_nested_attributes_for` は単純なケースでは問題ありません。条件付きバリデーションやモデルをまたぐロジックには、フォームオブジェクトを使ってください。

### 重要なモデルでの default scope

`default_scope { where(deleted: false) }` は、サポートやデバッグで必要になるものも含め、アプリ内のすべてのクエリからレコードを黙って除外します。明示的な名前付きスコープを優先してください。

### データベースの概念にちなんだ名前のモデル

`UserRole`、`OrderStatus`、`InvoiceState` は、たいていモデルではなく enum の候補です。

### Hotwire より先に JS フレームワークに手を出す

ページがサーバーレンダリングで、たまにインタラクティブな要素がある程度なら、Hotwire のほうが早く出荷できます。React/Vue は、本当に SPA 的なアプリのために取っておきましょう。

## ベストプラクティス

- コントローラーは薄く保ち、ビジネスロジックはサービスに移します。
- サービスから Result オブジェクトを返し、呼び出し側が例外ではなく結果で分岐できるようにします。
- 複数レコードへの書き込みはトランザクションで包みます。通知や副作用の失敗は、主たる書き込みを壊さずにログに記録します。
- ジョブには ID を渡し、`perform` を冪等に保ち、retry/discard を明示的に設定します。
- eager loading をデフォルトにします。意図しない N+1 は、軽い不都合ではなくバグとして扱います。
- concern は、少なくとも 2 つの無関係なモデルで共有される振る舞いのために取っておきます。
- サーバーレンダリングのアプリでは、クライアント側フレームワークより先に Hotwire を検討します。

## 関連スキル

- `backend-patterns` — サービス境界とアダプターパターン（Ruby パターンルールから参照されています）
- Ruby パターンルール（`rules/ruby/patterns.md`、`rules/ecc/ruby/patterns.md` としてインストールされます）— このスキルが実装する、判断基準と使いどころのガイダンス
