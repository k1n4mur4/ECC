---
name: react-testing
description: React Testing Library、Vitest/Jest、ネットワークモック用の MSW、axe によるアクセシビリティアサーション、およびコンポーネントテストと Playwright/Cypress のエンドツーエンド実行との判断境界を扱う React コンポーネントテストのスキルです。React コンポーネント、フック、ページのテストを書く、または修正するときに使用します。
metadata:
  origin: ECC
---

# React テスト

振る舞いに焦点を当てたコンポーネントテスト、カスタムフックのテスト、アクセシビリティアサーション、ネットワークレベルのモックのための、包括的な React テストパターンです。

## 有効化するタイミング

- React コンポーネント、カスタムフック、ページのテストを書くとき
- テストのない既存コンポーネントにテストカバレッジを追加するとき
- Enzyme やクラスコンポーネント時代のパターンから React Testing Library へ移行するとき
- 新しい React プロジェクトに Vitest または Jest をセットアップするとき
- テストで HTTP リクエストをモックするとき
- アクセシビリティ違反をアサートするとき
- どのテストを RTL、Playwright Component Testing、フル E2E のいずれに置くかを判断するとき

## コア原則

実装の詳細ではなく、ユーザーが目にするものと行う操作をテストします。

テストでは次のことを行います。

- 本番と同じプロバイダーでコンポーネントをレンダリングする
- アクセシブルなクエリ（role、label）と `userEvent` で操作する
- 目に見える出力と観測可能な副作用（コールバックの発火、リクエストの送信）をアサートする

テストでは次のことを避けます。

- コンポーネントの state、子に渡された props、どのフックが呼ばれたかを検査する
- React 自体やフレームワークのフックをモックする
- ユーザーに影響する範囲を超えて、レンダリング回数や DOM 構造をアサートする

## ライブラリの選択

| ランナー | 使う場面 | 備考 |
|---|---|---|
| **Vitest** | Vite、Remix、モダンな構成 | より高速、ネイティブ ESM、Jest 互換 API |
| **Jest** | Next.js、CRA、確立されたリポジトリ | 多くの React プロジェクトのデフォルト |
| **Playwright Component Testing** | 実際のブラウザエンジンが必要な場合 | JSDOM に必要な機能がない場合に使用 |
| **Cypress Component Testing** | 実ブラウザ、Cypress を既に使用している場合 | Playwright CT の代替 |

1 つを選んでください。明確なレーン分離がない限り、同じリポジトリで RTL + Vitest と Playwright CT の両方を実行しないでください。

## クエリの優先順位

React Testing Library は 3 つの階層でクエリを提供します。上から順に使用してください。

1. **すべての人にアクセシブル**: `getByRole`、`getByLabelText`、`getByPlaceholderText`、`getByText`、`getByDisplayValue`
2. **セマンティック**: `getByAltText`、`getByTitle`
3. **テスト ID（最終手段）**: `getByTestId`

```tsx
// 最良
screen.getByRole("button", { name: /save/i });

// 入力欄ならこれで OK
screen.getByLabelText("Email");

// 最終手段
screen.getByTestId("save-btn");
```

バリアント:

- `getBy*` — 一致するものがなければ例外を投げる
- `queryBy*` — `null` を返す（「存在しないこと」のアサートに使用）
- `findBy*` — 非同期で Promise を返す（非同期処理の後に現れる要素に使用）

## `userEvent` によるユーザー操作

```tsx
import userEvent from "@testing-library/user-event";

test("submits the form", async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();
  render(<UserForm onSubmit={onSubmit} />);

  await user.type(screen.getByLabelText("Email"), "user@example.com");
  await user.click(screen.getByRole("button", { name: /save/i }));

  expect(onSubmit).toHaveBeenCalledWith({ email: "user@example.com" });
});
```

- userEvent の呼び出しは必ず `await` する
- `userEvent.setup()` はテストごとに 1 回呼び、返された `user` を再利用する
- `userEvent` は実際のブラウザの操作シーケンスをシミュレートし、`fireEvent` は単一の合成イベントをディスパッチする。`userEvent` を優先する

## 非同期パターン

```tsx
// 非同期処理の後に現れる要素
expect(await screen.findByText("Loaded")).toBeInTheDocument();

// 副作用のアサーション
await waitFor(() => expect(saveSpy).toHaveBeenCalled());

// 消えるはずの要素
await waitForElementToBeRemoved(() => screen.queryByText("Loading"));
```

`setTimeout` + アサーションは決して使わないでください。不安定になります。上記のマッチャーを使用します。

## MSW によるネットワークモック

Mock Service Worker はネットワーク層でモックします。コンポーネント、フック、fetch ライブラリはすべて本番とまったく同じように動作します。

### セットアップ

```ts
// test/setup.ts
import { setupServer } from "msw/node";
import { http, HttpResponse } from "msw";

export const handlers = [
  http.get("/api/users/:id", ({ params }) =>
    HttpResponse.json({ id: params.id, name: "Alice" }),
  ),
  http.post("/api/users", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: "new-id", ...body }, { status: 201 });
  }),
];

export const server = setupServer(...handlers);

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: "error"` を設定して、モックされていないリクエストがあればテストが明確に失敗するようにしてください。黙って通るテストは、赤いテストより悪いものです。

### テストごとの上書き

```tsx
test("renders error on 500", async () => {
  server.use(
    http.get("/api/users/:id", () => new HttpResponse(null, { status: 500 })),
  );
  render(<UserPage id="1" />);
  expect(await screen.findByText(/something went wrong/i)).toBeInTheDocument();
});
```

## プロバイダーのラッピング

プロバイダーは `test-utils.tsx` で一度だけラップします。

```tsx
// test-utils.tsx
import { render, RenderOptions } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

export function renderWithProviders(
  ui: React.ReactElement,
  options?: RenderOptions,
) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={lightTheme}>
        <MemoryRouter>{ui}</MemoryRouter>
      </ThemeProvider>
    </QueryClientProvider>,
    options,
  );
}

export * from "@testing-library/react";
```

その後、すべてのテストファイルで `import { renderWithProviders, screen } from "test-utils"` します。

## カスタムフックのテスト

```tsx
import { renderHook, act } from "@testing-library/react";

test("useCounter increments and decrements", () => {
  const { result } = renderHook(() => useCounter(0));

  expect(result.current.count).toBe(0);

  act(() => result.current.increment());
  expect(result.current.count).toBe(1);

  act(() => result.current.decrement());
  expect(result.current.count).toBe(0);
});

test("useCounter accepts initial value", () => {
  const { result } = renderHook(() => useCounter(10));
  expect(result.current.count).toBe(10);
});

test("useUser fetches user data", async () => {
  // QueryClient はテストごとに wrapper の外で 1 回だけ生成し、再レンダリングをまたいで保持する。
  // wrapper のクロージャ内で生成すると、レンダリングのたびにキャッシュ状態がリセットされ、不安定なテストになる。
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );

  const { result } = renderHook(() => useUser("1"), { wrapper });

  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toEqual({ id: "1", name: "Alice" });
});
```

- 状態を変更する呼び出しは `act` でラップする
- フックの公開 API のみを通してテストする
- コンテキストを使用するフックには `wrapper` を渡す

## アクセシビリティアサーション

```tsx
import { axe, toHaveNoViolations } from "jest-axe"; // または vitest-axe
expect.extend(toHaveNoViolations);

test("UserCard has no a11y violations", async () => {
  const { container } = render(<UserCard user={mockUser} />);
  expect(await axe(container)).toHaveNoViolations();
});
```

すべてのインタラクティブなコンポーネントのコンポーネントテストで axe を実行してください。次のような問題を検出できます。

- フォーム入力欄のラベル欠落
- 無効な ARIA の使用
- 色コントラスト不足（限定的 — JSDOM には実際の CSS エンジンがないため、インラインスタイルでのみ機能します。視覚的なコントラストは Playwright で扱います）
- 画像の alt テキスト欠落
- 見出し順序の違反

相互参照: より広範なアクセシビリティテストのプレイブックは [skills/accessibility/SKILL.md](../accessibility/SKILL.md) を参照してください。

## スナップショットテストを使うべきでない場合

レンダリング出力のスナップショットには次の問題があります。

- スタイル変更のたびに壊れる
- レビューで形式的に承認されてしまう
- 振る舞いではなく実装の詳細（DOM 構造）をテストしている

スナップショットを使ってよい場合:

- 純粋なデータシリアライズ関数（`formatInvoice(invoice)` -> 安定した文字列）
- 生成される設定ファイル（例: webpack 設定の出力）

コンポーネントの視覚的回帰テストには、Playwright/Cypress のスクリーンショットや Percy/Chromatic を使用してください。DOM 文字列ではなく、実際の視覚的な差分を比較できます。

## Playwright / Cypress を使うべき場合

JSDOM（Vitest/Jest が使用）にはできないこと:

- 実際のレイアウト（flexbox、grid、ビューポートクエリ）のレンダリング
- ネイティブなブラウザアニメーションや CSS トランジションの実行
- スクロール動作、ドラッグアンドドロップ、クリップボードからの貼り付けのテスト
- iframe、ポップアップ、ダウンロード、クロスオリジンのフローの処理
- DevTools を完全にサポートした、制御された環境での実ネットワークの実行

これらのいずれかが必要な場合は、Playwright Component Testing（実ブラウザでのコンポーネントテスト）またはフル E2E を使用してください。[e2e-testing スキル](../e2e-testing/SKILL.md)を参照してください。

判断境界:

- フック、プレゼンテーショナルコンポーネント、ロジックを持つフォーム -> RTL
- レイアウトが重要なコンポーネント、または JSDOM にないブラウザ API を使用するコンポーネント -> Playwright CT
- 複数ページにまたがる完全なユーザーフロー -> Playwright/Cypress E2E

## カバレッジ目標

| レイヤー | 目標 |
|---|---|
| 純粋なユーティリティ | >=90% |
| カスタムフック | >=85% |
| プレゼンテーショナルコンポーネント | >=80% — 行数ではなく振る舞い |
| コンテナコンポーネント | >=70% — ゴールデンパス + エラー状態 |
| ページ | E2E で別途カバー。最低限スモークテスト |

`vitest.config.ts` / `jest.config.js` で設定します。

```ts
// vitest.config.ts
test: {
  coverage: {
    provider: "v8",
    reporter: ["text", "html", "lcov"],
    thresholds: {
      lines: 80,
      functions: 80,
      branches: 70,
      statements: 80,
    },
  },
}
```

## アンチパターン

- `container.querySelector("...")` — アクセシビリティクエリを迂回し、実際のユーザーなら失敗する場面でもテストが通ってしまう
- レンダリング回数のアサート — 実装の詳細
- `jest.mock("react", ...)` — React は決してモックしない。代わりにコンポーネントをリファクタリングする
- デフォルトで子コンポーネントをモックする — 分離ではなく統合をテストしている。子が重い副作用を持つ場合にのみモックする
- `act()` の警告を無視する — 実際のバグ（アンマウント後の state 更新、非同期ラップの欠落）を示すシグナル
- テスト間で可変な状態を共有する — テストの実行順序が変わると不安定になる
- `it.skip()` を外しても通るテスト — そのテストは、あなたが思っているものを実際にはアサートしていない

## TDD ワークフロー

```
RED     -> 次の要件に対する失敗するテストを書く
GREEN   -> 通すための最小限のコンポーネントコードを書く
REFACTOR -> コンポーネントを改善し、テストはグリーンのまま保つ
REPEAT  -> 次の要件へ
```

新しいコンポーネントの場合:

1. コンポーネントの props の型とシグネチャを定義する
2. 最も単純なケースの最初のテストを書く
3. 正しい理由で失敗することを確認する
4. 通すのに必要最小限だけ実装する
5. 次のテストケースを追加する
6. 3 つ目の類似テストでパターンが見えてきたらリファクタリングする

## テストコマンド

```bash
# Vitest
vitest                            # ウォッチ
vitest run                        # 1 回実行
vitest run --coverage             # カバレッジ付き
vitest run path/to/file.test.tsx  # 単一ファイル

# Jest
jest --watch
jest --coverage
jest path/to/file.test.tsx

# CI モード
CI=true vitest run --coverage
```

## 関連項目

- ルール: [rules/react/testing.md](../../../../rules/react/testing.md)
- スキル: [react-patterns](../react-patterns/SKILL.md)、[accessibility](../accessibility/SKILL.md)、[e2e-testing](../e2e-testing/SKILL.md)、[tdd-workflow](../tdd-workflow/SKILL.md)
- エージェント: `react-reviewer`（コードレビュー中にテストの品質をレビューする）、`tdd-guide`（TDD プロセスを徹底する）
- コマンド: `/react-test`、`/react-review`

## 例

### MSW と userEvent によるフォーム送信

```tsx
test("submits user form and shows success", async () => {
  server.use(
    http.post("/api/users", () =>
      HttpResponse.json({ id: "1", name: "Alice" }, { status: 201 }),
    ),
  );

  const user = userEvent.setup();
  renderWithProviders(<UserForm />);

  await user.type(screen.getByLabelText("Name"), "Alice");
  await user.type(screen.getByLabelText("Email"), "alice@example.com");
  await user.click(screen.getByRole("button", { name: /save/i }));

  expect(await screen.findByText(/saved successfully/i)).toBeInTheDocument();
});
```

### エラーバウンダリのテスト

```tsx
function Broken() {
  throw new Error("boom");
}

test("error boundary renders fallback", () => {
  // 想定された throw による React の console.error ノイズを抑制し、その後に復元する。
  // こうしないとスパイがテスト間でリークし、他の場所の本物のエラーを隠してしまう。
  const errorSpy = vi.spyOn(console, "error").mockImplementation(() => {});
  try {
    render(
      <ErrorBoundary fallback={<div>Something went wrong</div>}>
        <Broken />
      </ErrorBoundary>,
    );

    expect(screen.getByText("Something went wrong")).toBeInTheDocument();
  } finally {
    errorSpy.mockRestore();
  }
});
```

### Suspense バウンダリのテスト

```tsx
test("shows loading then content", async () => {
  renderWithProviders(
    <Suspense fallback={<div>Loading...</div>}>
      <UserDetail id="1" />
    </Suspense>,
  );

  expect(screen.getByText("Loading...")).toBeInTheDocument();
  expect(await screen.findByText("Alice")).toBeInTheDocument();
});
```
