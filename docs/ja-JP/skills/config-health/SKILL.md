---
name: config-health
description: Claude Code の実行時設定の整合性を監視します。起動時に設定ドリフト、ルールの陳腐化、フック配線の欠落を検出し、ツールごとのモードも任意で利用できます。起動時のソフト監視により delivery-gate を補完します。
metadata:
  origin: ECC
---

# Config Health

リアルタイム監視レイヤーです。delivery-gate はセッション終了時にブロックしますが、config-health はセッション中、つまり修正コストが低いうちに問題を検出します。

## 有効化するタイミング

- delivery-gate を導入した後、多層防御を実現したいとき
- フックが何も言わずに発火しなくなったとき
- 設定ルールが増え続け、どれがまだ機能しているか分からないとき
- セッション開始時に設定の整合性をスキャンするとき
- 高リスクな Edit/Write 操作の前に任意で実行するとき。これはオプトインであり、デフォルトではありません

## 仕組み

Session Start → config-health がルールとフックをスキャンします（ソフト警告のみで、ブロックはしません）
Session Work → 任意の PreToolUse ガード。自分で配線した場合のみ動作します
Session End → delivery-gate が検証します（ハードブロック、exit 2）

境界線は「後から修正できるか？」です。設定ドリフトなら config-health が警告します。growth-log の欠落なら delivery-gate がブロックします（ハード exit 2）。

## 監視対象

1. フック配線の監査: フックコマンドが参照するすべてのスクリプトをディスク上
   で確認します。デフォルトではセッション開始時に実行されます。任意の
   PreToolUse モードでは、一致した Edit/Write 呼び出しごとに実行することも
   できますが、このモードはデフォルトの配線には含まれず、繰り返しコストを
   許容する場合を除き推奨されません。
2. ルールの健全性: `CLAUDE.md` から参照されているすべての `rules/*.md` が存在すること。
3. ガードの陳腐化: `rule-health.jsonl` に記録された直近 5 セッションで発火カウンタがゼロだったルール。
   直近 5 件の*レコード*を取得し、そこから判定できる程度に複雑なものに絞り込むため、
   判定にはレコードが合計で最低 5 件必要です。

デフォルトの配線は SessionStart のみです。PreToolUse はオプトインモードとして
利用できますが、デフォルトでは推奨されません。一致するすべての Edit と Write
に対してこのスクリプトを新しいプロセスで毎回パースすることになり、ツール固有の
根拠が増えるわけでもないためです。[PreToolUse のコスト](#pretooluse-のコストオプトイン)を参照してください。

## フックのパス

フックコマンドは、パスを確認する前にシェルと同じ方法で分割されます。そのため、
通常のプラグインインストールですべてのフックが欠落として報告されることはありません。

- `~/.claude/scripts/x.py`、`$HOME/scripts/x.py`、`${USERPROFILE}/…` は
  ユーザーホームを基準に解決されます。
- `${CLAUDE_PLUGIN_ROOT}/…` と `${CLAUDE_PROJECT_DIR}/…` は展開されます。
- 相対パス（`.claude/scripts/x.py`、`scripts/hooks/x.js`）は、プロジェクトディレクトリ、
  ユーザーホーム、プラグインルートの**すべて**を基準に解決されます。フックコマンドは
  どこから実行されるかを示さないためです。3 つすべてで見つからない場合にのみ報告されます。
- 引用符で囲まれた語は 1 つの引数として扱われるため、
  `python3 "C:\Program Files\ecc\guard.py"` は空白で分割されず、引用符内の
  `;` `|` `&` は区切り文字ではなく名前の一部として扱われます。シェルの引用規則に
  対する意図的な例外が 1 つあります。バックスラッシュがエスケープするのは空白、
  引用符、シェルメタ文字のみで、別のバックスラッシュ、`$`、バッククォートは
  エスケープしません。そのため `C:\Users\me\guard.py`、`\\server\share\x.py`、
  `C:\$Recycle.Bin\x.py` はそのまま保たれます。POSIX のエスケープ処理では、
  これらは存在しないパスに壊れてしまいます。
- インタプリターのプログラム本体はスクリプトパスではなく、2 種類は異なる扱いを受けます。
  `sh -c "python3 x.py"` はコマンドラインなので、再度コマンドとしてスキャンされます。
  `-c`、`-lc`、`--command` はいずれも対象で、間にオプションがあっても
  （`bash -x -c`、`bash -o pipefail -c`）本体が孤立することはありません。
  `node -e` や `python -c` の本体は別の言語のソースであり、文字列は単なる文字列です。
  `p.join(r,'scripts/hooks/x.js')` は実行時に組み立てられ、何かが開くファイルではない
  ため、スキップされます。したがって JS 本体の*内部*で指定された欠落ファイルは
  報告されません。モニターはパスと文字列を区別できないためです。

**報告されずにスキップされる**もの: このモニターが解決しないプレースホルダを含むトークン、
展開結果が監査対象ルートの外を指すプレースホルダ、シングルクォートで囲まれた
プレースホルダ（シェルは展開しません）、`sh -c` ペイロード内を含め閉じられていない
引用符を持つコマンド、3 段を超えてネストされた `sh -c` チェーンです。

`--check` は判定されなかったものを出力します。誰にも見えない盲点はヘルスチェックとは言えないからです。

| `N hook path(s) not audited` | モニターが判定しないプレースホルダやパス、およびパースできなかったコマンド |
| `N hook command(s) have an unclosed quote` | 閉じられない引用符を持つコマンド。設計判断ではなくタイプミス |
| `N hook command(s) nested sh -c deeper than 3 levels` | モニターが追跡をやめたネスト。コマンドの残りは監査済み |
| `N interpreter program body/bodies were skipped unjudged` | `node -e` / `python -c` の本体。内部で指定されたファイルは別言語の文字列であり、確認できない |
| `N settings file(s) could not be read` | **info ではなく警告**: 不正な形式の設定ファイルは、内容が結果を左右する唯一の入力であり、監査されなかった |
| `N relative hook path(s) were satisfied by the user home or plugin root` | マルチルートのトレードオフ: 本当に壊れているプロジェクトスコープのフックも、ここでは健全なプラグインのフックと同じに見える |
| `$CLAUDE_PLUGIN_ROOT resolved to …` | 判定に使われたルート |

健全な ECC インストールでは、最後の 2 行が注目すべき行です。実際の環境では
検出 0 件、スキップされたプログラム本体 23 件、プラグインルートによって
満たされた相対パス 17 件と報告されます。

## 環境変数の入力

検出結果は、プロセス環境ではなく、設定ファイルとこれらの変数の関数です。

| 変数 | 効果 |
|----------|--------|
| `CONFIG_HEALTH_USER_HOME` | ユーザーホーム。`~` と `$HOME` の解決先でもある |
| `CLAUDE_CONFIG_DIR` | Claude のデータルート。ユーザー設定と rule-health ログの場所。デフォルトは `~/.claude` |
| `CLAUDE_PROJECT_DIR` | プロジェクトディレクトリ |
| `CONFIG_HEALTH_PLUGIN_ROOT` | プラグインルートを固定する |
| `CLAUDE_PLUGIN_ROOT` | プラグインルート。`CONFIG_HEALTH_PLUGIN_ROOT` が優先される |

ランチャーが `CLAUDE_CONFIG_DIR` を設定している場合、`~/.claude/settings.json` は
Claude が読み込むファイルではありません。モニターは代わりに
`$CLAUDE_CONFIG_DIR/settings.json` を読み取り、`--check` は解決したルートを出力します。

**複数のプラグインをインストールしている場合は？** プロバイダーは、*実行中の*プラグインの
ルートを `CLAUDE_PLUGIN_ROOT` に設定するため、2 つ目のプラグイン向けに配線された設定行は
誤ったディレクトリに対して判定されます。1 つの変数で 2 つのプラグインを表すことはできないため、
その場合は `CONFIG_HEALTH_PLUGIN_ROOT` を明示的に設定してください。

**スタンドアロンインストールの場合は？** エントリポイントと**その 3 つのヘルパーモジュール**
（`config_health_constants.py`、`config_health_paths.py`、`config_health_scan.py`）を
`config-health.py` と同じディレクトリにコピーしてください。エントリポイントはこれらを名前で
インポートします。これにより、環境にプラグインルートが存在しない場所に配置されることになります。
その結果として次の 2 点が生じます。どちらも無視せず対処する価値があります。

- `${CLAUDE_PLUGIN_ROOT}/…` 行は解決できなくなりスキップされます。これは
  検証ではなく沈黙です。
- プラグインルートは、相対パスの確認対象ディレクトリではなくなります。そのため
  **ECC 自身の `scripts/hooks/x.js` 参照がプロジェクトとホームに対して判定され、
  このリポジトリの 23 個のフックで 17 件の検出が発生します。** これらの検出は
  ノイズではありません。モニターがプラグインを見られないことを正しく報告している
  のです。

これらのフックを対象にしたい場合は、フックの `env` ブロックに
`CONFIG_HEALTH_PLUGIN_ROOT` を設定するか、`~` や `$HOME` でそれらのフックを配線してください。

## PreToolUse のコスト（オプトイン）

`--pretool` はオプトインです。配線した場合、一致したツール呼び出しごとに（通常は
すべての Edit とすべての Write で）新しいプロセスで 1 回実行され、そのたびに監査が
走ります。「このスクリプトは存在するか」は、これから実行される呼び出しではなく設定
ファイルの性質であるため、ツールごとのフックにはツール固有の根拠が追加されません。

このリポジトリの**実際の 23 個のフックコマンド**で、Windows 上の Python 3.12 を使い、
スケジューラーのドリフトを相殺するために A/B を交互に実行し、30 回のペア実行の中央値を
測定しました。

| | 変更前 | 変更後 |
|---|---|---|
| 配線監査そのもの（プロセス内） | 4.33 ms | **3.83 ms** |
| このスクリプトのパースとコンパイル（`__main__` スクリプトはバイトキャッシュされない） | 1.06 ms | 3.00 ms |
| `--pretool` プロセス全体の中央値 | 50.6 ms | 54.7 ms |
| `python -c pass`（参考） | 42.1 ms | 42.1 ms |

逆方向を指す 2 点を分けて考える価値があります。

- **監査は安くなりました。** プレースホルダの展開、シェルのようなコマンド分割、
  相対パスごとに 3 つのルートの確認と、厳密にはより多くの作業を行うようになった
  にもかかわらず、4.33 ms から 3.83 ms になりました。旧バージョンは、存在する
  ファイルに関する 55 件の検出を生成することに時間を費やしており、そのたびに
  `stat` と整形された文字列が必要でした。
- **スクリプトが大きくなり、それがコストのすべてです。** `__main__` として実行される
  スクリプトは `.pyc` にバイトキャッシュされないため、10.7 KB から 42 KB への増加は、
  呼び出しのたびに +1.9 ms のパースとコンパイルになります。

結論: **約 55 ms のフック呼び出しに対して +4.1 ms、約 8%** であり、正確に言えば、原因は
監査ではなくスクリプトサイズです。すべての docstring を削除してもコンパイルで
回復するのは 0.15 ms にすぎないため、原因は文章ではなくコードです。

これが、デフォルトの配線で `--startup` のみを維持している理由です。監査は一致した
ツール呼び出しごとではなくセッションごとに 1 回実行され、パースのコストもそれに
伴って減ります。一致する呼び出しごとのチェックに約 8% の価値がある場合にのみ
オプトインしてください。

フックのペイロードは読み捨てられ、パースも出力もされません。そのサイズが判定結果を
変えることはありません。ハングしたフックを制限するのは、読み取りではなくフック配線の
`timeout` です。

## 例

欠落したフックスクリプト:
`hook "PreToolUse" references missing script: .claude/scripts/ghost.py` → 設定ファイルが
存在しないファイルを指しています。終了コードは 0 のままです。

存在しないルールへの参照:
`CLAUDE.md references missing rule file: rules/ghost.md` → exit 0。

ルールの陳腐化:
`rule "双池强制触发" has not fired in the last 5 sessions → may be dead` — ウィンドウは
直近 5 件の複雑なセッションであり、任意の数だけ遡ったセッションではありません。
このウィンドウ内に 0 を超えるカウントが 1 つでもあればルールは生きていると見なされ、
短いセッションでも同様です。カウントが 0 を超えているのは、ルールが発火したことを意味します。

健全なプラグインインストール:
プラグインがインストールされている状態での
`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/guard.py"` → 検出なし。`guard.py` が
プラグインに本当に存在しない場合 → 検出 1 件、終了コードは 0 のまま。**ただし、
モニター自身の環境に `CLAUDE_PLUGIN_ROOT`（または `CONFIG_HEALTH_PLUGIN_ROOT`）が設定されている場合に限ります。**
設定されていなければ、トークンは解決不能であり、どちらの場合も検出はありません。

このモニターが読み取るもの: フックが配線された設定ファイル（ユーザーディレクトリの
`settings.json`、プロジェクトディレクトリの `settings.json`、プロジェクトディレクトリの
`.claude/settings.local.json`）、`CLAUDE_PLUGIN_ROOT`（または `CONFIG_HEALTH_PLUGIN_ROOT`）が
設定されている場合はプラグイン自身の `hooks/hooks.json`、（プロジェクトディレクトリの）
`CLAUDE.md`、そして `$CLAUDE_CONFIG_DIR/session-data/rule-health.jsonl`
（デフォルトは `~/.claude/session-data/rule-health.jsonl`）です。参照を見つけるために
ドキュメントを読むことはなく、スクリプトが何か所に配線されているかを数えることもありません。

## インストール

**ECC ユーザー:** フックに関する明示的な判断とともに `config-health` モジュールをインストールします。デフォルトの SessionStart 配線なら `npx ecc-universal install --modules config-health --enable-hooks`、またはフック同意付きの `full` プロファイルを使用します。インストーラーは、`--enable-hooks` または `--no-hooks` なしではフックを同梱するモジュールの適用を拒否します。これは **Claude 専用**のモジュールであり、PreToolUse はオプトインです。他のハーネスを対象としないため、共有の 13 ハーネス向けモジュールからは分離されたままです。

このモジュールは独自のフック設定（`manifests/install-assets/config-health-hooks.json`）を同梱しており、インストール時に `${CLAUDE_PLUGIN_ROOT}` をインストールルートに置換して `settings.json` にマージされます。そのため、ホームへのインストールでは `~/.claude/scripts/config-health.py` を、プロジェクトへのインストールでは `<project>/.claude/scripts/config-health.py` を指します。このマージは設定の書き込みであるため、フック同意によって制御されます。

- `npx ecc-universal install --modules config-health --enable-hooks` は SessionStart フックを配線します。
- `npx ecc-universal install --modules config-health --no-hooks` はスクリプトとスキルのみをインストールします。`settings.json` には何も書き込まれず、以下の JSON を参考に自分で配線します。

アンインストールすると、ファイルとともにフックエントリも削除されます。

**スタンドアロン:** `scripts/config-health.py` と 3 つのヘルパーモジュール
（`config_health_constants.py`、`config_health_paths.py`、`config_health_scan.py`）を
`${CLAUDE_CONFIG_DIR:-~/.claude}/scripts/` にコピーし、有効化する前にエントリポイントが
存在することを確認してください。ヘルパーはエントリポイントと同じディレクトリに置く
必要があります。ランチャーが `CLAUDE_CONFIG_DIR` を設定している場合は、フックコマンドで
そのパスを使用してください。その構成では `~/.claude` は Claude が読み込むファイルでは
ありません。

**重要:** これらのフックエントリは既存の `hooks` オブジェクトにマージしてください。置き換えると delivery-gate などのフックが失われます。

デフォルト（SessionStart のみ）:

```json
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "python3 ~/.claude/scripts/config-health.py --startup", "timeout": 60}]}]
  }
}
```

任意のツールごとのモード（オプトイン。一致するすべての Edit と Write で新しいプロセスが
追加されます。デフォルトでは推奨されません）:

```json
{
  "hooks": {
    "PreToolUse": [{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "python3 ~/.claude/scripts/config-health.py --pretool", "timeout": 60}]}]
  }
}
```

## 設計原則

1. プロセスの監視でブロックしない — config-health は警告し、delivery-gate がブロックする
2. delivery-gate が確認できないものを確認する — ファイルシステムの状態ではなく設定の挙動
3. あらゆる判断を沈黙の側に倒し、判断しなかったものを数える。このモニターが構築できない
   パスは「欠落」ではなく「不明」です。相対パスは、監査対象のすべてのルートで欠落している
   場合にのみ報告されます。この非対称性は意図的です。沈黙のコストは見逃されるチェック
   1 件ですが、誤警告のコストは、このフックが出力する他のすべての行に対するユーザーの
   信頼です。
4. 確認しなかったことを伝える。`--check` はスキップ、パース不能、クロスルートの件数を
   出力するため、盲点を想定のままにせず、見つけて修正できます。

## ファイル

| ファイル | 目的 | フック |
|------|---------|------|
| scripts/config-health.py | CLI エントリ: startup、pre-tool、check | SessionStart、PreToolUse はオプトイン |
| scripts/config_health_constants.py | 定数、正規表現、監査セット | — |
| scripts/config_health_paths.py | パス解決と防御的な読み取り | — |
| scripts/config_health_scan.py | シェルコマンドのトークン化とスキャン | — |
