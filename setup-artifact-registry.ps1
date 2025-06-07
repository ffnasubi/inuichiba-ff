# ----------------------------------------------
# ✅ GCF用 Artifact Registry がなければ作成
# Artifact Registry = Firebase Functions の Dockerイメージ保管庫
# Firebase Functions のデプロイ直前に gcf-artifacts を作成することで、
# GCR の自動作成を防ぐ
# (GCR があると使われてしまい、Gen1 になってしまうため)
# 作成後は削除せず、残しておくことを推奨
# ----------------------------------------------
# powershell -ExecutionPolicy Bypass -File .\setup-artifact-registry.ps1 -envName ffprod
# powershell -ExecutionPolicy Bypass -File .\setup-artifact-registry.ps1 -envName ffdev
# ----------------------------------------------


param(
  [string]$envName = "ffprod"
)

switch ($envName) {
  "ffprod" {
    $projectId = "inuichiba-ffprod"
  }
  "ffdev" {
    $projectId = "inuichiba-ffdev"
  }
  default {
    Write-Host "❌ 未知の環境名: $envName" -ForegroundColor Red
    exit 1
  }
}

$repoName = "gcf-artifacts"
$location = "asia-northeast1"

Write-Host "`n🔍 [$projectId] に Artifact Registry [$repoName] が存在するか確認中..." -ForegroundColor Cyan

$existingRepo = gcloud artifacts repositories list `
  --project=$projectId `
  --location=$location `
  --format="value(name)" | Where-Object { $_ -like "*$repoName" }

if (-not $existingRepo) {
    Write-Host "📦 Artifact Registry [$repoName] が見つかりません。作成します..." -ForegroundColor Yellow
    gcloud artifacts repositories create $repoName `
      --repository-format=docker `
      --location=$location `
      --description="GCF Functions 用 Artifact Registry ($envName)" `
      --project=$projectId
} else {
    Write-Host "✅ すでに存在します → $existingRepo" -ForegroundColor Green
}
