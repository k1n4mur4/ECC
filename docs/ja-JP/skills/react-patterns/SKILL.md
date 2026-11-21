---
name: react-patterns
description: フックの規律、サーバー/クライアントコンポーネントの境界、Suspense + エラーバウンダリ、フォームアクション、データフェッチ、状態管理の判断ツリー、アクセシビリティファーストの構成を含む React 18/19 のパターン。React コンポーネントの作成またはレビュー時に使用します。
metadata:
  origin: ECC
---

# React パターン

堅牢でアクセシブルかつ高性能なコンポーネントツリーを構築するための、React 18/19 の慣用的なパターンです。

## 有効化するタイミング

- React 関数コンポーネント、カスタムフック、コンポーネントツリーの作成または変更
- JSX/TSX ファイルのレビュー
- 状態の形やコンポーネント構成の設計
- クラスコンポーネントや、古い `forwardRef`/`useEffect` 依存のコードの移行
- ローカル状態、リフトアップした状態、コンテキスト、外部ストアの中からの選択
- Server Components / Client Components（Next.js App Router、RSC）の扱い
- React 19 のアクションまたは制御された入力によるフォームの実装
- TanStack Query / SWR / RSC によるデータフェッチの組み込み

## コア原則

### 1. レンダーは props と state の純粋関数である

```tsx
// Good: レンダー中に導出する
function Cart({ items }: { items: CartItem[] }) {
  const total = items.reduce((sum, i) => sum + i.price * i.qty, 0);
  return <span>{formatMoney(total)}</span>;
}

// Bad: 導出された state を別に保持している
function Cart({ items }: { items: CartItem[] }) {
  const [total, setTotal] = useState(0);
  useEffect(() => {
    setTotal(items.reduce((sum, i) => sum + i.price * i.qty, 0));
  }, [items]);
  return <span>{formatMoney(total)}</span>;
}
```

`useEffect` 内で派生状態を扱うと、レンダーサイクルが増え、同期がずれる恐れがあり、データフローも見えにくくなります。

### 2. 副作用はレンダーの外に置く

エフェクト、ミューテーション、ネットワーク呼び出し、サブスクリプションは、イベントハンドラーまたは `useEffect` 内に置きます。レンダー本体には決して置きません。

### 3. 継承よりコンポジション

React にはコンポーネントの継承モデルがありません。`children`、レンダープロップ、またはコンポーネントを渡す props で組み合わせます。

## フックの規律

完全なルールセットは [rules/react/hooks.md](../../../../rules/react/hooks.md) を参照してください。要点は次のとおりです。

- トップレベルのみで呼び出し、条件付きでは呼び出さない
- すべてのサブスクリプション、インターバル、リスナーをクリーンアップする
- 新しい状態が古い状態に依存する場合は関数型アップデーター（`setX(prev => prev + 1)`）を使う
- 既定の立場: メモ化しない。`useMemo`/`useCallback` は、プロファイラーまたは依存チェーンが必要性を証明した場合にのみ追加する
- カスタムフックの抽出は、同じフックのシーケンスが 2 つ以上のコンポーネントに現れる場合のみ

## 状態の配置場所の判断ツリー

```
Used by one component?
  -> useState inside it

Used by parent + a few descendants?
  -> lift to nearest common ancestor

Used across distant branches AND low-frequency reads (theme, auth, locale)?
  -> React Context

High-frequency updates shared across the tree?
  -> external store (Zustand, Jotai, Redux Toolkit)

Derived from a server?
  -> server-state library (TanStack Query, SWR, RSC fetch)
```

ほとんどのページにはコンテキストもグローバルストアも不要です。リフトアップの重複が苦痛になるまでは、抽象化を控えてください。

## Server / Client Components（RSC）

```tsx
// Server Component - デフォルト、async 可、それ自体の JS は配信されない
export default async function ProductPage({ params }: { params: { id: string } }) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  if (!product) notFound();
  return <ProductView product={product} />;
}

// Client Component - "use client" でオプトインする
"use client";
export function AddToCartButton({ productId }: { productId: string }) {
  const [pending, startTransition] = useTransition();
  return (
    <button
      disabled={pending}
      onClick={() => startTransition(() => addToCart(productId))}
    >
      {pending ? "Adding..." : "Add to cart"}
    </button>
  );
}
```

境界のルール:

- Server -> Client: シリアライズ可能な props または `children` を渡す
- Client -> Server: `<form action={...}>` 経由、またはイベントハンドラーから命令的に Server Actions を呼び出す
- Client Component のファイルから Server Component を `import` しない。代わりに `children` 経由で組み合わせる

## Suspense + エラーバウンダリ

```tsx
<ErrorBoundary fallback={<ErrorView />}>
  <Suspense fallback={<UserSkeleton />}>
    <UserDetail id={id} />
  </Suspense>
</ErrorBoundary>
```

- Suspense バウンダリはルートの最上位ではなく、データの近くに置く。コンテンツを段階的に表示する
- エラーバウンダリは現在もクラス API です。フックで扱いやすいラッパーには `react-error-boundary` を使います
- エラーバウンダリが捕捉するのは、子のレンダー中、ライフサイクル、コンストラクターでスローされたエラーです。イベントハンドラーや非同期コード内のエラーは捕捉しません

## フォーム

### React 19 のフォームアクション（新規コードで推奨）

```tsx
"use client";
import { useActionState } from "react";

const initial = { error: null as string | null };

async function updateUserAction(_prev: typeof initial, formData: FormData) {
  "use server";
  const parsed = UserSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { error: "Invalid input" };
  await db.user.update({ where: { id: parsed.data.id }, data: parsed.data });
  return { error: null };
}

export function UserForm() {
  const [state, formAction, pending] = useActionState(updateUserAction, initial);
  return (
    <form action={formAction}>
      <input name="name" required />
      <button type="submit" disabled={pending}>Save</button>
      {state.error && <p role="alert">{state.error}</p>}
    </form>
  );
}
```

### 制御された入力

値が他の UI を駆動する場合、キー入力ごとにフォーマットする場合、またはリアルタイムバリデーションを実装する場合に、制御された入力を使います。

### 複雑なフォーム

複数ステップのフォーム、動的なフィールド配列、フィールド間のバリデーションには、ライブラリ（React Hook Form、TanStack Form）を使います。些細な複雑さを超えるフォームの状態管理を自前で実装するのは、保守上の罠です。

## データフェッチの判断マトリクス

| 必要なもの | ツール |
|---|---|
| Next.js App Router でのリクエストごとのデータ | RSC の `await fetch()` |
| クライアントサイドのキャッシュ + ミューテーション + 無効化 | TanStack Query |
| 軽量なクライアントキャッシュ + 再検証 | SWR |
| リアルタイムサブスクリプション | Server-Sent Events、WebSockets、またはライブラリのサブスクリプション API |
| 一度きりの投げっぱなし処理 | イベントハンドラー内の `fetch()` |

アプリケーションデータに `useEffect` + `fetch` を使うのは避けてください。競合状態があり、キャッシュも再試行もなく、Suspense とも統合できません。

## コンポジションのレシピ

### `children` によるスロット

```tsx
<Layout>
  <Header />
  <Main>{content}</Main>
</Layout>
```

### 名前付きスロット

```tsx
<Page header={<Nav />} sidebar={<Filters />}>
  <Results />
</Page>
```

### コンパウンドコンポーネント（Context による状態共有）

```tsx
<Tabs defaultValue="profile">
  <Tabs.List>
    <Tabs.Trigger value="profile">Profile</Tabs.Trigger>
    <Tabs.Trigger value="settings">Settings</Tabs.Trigger>
  </Tabs.List>
  <Tabs.Panel value="profile"><Profile /></Tabs.Panel>
  <Tabs.Panel value="settings"><Settings /></Tabs.Panel>
</Tabs>
```

### レンダープロップ / function-as-child

親がレンダリング出力にパラメーターを渡す必要がある場合に便利です。

```tsx
<DataLoader id={id}>
  {({ data, isLoading }) => isLoading ? <Spinner /> : <UserCard user={data} />}
</DataLoader>
```

モダンな代替案: 同じ形を返すフック（`useData(id)`）。たいていはこちらのほうがすっきりします。

## パフォーマンス

### `React.memo` が実際に役立つ場合

コンポーネントを `React.memo` でラップするのは、次の条件をすべて満たす場合のみです。

1. 頻繁に再レンダリングされる
2. レンダー間で props が通常は同じである
3. レンダーのコストが計測可能なほど高い

`React.memo` はレンダーごとに等価性チェックを追加します。ほとんどのレンダーで props が異なる場合、そのチェックは純粋なオーバーヘッドです。

### レンダーのカスケードを避ける

- 可能な限り、状態は上ではなく下へ移す
- コンテキストを分割する: 関心事ごとに 1 つのコンテキストとし、`themeContext` の変更で認証コンテキストのコンシューマーが再レンダリングされないようにする
- 外部状態ライブラリには `useSyncExternalStore` を使う。安全な並行レンダリングに必須

### リスト

- 安定した `key` props を指定する（配列のインデックスではなくデータベースの id）
- 1 行あたりの処理が軽くない場合に、表示アイテム数が約 50 を超えたら、`@tanstack/react-virtual` または `react-window` で長いリストを仮想化する

## アクセシビリティファーストのコンポジション

- `role` 属性に頼る前に、必ずセマンティック HTML（`<button>`、`<a>`、`<nav>`、`<main>`）をレンダリングする
- すべてのインタラクティブ要素はキーボードで到達可能でなければならない
- フォーム入力にはラベルが必要。`<label htmlFor>`、またはアイコンで視覚的にラベル付けされている場合は `aria-label` を使う
- ルート変更時およびモーダルの開閉時にフォーカスを管理する
- コンポーネントテストで `axe` を実行する（[skills/react-testing](../react-testing/SKILL.md) を参照）
- 相互参照: [skills/accessibility/SKILL.md](../accessibility/SKILL.md) は WCAG の基準とパターンライブラリを扱う

## ルーティング

このスキルはルーターに依存しません。上記のパターンは React Router、TanStack Router、Next.js App Router、Remix Router で動作します。ルーター固有のパターン（ローダー、アクション、ネストされたレイアウト）はルーターのドキュメントに従います。それらは React コアの上に重なるフレームワークの関心事です。

## 対象外（参照用セクション）

- **Next.js 固有事項**: App Router のデータ読み込み、Route Handlers、Middleware、Parallel Routes は別の関心事のため、Next.js のドキュメントを参照する
- **React Native**: プラットフォーム固有のパターンは大きく異なるため、別の `react-native-patterns` スキルを設けるのが適切です（まだ存在しません）
- **Remix**: ローダー/アクションの規約は RSC と重なるが、Remix のドキュメントに従う

## 関連

- ルール: [rules/react/](../../../../rules/react/) — coding-style、hooks、patterns、security、testing
- スキル: Vercel 由来のパフォーマンスルールセットの [react-performance](../react-performance/SKILL.md)、フレームワーク横断の UI 関心事の [frontend-patterns](../frontend-patterns/SKILL.md)、[accessibility](../accessibility/SKILL.md)、フレームワーク比較の [angular-developer](../angular-developer/SKILL.md)
- エージェント: コードレビューの `react-reviewer`、ビルド/バンドラーエラーの `react-build-resolver`
- コマンド: `/react-review`、`/react-build`、`/react-test`

## 例

### デバウンス検索用のカスタムフック

```tsx
function useDebounce<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(id);
  }, [value, delay]);
  return debounced;
}

function SearchBox() {
  const [query, setQuery] = useState("");
  const debounced = useDebounce(query, 300);
  const { data } = useQuery({
    queryKey: ["search", debounced],
    queryFn: () => searchApi(debounced),
    enabled: debounced.length > 0,
  });
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <Results items={data ?? []} />
    </>
  );
}
```

### React 19 の `useOptimistic` による楽観的 UI

```tsx
"use client";
import { useOptimistic } from "react";

export function MessageList({ messages }: { messages: Message[] }) {
  const [optimistic, addOptimistic] = useOptimistic(
    messages,
    (state, newMessage: Message) => [...state, newMessage],
  );

  async function send(formData: FormData) {
    const text = String(formData.get("text"));
    addOptimistic({ id: "pending", text, sender: "me" });
    await saveMessage(text);
  }

  return (
    <>
      <ul>{optimistic.map((m) => <li key={m.id}>{m.text}</li>)}</ul>
      <form action={send}>
        <input name="text" />
        <button type="submit">Send</button>
      </form>
    </>
  );
}
```

### レンダーのカスケードを避けるためのコンテキスト分割

```tsx
// 2 つのコンテキスト: 1 つはほとんど変化せず、もう 1 つは頻繁に変化する
const ThemeContext = createContext<Theme>("light");
const NotificationsContext = createContext<Notification[]>([]);

// ThemeContext だけを使うコンポーネントは、通知が変化しても再レンダーされない
```
