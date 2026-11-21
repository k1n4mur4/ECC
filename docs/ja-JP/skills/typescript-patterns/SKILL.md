---
name: typescript-patterns
description: モダンな TypeScript および JavaScript アプリケーションにおける、厳格で型安全かつ保守しやすいコードのための TypeScript パターン。strict なコンパイラ設定、型設計、絞り込み、判別共用体、ジェネリクス、非同期処理とエラーハンドリング、モジュール境界、依存関係の管理、型レベルのテストを扱います。TypeScript または JavaScript のコードを書く際やレビューする際に使用します。
metadata:
  origin: ECC
---

# TypeScript 開発パターン

堅牢で型安全かつ保守しやすいアプリケーションを構築するための TypeScript のパターンとベストプラクティスです。コンパイラはプログラムの形を証明できるときに最も役立ちます。そのため、ここでの指針は「型システムと戦うのではなく、型システムに実質的な仕事をさせる」ことです。このスキルは「どうやるか」を扱います。「何を」「いつ」使うか（どのパターンを選ぶかの判断）については、TypeScript ルール（このリポジトリの `rules/typescript/coding-style.md` と `rules/typescript/patterns.md`。インストール先は `rules/ecc/typescript/coding-style.md` と `rules/ecc/typescript/patterns.md`）を参照してください。

## 有効化するタイミング

- 新しい TypeScript または JavaScript のコードを書くとき
- `.ts` や `.tsx` ファイルに触れる PR をレビューするとき
- 既存の TypeScript をリファクタリングして `any` を取り除く、型を引き締める、または strict 化を進めるとき
- 新機能のために型、ジェネリクス、モジュール境界を設計するとき
- 新しい TypeScript プロジェクトをセットアップするとき、または `tsconfig.json` をアップグレードするとき
- コードベース全体に波及する型エラーをデバッグするとき（多くの場合、型注釈ではなく設計の問題です）

## コア原則

### 1. strict モードが基本線

`strict: true`（`strictNullChecks`、`noImplicitAny`、`strictFunctionTypes` などを有効にします）は、健全なコードベースでは必須です。strict でコンパイルできないコードベースがあるなら、それは移行タスクであり、フラグをオフのままにしておく理由にはなりません。

```jsonc
// tsconfig.json — 厳格で、問題を見逃しにくいベースライン
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "noFallthroughCasesInSwitch": true,
    "noPropertyAccessFromIndexSignature": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "forceConsistentCasingInFileNames": true,
    "verbatimModuleSyntax": true
  }
}
```

`noUncheckedIndexedAccess` は、配列やレコードへのアクセス結果を undefined の可能性ありとして扱うため、ランタイムクラッシュの一群をコンパイル時に表面化させます。ノイズが多すぎる場合は、フラグを外すのではなく、次のパターンを追加してください。

```typescript
// インデックスが存在することを確認済みなら、まず要素をローカル変数に取り出す。
const [first] = items
if (first === undefined) {
  throw new Error("expected at least one item")
}
```

### 2. `any` はツールではなくバグ

`any` は、バグが最も潜みやすい場所、つまり信頼できないデータや動的なデータとの境界で、型システムを無効にします。`unknown` を使って絞り込んでください。どうしてもフォールバックが必要な場合は、暗黙の `any` よりも、コメント付きで明示的に型を緩めるほうを選びます。

```typescript
// Bad: any が公開 API の型チェックを無効にする
export function parseConfig(raw: any): Config {
  return raw.config ?? {}
}

interface Config {
  timeout: number
  retries: number
}

const DEFAULT_CONFIG: Config = { timeout: 30_000, retries: 3 }

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}

function toPositiveInt(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    throw new TypeError(`Expected ${field} to be a positive integer`)
  }
  return value
}

// Good: unknown により境界で安全な絞り込みが強制される。使用するすべての
// フィールドは明示的な範囲で検証され、デフォルト値は先頭で宣言されている。
export function parseConfig(raw: unknown): Config {
  if (!isRecord(raw)) return { ...DEFAULT_CONFIG }
  return {
    timeout: raw['timeout'] === undefined ? DEFAULT_CONFIG.timeout : toPositiveInt(raw['timeout'], 'timeout'),
    retries: raw['retries'] === undefined ? DEFAULT_CONFIG.retries : toPositiveInt(raw['retries'], 'retries'),
  }
}
```

### 3. 公開 API には明示的な型、ローカルには推論

TypeScript はローカル変数をうまく推論します。パラメータや戻り値の型が暗黙のままの関数をエクスポートすると、推論の結果がすべての利用者に漏れ出し、意図が読み取れなくなります。

```typescript
// Bad: 型が明示されていないエクスポート API
export function formatUser(user) {
  return `${user.firstName} ${user.lastName}`
}

// Good: 公開契約は明示し、内部は推論に任せる
interface User {
  firstName: string
  lastName: string
}

export function formatUser(user: User): string {
  return `${user.firstName} ${user.lastName}`
}
```

## 型設計

### インターフェースと型エイリアス

拡張または実装される可能性のあるオブジェクトの形には `interface` を、共用体、交差型、タプル、マップ型、ユーティリティ型には `type` を使います。実行時に値を列挙する必要がある場合や、それを要求するコードとの相互運用が必要な場合を除き、`enum` よりも文字列リテラルの共用体を優先します。

```typescript
interface User {
  id: string
  email: string
}

type UserRole = 'admin' | 'member'
type AdminUser = User & { role: 'admin' }
```

### 判別共用体を標準のステートマシンとする

値が複数の形を取り得る場合は、リテラルの `type`/`kind` フィールドを持つ判別共用体としてモデル化します。すると網羅性チェックがコンパイラの機能としてそのまま使えます。ランタイムのフォールバックではなく、分岐が欠けていればコンパイルエラーになります。

```typescript
type Transaction =
  | { kind: 'draft'; id: string }
  | { kind: 'submitted'; id: string; submittedAt: Date }
  | { kind: 'paid'; id: string; paidAt: Date; amountCents: number }

function describe(t: Transaction): string {
  switch (t.kind) {
    case 'draft':
      return 'Saved but not sent'
    case 'submitted':
      return `Submitted on ${t.submittedAt.toISOString()}`
    case 'paid':
      return `Paid ${t.amountCents} cents on ${t.paidAt.toISOString()}`
    default:
      // 網羅性チェック: 新しいメンバーを追加するとここがコンパイルエラーになる
      return assertNever(t)
  }
}

function assertNever(value: never): never {
  throw new Error(`Unhandled member: ${JSON.stringify(value)}`)
}
```

### 構造だけでは足りない場面でのブランドと名目的な安全性

構造的型付けでは `CustomerId` と `string` を区別できません。ID や単位を他のものと取り違えてはならない場合は、ブランド（ユニークシンボルをキーとするファントムフィールド）を追加します。

```typescript
declare const brand: unique symbol

export type CustomerId = string & { [brand]: 'CustomerId' }

function ensureCustomerId(value: string): CustomerId {
  if (!/^cus_[a-z0-9]+$/.test(value)) {
    throw new TypeError(`Invalid customer id: ${value}`)
  }
  return value as CustomerId
}
```

ブランドは境界となるモジュールの内部に留めてください。キャストを行うヘルパーを、それを正当化する検証から遠い場所に公開してはいけません。

### ジェネリクスで呼び出し側に依存する型をモデル化する

値の型が呼び出し側の提供するものに依存するなら、`any` や `unknown` に押し潰して呼び出し箇所で手動キャストするのではなく、ジェネリクスにします。

```typescript
// Bad: 呼び出し側が結果をキャストしなければならない
export function getCached(key: string): unknown {
  return cache.get(key)
}

// Good: 呼び出し側の型がそのまま流れる
export function getCached<T>(key: string, parse: (raw: string) => T): T | undefined {
  const raw = cache.get(key)
  if (raw === undefined) return undefined
  return parse(raw)
}
```

契約が分かりやすくなるようにジェネリクスには制約を付けます。形についての前提があるなら、制約のない `T` よりも `T extends SomeShape` を優先してください。

### 位置引数よりもオプションオブジェクト

調整項目が数個を超える関数は、単一のオプションオブジェクトを受け取るようにします。呼び出し箇所が自己説明的になり、位置引数の変更を伴わずに新しい項目を追加できます。

```typescript
interface FetchOptions {
  timeoutMs?: number
  retries?: number
  signal?: AbortSignal
}

export async function fetchWithRetry(url: string, options: FetchOptions = {}): Promise<Response> {
  // ...
}
```

## 絞り込みとランタイムの安全性

### 境界で検証し、内部では信頼する

信頼できないデータは I/O の境界、つまり API ハンドラ、メッセージコンシューマ、ファイルローダーから入ってきます。スキーマで一度だけパースと検証を行い、その後は絞り込まれた型をドメイン全体に引き継ぎます。ここが検証ライブラリ（たとえば Zod）の本領です。スキーマがランタイムチェックとコンパイル時の型の両方を担います。

```typescript
import { z } from 'zod'

const userInputSchema = z.object({
  email: z.string().email(),
  age: z.number().int().min(0).max(150)
})

export type UserInput = z.infer<typeof userInputSchema>

// 境界で一度だけ検証する
const input: UserInput = userInputSchema.parse(rawBody)
```

### 型述語とアサーション関数

形をガードする際は、チェックなしのキャストよりも型述語やアサーション関数を優先します。ガードが不変条件を文書化し、コンパイラがその使用を検査します。

```typescript
function isConfig(value: unknown): value is Config {
  if (typeof value !== 'object' || value === null) return false
  if (!('timeout' in value) || !('retries' in value)) return false
  const { timeout, retries } = value
  return (
    typeof timeout === 'number' && Number.isInteger(timeout) && timeout > 0 &&
    typeof retries === 'number' && Number.isInteger(retries) && retries > 0
  )
}
```

真偽値を返すのではなく、不正な値に対して明示的に失敗させたい場合は、アサーションシグネチャを使います。

```typescript
function assertIsStringArray(value: unknown): asserts value is string[] {
  if (!Array.isArray(value)) {
    throw new TypeError('Expected an array of strings')
  }
  // イテレーションは疎な位置をスキップせず undefined として訪問する。
  for (const item of value) {
    if (typeof item !== 'string') throw new TypeError('Expected an array of strings')
  }
}
```

### デフォルトで readonly

関数が変更しない配列やオブジェクトのパラメータには、`readonly`/`ReadonlyArray` を付けます。意図しない変更を防ぎ、シグネチャで意図を示せます。（コーディングスタイルのルールに従い、イミュータブルな更新にはスプレッド演算子を優先します。）

```typescript
export function totalAmount(items: readonly LineItem[]): number {
  return items.reduce((sum, item) => sum + item.amountCents, 0)
}
```

ランタイムでのイミュータビリティ（たとえば `Object.freeze`）は、アプリケーションの重要な境界のためのものです。日常的な防御策は、型の位置に付ける `readonly` です。

## エラーハンドリング

### 境界で失敗させ、端で処理する

`try/catch` は、握りつぶされたエラーが積み重なるように内部の呼び出しごとに巡らせるものではなく、呼び出し側が失敗に対処できる場所に置きます。async/await と `try/catch` を使い、`unknown` のエラーは安全に絞り込みます（コーディングスタイルのルールに従います）。

このエンドポイントの例は、ASCII の英字、数字、アンダースコア、ハイフンからなる空でない ID（たとえば `u_1`）を受け付けます。パスを組み立てたりリクエストを送ったりする前に、その契約を検証してください。ID の文法は実際の API に合わせて調整します。

```typescript
type User = { id: string; email: string }

function isUser(value: unknown): value is User {
  if (typeof value !== 'object' || value === null) return false
  if (!('id' in value) || !('email' in value)) return false
  const { id, email } = value
  return (
    typeof id === 'string' && id.length > 0 &&
    typeof email === 'string' && email.includes('@')
  )
}

function assertUserId(userId: string): void {
  if (typeof userId !== 'string' || userId.length === 0 || /[^A-Za-z0-9_-]/.test(userId)) {
    throw new TypeError('Expected a user ID using letters, digits, "_" or "-"')
  }
}

async function loadUser(userId: string): Promise<User> {
  assertUserId(userId)
  const response = await fetch(`/users/${userId}`)
  if (!response.ok) {
    throw new Error(`Failed to load user ${userId}: ${response.status}`)
  }
  const data: unknown = await response.json()
  if (!isUser(data)) {
    throw new TypeError(`Invalid user payload for ${userId}`)
  }
  return data
}

export async function getUser(userId: string): Promise<User> {
  try {
    return await loadUser(userId)
  } catch (error: unknown) {
    if (error instanceof Error) {
      // 既知の失敗モード: リトライするか、分かりやすいメッセージを表示する
      throw new Error(`user lookup failed: ${error.message}`, { cause: error })
    }
    throw new TypeError('unknown error shape')
  }
}
```

### 想定内の失敗には Result 型

想定内のビジネス上の失敗（バリデーション、not-found、競合）には、判別共用体の `Result` を使うと、失敗が例外フローに隠れずに型として明示されます。

```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E }

function createUser(input: UserInput): Result<User, ValidationIssue[]> {
  const issues = validate(input)
  if (issues.length > 0) {
    return { ok: false, error: issues }
  }
  return { ok: true, value: { id: generateId(), ...input } }
}
```

例外は想定外の事態のために取っておきます。想定内の結果は戻り値の型で表現します。

### エラーのコンテキストを保持する

`new Error(message, { cause })`（ES2022 以降で利用可能）を使い、再ラップしても元の失敗の連鎖が残るようにします。エラーを文字列化してメッセージに埋め込み、原因を失ってはいけません。

## 非同期パターン

### 独立したファンアウトには `Promise.allSettled` を優先する

結果が互いに独立していて、1 つの失敗で他の結果を捨ててはならない場合は、`Promise.allSettled` を使い、プロミスごとの結果を処理します。

```typescript
const results: PromiseSettledResult<number>[] = await Promise.allSettled(
  sourceIds.map((id) => fetchCount(id))
)

const total = results.reduce((sum, result) => {
  if (result.status === 'fulfilled') {
    return sum + result.value
  }
  log.warn('count fetch failed', result.reason)
  return sum
}, 0)
```

フェイルファストのセマンティクスが欲しい場合、つまり本当にすべて成功か全体失敗かという処理には `Promise.all` を使います。

### 無制限の並行実行を避ける

数百ものプロミスを一度にファンアウトすると、接続とイベントループに負荷がかかりすぎます。小さなプールで並行数を制限してください。

```typescript
async function mapWithConcurrency<T, R>(
  items: readonly T[],
  limit: number,
  mapper: (item: T) => Promise<R>
): Promise<R[]> {
  if (!Number.isInteger(limit) || limit < 1) {
    throw new RangeError(`Expected concurrency limit to be a positive integer, got: ${limit}`)
  }
  const results: R[] = new Array(items.length)
  let nextIndex = 0

  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (true) {
      const index = nextIndex++
      if (index >= items.length) return
      // noUncheckedIndexedAccess の下では必須: 上でインデックスが範囲内で
      // あることは確認済みだが、コンパイラはここを依然として T | undefined と
      // みなす。実際に疎配列の穴であるものだけをスキップし、
      // Array.prototype.map と同じ挙動にする: 存在する `undefined` 要素は
      // 正当な値であり、mapper に渡されなければならない。
      if (!Object.hasOwn(items, index)) continue
      // 要素の存在は上で確認済みなので、このインデックスアクセスは範囲内で
      // 値が入っている。穴でも、コンパイラの推測による undefined でもない。
      results[index] = await mapper(items[index]!)
    }
  })

  // ワーカーのどれか 1 つが reject されるとプール全体が reject される:
  // Promise.all は最初の reject を呼び出し側へ伝播する（フェイルファスト）。
  // これは reject であってキャンセルではない。プールがすでに reject された
  // 後でも、他のワーカーは動き続け、残りのアイテムをさらに処理し終える
  // 可能性がある。実行中の処理が走り続けても構わない場合にのみ Promise.all
  // を使うこと。そうでなければ allSettled を使うか、mapper に AbortSignal
  // を渡すこと。
  await Promise.all(workers)
  return results
}
```

### タイムアウトとキャンセル

長時間実行される処理や外部へのリクエストには、呼び出し側がキャンセルできるよう必ず `AbortSignal` を通します。基になる処理を中断できない場合に厳密なタイムアウトが必要なときは、`Promise.race` と組み合わせます。

```typescript
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timed out after ${ms}ms`)), ms)
    promise.then(
      (value) => {
        clearTimeout(timer)
        resolve(value)
      },
      (reason) => {
        clearTimeout(timer)
        reject(reason)
      }
    )
  })
}
```

## Null と Undefined の規律

センチネル値を混在させるのではなく、判別的なアプローチを優先します。「見つからない」や「存在しない」が正当な状態である場合は、`T | undefined` を使って明示的にチェックしてください。`?.` チェーンを深くネストさせ、その後にバグを隠す無言のフォールバックを置くことは避けます。

```typescript
function findUser(id: string): User | undefined {
  return users.get(id)
}

const user = findUser('u_1')
if (user === undefined) {
  return notFound()
}
// ここから先、`user` は User に絞り込まれている
```

誤った型を黙って受け入れてしまう truthy 判定（`result` が `0` や `''` になり得るのに `if (result)` と書くなど）は避けます。`undefined`/`null` と明示的に比較してください。

## モジュール境界とエクスポート

### 小さく名前付きのモジュール

各モジュールの境界で、意図した公開面を示します。デフォルトエクスポートよりも明示的な名前付きエクスポートを優先し、公開の端で再エクスポートします。そうすれば利用者は、リファクタリングされ得る深い内部ではなく、その型を所有するモジュールからインポートできます。

```typescript
// user/model.ts — 内部の型
export interface UserAccount {
  id: string
  email: string
  role: UserRole
}

// user/index.ts — 公開面
export { type UserAccount, type UserRole } from './model'
export { createUser, findUser, updateUser } from './service'
```

### バレルの肥大化と循環インポートを避ける

モジュールのロード時にすべてをインポートするバレルは作らないでください（ツリーシェイキングを妨げ、コールドスタートを悪化させます）。具体的なパスからインポートします。循環インポートは、本来は 1 つに統合すべき境界を分割してしまっているサインです。双方が必要とする型は、どちらもインポートしない共有モジュールに置きます。

### 依存の向きで分割する

型グラフに進むべき方向を示させます。境界をまたぐ型は契約モジュールに置き、実装は契約をインポートし、契約から実装をインポートしてはいけません。node/バックエンドのコードベースでは、おおよそ次のようになります。`domain`（純粋な型とルール）→ `application`（ユースケース）→ `infrastructure`（アダプタ）で、依存は内側にのみ向かいます。

## 依存関係とビルド

### 診断してから依存関係を追加する

小さな処理のたびにユーティリティを取り込むよりも、組み込みの `Array`、`Map`、`Promise`、`Intl` を優先します。小さなインライン関数は、アップグレード、監査、互換性維持が必要になる依存関係よりも優れています。（Go の「少しのコピーは少しの依存より良い」という格言は TypeScript にも当てはまります。）

### 型への信頼ではなくランタイム検証

ランタイムで検証するスキーマ（Zod、バリデータ、または手書きのガード）は、信頼できないデータとコンパイル時の型をつなぐ橋渡しです。ライブラリのアプローチは異なります（Zod などのスキーマファーストのライブラリはスキーマから型を導出しますが、エコシステムによっては型ファーストで、ランタイムチェックが導出されるバリデータもあります）。1 つのモデルを選び、コードベース全体で一貫させてください。

### コンパイラをインクリメンタルかつ高速に保つ

大規模なコードベースでは、プロジェクト参照を使った `composite: true`、`incremental` ビルドキャッシュ、バンドラーが対応している場合の `moduleResolution: bundler` が効果的です。型チェックが遅いことは、開発者を型システムから遠ざけるワークフロー上の問題です。型チェックを緩めるのではなく、チェック対象の範囲を絞ることに投資してください。

## パフォーマンス

### 型は実行時コストがゼロ、構造はそうではない

型レベルの曲芸（マップ型、条件型、テンプレートリテラル型）は実行時のコストこそゼロですが、開発者にとっての分かりやすさを大きく損なうことがあります。複雑な型の仕組みは境界モジュールの内側に閉じ込め、型の曲芸を公開 API としてエクスポートしないでください。

### 不要なオブジェクトのリネームを避ける

大きなネストしたオブジェクトのコピーやスプレッドを繰り返すと、ホットパスでは実際にコストがかかります。変更箇所でスプレッドによるイミュータブルな更新を行うのを優先しつつ、変更のない構造を防御的に再コピーするのは避けます（たとえば、レンダリングパスやメッセージごとのハンドラ内）。

### 冪等な計算をメモ化する

同じ入力で繰り返される、純粋で高コストな導出は、キャッシュの背後に置くべきです。クリアされることのない場当たり的なグローバルキャッシュではなく、明示的な有効期間を持つ `Map` ベースのキャッシュを使います。

## 型レベルのテスト

### ランタイムだけでなく型もアサートする

振る舞いのテストはランタイムの挙動を証明し、専用の型テストは公開 API の契約を固定します。型が黙って緩くなるのはリグレッションです。

```typescript
import { expectTypeOf } from 'vitest'

expectTypeOf<Result<User, ValidationIssue[]>>().toEqualTypeOf<
  | { ok: true; value: User }
  | { ok: false; error: ValidationIssue[] }
>()
```

### `satisfies` で意図を保つ

`satisfies` は、値をある形に対して検査しつつ、その形へ型を広げません。リテラル型を保ったまま構造を検証できる理想的な方法です。

```typescript
const statusByAction = {
  new: 'open',
  reopen: 'open',
  close: 'closed'
} as const satisfies Record<Action, Status>
```

## TypeScript ツールの統合

### 基本コマンド

```bash
# プロジェクト全体の型チェック
npx tsc --noEmit

# 高速なフィードバックのためのウォッチモード
npx tsc --noEmit --watch

# テストの実行 (Vitest)
npx vitest run

# 型情報を使うルールでの Lint (typescript-eslint)
npx eslint .

# フォーマット
npx prettier --write .
```

### 推奨される Linter のベースライン

`typescript-eslint` の recommended-type-checked ルールセットが実用上のデフォルトです。`no-unsafe-assignment`、`no-unsafe-member-access`、`no-unsafe-argument`、`no-unsafe-call` を、スタイル上のノイズからコンパイラ並みの保証へと引き上げます。型情報を使う設定は維持してください。遅い場合はプロジェクト構造の見直しを促すサインであり、無効にする理由にはなりません。

## 避けるべきアンチパターン

- **手っ取り早さのための `any`** — コンパイラによる証明を、実行時の推測に変えてしまいます。代わりに `unknown` と絞り込みを使ってください。
- **嘘をつく `as` キャスト** — 実際には行っていないチェックを迂回するキャストは、ヌルポインタや形に関するバグの温床です。検証してからキャストし、キャストは検証を行うモジュールの内部に留めてください。
- **深くネストしたコールバック / プロミスチェーン** — async/await を優先してください。フラットなコードは絞り込みしやすいコードです。
- **`enum` の型強制によるバグ** — 文字列リテラルの共用体なら、ランタイムの成果物や逆引きマッピングの落とし穴なしに、同じ安全性が得られます。
- **巨大なゴッド型** — 無関係な複数の形をモデル化する単一のインターフェースは、判別共用体、または複数のインターフェースにすべきです。
- **すべてがオプションのオプションオブジェクト** — `allOptional` 型の設定は、呼び出し箇所のタイプミスを黙って飲み込みます。関数が本当に依存しているものには必須フィールドを使うのが望ましいです。
- **サイレントな catch** — `catch {}` や `catch (e) { /* nothing */ }` は、呼び出し側が処理済みだと思い込んでいる失敗を隠します。
- **同期と非同期のエラーパスの混在** — `async` 関数は、最初の `await` より前であっても、スローを常に reject として表面化させます。同期的にスローし得る（プロミスを返す前に）のは、プロミスを返す非 `async` 関数だけで、呼び出し側は 2 種類のエラーの形を扱う必要が生じます。すべての失敗が reject になるよう、一貫して `async` を使うのが望ましいです。

```typescript
async function asyncFails(): Promise<never> {
  throw new Error('becomes a rejection, never a sync throw')
}

function lazyFails(): Promise<never> {
  throw new Error('throws synchronously — needs try/catch AND .catch')
}
```

**覚えておくこと**: 型システムは証明のためのツールであり、事務的な負担ではありません。妥当な型注釈を付けても型エラーが解消しないときは、変えるべきなのは多くの場合コンパイラではなく設計です。巧妙な型エンジンよりも、退屈で明示的、かつスコープの適切な TypeScript を選びましょう。

## 関連スキル

- `nestjs-patterns` — TypeScript バックエンド向けの NestJS アーキテクチャパターン（モジュール、コントローラー、プロバイダー、DTO バリデーション）
- `frontend-patterns` — React と Next.js のコンポーネントおよび状態管理のパターン
- TypeScript ルール（`rules/typescript/`。インストール先は `rules/ecc/typescript/`）— このスキルが「どうやるか」として実装する、「何を」「いつ」にあたる内容
- `prisma-patterns` — TypeScript アプリケーションで使用されるデータベースアクセスのパターン
