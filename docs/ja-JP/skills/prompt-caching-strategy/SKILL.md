---
name: prompt-caching-strategy
description: >-
  LLM のプロンプトキャッシュヒット率を最適化し、API コストの削減とレイテンシの改善を図ります。
  プロンプト構造を分析し、キャッシュ可能なコンテンツと不可能なコンテンツを識別し、
  キャッシュ再利用を最大化するための再構成を提案します。
  TRIGGER when: ユーザーが "prompt cache"、"cache hit rate"、"reduce LLM cost"、
  "optimize token usage"、"cheaper LLM calls" と言った場合、または OpenAI/Anthropic/その他の
  プロバイダーのプロンプトキャッシュ戦略について尋ねた場合。
  DO NOT TRIGGER when: ユーザーが単一プロンプトの品質を最適化したいだけの場合
  （代わりに prompt-optimizer を使用）、または一般的なキャッシュ基盤について尋ねた場合。
metadata:
  origin: community
  author: cyberspace-cs
  version: "1.0.0"
---

# プロンプトキャッシュ戦略

再利用可能なプロンプトコンテンツを配置し直してキャッシュの再利用を改善し、その上で入力コストとレイテンシを測定します。削減効果は、モデル、プラットフォーム、キャッシュ適格性、書き込み、保持期間、再利用、出力量に依存します。このスキルにおける実行時のキャッシュヒットと削減効果は**未測定**です。以下の例は、プロバイダー呼び出しなしで算術のみを検証するものです。

## 有効化するタイミング

認可済みの指示、ツール、参照資料を共有する、繰り返し発生する API リクエストに使用します。まず、正確なプロバイダーのエンドポイント、モデル、サービスティア、キャッシュモードを特定します。料金、最小プレフィックス長、保持期間を選択する前に、最新のドキュメントを参照してください。キャッシュはコンテキストウィンドウの使用量を減らしません。

## 仕組み

### 安定したプレフィックスを維持する

再利用可能な指示、ツールスキーマ、例は安定させておき、変化する質問、タイムスタンプ、取得結果は、API が許す範囲でそれらの後ろに配置します。プロバイダーのシリアライズ順序を尊重してください。Claude は tools、system、messages の順に使用します。プレフィックスが一致するには、ツールスキーマや関連するリクエスト設定を含め、内容が同一である必要があります。プレフィックスが変更されると、その箇所以降は再利用できなくなる可能性があります。動的なサフィックスも、変更されずに再利用されるなら、後でキャッシュされることがあります。

```text
Reusable prefix: approved tools, instructions, stable examples/reference
Changing suffix: current question, fresh retrieval results, request metadata
```

関連するコンテキストのみを選択します。適格性のしきい値を満たすためだけにプロンプトを水増ししたり、アクセス範囲を広げたりする場合は、それ自体のコストと品質の正当化が必要です。

### ユーザーとワークスペースの境界を維持する

キャッシュの参照や再利用の前に、コンテンツへのアクセスを認可します。アプリケーション管理のキャッシュハンドルと集計キーは、承認されたユーザー、ワークスペース、プロバイダーアカウント、モデル、コンテンツリビジョンにスコープを限定します。そのスコープ向けに明示的に承認された資料のみを共有します。キャッシュキーはルーティング／集計のヒントであり、認可ゲートでもサンドボックスでもありません。プロバイダーのキャッシュ分離は、アプリケーションのアクセスチェックの代わりにはなりません。権限やコンテンツが変更されたときは、アプリケーションの参照を無効化し、プロバイダーの保持／削除コントロールに従ってください。プライベートなプロンプト内容をログに記録しないでください。コンテキストの選択、ケイパビリティ、サンドボックスの強制、エビデンスは、キャッシュ最適化とは独立したものとして維持します。

## プロバイダーの要件と使用状況のエビデンス

リンク先のドキュメントが正式な情報源です。エンドポイントや SDK のバージョンによって、使用状況のフィールド名が異なる場合があります。そのバージョンをカウンターと併せて記録してください。

| プロバイダー | 確認すべき要件 | 記録すべきカウンター |
| --- | --- | --- |
| OpenAI | モデル固有の自動／明示モード、最小長、保持期間、書き込み／読み取り料金。旧モデルと新モデルで異なる | Responses の `usage.input_tokens_details.cached_tokens` および、存在する場合は `cache_write_tokens`、入力と出力の合計。Chat Completions は `prompt_tokens_details.cached_tokens` を使用 |
| Claude | 対応プラットフォーム、モデルの最小値、`cache_control` のサポートと TTL。キャッシュ書き込みは通常の入力より高コストになる場合がある | `input_tokens`、`cache_creation_input_tokens`、`cache_read_input_tokens`、`output_tokens`。料金が異なる場合は TTL ごとに書き込みを分割 |
| Gemini | モデルの最小値と API。Interactions は暗黙的キャッシュをサポートし、明示的なキャッシュオブジェクトには GenerateContent が必要 | Interactions の `usage.total_cached_tokens`。GenerateContent の `usage_metadata` のキャッシュ／入力／出力カウンターに加え、明示的キャッシュのトークン数と保持期間 |

選択したモデルについて、[OpenAI のプロンプトキャッシュガイド](https://developers.openai.com/api/docs/guides/prompt-caching)と[料金](https://developers.openai.com/api/docs/pricing/)を参照してください。Chat Completions については、[使用状況スキーマ](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)を確認してください。通常の入力は、合計からキャッシュ読み取りと別途報告された書き込みを差し引いて導出します。同じトークンを二重に数えないでください。

現行のモデル／プラットフォームの制限と TTL の料金については、[Claude のプロンプトキャッシュガイド](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)を参照してください。その `input_tokens` は、キャッシュ読み取りおよび書き込みとは別に通常の入力を数えます。短いプレフィックスは、キャッシュ対象としてマークしていてもキャッシュカウンターがゼロになることがあります。すべての Claude モデルやホスト型プラットフォームが同じ最小値や読み取り料金を使用すると仮定しないでください。

[Gemini のキャッシュガイド](https://ai.google.dev/gemini-api/docs/caching)、[GenerateContent キャッシュガイド](https://ai.google.dev/gemini-api/docs/generate-content/caching)、[料金](https://ai.google.dev/gemini-api/docs/pricing)を参照してください。明示的キャッシュのストレージは、読み取り、通常の入力、出力とは別に、トークン数と保持期間に応じて課金されます。暗黙的なヒットは保証されません。他のプロバイダーの料金をそのまま流用せず、選択したエンドポイントの課金カテゴリを確認してください。

## コスト比較計算ツール

実際の使用量を重複しないカテゴリに正規化し、100 万トークンあたり同一通貨の料金を使用します。TTL、モダリティ、ティア、モデルによって料金が異なる場合は、書き込みカテゴリを分割します。ストレージは 100 万トークン時間（million-token-hours）を使用します。ツールやグラウンディングなど、その他の該当する料金には、それぞれ別の行が必要です。計測期間には、すべてのウォームアップ、ミス、有効期限切れ、リフレッシュ、リトライのリクエストを含めてください。

```text
baseline = (ordinary + written + read) * ordinary_input_rate / 1e6
           + output * output_rate / 1e6
actual   = ordinary * ordinary_input_rate / 1e6
           + written * cache_write_rate / 1e6
           + read * cache_read_rate / 1e6
           + output * output_rate / 1e6
           + storage_token_hours * storage_rate / 1e6
savings  = baseline - actual
```

この仮想比較（反事実）では、プロンプトと出力の量を固定します。明示的キャッシュの作成については、別途課金される作成時の入力を書き込みカテゴリに含め、エンドポイントの文書化された料金を使用します。存在しないカテゴリはゼロに設定します。ウォームアップのリクエストや出力が異なる場合は、実際の導入前後の請求書を別途比較してください。キャッシュ割引を請求総額や出力トークンに適用しないでください。

実行可能な計算ツールは、生のプロバイダーレスポンスではなく、正規化されたカウンターを受け取ります。

```javascript
function compareCacheCost(usage, rates) {
  const counts = ['uncached', 'written', 'read', 'output', 'storageTokenHours'];
  const prices = ['input', 'write', 'read', 'output', 'storage'];
  for (const [values, keys] of [[usage, counts], [rates, prices]]) {
    for (const key of keys) {
      if (!Number.isFinite(values[key]) || values[key] < 0) {
        throw new Error(`${key} must be a finite nonnegative number`);
      }
    }
  }
  const outputCost = usage.output * rates.output / 1e6;
  const storageCost = usage.storageTokenHours * rates.storage / 1e6;
  const baseline = (usage.uncached + usage.written + usage.read)
    * rates.input / 1e6 + outputCost;
  const actual = (usage.uncached * rates.input + usage.written * rates.write
    + usage.read * rates.read) / 1e6 + outputCost + storageCost;
  return { baseline, actual, savings: baseline - actual, outputCost, storageCost };
}
```

## 例

これらは仮想的な料金とカウントであり、プロバイダーの見積もりでも実測のヒットでもありません。10 回の呼び出しがそれぞれ、10,000 トークンの安定したプレフィックス、2,000 トークンの変化するサフィックス、2,000 トークンの出力を含みます。プレフィックスの書き込みは 1 回、プレフィックス全体の読み取りは 9 回と仮定します。

| カテゴリ | トークン数 | 例の料金（100 万あたり） | コスト |
| --- | ---: | ---: | ---: |
| 通常の入力 | 20,000 | $3.00 | $0.0600 |
| キャッシュ書き込み | 10,000 | $3.75 | $0.0375 |
| キャッシュ読み取り | 90,000 | $0.30 | $0.0270 |
| 出力 | 20,000 | $15.00 | $0.3000 |
| ストレージ | 0 トークン時間 | $0.00 | $0.0000 |

ベースライン: 120,000 入力トークンを $3 で計算し、同じ出力を加えて **$0.6600**。キャッシュありの場合は **$0.4245**、削減額は **$0.2355** です。書き込みのプレミアムは含まれており、出力の $0.3000 の請求額は変わりません。出力量の多いワークロードでも、これらの仮定の下では入力の削減額の絶対値は同じで、総コストに占める割合が小さくなるだけです。

明示的キャッシュが 10,000 トークンを 2 時間保持し、仮想的な 100 万トークン時間あたり $1 とする場合、ストレージ費用 **$0.0200** が加算されます。コストは **$0.4445** になります。実際の見積もりには、選択した Gemini エンドポイントの料金を使用してください。

1 回限りの呼び出しでは、そのプレフィックスの書き込みは通常の入力の $0.0300 ではなく $0.0375 かかります。つまり **$0.0075 の追加コスト**となり、読み取りによる削減はありません。選択したモデルの文書化された最小値を下回る 500 トークンのプレフィックスについては、そのリクエストをキャッシュなしとして扱ってください。カウンターなしで将来のヒットを主張すると、削減効果を過大評価することになります。キャッシュの期限切れが繰り返されたり、プレフィックスが変わり続けたりすると、期待した削減がコスト増に転じることもあります。

## 検証ワークフロー

1. 最新のドキュメントから、適格なプレフィックスのサイズとモデル／プラットフォームの要件を把握する。
2. ECC リポジトリで `node tests/skills/prompt-caching-strategy.test.js` を実行し、オフラインの例とエッジケースを確認する。
3. プロバイダーのトラフィックが認可されている場合は、一致するリクエストを比較し、承認されたユーザー／ワークスペースごとに、実際のキャッシュ済みトークン数、すべての入力カテゴリ、出力、ストレージ、レイテンシ、実現したコストを集計する。ミスや書き換えも記録する。
4. キャッシュ読み取りを総入力トークンで割った値をトークンヒット率として報告し、リクエストヒット率は別に報告する。分母とサンプリング期間を明示する。
5. トラフィックを測定していない場合は、ヒット率、レイテンシの改善、実現した削減額を未測定と明記する。オフラインの算術は、実行時のキャッシュ動作を何も立証しない。

## 他のスキルとの関係

- **prompt-optimizer** は、再利用の最適化に先立ってプロンプトの品質を改善します。
- **context-budget** は不要なコンテキストを特定します。キャッシュしてもコンテキストは消費されます。
- **cost-aware-llm-pipeline** は、キャッシュをルーティング、リトライ、その他のコストと比較します。
