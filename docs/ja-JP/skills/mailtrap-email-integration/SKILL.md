---
name: mailtrap-email-integration
description: MailtrapのEmail APIを使ったトランザクションメール送信の統合をエージェントに案内します。サンドボックステスト、ドメイン検証、API認証を含みます。メール送信機能の実装、配信問題のデバッグ、安全な開発/ステージング向けメールテストのセットアップ時に使用します。
origin: ECC
---

# Mailtrap Email Integration

MailtrapのEmail APIとSandboxを使って、アプリケーションにトランザクションメール送信を追加するためのパターンです。認証、環境の分離、よくある配信上の落とし穴を扱います。

## 有効化するタイミング

- 「メール送信」機能（サインアップ確認、パスワードリセット、通知、領収書）を実装するとき
- 開発/ステージング環境でメールが届かない原因をデバッグするとき
- プロジェクトで最初のメール送信連携をセットアップするとき
- サンドボックスを分離せずにメールAPIを直接呼び出しているコードをレビューするとき

## 基本概念

**SandboxとProductionの分離。** Mailtrapはメールを配信せずに捕捉するSandbox APIを提供しており、開発/ステージングで使用し、テストメールが実際の受信箱に届かないようにします。本番送信には、検証済みドメインを使う別のエンドポイントを利用します。開発環境を本番の送信エンドポイントに向けてはいけません。

**認証。** リクエストは `Authorization` ヘッダーにBearerトークンを指定します。トークンはプロジェクト単位でスコープが決まり、通常、サンドボックスと本番では別のトークンを使います。

**ドメイン検証。** 本番送信では、Mailtrapが実際の受信者へ配信する前に、DNSレコード（SPF、DKIM、DMARC）による送信ドメインの検証が必要です。これを省略すると、配信が黙って失敗したり、迷惑メールフォルダに入ったりします。

## コード例

```typescript
// MailtrapのEmail API経由で送信（本番）
async function sendEmail(to: string, subject: string, html: string) {
  const response = await fetch("https://send.api.mailtrap.io/api/send", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${process.env.MAILTRAP_API_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: { email: "no-reply@yourverifieddomain.com", name: "Your App" },
      to: [{ email: to }],
      subject,
      html,
    }),
  });

  if (!response.ok) {
    throw new Error(`Email send failed: ${response.status}`);
  }
  return response.json();
}
```

```typescript
// 同じ呼び出しを、非本番環境ではSandboxにルーティング
const MAILTRAP_ENDPOINT = process.env.NODE_ENV === "production"
  ? "https://send.api.mailtrap.io/api/send"
  : `https://sandbox.api.mailtrap.io/api/send/${process.env.MAILTRAP_INBOX_ID}`;
```

## アンチパターン

| アンチパターン | 問題となる理由 | 代わりにどうするか |
| --- | --- | --- |
| 開発/テストで本番の送信エンドポイントを使う | テストメールが実際の受信箱に届き、迷惑メール報告やテストデータの漏えいのリスクがある | 非本番環境はSandboxエンドポイントにルーティングする |
| APIトークンをソースにハードコードする | バージョン管理にコミットされると認証情報が漏えいするリスクがある | トークンは環境変数/シークレットマネージャーから読み込む |
| ドメイン検証の完了前に送信する | メールが黙って失敗するか、迷惑メールに分類される | 本番送信を有効にする前にSPF/DKIM/DMARCレコードを検証する |
| 送信失敗時のリトライ/エラー処理がない | 通知が黙って失敗する（例: ユーザーにパスワードリセットメールが届かない） | レスポンスステータスを確認し、失敗をログに記録し、対処につながるエラーとして表面化させる |

## ベストプラクティス

- サンドボックスと本番のトークンは別々の環境変数に保持し、1つのトークンを複数の環境で共有しない
- メールを伴う本番ローンチの前に、送信ドメインのDNSレコードを検証する
- 配信失敗は、デバッグに十分なコンテキスト（受信者、テンプレート、タイムスタンプ、レスポンスコード）とともにログに記録する
- メール送信は失敗しうるネットワーク呼び出しとして扱い、try/catchで囲み、成功を前提にしない

## 関連スキル

`api-and-interface-design`, `security-and-hardening`, `ci-cd-and-automation`
