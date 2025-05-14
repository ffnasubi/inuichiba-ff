# ===========================================
# Firebase Functions デプロイ最低限 IAM 権限付与
# ===========================================
# 実行方法
# .\set-iam-minimum-ffdeploy.ps1 -projectId "inuichiba-ffprod"
# .\set-iam-minimum-ffdeploy.ps1 -projectId "inuichiba-ffdev"


param(
    [Parameter(Mandatory = $true)]
    [string]$projectId
)

Write-Host "`n🚀 プロジェクトID: $projectId" -ForegroundColor Cyan

# Cloud Build サービスアカウント (Cloud Build が FF をデプロイする際に使用)
$saCloudBuild = "$((gcloud projects describe $projectId --format='value(projectNumber)'))@cloudbuild.gserviceaccount.com"

# Functions のデプロイに最低限必要な IAM ロール
$requiredRoles = @(
    "roles/cloudfunctions.developer",      # Cloud Functions のデプロイ許可
    "roles/artifactregistry.writer",       # Artifact Registry 書き込み許可
    "roles/run.admin",                     # Cloud Run の管理（Gen2）
    "roles/iam.serviceAccountUser"         # 任意の SA を使うための実行権限
)

Write-Host "`n🔧 Cloud Build に IAM 権限を付与中..." -ForegroundColor Yellow
foreach ($role in $requiredRoles) {
    gcloud projects add-iam-policy-binding $projectId `
        --member "serviceAccount:$saCloudBuild" `
        --role $role `
        --quiet

    Write-Host "✅ 付与済: $role"
}

Write-Host "`n🌟 完了しました。これで FF デプロイのみ必要な IAM 最小構成です。" -ForegroundColor Green
