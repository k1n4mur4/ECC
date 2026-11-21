---
name: godot-testing
description: Godot 4 の GDScript プロジェクトのテスト - 依存ゼロのヘッドレスチェックシーン、gdUnit4 と GUT のスイート、シーンランナーテスト、シグナルのアサーション、CI コマンド。Godot プロジェクトにテストを追加するとき、CI をセットアップするとき、変更によってゲームが壊れていないことを証明するときに使用します。
origin: ECC
---

# Godot 4 テスト

GDScript ゲームを層状にテストする方法です。ほとんどのチェックをウィンドウも人手も使わずに、ヘッドレスで数秒以内に実行できます。

## 有効化するタイミング

- Godot プロジェクトに最初のテストを追加するとき
- gdUnit4 または GUT のスイートを書く、またはレビューするとき
- CI やコミット前チェック用にヘッドレス実行をセットアップするとき
- プレイテスターにビルドを渡す前に「これはまだ動くか?」を確認したいとき

## ゲームのテストピラミッド

| 層 | チェックする内容 | ウィンドウが必要か | 速度 |
|-------|---------------|-----------------|-------|
| 1. ロジックテスト | `RefCounted` や `Resource` クラスにある純粋なルール（ダメージ計算、インベントリ、クラフト） | 不要 | ミリ秒 |
| 2. シーンテスト | シーンが読み込まれ、ノードが接続され、シグナルが発火し、数フレームが実行されること | 不要（通常） | 秒 |
| 3. プレイテスト | 操作感、バランス、面白さ | 必要（人間） | 分 |

テストの大半は層 1 で書きます。これはゲームのルールが Node の外にある場合にのみ成立します。`godot-patterns` を参照してください。

## オプション A: 依存ゼロのチェックシーン

アドオンは不要です。スクリプト付きのシーンがチェックを実行してプロセスの終了コードを設定するため、シェルや CI ジョブがそれを検知して失敗させられます。

```gdscript
# tests/verify_logic.gd。tests/verify_logic.tscn のルート Node にアタッチします
extends Node
## 小さなヘッドレステストランナー。次のコマンドで実行します:
##   godot --headless --path . res://tests/verify_logic.tscn

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	# 各 _test_* 関数は、関連するチェックのひとまとまりです。
	_test_inventory_clamps_to_stack()
	_test_health_never_negative()

	print("%d passed, %d failed" % [_passed, _failed])
	# 0 以外の終了コードが、実行の失敗を CI に伝えます。
	get_tree().quit(1 if _failed > 0 else 0)


## アサーションを 1 件記録し、失敗したときだけ 1 行出力します。
func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL: " + message)   # push_error はデバッガにも表示されます


func _test_inventory_clamps_to_stack() -> void:
	var inv := Inventory.new()
	var added: int = inv.add(&"wood", 150)
	_check(added == Inventory.MAX_STACK, "add() clamps to MAX_STACK")
	_check(inv.add(&"wood", 1) == 0, "a full stack accepts nothing more")


func _test_health_never_negative() -> void:
	var health := Health.new()          # Node なので、最後に自分で解放します
	health.damage(health.maximum + 50)
	_check(health.current == 0, "health floors at zero")
	health.free()
```

`godot -s script.gd` ではなくシーンを使う理由: シーンとして実行すると autoload が通常どおり読み込まれるため、それらを参照するコードが動作します。`--script` で起動したスクリプトはメインループとして動作するため、autoload の名前が解決できないことがあります。

長所: インストール不要で、小さく、読みやすいこと。制限: テストの自動検出、モック、見やすいレポートがないこと。手狭に感じたらオプション B に移行してください。

## オプション B: gdUnit4

フルーエントなアサーション、モック、シーンランナー、コマンドラインランナーを備えた、Godot に組み込んで使うフレームワークです。Godot Asset Library または GitHub リポジトリから `addons/gdUnit4` にインストールし、Project Settings > Plugins で有効にします。

### スイート

```gdscript
# tests/test_inventory.gd
extends GdUnitTestSuite
## gdUnit4 は名前が test_ で始まるメソッドを検出します。


func test_add_clamps_to_stack() -> void:
	var inv := Inventory.new()
	var added: int = inv.add(&"wood", 150)
	# フルーエントなアサーション: assert_int(actual).is_equal(expected)
	assert_int(added).is_equal(Inventory.MAX_STACK)


func test_add_emits_signal() -> void:
	var inv := Inventory.new()
	# monitor_signals を使うと、後でシグナルが発火したかどうかを確認できます。
	var monitor := monitor_signals(inv)
	inv.add(&"wood", 5)
	await assert_signal(inv).is_emitted("item_added", &"wood", 5)
```

### フィクスチャとクリーンアップ

- `before()` / `after()` はスイートごとに 1 回実行されます。`before_test()` / `after_test()` は各テストの前後で実行されます。
- 作成したものはすべて `auto_free(...)` で包むと、gdUnit4 がテスト後に解放するため、リークが発生しません。
- ノードをツリー内に置く必要がある場合は `add_child(auto_free(node))` を使います。

### シーンランナー（層 2）

```gdscript
func test_player_moves_right() -> void:
	# scene_runner はシーンを読み込み、プレイヤーが操作するように動かせます。
	var runner := scene_runner("res://scenes/main.tscn")
	runner.simulate_action_pressed(&"move_right")   # InputMap のアクション名を使用します
	await runner.simulate_frames(30)                # 30 フレーム経過させます
	var player := runner.find_child("Player") as Node2D
	assert_object(player).is_not_null()
	assert_float(player.position.x).is_greater(0.0)
```

### モック

```gdscript
func test_with_mock() -> void:
	var mock_node := mock(Node)     # 実際のメソッド名を持つ代役
	mock_node.get_name()
	verify(mock_node).get_name()    # ちょうど 1 回呼ばれたことをアサートします
```

自分で管理していない依存先（ネットワーククライアントやセーブシステムなど）はモックします。テスト対象のクラス自体はモックしないでください。

### コマンドラインからの実行

```powershell
# tests/ 内のすべてのスイートを実行します。Godot が PATH にない場合は、godot を Godot 実行ファイルのパスに置き換えてください。
godot --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests
```

- `-a <dir or file>` は実行するテストを追加します。`-i <suite>` は 1 つのスイートを無視します。`-c` は失敗後も続行します（デフォルトは最初の失敗で停止します）。
- gdUnit4 の CI ランナーは、ヘッドレスモードではシミュレートされた入力イベントが動作しないため、デフォルトではヘッドレスモードでの実行を拒否します。スイートが入力に依存しない場合は `--ignoreHeadlessMode` を追加してください。`simulate_*` を呼ぶスイートには、ディスプレイまたは仮想ディスプレイ（たとえば Linux CI での `xvfb`）が必要です。
- アドオンには、このコマンドをラップする `runtest.sh` と Windows 用の同等物が同梱されています。インストールしたバージョンで確認してください。

## オプション C: GUT

GUT（Godot Unit Test）は、もう 1 つの広く使われているアドオンです。

```gdscript
# test/unit/test_health.gd
extends GutTest   # GUT は test_ で始まるメソッドを検出します


func test_health_floors_at_zero() -> void:
	var health := autofree(Health.new())    # autofree = テスト後に解放されます
	health.damage(999)
	assert_eq(health.current, 0, "health floors at zero")
```

```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit
```

`-gexit` を指定すると、実行がステータスコード付きで終了します。フラグの綴りは GUT のバージョン間で変わる可能性があるため、`gut_cmdln.gd` を `-gh` 付きで実行して最新の一覧を確認してください。

## どれを選ぶか

| あなたの状況 | 選択 |
|-----------|------|
| 始めたばかりで小規模なプロジェクト | A（チェックシーン）から始め、必要になったら B/C に移行する |
| シーンランナーとモックが欲しい、GDScript と C# を使う | B（gdUnit4） |
| すでに GUT を使っている | C。2 つのフレームワークを混在させないこと |

## 低コストな安全チェック（最初に実行）

```powershell
# スクリプトを解析して終了します。ゲームを実行せずに構文エラーを検出します。
# 注意: ここでは autoload が登録されないため、autoload の名前を使うスクリプトは
# ゲームが問題なく動作する場合でも "Identifier not found" と報告します。
# 下の起動チェックが、信頼できるコンパイルテストです。
godot --headless --path . --check-only --script res://scripts/player.gd

# プロジェクトを起動してメインシーンを読み込み、数フレーム後に終了します。読み込み時のエラーを検出します。
godot --headless --path . --quit-after 5

# インポートキャッシュを再構築します（新規の CI チェックアウトでは、テストがアセットを読み込む前に必要です）。
godot --headless --path . --import
```

## CI の概要

```yaml
# .github/workflows/tests.yml（概要のみ。動作確認済みのバージョンを固定してください）
steps:
  - uses: actions/checkout@v4
  - name: Install Godot            # 好みの Godot セットアップ用アクションか、バージョンを固定したダウンロードを使用してください
    run: echo "install a pinned Godot build here"
  - name: Import assets
    run: godot --headless --path . --import
  - name: Run tests
    run: godot --headless --path . res://tests/verify_logic.tscn
```

CI を高速に保つため、実行間で `.godot/` インポートフォルダをキャッシュしてください。

## 落とし穴

| 落とし穴 | 対処 |
|---------|-----|
| テストがローカルでは通るが CI では失敗する | インポート手順が抜けています。最初に `--import` を実行してください。 |
| ヘッドレスで入力シミュレーションが効かない | ヘッドレスでは入力イベントが破棄されます。代わりにロジック層をテストするか、ディスプレイを使用してください。 |
| ノードのリークと孤立ノードの警告 | `auto_free`（gdUnit4）または `autofree`（GUT）を使うか、チェックシーンでは `free()` を使ってください。 |
| テストがフレームのタイミングに依存している | シグナルまたは `simulate_frames` を `await` し、固定の実時間スリープは使わないでください。 |
| テストが autoload を介して状態を共有している | `before_test()` で autoload をリセットするか、依存関係を注入してください。 |
| 巨大な 1 つのテスト | 1 テストにつき 1 つの振る舞いとし、その振る舞いにちなんだ名前を付けてください。 |
| ランダム性によってテストが不安定になる | `RandomNumberGenerator` にシードを設定し（`rng.seed = 12345`）、それを渡してください。 |

## 関連

- スキル: `godot-patterns` - 層 1 のテストが可能になるようにコードを構造化する
- スキル: `tdd-workflow` - レッド・グリーン・リファクタのループ
- エージェント: `tdd-guide` - テストファーストのガイダンス
- エージェント: `gdscript-reviewer` - レビューチェックリスト
