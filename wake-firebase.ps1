# wake-firebase.ps1
# ===============================
# Firebase Functions + Hosting 復旧スクリプト
# (詳細はwake-firebase.mdと★最低限覚えとこう.txtをよむこと)
# ===============================
# 前提: firebase login / gcloud auth login が済んでいること
# firebase login
# gcloud auth login
# 実行方法
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\wake-firebase.ps1


$projectIds = @("inuichiba-ffprod", "inuichiba-ffdev")
$configFileProd = "firebase.ffprod.json"
$configFileDev  = "firebase.ffdev.json"

foreach ($project in $projectIds) {
    Write-Host "🚀 [$project] Functions をデプロイ中..." -ForegroundColor Cyan

    if ($project -eq "inuichiba-ffprod") {
        firebase deploy --only functions --project=$project --config=$configFileProd
    } else {
        firebase deploy --only functions --project=$project --config=$configFileDev
    }

    Write-Host "🧱 [$project] Hosting をデプロイ中..." -ForegroundColor Cyan

    if ($project -eq "inuichiba-ffprod") {
        firebase deploy --only hosting --project=$project --config=$configFileProd
    } else {
        firebase deploy --only hosting --project=$project --config=$configFileDev
    }

    Write-Host "✅ [$project] Functions と Hosting の復旧が完了" -ForegroundColor Green
}

Write-Host "`n🎉 全プロジェクトの復旧処理が完了しました！" -ForegroundColor Green

# 💡 タイムアウト時の再実行案内
Write-Host "`n💡 タイムアウト等で失敗した場合は、以下のコマンドを手動で実行してください：" -ForegroundColor Cyan
Write-Host "`n【inuichiba-ffprod】" -ForegroundColor Cyan
Write-Host "firebase deploy --only functions --project=inuichiba-ffprod --config=firebase.ffprod.json --force" -ForegroundColor Green
Write-Host "firebase deploy --only hosting  --project=inuichiba-ffprod --config=firebase.ffprod.json --force" -ForegroundColor Green

Write-Host "`n【inuichiba-ffdev】" -ForegroundColor Cyan
Write-Host "firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force" -ForegroundColor Green
Write-Host "firebase deploy --only hosting  --project=inuichiba-ffdev --config=firebase.ffdev.json --force" -ForegroundColor Green

Write-Host "`n👆 上記コマンドをコピペして再試行してください。" -ForegroundColor Cyan
