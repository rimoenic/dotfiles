# Windows側のdotfilesセットアップスクリプト
# 実行方法: powershell -ExecutionPolicy Bypass -File .\setup.ps1

$dotfilesWindows = $PSScriptRoot

function Backup-AndCopy {
    param(
        [string]$Src,
        [string]$Dest
    )
    if (Test-Path $Dest) {
        $backup = "$Dest.orig"
        Copy-Item $Dest $backup -Force
        Write-Host "Backed up: $Dest -> $backup"
    }
    Copy-Item $Src $Dest -Force
    Write-Host "Copied: $Dest"
}

# .wslconfig
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

# Windows Terminal settings.json
$wtDir = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
$wtSrc = "$dotfilesWindows\WindowsTerminal\settings.json"
if (Test-Path $wtDir) {
    Backup-AndCopy $wtSrc "$wtDir\settings.json"
} else {
    Write-Host "WARNING: Windows Terminal not found. Install it from Microsoft Store first."
}

# PowerShell profile (oh-my-posh)
$profileSrc = "$dotfilesWindows\oh-my-posh\Microsoft.PowerShell_profile.ps1"
$profileDir  = Split-Path $PROFILE
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir | Out-Null
}
Backup-AndCopy $profileSrc $PROFILE
