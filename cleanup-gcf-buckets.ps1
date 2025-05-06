# ----------------------------------------------
# GCF Gen1/Gen2 関連の不要な Cloud Storage バケットを削除
# 使用例:
#   powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffprod
# ----------------------------------------------

param (
  [string]$env = "ffprod"
)

switch ($env) {
  "ffprod" { $projectId = "inuichiba-ffprod" }
  "ffdev"  { $projectId = "inuichiba-ffdev" }
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
  exit 0
}

foreach ($bucket in $bucketsToDelete) {
  Write-Host "🗑️ 削除中: $bucket" -ForegroundColor Yellow
  gcloud storage buckets delete $bucket --quiet
}

Write-Host "`n✅ クリーンアップ完了！" -ForegroundColor Green
