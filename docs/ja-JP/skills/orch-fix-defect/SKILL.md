---
name: orch-fix-defect
description: バグ修正をオーケストレーションします。バグを失敗する回帰テストとして再現し、green になるまで修正し、レビューを行い、ゲート付きでコミットします。各フェーズは対応する ECC エージェントに委譲します。既存の動作が壊れている、または誤っている場合に使用します。
metadata:
  origin: ECC
---

# orch-fix-defect

Actor · action · target: **orch · fix · defect**。[`orch-pipeline`](../orch-pipeline/SKILL.md) の共有エンジンを薄くラップしたものです。

## 使用するタイミング

- 何かが**壊れている**場合: 誤った出力、エラー、クラッシュ、リグレッション。
- 兄弟スキルとの区別:
  - 動作は正しいが別の動作にしたい → `orch-change-feature`。
  - その機能がまだ存在しない → `orch-add-feature`。

## オペレーション設定

- **デフォルトのサイズ下限:** small（多くの場合 trivial）。
- **フェーズマスク:** 0 → (根本原因が自明でない場合、または standard 以上の場合のみ、軽量版のフェーズ 2) →
  4 → 5 → 6。リサーチ (1) は通常スキップします。
- **最初の一手（フェーズ 4）:** バグを**新たな失敗する**テスト（回帰テスト）として再現し、
  green になるまで修正します。まずバグの存在を証明することが、本当の修正と単なる調整との違いになります。

## 仕組み

1. 上記の設定で `orch-pipeline` エンジンを実行します。
2. 根本原因が不明な場合は、red テストの前に `code-explorer` で範囲を絞り込みます。
   ビルドの破損は `build-error-resolver` / `/build-fix` にエスカレーションします。
3. **Gate 1**（計画が作成された場合のみ）と **Gate 2**（コミット前）で停止します。
4. 欠陥がセキュリティ上重要なパスにある場合は `security-reviewer` を追加します。

## 例

```
orch-fix-defect: poller crashes on empty NWS response
→ write failing test reproducing the crash → fix to green
→ code-review → commit  [GATE 2: confirm]   (commit: fix:)
```
