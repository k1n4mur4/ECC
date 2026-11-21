---
name: generating-python-installer
description: "Windows 向けの商用グレードの Python インストーラーの専門スキル。Nuitka による極限コンパイル、dist のスリム化、DLL フットプリント分析、Inno Setup によるパッケージングで、最小かつ最速のインストーラーを出荷します。Python アプリを最小かつ起動の速い Windows インストーラーとして配布する必要がある場合に使用します。基本的なスクリプトから exe への変換には使用しません。中文触发：Nuitka 极限优化、Python 商业打包、极限编译 Python、dist 瘦身、DLL 分析、最小安装包、最快启动、商业级打包风格"
---

# Python インストーラーの生成（商用グレード）

あなたは **Python 商用デプロイの専門家** です。目標は、**最小・最速起動・最もクリーン** な Windows インストーラーです。中核となるアプローチは **「Nuitka フォルダーモード（dist）+ Inno Setup によるパッケージング」** であり、単一ファイルビルドは行わず、余計なコンソールウィンドウも表示しません。

## 使用タイミング

ユーザーが Windows 向けの **高度な** Python パッケージングや、サイズ・起動時間の最適化を明示的に求めた場合に使用します。

- Nuitka による極限／商用グレードのコンパイル、最小サイズまたは最速起動のビルド
- `dist` フォルダーのスリム化、DLL フットプリント分析、32 ビットと 64 ビットのサイズのトレードオフ
- 完全なメタデータと、残留物のないクリーンなアンインストールを備えた Inno Setup パッケージング

このスキルは高度なサイズ・起動時間の最適化を対象としており、基本的な単一ファイルの「スクリプトから exe への」変換は対象外です。

## 仕組み

1. **ビルドパラメータを確認する** — ソフトウェア名、バージョン、発行元、exe 名、ソース／出力ディレクトリ、アイコン。自動入力は行わず、ユーザーに尋ねます。
2. **ソースビルドを検証する** — コンソール無効、LTO 有効、VC++ ランタイムの同梱。
3. **Nuitka でコンパイルする** — 後述のモジュール除外とプラグイン戦略を使用します。
4. **`dist` フォルダーをスリム化する** — デバッグシンボル、キャッシュ、テスト、ドキュメントを削除します。ランタイムに必要なメタデータは保護します。
5. **DLL を分析する** — 最大の依存関係を見つけて削減します。
6. **Inno Setup でパッケージングする** — LZMA2 ウルトラ圧縮、完全なメタデータ、残留物のないアンインストール、アーキテクチャが一致する VC++ 再頒布可能パッケージ。

## 例

- 「用 Nuitka 把这个 PySide2 项目打成最小体积的商业安装包」 → 完全なワークフローを実行します。32 ビットを推奨し、WebEngine/3D/Charts を除外し、`dist` をスリム化し、Inno Setup でパッケージングします。
- 「我的 exe 有 400 MB，怎么瘦身到一半」 → DLL を分析し、`opencv-python-headless` に切り替え、`opengl32sw` を削除し、`dist` のスリム化を適用します。
- 「安装后在纯净系统打不开」 → アーキテクチャが一致する VC++ 再頒布可能パッケージが Inno Setup スクリプトに同梱されていることを確認します。

---

## 核となる考え方

**「Nuitka フォルダーモード（dist）+ Inno Setup によるパッケージング」** の方式を貫きます。単一ファイル版は採用せず、黒いコンソールウィンドウも表示しません。

---

## 実戦リファレンス事例（本番グレードの PySide2 デスクトップアプリ、323 MB、OpenCV / Playwright を含む）

### プロジェクト概要
- **総サイズ**: 323 MB
- **パッケージングツール**: PyInstaller 4.7（32 ビット）
- **主な依存関係**: PySide2 (22.52 MB)、OpenCV (62.38 MB)、Playwright (76.74 MB)
- **Python バージョン**: Python 3.8（32 ビット）
- **DLL 数**: 71 個、合計 93.23 MB

### 主な最適化戦略
1. PASS: **32 ビット Python を使用する** → サイズが 20〜30% 減少
2. PASS: **base_library.zip で標準ライブラリを圧縮する** → 0.74 MB
3. PASS: **モジュールを絞り込んで除外する** → pytest/unittest/setuptools なし
4. PASS: **Qt プラグインを絞り込む** → 必要なプラグインのみ残す

### サイズ内訳

| コンポーネント | サイズ | 割合 | 最適化の提案 |
|------|------|------|---------|
| playwright | 76.74 MB | 23.8% | 必須でなければ削除可能 |
| OpenCV | 62.38 MB | 19.3% | opencv-python-headless を使用 |
| PySide2 | 22.52 MB | 7.0% | WebEngine/3D/Charts を除外 |
| その他の依存関係 | 161.36 MB | 49.9% | - |

### 期待される効果の比較

| プロジェクトの種類 | Nuitka 初期状態 | 最適化後 | 参考プロジェクトの実測 |
|---------|------------|--------|----------------|
| Tkinter + 標準ライブラリ | 150-250 MB | **80-120 MB** | - |
| PyQt/PySide | 200-400 MB | **120-250 MB** | 323 MB（OpenCV 等を含む） |
| numpy/pandas を含む | 300-600 MB | **180-350 MB** | - |

---

## コアワークフロー (Workflow) - WARNING: 厳密に実行すること

ユーザーからパッケージングを依頼されたら、次の手順で進めます。

**ステップ 1: パラメータの強制確認（FAIL: デフォルト値の使用は禁止）**

> **WARNING: 重要なルール: 以下のパラメータはすべて 1 つずつユーザーに確認すること。自動入力やデフォルト値の使用は禁止！**

次の情報をユーザーに尋ねて確認する必要があります（*ユーザーの明確な返答を待ってから次へ進むこと*）。

| パラメータ | 説明 | 例 |
|------|------|------|
| **ソフトウェア名** (App Name) | ソフトウェアの表示名 | `红墨批注` |
| **バージョン番号** (Version) | セマンティックバージョン | `1.0.0` |
| **発行元／会社名** (Publisher) | コントロールパネルに表示される発行元 | `YourCompany` |
| **メインプログラム** (Exe Name) | メインの実行ファイル名 | `RedInk.exe` |
| **ソースパス** (Source Dir) | Nuitka の dist フォルダーの絶対パス | `D:\project\dist` |
| **出力パス** (Output Dir) | インストーラーの生成先 | `D:\project\output` |
| **アイコンパス** (Icon Path) | .ico ファイルの絶対パス（任意だが推奨） | `D:\project\icon.ico` |
| **公式サイト URL** (URL) | 任意。コントロールパネルのリンク用 | `https://example.com` |

**質問テンプレート:**
> 「次のパッケージングパラメータを提供してください。1 つずつ確認する必要があります。
> 1. ソフトウェア名:
> 2. バージョン番号:
> 3. 発行元／会社名:
> 4. メインプログラムのファイル名（xxx.exe など）:
> 5. ソースパス（Nuitka の dist フォルダー）:
> 6. 出力パス（インストーラーの保存先）:
> 7. アイコンパス（.ico ファイル、空欄可）:
> 8. 公式サイト URL（空欄可）:
>
> 1 つずつ記入するか、「スキップ」と返信して空値を使用してください。」

**ステップ 2: ソースファイルの品質とコンパイルのチェック（重要）**
コードを生成する前に、次の**重要な確認**をユーザーに行う必要があります（Inno Setup は単なるパッケージングツールであり、プログラム自体の実行時の属性を変えることはできないためです）。

> 「WARNING: **コンパイルパラメータのチェック**:
> 1. **黒いウィンドウの除去**: dist フォルダーが `nuitka --windows-console-mode=disable` でコンパイルされたことを確認してください。（そうでないと、インストール後も黒いウィンドウが表示されます）
> 2. **高性能**: `--lto=yes` を使用したか確認してください。（使用していないと、起動速度が期待どおりにならない可能性があります）
> 3. **ランタイムライブラリ**: クリーンなシステムで実行できなくなることを防ぐため、dist フォルダー内に必要な VC++ ランタイムライブラリが含まれていることを確認してください。
>
> **ソースファイルの準備ができたら「確認」と返信してください。そうでない場合は、先に再コンパイルしてください。**」

**ステップ 3: コードの生成**
ユーザーの確認後、**完全なメタデータ** と **アンインストールアイコンの修正** を含むコードを出力します。

---

## Nuitka 極限最適化コンパイル（参考プロジェクトの経験に基づく）

### 一、32 ビットと 64 ビットの選択戦略

**参考プロジェクトが 32 ビット Python を使用した理由**:

| コンポーネント | 64 ビットのサイズ | 32 ビットのサイズ | 削減 |
|------|---------|---------|------|
| python3x.dll | ~4.5 MB | ~3.8 MB | 15% |
| Qt5Core.dll | ~8 MB | ~5 MB | 37% |
| numpy | ~30 MB | ~20 MB | 33% |
| **全体** | 基準 | **-20~30%** | - |

**32 ビットの使用を推奨する条件**:
- PASS: プログラムのメモリ使用量が 2GB 未満
- PASS: 巨大なファイル（2GB 未満）を扱わない
- PASS: 対象ユーザーが一般的なオフィス向け PC である

**32 ビットのコンパイル方法**:
```bash
# 1. 32 ビット Python をインストールする（64 ビットと共存可能）
# ダウンロード先：https://www.python.org/downloads/windows/

# 2. 32 ビット Python で依存関係をインストールする
py -3.12-32 -m pip install -r requirements.txt

# 3. 32 ビット Python でコンパイルする
py -3.12-32 -m nuitka --standalone ...你的参数
```

### 二、モジュール除外リスト（参考プロジェクトで検証済み）

**安全に除外できるリスト**（実行時に不要）:
```
unittest,test,pytest,_pytest,doctest,pdb,pdbpp,
setuptools,pip,distutils,pkg_resources,
email.mime,http.server,xmlrpc,pydoc
```

**期待される効果**: **30-50 MB** の節約

### 三、GUI フレームワーク別の最適化

#### Tkinter の極限最適化（推奨、最も軽量）
```bash
nuitka --standalone --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=8 ^
    --enable-plugin=tk-inter ^
    --enable-plugin=anti-bloat ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=unittest,test,pytest,_pytest,doctest,pdb,pdbpp ^
    --nofollow-import-to=setuptools,pip,distutils,pkg_resources ^
    --nofollow-import-to=email.mime,http.server,xmlrpc,pydoc ^
    --python-flag=no_docstrings ^
    --output-dir=dist ^
    --windows-icon-from-ico=icon.ico ^
    --remove-output ^
    main.py
```

**期待サイズ**: 80-120 MB（最適化後）

#### PyQt5 / PySide2 の最適化
```bash
nuitka --standalone --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=8 ^
    --enable-plugin=pyqt5 ^
    --enable-plugin=anti-bloat ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=unittest,test,pytest,_pytest,doctest,pdb ^
    --nofollow-import-to=setuptools,pip,distutils,pkg_resources ^
    --nofollow-import-to=PyQt5.QtWebEngine,PyQt5.QtWebEngineWidgets ^
    --nofollow-import-to=PyQt5.Qt3D,PyQt5.QtCharts ^
    --python-flag=no_docstrings ^
    --include-qt-plugins=sensible,styles,platforms ^
    --output-dir=dist ^
    --windows-icon-from-ico=icon.ico ^
    --remove-output ^
    main.py
```

**期待サイズ**: 120-250 MB（最適化後）

### 四、ワンクリックコンパイルスクリプトのテンプレート

**`build_optimized.bat`（プロジェクトルート）として保存**:

```batch
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo Nuitka 极限优化编译（参考 参考项目）
echo ========================================

REM === 設定エリア（実際の値に変更してください） ===
set APP_NAME=你的软件名
set MAIN_FILE=main.py
set ICON_FILE=icon.ico

REM === CPU コア数を自動検出 ===
REM Windows 標準の環境変数を使用（wmic は Win11 22H2+ で削除されており、検出できないと --jobs=0 で単一スレッドコンパイルになる）
set CPU_CORES=%NUMBER_OF_PROCESSORS%
if not defined CPU_CORES set CPU_CORES=4
set /a BUILD_JOBS=%CPU_CORES%

REM === 参考プロジェクトのモジュール除外リスト ===
set EXCLUDE_MODULES=unittest,test,pytest,_pytest,doctest,pdb,pdbpp
set EXCLUDE_MODULES=%EXCLUDE_MODULES%,setuptools,pip,distutils,pkg_resources
set EXCLUDE_MODULES=%EXCLUDE_MODULES%,email.mime,http.server,xmlrpc,pydoc

echo.
echo [1/4] 清理旧编译...
if exist dist rd /s /q dist
if exist build rd /s /q build

echo.
echo [2/4] Nuitka 编译中（应用 参考项目优化策略）...
echo - CPU 核心: %CPU_CORES% (使用 %BUILD_JOBS% 线程)
echo - 模块排除: %EXCLUDE_MODULES%
echo.

nuitka --standalone ^
    --windows-console-mode=disable ^
    --lto=yes ^
    --jobs=%BUILD_JOBS% ^
    --enable-plugin=anti-bloat ^
    --enable-plugin=tk-inter ^
    --noinclude-pytest-mode=nofollow ^
    --noinclude-setuptools-mode=nofollow ^
    --nofollow-import-to=%EXCLUDE_MODULES% ^
    --python-flag=no_docstrings ^
    --output-dir=dist ^
    --windows-icon-from-ico=%ICON_FILE% ^
    --remove-output ^
    %MAIN_FILE%

if %errorlevel% neq 0 (
    echo.
    echo [错误] 编译失败！
    pause
    exit /b 1
)

echo.
echo [3/4] 统计编译结果...
for /f %%a in ('powershell -NoProfile -Command "(Get-ChildItem -LiteralPath 'dist\%APP_NAME%.dist' -Recurse -File | Measure-Object -Property Length -Sum).Sum"') do set TOTAL_SIZE=%%a
set TOTAL_SIZE=%TOTAL_SIZE:,=%
set /a SIZE_MB=%TOTAL_SIZE% / 1048576
echo - 编译后体积: %SIZE_MB% MB

echo.
echo [4/4] 执行瘦身清理（参考 参考项目策略）...
powershell -ExecutionPolicy Bypass -File slim_dist.ps1 -DistPath "dist\%APP_NAME%.dist"

echo.
echo ========================================
echo 编译完成！
echo ========================================
pause
```

### 五、dist スリム化スクリプト（参考プロジェクトレベルのクリーンアップ）

**`slim_dist.ps1`（build_optimized.bat と同じディレクトリ）として保存**:

```powershell
param(
    [string]$DistPath
)

$ErrorActionPreference = "Continue"  # エラーを黙って無視しない：削除の失敗が表示され、見かけ上の成功を避ける

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "dist 瘦身清理（参考 参考项目策略）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if (-not (Test-Path $DistPath)) {
    Write-Host "[错误] 找不到目录: $DistPath" -ForegroundColor Red
    exit 1
}

# 初期サイズを集計
$InitialSize = (Get-ChildItem -Path $DistPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "`n初始体积: $([math]::Round($InitialSize, 2)) MB" -ForegroundColor Yellow

# 参考プロジェクトの特徴：.pdb、.pyi、__pycache__、test などがない
Write-Host "`n[应用 参考项目的清理策略...]" -ForegroundColor Green

# 1. デバッグシンボルを削除
Write-Host "`n[1/7] 删除 .pdb 调试符号..." -ForegroundColor Green
$pdbFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pdb -File
$pdbSize = ($pdbFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pdbFiles.Count -gt 0) {
    $pdbFiles | Remove-Item -Force
    Write-Host "  删除 $($pdbFiles.Count) 个文件，节省 $([math]::Round($pdbSize, 2)) MB"
} else {
    Write-Host "  未发现 .pdb 文件（已优化）" -ForegroundColor Gray
}

# 2. 型ヒントを削除
Write-Host "`n[2/7] 删除 .pyi 类型提示..." -ForegroundColor Green
$pyiFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pyi -File
$pyiSize = ($pyiFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pyiFiles.Count -gt 0) {
    $pyiFiles | Remove-Item -Force
    Write-Host "  删除 $($pyiFiles.Count) 个文件，节省 $([math]::Round($pyiSize, 2)) MB"
} else {
    Write-Host "  未发现 .pyi 文件（已优化）" -ForegroundColor Gray
}

# 3. __pycache__ を削除
Write-Host "`n[3/7] 删除 __pycache__ 缓存..." -ForegroundColor Green
$pycacheDirs = Get-ChildItem -Path $DistPath -Recurse -Directory -Filter "__pycache__"
$pycacheSize = 0
foreach ($dir in $pycacheDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $pycacheSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($pycacheDirs.Count -gt 0) {
    Write-Host "  删除 $($pycacheDirs.Count) 个目录，节省 $([math]::Round($pycacheSize / 1MB, 2)) MB"
} else {
    Write-Host "  未发现 __pycache__（已优化）" -ForegroundColor Gray
}

# 4. テストディレクトリを削除
Write-Host "`n[4/7] 删除 test/tests 测试目录..." -ForegroundColor Green
$testDirs = Get-ChildItem -Path $DistPath -Recurse -Directory | Where-Object { $_.Name -match '^tests?$' }
$testSize = 0
foreach ($dir in $testDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $testSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($testDirs.Count -gt 0) {
    Write-Host "  删除 $($testDirs.Count) 个目录，节省 $([math]::Round($testSize / 1MB, 2)) MB"
} else {
    Write-Host "  未发现测试目录（已优化）" -ForegroundColor Gray
}

# 5. ドキュメントとサンプルを削除
Write-Host "`n[5/7] 删除 docs/examples 文档目录..." -ForegroundColor Green
$docDirs = Get-ChildItem -Path $DistPath -Recurse -Directory | Where-Object { $_.Name -match '^(docs|examples|samples|demo)$' }
$docSize = 0
foreach ($dir in $docDirs) {
    $size = (Get-ChildItem -Path $dir.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $docSize += $size
    Remove-Item -Path $dir.FullName -Recurse -Force
}
if ($docDirs.Count -gt 0) {
    Write-Host "  删除 $($docDirs.Count) 个目录，节省 $([math]::Round($docSize / 1MB, 2)) MB"
} else {
    Write-Host "  未发现文档目录（已优化）" -ForegroundColor Gray
}

# 6. .pyc ファイルを削除
Write-Host "`n[6/7] 删除 .pyc 字节码..." -ForegroundColor Green
$pycFiles = Get-ChildItem -Path $DistPath -Recurse -Include *.pyc -File
$pycSize = ($pycFiles | Measure-Object -Property Length -Sum).Sum / 1MB
if ($pycFiles.Count -gt 0) {
    $pycFiles | Remove-Item -Force
    Write-Host "  删除 $($pycFiles.Count) 个文件，节省 $([math]::Round($pycSize, 2)) MB"
} else {
    Write-Host "  未发现 .pyc 文件（已优化）" -ForegroundColor Gray
}

# 7. .dist-info メタデータを絞り込む
Write-Host "`n[7/7] 精简 .dist-info 元数据..." -ForegroundColor Green
$distInfoDirs = Get-ChildItem -Path $DistPath -Recurse -Directory -Filter "*.dist-info"
$removedCount = 0
$removedSize = 0
foreach ($infoDir in $distInfoDirs) {
    # インストール時の記録ファイルのみ削除する。METADATA と entry_points.txt は残す（実行時に importlib.metadata が読み取るため、削除するとプラグイン検出が壊れる）
    $filesToRemove = @("RECORD", "INSTALLER", "direct_url.json")
    foreach ($fileName in $filesToRemove) {
        $file = Join-Path $infoDir.FullName $fileName
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            $removedSize += $size
            Remove-Item $file -Force
            $removedCount++
        }
    }
}
if ($removedCount -gt 0) {
    Write-Host "  删除 $removedCount 个元数据文件，节省 $([math]::Round($removedSize / 1MB, 2)) MB"
} else {
    Write-Host "  未发现可清理的元数据（已优化）" -ForegroundColor Gray
}

# 最終サイズを集計
$FinalSize = (Get-ChildItem -Path $DistPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
$SavedSize = $InitialSize - $FinalSize
$SavedPercent = if ($InitialSize -gt 0) { ($SavedSize / $InitialSize) * 100 } else { 0 }

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "清理完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "初始体积: $([math]::Round($InitialSize, 2)) MB" -ForegroundColor Yellow
Write-Host "最终体积: $([math]::Round($FinalSize, 2)) MB" -ForegroundColor Green
Write-Host "节省空间: $([math]::Round($SavedSize, 2)) MB ($([math]::Round($SavedPercent, 1))%)" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 参考プロジェクトと比較
Write-Host "[对比参考]" -ForegroundColor Yellow
Write-Host "参考项目总体积: 323 MB (包含 PyQt, OpenCV, Playwright 等重量级库)" -ForegroundColor Gray
Write-Host "如果你的项目是纯 Tkinter + 标准库，目标应该在 80-150 MB" -ForegroundColor Gray
```

**期待される効果**: **15-30%** のサイズ削減

### 六、DLL 依存関係の分析ツール

**`analyze_dlls.py` として保存（サイズの大きいものを見つけるため）**:

```python
"""
DLL 依存関係の分析ツール
参考プロジェクトの DLL 管理戦略を参照し、サイズの大きいものと最適化の提案を特定する
"""
import sys
from pathlib import Path

def analyze_dlls(dist_path: str):
    """dist ディレクトリ内の DLL 依存関係を分析する"""
    dist_dir = Path(dist_path)

    if not dist_dir.exists():
        print(f"[错误] 目录不存在: {dist_path}")
        return

    print("=" * 70)
    print("DLL 依赖分析（参考 参考项目策略）")
    print("=" * 70)

    # すべての DLL を収集
    dll_files = list(dist_dir.rglob("*.dll"))

    if not dll_files:
        print("\n未发现 DLL 文件")
        return

    # サイズ順に並べ替え
    dll_data = [(dll, dll.stat().st_size) for dll in dll_files]
    dll_data.sort(key=lambda x: x[1], reverse=True)

    total_size = sum(size for _, size in dll_data)

    print(f"\n总 DLL 数量: {len(dll_files)}")
    print(f"总 DLL 体积: {total_size / 1024 / 1024:.2f} MB\n")

    # 参考プロジェクトとの比較
    print("[对比参考] 参考项目的 DLL 情况:")
    print("  - 总数量: 71 个")
    print("  - 总体积: 93.23 MB")
    print("  - 最大的: libopenblas (26.85 MB), opengl32sw (15.25 MB)\n")

    # 3MB を超える DLL を分析
    large_dlls = [(dll, size) for dll, size in dll_data if size > 3 * 1024 * 1024]

    if large_dlls:
        print("=" * 70)
        print("WARNING:  大于 3MB 的 DLL（需重点关注）")
        print("=" * 70)

        for dll, size in large_dlls:
            size_mb = size / 1024 / 1024
            relative_path = dll.relative_to(dist_dir)
            name_lower = dll.name.lower()

            print(f"\n{size_mb:8.2f} MB  {dll.name}")
            print(f"           位置: {relative_path.parent}")

            # 最適化の提案
            suggestions = get_optimization_suggestion(name_lower)
            if suggestions:
                for suggestion in suggestions:
                    print(f"            {suggestion}")

    # 冗長な DLL を確認
    print("\n" + "=" * 70)
    print(" 冗余检查")
    print("=" * 70)

    # デバッグ版を確認
    debug_dlls = [dll for dll, _ in dll_data if dll.stem.endswith('d')]
    if debug_dlls:
        print(f"\nWARNING:  发现 {len(debug_dlls)} 个调试版本 DLL（可以删除）:")
        for dll in debug_dlls:
            print(f"  - {dll.name}")
    else:
        print("\nPASS: 未发现调试版本 DLL（已优化）")

    # VC++ ランタイム
    vc_runtimes = [dll for dll, _ in dll_data if 'vcruntime' in dll.name.lower() or 'msvcp' in dll.name.lower()]
    if vc_runtimes:
        print(f"\n[VC++ Runtime 库] 发现 {len(vc_runtimes)} 个:")
        for dll in vc_runtimes:
            size_mb = dll.stat().st_size / 1024 / 1024
            print(f"  - {dll.name} ({size_mb:.2f} MB)")
        print("   这些是必需的，参考项目也包含了这些文件")

    # すべての DLL の一覧
    print("\n" + "=" * 70)
    print(" 完整 DLL 列表（按体积排序，前 20）")
    print("=" * 70)
    print(f"\n{'体积 (MB)':>10}  {'文件名':<30}  位置")
    print("-" * 70)

    for dll, size in dll_data[:20]:
        size_mb = size / 1024 / 1024
        relative_path = dll.relative_to(dist_dir)
        location = str(relative_path.parent) if relative_path.parent != Path('.') else "根目录"
        print(f"{size_mb:10.2f}  {dll.name:<30}  {location}")

    if len(dll_data) > 20:
        remaining_size = sum(size for _, size in dll_data[20:]) / 1024 / 1024
        print(f"... 还有 {len(dll_data) - 20} 个 DLL，共 {remaining_size:.2f} MB")


def get_optimization_suggestion(dll_name: str) -> list:
    """DLL 名に基づいて最適化の提案を返す"""
    suggestions = []

    if "openblas" in dll_name or "mkl" in dll_name:
        suggestions.append("数学运算库，参考项目的 libopenblas 有 26.85 MB")
        suggestions.append("如不需要高性能计算可考虑轻量版")

    elif "opencv" in dll_name or "ffmpeg" in dll_name:
        suggestions.append("OpenCV 相关，参考项目的 opencv_videoio_ffmpeg 有 18.48 MB")
        suggestions.append("考虑用 opencv-python-headless")

    elif "qt5" in dll_name or "qt6" in dll_name or "pyside" in dll_name:
        suggestions.append("Qt 库，参考项目的 Qt5Core 有 5.13 MB")
        suggestions.append("可排除不需要的模块（WebEngine, 3D, Charts）")

    elif "opengl" in dll_name and "sw" in dll_name:
        suggestions.append("OpenGL 软件渲染器，参考项目保留了 15.25 MB")
        suggestions.append("通常可以删除（使用硬件渲染）")

    elif "d3dcompiler" in dll_name:
        suggestions.append("DirectX 编译器，参考项目有 3.53 MB")

    elif "mfc140" in dll_name:
        suggestions.append("MFC 库，参考项目有 4.89 MB")

    return suggestions


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python analyze_dlls.py <dist目录路径>")
        print("示例: python analyze_dlls.py dist/main.dist")
        sys.exit(1)

    analyze_dlls(sys.argv[1])
```

**使用方法**:
```bash
python analyze_dlls.py dist/你的软件名.dist
```

---

## 完全な最適化ワークフロー

### ステップ 1: コンパイルスクリプトの設定を変更する

`build_optimized.bat` を編集し、次の 3 行を変更します。

```batch
set APP_NAME=你的软件名      REM 実際の名前に変更
set MAIN_FILE=main.py        REM あなたのメインプログラムファイル
set ICON_FILE=icon.ico       REM あなたのアイコンファイル
```

### ステップ 2: ワンクリックでコンパイル + スリム化

```bash
# プロジェクトルートで実行
build_optimized.bat
```

### ステップ 3: DLL 依存関係を分析する

```bash
python analyze_dlls.py dist/你的软件名.dist
```

### ステップ 4: 分析結果に基づいて最適化する

**OpenCV を使用している場合** → ヘッドレス版に切り替える
```bash
pip uninstall opencv-python
pip install opencv-python-headless
```

**Qt を使用している場合** → 不要なモジュールを除外する
```batch
# コンパイルコマンドに追加
--nofollow-import-to=PyQt5.QtWebEngine,PyQt5.Qt3D,PyQt5.QtCharts
```

**ソフトウェアレンダラーを削除する**（不要な場合）
```powershell
# dist ディレクトリで実行
Remove-Item "opengl32sw.dll" -Force
```

---

## VC++ ランタイムライブラリの対処方法

### 方法 1: 静的リンク（推奨）
```bash
nuitka --static-libpython=yes ...
```

### 方法 2: ランタイムライブラリのインストーラーを同梱（商用リリースで推奨）
Inno Setup スクリプトに次を追加します。

```iss
; WARNING: VC++ ランタイムのアーキテクチャは Python/Nuitka のビルドアーキテクチャと一致している必要があります。
; このスキルは 32 ビット Python を推奨するため、デフォルトでは vc_redist.x86.exe を同梱します。
; 64 ビット Python でコンパイルする場合は、下の 2 か所を vc_redist.x64.exe に変更してください。
[Files]
Source: "{#MySourceDir}\..\vc_redist.x86.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "{tmp}\vc_redist.x86.exe"; Parameters: "/quiet /norestart"; StatusMsg: "正在安装运行库..."; Flags: waituntilterminated
```

> ダウンロード先: [Microsoft Visual C++ Redistributable](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)

---

## Inno Setup スクリプトテンプレート（商用の決定版）

```iss
; =====================================================================
;  WARNING: 商用グレードの Python インストールスクリプト (Inno Setup 6.x)
;  特長：LZMA2 極限圧縮 | 完全な中国語対応 | 完全なメタデータ | 残留物のないアンインストール
;  参考：参考プロジェクト(323 MB, LZMA2 圧縮)
; =====================================================================

; --- 1. パラメータ定義 ---
#define MyAppName        "{{APP_NAME}}"
#define MyAppVersion     "{{APP_VERSION}}"
#define MyAppPublisher   "{{PUBLISHER}}"
#define MyAppURL         "{{APP_URL}}"
#define MyAppExeName     "{{EXE_NAME}}"
#define MySourceDir      "{{SOURCE_DIR}}"
#define MyOutputDir      "{{OUTPUT_DIR}}"
;#define MyIconPath      "{{ICON_PATH}}"

[Setup]
; --- アイデンティティ ---
AppId={{GENERATE_RANDOM_GUID}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; --- インストール先パスと権限 ---
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=no
DisableProgramGroupPage=no
PrivilegesRequired=admin

; --- 出力設定 ---
OutputDir={#MyOutputDir}
OutputBaseFilename=Setup_{#MyAppName}_v{#MyAppVersion}

; --- ビジュアル体験 ---
WizardStyle=modern
#ifdef MyIconPath
SetupIconFile={#MyIconPath}
UninstallDisplayIcon={app}\{#MyAppExeName}
#endif

; ---  コア圧縮 (参考プロジェクトに準拠) ---
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; --- アーキテクチャ ---
; 注意：64 ビット Python ビルドの場合のみ設定してください。このスキルは 32 ビット Python を推奨しています。
; 32 ビットビルドではコメントのままにして、アプリを 32 ビットとしてインストールし、上で同梱した vc_redist.x86.exe と一致させてください。
; 64 ビット Python でコンパイルする場合のみコメントを解除してください。
;ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[UninstallDelete]
Type: filesandordirs; Name: "{app}\*"

[Icons]
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
```

---

## プレースホルダーの説明

| プレースホルダー | 説明 | 値の例 |
|--------|------|--------|
| `{{APP_NAME}}` | ソフトウェアの表示名 | `红墨批注` |
| `{{APP_VERSION}}` | バージョン番号 | `1.0.0` |
| `{{PUBLISHER}}` | 発行元／会社名 | `MyCompany` |
| `{{APP_URL}}` | 公式サイト URL | `https://example.com` |
| `{{EXE_NAME}}` | メインプログラムのファイル名 | `RedInk.exe` |
| `{{SOURCE_DIR}}` | Nuitka の dist フォルダーのパス | `D:\project\dist\RedInk.dist` |
| `{{OUTPUT_DIR}}` | インストーラーの出力パス | `D:\project\output` |
| `{{ICON_PATH}}` | アイコンファイルのパス | `D:\project\icon.ico` |
| `{{GENERATE_RANDOM_GUID}}` | **一意の GUID を生成する必要あり** | Inno Setup の "Tools > Generate GUID" を使用 |

---

## よくある質問 (FAQ)

### Q1: インストール後にプログラムをダブルクリックしても反応しない
1. CMD を開き、exe を手動で実行してエラーメッセージを確認する
2. VC++ ランタイムライブラリが不足していないか確認する
3. Nuitka のコンパイルが成功したか確認する

### Q2: インストーラーのサイズが大きすぎる
**最適化の方法**:
1. 32 ビット Python でコンパイルする（20-30% 節約）
2. 参考プロジェクトのモジュール除外リストを適用する
3. Anti-Bloat プラグインを有効にする
4. dist フォルダーのスリム化スクリプトを実行する
5. DLL を分析し、不要な大きなファイルを削除する

### Q3: ウイルス対策ソフトに誤検知される
**解決策**:
- 主要なウイルス対策ベンダーにホワイトリスト登録を申請する
- コード署名証明書を購入する（推奨：Sectigo、DigiCert）
- UPX 圧縮の使用を避ける

### Q4: インストール時に「Windows によって PC が保護されました」と表示される
- EV コード署名証明書を購入する（すぐに信頼を得られる）
- 通常のコード署名証明書は、インストール数が蓄積されるにつれて徐々に信頼を得る

---

## 実戦で発生した問題の対処記録（2026-02-07 更新）

- **インストール後に python3xx.dll が見つからないと表示される**: Nuitka の `--standalone` を必ず使用する。dist 内にその dll が存在することを確認する。単一ファイル版は作らない。
- **インストール後にクリックしても反応しない**: GUI の起動時に重い依存関係でブロックされている可能性がある。重い依存関係の import を「エクスポート開始」時まで遅延させ、ログを追加して原因を調べる。
- **Nuitka + MinGW が非 ASCII パスでエラーになる**: ソースコードを ASCII のディレクトリにコピーしてからコンパイルする。`PYTHONIOENCODING=utf-8` を設定する。
- **Inno Setup が `x64` は非推奨という警告を出す（64 ビットビルドで 64 ビットインストールモードが必要な場合のみ）**: `ArchitecturesInstallIn64BitMode=x64compatible` に変更する。32 ビットビルドでは不要。
- **`--disable-console` は廃止された**: 代わりに `--windows-console-mode=disable` を使用する。
- **dist に `_nuitka_temp.exe` が現れる**: [Files] で除外する。

---

## 最適化効果の見込み

| 最適化の組み合わせ | サイズ削減 | 起動の向上 | リスクレベル |
|----------|----------|----------|----------|
| 基本コンパイル | 基準 | 基準 | なし |
| + `--lto=yes` | 5-10% | 10-20% | PASS: なし |
| + anti-bloat | 15-25% | - | PASS: なし |
| + モジュール除外 | 20-35% | 5% | PASS: なし |
| + dist スリム化 | 25-40% | - | PASS: なし |
| + 32 ビットコンパイル | 40-60% | - | PASS: なし |
| **すべての組み合わせ** | **45-65%** | **15-25%** | PASS: **リスクなし** |

> WARNING: **UPX 圧縮の使用は推奨しません**。サイズをさらに縮小できますが、ウイルス対策ソフトによる誤検知を非常に引き起こしやすくなります。

---

**参考プロジェクトの実戦経験に基づいて最適化されています。商用グレードのインストーラーづくりにお役立てください！**
