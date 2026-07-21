# dotfiles の powershell/ 配下を順番に読み込む
$dotfilesPs = "$env:USERPROFILE\.dotfiles\windows\powershell"
Get-ChildItem "$dotfilesPs\*.ps1" | Sort-Object Name | ForEach-Object { . $_.FullName }
