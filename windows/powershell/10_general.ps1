# PowerShell Core7でもConsoleのデフォルトエンコーディングはsjisなので必要
[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")
[System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding("utf-8")

# git logなどのマルチバイト文字を表示させるため (絵文字含む)
$env:LESSCHARSET = "utf-8"

# 音を消す
Set-PSReadlineOption -BellStyle None

# 予測インテリセンス
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
# ドロップダウン表示（デフォルトはInlineView）
# Set-PSReadLineOption -PredictionViewStyle ListView
# 1単語ずつ受け入れ（デフォルトはRightArrowで全受け入れ）
# Set-PSReadLineKeyHandler -Chord Ctrl+f -Function AcceptNextSuggestionWord

# 重複履歴無効化
Set-PSReadlineOption -HistoryNoDuplicates

Import-Module -Name Terminal-Icons
Import-Module -Name z
# タブ補完候補を予測に追加（HistoryAndPlugin設定時に有効）
# Import-Module -Name CompletionPredictor
