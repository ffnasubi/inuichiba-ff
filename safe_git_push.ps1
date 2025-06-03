# safe_git_push.ps1
# gitのソース登録を安全に自動実行する（競合が起きたら中断する）
# 
# 実行方法
# cd D:\nasubi\inuichiba_ff
# .\safe_git_push.ps1
# もし実行できなかったら最初の一回だけ以下を実行
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


Write-Host "`n🔍 現在のブランチを確認中..." -ForegroundColor Yellow
$branch = git rev-parse --abbrev-ref HEAD
Write-Host "📍 現在のブランチ: $branch" -ForegroundColor Cyan

# ⛔️ ffmain以外なら中断
if ($branch -ne "ffmain") {
    Write-Host "`n⚠️ ブランチが 'ffmain' ではありません。現在のブランチ: '$branch'" -ForegroundColor Red
    Write-Host "🚫 'ffmain' ブランチでのみ push 可能です。中止します。" -ForegroundColor Red
    exit 1
}

# 🔄 リモートと差分チェック
Write-Host "`n🔄 リモートと差分をチェックします（fetch + diff）..." -ForegroundColor Yellow
git fetch origin
$remoteDiff = git log HEAD..origin/$branch --oneline

if ($remoteDiff) {   
		Write-Host "⚠️ ローカルとGitHubに差分があります。" -ForegroundColor Yellow
    $conflicts = git diff --name-only --diff-filter=U

		if ($conflicts) {
      Write-Host "🔍 競合の可能性のあるファイル一覧：" -ForegroundColor Yellow
      foreach ($file in $conflicts) {
        Write-Host "📛 $file" -ForegroundColor Magenta
      }
		} else {
    	Write-Host "差分は見つけられませんでしたので変更のあるファイル一覧を表示します" -ForegroundColor Green
			$diffs = git diff --name-only
      if ($diffs) {
				foreach ($diff in $diffs) {
        	Write-Host "📛 $diff" -ForegroundColor Magenta
      	}
			}
		}
		
		Write-Host "`n📌 競合が起きたときの対処方法：" -ForegroundColor Cyan
    Write-Host "1. 上記ファイルを手動で修正（<<<<<<< などを削除）" -ForegroundColor DarkCyan
    Write-Host "2. git add <ファイル名>" -ForegroundColor DarkCyan
    Write-Host "3. git rebase --continue" -ForegroundColor DarkCyan
    Write-Host "4. git push origin $branch" -ForegroundColor DarkCyan
		exit 1	
}


Write-Host "`n📦 変更内容を確認中..." -ForegroundColor Yellow
git status

Write-Host "`n🗂 変更のあるファイル一覧:" -ForegroundColor Yellow
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


# 📝 コミットメッセージ入力
Write-Host "`n🔸 コミットメッセージを入力してください：" -ForegroundColor Cyan
$commitMessage = Read-Host

# ✅ 実行確認
Write-Host "`n⚠️ 続けて git add -A → commit → push を実行しますか？（Y/N）" -ForegroundColor Red
$confirm = Read-Host

if ($confirm -eq "Y" -or $confirm -eq "y") {
    Write-Host "`n📥 git add -A を実行します..." -ForegroundColor DarkCyan
    git add -A

		Write-Host "📝 git commit を実行します..." -ForegroundColor DarkCyan
    git commit -m $commitMessage

    Write-Host "🚀 git push origin ffmain を実行します..." -ForegroundColor DarkCyan
    git push origin $branch

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ push に成功しました！" -ForegroundColor Green
    } else {
        Write-Host "`n❌ push に失敗しました。" -ForegroundColor Red
    }
} else {
    Write-Host "`n🚫 中止しました。安心してやり直してください。" -ForegroundColor Red
}
