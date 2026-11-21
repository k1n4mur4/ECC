---
name: kubernetes-patterns
description: 本番グレードのデプロイ向けの、Kubernetes ワークロードパターン、リソース管理、RBAC、プローブ、オートスケーリング、ConfigMap/Secret の扱い、kubectl デバッグ。Kubernetes マニフェストの作成・レビュー時、またはプローブ、RBAC、オートスケーリング、リソース制限、繰り返し退避（evict）される Pod のデバッグ時に使用します。
metadata:
  origin: ECC
---

# Kubernetes パターン

ワークロードを確実にデプロイ・管理・デバッグするための、本番グレードの Kubernetes パターンです。

## 有効化するタイミング

- Kubernetes マニフェスト（Deployment、Service、Ingress、Job）を書くとき
- リソースの requests/limits や liveness/readiness プローブを設定するとき
- RBAC、Namespace、ServiceAccount を設定するとき
- K8s で設定情報とシークレットを管理するとき
- CrashLoopBackOff、OOMKilled、Pending の Pod、イメージ取得エラーをデバッグするとき
- 再起動回数ゼロのまま Pod が置き換わり続ける問題（退避、descheduler によるチャーン）を調査するとき
- HPA（Horizontal Pod Autoscaler）や PodDisruptionBudget を設定するとき
- セキュリティや正確性の観点で K8s YAML をレビューするとき

## 使用するタイミング

> 上記の **有効化するタイミング** と同じです。このエイリアスは、リポジトリのスキル形式規約を満たすためのものです。Kubernetes の YAML やワークロードを書く、レビューする、デバッグするときは、いつでもこのスキルを使用してください。

## 仕組み

このスキルは、タスク別に整理された **コピー＆ペーストで使える本番グレードの YAML パターン** と **kubectl デバッグコマンド** を提供します。

1. **Deployment テンプレート** — セキュリティコンテキスト、ローリングアップデート戦略、3 種類すべてのプローブ、リソース制限、ConfigMap/Secret からの環境変数注入を備えた、完全に設定済みの本番用 `Deployment`。
2. **プローブ** — startup、liveness、readiness の使い分けを示す判断表と、正しい `failureThreshold × periodSeconds` の計算。
3. **Service と Ingress** — ClusterIP、LoadBalancer、および cert-manager アノテーションを用いた TLS Ingress のパターン。
4. **ConfigMap と Secret** — `envFrom`、ファイルマウント、外部シークレットに関するガイダンス。
5. **リソース管理** — ワークロードの種類別（Web API、JVM、ワーカー、サイドカー）の requests と limits の目安。
6. **RBAC** — 最小権限の ServiceAccount → Role → RoleBinding の連鎖。
7. **HPA と PDB** — オートスケーリングとノードドレイン時の安全性の設定。
8. **Job と CronJob** — 正しい `restartPolicy` を用いた、単発およびスケジュール実行のワークロードパターン。
9. **kubectl チートシート** — ログ、exec、ロールバック、port-forward、dry-run、よくあるエラーの診断、Pod チャーン（退避）の切り分け。
10. **アンチパターンとチェックリスト** — やってはいけないことと、セキュリティ・信頼性・可観測性のチェックリスト。

## 例

完全で実行可能な例は以下の各セクションを参照してください。クイックリファレンス:

| タスク | 参照先 |
|------|---------|
| 本番用 Deployment YAML 一式 | [コアワークロードパターン](#コアワークロードパターン) |
| プローブの設定 | [プローブ](#プローブ--livenessreadinessstartup) |
| 最小権限の RBAC 設定 | [RBAC](#rbac--role-と-serviceaccount) |
| CrashLoopBackOff のデバッグ | [kubectl デバッグチートシート](#kubectl-デバッグチートシート) |
| 再起動ゼロで Pod が置き換わる | [Pod チャーンの切り分け](#再起動ゼロで-pod-が置き換わるチャーン) |
| オートスケーリング | [HPA](#horizontal-pod-autoscaler-hpa) |

---

## コアワークロードパターン

### Deployment — 本番用テンプレート

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-namespace
  labels:
    app: my-app
    version: "1.0.0"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # 更新中に 1 つ余分な Pod を許可
      maxUnavailable: 0    # 希望数を下回らせない
  template:
    metadata:
      labels:
        app: my-app
        version: "1.0.0"
    spec:
      # Pod レベルのセキュリティコンテキスト
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001

      # 正常なシャットダウン
      terminationGracePeriodSeconds: 30

      containers:
        - name: my-app
          image: ghcr.io/org/my-app:1.0.0   # :latest は絶対に使用しない
          imagePullPolicy: IfNotPresent

          ports:
            - containerPort: 8080
              protocol: TCP

          # リソースの requests と limits の両方が必須
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"

          # コンテナのセキュリティコンテキスト
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL

          # プローブ（下記のプローブのセクションを参照）
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            failureThreshold: 30
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
            failureThreshold: 2

          # ConfigMap と Secret から環境変数を設定
          envFrom:
            - configMapRef:
                name: my-app-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: my-app-secrets
                  key: db-password

          # readOnlyRootFilesystem: true の場合の書き込み可能な tmp ディレクトリ
          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

---

## プローブ — Liveness、Readiness、Startup

それぞれのプローブをいつ使うかを理解することが重要です。

| プローブ | 失敗時のアクション | 用途 |
|-------|---------------|---------|
| `startupProbe` | 起動が遅い場合にコンテナを強制終了 | 起動が遅いアプリ（JVM、Python） |
| `livenessProbe` | コンテナを再起動 | デッドロック／ハングしたプロセスの検出 |
| `readinessProbe` | Service のエンドポイントから除外 | 一時的な利用不可（DB 再接続） |

```yaml
# 正しいパターン: startupProbe が遅い起動をカバーし、
# その後 liveness/readiness が引き継ぐ
startupProbe:
  httpGet:
    path: /health
    port: 8080
  failureThreshold: 30  # 30 * 5s = 最大起動時間 150 秒
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 30
  failureThreshold: 3   # 3 * 30s = 再起動まで 90 秒

readinessProbe:
  httpGet:
    path: /ready         # 別エンドポイント: DB、キャッシュなどを確認
    port: 8080
  periodSeconds: 10
  failureThreshold: 2
```

```yaml
# 誤り: startupProbe を使わず initialDelaySeconds を使用
# アプリの起動に 60 秒かかる場合は、代わりに startupProbe を設定する
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 60   # 悪い例: 任意の待機時間であり、競合状態になる
```

---

## Service と Ingress

### Service のタイプ

```yaml
# ClusterIP（デフォルト）— 内部専用
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-namespace
spec:
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
```

```yaml
# LoadBalancer — 外部トラフィック（クラウドプロバイダー）
spec:
  type: LoadBalancer
  ports:
    - port: 443
      targetPort: 8080
```

### TLS 付き Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.example.com
      secretName: my-app-tls
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

---

## ConfigMap と Secret

### ConfigMap — 機密でない設定

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: my-namespace
data:
  LOG_LEVEL: "info"
  APP_ENV: "production"
  MAX_CONNECTIONS: "100"
  # 複雑な設定はファイルとしてマウント
  app.yaml: |
    server:
      port: 8080
      timeout: 30s
```

```yaml
# ConfigMap をファイルとしてマウント
volumes:
  - name: config
    configMap:
      name: my-app-config
      items:
        - key: app.yaml
          path: app.yaml
volumeMounts:
  - name: config
    mountPath: /etc/app
    readOnly: true
```

### Secret — 機密データ

```bash
# リテラルから Secret を作成（CLI で作成し、その後 Vault/SOPS に保存）
kubectl create secret generic my-app-secrets \
  --from-literal=db-password='s3cr3t' \
  --namespace=my-namespace \
  --dry-run=client -o yaml | kubectl apply -f -
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: my-namespace
type: Opaque
# 値は base64 エンコードされているだけ（暗号化ではありません — 実際の暗号化には Sealed Secrets または ESO を使用）
data:
  db-password: czNjcjN0  # 's3cr3t' の base64
```

> **重要:** 生の Kubernetes Secret は base64 エンコードされているだけで、クラスターで暗号化が設定されていない限り保存時に暗号化されません。本番環境では [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) または [External Secrets Operator](https://external-secrets.io) を使用してください。

---

## リソースの requests と limits

```yaml
resources:
  requests:       # スケジューラーが Pod の配置にこれを使用
    cpu: "100m"   # 100 ミリコア = 0.1 CPU
    memory: "128Mi"
  limits:         # これを超えるとコンテナは強制終了/スロットリングされる
    cpu: "500m"
    memory: "256Mi"
```

**目安:**

| ワークロードの種類 | CPU request | メモリ request | 備考 |
|---------------|-------------|----------------|-------|
| Web API | 100–250m | 128–256Mi | limits は requests の 2〜4 倍に設定 |
| ワーカー/コンシューマー | 250–500m | 256–512Mi | 予測可能性のためメモリ limit = request |
| JVM アプリ | 500m–1 | 512Mi–2Gi | JVM のオーバーヘッド分として `-Xmx` より余裕を持たせる |
| サイドカー | 10–50m | 32–64Mi | 最小限に保つ |

```yaml
# 誤り: requests も limits もない — スケジューリングが予測不能になり、OOM による退避が起きる
containers:
  - name: app
    image: myapp:latest
    # resources の指定がない — 本番環境では危険

# 誤り: requests なしの limits — requests は limits がデフォルトになり、容量を過剰に確保してしまう
resources:
  limits:
    cpu: "2"
    memory: "1Gi"
  # requests がない — limits の値がデフォルトになる
```

---

## RBAC — Role と ServiceAccount

### 最小権限の原則

**アプリが Kubernetes API を呼び出すかどうかに応じた 2 つのパターン:**

#### パターン A — アプリが Kubernetes API を必要としない場合（ほとんどのアプリ）

ServiceAccount のトークン自動マウントを無効にします。Role/RoleBinding は不要です。

```yaml
# トークンを無効にした ServiceAccount — 最も安全なデフォルト
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-namespace
automountServiceAccountToken: false   # K8s API トークンは Pod に注入されない
```

```yaml
# Deployment での参照 — トークンなし、API アクセスなし
spec:
  template:
    spec:
      serviceAccountName: my-app-sa
      automountServiceAccountToken: false   # 念のため Pod レベルでも設定
```

#### パターン B — アプリが Kubernetes API を必要とする場合（オペレーター、コントローラー、設定ウォッチャー）

トークンを有効にし、実際に必要な権限のみを付与します。

```yaml
# 1. ServiceAccount — この SA のトークンを有効にする
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-namespace
automountServiceAccountToken: true    # トークンが必要: アプリが K8s API を呼び出す
```

```yaml
# 2. Role — アプリが必要とするものだけを付与（Namespace スコープ）
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: my-app-role
  namespace: my-namespace
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]    # 読み取り専用、特定のリソース
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["my-app-secrets"]  # 名前で特定の Secret に限定
    verbs: ["get"]
```

```yaml
# 3. Role を ServiceAccount にバインド
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: my-app-rolebinding
  namespace: my-namespace
subjects:
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-namespace
roleRef:
  kind: Role
  apiGroup: rbac.authorization.k8s.io
  name: my-app-role
```

```yaml
# 4. Deployment で SA を参照
spec:
  template:
    spec:
      serviceAccountName: my-app-sa
      # automountServiceAccountToken は SA の設定を引き継いで true がデフォルトになる — トークンが注入される
```

---

## Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: my-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2      # HA のため常に最低 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70    # 平均 CPU が 70% を超えたらスケールアップ
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

> HPA は、すべてのコンテナに `resources.requests` が設定されている必要があります。使用率を `current / request` として計算するためです。

---

## PodDisruptionBudget (PDB)

ノードのドレインやローリングアップデート中に、同時に停止する Pod が多くなりすぎるのを防ぎます。

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
  namespace: my-namespace
spec:
  minAvailable: 2           # または maxUnavailable: 1 を使用
  selector:
    matchLabels:
      app: my-app
```

---

## Namespace とマルチテナンシー

```bash
# リソースクォータ付きで Namespace を作成
kubectl create namespace my-namespace

# ResourceQuota を適用して Namespace の消費量を制限
kubectl apply -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: my-namespace-quota
  namespace: my-namespace
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
EOF
```

---

## Job と CronJob

```yaml
# 単発の Job（DB マイグレーション、データ処理）
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  namespace: my-namespace
spec:
  backoffLimit: 3          # 失敗時に最大 3 回までリトライ
  ttlSecondsAfterFinished: 3600   # 1 時間後に自動削除
  template:
    spec:
      restartPolicy: OnFailure    # Job では Always は使わない（OnFailure または Never）
      containers:
        - name: migrate
          image: ghcr.io/org/my-app:1.0.0
          command: ["python", "manage.py", "migrate"]
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
```

```yaml
# CronJob
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup-job
  namespace: my-namespace
spec:
  schedule: "0 2 * * *"         # 毎日午前 2 時
  concurrencyPolicy: Forbid      # 前回の実行が継続中なら実行しない
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cleanup
              image: ghcr.io/org/cleanup:1.0.0
              resources:
                requests:
                  cpu: "50m"
                  memory: "64Mi"
```

---

## kubectl デバッグチートシート

```bash
# --- Pod のステータスとログ ---
kubectl get pods -n my-namespace
kubectl get pods -n my-namespace -o wide          # 割り当てられたノードを表示
kubectl describe pod <pod-name> -n my-namespace   # イベントと状態の詳細
kubectl logs <pod-name> -n my-namespace           # 現在のログ
kubectl logs <pod-name> -n my-namespace --previous  # クラッシュしたコンテナのログ
kubectl logs <pod-name> -n my-namespace -c <container>  # マルチコンテナ Pod

# --- 実行中のコンテナに入る ---
kubectl exec -it <pod-name> -n my-namespace -- sh
kubectl exec -it <pod-name> -n my-namespace -- bash

# --- リソース使用量を確認 ---
kubectl top pods -n my-namespace
kubectl top nodes

# --- Deployment の操作 ---
kubectl rollout status deployment/my-app -n my-namespace
kubectl rollout history deployment/my-app -n my-namespace
kubectl rollout undo deployment/my-app -n my-namespace      # ロールバック
kubectl rollout undo deployment/my-app --to-revision=2 -n my-namespace

# --- 手動でスケール ---
kubectl scale deployment my-app --replicas=5 -n my-namespace

# --- イベントを確認（クラスター全体の問題）---
kubectl get events -n my-namespace --sort-by='.lastTimestamp'

# --- ローカルデバッグ用の port-forward ---
kubectl port-forward pod/<pod-name> 8080:8080 -n my-namespace
kubectl port-forward svc/my-app 8080:80 -n my-namespace

# --- dry-run で YAML を検証 ---
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server   # 稼働中のクラスターに対して検証
```

### よくあるエラーの診断

```bash
# CrashLoopBackOff: コンテナがクラッシュし続ける
kubectl logs <pod-name> --previous -n my-namespace  # クラッシュ時のログを確認
kubectl describe pod <pod-name> -n my-namespace     # 終了コードと OOMKilled を確認

# ImagePullBackOff: イメージを取得できない
kubectl describe pod <pod-name> -n my-namespace     # Events セクションを確認
# 原因: イメージタグの誤り、imagePullSecret の欠落、プライベートレジストリ

# Pending の Pod: スケジュールされない
kubectl describe pod <pod-name> -n my-namespace
# 原因: リソース不足、一致する nodeSelector がない、taint/toleration の不一致

# OOMKilled: メモリ不足
# メモリ limits を増やし、メモリリークを確認する
kubectl describe pod <pod-name> -n my-namespace | grep -A5 "Last State"
```

### 再起動ゼロで Pod が置き換わる（チャーン）

`RESTARTS 0` の新しい Pod は、新規レプリカである場合も、置き換えられたものである場合もあります。Pod UID と `creationTimestamp` を以前の観測結果と比較してください。UID が変わっていれば置き換えが確定しますが、再起動回数だけでは削除されたことの証明にはなりません。`kubectl get events` では何も表示されないことがよくあります。イベントはデフォルトで 1 時間後に失効し、`events.k8s.io` への RBAC を持たない descheduler はイベントを発行しないためです。kubelet によるノード圧迫（node-pressure）の退避は別物です。Eviction API を経由せず、古い Pod は `Evicted` として一覧に残ります。

| シグナル | 考えられる原因 | 確認方法 |
|--------|--------------|--------------|
| テンプレートの変更が `kubectl.kubernetes.io/restartedAt` のみの新しい ReplicaSet | `kubectl rollout restart` | 監査ログ: Deployment への `patch` と送信者 |
| 同じ ReplicaSet、同じノード | API 起点の退避（descheduler、`kubectl drain`） | 監査ログ: `pods/eviction` の `create` |
| 同じ ReplicaSet で、ノードが追加または削除された | ノードの回収または置き換え（スポット/プリエンプティブル、オートスケーラー、アップグレード） | `kubectl get nodes`（AGE）、クラウドプロバイダーのログ |

```bash
# 誰が何を退避したか: API サーバーの監査ログ、objectRef.subresource=eviction、verb=create
# GKE の例（Cloud Logging）:
gcloud logging read 'protoPayload.methodName="io.k8s.core.v1.pods.eviction.create"' --freshness=4h \
  --format='value(timestamp,protoPayload.authenticationInfo.principalEmail,protoPayload.resourceName)'

# descheduler の CronJob は、各退避の背後にあるプラグインをログに出力する
kubectl logs -n kube-system job/<descheduler-job> | grep "Evicted pod"
```

---

## アンチパターン

```yaml
# 悪い例: :latest タグの使用 — デプロイが非決定的になる
image: myapp:latest

# 良い例: 特定の不変タグ（SHA またはセマンティックバージョン）に固定
image: ghcr.io/org/myapp:1.4.2
# または
image: ghcr.io/org/myapp@sha256:abc123...

# ---

# 悪い例: root での実行
securityContext: {}    # デフォルトは root

# 良い例: 明示的な UID を指定した非 root
securityContext:
  runAsNonRoot: true
  runAsUser: 1001

# ---

# 悪い例: リソース制限なし — 1 つの Pod がノード全体を枯渇させうる
containers:
  - name: app
    image: myapp:1.0.0
    # resources の定義なし

# 良い例: 常に requests と limits を設定
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"

# ---

# 悪い例: 平文のシークレットを ConfigMap に保存
apiVersion: v1
kind: ConfigMap
data:
  DB_PASSWORD: "mysecretpassword"   # 絶対にやらない — Secret または外部シークレットマネージャーを使用

# ---

# 悪い例: アプリケーションの ServiceAccount に ClusterAdmin を付与
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
roleRef:
  kind: ClusterRole
  name: cluster-admin    # アプリに全権限を与えてしまう

# ---

# 悪い例: PDB の minAvailable: 0 — 目的を台無しにする
spec:
  minAvailable: 0

# ---

# 悪い例: スケジューラーが満たせないソフトな分散を descheduler が強制する
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway   # スケジューラーはスコアリングにしか使わない
# ...さらに、constraints: [DoNotSchedule, ScheduleAnyway] を指定した
# descheduler の RemovePodsViolatingTopologySpreadConstraint があり、
# レプリカ数がノード数に近く、ノードが requests でほぼ満杯だと、実行のたびに Pod が 1 つ退避される。
# 置き換えられた Pod は再び混雑したノードに配置され、次の実行でまた退避されるため、Pod は一日中チャーンし続ける。
# 良い例: descheduler には DoNotSchedule（デフォルト）のみを強制させるか、
# maxSkew を引き上げるか、分散が満たせるよう余剰容量を確保する

# ---

# 悪い例: Job での restartPolicy: Always（無限の再起動ループを引き起こす）
spec:
  restartPolicy: Always   # Job には OnFailure か Never を使用
```

---

## ベストプラクティスチェックリスト

### セキュリティ
- [ ] コンテナが非 root で実行される（`runAsNonRoot: true`、`runAsUser` を設定）
- [ ] `readOnlyRootFilesystem: true` とし、書き込み可能なパスには `emptyDir` を使用
- [ ] `allowPrivilegeEscalation: false`
- [ ] すべての capability を削除（`capabilities.drop: [ALL]`）
- [ ] アプリごとに専用の ServiceAccount を使用し、`default` は使わない
- [ ] 必要でない限り `automountServiceAccountToken: false`
- [ ] RBAC は最小権限に従う（必要でない限り `ClusterRole` ではなく `Role` を使用）
- [ ] Secret は Sealed Secrets または External Secrets Operator で管理

### 信頼性
- [ ] 3 種類すべてのプローブを設定（startup + liveness + readiness）
- [ ] すべてのコンテナにリソースの requests と limits の両方を設定
- [ ] 本番ワークロードには `minReplicas: 2` 以上
- [ ] ステートフルまたは重要なサービスには PodDisruptionBudget を定義
- [ ] `maxUnavailable: 0` の `RollingUpdate` 戦略
- [ ] 負荷が変動するサービスには HPA を設定

### 可観測性
- [ ] アプリが `/health`（liveness）と `/ready`（readiness）のエンドポイントを公開
- [ ] 構造化 JSON ログ（ログに PII を含めない）
- [ ] リソースラベル: `app`、`version`、`environment`

---

## 関連スキル

- `docker-patterns` — マルチステージ Dockerfile とイメージのセキュリティ
- `deployment-patterns` — CI/CD パイプライン、ロールバック戦略、ヘルスチェックエンドポイント
- `security-review` — より広範なセキュリティ強化のコンテキスト
- `git-workflow` — K8s との GitOps 連携（ArgoCD / Flux パターン）
