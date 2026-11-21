---
name: orch-add-feature
description: 完全に新しい機能を、調査・計画・TDD 実装・レビュー・ゲート付きコミットまで一貫してオーケストレーションし、各フェーズを対応する ECC エージェントに委譲します。まだ存在しない機能を追加するときに使用します。
metadata:
  origin: ECC
---

# orch-add-feature

アクター · アクション · 対象: **orch · add · feature**。[`orch-pipeline`](../orch-pipeline/SKILL.md) の共有エンジンを薄くラップしたものです。

## 使用するタイミング

- ユーザーが**まだ存在しない**機能を求めているとき（「追加して」「構築して」「実装して」「〜をサポートして」など）。
- 新規の振る舞いであり、修正（`orch-fix-defect`）でも、既存の振る舞いの変更（`orch-change-feature`）でもない場合。

## オペレーション設定

- **デフォルトのサイズ下限:** standard — 明らかに小規模でない限り、調査 + 計画を実行します。
- **フェーズマスク:** 0 → 1 → 2 → 4 → 5 → 6（3 Scaffold はスキップします。これは MVP 専用です）。
- **最初の一手（フェーズ 4）:** 新しい振る舞いに対する*新規の*失敗するテストを書き、グリーンになるまで実装します。

## 仕組み

1. 上記の設定で `orch-pipeline` エンジンを実行します。
2. 最初にサイズを分類します。小規模・些細な機能は 4 → 5 → 6 に集約されます。
3. **Gate 1**（計画の承認）と **Gate 2**（コミット前）で停止します。
4. 機能がセキュリティ上のトリガーに触れる場合は `security-reviewer` を追加します。

> 関連: `/feature-dev` はこのフローのスタンドアロン版です。`orch-add-feature` との違いは `orch-pipeline` エンジン（サイズ分類器と 2 つのゲート）をファミリー内の他のスキルと共有している点で、これにより些細な機能を 4 → 5 → 6 に適正サイズ化します。

## 例

```
orch-add-feature: add OAuth2 login to nws-poller
→ research existing auth libs → plan task_list  [GATE 1: approve]
→ TDD each task → code-review (+ security-reviewer: auth path)
→ commit  [GATE 2: confirm]
```
