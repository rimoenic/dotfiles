# _PSFZF_FZF_DEFAULT_OPTSはPSFZFで効く。PSFZFとfzfでDEFAULT OPTSを分けたい時
# $env:_PSFZF_FZF_DEFAULT_OPTS="--reverse --border --height 50%"
$env:FZF_DEFAULT_OPTS="--reverse --border --height 50%"
$env:FZF_DEFAULT_COMMAND='fd -HL --exclude ".git" .'

# Install-Module -Scope CurrentUser PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# Ctrl+] : ghq list を fzf で選んでそのディレクトリに cd する（zshrc の ghq-fzf 相当）
Set-PSReadLineKeyHandler -Chord 'Ctrl+]' -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $selected = ghq list | fzf --query "$line"
    if ([string]::IsNullOrWhiteSpace($selected)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        return
    }

    $root = (ghq root).Trim()
    $path = Join-Path $root $selected

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Set-Location `"$path`"")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
