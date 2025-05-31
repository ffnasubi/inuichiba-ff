# safe_git_push.ps1
# gitのソース登録を自動実行する
# 実行方法
# .\safe_git_push.ps1
# もし実行できなかったら最初の一回だけ以下を実行
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


Write-Host "`n📦 変更内容を確認中..." -ForegroundColor Yellow
$gitStatus = git status
foreach ($line in $gitStatus) {
    Write-Host $line -ForegroundColor Cyan
}

Write-Host "`n🗂 変更のあるファイル一覧（差分）:" -ForegroundColor Yellow
$diffFiles = git diff --name-only
if ($diffFiles) {
    foreach ($file in $diffFiles) {
        Write-Host "  - $file" -ForegroundColor White
    }
} else {
    Write-Host "⚠️ 差分はありません（すでにステージ済みかもしれません）" -ForegroundColor DarkGray
}

Write-Host "`n⏳ 60秒間お待ちします... じっくり内容を確認してください。" -ForegroundColor DarkGray
# ✅ 60秒間の確認タイム
for ($i = 60; $i -ge 1; $i--) {
    Write-Host "⏳ 残り $i 秒..." -NoNewline
    Start-Sleep -Seconds 1
    Write-Host "`r" -NoNewline
}

Write-Host "`n🔸 コミットメッセージを入力してください：" -ForegroundColor Cyan
$commitMessage = Read-Host


Write-Host "`n⚠️ 続けて git add -A → commit → push を実行しますか？（Y/N）" -ForegroundColor Red
$confirm = Read-Host

if ($confirm -eq "Y" -or $confirm -eq "y") {
    Write-Host "`n📥 git add -A を実行します..." -ForegroundColor DarkCyan
    git add -A

		Write-Host "📝 git commit を実行します..." -ForegroundColor DarkCyan
    git commit -m $commitMessage

    Write-Host "🚀 git push origin ffmain を実行します..." -ForegroundColor DarkCyan
    git push origin ffmain

    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n⚠️ push に失敗しました。GitHub にしかないファイルがある可能性があります。" -ForegroundColor Yellow
        Write-Host "🛠 git pull --rebase を自動実行します..." -ForegroundColor Cyan
        git pull --rebase

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ rebase に失敗しました。競合している可能性があります。git statusで競合中のファイルを一覧表示して手動で解決してください。" -ForegroundColor Red
            exit 1
        }

        Write-Host "🔁 push を再試行します..." -ForegroundColor Cyan
        git push origin ffmain

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ push 再試行も失敗しました。git statusで競合中のファイルを一覧表示して手動で解決してください。" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "`n✅ push 成功！（rebase 後）" -ForegroundColor Green
        }
    } else {
        Write-Host "`n✅ push 成功！" -ForegroundColor Green
    }    
    Write-Host "`n✅ Push 完了！" -ForegroundColor Green
} else {
    Write-Host "`n🚫 中止しました。安心してやり直してください。" -ForegroundColor Red
}
