# fav-tool（常用パッケージ）の一括導入
#
# 実行方法:
#   powershell -ExecutionPolicy Bypass -File .\install_fav_tools.ps1
#   pwsh -File .\install_fav_tools.ps1 -WhatIf     # 何が入るかだけ確認
#
# setup.ps1 からは呼ばない。60 パッケージ超あって重く、環境構築のたびに
# 全部入れたいわけではないため、必要なときだけ明示的に叩く。
#
# 日本語コメントを含むため UTF-8 BOM 付きで保存すること。BOM を落とすと
# Windows PowerShell 5.1 が Shift-JIS と誤読してパースエラーになる。

[CmdletBinding()]
param(
    # 導入するパッケージの宣言。winget 公式の import 形式。
    # 既定値をここで組み立てない。5.1 では param ブロック評価時に $PSScriptRoot が
    # 空文字のため、Join-Path が失敗する。解決は param ブロックの後で行う。
    [string]$ManifestPath,

    # 導入済みパッケージも最新へ更新する。既定では触らない。
    [switch]$Upgrade,

    # 実際には導入せず、未導入のものを一覧するだけ。
    [switch]$WhatIf
)

Set-StrictMode -Version Latest

# 'Stop' にしない。winget は正常系でも stderr に書くため、'Stop' だと
# 成功しているのに終了エラーとして落ちる。失敗判定は $LASTEXITCODE で行う。
$ErrorActionPreference = 'Continue'

# StrictMode 下では未設定の $LASTEXITCODE を読むだけで例外になる。
$global:LASTEXITCODE = 0

# $PSScriptRoot はここで初めて使える（param ブロック内では空）。
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$manifestDir = Join-Path $scriptDir 'winget'

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $manifestDir 'fav_tools.json'
} elseif (-not (Test-Path $ManifestPath)) {
    # ファイル名だけ渡された場合も受け付ける（-ManifestPath machine_dependent.json）。
    # 宣言ファイルは winget/ に集約してあるため、そこからの解決を試みる。
    $candidate = Join-Path $manifestDir $ManifestPath
    if (Test-Path $candidate) { $ManifestPath = $candidate }
}

#region ---------- ヘルパ ----------

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Skip { param([string]$Message) Write-Host "    $Message" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

function Get-ManifestPackageId {
    param([string]$Path)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    $ids = @()
    foreach ($source in $json.Sources) {
        foreach ($pkg in $source.Packages) {
            if ($pkg.PackageIdentifier) { $ids += $pkg.PackageIdentifier }
        }
    }
    # カンマを外さない。1 件だけの宣言（fonts.json 等）では配列が文字列に
    # 展開され、StrictMode 下で呼び出し側の .Count が例外になる。
    return ,$ids
}

# winget-font ソースを含む宣言かどうか。
#
# フォントは winget list での ID が FONT\User\<ID> となり、宣言の <ID> と
# そのままでは一致しない。照合時に前置を剥がす必要があるかをここで判定する。
#
# ソース定義で見る。ID の綴りからフォントかどうかは判別できないため。
#
# 判定はソース単位ではなくファイル単位。winget-font のソースが 1 つでもあれば、
# 同じファイル内の通常パッケージにも前置剥がしが効く。ソース単位に精密化する
# なら ID とソースの組で持ち回る必要があるが、そこまではしない。剥がした ID が
# 通常パッケージの宣言 ID と衝突して初めて誤判定になり（例: FONT\User\Git.Git
# が存在し、かつ宣言に Git.Git がある）、フォント名と通常パッケージ ID の
# 名前空間は実質重ならないため。運用上も fonts.json を分けてあり混在しない。
#
# Name と Argument の AND で判定する。片方でも合えば通す作りにしない。
# Name はローカルで付け替えられる（winget source add --name は任意の名前を
# 取る）ため、名前だけを信じると任意のソースが winget-font を名乗れてしまう。
# Argument も部分一致にしない。末尾 /fonts のような緩い照合では攻撃者の
# ドメイン（https://evil.example/fonts）が通る。
#
# 通す条件を絞りすぎて外した場合は、前置を剥がさないだけで「未導入」表示に
# 寄る。誤って「導入済み」と出して導入を取りこぼすより安全なので、迷ったら
# 通さない側に倒す。公式 URL が変わったらここを直す。
$script:FontSourceName = 'winget-font'
$script:FontSourceArgument = 'https://cdn.winget.microsoft.com/fonts'

function Test-FontManifest {
    param([string]$Path)

    $json = Get-Content $Path -Raw | ConvertFrom-Json
    foreach ($source in $json.Sources) {
        # SourceDetails を持たない宣言もあるため、PSObject 経由で存在を確かめる。
        # StrictMode 下では未定義プロパティへの直接アクセスが例外になる。
        $details = $source.PSObject.Properties['SourceDetails']
        if (-not $details) { continue }

        $name = $details.Value.PSObject.Properties['Name']
        if (-not $name -or $name.Value -ne $script:FontSourceName) { continue }

        # URL は完全一致で見る。大文字小文字だけはホスト名の慣習に合わせて無視する。
        $argument = $details.Value.PSObject.Properties['Argument']
        if (-not $argument) { continue }
        if ($argument.Value.TrimEnd('/') -ine $script:FontSourceArgument) { continue }

        return $true
    }
    return $false
}

# 導入済み ID の一覧を 1 回の winget 呼び出しで取得する。
#
# パッケージごとに winget list を叩かない。1 件 1〜2 秒かかるため 60 件超では
# 数分待たされる。一覧なら全体で数秒で済む。
#
# export ではなく list を使う。export は「マニフェストに書き戻せるもの」しか
# 出力せず、導入済みでも黙って落ちるパッケージがある（実測: DeepL）。
#
# 出力は表形式で、ID 列はヘッダの 'ID' の桁位置で切り出す。列幅は日本語の
# アプリ名に合わせて可変なので、固定幅を決め打ちしてはいけない。
function Get-InstalledPackageId {
    # 端末幅で列が切り詰められると ID が欠ける。明示的に広げておく。
    $prevWidth = $env:WINGET_CLI_OUTPUT_WIDTH
    $env:WINGET_CLI_OUTPUT_WIDTH = '400'
    try {
        $lines = & winget list --accept-source-agreements 2>&1 | Out-String -Width 400
    } finally {
        $env:WINGET_CLI_OUTPUT_WIDTH = $prevWidth
    }

    $rows = $lines -split "`r?`n"

    # ヘッダ行は区切り線（---）の直前。ロケール非依存に位置で見つける。
    $sepIndex = -1
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i] -match '^-{5,}$') { $sepIndex = $i; break }
    }
    if ($sepIndex -lt 1) { return @() }

    $header = $rows[$sepIndex - 1]

    # ヘッダの列名の前は必ず 2 スペース以上空く。その境界を列開始位置とする。
    $columnStarts = @(0) + ([regex]::Matches($header, '(?<=\s{2})\S') | ForEach-Object { $_.Index })
    $idColumn = $columnStarts | Select-Object -Skip 1 -First 1
    if (-not $idColumn) { return @() }
    $nextColumn = $columnStarts | Select-Object -Skip 2 -First 1

    $ids = @()
    foreach ($row in $rows[($sepIndex + 1)..($rows.Count - 1)]) {
        if ($row.Length -le $idColumn) { continue }

        $width = if ($nextColumn -and $nextColumn -lt $row.Length) { $nextColumn - $idColumn }
                 else { $row.Length - $idColumn }
        $id = $row.Substring($idColumn, $width).Trim()

        if ($id) { $ids += $id }
    }
    return $ids
}

#endregion

#region ---------- main ----------

Write-Host ''
Write-Host '=== fav-tool installer ===' -ForegroundColor White
Write-Host "    manifest : $ManifestPath"
Write-Host ''

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warn 'winget が見つかりません。'
    Write-Warn 'Microsoft Store から「アプリ インストーラー」を導入してください。'
    exit 1
}

if (-not (Test-Path $ManifestPath)) {
    Write-Warn "マニフェストが見つかりません: $ManifestPath"
    exit 1
}

# --- 1. マニフェスト読み込み ---
Write-Step 'マニフェストを読み込みます'
try {
    $ids = Get-ManifestPackageId -Path $ManifestPath
} catch {
    Write-Warn "マニフェストの解析に失敗しました: $($_.Exception.Message)"
    exit 1
}
Write-Ok "$($ids.Count) パッケージが宣言されています。"

# --- 2. 未導入の洗い出し ---
# import は導入済みをスキップするが、事前に一覧を見せないと「何が入るか
# 分からないまま長時間走る」ことになるため、先に照会して提示する。
#
# この判定は目安であって正確ではない。あくまで差分の雰囲気を掴むためのもの。
# 導入済みを「未導入」と誤表示することがある（実測: 表示名が長く一覧で行が
# 折り返される Windows ターミナル、ストアの製品 ID で表示される msstore 由来）。
# 1 件ずつ winget list --id で照会すれば潰せるが、1 件 1〜2 秒かかり 60 件超
# では待ち時間に見合わないため採らない。実害は表示だけで、import 側は
# --no-upgrade が導入済みを正しく除くため二重導入にはならない。
Write-Step '導入状況を確認します（目安）'
$installed = Get-InstalledPackageId

# フォント宣言のときだけ FONT\User\ 等の前置を剥がした形も照合対象に加える。
# 剥がすのは FONT\ に限る。ARP\ や MSIX\ の後ろは実 ID ではなく製品コードや
# パッケージフルネームなので、剥がしても宣言の ID とは一致しない。
#
# 元の値は消さず追加する。剥がした形だけにすると FONT\ 付きで宣言された
# 場合に拾えなくなる。候補が増えるだけなので取りこぼしは増えない。
if (Test-FontManifest -Path $ManifestPath) {
    $installed += $installed |
        Where-Object { $_ -match '^FONT\\' } |
        ForEach-Object { ($_ -split '\\')[-1] }
}

$pending = @()
foreach ($id in $ids) {
    # -contains は既定で大文字小文字を区別しない。winget 自身も区別しないため
    # これで一致する。宣言は数十件なので、索引を組むほどの件数ではない。
    $isInstalled = $installed -contains $id

    if ($isInstalled) {
        Write-Skip "導入済み: $id"
    } else {
        Write-Ok "未導入  : $id"
        $pending += $id
    }
}

Write-Host ''
Write-Host "    導入済み: $($ids.Count - $pending.Count) / 未導入: $($pending.Count)"
Write-Host ''

if ($WhatIf) {
    Write-Step '-WhatIf のため、ここで終了します（何も導入しません）'
    exit 0
}

if ($pending.Count -eq 0 -and -not $Upgrade) {
    Write-Step 'すべて導入済みです。'
    exit 0
}

# --- 3. 導入 ---
Write-Step 'winget import を実行します'

# --ignore-versions : マニフェストにバージョンを書かない運用のため必須。
#                     省くと export 時点の版を要求して失敗する。
# --ignore-unavailable : 1 つでも入手不可だと全体が止まるのを防ぐ。
$importArgs = @(
    'import',
    '--import-file', $ManifestPath,
    '--ignore-versions',
    '--ignore-unavailable',
    '--accept-package-agreements',
    '--accept-source-agreements'
)

# --no-upgrade : 導入済みは触らない。付けないと実行のたびに全パッケージの
#                更新が走り、意図しない更新と長い待ち時間が発生する。
if (-not $Upgrade) { $importArgs += '--no-upgrade' }

& winget $importArgs
$exitCode = $LASTEXITCODE

Write-Host ''

# import は「全て導入済み」でも非 0 を返すため、失敗として扱わない。
if ($exitCode -ne 0) {
    Write-Skip "winget import exit=$exitCode（導入済みが含まれる場合も非 0 になります）"
}

Write-Step '完了しました。'
Write-Host ''

#endregion
