---
name: prisma-patterns
description: TypeScript バックエンド向けの Prisma ORM パターン。スキーマ設計、クエリ最適化、トランザクション、ページネーション、そして updateMany がレコードではなく件数を返すこと、$transaction のタイムアウト、migrate dev による DB リセット、一括書き込みで @updatedAt が適用されないこと、サーバーレスでの接続枯渇といった重大な落とし穴を扱います。Prisma のスキーマやクエリを書くとき、またはトランザクション、マイグレーション、サーバーレスの接続数制限をデバッグするときに使用します。
metadata:
  origin: ECC
---

# Prisma パターン

TypeScript バックエンドにおける Prisma ORM の本番運用パターンと、気づきにくい落とし穴をまとめます。

> **パターンを適用する前にバージョンを確認してください。** Prisma の API は複数のメジャーリリースを通じて変化してきました。
>
> ```bash
> npx prisma --version
> ```
>
> バージョン間の主な API の違い:
> - `relationJoins` は、リレーションを個別のクエリではなく JOIN で読み込めますが、大きな 1:N リレーションや深い `include` では行数が爆発する可能性があります。両方のアプローチをベンチマークしてください
> - `omit` フィールド修飾子と `prisma.$extends` Client Extensions API が追加されました
> - **新しいインストール**: パッケージ名が `@prisma/client` ではなく `prisma` になっている場合があります。`PrismaClient` にドライバーアダプター（例: `@prisma/adapter-pg`）が必要な場合があります。`datasource.url` が `schema.prisma` ではなく `prisma.config.ts` にある場合があります
> - CLI コマンド（`migrate dev`、`migrate deploy`、`generate`）はバージョン間で変わりません

## 有効化するタイミング

- Prisma スキーマのモデルやリレーションを設計・変更するとき
- クエリ、トランザクション、ページネーションのロジックを書くとき
- `updateMany`、`deleteMany`、その他の一括操作を使うとき
- データベースマイグレーションを実行または計画するとき
- サーバーレス環境（Vercel、Lambda、Cloudflare Workers）にデプロイするとき
- 論理削除やマルチテナントの行フィルタリングを実装するとき

## コアコンセプト

### ID 戦略

| 戦略 | 使用する場面 | 避ける場面 |
|---|---|---|
| `@default(cuid())` | デフォルトの選択肢。URL セーフで、ソート可能で、衝突しない | 外部システムが連番 ID を必要とする場合 |
| `@default(uuid())` | Prisma 以外のシステムとの相互運用が必要な場合 | 書き込みの多いテーブル（ランダムな UUID は B-tree インデックスを断片化させる） |
| `@default(autoincrement())` | 内部の結合テーブル、監査ログ | 公開 ID（レコード数が露出する） |

### スキーマのデフォルト

```prisma
model User {
  id        String    @id @default(cuid())
  email     String    @unique  // @unique はすでにインデックスを作成する — @@index は不要
  name      String
  role      Role      @default(USER)
  posts     Post[]
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?

  @@index([createdAt])
  @@index([deletedAt, createdAt]) // 論理削除 + ソートのクエリ用の複合インデックス
}
```

- すべての外部キーと、`WHERE` や `ORDER BY` で使う列に `@@index` を追加します。
- 論理削除が将来必要になりそうな場合は、最初から `deletedAt DateTime?` を宣言してください。後から追加すると、稼働中のテーブルに対するマイグレーションが必要になります。
- `updatedAt @updatedAt` は、Prisma が `update` と `upsert` の場合にのみ自動で設定します（一括更新の落とし穴についてはアンチパターンを参照）。

### `include` と `select`

| | `include` | `select` |
|---|---|---|
| 返す内容 | すべてのスカラーフィールド + 指定したリレーション | 指定したフィールドのみ |
| 使用する場面 | ほとんどのフィールドに加えてリレーションが必要な場合 | ホットパス、大きなテーブル、過剰取得を避けたい場合 |
| パフォーマンス | 列の多いテーブルでは過剰取得になる可能性がある | ペイロードが最小で、大規模データセットでより高速 |
| Prisma 5 の注記 | デフォルトで JOIN を使用（`relationJoins`） | 同様 |

```ts
// include — すべての列 + リレーション
const user = await prisma.user.findUnique({
  where: { id },
  include: { posts: { select: { id: true, title: true } } },
});

// select — 明示的な許可リスト
const user = await prisma.user.findUnique({
  where: { id },
  select: { id: true, email: true, name: true },
});
```

API レスポンスから Prisma の生のエンティティを返してはいけません。公開するフィールドを制御するために、レスポンス DTO へマッピングしてください。

```ts
// BAD: passwordHash、deletedAt、内部フィールドが漏洩する
return await prisma.user.findUniqueOrThrow({ where: { id } });

// GOOD: 明示的な DTO マッピング
const user = await prisma.user.findUniqueOrThrow({ where: { id } });
return { id: user.id, name: user.name, email: user.email };
```

### トランザクション形式の選択

| 状況 | 使用するもの |
|---|---|
| 独立した操作で、相互依存がない | 配列形式 |
| 後続のステップが先行する結果に依存する | インタラクティブ形式 |
| 外部呼び出し（メール、HTTP）を伴う | トランザクションには含めない |

```ts
// 配列形式 — 1 回のラウンドトリップでバッチ処理される
const [user, post] = await prisma.$transaction([
  prisma.user.update({ where: { id }, data: { name } }),
  prisma.post.create({ data: { title, authorId: id } }),
]);

// インタラクティブ形式 — tx クライアントのみを使い、外側の prisma クライアントは決して使わない
const post = await prisma.$transaction(async (tx) => {
  const user = await tx.user.findUniqueOrThrow({ where: { id } });
  if (user.role !== 'ADMIN') throw new Error('Forbidden');
  return tx.post.create({ data: { title, authorId: user.id } });
});
```

### PrismaClient シングルトン

各 `PrismaClient` インスタンスは独自のコネクションプールを開きます。インスタンス化は 1 回だけにしてください。

```ts
// lib/prisma.ts

// オプション A — アダプターベースの初期化（新しいバージョンの Prisma で必須）
import { PrismaClient } from '@prisma/client'; // または、使用している環境に応じた生成済みクライアントのパス
import { PrismaPg } from '@prisma/adapter-pg';

function createPrismaClient() {
  const adapter = new PrismaPg({
    connectionString: process.env.DATABASE_URL!,
  });
  return new PrismaClient({
    adapter,
    log: process.env.NODE_ENV === 'development' ? ['query', 'error'] : ['error'],
  });
}

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const prisma = globalForPrisma.prisma ?? createPrismaClient();

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;

// オプション B — 直接初期化（古いバージョン向け、アダプター不要）
// import { PrismaClient } from '@prisma/client';
// export const prisma = globalForPrisma.prisma ?? new PrismaClient({ ... });
```

使用している Prisma のバージョンで `PrismaClient` コンストラクタに `adapter` 引数が必要な場合は、オプション A を使用します。
`new PrismaClient()` が引数なしで動作する場合は、オプション B を使用します。どちらが正しいかはコンパイラが教えてくれます。

`globalThis` パターンは、ホットリロード（Next.js、nodemon、ts-node-dev）中にインスタンスが重複して作成されるのを防ぎます。

### N+1 問題

ループ内でリレーションを読み込むと、行ごとに 1 回ずつクエリが発行されます。

```ts
// BAD: N+1 — ユーザーごとに追加のクエリが 1 回発行される
const users = await prisma.user.findMany();
for (const user of users) {
  const posts = await prisma.post.findMany({ where: { authorId: user.id } });
}

// GOOD: 単一のクエリ
const users = await prisma.user.findMany({ include: { posts: true } });
```

Prisma 5 以降の `relationJoins` では、`include` 形式は単一の JOIN を使用します。大きな 1:N の集合では結果セットのサイズが増える可能性があるため、親 1 件あたり多数の行を返しうるリレーションの場合は、両方のアプローチをベンチマークしてください。

## コード例

### カーソルページネーション（フィードや大規模データセットに推奨）

```ts
async function getPosts(cursor?: string, limit = 20) {
  const items = await prisma.post.findMany({
    where: { published: true },
    orderBy: [
      { createdAt: 'desc' },
      { id: 'desc' }, // セカンダリソートにより、タイムスタンプが重複した場合の不安定なページネーションを防ぐ
    ],
    take: limit + 1,
    ...(cursor && { cursor: { id: cursor }, skip: 1 }),
  });

  const hasNextPage = items.length > limit;
  if (hasNextPage) items.pop();

  return { items, nextCursor: hasNextPage ? items[items.length - 1].id : null };
}
```

`limit + 1` 件を取得して最後の 1 件を取り除くのが、追加の count クエリなしで `hasNextPage` を検出する定石です。複数の行が同じタイムスタンプを持つ場合に不安定なページネーションになるのを防ぐため、必ず一意なフィールド（例: `id`）をセカンダリの `orderBy` に含めてください。オフセットページネーションは、ユーザーが任意のページへジャンプする必要がある場合（管理画面のテーブルなど）にのみ使用します。

### 論理削除

```ts
// 常に明示的にフィルタする — ミドルウェアには頼らない（挙動が隠れ、デバッグが難しい）
const activeUsers = await prisma.user.findMany({ where: { deletedAt: null } });

await prisma.user.update({ where: { id }, data: { deletedAt: new Date() } });
await prisma.user.update({ where: { id }, data: { deletedAt: null } }); // 復元
```

### エラーハンドリング

```ts
import { Prisma } from '@prisma/client'; // または、使用している環境に応じた生成済みクライアントのパス

try {
  await prisma.user.create({ data: { email } });
} catch (e) {
  if (e instanceof Prisma.PrismaClientKnownRequestError) {
    if (e.code === 'P2002') throw new ConflictError('Email already exists');
    if (e.code === 'P2025') throw new NotFoundError('Record not found');
    if (e.code === 'P2003') throw new BadRequestError('Referenced record does not exist');
  }
  throw e;
}
```

主なコード: `P2002` 一意制約違反 · `P2025` 見つからない · `P2003` 外部キー制約違反。

サービス境界でキャッチし、ドメインエラーに変換してください。Prisma の生のメッセージを API の利用者に公開してはいけません。

### コネクションプール — サーバーレス

接続パラメータは `DATABASE_URL` に直接埋め込んでください。URL にすでにクエリパラメータ（例: `?schema=public`）がある場合、文字列連結では壊れてしまいます。

```bash
# .env — 推奨: パラメータを URL に埋め込む
DATABASE_URL="postgresql://user:pass@host/db?connection_limit=1&pool_timeout=20"

# 外部プーラー（PgBouncer、Supabase pooler）を使う場合
DATABASE_URL="postgresql://user:pass@host/db?pgbouncer=true&connection_limit=1"
```

```ts
// Vercel、AWS Lambda、および同様のサーバーレスランタイム:
// インスタンスごとにプールを 1 に制限する。connection_limit と pool_timeout は DATABASE_URL で制御する

// アダプターベースのセットアップ（使用している Prisma のバージョンがアダプターを必要とする場合）:
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

// 直接セットアップ（使用している Prisma のバージョンがアダプターを必要としない場合）:
// const prisma = new PrismaClient();
```

## アンチパターン

### `updateMany` はレコードではなく件数を返す

```ts
// BAD: 結果は { count: 2 } — users[0] は undefined
const users = await prisma.user.updateMany({ where: { role: 'GUEST' }, data: { role: 'USER' } });

// GOOD: 先に ID を取得し、更新してから、影響を受けた行だけを取得する
const targets = await prisma.user.findMany({
  where: { role: 'GUEST' },
  select: { id: true },
});
const ids = targets.map((u) => u.id);
await prisma.user.updateMany({ where: { id: { in: ids } }, data: { role: 'USER' } });
const updated = await prisma.user.findMany({ where: { id: { in: ids } } });
```

`deleteMany` も同様で、`{ count: n }` を返し、削除した行は返しません。

### `$transaction` のインタラクティブ形式は 5 秒でタイムアウトする

```ts
// BAD: トランザクション内の外部呼び出しがデフォルトの 5 秒を超える → "Transaction already closed"
await prisma.$transaction(async (tx) => {
  const user = await tx.user.findUniqueOrThrow({ where: { id } });
  await sendWelcomeEmail(user.email); // 外部呼び出し
  await tx.user.update({ where: { id }, data: { emailSent: true } });
});

// GOOD: 外部呼び出しはトランザクションの外に出す
const user = await prisma.user.findUniqueOrThrow({ where: { id } });
await sendWelcomeEmail(user.email);
await prisma.user.update({ where: { id }, data: { emailSent: true } });

// タイムアウトを延ばすのは、一括処理が本当に必要とする場合のみ
await prisma.$transaction(async (tx) => { ... }, { timeout: 30_000 });
```

### `migrate dev` はデータベースをリセットすることがある

`migrate dev` はスキーマのドリフトを検出し、DB のリセットを促すことがあり、その場合すべてのデータが削除されます。

```bash
# 共有の開発環境、ステージング、本番では絶対に実行しない
npx prisma migrate dev --name add_column

# ローカルの個人開発以外ではどこでも安全
npx prisma migrate deploy

# 適用せずにドリフトを確認する
npx prisma migrate diff \
  --from-migrations ./prisma/migrations \
  --to-schema-datamodel ./prisma/schema.prisma \
  --shadow-database-url "$SHADOW_DATABASE_URL"
```

### マイグレーションファイルの手動編集は今後のデプロイを壊す

Prisma はすべてのマイグレーションファイルのチェックサムを記録しています。適用後に編集すると、元のファイルがすでに実行された全環境で `P3006 checksum mismatch` が発生します。代わりに新しいマイグレーションを作成してください。

### 破壊的なスキーマ変更には複数ステップのマイグレーションが必要

既存の列に `NOT NULL` を追加したり、列名を変更したりする操作を 1 回のマイグレーションで行うと、テーブルがロックされるかデータが失われます。expand-and-contract（拡張と縮小）を使用してください。

```bash
# ステップ 1: ローカルでマイグレーションを作成し、その後デプロイする
npx prisma migrate dev --name add_new_column   # ローカルのみ
npx prisma migrate deploy                       # ステージング / 本番
```

```ts
// ステップ 2: データをバックフィルする（シェルではなく、スクリプトまたはマイグレーションジョブで実行する）
await prisma.user.updateMany({ data: { newColumn: derivedValue } });
```

```bash
# ステップ 3: NOT NULL 制約のマイグレーションをローカルで作成し、その後デプロイする
npx prisma migrate dev --name make_new_column_required  # ローカルのみ
npx prisma migrate deploy                               # ステージング / 本番
```

### `@updatedAt` は `updateMany` では動作しない

`@updatedAt` が自動で設定されるのは `update` と `upsert` のみです。一括書き込みでは更新されないままになります。

```ts
// BAD: updatedAt は古い値のまま
await prisma.post.updateMany({ where: { authorId }, data: { published: true } });

// GOOD
await prisma.post.updateMany({
  where: { authorId },
  data: { published: true, updatedAt: new Date() },
});
```

### 論理削除と `findUniqueOrThrow` の組み合わせでは削除済みレコードが返される

`findUniqueOrThrow` が `P2025` をスローするのは、行が DB に存在しない場合のみです。論理削除された行は DB に残っているため、エラーなしで返されます。

`findUniqueOrThrow` は `where` に一意制約のフィールドを必要とします。`id` と一緒に `deletedAt: null` を追加すると、`{ id, deletedAt }` は複合一意制約ではないため型エラーになります。代わりに `findFirstOrThrow` を使用してください。

```ts
// BAD: 論理削除済みのユーザーを返す
const user = await prisma.user.findUniqueOrThrow({ where: { id } });

// BAD: Prisma の型エラー — { id, deletedAt } は一意制約ではない
const user = await prisma.user.findUniqueOrThrow({ where: { id, deletedAt: null } });

// GOOD: findFirstOrThrow は任意の where 条件をサポートする
const user = await prisma.user.findFirstOrThrow({ where: { id, deletedAt: null } });
```

### `where` なしの `deleteMany` はすべての行を削除する

```ts
// BAD: 何の警告もなくテーブルを空にする
await prisma.post.deleteMany();

// GOOD
await prisma.post.deleteMany({ where: { authorId: userId } });
```

## ベストプラクティス

| ルール | 理由 |
|---|---|
| CI/CD では `migrate deploy`、`migrate dev` はローカルのみ | `migrate dev` はドリフト時に DB をリセットすることがある |
| エンティティをレスポンス DTO にマッピングする | 内部フィールドの漏洩を防ぐ |
| `PrismaClientKnownRequestError` をサービス境界でキャッチする | ドメインエラーに変換する |
| 手動の null チェックより `*OrThrow` メソッドを優先する | P2025 を自動でスローする。一意でないフィールドでフィルタする場合は `findFirstOrThrow` を使う |
| サーバーレスでは `connection_limit=1` + 外部プーラー | 接続の枯渇を防ぐ |
| `deleteMany` には必ず `where` を指定する | 誤ってテーブルを空にするのを防ぐ |
| `updateMany` では `updatedAt: new Date()` を手動で設定する | `@updatedAt` は一括書き込みをスキップする |

## 関連スキル

- `nestjs-patterns` — Prisma を統合する NestJS のサービス層
- `postgres-patterns` — PostgreSQL レベルのインデックス設計と接続チューニング
- `database-migrations` — 本番向けの複数ステップのマイグレーション計画
- `backend-patterns` — 汎用的な API とサービス層の設計
