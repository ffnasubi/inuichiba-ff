# ----------------------------------------------
# deploy-and-cleanup.ps1
# 通常のデプロイは必ずこのスクリプトでのみ行うこと！！
# 1. あらかじめ Artifact Registry を作り、GCR を使わない(Gen2の状態にした)上で
# 2. Firebase Functions をデプロイし、
# 3. GCF由来の不要なバケットなどを削除する統合スクリプト
# 
# 特に2の前に1は必ず必要。でないと GCR が作られて Gen1 でデプロイされてしまう
# (Gen2 移行を推奨されている)
# ----------------------------------------------
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffdev
# ----------------------------------------------

param (
  [string]$env = "ffdev",
)

switch ($env) {
  "ffprod" {
    $projectId = "inuichiba-ffprod"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json"
  }
  "ffdev" {
    $projectId = "inuichiba-ffdev"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"
  }
  default {
    Write-Host "❌ 未知の環境名です: $env" -ForegroundColor Red
    exit 1
  }
}

gcloud config set project $projectId | Out-Null

Write-Host "`n🚀 Gen2にするため artifact-registry を先に作ります（環境: $env）..." -ForegroundColor Cyan
if (-Not (Test-Path ".\setup-artifact-registry.ps1")) {
  Write-Host "❌ setup-artifact-registry.ps1 が見つかりません" -ForegroundColor Red
  exit 1
}
powershell -ExecutionPolicy Bypass -File .\setup-artifact-registry.ps1 -envName $env 

Write-Host "`n🚀 デプロイを開始します（環境: $env）..." -ForegroundColor Cyan
firebase deploy --only functions --project=$projectId --force

if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Firebase Functions のデプロイに失敗しました" -ForegroundColor Red
  Write-Host "`n🧨 gcf-artifacts の削除を実行します。" -ForegroundColor Red

  $repoExists = & gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1 --project=$projectId 2>$null
  if ($repoExists) {
    gcloud artifacts repositories delete gcf-artifacts `
      --location=asia-northeast1 `
      --project=$projectId `
      --quiet
    Write-Host "✅ gcf-artifacts を削除しました" -ForegroundColor Cyan
  } else {
    Write-Host "⏭ gcf-artifacts は存在しませんでした。スキップします" -ForegroundColor Cyan
  }

  exit 1
}


Write-Host "`n🕒 gcf-artifacts などの残骸ファイルを削除する前に120秒待ちます" -ForegroundColor Yellow
Write-Host "⏳ 中止したい場合は [Ctrl + C] を押してください(残骸ファイルは削除されません)..." -ForegroundColor Yellow

for ($i = 120; $i -ge 1; $i--) {
  Write-Host -NoNewline "`r残り $i 秒..."
  Start-Sleep -Seconds 1
} 

Write-Host "`n🧹 GCFバケットと Artifact Registry などのクリーンアップを実行します..." -ForegroundColor Cyan
Write-Host   "🧹 Cloud Build / PubSub の課金源も削除/抑制します..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env $env

Write-Host "`n✅ デプロイ & クリーンアップ完了！" -ForegroundColor Green


# HTMLファイルを既定のブラウザで開く
$reportPath = "pause_firebase_check.html"
if (Test-Path $reportPath) {
    Start-Process $reportPath
    Write-Host "🔴 「pause_firebase 休眠チェック用リンク($reportPath)」をブラウザで開きました" -ForegroundColor Red 
    Write-Host "🔴 知らない間に課金されてないかしっかりチェックしてください" -ForegroundColor Red 

} else {
    Write-Host "⚠️ $reportPath が見つかりませんでした。" -ForegroundColor Yellow
}

