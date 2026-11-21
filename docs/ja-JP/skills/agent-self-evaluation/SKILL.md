---
name: agent-self-evaluation
description: 非自明なタスクを完了した後に使用します。エージェントが自身の出力を、正確性・網羅性・明瞭性・実行可能性・簡潔性の 5 つの軸で自己評価し、各基準について具体的な根拠を示します。具体的な改善提案を含む、構造化された 1〜5 のスコアカードを作成します。
origin: ECC
---

# エージェントの自己評価

複雑なタスクを完了した後、エージェントは一度立ち止まり、構造化された 5 軸のルーブリックに照らして自身の出力を評価します。これは合否を判定するゲートではありません。ユーザーが指摘する前に、抜け漏れを見つけ、過信を指摘し、改善すべき点を洗い出すための意図的な振り返りステップです。

## 使用するタイミング

- 3 ファイル以上、または 50 行以上にまたがるコードを書いた後
- 複数ステップのワークフロー（実装 → テスト → レビュー）を完了した後
- 3 回以上の試行を要したデバッグセッションの後
- 設計ドキュメント、アーキテクチャ上の意思決定、または文章による分析を作成した後
- ユーザーが「どのくらい良かった？」や「自己評価して」と尋ねたとき
- セッション終了時の Stop フックで実行（設定されている場合。[フック連携ガイド](../../../../skills/agent-self-evaluation/references/hook-integration.md)を参照）

## 補助ファイル

- [評価基準](../../../../skills/agent-self-evaluation/references/evaluation-criteria.md) — 隣接する評価を見分けるための具体的なスコア基準
- [フック連携](../../../../skills/agent-self-evaluation/references/hook-integration.md) — オプトインの Stop および PostToolUse リマインダー
- [高スコアの例](../../../../skills/agent-self-evaluation/examples/high-score-example.md) — 完全に検証済みの評価レポート
- [低スコアの例](../../../../skills/agent-self-evaluation/examples/low-score-example.md) — 実質的なギャップを特定した評価
- [レポートテンプレート](../../../../skills/agent-self-evaluation/templates/evaluation-report.md) — そのままコピーして使えるスコアカードとスコアリングのトリガー
- [評価スクリプト](../../../../skills/agent-self-evaluation/scripts/evaluate.py) — ファイルまたはパイプで渡された出力に対する、オプションのヒューリスティックな一次チェック

## 基本概念

### 5 つの評価軸

| 軸 | 問い | 検出できるもの |
|---|---|---|
| **正確性（Accuracy）** | 事実、主張、出力は正しいか？ | ハルシネーション、誤った API 名、不正な構文、誤った記述 |
| **網羅性（Completeness）** | ユーザーが求めたことをすべてカバーしたか？ | 見落としたエッジケース、未処理のエラーパス、忘れた要件、スキップしたサブタスク |
| **明瞭性（Clarity）** | 説明は理解しやすく、適切に構成されているか？ | 分かりにくい説明、定義のない専門用語、不足しているコンテキスト、冗長な記述 |
| **実行可能性（Actionability）** | ユーザーはその出力をすぐに実行に移せるか？ | 曖昧な提案、欠けている手順、方法を示さない「X すべきです」、検証手段の欠如 |
| **簡潔性（Conciseness）** | 必要最小限の語数・トークン数で済ませたか？ | 冗長さ、過剰な説明、ユーザーの質問の逐語的な繰り返し、水増しされた内容 |

### スコアリング尺度

```
5 — 卓越: 合理的に考えられる改善の余地がない
4 — 良好: 軽微な指摘のみで、実質的なギャップはない
3 — 十分: 依頼は満たしているが、少なくとも 1 つの軸に顕著な弱点がある
2 — 弱い: 使いやすさまたは正確性に影響する明確なギャップがある
1 — 不十分: 依頼を根本的に満たしていない、または重大な誤りを含む
```

### 根拠のルール

5 未満のスコアには、必ず具体的な根拠を示す必要があります。スコア 3 の理由が単に「もっと良くできる」では不十分で、何が欠けているか、何が誤っているかを正確に述べなければなりません。合言葉は **「ギャップは名指しするだけでなく、示せ」** です。

## ワークフロー

### ステップ 1: 素材を集める

評価対象を集めます。

```
- ユーザーの元のリクエスト（会話から読み直す）
- 最終的な応答/出力（成果物）
- 正確性を検証するツール出力（テスト結果、終了コード、lint 出力）
- タスク中に受け取ったユーザーのフィードバック（修正、「やり直して」、「それは違う」）
```

### ステップ 2: 各軸を個別にスコアリングする

5 つの軸を 1 つずつ順に確認します。各軸について、次を行います。

1. 軸の問いを読む
2. 出力の中から根拠（または根拠の欠如）を探す
3. 1〜5 のスコアを付ける
4. スコアが 5 未満の場合、ギャップを挙げた 1 文の改善メモを書く

先に頭の中でスコアを平均し、そこから逆算してはいけません。各軸を新たにスコアリングしてください。

### ステップ 3: 評価レポートを作成する

[評価レポートテンプレート](../../../../skills/agent-self-evaluation/templates/evaluation-report.md)を使用します。レポートには次を含める必要があります。

```
- 1 行のサマリー
- 5 軸のスコアカード（軸ごとのスコアと根拠）
- 総合スコア（単純平均、小数第 1 位に丸める）
- 影響度順に並べた 1〜3 件の具体的な改善点
- セルフチェック: 「ユーザーはこの評価に同意するか？」
```

### ステップ 4: 改善を適用する

いずれかの軸のスコアが 3 以下の場合:

1. 何を別の方法で行うかを述べる
2. ギャップが 30 秒未満で修正できる場合（リンクの欠落、不明瞭な言い回しなど）は、今すぐ修正する
3. ギャップの解消に手戻りが必要な場合は、明示的に示す: 「この軸は [理由] のスコアになりました。根拠は [根拠] です。[具体的な修正] で再実行すれば、[スコア] に上がる可能性が高いです。」

## コード例

### 例: 良い評価（スコア 4 以上）

```
Task: Add retry logic to HTTP client

Scorecard:
  Accuracy:    5 — All API calls correct. Verified: retries use
                  exponential backoff. No hallucinated methods.
  Completeness: 4 — Covered happy path + 3 error cases. Missing:
                  timeout handling for hung connections.
  Clarity:      5 — Code comments explain backoff formula.
                  PR description links to incident that motivated this.
  Actionability:5 — Single merge. No follow-up tasks. Tests pass.
  Conciseness:  4 — 47 lines total. The retry loop could be extracted
                  into a helper to drop ~8 lines.

Overall: 4.6 — One gap (timeout handling). Fix before merging.
```

### 例: 弱い評価（スコア 2〜3）

```
Task: Add retry logic to HTTP client

Scorecard:
  Accuracy:    2 — Used urllib3 which doesn't match our
                  httpx-based codebase. Wrong library.
  Completeness: 3 — Works for GET. POST/PUT not handled (user
                  said "all HTTP requests").
  Clarity:      4 — Code is readable. Good variable names.
  Actionability:2 — "Add tests" mentioned but no test file created.
                  User has to write tests before merging.
  Conciseness:  3 — 120 lines. The retry config is duplicated in
                  3 places instead of one shared RetryConfig object.

Overall: 2.8 — Wrong library used. Needs httpx rewrite.
  Fix accuracy first (switch to httpx), then extend to all
  HTTP methods, then consolidate config.
```

## アンチパターン

### 「すべて 5」

```
FAIL: Accuracy:    5 — All good.
   Completeness: 5 — Everything covered.
   Clarity:      5 — Clear.
```

根拠が示されていません。これは自画自賛であり、評価ではありません。本物の 5 には、改善の余地がないことの証明が必要です。

### スコープの拡大を理由とした過度な減点

```
FAIL: Completeness: 2 — Didn't handle WebSocket connections or
   gRPC streaming (user didn't ask for these)
```

評価の対象は、ユーザーが実際に依頼した内容のみです。追加で作れたかもしれないものは対象外です。

### 評価を蒸し返しに使う

```
FAIL: "As I said earlier, this approach is wrong. Score: 1"
```

評価の対象は納品された出力であり、すでに下された設計上の判断を改めて争う場ではありません。アプローチが誤っていたのであれば、納品前に気付くべきことでした。

### 個人的な好みと客観的なギャップの混同

```
FAIL: "Score: 3. I don't like Python decorators."
```

「好きではない」は根拠ではありません。可読性、テスト容易性、正確性に関する具体的な懸念を示すか、スコアを 4 以上のままにしてください。

## ベストプラクティス

- **プロセスではなく出力を評価する。** ユーザーが気にするのは納品された内容であり、何回反復したかではありません。
- **弱い軸ごとに改善点は 1 つ。** 1 つの軸に 5 つの項目を挙げず、最も影響の大きいギャップを選びます。
- **改善点をユーザーへの影響に結び付ける。** 「エラー処理を追加する」よりも、「エラー処理がないと、ユーザーの API 呼び出しがエラーを出さずにクラッシュする」の方が優れています。
- **「修正済み」の姿を具体的に示す。** 「ライブラリの問題を修正する」よりも、「リトライ用に設定した httpx トランスポートで再実行する」の方が優れています。
- **ツール出力を根拠として使う。** テストが通ったならそれを引用し、lint がクリーンならそれを引用します。推測せず、証拠を grep で確認してください。
- **ギャップが見つからなければ、もっと探す。** 5 軸すべてで満点になることはまれです。「自分がユーザーなら、この出力のどこに不満を覚えるか？」と自問してください。

## 関連スキル

- `agent-eval` — ベンチマークタスクにおける、異なるコーディングエージェントの直接比較
- `verification-loop` — 出力を期待結果に照らして体系的に検証する
- `security-review` — セキュリティに特化したコードレビューのチェックリスト
