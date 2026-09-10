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
    return $ids
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

# 一覧に現れない ID の最終確認。
#
# msstore 由来のパッケージは一覧ではストアの製品 ID（XPDNX7G06BLH2G 等）で
# 表示され、マニフェストの ID（DeepL.DeepL）とは一致しない。--id 指定で
# 引いたときだけ winget が名寄せするので、取りこぼし分だけここで照会する。
#
# 終了コードは見ない。未導入でも 0 を返すため（実測済み）、全件を導入済みと
# 誤判定する。「見つかりません」の文言も日本語ロケールでは別文字列。
# 消去法で、出力に ID が現れるかを見る。
function Test-PackageInstalled {
    param([string]$Id)

    $listed = & winget list --id $Id --exact 2>&1 | Out-String
    return ($listed -match [regex]::Escape($Id))
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
Write-Step '導入状況を確認します'
$installed = Get-InstalledPackageId

# ID の大文字小文字は winget 自身が区別しないため、照合側も揃えておく。
$installedSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$installed, [System.StringComparer]::OrdinalIgnoreCase)

$pending = @()
foreach ($id in $ids) {
    $isInstalled = $installedSet.Contains($id)

    # 一覧で見つからなかったものだけ個別照会する。誤って「未導入」と出すと
    # 導入済みのパッケージに import が走るため、ここは取りこぼしを潰しておく。
    if (-not $isInstalled) { $isInstalled = Test-PackageInstalled -Id $id }

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
