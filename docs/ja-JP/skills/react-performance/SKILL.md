---
name: react-performance
description: Vercel Engineering の React Best Practices (https://github.com/vercel-labs/agent-skills) を基にした、React と Next.js のパフォーマンス最適化パターン。70 以上のルールを 8 つの優先度カテゴリ（ウォーターフォール、バンドルサイズ、サーバーサイド、クライアントフェッチ、再レンダリング、レンダリング、JS マイクロパフォーマンス、高度なパターン）に整理しています。React/Next.js コードをパフォーマンスの観点から作成、レビュー、リファクタリングするときに使用します。
metadata:
  origin: ECC
---

# React パフォーマンス

[Vercel Labs `react-best-practices`](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)（MIT、v1.0.0）を基にした、React 18/19 と Next.js 向けのパフォーマンス最適化パターンです。このスキルはルールを優先度別に整理し、実際のコードレビューやリファクタリングで使える決定木形式のガイダンスを提供します。

## 使用タイミング

- パフォーマンスの観点から React/Next.js コードを書く、またはレビューするとき
- ページ読み込みの遅さ、インタラクションの遅さ、クライアントでの高 CPU 使用率を診断するとき
- バンドルサイズや Lighthouse の Core Web Vitals の劣化を監査するとき
- Server Components / API ルートのウォーターフォールを解消するとき
- クライアント側の再レンダリングを減らすとき
- 長いリスト、アニメーション、ハイドレーションを最適化するとき
- `app/`、`pages/`、`components/`、またはデータレイヤーに触れる PR の最適化の選択を監査するとき

## 優先度インデックス

| 優先度 | カテゴリ | プレフィックス | 重要になる場面 |
|---|---|---|---|
| 1 — CRITICAL | ウォーターフォールの排除 | `async-` | `await` の後に独立した `await` が続くとき |
| 2 — CRITICAL | バンドルサイズの最適化 | `bundle-` | 初回ロード JS、ルート単位のインポート、サードパーティライブラリ |
| 3 — HIGH | サーバーサイドのパフォーマンス | `server-` | RSC、Server Actions、API ルート、SSR |
| 4 — MEDIUM-HIGH | クライアントサイドのデータフェッチ | `client-` | フック内での SWR / TanStack Query / 生の `fetch` |
| 5 — MEDIUM | 再レンダリングの最適化 | `rerender-` | 高頻度の状態更新、親子間のファンアウト |
| 6 — MEDIUM | レンダリングパフォーマンス | `rendering-` | 長いリスト、アニメーション、ハイドレーション |
| 7 — LOW-MEDIUM | JavaScript パフォーマンス | `js-` | ホットループ、頻繁なメモリ割り当て |
| 8 — LOW | 高度なパターン | `advanced-` | Effect とイベントの統合、安定した ref |

## 1. ウォーターフォールの排除（CRITICAL）

> 「ウォーターフォールはパフォーマンス低下の最大の原因」 — 逐次的な `await` は、そのたびにネットワークのレイテンシ全体を上乗せします。

### await の前に軽い条件をチェックする

リモートデータを await する前に、同期的に判定できる条件（props、環境変数、ハードコードされたフラグ）を確認します。

```ts
// INCORRECT
async function Page({ id }: { id: string }) {
  const flag = await getFlag("show-page");
  if (!flag || !id) return null;
  const data = await getData(id);
  // ...
}

// CORRECT — 軽い同期条件で先に早期リターンする
async function Page({ id }: { id: string }) {
  if (!id) return null;
  const flag = await getFlag("show-page");
  if (!flag) return null;
  const data = await getData(id);
}
```

### await は使う直前まで遅らせる

`await` を、その結果を使う分岐の内側に移動します。

```ts
// INCORRECT — データが必要か判断する前に await している
const user = await getUser(id);
if (mode === "guest") return renderGuest();
return renderUser(user);

// CORRECT
if (mode === "guest") return renderGuest();
const user = await getUser(id);
return renderUser(user);
```

### 独立した処理には Promise.all を使う

```ts
// INCORRECT — 逐次実行
const user = await getUser(id);
const posts = await getPosts(id);
const followers = await getFollowers(id);

// CORRECT — 並列実行
const [user, posts, followers] = await Promise.all([
  getUser(id),
  getPosts(id),
  getFollowers(id),
]);
```

### 部分的な依存関係 — 早く開始し、遅く await する

```ts
// CORRECT — すべての Promise を先に起動し、各結果が必要になった時点で await する
const userP = getUser(id);
const postsP = getPosts(id);
const profile = await getProfile(id);
if (profile.private) return null;
const [user, posts] = await Promise.all([userP, postsP]);
```

### ストリーミングのための Suspense

`<Suspense>` 境界をデータの近くに置くことで、ページは描画できる部分を先に描画し、遅いサブツリーは後からストリーミングされます。トレードオフとして、コンテンツ到着時にレイアウトシフトが発生するため、スペースを確保してください（スケルトンや `min-height`）。

### Server Components: コンポジションによる並列化

```tsx
// INCORRECT — 1 つのコンポーネント内の兄弟 await が逐次実行される
export default async function Page() {
  const user = await getUser();
  const cart = await getCart();
  return <View user={user} cart={cart} />;
}

// CORRECT — 子コンポーネントに分割すると、React が並列に実行する
export default async function Page() {
  return (
    <View>
      <UserSection />
      <CartSection />
    </View>
  );
}
```

## 2. バンドルサイズの最適化（CRITICAL）

### バレルではなく直接インポートする

バレル `index.ts` ファイルは、ツリーシェイキングで大半が除去される場合でも、バンドラーにモジュールグラフ全体をたどらせます。直接インポートにすると、実際の多くのアプリで初回ロード JS を 200〜800ms 短縮できます。

```ts
// INCORRECT
import { Button, Card, Modal } from "@/components";

// CORRECT
import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import { Modal } from "@/components/Modal";
```

Next.js 13.5 以降には、指定したパッケージに対してこれを自動化する [Optimize Package Imports](https://nextjs.org/docs/app/api-reference/next-config-js/optimizePackageImports) があります。ぜひ活用してください。ただし、リストにないライブラリでは引き続き手動で直接インポートする必要があります。

### 静的に解析可能なパス

```ts
// INCORRECT — バンドラー/トレース解析を妨げる
const mod = await import(`./pages/${name}`);

// CORRECT — 分岐ごとに明示する
const mod = name === "home" ? await import("./pages/home") : await import("./pages/about");
```

### 重いコンポーネントには動的インポートを使う

```tsx
import dynamic from "next/dynamic";

const HeavyChart = dynamic(() => import("./HeavyChart"), {
  loading: () => <Skeleton />,
  ssr: false, // クライアント専用の場合
});
```

### サードパーティスクリプトの遅延読み込み

アナリティクス、ロギング、サポートウィジェットは、ハイドレーションの「後」に読み込みます。`next/script` で `strategy="afterInteractive"`（デフォルト）または `"lazyOnload"` を使用します。

### 条件付きモジュール読み込み

```tsx
if (user.role === "admin") {
  const { AdminPanel } = await import("./admin/AdminPanel");
  // ...
}
```

### hover/focus 時のプリロード

hover 時に `<link rel="preload">` または `import()` を発火させ、ユーザーがクリックする頃にはバンドルがキャッシュに入っているようにします。

## 3. サーバーサイドのパフォーマンス（HIGH）

### Server Actions も API ルートと同様に認証する

すべての `"use server"` 関数は公開エンドポイントです。アクション内で認証と認可の「両方」を行ってください。呼び出し元の Client Component 側の制御に頼ってはいけません。

```ts
"use server";
export async function deleteUser(formData: FormData) {
  const session = await getSession();
  if (!session?.user) throw new Error("Unauthorized");
  const targetId = String(formData.get("id"));
  if (session.user.role !== "admin" && session.user.id !== targetId) {
    throw new Error("Forbidden");
  }
  await db.user.delete({ where: { id: targetId } });
}
```

### リクエスト単位の重複排除に `React.cache()` を使う

```ts
import { cache } from "react";

export const getUser = cache(async (id: string) => {
  return db.user.findUnique({ where: { id } });
});
```

`React.cache` は 1 リクエスト内で重複を排除します。同じレンダリング内の 3 つの Server Components から `getUser("1")` を呼んでも、DB クエリは 1 回だけです。

### リクエストをまたぐデータには LRU キャッシュ

リクエストごとに変わらないデータ（設定、ルックアップテーブル）は、React の外側で LRU キャッシュまたは `unstable_cache` を使ってキャッシュします。

### RSC props での重複シリアライズを避ける

Server Component が同じデータを複数の Client Components にレンダリングすると、データは利用側ごとに 1 回ずつシリアライズされます。Client Component を上位に引き上げ、children として渡してください。

### 静的な I/O はモジュールスコープに巻き上げる

```ts
// CORRECT — モジュール読み込み時に 1 回だけ実行される
const fontData = readFileSync(fontPath);

export async function Page() {
  return <Banner font={fontData} />;
}
```

### RSC/SSR でミュータブルなモジュールレベル状態を持たない

サーバー上のモジュール状態はすべてのリクエストで共有されるため、ユーザー間の競合状態を引き起こします。代わりに、リクエストスコープのストレージ（`headers()`、`cookies()`、非同期コンテキスト）を使用してください。

### Client Components に渡すデータを最小限にする

Client が必要とするものだけをシリアライズします。フィールドを削り、ページネーションし、DB レイヤーでカラムを絞り込みます。

### ネストしたフェッチは項目ごとに Promise.all で並列化する

```ts
const users = await getUsers();
const enriched = await Promise.all(
  users.map(async (u) => ({ ...u, posts: await getPostsFor(u.id) })),
);
```

### ブロッキングしない処理には `after()` を使う

Next.js 15 の `after()` は、レスポンス送信後に処理を実行します。ロギング、キャッシュのウォームアップ、アナリティクスなどに使います。

```ts
import { after } from "next/server";
export async function GET() {
  const data = await getData();
  after(() => logAnalytics(data));
  return Response.json(data);
}
```

## 4. クライアントサイドのデータフェッチ（MEDIUM-HIGH）

### 重複排除に SWR / TanStack Query を使う

複数のコンポーネントが `useUser(id)` を呼び出しても、ネットワークリクエストとキャッシュエントリは 1 つに共有されるべきです。SWR または TanStack Query を使用し、共有データのために独自の `useEffect` + `fetch` を実装してはいけません。

### グローバルイベントリスナーの重複を排除する

```tsx
// INCORRECT — 各コンポーネントが個別に追加している
useEffect(() => {
  window.addEventListener("scroll", handler);
  return () => window.removeEventListener("scroll", handler);
}, []);

// CORRECT — フックとグローバルなサブジェクトによる単一の共有リスナー
const useScroll = createScrollHook(); // 内部ではシングルトンのサブジェクト
```

### スクロールには passive リスナーを使う

```ts
window.addEventListener("scroll", handler, { passive: true });
```

スクロールの滑らかさが向上します。ただし、リスナーは `preventDefault()` を呼べません。

### localStorage: バージョン管理と最小化

- 必ず `version` フィールドを保存し、スキーマ変更時に更新して、古いデータは移行または破棄する
- ペイロードは小さく保つ — `localStorage` は同期 API でメインスレッドをブロックする

## 5. 再レンダリングの最適化（MEDIUM）

### コールバック内でのみ使う状態は購読しない

```tsx
// INCORRECT — count が変わるたびに再レンダリングされる
const count = useStore((s) => s.count);
const handler = () => doSomething(count);

// CORRECT — 呼び出し時に 1 回だけ読み取る
const handler = () => {
  const count = useStore.getState().count;
  doSomething(count);
};
```

### 高コストな処理をメモ化したコンポーネントに切り出す

```tsx
// CORRECT — 子コンポーネントは `items` が変わったときだけ再レンダリングされる
const Heavy = memo(function Heavy({ items }: { items: Item[] }) {
  return <Chart data={transform(items)} />;
});
```

### プリミティブでないデフォルト props を巻き上げる

```tsx
// INCORRECT — レンダリングごとに新しい配列が作られ、memo が効かなくなる
<List items={items ?? []} />

// CORRECT
const EMPTY: Item[] = [];
<List items={items ?? EMPTY} />
```

### Effect ではプリミティブな依存値を使う

```tsx
// INCORRECT — レンダリングごとにオブジェクトの同一性が変わる
useEffect(() => {}, [{ id, name }]);

// CORRECT — プリミティブ
useEffect(() => {}, [id, name]);
```

### 生の値ではなく、導出した boolean を購読する

```tsx
// INCORRECT — カートが変わるたびに再レンダリングされる
const cart = useStore((s) => s.cart);
const hasItems = cart.length > 0;

// CORRECT — 空かどうかが切り替わったときだけ再レンダリングされる
const hasItems = useStore((s) => s.cart.length > 0);
```

### 導出値はレンダリング中に計算し、`useEffect` では行わない

```tsx
// INCORRECT
const [full, setFull] = useState("");
useEffect(() => setFull(`${first} ${last}`), [first, last]);

// CORRECT
const full = `${first} ${last}`;
```

### 安定したコールバックには関数形式の `setState` を使う

```tsx
// CORRECT
const increment = useCallback(() => setCount((c) => c + 1), []);
```

### 高コストな値には遅延 state 初期化を使う

```tsx
const [tree] = useState(() => parseTree(largeInput));
```

### 単純なプリミティブには memo を避ける

`useMemo(() => x + 1, [x])` はオーバーヘッドです。memo が価値を発揮するのは、オブジェクトの同一性と高コストな計算に対してです。

### 依存が独立したフックは分割する

```tsx
// INCORRECT — どちらかのソースが変わると、両方のセレクターが再実行される
const { a, b } = useSomething(source1, source2);

// CORRECT
const a = useA(source1);
const b = useB(source2);
```

### インタラクションのロジックはイベントハンドラーに移す

イベントハンドラーはユーザー操作のときだけ実行されます。一方、`useEffect` は依存値が変わるたびに再実行されます。

### 緊急でない更新には `startTransition` を使う

```tsx
const [pending, startTransition] = useTransition();
startTransition(() => setFilters(newFilters));
```

### 高コストなレンダリングには `useDeferredValue` を使う

```tsx
const deferredQuery = useDeferredValue(query);
const results = useMemo(() => expensiveSearch(deferredQuery), [deferredQuery]);
```

### 一時的で頻繁に変わる値には `useRef` を使う

頻繁に変化するが再レンダリングを引き起こすべきでない値（タイムスタンプ、最後に押されたキー、アキュムレーターなど）に使います。

### コンポーネントの中でコンポーネントを定義しない

```tsx
// INCORRECT — Outer がレンダリングされるたびに Inner が新しいコンポーネントになる
function Outer() {
  const Inner = () => <span />;
  return <Inner />;
}
```

レンダリングのたびに新しい `Inner` 型が作られ、リコンシリエーションが無効になり、子要素がアンマウントされます。

## 6. レンダリングパフォーマンス（MEDIUM）

### SVG ではなくラッパーをアニメーションさせる

SVG を囲む `<div>` ラッパーを transform すると GPU アクセラレーションが効きます。SVG 自体を transform すると再描画（paint）が発生します。

### 長いリストには `content-visibility: auto` を使う

```css
.row { content-visibility: auto; contain-intrinsic-size: auto 80px; }
```

ブラウザが画面外のレンダリングをスキップします。数百行のリストでは大きな効果があります。

### 静的な JSX を巻き上げる

```tsx
const STATIC_HEADER = <h1>Title</h1>;
function Page() {
  return <>{STATIC_HEADER}<Body /></>;
}
```

### SVG: 座標の精度を下げる

`d="M10.123456,20.654321"` → `d="M10.12,20.65"`。桁数が増えるほどバイト数が増えますが、見た目の差はサブピクセル程度です。

### インラインスクリプトによるハイドレーション時のちらつき防止

ハイドレーション前に必要な値（テーマ、ロケール）は、React のマウント前に `document.documentElement.dataset.*` を設定する `<script>` をインラインで埋め込みます。

### 想定内のハイドレーション不一致は限定的に抑制する

```tsx
<time suppressHydrationWarning>{new Date().toLocaleString()}</time>
```

差異が出ると分かっているリーフノードに「のみ」使用してください。他の子要素を含むツリーには決して使用しないでください。

### 表示/非表示にはマウント/アンマウントではなく `<Activity>` を使う

React 19 の `<Activity mode="visible|hidden">` は、ツリーの状態と Effect をマウントしたまま非表示にします。タブやアコーディオンでは、アンマウント/再マウントより低コストです。

### 条件付きレンダリングには `&&` よりも三項演算子を使う

```tsx
// INCORRECT — `0` がテキストノードとして描画される
{count && <Badge>{count}</Badge>}

// CORRECT
{count > 0 ? <Badge>{count}</Badge> : null}
```

### ローディング状態には `useTransition` を使う

`startTransition` をアクションと組み合わせます。次の状態を計算している間、React は直前の UI を表示したまま `isPending` を true にします。

### React DOM のリソースヒント

```tsx
import { preload, preconnect } from "react-dom";
preload("/api/critical", { as: "fetch" });
preconnect("https://api.example.com");
```

### `<script>` タグでの `defer` / `async`

`defer` は DOMContentLoaded 後の順序保証付き実行に、`async` は実行順序を問わない即時実行に使います。

## 7. JavaScript パフォーマンス（LOW-MEDIUM）

- **DOM/CSS の変更をまとめる** — プロパティを個別に設定せず、クラスの切り替えや `cssText` で適用する
- **繰り返しのルックアップには `Map`** — `O(1)` 対 `O(n)` の線形探索
- **ループ内でプロパティアクセスをキャッシュする** — `const len = arr.length`
- **純粋関数をメモ化する** — モジュールレベルの `Map<key, result>`
- **`localStorage` の読み取りをキャッシュする** — 同期 API のため、1 レンダリングにつき 1 回だけ読む
- **`filter().map()` を 1 回のパスにまとめる** — `flatMap` または単一の `for`
- **高コストな比較の前に配列長を確認する**
- **関数から早期リターンする**
- **RegExp はループの外に巻き上げる** — コンパイルは無料ではない
- **最小値/最大値は `sort()` ではなくループで求める** — `O(n)` 対 `O(n log n)`
- **所属判定には `Set`/`Map`** — `O(1)` 対 `Array.includes` の `O(n)`
- **不変性が重要なときは、破壊的変更ではなく `toSorted()`** を使う
- **`flatMap` で map と filter を 1 回のパスで行う**
- **重要でない処理には `requestIdleCallback`** を使う

## 8. 高度なパターン（LOW）

### `useEffectEvent` の依存配列

`useEffectEvent` から得られる値は安定しています。Effect の依存配列に追加「しないで」ください。

### イベントハンドラーの ref

メモ化した子コンポーネントに渡す安定したコールバックの場合:

```tsx
const handlerRef = useRef(handler);
useEffect(() => { handlerRef.current = handler; });
const stable = useCallback((arg) => handlerRef.current(arg), []);
```

### アプリ読み込みごとに 1 回だけ初期化する

モジュールレベルのシングルトン（テレメトリ、ロガー）は、`useEffect` ではなくモジュールスコープのフラグでガードします。

### 安定したコールバック ref のための `useLatest`

```tsx
function useLatest<T>(value: T) {
  const ref = useRef(value);
  ref.current = value;
  return ref;
}
```

## 自動化ツール

これらのルールの多くは、現在は自動化されています。

- **Next.js 13.5+ Optimize Package Imports** — バレルインポートの最適化
- **React Compiler**（RFC、canary 版）— 自動メモ化
- **Turbopack** — より高速なビルドと優れたツリーシェイキング
- **Bundle Analyzer**（`@next/bundle-analyzer`）— 初回ロード JS の可視化

プロジェクトで React Compiler を導入している場合は、`rerender-*` の手動メモ化ルールを「レビューのみ」に格下げしてください。コンパイラが処理するためです。手動の `useMemo`/`useCallback` は不要なノイズになります。

## Lighthouse / Web Vitals との対応

| 指標 | 最も関連するカテゴリ |
|---|---|
| **LCP**（Largest Contentful Paint） | ウォーターフォール、バンドルサイズ、リソースヒント |
| **INP**（Interaction to Next Paint） | 再レンダリング、レンダリング、JavaScript |
| **CLS**（Cumulative Layout Shift） | レンダリング（Suspense の配置、画像の寸法） |
| **TBT**（Total Blocking Time） | バンドルサイズ、JavaScript、サードパーティの遅延読み込み |
| **FID**（レガシー） | バンドルサイズ、ハイドレーション |

## 関連

- スキル: [react-patterns](../react-patterns/SKILL.md)、[react-testing](../react-testing/SKILL.md)、[frontend-patterns](../frontend-patterns/SKILL.md)、[accessibility](../accessibility/SKILL.md)、[nextjs-turbopack](../nextjs-turbopack/SKILL.md)
- ルール: [rules/react/](../../../../rules/react/)
- エージェント: `react-reviewer` はコードレビューでこれらのルールを適用し、`react-build-resolver` は関連するビルド失敗を処理します
- コマンド: `/react-review`、`/react-build`、`/react-test`

## 出典

Vercel Labs の `react-best-practices` スキル（MIT ライセンス、著作権 Vercel Engineering、v1.0.0 2026 年 1 月）を基にしています。出典: [https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices](https://github.com/vercel-labs/agent-skills/tree/main/skills/react-best-practices)。

このスキルは、元の 70 ルールのカタログを、1 つの参照しやすいリファレンスとして再構成し、適応させたものです。拡張例を含む元のルールセット全体については、上流リポジトリを参照してください。
