# Windows側のdotfilesセットアップスクリプト
# 実行方法: powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# repo 内から実行する場合と、bootstrap.ps1 が raw DL したこのファイル単体を
# 実行する場合の両方を想定する。後者では repo がまだ無いので自分で clone する。

param(
    [string]$DotfilesRoot = (Join-Path $env:USERPROFILE '.dotfiles'),
    [string]$RepoUrl      = 'https://github.com/rimoenic/dotfiles.git'
)

#region ---------- SSH鍵ヘルパ ----------

# ed25519 を使う。OpenSSH 9.5 以降は ssh-keygen の既定型でもある。
# 耐量子の mldsa44-ed25519 は OpenSSH 10.4 で入ったが、実験的・既定で無効・
# GitHub 未対応なので採らない（GitHub の耐量子化は鍵交換側で、鍵の型とは無関係）。
#
# -a（KDFラウンド数）は付けない。パスフレーズが空だと private key は暗号化されず、
# ラウンド数は一切使われないため（実測で -a 16 と -a 512 の出力がバイト同一）。
function New-SshKeyIfMissing {
    $sshDir  = Join-Path $env:USERPROFILE '.ssh'
    $keyPath = Join-Path $sshDir 'id_ed25519'

    if (Test-Path $keyPath) {
        Write-Host "SSH key already exists, skipping. ($keyPath)"
        return
    }

    if (!(Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
        Write-Host "WARNING: ssh-keygen not found. Install OpenSSH Client:"
        Write-Host "  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0"
        return
    }

    if (!(Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    # コメントは user@host にする。GitHub の鍵一覧で「どのマシンの鍵か」が分かり、
    # 失効させたいときに判断できるため（メールアドレスだと機械を特定できない）。
    $comment = "$env:USERNAME@$env:COMPUTERNAME"

    # -N '""' と書く。PowerShell は素の '' を渡す際に空文字を落としてしまい、
    # ssh-keygen が対話でパスフレーズを聞いて止まる（または """ が passphrase になる）。
    Write-Host "Generating SSH key: $keyPath"
    & ssh-keygen -t ed25519 -N '""' -C $comment -f $keyPath -q

    if (Test-Path "$keyPath.pub") {
        Write-Host ""
        Write-Host "=== Add this public key to GitHub (https://github.com/settings/keys) ==="
        Get-Content "$keyPath.pub"
        Write-Host ""
    }
}

#endregion

#region ---------- dotfiles repo ヘルパ ----------

# clone は https で行う。生成した鍵は GitHub にまだ登録されていないため、
# SSH だと初回 clone がここで失敗するため。
function Get-DotfilesRepo {
    param([string]$Path, [string]$Url)

    if (Test-Path (Join-Path $Path '.git')) {
        Write-Host "Repository already cloned, skipping. ($Path)"
        return $true
    }

    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "WARNING: git not found. Install it first:"
        Write-Host "  winget install --id Git.Git -e"
        return $false
    }

    # installer.sh と同じく、既存ディレクトリは消さず .orig に退避する
    if (Test-Path $Path) {
        $backup = "$Path.orig"
        Write-Host "Backing up existing directory: $Path -> $backup"
        Move-Item $Path $backup -Force
    }

    Write-Host "Cloning $Url -> $Path"
    & git clone $Url $Path
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: git clone failed (exit $LASTEXITCODE)"
        return $false
    }
    return $true
}

#endregion

#region ---------- パッケージ導入ヘルパ ----------

# git のみ個別導入。fav_tools.json にも含まれているが、その manifest 自体が
# repo の中にあるため、clone より前に git を用意する必要がある。
function Install-Git {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Host "git already installed, skipping."
        return
    }

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "WARNING: winget not found. Install git manually:"
        Write-Host "  https://git-scm.com/download/win"
        return
    }

    Write-Host "Installing Git.Git..."
    & winget install --id Git.Git --exact --silent `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: failed to install Git.Git (exit $LASTEXITCODE)"
    }
}

# PATH を張り直す。winget でインストールした直後は、このプロセスの PATH が
# 古いままで git などを解決できないため（新規プロセスにしか反映されない）。
function Update-PathFromRegistry {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user | Where-Object { $_ }) -join ';'
}

function Install-ModuleIfMissing {
    param([string]$Name)
    if (!(Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing $Name..."
        Install-Module -Scope CurrentUser -Name $Name -Force
    } else {
        Write-Host "$Name already installed, skipping."
    }
}

#endregion

#region ---------- 設定ファイル配置ヘルパ ----------

function Backup-AndCopy {
    param(
        [string]$Src,
        [string]$Dest
    )

    # 中身が同じなら何もしない。毎回コピーすると、内容が変わっていなくても
    # .orig が上書きされて「直前の状態」を失う。差分が無いのに退避すると
    # 退避の意味も無いため、ハッシュで比較して同一なら noop にする。
    if (Test-Path $Dest) {
        $srcHash  = (Get-FileHash -Path $Src  -Algorithm SHA256).Hash
        $destHash = (Get-FileHash -Path $Dest -Algorithm SHA256).Hash
        if ($srcHash -eq $destHash) {
            Write-Host "Identical, skipping. ($Dest)"
            return
        }

        $backup = "$Dest.orig"
        Copy-Item $Dest $backup -Force
        Write-Host "Backed up: $Dest -> $backup"
    }
    Copy-Item $Src $Dest -Force
    Write-Host "Copied: $Dest"
}

#endregion

#region ---------- main ----------

# --- 1. git ---
# git だけは manifest より先に個別導入する。manifest は repo の中にあり、
# その repo を clone するのに git が要る、という循環があるため。
Install-Git
Update-PathFromRegistry

# --- 2. SSH鍵 ---
New-SshKeyIfMissing

# --- 3. dotfiles repo ---
# repo 内から実行されている場合はそれを使い、単体実行なら clone する。
if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'WindowsTerminal'))) {
    $dotfilesWindows = $PSScriptRoot
} else {
    if (!(Get-DotfilesRepo -Path $DotfilesRoot -Url $RepoUrl)) {
        Write-Host "ERROR: dotfiles repository unavailable. Aborting."
        exit 1
    }
    $dotfilesWindows = Join-Path $DotfilesRoot 'windows'
}

# --- 4. PowerShell モジュール ---
# fav_tools.json の導入はここでは行わない。60 パッケージ超で非常に重く、
# 環境構築のたびに全部入れたいわけではないため、install_fav_tools.ps1 として
# 独立させ、必要なときだけ明示的に叩く。
Install-ModuleIfMissing "PSFzf"
Install-ModuleIfMissing "Terminal-Icons"
Install-ModuleIfMissing "z"

# --- 5. .wslconfig ---
$wslconfigDest = "$env:USERPROFILE\.wslconfig"
$wslconfigSrc  = "$dotfilesWindows\wsl\.wslconfig.example"
if (!(Test-Path $wslconfigDest)) {
    Copy-Item $wslconfigSrc $wslconfigDest
    Write-Host "Copied .wslconfig to $wslconfigDest"
    Write-Host "NOTE: Edit memory/swap values to match your machine."
    Invoke-Item $wslconfigDest
} else {
    Write-Host ".wslconfig already exists, skipping. ($wslconfigDest)"
}

# --- 6. git config ---
# 設定本体は repo の git/*.gitconfig に置き、ここではそれを include するだけの
# 薄い config を生成する。WSL 側（home.nix の programs.git）も同じ
# common.gitconfig を読むので、共通部分の実体が一つに保たれる。
#
# 置き場所は ~/.config/git/config（XDG）にする。Home Manager が WSL 側で
# 生成するのがこのパスなので、両OSで構成を揃えるため。Git for Windows も
# この場所を global スコープとして読む。
$gitRepoDir      = Split-Path $dotfilesWindows -Parent
$gitConfigDir    = Join-Path $env:USERPROFILE '.config\git'
$gitconfigDest   = Join-Path $gitConfigDir 'config'
$gitconfigLegacy = Join-Path $env:USERPROFILE '.gitconfig'
$gitLocalSample  = Join-Path $gitRepoDir 'git\local.gitconfig.example'
$gitLocal        = Join-Path $gitRepoDir 'git\local.gitconfig'

# include の path は Git が解釈するため、区切りは / に統一する。
# Git for Windows はバックスラッシュをエスケープ文字として扱うため。
$gitDirForward = $gitRepoDir.Replace('\', '/') + '/git'

if (!(Test-Path $gitConfigDir)) {
    New-Item -ItemType Directory -Path $gitConfigDir -Force | Out-Null
}

if (Test-Path $gitconfigDest) {
    Write-Host "git config already exists, skipping. ($gitconfigDest)"
    Write-Host "NOTE: To use the shared config, add these lines manually:"
    Write-Host "  [include]"
    Write-Host "      path = $gitDirForward/common.gitconfig"
    Write-Host "  [include]"
    Write-Host "      path = $gitDirForward/windows.gitconfig"
} else {
    @"
# このファイルは windows/setup.ps1 が生成した。設定本体は .dotfiles/git/ にある。
[include]
    path = $gitDirForward/common.gitconfig
[include]
    path = $gitDirForward/windows.gitconfig
[include]
    path = $gitDirForward/local.gitconfig
"@ | Set-Content -Path $gitconfigDest -Encoding utf8NoBOM
    Write-Host "Created: $gitconfigDest"
}

# ~/.gitconfig が残っていると、そちらが XDG 側より優先される（Git は XDG を
# 先に読み、~/.gitconfig で上書きする）。生成した config が黙って無効化される
# ため、消すかどうかは利用者が判断できるよう知らせるに留める。
if (Test-Path $gitconfigLegacy) {
    Write-Host ""
    Write-Host "WARNING: $gitconfigLegacy still exists and TAKES PRECEDENCE over"
    Write-Host "         $gitconfigDest"
    Write-Host "         Move any machine-specific settings there, then delete it."
    Write-Host ""
}

# ユーザ情報は repo に入れていないので、雛形から作って編集を促す。
if (!(Test-Path $gitLocal)) {
    Copy-Item $gitLocalSample $gitLocal
    Write-Host "Created: $gitLocal"
    Write-Host "NOTE: Set your name and email there."
    Invoke-Item $gitLocal
}

# --- 7. Windows Terminal settings.json ---
$wtDir = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtSrc = "$dotfilesWindows\WindowsTerminal\settings.json"
if (Test-Path $wtDir) {
    Backup-AndCopy $wtSrc "$wtDir\settings.json"
} else {
    Write-Host "WARNING: Windows Terminal not found. Install it from Microsoft Store first."
}

# --- 8. PowerShell profile ---
# ローダーのみコピー。設定本体は dotfiles/windows/powershell/ 以下を直接参照する。
$profileSrc = "$dotfilesWindows\Microsoft.PowerShell_profile.ps1"
$profileDir  = Split-Path $PROFILE
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir | Out-Null
}
Backup-AndCopy $profileSrc $PROFILE

#endregion
