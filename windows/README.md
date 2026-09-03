# windows/

Windows 側の設定とパッケージ宣言。

## セットアップ

素の Windows 11 から始める場合は [doc/bootstrap.ps1](../doc/bootstrap.ps1) を実行する。
WSL 導入 → PowerShell 7 → `setup.ps1` → WSL 内で `installer.sh`、までを通す。

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

## パッケージ宣言

winget 公式の import 形式で宣言し、`winget install` を直に叩かない運用にしている。
バージョンは固定しない（`--ignore-versions` で常に最新を入れる）。

宣言ファイルは `winget/` に集約している。

| ファイル | 内容 | 導入方法 |
|---|---|---|
| `winget/fav_tools.json` | 常用ツール（どのマシンでも入れる） | `install_fav_tools.ps1` |
| `winget/machine_dependent.json` | マシン依存（機種・周辺機器。マシンごとに取捨選択） | `install_fav_tools.ps1 -ManifestPath machine_dependent.json` |
| `winget/optional_tools.json` | 任意。必要なときだけ入れるもの | `install_fav_tools.ps1 -ManifestPath optional_tools.json` |

`winget export` の生出力（`winget/winget_pkgs*.json`）は環境依存の実導入リストなので
リポジトリには含めない（`.gitignore` 済み）。手元で棚卸ししたいときに書き出す。

```powershell
winget export -o .\winget\winget_pkgs.json
```

`-ManifestPath` はファイル名だけでも渡せる（`winget/` から解決される）。

3 ファイルの宣言は計 70 件で、重複はない。実際に導入しているもののうち、
依存ランタイムなど宣言していないものについては「宣言していないもの」を参照。

`setup.ps1` からは呼ばない。数が多く重いため、必要なときだけ明示的に叩く。

```powershell
# 何が入るか確認するだけ（何も導入しない）
.\install_fav_tools.ps1 -WhatIf

# 未導入のものを導入
.\install_fav_tools.ps1

# 導入済みも最新へ更新
.\install_fav_tools.ps1 -Upgrade

# マシン依存のものを導入
.\install_fav_tools.ps1 -ManifestPath machine_dependent.json -WhatIf

# 任意のものを導入
.\install_fav_tools.ps1 -ManifestPath optional_tools.json -WhatIf
```

### machine_dependent.json の内訳

マシンを買い替えたら、そのマシンに要るものだけ残して編集する。

| パッケージ | 対象 |
|---|---|
| `Lenovo.SystemUpdate` | Lenovo 製 PC のドライバ更新 |
| `Lenovo.UpdateRetriever` | 同上（更新パッケージの取得） |
| `Dell.DisplayAndPeripheralManager` | Dell 製ディスプレイ・周辺機器 |
| `Intel.IntelExtremeTuningUtility` | Intel CPU のチューニング |
| `Logitech.UnifyingSoftware` | Logicool Unifying レシーバー |

### optional_tools.json の内訳

常用ではないが、必要になったら入れるもの。

| パッケージ | 備考 |
|---|---|
| `Microsoft.WinDbg` | デバッガ。要否は場合による |
| `Oracle.VirtualBox` | WSL2 / Hyper-V との共存に注意が要る。要否は場合による |

### 宣言していないもの

実際には導入しているが、どの宣言ファイルにも入れていないもの。
（`winget export` すると現れる）

- **WSL 関連** — `Microsoft.WSL` / `Canonical.Ubuntu.2404`。
  `bootstrap.ps1` が `wsl --install` で扱う。winget の `Microsoft.WSL` は
  アプリ本体だけでオプション機能を有効化しないため、そちらでは代用できない。
- **依存ランタイム** — `Microsoft.VCRedist.*` / `Microsoft.UI.Xaml.*` /
  `Microsoft.WindowsAppRuntime.*` / `Microsoft.DotNet.*` / `Microsoft.VCLibs.*`。
  他のパッケージが必要に応じて自動で引くため、明示すると管理対象が無駄に増える。
  export に出てくるのは「入っている」だけで、「意図して入れた」ものではない。

### かつて入れていたが宣言しないもの

以前は導入していたが、現在は入れていないもの。いずれも宣言しない。
同じ判断を繰り返さないよう理由を残す。

| パッケージ | 宣言しない理由 |
|---|---|
| `Microsoft.Edge` | Windows に最初から入っているため明示しない |
| `Microsoft.OneDrive` | 同上 |
| `Microsoft.Outlook` | 同上 |
| `Microsoft.AppInstaller` | winget 自身。winget では入れられない |
| `Microsoft.VisualStudioCode.Insiders` | 不安定版の利用をやめた |
| `Canonical.Ubuntu.2204` | WSL ディストロ。新環境に古い版は入れない |
| `CubeSoft.CubePDF` | PDF 系が重複していたため整理 |
| `boostio.boostnote` | 脱却予定のため明示では入れない |
| `Apple.Bonjour` | 明示的に入れた覚えがない（何かの付随インストール） |
| `Lenovo.QuickClean` | 同上 |

## ファイル構成

```
bootstrap は doc/ 側にある

setup.ps1                        Windows 側の設定（SSH鍵・clone・WT・profile）
install_fav_tools.ps1            パッケージ一括導入
winget/                          パッケージ宣言（winget import 形式）
  fav_tools.json                   常用ツール
  machine_dependent.json           マシン依存（機種・周辺機器）
  optional_tools.json              任意（必要なときだけ入れる）
  winget_pkgs*.json                winget export の生出力（gitignore）
Microsoft.PowerShell_profile.ps1 profile ローダー（$PROFILE にコピーされる）
powershell/                      profile 本体（ローダーから直接参照される）
WindowsTerminal/settings.json    Windows Terminal 設定
wsl/.wslconfig.example           .wslconfig の雛形
```

## スクリプト編集時の注意

`.ps1` は **UTF-8 BOM 付き**で保存すること。日本語コメントを含む状態で BOM を
落とすと、Windows PowerShell 5.1 が Shift-JIS と誤読し、マルチバイト文字が
後続の括弧を壊してパースエラーになる。

また、素の Windows 11 に入っているのは 5.1 だけなので、PowerShell 7 固有の
構文（`&&` / `??` / `?:` / `-AsHashtable` 等）は使わない。
