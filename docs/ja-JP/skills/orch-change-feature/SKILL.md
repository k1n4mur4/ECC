---
name: orch-change-feature
description: 既存の正常に動作している機能を新しい望ましい振る舞いへ変更する作業を、テストを新仕様に更新し、実装を合わせて変更し、レビューを行い、ゲート付きでコミットするところまでオーケストレーションします。振る舞いが壊れているわけではなく、別の振る舞いにしたい場合に使用します。
metadata:
  origin: ECC
---

# orch-change-feature

アクター · アクション · 対象: **orch · change · feature**。[`orch-pipeline`](../orch-pipeline/SKILL.md) の共有エンジンを薄くラップしたものです。

## 使用するタイミング

- 既存の機能は**動作している**が、望ましい振る舞いが異なるとき（「変更して」「調整して」「〜もするようにして」「X ではなく Y にして」など）。
- 兄弟スキルとの区別:
  - 壊れて**いない** → `orch-fix-defect` ではありません（再現すべきバグがないため）。
  - 新規で**ない** → `orch-add-feature` ではありません（その機能はすでに存在するため）。

## オペレーション設定

- **デフォルトのサイズ下限:** small — ほとんどの調整は 1〜2 個の関数で済みます。
- **フェーズマスク:** 0 →（新しい振る舞いに調査が必要な場合のみ 1）→ 軽量な 2 → 4 → 5 → 6。
- **最初の一手（フェーズ 4）:** *既存の*テストを新しい望ましい振る舞いを表すように更新し、それらがグリーンになるまで実装を変更します。テストを先に変更することが、調整と修正を分けるポイントです。

## 仕組み

1. 上記の設定で `orch-pipeline` エンジンを実行します。
2. 計画は軽量に保ちます。`planner` による本格的な計画作成が必要になるのは、`standard` 以上のサイズの場合のみです。
3. **Gate 1**（計画 / 変更後テストの承認）と **Gate 2**（コミット前）で停止します。
4. 変更がセキュリティ上のトリガーに触れる場合は `security-reviewer` を追加します。

## 例

```
orch-change-feature: make nws-poller alert at 2 warnings instead of 3
→ update threshold tests to new spec → change impl to green
→ code-review → commit  [GATE 2: confirm]
```
