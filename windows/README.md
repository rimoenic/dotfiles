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
| `winget/fonts.json` | フォント（`winget-font` ソース） | `install_fav_tools.ps1 -ManifestPath fonts.json` |

フォントを別ファイルにしているのは `SourceDetails` が他と異なり同居させられないため。
`winget-font` は検索時に `-s winget-font` の明示指定が要るソース（`winget source list`
の「明示的」列が true）だが、import は宣言の `SourceDetails` でソースを直接指すため
この制約を受けない。

`winget export` の生出力（`winget/winget_pkgs*.json`）は環境依存の実導入リストなので
リポジトリには含めない（`.gitignore` 済み）。手元で棚卸ししたいときに書き出す。

```powershell
winget export -o .\winget\winget_pkgs.json
```

`-ManifestPath` はファイル名だけでも渡せる（`winget/` から解決される）。

4 ファイルの宣言は計 76 件で、重複はない。実際に導入しているもののうち、
依存ランタイムなど宣言していないものについては「宣言していないもの」を参照。

`setup.ps1` からは呼ばない。数が多く重いため、必要なときだけ明示的に叩く。

### winget configure に移行していない理由

`winget configure`（DSC ベース）は import/export より新しい宣言的管理で、パッケージ
だけでなくソース登録や OS 設定まで 1 ファイルで扱える。移行を検討したが、**速度が
見合わないため見送った。**

`winget configure test` での照合は実測で 67 パッケージ 約 175 秒、Source 3 件を
含む 79 リソースで **約 17 分**かかる。`winget list` との照合は数秒で終わるため、
日常的に差分を確認する用途には重すぎる。

判定の正確さでは configure が勝る（表をパースしないため）。ただし `winget list` 側の
誤判定は原因が分かって解消済みなので、精度を理由に乗り換える必要はなくなった。

`winget/all-packages.configure.winget` を精査済みの宣言として置いてあるが、
**現状の運用では使っていない**。初回セットアップや、将来 winget 側が速くなった
ときの土台として保管している。生成元の `winget configure export --all` の出力は
環境依存の情報（PowerShell プロファイルのパス、OS の外観設定、依存ランタイム、
機種依存パッケージ）を含むため、そのままでは使えない。

調査の詳細は Obsidian の `50_Knowledge/Windows/winget configure.md` を参照。

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
| `Microsoft.Sysinternals.Ctrl2Cap` | Ctrl と Caps Lock を入れ替えられないキーボード（下記） |

#### Ctrl2Cap

Caps Lock を Ctrl として使うためのリマッパ。
キーボード側（ハード/ファームウェア）で入れ替えられるならそちらを使う。
ノート PC の内蔵キーボードのように、それができないマシンでだけ入れる。

v3.0 でドライバ方式をやめ、レジストリの Scancode Map 方式になった
（v2.x の `.sys` を登録する版とは別物。zip に `.sys` は入っていない）。
書き込み先は次の 1 箇所だけで、Caps Lock (0x3A) を左 Ctrl (0x1D) に割り当てる。

```
HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout  →  Scancode Map
```

winget で入るのは実行ファイルだけで、**それだけでは効かない**。
HKLM 配下のため書き込みに管理者権限が要り、反映にはサインアウトが要る
（Scancode Map の読み込みがログオン時のため。ドライバ方式と違い再起動までは不要）。

```powershell
# 管理者の PowerShell で
ctrl2cap /install
# サインアウト（または再起動）で有効になる

# 既に別のキーへ割り当て済みの場合は上書きしない。上書きするなら /force
ctrl2cap /install /force

# やめるとき
ctrl2cap /uninstall
```

現在の状態はレジストリを直接見れば分かる。値が無ければ未設定。

```powershell
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout').'Scancode Map'
```

Scancode Map は Ctrl2Cap 専用の値ではなく、キーリマップ全体で共有する 1 つの値。
そのため Ctrl2Cap を入れずに手で同じ値を書いても等価で、逆に他のリマップ設定と
競合しうる。`ctrl2cap /uninstall` は値ごと消すので、他の割り当ても一緒に失われる。

`setup.ps1` からは行わない。管理者権限とサインアウトが要るうえ、
入れるかどうかがマシンの判断になるため、手作業に残す。

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
  fonts.json                       フォント（winget-font ソース）
  all-packages.configure.winget    winget configure 形式の宣言（保管のみ。運用では未使用）
  winget_pkgs*.json                winget export の生出力（gitignore）
  all.configure.winget             winget configure export --all の生出力（gitignore）
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
