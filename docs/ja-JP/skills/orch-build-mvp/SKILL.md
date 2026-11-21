---
name: orch-build-mvp
description: 設計書や仕様書から動作する MVP を立ち上げる工程をオーケストレーションします。SDD/PRD を取り込み、薄い垂直スライスを計画し、最初のエンドツーエンドのスライスをスキャフォールドしたうえで、レビューとゲート付き feat コミットを伴うジェネレーター・エバリュエーターのビルドループを回します。設計書や仕様書を、計画した垂直スライスを経て動作する MVP に仕上げる必要があるときに使用します。
metadata:
  origin: ECC
---

# orch-build-mvp

Actor · action · target: **orch · build · mvp**。[`orch-pipeline`](../orch-pipeline/SKILL.md) の共有エンジンを薄くラップしたものです。

## 使用するタイミング

- ユーザーが**設計書・仕様書**（SDD、PRD、system_design）を持っており、そこから動作する垂直スライスを立ち上げたいとき。
- 引数としてドキュメントのパスを受け取ります（例: `civicpulse/docs/SDD-v0.6.md`）。

## オペレーション設定

- **デフォルトのサイズ下限:** large — Scaffold を含む完全なパイプラインです。
- **フェーズマスク:** 0（仕様を読む）→ 1 → 2（重め）→ 3（スキャフォールド）→ 4 → 5 → 6。
- **最初の一手（フェーズ 0 → 2）:** ドキュメントを読み、スコープ、確定済みの決定事項、機能一覧を抽出します。それを**薄い垂直スライス**（すべてのモデルを作ってからすべてのビューを作るのではなく、まず 1 本のエンドツーエンドの経路）という方針で順序立てます。フェーズ 3 でその最初のスライスを立ち上げます。

## 仕組み

1. 上記の設定で `orch-pipeline` エンジンを実行します。
2. 反復ループを自前で組むのではなく、**既存の GAN ハーネスを再利用**します。
   - SDD を `gan-harness/spec.md` と `gan-harness/eval-rubric.md` に変換します（すでに仕様があるため、`gan-planner` が生成するものの代わりになります）。
   - `/gan-build "<one-line brief>" --skip-planner` でビルドを進めます（デフォルト: `--max-iterations 15`、`--pass-threshold 7.0`、`--eval-mode playwright`。UI を伴わないスライスには `--eval-mode code-only` を使用します）。
   - このコマンドは `gan-generator` → `gan-evaluator` のループを実行し、スコアが合格基準に達するか頭打ちになるまで `gan-harness/feedback/feedback-NNN.md` を書き出します。
3. **Gate 1**（スライス計画）と **Gate 2**（コミット前）で停止します。スキャフォールドと各スライスは、それぞれ別々の `feat:` コミットとしてコミットします。
4. セキュリティ上のトリガーに触れるスライスには `security-reviewer` を追加します。

## 例

```
orch-build-mvp: civicpulse/docs/SDD-v0.6.md
→ read SDD → slice list (vertical) → scaffold slice 1  [GATE 1: approve]
→ /gan-build --skip-planner (generator → evaluator loop) scores vs spec → review
→ commit feat:  [GATE 2: confirm] → next slice
```
