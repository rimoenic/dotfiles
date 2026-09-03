# Windows 起点の dotfiles ブートストラップ
#
# 実行方法（管理者権限の PowerShell で）:
#   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
#
# PowerShell 7 固有の構文（&&, ??, ?:, -AsHashtable 等）は使わないこと。
# 素の Windows 11 に入っているのは Windows PowerShell 5.1 だけで、7 はこの
# スクリプト自身がこれから入れるため、7 前提で書くと初回に動かない。
#
# 日本語コメントを含むため UTF-8 BOM 付きで保存すること。BOM を落とすと 5.1 が
# Shift-JIS と誤読し、マルチバイト文字が後続の括弧を壊してパースエラーになる。
#
# 冪等。中断しても再実行すれば続きから進む。

[CmdletBinding()]
param(
    # 'Ubuntu' ではなくバージョン付きを既定にする。'Ubuntu' はメタパッケージで
    # どの版が入るか Windows 側の都合で変わり、再現性がないため。
    # wsl --list --online の Name 列と一致していないと導入に失敗する。
    [string]$Distro = 'Ubuntu-24.04',

    [string]$RepoOwner = 'rimoenic',
    [string]$RepoName  = 'dotfiles',
    [string]$RepoRef   = 'master',

    [switch]$SkipWindowsSetup,
    [switch]$SkipPwsh7
)

Set-StrictMode -Version Latest

# 'Stop' にしない。wsl/winget は正常系でも stderr に書くため、'Stop' だと
# 成功しているのに終了エラーとして落ちる。失敗判定は $LASTEXITCODE で行う。
$ErrorActionPreference = 'Continue'

# StrictMode 下では未設定の $LASTEXITCODE を読むだけで例外になる（5.1 で実測）。
# ネイティブコマンドを一度も実行していない新規セッションが該当する。
$global:LASTEXITCODE = 0

# 5.1 の Invoke-WebRequest は進捗バー描画で極端に遅くなる。7 では不要だが、
# 5.1 で動かす以上ここで消しておく必要がある。
$ProgressPreference = 'SilentlyContinue'

# 5.1 の既定 SecurityProtocol は環境によっては TLS 1.2 を含まず、GitHub への
# HTTPS が失敗する。7 では既定で問題ないが 5.1 のために明示する。
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RawBase     = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$RepoRef"
$DotfilesWin = Join-Path $env:USERPROFILE '.dotfiles'

#region ---------- 出力ヘルパ ----------

function Write-Step   { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok     { param([string]$Message) Write-Host "    $Message" -ForegroundColor Green }
function Write-Skip   { param([string]$Message) Write-Host "    $Message" -ForegroundColor DarkGray }
function Write-Warn   { param([string]$Message) Write-Host "    $Message" -ForegroundColor Yellow }

# 最後にまとめて表示する「人間がやること」
$script:NextActions = New-Object System.Collections.Generic.List[string]
function Add-NextAction { param([string]$Message) $script:NextActions.Add($Message) }

#endregion

#region ---------- 前提チェック ----------

function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-CommandExists {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

# 単一のネイティブコマンドだけを昇格実行する。
#
# スクリプト全体を昇格再実行する方式は採らない。別ウィンドウで走ることになり
# 出力が分断されるうえ、昇格が不要な処理まで管理者権限で動いてしまうため。
#
# UAC 拒否は例外になるので、throw させず $null を返す。呼び出し側で
# 「手動実行してください」と案内に切り替えたく、ここで落としたくないため。
function Invoke-Elevated {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $argLine = $Arguments -join ' '
    Write-Warn "管理者権限が必要です。UAC ダイアログを承認してください:"
    Write-Warn "    $FilePath $argLine"

    try {
        $proc = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
            -Verb RunAs -Wait -PassThru -ErrorAction Stop
    } catch {
        # UAC 拒否（キャンセル）など
        Write-Warn "昇格に失敗しました: $($_.Exception.Message)"
        return $null
    }

    return $proc.ExitCode
}

#endregion

#region ---------- WSL ----------

# 導入済みディストロ名の一覧を返す。
#
# [Console]::OutputEncoding を UTF-16 に切り替える方法は採らない。wsl.exe の
# 既定出力は確かに UTF-16LE だが、WSL_UTF8=1 が設定されていると UTF-8 で出るため、
# 両方が効くと二重に解釈して全体が化け、名前の一致判定が必ず失敗する。
# WSL_UTF8 に一本化し、ここでは素直に読む。
# （NUL 除去は WSL_UTF8 が効かない古い wsl.exe への保険として残す）
function Get-InstalledDistro {
    if (-not (Test-CommandExists 'wsl')) { return @() }

    $env:WSL_UTF8 = '1'
    $raw = & wsl.exe --list --quiet 2>$null

    if ($null -eq $raw) { return @() }

    $names = @()
    foreach ($line in $raw) {
        $name = ($line -replace "`0", '').Trim()
        if ($name) { $names += $name }
    }
    return $names
}

# WSL 本体（オプション機能 + カーネル）の導入。
#
# winget install Microsoft.WSL は使わない。あれは「WSL アプリ本体」パッケージで、
# 土台の Windows オプション機能（VirtualMachinePlatform 等）を有効化しないため、
# 素の Windows 11 ではアプリだけ入って動かない状態になりうる。
#
# また wsl.exe は Windows 11 に標準同梱なので、「wsl.exe を入れるために winget を
# 使う」という発想自体が不要。
function Install-WslCore {
    Write-Step 'WSL 本体'

    if (-not (Test-CommandExists 'wsl')) {
        # Windows 11 では wsl.exe は OS 同梱なので通常ここには来ない。
        # 到達する時点で Home エディションや仮想化無効など、スクリプトで
        # 面倒を見きれない環境の可能性が高いため、導入を試みず案内で終える。
        Write-Warn 'wsl.exe が見つかりません。'
        Add-NextAction "wslのインストールに対応していない可能性があります。"
        return $false
    }

    # 導入済みかの事前判定はしない。判定を挟むほうが壊れるため。
    #
    # `wsl --status` で判定してはいけない:
    #   - オプション機能が無効な中途半端な状態でも exit 0 を返す。未導入を
    #     導入済みと誤判定する（podman も exit 0 を信用せず出力を見ている）
    #   - Win11 24H2 の inbox stub はインストール確認ウィンドウを出して
    #     60 秒ハングすることがある（rancher-desktop#7975）
    #
    # `wsl --install --no-distribution` は導入済みでも exit 0 を返す（実測済み）ので、
    # 判定せず毎回叩いて exit code だけ見るのが単純かつ安全。
    Write-Ok 'WSL 本体（オプション機能・カーネル）を確認/導入します...'

    # 出力を読む都合上 UTF-8 にしておく。付けないと UTF-16 のまま文字化けする。
    $env:WSL_UTF8 = '1'

    # 最初から昇格しない。導入済み環境では非管理者でも成功するため、
    # 先に昇格すると毎回不要な UAC が出る。失敗したときだけ昇格する。
    $output = & wsl.exe --install --no-distribution 2>&1 | ForEach-Object { $_.ToString() }
    $exitCode = $LASTEXITCODE
    if ($output) { $output | ForEach-Object { Write-Skip $_ } }

    # 昇格実行の出力は取得できない（別プロセスのため）。後段の再起動判定を
    # 出力文言だけに頼ると、実際に機能有効化が走った昇格経路 —— つまり最も
    # 再起動が必要な場面 —— で空振りする。そのため昇格の有無を持っておく。
    $elevated = $false

    if ($exitCode -ne 0) {
        Write-Warn "通常権限では失敗しました (exit $exitCode)。管理者権限で再試行します。"
        $exitCode = Invoke-Elevated -FilePath 'wsl.exe' -Arguments @('--install', '--no-distribution')
        $elevated = $true

        if ($null -eq $exitCode) {
            Add-NextAction "管理者 PowerShell で ``wsl --install --no-distribution`` を実行してください。"
            return $false
        }
    }

    if ($exitCode -ne 0) {
        Write-Warn "wsl --install --no-distribution が失敗しました (exit $exitCode)。"
        Add-NextAction "管理者 PowerShell で ``wsl --install --no-distribution`` を実行してください。"
        return $false
    }

    Write-Ok 'WSL 本体は利用可能です。'

    # 再起動の要否。
    #
    # 「導入できたら常に再起動を促す」ことはしない。毎回叩く作りなので、
    # 導入済み環境で実行するたびに不要な再起動を案内してしまうため。
    #
    # 逆に出力文言だけで判定することもできない。導入済み環境では
    # 「この操作を正しく終了しました。」しか返らず（実測済み）、「既に有効」と
    # 「今回有効化した」が同一文言になるため。
    #
    # そこで「何も起きなかった＝不要」を既定とし、昇格が要った場合と、
    # 出力に再起動要求があった場合のみ案内する。
    # 英語マッチも残す。文言は OS の言語設定に従うため、英語環境では
    # 日本語だけだと静かに検出漏れする。
    $needsReboot = $elevated
    foreach ($line in $output) {
        if ($line -match '再起動|restart|reboot') { $needsReboot = $true }
    }

    if ($needsReboot) {
        Write-Warn 'オプション機能が有効化されました。Windows の再起動が必要です。'
        Add-NextAction 'Windows を再起動してから bootstrap.ps1 を再実行してください。'
    }

    return $true
}

function Install-WslDistro {
    param([string]$Name)

    Write-Step "WSL ディストロ: $Name"

    if (-not (Test-CommandExists 'wsl')) {
        Write-Warn 'wsl.exe が見つからないためスキップします。'
        return $false
    }

    $installed = Get-InstalledDistro
    if ($installed -contains $Name) {
        Write-Skip "$Name は導入済み。スキップします。"
        return $true
    }

    Write-Ok "$Name を導入します（初回起動はしません）..."
    # --no-launch は必須。省くと初回起動が走り、UNIX ユーザー作成の対話が
    # このスクリプトを掴んだまま止まる。ユーザー作成は最後に案内して人間に任せる。
    # （--no-distribution とは別物。あちらは本体のみでディストロを入れない指定）
    & wsl.exe --install --distribution $Name --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "wsl --install が失敗しました (exit $LASTEXITCODE)。"
        Add-NextAction "``wsl --install --distribution $Name --no-launch`` を手動で実行してください。Windows の再起動が必要な場合があります。"
        return $false
    }

    Write-Ok "$Name を導入しました。"
    return $true
}

# ディストロの初回起動（UNIX ユーザー作成）が済んでいるか。
#
# 「導入済み＝使える」とは扱えない。--no-launch で入れた直後は root しかおらず、
# その状態で installer.sh を流すと root の home に配置されて壊れるため、
# 既定ユーザーの uid が非 0 かどうかまで見る。
function Test-DistroInitialized {
    param([string]$Name)

    $installed = Get-InstalledDistro
    if ($installed -notcontains $Name) { return $false }

    $uid = & wsl.exe --distribution $Name --exec id -u 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($null -eq $uid) { return $false }

    return (("$uid".Trim()) -ne '0')
}

#endregion

#region ---------- winget ----------

function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Label
    )

    if (-not $Label) { $Label = $Id }

    if (-not (Test-CommandExists 'winget')) {
        Write-Warn "winget が見つからないため $Label をスキップします。"
        Add-NextAction "Microsoft Store から「アプリ インストーラー」を導入し、``winget install --id $Id -e`` を実行してください。"
        return $false
    }

    # winget list の終了コードで判定してはいけない。未導入でも 0 を返すため
    # （実測済み）、全パッケージを導入済みと誤判定して何も入らなくなる。
    # 「見つかりません」の文言も日本語ロケールでは別文字列なので使えない。
    # 消去法で、出力に PackageIdentifier が現れるかを見る。
    $listed = & winget.exe list --id $Id --exact 2>&1 | Out-String
    if ($listed -match [regex]::Escape($Id)) {
        Write-Skip "$Label は導入済み。スキップします。"
        return $true
    }

    Write-Ok "$Label を導入します..."
    & winget.exe install --id $Id --exact --silent `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "$Label の導入に失敗しました (exit $LASTEXITCODE)。"
        Add-NextAction "``winget install --id $Id -e`` を手動で実行してください。"
        return $false
    }

    Write-Ok "$Label を導入しました。"
    return $true
}

#endregion

#region ---------- dotfiles 取得 ----------

# repo 全体は落とさない。bootstrap は単体で落ちてくる想定で、repo 本体の clone は
# WSL 側の installer.sh が担うため、二重取得になる。Windows 側で必要なのは
# setup.ps1 とその参照先だけ。
function Get-RemoteFile {
    param(
        [string]$RelativePath,
        [string]$Destination
    )

    $uri = "$RawBase/$RelativePath"
    $dir = Split-Path $Destination -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    # ここだけ Stop にする。スクリプト既定の Continue のままだと DL 失敗が
    # 例外にならず、呼び出し側の catch をすり抜けて空ファイルのまま進んでしまう。
    Invoke-WebRequest -Uri $uri -OutFile $Destination -UseBasicParsing -ErrorAction Stop
}

#endregion

#region ---------- main ----------

Write-Host ''
Write-Host '=== dotfiles bootstrap (Windows) ===' -ForegroundColor White
Write-Host "    distro : $Distro"
Write-Host "    repo   : $RepoOwner/$RepoName@$RepoRef"
Write-Host "    dest   : $DotfilesWin"
Write-Host ''

if (-not (Test-Administrator)) {
    Write-Host '  非管理者で実行中です。' -ForegroundColor Yellow
    Write-Host '  管理者権限が必要な処理では、都度 UAC ダイアログが表示されます。' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  UAC を出したくない場合は、管理者 PowerShell で実行してください:' -ForegroundColor DarkGray
    Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor DarkGray
    Write-Host ''
}

# --- 1. WSL 本体 → ディストロ ---
$coreReady = Install-WslCore
if ($coreReady) {
    $distroReady = Install-WslDistro -Name $Distro
} else {
    Write-Step "WSL ディストロ: $Distro"
    Write-Skip 'WSL 本体が未準備のためスキップします。'
    $distroReady = $false
}

# --- 2. PowerShell 7 ---
# setup.ps1 の実行より前に入れておく。後回しにすると、7 で走らせたい setup.ps1 を
# 5.1 で走らせることになるため（setup.ps1 を将来 7 前提に書き直す想定）。
if (-not $SkipPwsh7) {
    Write-Step 'PowerShell 7'
    Install-WingetPackage -Id 'Microsoft.PowerShell' -Label 'PowerShell 7' | Out-Null
} else {
    Write-Step 'PowerShell 7'
    Write-Skip '-SkipPwsh7 が指定されたためスキップします。'
}

# --- 3. Windows 側の設定 ---
if (-not $SkipWindowsSetup) {
    Write-Step 'Windows 側の設定 (setup.ps1)'

    if (Test-Path (Join-Path $DotfilesWin 'windows\setup.ps1')) {
        # repo があるならそちらを優先する。DL し直すと、ローカルで編集した
        # setup.ps1 ではなくリモートの内容で上書き実行してしまうため。
        $setupPath = Join-Path $DotfilesWin 'windows\setup.ps1'
        Write-Skip "既存の repo を使います: $setupPath"
    } else {
        # 参照先ファイルを列挙して個別に落とすことはしない。windows/ にファイルを
        # 足すたびにこの一覧を直す羽目になるため。setup.ps1 だけ落として実行し、
        # repo 本体の clone は setup.ps1 自身に任せる。
        $stage = Join-Path $env:TEMP "dotfiles-bootstrap-$PID"
        $setupPath = Join-Path $stage 'setup.ps1'
        Write-Ok "setup.ps1 を取得します -> $setupPath"

        try {
            Get-RemoteFile -RelativePath 'windows/setup.ps1' -Destination $setupPath
        } catch {
            Write-Warn "取得に失敗しました: $($_.Exception.Message)"
        }
    }

    if (Test-Path $setupPath) {
        # pwsh を決め打ちで呼ばない。導入に失敗している場合に落ちるので、
        # 在るときだけ使い、無ければ 5.1 にフォールバックする。
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwsh) {
            Write-Ok "pwsh 7 で setup.ps1 を実行します。"
            & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $setupPath
        } else {
            Write-Ok "Windows PowerShell 5.1 で setup.ps1 を実行します。"
            & $setupPath
        }
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
            Write-Warn "setup.ps1 が非 0 で終了しました (exit $LASTEXITCODE)。"
        }
    } else {
        Write-Warn 'setup.ps1 が見つからないためスキップします。'
        Add-NextAction 'setup.ps1 を手動で実行してください。'
    }
} else {
    Write-Step 'Windows 側の設定 (setup.ps1)'
    Write-Skip '-SkipWindowsSetup が指定されたためスキップします。'
}

# --- 4. WSL 側の installer.sh ---
Write-Step "WSL 側のセットアップ (installer.sh)"

$installerCmd = "bash <(curl -fsSL $RawBase/doc/installer.sh)"

if (-not $distroReady) {
    Write-Warn "$Distro が未導入のため実行できません。"
    Add-NextAction "$Distro の導入後、WSL 内で以下を実行してください:`n      $installerCmd"
} elseif (-not (Test-DistroInitialized -Name $Distro)) {
    Write-Warn "$Distro の初回セットアップ（UNIX ユーザー作成）が未完了です。"
    Add-NextAction "``wsl --distribution $Distro`` を実行し、UNIX ユーザー名とパスワードを設定してください。"
    Add-NextAction "その後 WSL 内で以下を実行してください:`n      $installerCmd"
    Add-NextAction "あるいは、ユーザー作成後に bootstrap.ps1 を再実行すれば自動で続きを行います。"
} else {
    Write-Ok "$Distro 内で installer.sh を実行します..."
    & wsl.exe --distribution $Distro --exec bash -lc "curl -fsSL $RawBase/doc/installer.sh | bash"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "installer.sh が失敗しました (exit $LASTEXITCODE)。"
        Add-NextAction "WSL 内で以下を手動実行してください:`n      $installerCmd"
    } else {
        Write-Ok 'installer.sh が完了しました。'

        # installer.sh が書いた /etc/wsl.conf は、再起動しないと反映されない
        # （systemd や automount の設定が効かないまま次の起動を迎える）
        Write-Ok 'WSL を再起動して /etc/wsl.conf を反映します...'
        & wsl.exe --shutdown
    }
}

# --- 完了 ---
Write-Host ''
if ($script:NextActions.Count -gt 0) {
    Write-Host '=== 次にやること ===' -ForegroundColor Yellow
    $i = 1
    foreach ($action in $script:NextActions) {
        Write-Host "  $i. $action" -ForegroundColor Yellow
        $i++
    }
    Write-Host ''
    Write-Host '  上記を済ませてから bootstrap.ps1 を再実行すると、続きから進みます。' -ForegroundColor DarkGray
} else {
    Write-Host '=== 完了 ===' -ForegroundColor Green
    Write-Host "  Windows Terminal から $Distro を開いて確認してください。" -ForegroundColor Green
}
Write-Host ''

#endregion
