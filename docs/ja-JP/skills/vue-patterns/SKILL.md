---
name: vue-patterns
description: Vue.js 3 の Composition API パターン、コンポーネントアーキテクチャ、リアクティビティのベストプラクティス、Pinia による状態管理、Vue Router のナビゲーション、Nuxt の SSR パターン。Vue、Nuxt、Vite、Pinia のプロジェクトで有効化されます。Vue 3、Nuxt、Pinia のコード（Composition API、リアクティビティ、ルーターナビゲーション）を構築またはレビューするときに使用します。
origin: ECC
---

# Vue.js のパターンとベストプラクティス

Composition API（`<script setup>`）を用いた Vue.js 3 開発の包括的なガイドです。コンポーネント設計、リアクティビティ、状態管理、ルーティング、テスト、SSR パターンを扱います。素の Vue と異なる場合は、Nuxt 固有のガイダンスも含めています。

## 有効化するタイミング

次の場合にこのスキルを有効化します。
- プロジェクトが Vue.js（任意のバージョン）、Nuxt、Vite + Vue、または Pinia を使用している。
- ユーザーが Vue のコンポーネントアーキテクチャ、コンポーザブル、リアクティビティ、状態管理について質問している。
- Vue のシングルファイルコンポーネント（`.vue` ファイル）をレビューしている。
- Vue Router、Pinia ストア、Vite/Vitest の設定をセットアップしている。
- Vue 固有のパフォーマンス、セキュリティ、SSR パターンを議論している。

---

## 1. プロジェクト構成

### 推奨レイアウト（フィーチャーファースト）

```
src/
├── api/              # API クライアントとエンドポイント定義
├── assets/           # 静的アセット（画像、フォント、アイコン）
├── components/       # 共有・再利用可能なコンポーネント
│   ├── base/         # 基本 UI プリミティブ（Button、Input、Modal）
│   └── features/     # フィーチャー固有の共有コンポーネント
├── composables/      # 再利用可能な Composition API ロジック
├── layouts/          # ページレイアウト（任意）
├── pages/            # ルートレベルのページコンポーネント
├── router/           # Vue Router の設定
├── stores/           # Pinia ストア
├── types/            # TypeScript の型定義
├── utils/            # 純粋なユーティリティ関数
└── App.vue           # ルートコンポーネント
```

### ファイル命名

| 規約 | 使用場面 |
|-----------|-------------|
| `PascalCase.vue` | すべてのコンポーネント（`vue/multi-word-component-names` で強制） |
| `useCamelCase.ts` | コンポーザブル |
| `camelCase.ts` | ユーティリティ、API クライアント、型 |
| `kebab-case` ディレクトリ | ルートセグメント、フィーチャーフォルダ |

---

## 2. コンポーネントアーキテクチャ

### シングルファイルコンポーネントの順序

```vue
<script setup lang="ts">
// 1. インポート（vue → エコシステム → 絶対パス → 相対パス）
// 2. Props・Emits・Slots
// 3. コンポーザブル
// 4. ローカル状態（ref/reactive）
// 5. 算出プロパティ
// 6. メソッド
// 7. ウォッチャー
// 8. ライフサイクルフック
</script>

<template>
  <!-- Template content -->
</template>

<style scoped>
  /* Scoped styles */
</style>
```

### プレゼンテーショナルとコンテナ

- **コンテナコンポーネント**: データフェッチ、状態、副作用を担います。プレゼンテーショナルコンポーネントをレンダリングします。
- **プレゼンテーショナルコンポーネント**: props を受け取り、イベントを emit します。API 呼び出しやストアへのアクセスは行いません。純粋なレンダリングのみです。

### Props のベストプラクティス

```ts
// デフォルト値付きの型ベース props
interface Props {
  label: string;
  variant?: "primary" | "secondary";
  disabled?: boolean;
  items: Item[];
}

const props = withDefaults(defineProps<Props>(), {
  variant: "primary",
  disabled: false,
});
```

- 常に `type` を指定し、適切な場合は `required`/`default` も指定します。
- 真偽値の props には `isXxx`、`hasXxx`、`canXxx` を使います。
- props は決して変更せず、代わりにイベントを emit します。
- v-model バインディングには `defineModel()`（Vue 3.4+）、または `modelValue` + `update:modelValue` を使います。

### イベント

```ts
const emit = defineEmits<{
  submit: [];
  "update:modelValue": [value: string];
  select: [id: string, index: number];
}>();
```

- テンプレートでは kebab-case を使います（`@update:model-value`）。
- スクリプトでは camelCase を使います（`emit("update:modelValue", val)`）。

---

## 3. コンポーザブル（再利用可能なロジック）

### 構造

```ts
// composables/useDebounce.ts
export function useDebounce<T>(value: MaybeRef<T>, delay: number): Ref<T> {
  const debounced = ref(toValue(value)) as Ref<T>;

  let timer: ReturnType<typeof setTimeout>;
  watch(
    () => toValue(value),
    (newVal) => {
      clearTimeout(timer);
      timer = setTimeout(() => { debounced.value = newVal; }, delay);
    }
  );

  onUnmounted(() => clearTimeout(timer));
  return readonly(debounced);
}
```

### ルール

- `use` プレフィックスで始めなければなりません。
- リアクティブな値（`ref`、`computed`、`reactive`）を返し、プレーンなプリミティブは返しません。
- リアクティブな入力は `MaybeRef` / `toRef()` / `toValue()` で受け取ります。
- 副作用は `onUnmounted` またはウォッチャーの `onCleanup` でクリーンアップします。
- モジュールスコープでの副作用は禁止です。

### ミックスインとの比較

コンポーザブルは Vue 2 のミックスインを完全に置き換えます。
- **ミックスイン**: データフローが不透明で、信頼できる情報源（source of truth）が衝突し、名前の競合も起きます。
- **コンポーザブル**: 明示的なインポート、明確な戻り値を持ち、合成可能でツリーシェイキングにも対応します。

---

## 4. 状態管理

### 何をいつ使うか

| パターン | ユースケース |
|---------|----------|
| `ref()` / `reactive()` | コンポーネントのローカル状態 |
| Props + Emits | 親子間の通信 |
| Provide / Inject | テーマ、設定、プラグイン API |
| Pinia ストア | グローバルで共有される複雑な状態 |
| サーバー状態コンポーザブル | キャッシュ付きの API データ（`fetch`/TanStack Query をラップ） |

### Pinia のセットアップストア（推奨）

```ts
// stores/useCartStore.ts
export const useCartStore = defineStore("cart", () => {
  const items = ref<CartItem[]>([]);
  const isLoading = ref(false);

  const totalPrice = computed(() =>
    items.value.reduce((sum, i) => sum + i.price * i.quantity, 0)
  );
  const itemCount = computed(() =>
    items.value.reduce((sum, i) => sum + i.quantity, 0)
  );

  async function addItem(productId: string) {
    isLoading.value = true;
    try {
      const item = await fetchProduct(productId);
      const existing = items.value.find(i => i.id === item.id);
      if (existing) existing.quantity++;
      else items.value.push({ ...item, quantity: 1 });
    } finally {
      isLoading.value = false;
    }
  }

  return { items, isLoading, totalPrice, itemCount, addItem };
});
```

- セットアップストア構文を使います（オプションストアは使いません）。
- ビジネスレベルの変更にはアクションを、まとまった更新には `$patch()` を優先します。
- すべての非同期アクションで、ローディング、成功、エラーを処理します。

---

## 5. Vue Router

### ルート定義

```ts
const routes = [
  {
    path: "/users/:id",
    name: "user-detail",
    component: () => import("@/pages/UserDetail.vue"), // 遅延読み込み
    props: true, // パラメータを props として渡す
    meta: { requiresAuth: true },
  },
];
```

### ナビゲーションガード

```ts
router.beforeEach((to, from) => {
  const { isLoggedIn } = useAuthStore();
  if (to.meta.requiresAuth && !isLoggedIn) {
    return { name: "login", query: { redirect: to.fullPath } };
  }
});
```

### リアクティブなルートパラメータ

コンポーネントがマウントされたままルートパラメータが変わる場合:

```ts
const route = useRoute();
const id = computed(() => route.params.id as string);
watch(id, (newId) => fetchItem(newId));
```

---

## 6. テンプレートパターン

### テンプレート構文

```vue
<!-- v-if/v-else-if/v-else -->
<div v-if="isLoading">Loading...</div>
<div v-else-if="error">Error: {{ error }}</div>
<div v-else>{{ content }}</div>

<!-- v-show for frequent toggles -->
<div v-show="isOpen">Toggled content</div>

<!-- v-for with stable keys -->
<div v-for="item in items" :key="item.id">{{ item.name }}</div>

<!-- Computed filtered list (not v-if + v-for on same element) -->
<div v-for="item in activeItems" :key="item.id">{{ item.name }}</div>

<!-- Event handling -->
<form @submit.prevent="handleSubmit">
  <button type="submit">Save</button>
</form>

<!-- v-model -->
<input v-model="name" />
<CustomInput v-model="value" v-model:title="title" />
```

---

## 7. パフォーマンス

| 手法 | 使用場面 |
|-----------|-------------|
| `v-memo` | ほとんど変化しないリスト項目 |
| `v-once` | 一度だけレンダリングされ、以降ずっと静的なコンテンツ |
| `shallowRef()` | 丸ごと置き換えられる大きなデータ構造 |
| `shallowReactive()` | トップレベルのプロパティのみがリアクティブでよい場合 |
| `v-if` より `v-show` | 表示の切り替えが頻繁な場合 |
| `<KeepAlive :max="10">` | 切り替えられるビューのキャッシュ |
| 遅延ルート | 重要でないルートに `() => import(...)` |
| `Suspense` | フォールバック付きの非同期コンポーネント読み込み |

---

## 8. テスト

### スタック

- **Vitest**: ユニットテストとコンポーネントテスト
- **Vue Test Utils**: マウントと操作
- **@pinia/testing**: ストアのモック
- **Playwright**: E2E

### コンポーネントテストパターン

```ts
import { mount } from "@vue/test-utils";
import { createPinia, setActivePinia } from "pinia";
import UserCard from "./UserCard.vue";

beforeEach(() => { setActivePinia(createPinia()); });

it("renders and emits", async () => {
  const wrapper = mount(UserCard, {
    props: { user: { id: "1", name: "Alice" } },
  });
  expect(wrapper.text()).toContain("Alice");
  await wrapper.find("button").trigger("click");
  expect(wrapper.emitted("select")![0]).toEqual(["1"]);
});
```

---

## 9. Nuxt 固有のパターン

### 自動インポート

Nuxt は `ref`、`computed`、`watch`、`useFetch`、`useAsyncData` などを自動インポートします。インポートせずに直接使用します。Nuxt 以外のプロジェクトでは、常に明示的にインポートします。

### useAsyncData / useFetch

```ts
const { data: user, pending, error, refresh } = await useAsyncData(
  "user", // キャッシュ用の一意なキー
  () => $fetch(`/api/users/${id}`),
);

const { data: posts } = await useFetch("/api/posts", {
  query: { page: 1 },
  key: "posts-page-1", // リクエストを重複排除
});
```

### サーバールート

```ts
// server/api/users/[id].ts
export default defineEventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, z.object({
    id: z.string().uuid(),
  }).parse);
  // ... 取得して返す
});
```

### ランタイム設定

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  runtimeConfig: {
    // サーバー専用
    apiSecret: "",
    // パブリック（クライアントに公開）
    public: {
      apiBase: "https://api.example.com",
    },
  },
});
```

---

## 10. Vue 3.5+ の新 API

### リアクティブな Props の分割代入

Vue 3.5 でリアクティブな props の分割代入が安定版になりました。`defineProps()` から分割代入した変数は自動的にリアクティブになります。

```ts
// Vue 3.5+: 分割代入した props はリアクティブ（toRefs 不要）
const { count = 0, msg = "hello" } = defineProps<{
  count?: number;
  msg?: string;
}>();

// 制限: 分割代入した prop を直接 watch することはできない
watch(() => count, (newVal) => { ... }); // PASS getter が必要
```

### `useTemplateRef()`

テンプレート参照には、名前が一致するプレーンな ref の代わりに `useTemplateRef()` を使います。

```ts
import { useTemplateRef } from "vue";
const inputEl = useTemplateRef<HTMLInputElement>("input");
// "input" はテンプレート内の ref="input" 属性に対応し、変数名ではない
```

動的な ref ID にも対応しています: `useTemplateRef(dynamicRefId)`。

### `onWatcherCleanup()`

グローバルにインポートできるウォッチャーのクリーンアップ API です（Vue 3.5+）。ウォッチャーのコールバック内で同期的に呼び出す必要があります。

```ts
import { watch, onWatcherCleanup } from "vue";

watch(userId, async (newId) => {
  const controller = new AbortController();
  onWatcherCleanup(() => controller.abort());
  // ... signal 付きで取得
});
```

### `useId()`

フォーム要素やアクセシビリティ向けに、SSR で安定した一意の ID を生成します。

```ts
import { useId } from "vue";
const id = useId();
```

### `defer` Teleport

`<Teleport defer>` を使うと、同じレンダリングサイクルでレンダリングされるターゲットにテレポートできます。

```vue
<Teleport defer to="#container">Content</Teleport>
<div id="container"></div>
```

### 遅延ハイドレーション（SSR）

`defineAsyncComponent()` が `hydrate` 戦略に対応しました。

```ts
import { defineAsyncComponent, hydrateOnVisible } from "vue";
const AsyncComp = defineAsyncComponent({
  loader: () => import("./Comp.vue"),
  hydrate: hydrateOnVisible(),
});
```

---

## アンチパターン

| アンチパターン | なぜ問題か | 修正方法 |
|-------------|---------------|---------|
| `defineProps()` の分割代入（Vue < 3.5） | スナップショットを取り込み、リアクティビティを失う | `props.xxx` 経由でアクセスするか、`toRefs()` を使う |
| 分割代入した props への `watch()`（Vue 3.5+） | コンパイル時エラーになる。分割代入した props は直接ウォッチできない | ゲッターでラップする: `watch(() => count, ...)` |
| 同一要素への `v-if` + `v-for` | 実行順序が曖昧 | フィルタ済みの computed 配列を使う |
| `v-for` の key にインデックスを使用 | 並べ替え時に状態が壊れる | 安定したデータベース ID を使う |
| props の変更 | 単方向データフローに反する | イベントを emit するか `v-model` を使う |
| ユーザーコンテンツでの `v-html` | XSS 脆弱性 | DOMPurify でサニタイズする |
| Vue 3 でのミックスイン | 不透明で衝突しやすい | コンポーザブルに置き換える |
| コンポーザブルでのモジュールスコープの副作用 | インスタンス間で共有されてしまう | `onMounted` + `onUnmounted` でスコープを限定する |
| 置き換え可能な状態への `reactive()` | 置き換えるとリアクティビティが壊れる | 代わりに `ref()` を使う |
| クリーンアップのないウォッチャー | メモリリーク、競合状態 | `onCleanup` または `onWatcherCleanup()`（Vue 3.5+）を使う |
| 新規の Vue 3 コードでの Options API | エコシステムは Composition API へ移行している | `<script setup>` を使う |
| テンプレート参照にプレーンな ref を使用 | 動的な ref に非対応で、名前の一致に依存して壊れやすい | `useTemplateRef()`（Vue 3.5+）を使う |

## 関連スキル

- `accessibility` — ARIA、セマンティック HTML、フォーカス管理
- `frontend-patterns` — フレームワーク横断のフロントエンドアーキテクチャ
- `typescript` — Vue プロジェクトに適用する TypeScript のベストプラクティス
- `coding-standards` — 一般的なコード品質基準
