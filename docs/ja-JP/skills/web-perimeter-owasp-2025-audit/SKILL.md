---
name: web-perimeter-owasp-2025-audit
description: OWASP Top 10:2025 の攻撃面リードに対応づけた、受動的かつ非破壊的なWebペリメータセキュリティ監査。CDNのUnkeyed Header（X-Forwarded-Host）によるWebキャッシュポイズニング、サプライチェーンのマニフェスト露出、gitオブジェクトのダンプ防止（/.git/HEAD）、暗号関連ヘッダー、AIクローラーの境界ガバナンス（llms.txt、robots.txt）を対象とします。本番ドメインの監査、Cloudflare/Vercel/Nginxのエッジセキュリティ設定、ローンチ前のペリメータチェックの準備時に使用します。
metadata:
  origin: ECC
---

# Webペリメータセキュリティ監査（OWASP Top 10:2025 攻撃面リード）

Webアプリケーション、API、CDNエッジに対して、非破壊的かつ決定的なペリメータセキュリティ監査を実施します。観測可能なエッジ上の発見事項を、**ペリメータリード**として関連する **OWASP Top 10:2025** カテゴリに対応づけ、本番環境へ出荷する前に再現可能なチェックで修正を検証します。

## スコープと未検証のアプリケーション層の領域

外部から取得するHTTPレスポンスヘッダー、CDNキャッシュの挙動、クローラーポリシー、開示ファイルは、**公開されて観測可能なエッジペリメータ**しか検査しません。このチェックリストに合格しても、OWASP Top 10:2025 への完全な準拠が確立されるわけでは**ありません**。別途のコードレビューと認証付きテストの裏付けがない限り、以下のアプリケーション層の領域は**ペリメータ調査では未検証**として必ず報告してください。

- **認可とオブジェクトレベルのアクセス制御（A01:2025）:** BOLA/IDOR、テナント分離、権限昇格の検証には、認証付きのマルチロール統合テストが必要です（[OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)）。
- **認証とセッションのライフサイクル（A07:2025）:** MFAの強制、クレデンシャルスタッフィング対策、トークンのローテーション、サーバー側のセッション失効は、`Set-Cookie` のフラグだけでは証明できません（[OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)）。
- **インジェクションとビジネスロジック処理（A05 / A06:2025）:** SQL/NoSQL/コマンドインジェクション、SSRF、競合状態の検証には、ソース解析（SAST）と対象を絞ったDASTが必要です（[OWASP Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html)）。
- **内部のセキュリティログとアラート（A09:2025）:** 監査証跡の完全性、改ざん耐性、SIEMアラートは、テレメトリパイプラインの内部で検証する必要があります（[OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html)）。

## 重要な安全上の取り決め

- 破壊的なペイロード、ブルートフォーストラフィック、共有された本番キャッシュキーに対する分離されていないキャッシュポイズニングのプローブは、決して送信しないでください。
- ライブターゲットに対して `X-Forwarded-Host` または `X-Forwarded-Scheme` のプローブを送信する前に、まず新規に生成して検証済みの16進数キャッシュバスターを使い、クエリキーの分離を証明してください（`set -euo pipefail`、`CB_A=$(openssl rand -hex 8)`、`CB_B=$(openssl rand -hex 8)`）。
  1. `CB_A` または `CB_B` が空、同一、あるいは `^[0-9a-f]{16}$` に一致しない場合は、リクエストを送信する前にフェイルクローズします。
  2. `?__cb=${CB_A}` を付けたクリーンなリクエストを送信し（`--connect-timeout 3 --max-time 5`）、同一の `?__cb=${CB_A}` リクエストを最大2回まで繰り返して（合計最大3リクエスト、各 `--max-time 5`）キャッシュ `HIT` を確認し、その後 `?__cb=${CB_B}` を付けたクリーンなリクエストを1回送信して（`--max-time 5`）キャッシュ `MISS` になることを確認します。
  3. この限られた試行回数のうちに `HIT` の後に `MISS` が確認できない場合は、ライブプローブを中止し、分離されたステージング環境でのみ実行してください。
- 取得したすべてのヘッダーとボディには、`trap` によるクリーンアップ付きのプライベートな `mktemp -d` 作業ディレクトリを使用してください。予測可能な共有 `/tmp` のファイル名には決して書き込まないでください。
- フレームワークのデフォルトに頼らず、実際のHTTPレスポンスを検証してください。リバースプロキシやCDNは、アップストリームのヘッダーを削除または上書きすることがよくあります。
- ディレクトリルート（`/.git/` など）での `403 Forbidden` は、直接のオブジェクトパス（`/.git/HEAD`、`/.git/config`）も `404`/`403` を返さない限り、不十分として扱ってください。
- すべてのチェックはデフォルトでローカルに留めてください（`curl` / 標準のシステムツール）。外部CLIやリモートのスコアカードAPIは、ユーザーが明示的にオプトインし、ターゲットのホスト名の共有を承認した場合にのみ呼び出してください。

## 有効化するタイミング

- ローンチ前にライブドメインまたはステージング環境を監査するとき
- Cloudflare、Vercel、AWS CloudFront、Nginx、Next.jsミドルウェアのセキュリティ設定をレビューするとき
- CDNのWebキャッシュポイズニング（`X-Forwarded-Host`、`X-Forwarded-Scheme`）やCORSのオリジン反射を調査するとき
- サプライチェーンのアーティファクト（`package-lock.json`、`/.npmrc`、`/.yarnrc.yml`、ソースマップ）とAIクローラーの境界（`llms.txt`、`robots.txt`、`security.txt`）を強化するとき

## ペリメータ監査ワークフロー

### 1. 露出したアーティファクト、CORS、キャッシュ分離のリード（A01 / A02:2025 に関連）

1. **gitオブジェクトと設定アーティファクトの直接露出（`git-dumper` ベクトル）:**
   - `/.git/` のディレクトリインデックスを無効化しても（`403 Forbidden`）、直接のオブジェクトパスが読み取り可能なままであれば、リポジトリの再構築を防げ**ません**。
   - 機密性の高い内容を出力せずに、ファイル固有の限定的なシグネチャで各パスをプローブします（`--connect-timeout 3 --max-time 5`）。
     - `/.git/HEAD`: ステータスが `200` で、1行目が `^ref: refs/` または40文字の16進SHA（`^[0-9a-f]{40}$`）に一致するかを確認します。
     - `/.git/config`: ステータスが `200` で、ボディに `[core]` または `[remote "` セクションヘッダーが含まれるかを確認します。
     - `/docker-compose.yml`: ステータスが `200` で、ボディにトップレベルの `services:` ブロックが含まれるかを確認します。
     - 環境設定のパス（`/<dotenv-artifact>` など）: ステータスが `200` で、各行が `^[A-Z][A-Z0-9_]+=` に一致し、かつ `<!DOCTYPE` や `<html` を含まないかを確認し、真偽値の検出シグナルのみを報告して、シークレットの値は決してエコーしません。
2. **CORSの任意オリジン反射:**
   - `--connect-timeout 3 --max-time 5` を付けて `Origin: https://evil-probe.invalid` を送信します。
   - レスポンスが `Access-Control-Allow-Origin: https://evil-probe.invalid` を `Access-Control-Allow-Credentials: true` とともに反射する場合は、**高（HIGH）優先度のペリメータリード**として記録します。**CRITICAL** にエスカレートする前に、そのエンドポイントがブラウザコンテキストで認証済みまたは非公開のユーザーデータを提供しているかを確認してください（Cookieに関係なく同一の未認証コンテンツを返す公開エンドポイントは、重大度の低い設定ミスです）。
3. **Unkeyed HeaderによるWebキャッシュポイズニング（限定的なプローブとローカルステージングフィクスチャ）:**
   - クエリキーの分離を証明した後（`?__cb=${CB_A}` が3回以内の限定リクエストで `HIT` に達し、`?__cb=${CB_B}` が `MISS` を返す）、または分離されたステージングホスト上でのみ、プライベートな一時ディレクトリ内で限定的なプローブを実行します。
     ```bash
     set -euo pipefail
     CB_A="$(openssl rand -hex 8)"
     CB_B="$(openssl rand -hex 8)"
     if [[ ! "${CB_A}" =~ ^[0-9a-f]{16}$ ]] || [[ ! "${CB_B}" =~ ^[0-9a-f]{16}$ ]] || [[ "${CB_A}" == "${CB_B}" ]]; then
       echo "Fail closed: invalid cache-buster entropy" >&2
       exit 1
     fi

     WORK_DIR="$(mktemp -d)"
     trap 'rm -rf "${WORK_DIR}"' EXIT

     TARGET_BASE="https://example.com/"
     # Step 1: Prove query-key isolation (max 3 attempts for HIT on CB_A, then MISS on CB_B)
     CACHE_HIT=0
     for attempt in 1 2 3; do
       curl -sS --connect-timeout 3 --max-time 5 -D "${WORK_DIR}/iso_a_headers.txt" -o /dev/null "${TARGET_BASE}?__cb=${CB_A}"
       if grep -Eiq '^(cf-cache-status:\s*HIT|x-cache:\s*Hit|age:\s*[1-9])' "${WORK_DIR}/iso_a_headers.txt"; then
         CACHE_HIT=1
         break
       fi
     done
     curl -sS --connect-timeout 3 --max-time 5 -D "${WORK_DIR}/iso_b_headers.txt" -o /dev/null "${TARGET_BASE}?__cb=${CB_B}"
     if [[ "${CACHE_HIT}" -ne 1 ]] || ! grep -Eiq '^(cf-cache-status:[[:space:]]*MISS([[:space:]]|$)|x-cache:[[:space:]]*Miss([[:space:]]|$))' "${WORK_DIR}/iso_b_headers.txt" || grep -Eiq '^(cf-cache-status:[[:space:]]*HIT|x-cache:[[:space:]]*Hit|age:[[:space:]]*[1-9])' "${WORK_DIR}/iso_b_headers.txt"; then
       echo "Aborting live probe: query-key cache isolation not proven; use isolated staging." >&2
       exit 1
     fi

     # Step 2: Isolated GET probe on a fresh cache-buster key
     CB_PROBE="$(openssl rand -hex 8)"
     [[ "${CB_PROBE}" =~ ^[0-9a-f]{16}$ && "${CB_PROBE}" != "${CB_A}" && "${CB_PROBE}" != "${CB_B}" ]] || exit 1
     PROBE_URL="${TARGET_BASE}?__cb=${CB_PROBE}"

     curl -sS --connect-timeout 3 --max-time 5 \
       -D "${WORK_DIR}/probe_headers.txt" -o "${WORK_DIR}/probe_body.txt" "${PROBE_URL}" \
       -H "X-Forwarded-Host: cache-probe.invalid" \
       -H "X-Forwarded-Scheme: nothttps"

     # Step 3: Clean follow-up GET to the identical URL without probe headers
     curl -sS --connect-timeout 3 --max-time 5 \
       -D "${WORK_DIR}/clean_headers.txt" -o "${WORK_DIR}/clean_body.txt" "${PROBE_URL}"
     ```
   - 最初のリクエストだけで `cache-probe.invalid` が `${WORK_DIR}/probe_headers.txt`（`Location`）または `${WORK_DIR}/probe_body.txt` に現れた場合は、**MEDIUM（Unkeyed Input Reflection）** として報告します。
   - その後のクリーンなフォローアップリクエスト（`${WORK_DIR}/clean_headers.txt` と `${WORK_DIR}/clean_body.txt`）がキャッシュから返され（`CF-Cache-Status: HIT`、`X-Cache: Hit from cloudfront`、または `Age > 0`）、**かつ** 注入された `cache-probe.invalid` の反射、または汚染された `4xx`/`5xx` ステータスが再現される場合に限り、**HIGH（Confirmed Web Cache Poisoning）** にエスカレートします。
   - **自己完結型のローカルステージングフィクスチャ（ポジティブリプレイとネガティブコントロール）:**
     外部ネットワークに触れることなく検出ロジックをローカルで検証するには、次のループバックフィクスチャを実行します。
     ```bash
     python3 - << 'EOF'
     import http.server, threading, urllib.request

     STORE = {}
     class EdgeFixture(http.server.BaseHTTPRequestHandler):
         def log_message(self, *args): pass
         def do_GET(self):
             mode, _, query = self.path.partition("?")
             xfh = self.headers.get("X-Forwarded-Host", "clean.example")
             # /vulnerable caches by query only (unkeyed X-Forwarded-Host)
             # /safe includes X-Forwarded-Host in the cache key (negative control)
             key = (mode, query) if mode == "/vulnerable" else (mode, query, xfh)
             if key in STORE:
                 body, hit = STORE[key], "HIT"
             else:
                 body = f"<link href='https://{xfh}/app.js'>".encode()
                 STORE[key], hit = body, "MISS"
             self.send_response(200)
             self.send_header("CF-Cache-Status", hit)
             self.end_headers()
             self.wfile.write(body)

     srv = http.server.HTTPServer(("127.0.0.1", 0), EdgeFixture)
     port = srv.server_port
     threading.Thread(target=srv.serve_forever, daemon=True).start()

     def check_path(path):
         url = f"http://127.0.0.1:{port}{path}?__cb=deadbeef01234567"
         req1 = urllib.request.Request(url, headers={"X-Forwarded-Host": "cache-probe.invalid"})
         urllib.request.urlopen(req1, timeout=3).read()
         resp2 = urllib.request.urlopen(url, timeout=3)
         body2 = resp2.read().decode()
         hit2 = resp2.headers.get("CF-Cache-Status")
         return hit2 == "HIT" and "cache-probe.invalid" in body2

     assert check_path("/vulnerable") is True, "Expected positive replay detection on /vulnerable"
     assert check_path("/safe") is False, "Expected negative control to stay clean on /safe"
     srv.shutdown()
     print("Staging fixture verified: positive replay detected and negative control clean.")
     EOF
     ```

### 2. ソフトウェアサプライチェーンと完全性のリード（A03 / A08:2025 に関連）

1. **公開されたロックファイルとレジストリ設定の露出:**
   - 攻撃者が正確な依存関係ツリー（SBOM）を収集できないよう、`/package.json`、`/package-lock.json`、`/pnpm-lock.yaml`、`/yarn.lock` が本番環境で `404` または `403` を返すことを確認します。
   - 限定的で情報を持ち出さないシグネチャを使って、`/.npmrc` と `/.yarnrc.yml` を明示的にプローブします（`--connect-timeout 3 --max-time 5`）。HTTPステータスが `200` で、各行が `^(registry|@[a-z0-9_-]+:registry|//[^:]+:_authToken|npmScopes:|npmRegistries:|npmAuthToken:|nodeLinker:)` に一致し、かつ `<!DOCTYPE` や `<html` を含まないかを確認します。報告するのはHTTPステータスコードと真偽値の検出結果のみとし、設定内容やトークンの値は決して出力しないでください。
2. **本番環境のソースマップとSubresource Integrity（SRI）:**
   - 本番のJavaScriptバンドルが、元のTypeScriptやビジネスロジックを含む `.js.map` ファイルを公開していないかを確認します。
   - 外部CDNから読み込まれるサードパーティの `<script>` タグには、`integrity="sha384-..."` と `crossorigin="anonymous"` を必ず付与してください。

### 3. トランスポートとブラウザポリシーのリード（A04 / A05:2025 に関連）

1. **条件付きStrict Transport Security（HSTS）とTLSの状態:**
   - プレーンな `http://` が即座に（`301`/`308`）`https://` へリダイレクトされ、HTTPSレスポンスに適切な `max-age`（例: `max-age=31536000`）を持つ `Strict-Transport-Security` が含まれていることを確認します。
   - `includeSubDomains` と `preload` は、普遍的なデフォルトではなく**条件付きのデプロイ判断**として扱います。
     - `includeSubDomains` は、登録ドメイン配下の**すべての**サブドメインが有効なHTTPSをサポートしていることを確認した後にのみ追加してください。そうしないと、ブラウザはHTTPのみの内部サブドメインやレガシーなサブドメインへの接続を拒否します。
     - `preload` の申請は、[HSTS preload requirements](https://hstspreload.org/) を確認した後の、独立した明示的な運用判断として扱ってください。ブラウザのプリロードリストからの削除が反映されるまでには数か月かかるためです。
2. **Content-Security-Policy（CSP）の評価:**
   - `Content-Security-Policy` が `default-src`、`script-src`、`object-src 'none'`、`base-uri 'self'`、`frame-ancestors` を定義していることを確認します。
   - `script-src 'unsafe-eval'` が存在する場合は、**独立して**指摘します。暗号学的ノンス（`'nonce-...'`）とハッシュ（`'sha256-...'`）が無効化するのは `'unsafe-inline'` のみであり、`eval()` や文字列からのコード実行は無効化**しない**ためです。
   - `script-src 'unsafe-inline'` は、`'strict-dynamic'` またはレスポンスごとのノンス/ハッシュ（かつ、最新のブラウザで有効になる `unsafe-inline` フォールバックを含まない場合）が伴わない限り、指摘します。

### 4. クローラー境界とセッションCookieのリード（A06 / A07:2025 に関連）

1. **AIクローラーとエージェントの境界ガバナンス:**
   - `robots.txt` がAIクローラー（`GPTBot`、`ClaudeBot`、`PerplexityBot`、`Google-Extended`、`CCBot`）のルールを明示的に定義しているか、また `/llms.txt` または `/.well-known/agent.json` が機械可読な利用ポリシーを宣言しているかを確認します。
   - 攻撃者は素朴なWAFルールを回避するために `User-Agent: ChatGPT-User` や `Googlebot` を日常的に偽装するため、`User-Agent` 文字列だけを決して信頼しないでください。クローラーは、**Forward-Confirmed Reverse DNS（FCrDNS）**（クライアントIPに対する `PTR` 参照の後、IPが公式ドメインと一致することを確認する正引きの `A`/`AAAA` 参照）、公式に公開されているIP CIDRリスト（例: OpenAI/AnthropicのIPレンジ）、または暗号学的なHTTPメッセージ署名（`RFC 9421` Web Bot Auth）で検証してください。
2. **セッションCookieの強化（ペリメータ表面）:**
   - 認証情報またはセッション識別子を含むすべての `Set-Cookie` ヘッダーには、`HttpOnly` と `Secure` を含める必要があります。
   - `SameSite` と有効期間は、アプリケーションのアーキテクチャに照らして評価します。
     - ファーストパーティのフローでは、デフォルトで `SameSite=Lax`（または `Strict`）にします。`SameSite=None; Secure` は、意図的なクロスサイト埋め込み/フェデレーションが必要で、明示的なCSRF対策トークンまたはFetch Metadata（`Sec-Fetch-Site`）チェックが強制されている場合にのみ許可します。
     - 一時的なブラウザセッションCookieは、ブラウザを閉じると消えるよう、意図的に `Max-Age` と `Expires` を省略してもかまいません。永続Cookieには、セッションのリスク階層に適した有限の `Max-Age` または `Expires` を設定する必要があります。

### 5. エラー表面と開示ポリシーのリード（A09 / A10:2025 に関連）

1. **フェイルクローズのエラー処理（スタックトレースを漏らさない）:**
   - 存在しないルート（`/api/__probe_404_<random>`）を `--connect-timeout 3 --max-time 5` を付けてリクエストし、サーバーがスタックトレース（`java.sql.SQLException`、`PrismaClientKnownRequestError`、`Traceback`、`at Object.<anonymous>`、`/var/task/`、`node_modules/`）を漏らさず、クリーンで最小限のJSONまたはHTMLエラーを返すことを確認します。
2. **脆弱性開示ポリシー（`/.well-known/security.txt`）:**
   - `/.well-known/security.txt` で、RFC 9116への準拠（`Contact:` と期限切れでない `Expires:` フィールド）を確認します。

## オプションの外部検証（明示的なオプトインのみ）

デフォルトでは、プライベートなホスト名やステージングのホスト名がローカル環境の外に出ないよう、上記の `curl` ワークフローを使ってすべてのチェックをローカルで実行します。ユーザーが公開ドメインに対するサードパーティのスキャンを明示的に許可した場合は、実行前に外部CLIパッケージのバージョンを正確に固定してください。

```bash
# Opt-in only (requires user approval for external package execution / domain disclosure):
npx @stealthmark/cli@0.1.6 audit https://example.com
```

## 修正リファレンス（Next.jsヘッダー + パス拒否ミドルウェア）

`next.config.ts` の `headers()` はレスポンスヘッダーを付与するだけであり、機密パスへのアクセスをブロックは**しません**。`next.config.ts` をエッジの `middleware.ts`（または上流のNginx/Cloudflareルール）と組み合わせ、意図的な公開ディスカバリーエンドポイントを維持しつつ、隠れたリポジトリメタデータとロックファイルへのアクセスを拒否します。

```typescript
// 1) next.config.ts — baseline perimeter response headers & source map hardening
import type { NextConfig } from "next";

// Add "; includeSubDomains" only after confirming every subdomain supports HTTPS.
// Add "; preload" only as an explicit decision per https://hstspreload.org/ requirements.
const HSTS_POLICY =
  process.env.HSTS_ENABLE_PRELOAD === "true"
    ? "max-age=63072000; includeSubDomains; preload"
    : process.env.HSTS_INCLUDE_SUBDOMAINS === "true"
      ? "max-age=31536000; includeSubDomains"
      : "max-age=31536000";

const securityHeaders = [
  { key: "Strict-Transport-Security", value: HSTS_POLICY },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
  { key: "Vary", value: "Accept-Encoding, Origin" },
];

const nextConfig: NextConfig = {
  poweredByHeader: false,
  productionBrowserSourceMaps: false,
  async headers() {
    return [{ source: "/:path*", headers: securityHeaders }];
  },
};

export default nextConfig;
```

```typescript
// 2) middleware.ts — deny dotfiles, git metadata, registry configs, and lockfiles while preserving public /.well-known endpoints
import { NextResponse, type NextRequest } from "next/server";

const PUBLIC_WELL_KNOWN_PATHS = new Set([
  "/.well-known/security.txt",
  "/.well-known/agent.json",
]);

const BLOCKED_PATH_PREFIXES = [
  "/.git",
  "/.npmrc",
  "/.yarnrc.yml",
  "/package.json",
  "/package-lock.json",
  "/pnpm-lock.yaml",
  "/yarn.lock",
];

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (
    (pathname.startsWith("/.") && !PUBLIC_WELL_KNOWN_PATHS.has(pathname)) ||
    BLOCKED_PATH_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`))
  ) {
    return new NextResponse(null, { status: 404 });
  }
  return NextResponse.next();
}
```
