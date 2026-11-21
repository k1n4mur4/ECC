---
name: orch-refine-code
description: 振る舞いを保つリファクタリングをオーケストレーションします。テストがグリーンであることを確認し、振る舞いを変えずに再構成し、テストをグリーンに保ち、レビューを行い、ゲート付きでコミットします。構造は改善したいが振る舞いは変えてはならない場合に使用します。
metadata:
  origin: ECC
---

# orch-refine-code

アクター · アクション · 対象: **orch · refine · code**。[`orch-pipeline`](../orch-pipeline/SKILL.md) の共有エンジンを薄くラップしたものです。

## 使用するタイミング

- 振る舞いは同じまま **構造をより良く** する場合: モジュールの抽出、重複の除去、デッドコードの削除、ネストの削減、分かりやすさのための名前変更。
- 兄弟スキルとの区別: 振る舞いを少しでも変える意図がある場合、このスキルは不適切です（`orch-change-feature` / `orch-fix-defect` を使用してください）。

## 操作設定

- **デフォルトのサイズ下限:** standard — 再構成は複数ファイルに及びます。
- **フェーズマスク:** 0 → 2（再構成の計画）→ 4（グリーンの維持）→ 5 → 6。新しい振る舞いのテストは書きません。既存のスイートがセーフティネットです。
- **最初の動き（フェーズ 4）:** コードに触れる**前に**、関連するテストが存在し**グリーンである**ことを確認します。カバレッジが薄い場合は、先に特性化テスト（characterization tests）を追加します。その後、小さなステップで再構成し、各ステップの後にテストを再実行します。

## 仕組み

1. 上記の設定で `orch-pipeline` エンジンを実行します。
2. デッドコード／重複の一掃には、`refactor-cleaner` エージェントに委譲します（knip / depcheck / ts-prune を実行し、不要なコードを安全に削除します）。
3. **Gate 1**（再構成計画）と **Gate 2**（コミット前）で停止します。
4. `refactor:` としてコミットします。差分は振る舞いに中立でなければなりません。

## 例

```
orch-refine-code: extract the NWS HTTP client out of poller.py
→ confirm tests green → plan extraction  [GATE 1: approve]
→ move in small steps, tests green throughout → code-review
→ commit refactor:  [GATE 2: confirm]
```
