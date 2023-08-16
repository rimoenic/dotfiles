#-----------------------------------------------------
# General
#-----------------------------------------------------

# PowerShell Core7でもConsoleのデフォルトエンコーディングはsjisなので必要
[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
[System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")

# git logなどのマルチバイト文字を表示させるため (絵文字含む)
$env:LESSCHARSET = "utf-8"

# 音を消す
Set-PSReadlineOption -BellStyle None

# 予測インテリセンス
Set-PSReadLineOption -PredictionSource History

# 重複履歴無効化
Set-PSReadlineOption -HistoryNoDuplicates

# No Bell
Set-PSReadlineOption -BellStyle None

#-----------------------------------------------------
# Key binding
#-----------------------------------------------------

# Emacsベース
Set-PSReadLineOption -EditMode Emacs

#-----------------------------------------------------
# Powerline
#-----------------------------------------------------

#Invoke-Expression (& {
#    $hook = if ($PSVersionTable.PSVersion.Major -lt 6) { 'prompt' } else { 'pwd' }
#    (zoxide init --hook $hook powershell | Out-String)
#})

#oh-my-posh init pwsh --config ~/.oh-my-posh.json | Invoke-Expression
oh-my-posh init pwsh | Invoke-Expression


#-----------------------------------------------------
# fzf
#-----------------------------------------------------

# fzf
$env:FZF_DEFAULT_OPTS="--reverse --border --height 50%"
$env:FZF_DEFAULT_COMMAND='fd -HL --exclude ".git" .'
function _fzf_compgen_path() {
    fd -HL --exclude ".git" . "$1"
}
function _fzf_compgen_dir() {
    fd --type d -HL --exclude ".git" . "$1"
}


# Install-Module -Scope CurrentUser PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'




Import-Module -Name Terminal-Icons
Import-Module -Name z



function cdr() { fd -H -t d -E .git -E node_modules | fzf | cd }
function cdz() { z -l | oss | select -skip 3 | % { $_ -split " +" } | sls -raw '^[a-zA-Z].+' | fzf | cd }


function ssh-fzf() {
 Select-String -Path "config" -Pattern "Host " | select-string -Pattern "\*" -NotMatch -Raw | ForEach-Object { ($_ -split ' ')[1] } | fzf
}


# https://qiita.com/SAITO_Keita/items/3f9fa4cfb873d6795779
Register-ArgumentCompleter -CommandName ssh, scp -Native -ScriptBlock {
  param($wordToComplete, $commandAst, $cursorPosition)

  # .ssh\config　からHost項目の一覧を取得
  $sshConfigHostList = (Get-Content ~\.ssh\config).trim() -replace "\s+", " " | Select-String -Pattern "^Host\s" | ForEach-Object { $_ -split "\s+" | Select-Object -Skip 1 }

  # Host一覧 から　入力値（$wordToComplete）に合致する物を補完対象。
  # [System.Management.Automation.CompletionResult]を生成して返す
  $sshConfigHostList | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
    $resultType = [System.Management.Automation.CompletionResultType]::ParameterValue
    # CompletionResult Class
    # completionText , listItemText , resultType toolTip
    [System.Management.Automation.CompletionResult]::new($_, $_, $resultType , $_)
  }
}