# ----------------------------------------------
# GCF Gen1/Gen2 関連の不要な Cloud Storage バケットと Artifact Registry を削除
# 使用例:
#   powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffdev
# ----------------------------------------------

param (
  [string]$env = "ffprod"
)

switch ($env) {
  "ffprod" { 
    $projectId = "inuichiba-ffprod"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json" 
  }
  "ffdev"  { 
    $projectId = "inuichiba-ffdev"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json" 
  }
  default {
    Write-Host "❌ 未知の環境名: $env" -ForegroundColor Red
    exit 1
  }
}

gcloud config set project $projectId | Out-Null

Write-Host "`n🔍 不要なバケットを検索中..." -ForegroundColor Cyan
$buckets = gcloud storage buckets list --project=$projectId --format="value(name)"
$bucketsToDelete = $buckets | Where-Object {
  $_ -like "gcf-v2-uploads*" -or
  $_ -like "gcf-v2-sources*" -or
  $_ -like "gcf-sources*" -or
  $_ -like "*functions" -or
  $_ -like "staging.$projectId.appspot.com"
}

if ($bucketsToDelete.Count -eq 0) {
  Write-Host "✅ 削除対象バケットは見つかりませんでした。" -ForegroundColor Green
} else {
  foreach ($bucket in $bucketsToDelete) {
    Write-Host "🗑️ 削除中: $bucket" -ForegroundColor Yellow
    gcloud storage buckets delete $bucket --quiet
  }
  Write-Host "`n✅ バケットのクリーンアップ完了！" -ForegroundColor Green
}

# Artifact Registry の gcf-artifacts リポジトリを削除
Write-Host "`n🔍 Artifact Registry の gcf-artifacts を削除中..." -ForegroundColor Cyan
$repoExists = & gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1 --project=$projectId 2>$null
if ($repoExists) {
  gcloud artifacts repositories delete gcf-artifacts `
    --location=asia-northeast1 `
    --project=$projectId `
    --quiet
  Write-Host "✅ gcf-artifacts を削除しました。" -ForegroundColor Green
} else {
  Write-Host "⏭ gcf-artifacts は存在しませんでした。スキップします。" -ForegroundColor Gray
}

Write-Host "`n✅ クリーンアップ完了！" -ForegroundColor Green
