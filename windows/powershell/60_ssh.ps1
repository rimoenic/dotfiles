function Get-SshConfigHosts() {
    Select-String -Path "$HOME\.ssh\config.d/hosts*" -Pattern "^Host " | Select-String -Pattern "\*" -NotMatch -Raw | ForEach-Object { ($_ -split '\s+')[1] } | Sort-Object -Unique
}

function ssh-fzf() {
    Get-SshConfigHosts | fzf
}

# Ctrl+\ : ~/.ssh/config のホストを fzf で選んで ssh する（zshrc の ssh-fzf 相当）
Set-PSReadLineKeyHandler -Chord 'Ctrl+\' -ScriptBlock {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    $selected = Get-SshConfigHosts | fzf --query "$line"
    if ([string]::IsNullOrWhiteSpace($selected)) {
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        return
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("ssh $selected")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# https://qiita.com/SAITO_Keita/items/3f9fa4cfb873d6795779
Register-ArgumentCompleter -CommandName ssh, scp -Native -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $sshConfigHostList = (Get-Content ~\.ssh\config).trim() -replace "\s+", " " | Select-String -Pattern "^Host\s" | ForEach-Object { $_ -split "\s+" | Select-Object -Skip 1 }

    $sshConfigHostList | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $resultType = [System.Management.Automation.CompletionResultType]::ParameterValue
        [System.Management.Automation.CompletionResult]::new($_, $_, $resultType, $_)
    }
}
