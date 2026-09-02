function cdr() {
    $dir = fd -H -t d -E .git -E node_modules | fzf
    if ($dir) { Set-Location $dir }
}

function cdz() {
    $dir = z -l | Out-String -Stream | Select-Object -Skip 3 | ForEach-Object { $_ -split " +" } | Select-String -Pattern '^[a-zA-Z].+' -Raw | fzf
    if ($dir) { Set-Location $dir }
}
