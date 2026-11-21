---
name: react-native-patterns
description: React Native と Expo のアプリパターン — Expo Router ナビゲーション、状態の分離（サーバー/クライアント/ルート/フォーム）、Zod を用いた TanStack Query によるデータ取得、高性能なリスト、NativeWind/StyleSheet によるスタイリング、ネイティブ API、セキュアストレージ。React Native / Expo の画面、コンポーネント、ナビゲーション、データ層を構築・編集するときに使用します。
origin: ECC
---

# React Native / Expo パターン

Expo で本番運用レベルの React Native アプリを構築するための実践的なパターンです。ナビゲーション、状態、データ取得、リスト、スタイリング、ネイティブ API を扱います。`rules/react-native/` ルールセットと組み合わせて使用します。ルールは「何を」強制するかを定め、このスキルは「どのように」行うかを示します。

以下に挙げるライブラリ（NativeWind、Zustand/Jotai、TanStack Query）は、一般的で定評のある選択肢を例示として示したものです。重要なのは特定のパッケージではなくパターンであり、同等のものであればどれでも使用できます。バリデーションには、ECC の既存の `typescript/` ルールとの一貫性を保つため Zod を使用します。

これらのパターンは、New Architecture（最近の Expo SDK ではデフォルトで、SDK 55 以降では必須）上のマネージド Expo ワークフロー（Expo Router、EAS、`expo-*` モジュール）を前提としています。ブラウザの DOM は前提としません。React Native には `<div>` も URL バーもなく、Web のデータ取得のデフォルトもありません。

## 有効化するタイミング

次の場合にこのスキルを使用します。

- React Native / Expo の画面、コンポーネント、ナビゲーションを構築・編集するとき
- Expo Router（ファイルベースの `app/` ディレクトリ）でルーティングを設定するとき
- 状態をどこに置くべきか（サーバーキャッシュ、クライアントストア、ルートパラメータ、フォーム）を判断するとき
- TanStack Query でデータ取得を組み立て、Zod でレスポンスを検証するとき
- 長い、または重いリストを描画するとき
- スタイリング方式（NativeWind または StyleSheet）を選択・適用するとき
- ネイティブのデバイス API（カメラ、位置情報、通知）やセキュアストレージにアクセスするとき
- RN コードをモバイル特有の問題の観点でレビューするとき

ここでは Web/React-DOM のパターンを使用しないでください。状態を URL で持つ方式、`<div>`、ブラウザ向けの SWR のパターンは React Native には当てはまりません。

## コアコンセプト

### プロジェクト構造（Expo Router）

`app/` 配下のファイルベースルーティングです。ルートファイルは薄く保ちます。パラメータを読み取って検証し、`components/` または `features/` にある画面コンポーネントへ処理を委譲します。

```
app/
  _layout.tsx          # ルートスタック
  (tabs)/
    _layout.tsx        # タブナビゲーター
    index.tsx          # ホーム
  user/[id].tsx        # 動的ルート
components/
features/
  user/UserProfile.tsx
```

### ナビゲーション: ルートパラメータを検証する

ディープリンクや動的ルートは、信頼できない文字列を渡してきます。使用前に Zod で検証してください。

```tsx
// app/user/[id].tsx
import { useLocalSearchParams, router } from 'expo-router'
import { z } from 'zod'
import { UserProfile } from '@/features/user/UserProfile'

const Params = z.object({ id: z.string().uuid() })

export default function UserRoute() {
  const parsed = Params.safeParse(useLocalSearchParams())
  if (!parsed.success) {
    router.replace('/not-found')
    return null
  }
  return <UserProfile userId={parsed.data.id} />
}
```

### 状態: 関心事を分離する

サーバーデータをクライアントストアに複製しないでください。それぞれの関心事には専用の置き場所があります。

| 関心事 | 一般的な選択肢 |
|---------|------|
| サーバー状態（リモートデータ） | サーバーキャッシュライブラリ（TanStack Query、SWR） |
| クライアント/UI 状態 | 軽量ストア（Zustand、Jotai）または Context |
| ルート/ナビゲーション状態 | Expo Router のパラメータ |
| フォーム状態 | フォームライブラリ（例: React Hook Form）＋スキーマバリデーション |
| シークレット / トークン | `expo-secure-store` |
| 機密でない永続化 | `AsyncStorage` / MMKV |

状態を本当に共有する必要が生じるまでは、ローカルの `useState` を優先してください。

### データ取得: キャッシュライブラリ + Zod

`useEffect` 内での fetch ではなく、サーバーキャッシュライブラリ（TanStack Query、SWR）を使用します。境界で検証し、スキーマから型を推論します。ローディング、エラー、空の状態を明示的に処理してください。（例では TanStack Query を使用しています。）

```tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { z } from 'zod'

const User = z.object({ id: z.string(), email: z.string().email() })
type User = z.infer<typeof User>

export function useUser(id: string) {
  return useQuery({
    queryKey: ['user', id],
    queryFn: async (): Promise<User> => User.parse(await api.getUser(id)),
  })
}

export function useUpdateEmail(id: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (email: string) => api.updateEmail(id, email),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['user', id] }),
  })
}
```

### リスト: 仮想化する（大きな配列を ScrollView で map しない）

```tsx
import { FlatList } from 'react-native'

<FlatList
  data={items}
  keyExtractor={(item) => item.id}
  renderItem={renderItem}          // メモ化済み
  initialNumToRender={10}
  windowSize={5}
/>
```

大規模なリストや異種混在のリストには `FlashList`（Shopify）を使用します。

### スタイリング: 1 つの方式を選ぶ

`StyleSheet.create()` はフレームワークネイティブの選択肢で、ユーティリティクラス系ライブラリ（例: NativeWind）が一般的な代替手段です。どちらか一方を選び、一貫して使用してください。ホットパス（頻繁に実行されるパス）上で、JSX 内にインラインでスタイルオブジェクトを組み立てないでください。

```tsx
// NativeWind
<View className="p-4 rounded-2xl bg-white">
  <Text className="text-base font-semibold">Hello</Text>
</View>

// StyleSheet
const styles = StyleSheet.create({ card: { padding: 16, borderRadius: 16, backgroundColor: '#fff' } })
<View style={styles.card}>...</View>
```

### ネイティブ API: フックでラップし、副作用をクリーンアップする

Expo SDK の呼び出しとサブスクリプションは、JSX ではなく `use*` フック内に置きます。必ずクリーンアップしてください。

```tsx
import { useEffect, useState } from 'react'
import * as Location from 'expo-location'

type LocationState =
  | { status: 'loading' }
  | { status: 'denied' }
  | { status: 'granted'; coords: Location.LocationObjectCoords }

export function useCurrentLocation() {
  // 座標だけでなくステータスも追跡する。これにより UI は「読み込み中」と
  // 「権限が拒否された」を区別し、対処可能なメッセージを表示できる。
  const [state, setState] = useState<LocationState>({ status: 'loading' })

  useEffect(() => {
    let active = true
    ;(async () => {
      const { status } = await Location.requestForegroundPermissionsAsync()
      if (status !== 'granted') {
        if (active) setState({ status: 'denied' })
        return
      }
      const pos = await Location.getCurrentPositionAsync({})
      if (active) setState({ status: 'granted', coords: pos.coords })
    })()
    return () => { active = false }   // アンマウント後の古い結果を無視する
  }, [])

  return state
}
```

### トークンのセキュアストレージ

```tsx
import * as SecureStore from 'expo-secure-store'

await SecureStore.setItemAsync('auth_token', token)   // Keychain / Keystore
const token = await SecureStore.getItemAsync('auth_token')
```

## コード例

### 完全な画面: ルート → クエリ → リスト → 各状態

```tsx
// app/(tabs)/orders.tsx
import { memo, useCallback } from 'react'
import { FlatList, Text, View } from 'react-native'
import { useQuery } from '@tanstack/react-query'
import { z } from 'zod'

const OrderSchema = z.object({ id: z.string(), total: z.number(), status: z.string() })
const OrdersSchema = z.array(OrderSchema)
type Order = z.infer<typeof OrderSchema>

function useOrders() {
  return useQuery({
    queryKey: ['orders'],
    queryFn: async () => OrdersSchema.parse(await api.listOrders()),
  })
}

// 参照がレンダー間で安定するようメモ化する（リストのガイダンスを参照）。
const OrderRow = memo(function OrderRow({ item }: { item: Order }) {
  return (
    <View className="px-4 py-3 border-b border-neutral-200">
      <Text className="font-medium">#{item.id}</Text>
      <Text className="text-neutral-500">{item.status} · ${item.total}</Text>
    </View>
  )
})

export default function OrdersScreen() {
  const { data, isLoading, isError, refetch, isRefetching } = useOrders()
  const renderItem = useCallback(({ item }: { item: Order }) => <OrderRow item={item} />, [])

  if (isLoading) return <Centered><Text>Loading…</Text></Centered>
  if (isError) return <Centered><Text accessibilityRole="alert">Could not load orders.</Text></Centered>
  if (!data?.length) return <Centered><Text>No orders yet.</Text></Centered>

  return (
    <FlatList
      data={data}
      keyExtractor={(o) => o.id}
      onRefresh={refetch}
      refreshing={isRefetching}
      renderItem={renderItem}
    />
  )
}
```

### フォーム: React Hook Form + Zod リゾルバー

```tsx
import { useForm, Controller } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { TextInput, Button, Text } from 'react-native'

const Schema = z.object({ email: z.string().email('Invalid email') })
type FormValues = z.infer<typeof Schema>

export function EmailForm({ onSubmit }: { onSubmit: (v: FormValues) => void }) {
  const { control, handleSubmit, formState: { errors } } = useForm<FormValues>({
    resolver: zodResolver(Schema),
    defaultValues: { email: '' },
  })

  return (
    <>
      <Controller
        control={control}
        name="email"
        render={({ field: { value, onChange, onBlur } }) => (
          <TextInput
            value={value}
            onChangeText={onChange}
            onBlur={onBlur}
            autoCapitalize="none"
            keyboardType="email-address"
            accessibilityLabel="Email address"
          />
        )}
      />
      {errors.email && <Text accessibilityRole="alert">{errors.email.message}</Text>}
      <Button title="Save" onPress={handleSubmit(onSubmit)} />
    </>
  )
}
```

## アンチパターン

```tsx
// 悪い例: 大きな配列を ScrollView 内で map している（仮想化されず、カクつき、メモリ消費大）
<ScrollView>{items.map((i) => <Row key={i.id} item={i} />)}</ScrollView>
// 良い例: FlatList / FlashList

// 悪い例: サーバーデータをクライアントストアにコピーしている（信頼できる情報源が 2 つになり、古いデータが残る）
const useStore = create((set) => ({ users: [], setUsers: (u) => set({ users: u }) }))
useEffect(() => { getUsers().then(setUsers) }, [])
// 良い例: サーバー状態は useQuery が保持し、必要なものは導出する

// 悪い例: トークンを AsyncStorage に保存している（暗号化されない）
await AsyncStorage.setItem('auth_token', token)
// 良い例: expo-secure-store

// 悪い例: ディープリンクのパラメータを信頼している
const { id } = useLocalSearchParams(); fetchUser(id)
// 良い例: 使用前に Zod で検証する

// 悪い例: ホットパスで毎レンダーごとにインラインのスタイルオブジェクトが再生成される
<View style={{ padding: 16, backgroundColor: '#fff' }} />
// 良い例: モジュールスコープの StyleSheet.create、または NativeWind の className

// 悪い例: 本物のシークレットがバンドルに含まれている
const STRIPE_SECRET = 'sk_live_...'
// 良い例: 特権的な呼び出しはサーバー側で行い、アプリに含めるのは、バックエンドのルールで保護された公開キーのみにする
```

## ベストプラクティス

- ルートファイルは薄く保ち、ロジックは画面コンポーネントと `use*` フックに置く。
- すべての外部入力（API レスポンス、ルートパラメータ、プッシュペイロード）を Zod で検証する。
- サーバー状態は TanStack Query に任せ、クライアントストアは小さく保つ。
- ローディング、エラー、空の状態を必ず描画する。フォールバックのないスピナーだけにしない。
- リストを仮想化し、`renderItem` をメモ化し、安定した `keyExtractor` を提供する。
- アニメーションには `react-native-reanimated`（UI スレッド）を使用し、JS スレッドでの重い処理を避ける。
- トークンは `expo-secure-store` に保存し、認可をクライアントに委ねない。
- セーフエリア、Dynamic Type、アクセシビリティのロール/ラベルを最初から考慮する。
- リリース前に、すべてのネイティブ依存関係が New Architecture に対応していることを確認する。

## 関連スキル

- `frontend-patterns` — React/Next.js（Web）のパターン。React の共通概念には有用ですが、DOM 固有です。
- `coding-standards` — RN コードにも適用される TypeScript/JavaScript のイディオム。
- `tdd-workflow`, `e2e-testing` — テストプロセス（RN では Jest + React Native Testing Library、Maestro/Detox を使用）。
- `security-review` — 上記の RN バンドル/シークレットに関するガイダンスを補完する、一般的なセキュリティチェックリスト。
