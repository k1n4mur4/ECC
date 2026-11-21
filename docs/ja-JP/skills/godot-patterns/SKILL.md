---
name: godot-patterns
description: Godot 4 GDScript の慣用パターン - 静的型付け、シーンとノードの設計、シグナル、リソース、オートロード、入力、ライフサイクルの安全性。GDScript の作成やレビュー、シーン設計、ゲーム状態の置き場所を決める際に使用します。
origin: ECC
---

# Godot 4 GDScript パターン

GDScript で書かれた Godot 4.x プロジェクト向けの慣用パターンです。Godot 4.7 のドキュメントに照らして検証していますが、ほとんどの内容はすべての 4.x リリースに当てはまります。

## 有効化するタイミング

- `.gd` ファイルを書く、またはレビューするとき
- シーンツリーを設計する、またはどのノードが何を所有するかを決めるとき
- シグナル、直接呼び出し、オートロード、Resource のどれを使うか選ぶとき
- 「node not found」、解放済みオブジェクト、シグナル接続のエラーをデバッグするとき
- レンダラーを起動せずにロジックをテストできるようゲームを構成するとき

## コア原則

1. **すべてに型を付ける。** 型付き GDScript はパース時にバグを検出し、エディタも高速化します。
2. **下へ呼び出し、上へシグナル。** 親は子のメソッドを呼び出せます。子はシグナルでイベントを通知し、親を直接参照しません。
3. **可能な限りゲームロジックを Node の外に置く。** 素の `RefCounted` や `Resource` クラスはヘッドレスでテストできます。Node は描画と入力の転送を担当させます。
4. **データは定数だらけのスクリプトではなく Resource に置く。**
5. **オートロードはグローバル状態です。** できるだけ少なくし、それぞれを公開 API として扱います。

## 静的型付け

```gdscript
class_name Inventory
extends RefCounted
## アイテム数の入れ物。純粋なデータとルールのみで Node を含まないため、テストをヘッドレスで実行できる。

signal item_added(item_id: StringName, new_count: int)  ## 型付きシグナルパラメータ

const MAX_STACK: int = 99           ## 型付き定数

var _counts: Dictionary[StringName, int] = {}  ## 型付き Dictionary（Godot 4.4 以降）


## アイテムを `amount` 個追加し、実際に追加できた個数を返す。
func add(item_id: StringName, amount: int) -> int:
	var current: int = _counts.get(item_id, 0)
	var added: int = mini(amount, MAX_STACK - current)   # スタック上限に収める
	if added <= 0:
		return 0
	_counts[item_id] = current + added
	item_added.emit(item_id, _counts[item_id])           # emit_signal() ではなく Signal.emit()
	return added
```

経験則:

- パラメータと戻り値の型を注釈する（`-> void` も含む）。
- 右辺から型が明らかな場合は `:=` を使い、そうでない場合は明示的な型を使う。
- 型付き配列（`Array[Enemy]`）を使い、4.4 以降では型付き辞書も使う。
- 頻繁に比較される ID やキーには `StringName` リテラル（`&"player"`）を使う。
- `as` でキャストし、使用前に結果が `null` でないか確認する。

## ファイル構成と命名

| 対象 | 規約 | 例 |
|------|------|----|
| ファイルとフォルダ | `snake_case` | `player_controller.gd` |
| クラス（`class_name`） | `PascalCase` | `PlayerController` |
| 関数、変数 | `snake_case` | `take_damage()` |
| プライベートメンバー | 先頭に `_` | `_speed` |
| 定数、enum の値 | `CONSTANT_CASE` | `MAX_LIVES` |
| シグナル | 過去形の `snake_case` | `health_changed` |

スクリプト内の順序（公式スタイルガイドより）: `class_name`、`extends`、ドキュメントコメント、シグナル、enum、定数、`@export` 変数、パブリック変数、プライベート変数、`@onready` 変数、そしてメソッド。組み込みコールバック（`_init`、`_ready`、`_process`）は独自メソッドより前に置きます。

## シーンとノードの設計

### 下へ呼び出し、上へシグナル

```gdscript
class_name Player
extends CharacterBody2D
## プレイヤーは子の Health を所有し、そのシグナルを待ち受ける。Health は Player について何も知らない。

@onready var _health: Health = %Health        # %Name = シーン内で一意なノード。親が変わっても壊れない


func _ready() -> void:
	# 子のシグナルを介してツリーの上方向へ通知を受け取る（子から親への通信）。
	_health.died.connect(_on_died)


func _on_died() -> void:
	queue_free()                               # 死の意味は親が決める
```

```gdscript
class_name Health
extends Node
## 再利用可能なコンポーネント。イベントを発行するだけで、親には決して触れない。

signal died
signal changed(current: int, maximum: int)

@export var maximum: int = 10                  # インスペクターでシーンごとに調整可能

var current: int = maximum


func damage(amount: int) -> void:
	current = maxi(current - amount, 0)
	changed.emit(current, maximum)
	if current == 0:
		died.emit()
```

### ハードコードしたパスを使わない兄弟ノードの接続

`get_node("../../UI/Label")` は避けてください。ツリーが変わるたびに壊れます。次の順に検討してください。

1. 同じシーン内のノードには `%UniqueName` を使う。
2. インスペクターで割り当てる `@export var target: Node` を使う。
3. 共通の祖先が接続するシグナルを使う。
4. 「ある種類のすべて」を取得するクエリにはグループ（`add_to_group("enemies")`、`get_tree().get_nodes_in_group("enemies")`）を使う。

## シグナル

- `Callable` で接続する: `button.pressed.connect(_on_pressed)`。
- 一度だけ反応させる場合は `CONNECT_ONE_SHOT` を使う。
- 破棄時には切断するか `queue_free()` する。解放済みオブジェクトへの接続は自動的にクリーンアップされる。ただし、長寿命の発行元が、まだ生きている短寿命オブジェクトの Callable を保持していると、そのオブジェクトはシグナルに反応し続ける。
- 追加の引数は `.bind()` で束縛する: `slot.pressed.connect(_on_slot.bind(slot_index))`。
- フレームごとの頻繁なデータにシグナルを使わない。値を直接読み取る。

## データのための Resource

```gdscript
class_name WeaponData
extends Resource
## デザイナーが編集できる武器のステータスを .tres ファイルとして保存する。小さなヘルパー以外のロジックは持たない。

@export var display_name: String = ""
@export var damage: int = 1
@export var cooldown_seconds: float = 0.5
@export var icon: Texture2D


## 毎秒ダメージ。導出値にすることで二重に保存されず、ずれることもない。
func dps() -> float:
	return damage / cooldown_seconds
```

- 読み取り専用データは 1 つの `.tres` を共有する。インスタンスごとに変更する前には `duplicate()` を呼び出す。さもないと、そのファイルを使うすべてが一緒に変わる。
- セーブデータにも Resource を使えるが、信頼できないパスから `.tres` や `.res` を読み込んではいけない。Resource にはスクリプトを埋め込めるためである。ユーザーが提供するセーブには JSON か `ConfigFile` を使う。

## オートロード（シングルトン）

適した用途: イベントバス、設定、シーン遷移マネージャー、セーブシステム。
不適切な用途: レベルごとの状態を保持し、リスタート時にリセットされるべきもの。

```gdscript
# events.gd、Project Settings > Globals > Autoload に "Events" として登録
extends Node
## 小さなグローバルイベントバス。シーンをまたぐイベントだけに限定する。

signal player_died
signal score_changed(new_score: int)
```

各オートロード名を公開 API として扱ってください。ドキュメント化し、ゲームプレイのコードがそのプライベートフィールドに直接アクセスしないようにします。

## プロセスコールバックとタイミング

| コールバック | 用途 |
|--------------|------|
| `_physics_process(delta)` | 移動、物理、物理ティックに結び付くすべて |
| `_process(delta)` | ビジュアル、UI、補間 |
| `_input(event)` / `_unhandled_input(event)` | 個別の入力イベント。ゲームプレイには `_unhandled_input` を優先し、UI が先にイベントを消費できるようにする |

```gdscript
func _physics_process(delta: float) -> void:
	# Input.get_vector は 4 つの名前付きアクションを読み取り、正規化された 2D 方向を返す。
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * speed          # speed は毎秒あたりの単位なので、ここでは delta は不要
	move_and_slide()                      # move_and_slide() は内部で delta を適用する
```

- フレームごとに加算するもの（`position += velocity * delta`）は `delta` でスケールするが、`move_and_slide()` ではスケールしない。
- 入力はハードコードしたキーではなく、プロジェクト設定の InputMap アクションとして定義する。これによりリバインドやゲームパッドが機能する。
- 短い遅延には `await get_tree().create_timer(1.0).timeout` を使う。停止や再開が必要な場合は `Timer` ノードを使う。
- アイドル状態のノードは `set_process(false)` で処理を止める。

## ライフサイクルの安全性

```gdscript
# BAD: タイマーが発火する前に enemy が解放されている可能性がある。
await get_tree().create_timer(2.0).timeout
enemy.take_damage(5)

# GOOD: await のたびに、参照がまだ有効か確認する。
await get_tree().create_timer(2.0).timeout
if is_instance_valid(enemy):
	enemy.take_damage(5)
```

- `free()` ではなく `queue_free()` を使い、ノードがフレーム内の安全なタイミングで削除されるようにする。
- `@onready` 変数はノードがツリーに入った後でのみ有効。`_init` では決して読み取らない。
- `remove_child()` で取り除いたノードは解放されない。自分で解放しないとリークする。
- 存在しないパスへの `get_node()` は実行時にエラーになる。存在しないことが正当な場合は `get_node_or_null()` を使う。

## アンチパターン

| アンチパターン | 問題点 | 代わりに |
|----------------|--------|----------|
| すべて型なし | バグが実行時に発覚し、オートコンプリートも弱い | 型を注釈する |
| 2,000 行の `main.gd` 1 つ | テスト不能、マージ競合 | コンポーネントと `RefCounted` のロジッククラスに分割する |
| 子が `get_parent().foo()` を呼ぶ | 隠れた結合があり、再利用すると壊れる | シグナルを発行する |
| 深い `get_node("../../..")` パス | ツリーの変更で壊れる | `%Unique` 名、export、グループ |
| スクリプト内のマジックナンバー | 調整にコード変更が必要 | `@export` または `Resource` |
| 共有 Resource の変更 | すべてのインスタンスが変わる | 先に `duplicate()` する |
| オートロード内のゲームプレイ | リスタートをまたいで状態が漏れる | シーンが所有するノードにし、ロード時にリセットする |
| `KEY_*` のハードコードチェック | リバインドやゲームパッドが使えない | InputMap アクション |

## 関連項目

- スキル: 上記パターンのヘッドレステスト用の `godot-testing`
- エージェント: レビューチェックリスト用の `gdscript-reviewer`
- スキル: Python から来た場合に最も近い、型付きで snake_case のイディオムを持つ `python-patterns`
