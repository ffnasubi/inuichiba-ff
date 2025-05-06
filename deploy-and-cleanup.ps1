# ----------------------------------------------
# Firebase Functions をデプロイし、
# GCF由来の不要なバケットを削除する統合スクリプト
# 使用例:
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffdev
# ----------------------------------------------

param (
  [string]$env = "ffdev"
)

switch ($env) {
  "ffprod" {
    $projectId = "inuichiba-ffprod"
    $configFile = "firebase.ffprod.json"
  }
  "ffdev" {
    $projectId = "inuichiba-ffdev"
    $configFile = "firebase.ffdev.json"
  }
  default {
    Write-Host "❌ 未知の環境名です: $env" -ForegroundColor Red
    exit 1
  }
}

Write-Host "`n🚀 デプロイを開始します（環境: $env）..." -ForegroundColor Cyan
gcloud config set project $projectId | Out-Null

firebase deploy --only functions --project=$projectId --config=$configFile --force

if ($LASTEXITCODE -ne 0) {
  Write-Host "❌ Firebase Functions のデプロイに失敗しました。クリーンアップを中止します。" -ForegroundColor Red
  exit 1
}

Write-Host "`n🧹 GCFバケットのクリーンアップを実行します..." -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env $env

Write-Host "`n✅ デプロイ & クリーンアップ完了！" -ForegroundColor Green
