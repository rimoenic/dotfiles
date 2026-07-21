function ssh-fzf() {
    Select-String -Path "config" -Pattern "Host " | select-string -Pattern "\*" -NotMatch -Raw | ForEach-Object { ($_ -split ' ')[1] } | fzf
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
