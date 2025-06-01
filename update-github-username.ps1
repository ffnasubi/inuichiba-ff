# -----------------------------------------------
# GitHub リモートURLと README.md のURLを一括更新
# 実行方法: PowerShell を管理者で開き、プロジェクトルートで実行
# powershell -ExecutionPolicy Bypass -File .\update-github-username.ps1
# -----------------------------------------------

# 設定（旧・新のGitHubユーザー名）
$oldUser = "ffnasubi"
$newUser = "inuichiba"

# 対象となるディレクトリ一覧（手動で追加）
$repoDirs = @(
    "D:\nasubi\inuichiba_ff",
    "D:\nasubi\inuichiba-ffimages"
)

foreach ($dir in $repoDirs) {
    Write-Host "`n📂 処理対象: $dir" -ForegroundColor Yellow
    Set-Location $dir

    # git remote 更新
    $remoteUrl = git remote get-url origin
    if ($remoteUrl -like "*$oldUser*") {
        $newUrl = $remoteUrl -replace $oldUser, $newUser
        git remote set-url origin $newUrl
        Write-Host "✅ remote URL を変更しました: $newUrl" -ForegroundColor Green
    } else {
        Write-Host "⚠️ remote URL に $oldUser が含まれていません。スキップ。" -ForegroundColor DarkGray
    }

    # README.md 置換（存在する場合）
    $readmePath = Join-Path $dir "README.md"
    if (Test-Path $readmePath) {
        (Get-Content $readmePath) -replace $oldUser, $newUser | Set-Content $readmePath
        Write-Host "📝 README.md のURLを置換しました。" -ForegroundColor Cyan
    } else {
        Write-Host "❌ README.md が見つかりません。スキップ。" -ForegroundColor Red
    }
}

Write-Host "`n🎉 すべての処理が完了しました！" -ForegroundColor Cyan
