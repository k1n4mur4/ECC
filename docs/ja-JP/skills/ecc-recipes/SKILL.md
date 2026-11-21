---
name: ecc-recipes
description: 記述されたワークフローを、実行順序と停止条件を添えて適切なECCコマンドグループに対応付けます。または、commandsディレクトリからライブで読み取ったすべてのコマンドグループのレシピファミリーを一覧表示します。助言のみで、実行はしません。どのコマンドでワークフローを実行できるか、タスクのコマンド順序、ECCのパイプライン一覧を尋ねられたときに使用します。タスクの実行（コマンド自体にルーティングしてください）、単一コマンドのドキュメント（ecc-guideを使用）、プロンプトの書き換え（prompt-optimizerを使用）には使用しません。
argument-hint: <workflow description | empty=list all>
origin: community
author: KyawZinLatt
metadata:
  version: "1.0.0"
---

# ECC Recipes

「自分のワークフローを実行するのはどのECCスラッシュコマンドのグループで、どの順序で実行し、いつ止めるのか」に答える単一のエントリーポイントです。すべてのコマンドグループのレシピファミリーを閲覧することもできます。

既存の2つのスキルの間にあるギャップを埋めます。

- `ecc-guide` — コマンドとドキュメントの参照先を一覧表示しますが、フラットなカタログです。
- `prompt-optimizer` — タスクをコンポーネントに対応付けますが、その出力は単一のプロンプトであり、実行順序と停止条件を持つ複数コマンドのグループではありません。

このスキルが追加するのは、**ファミリーのグループ化 + 実行順序 + 停止条件**です。

## 有効化するタイミング

- 「<workflow> にはどのコマンドグループを実行すればよいですか？」
- 「MVPの構築 / 不具合の修正 / リファクタリングのコマンド順序は何ですか？」
- 「ECCのコマンドグループのレシピをすべて見せて」（カタログモード）
- 「ECCにはワークフローのパイプラインがいくつありますか？」
- ユーザーが説明の有無にかかわらず `/ecc-recipes` を呼び出した場合。

### 使用しないタイミング

- ユーザーがタスクを今すぐ実行してほしい場合 — 説明するのではなく、実際のコマンドにルーティングします。
- ユーザーが1つのコマンドの詳細なドキュメントを求めている場合 — `ecc-guide` を使用します。
- ユーザーがプロンプトの下書きの書き換えを求めている場合 — `prompt-optimizer` を使用します。

## コア原則

**記憶ではなく、現在のファイルから答えます。** コマンドセットは変化します。件数やメンバー一覧をハードコードしてはいけません。実行のたびにライブの `commands/` ディレクトリを読み取り、その後ファミリーに分類します。

### ライブ読み取り

commandsディレクトリを解決し（最初に存在するもの）、名前を一覧表示します。

```bash
for D in \
  "$HOME"/.claude/plugins/marketplaces/ecc/commands \
  "$HOME"/.claude/plugins/cache/ecc/ecc/*/commands \
  ./commands \
  ./.claude/commands \
  "$HOME"/.claude/commands; do
  [ -d "$D" ] && CMD_DIR="$D" && break
done
[ -z "${CMD_DIR:-}" ] && { echo "No ECC commands directory found."; return 1; }
find "$CMD_DIR" -maxdepth 1 -name '*.md' -exec basename {} .md \; | sort
```

より豊富なグループ化のために、`manifests/install-*.json` が存在する場合は任意で読み取ります。必要最小限の読み取りにとどめてください。

## ファミリーの分類（プレフィックスによる）

コマンド名を先頭のプレフィックスでグループ化し、既知の単独コマンドは手動で対応付けます。ファミリーはライブで導出されます。以下の表は固定リストではなく、*分類ルール*です。

| ファミリーのプレフィックス | レシピの意味 | 典型的な実行順序 |
|---|---|---|
| `orch-*` | タスク種別ごとのゲート付き Research、Plan、TDD、Review、Commit | タスクの種類に応じて orch-* を1つ選びます。内部のフェーズはそのコマンド自身が実行します |
| `multi-*` | マルチモデルワークフロー | `multi-plan`、次に `multi-execute`、次にレビュー（またはエンドツーエンドで `multi-workflow`） |
| `prp-*` | PRDから計画、実装、PRまでのパイプライン | `prp-prd`、次に `prp-plan`、次に `prp-implement`、次に `prp-commit`、次に `prp-pr` |
| `epic-*` | 大規模なマルチユニットのエピック（並列） | `epic-decompose`、次に `epic-claim`、次に `epic-validate`、次に `epic-review`、次に `epic-unblock`、次に `epic-sync`、次に `epic-publish` |
| `loop-*` | マネージドな自律ループとモニター | `loop-start <pattern>`、その後 `loop-status` で監視 |
| `gan-*` | ジェネレーターとエバリュエーターのループ | `gan-build`（コード）または `gan-design`（UI）。自己ループします |
| `*-build` / `*-review` / `*-test` | 言語ごとのCIトライアド（テスト・ビルド・レビューの3点セット） | `<lang>-test`（TDD）、次に `<lang>-build`（修正）、次に `<lang>-review` |
| `hookify-*` | 動作フックの管理 | `hookify`、次に `hookify-list`、次に `hookify-configure` |
| `learn` / `instinct-*` / `evolve` / `promote` / `prune` | 継続的学習 | `learn`、次に `instinct-status`、次に `evolve`、次に `promote` |
| 単独コマンド | `santa-loop`、`plan`、`plan-prd`、`pr`、`code-review`、`checkpoint` など | 単独で、またはグループ間のつなぎとして使用 |

プレフィックスルールに一致しないコマンドは、1行の説明とともに**単独コマンド**の下に一覧表示します。

## 仕組み

```
1. CMD_DIR からコマンド名をライブで読み取る。
2. プレフィックスと単独コマンドのマップでファミリーに分類する。
3. ワークフローの説明が与えられた場合 -> マッチモード。
   なければ -> カタログモード。
4. 助言のみ: 計画を出力する。一致したコマンドは決して実行しない。
```

### カタログモード（説明なし）

ファミリーの表を出力します。各ファミリーについて、メンバー数、メンバー、1行の意味、典型的な実行順序を示します。最後にコマンドの総数を示し、一致するレシピを得るためにワークフローを記述するよう促します。

### マッチモード（説明あり）

1. ワークフローを1文で言い換えます。
2. 最適なファミリーを1〜2個選び、それぞれ理由を1行で述べます。
3. **実行順序ブロック** — 一致したファミリーの正確なコマンド順序を示します。
4. **停止条件** — 常に明示します（最大実行回数、完了シグナル、レビュー合格回数、または単発実行）。自律ループの場合は、サブスクリプションの急速な消費について警告し、上限として機能するバックストップ（最大反復回数など）を推奨します。
5. **参照先** — `commands/<name>.md` のパスと `/ecc-guide <name>`。

## 出力テンプレート（マッチモード）

```
Workflow: <one-sentence restatement>

Best fit: <family> — <why>
(Alt: <family> — <why>)

Run-order:
  /<cmd1>   # job
  /<cmd2>   # job
  /<cmd3>   # job
  STOP when: <condition>
  WARNING (autonomous loops only): an unbounded loop burns subscription/credits —
  add a max-iteration or max-cost backstop alongside the completion signal.

Read full docs:
  commands/<cmd1>.md   (or: /ecc-guide <cmd1>)
```

## 例

**カタログ:** `/ecc-recipes` → ファミリーの表と総数を出力します。

**マッチ:** `/ecc-recipes plan a whole app upfront then auto-build with adversarial
review until done` → 最適: `loop-*`（自律）が `gan-*` または `santa-loop`（敵対的）をラップします。実行順序: `plan-prd`、次に `loop-start rfc-dag --mode safe`、その後 `loop-status` で監視。停止: すべてのユニットがN回連続でレビューに合格したとき（消費を抑えるため、最大反復回数のバックストップを追加）。

**マッチ:** `/ecc-recipes fix a bug in my Go service` → 最適: `orch-fix-defect`（再現、修正、レビュー、コミット）。代替: `go-test`、次に `go-build`、次に `go-review`。停止: リグレッションテストがグリーンになり、レビューに合格したとき。

## 非目標

- 実行器ではありません — 助言のみです。
- コマンドごとの詳細なドキュメントではありません — それは `ecc-guide` の役割です。
- プロンプトの書き換えではありません — それは `prompt-optimizer` の役割です。
- コマンドの件数やメンバー一覧を決してハードコードしません — 常にライブで読み取ります。
