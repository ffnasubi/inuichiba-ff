# safe_git_push.ps1
# gitのソース登録を自動実行する
# 実行方法
# .\safe_git_push.ps1
# もし実行できなかったら最初の一回だけ以下を実行
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


Write-Host "🔸 コミットメッセージを入力してください：" -ForegroundColor Cyan
$commitMessage = Read-Host

Write-Host "`n📦 変更内容を確認中..." -ForegroundColor Yellow
$gitStatus = git status
foreach ($line in $gitStatus) {
    Write-Host $line -ForegroundColor Cyan
}

Write-Host "`n⏳ 60秒間お待ちします... じっくり内容を確認してください。" -ForegroundColor DarkGray
Start-Sleep -Seconds 60

Write-Host "`n⚠️ 続けて git add -A → commit → push を実行しますか？（Y/N）" -ForegroundColor Red
$confirm = Read-Host

if ($confirm -eq "Y" -or $confirm -eq "y") {
    Write-Host "`n📥 git add -A を実行します..." -ForegroundColor DarkCyan
    git add -A

    Write-Host "📝 git commit を実行します..." -ForegroundColor DarkCyan
    git commit -m $commitMessage

    Write-Host "🚀 git push origin ffmain を実行します..." -ForegroundColor DarkCyan
    git push origin ffmain

    Write-Host "`n✅ Push 完了！" -ForegroundColor Green
} else {
    Write-Host "`n🚫 中止しました。安心してやり直してください。" -ForegroundColor Red
}
