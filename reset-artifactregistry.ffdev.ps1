# reset-artifactregistry.ffdev.ps1 (ffdev用)
# Firebase Cloud Functions 用 Artifact Registry を初期化し、IAMロールを付与する
# 🔒 このファイルは UTF-8 (BOM付き) で保存してください
# 🚀 実行前に課金アカウントがリンクされていることを確認！

# 実行例（PowerShell管理者）:
# cd "D:\nasubi\inuichiba_ff"
# .\reset-artifactregistry.ffdev.ps1
# Start-Sleep -Seconds 120
# firebase deploy --only functions --force

# 🔐 ローカル固定用の認証ファイル（GCPサービスアカウント鍵）
$CredentialJsonPath = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"

if (-not (Test-Path $CredentialJsonPath)) {
  Write-Host "❌ 認証ファイルが見つかりません: $CredentialJsonPath" -ForegroundColor Red
  exit 1
}

Write-Host "🔧 GOOGLE_APPLICATION_CREDENTIALS を設定中..." -ForegroundColor Cyan
$env:GOOGLE_APPLICATION_CREDENTIALS = $CredentialJsonPath

# プロジェクト構成
$PROJECT_ID = "inuichiba-ffdev"
$REGION = "asia-northeast1"
$REPO_NAME = "gcf-artifacts"

# プロジェクト番号を取得
Write-Host "🔎 プロジェクト番号を取得中..." -ForegroundColor Cyan
$PROJECT_NUMBER = (gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# 必要APIを明示的に有効化
Write-Host "🔗 必要なAPI (Artifact Registry, Cloud Build) を有効化中..." -ForegroundColor Cyan
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID

# 少し待機してAPI反映を安定化
Write-Host "⏳ APIの有効化を反映させるため待機中..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 既存のリポジトリを削除（存在しなくてもOK）
Write-Host "🚮 旧リポジトリ [$REPO_NAME] を削除中..." -ForegroundColor Yellow
gcloud artifacts repositories delete $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --quiet

# リポジトリ再作成
Write-Host "✅ 新リポジトリ [$REPO_NAME] を作成中..." -ForegroundColor Green
gcloud artifacts repositories create $REPO_NAME `
  --project=$PROJECT_ID `
  --repository-format=docker `
  --location=$REGION `
  --description="For Firebase Cloud Functions builds"

# 🔍 脆弱性スキャンの状態確認 → 有効な場合のみ無効化
Write-Host "🚫 脆弱性スキャンの状態を確認中..." -ForegroundColor Yellow
$vulnStatus = gcloud artifacts repositories describe $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --format="value(vulnerabilityScanningConfig.enablementState)"

if ($vulnStatus -eq "SCANNING_ENABLED") {
  Write-Host "⚠️ 有効なので無効化します..." -ForegroundColor Red
  gcloud beta artifacts repositories update $REPO_NAME `
    --project=$PROJECT_ID `
    --location=$REGION `
    --clear-vulnerability-scanning
} else {
  Write-Host "✅ 脆弱性スキャンは無効(OK)です。" -ForegroundColor Green
}

# IAMロールの付与（主要サービスアカウント）
Write-Host "🔐 IAMロールを付与中..." -ForegroundColor Cyan

$SERVICE_ACCOUNTS = @(
  "service-$PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com",
  "service-$PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com",
  "service-$PROJECT_NUMBER@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

foreach ($SA in $SERVICE_ACCOUNTS) {
  Write-Host "➡️ writer: $SA" -ForegroundColor DarkCyan
  gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
    --project=$PROJECT_ID --location=$REGION `
    --member="serviceAccount:$SA" `
    --role="roles/artifactregistry.writer"

  Write-Host "➡️ reader: $SA" -ForegroundColor DarkCyan
  gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
    --project=$PROJECT_ID --location=$REGION `
    --member="serviceAccount:$SA" `
    --role="roles/artifactregistry.reader"
}

# Cloud Build サービスアカウント存在確認と付与
$CLOUD_BUILD = "$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
Write-Host "📦 Cloud Build SA の存在確認中..." -ForegroundColor Cyan
$cbExists = gcloud iam service-accounts list --project=$PROJECT_ID --format="value(email)" | Select-String $CLOUD_BUILD

if ($cbExists) {
  Write-Host "📦 Cloud Build SA に IAM ロールを付与中..." -ForegroundColor DarkCyan
  gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$CLOUD_BUILD" `
    --role="roles/artifactregistry.writer"
  gcloud projects add-iam-policy-binding $PROJECT_ID `
    --member="serviceAccount:$CLOUD_BUILD" `
    --role="roles/artifactregistry.reader"
} else {
  Write-Host "⚠️ Cloud Build SA がまだ存在しません。スキップします。" -ForegroundColor Yellow
}

# gcf-admin-robot に reader 権限
$GCF_ADMIN_SA = "service-$PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com"
Write-Host "👤 GCF 管理SAに reader 権限を付与: $GCF_ADMIN_SA" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
  --project=$PROJECT_ID --location=$REGION `
  --member="serviceAccount:$GCF_ADMIN_SA" `
  --role="roles/artifactregistry.reader"

# compute@developer に reader 権限
$COMPUTE_SA = "$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
Write-Host "🏃‍♂️ compute@developer に reader 権限: $COMPUTE_SA" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
  --project=$PROJECT_ID --location=$REGION `
  --member="serviceAccount:$COMPUTE_SA" `
  --role="roles/artifactregistry.reader"

# 🔻 脆弱性スキャンがきちんと無効化されてるか確認
Write-Host "`n🚫 脆弱性スキャンは SCANNING_DISABLED ならOK" -ForegroundColor Yellow
gcloud artifacts repositories describe gcf-artifacts `
--project=$PROJECT_ID `
--location=$REGION `
--format="value(vulnerabilityScanningConfig.enablementState)"

# ✅ 完了！
Write-Host "🌟 完了しました！このあと以下のコマンドを実行してください:" -ForegroundColor Green
Write-Host "   Start-Sleep -Seconds 120" -ForegroundColor Green
Write-Host "   ✅ 開発環境へのデプロイ"  -ForegroundColor DarkCyan
Write-Host "   firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force"  -ForegroundColor Green
Write-Host "   ✅ 本番環境へのデプロイ"  -ForegroundColor DarkCyan
Write-Host "   firebase deploy --only functions --project=inuichiba-ffprod --config=firebase.ffprod.json --force"  -ForegroundColor Green
