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

# winget list の終了コードで判定してはいけない。未導入でも 0 を返すため
# （実測済み）、全パッケージを導入済みと誤判定する。
# 「見つかりません」の文言も日本語ロケールでは別文字列なので使えない。
# 消去法で、出力に PackageIdentifier が現れるかを見る。
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
Write-Step '導入状況を確認します（少し時間がかかります）'
$pending = @()
foreach ($id in $ids) {
    if (Test-PackageInstalled -Id $id) {
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
