param (
  [string]$CredentialJsonPath = ""
)

# reset-artifactregistry.ffprod.ps1 (ffprod用) 
# Firebase Cloud Functions 用の Artifact Registry を再作成し、必要な IAM ロールを自動付与する
# .ps1はUTF-8(BOMあり)一択

# 実行方法 (管理者権限で)
# cd "D:\nasubi\inuichiba_ff"
# 実行例（管理者として PowerShell 起動後）
# ※jsonファイル名は安全のため伏字にしているので、実行時正しく記述すること
# .\reset-artifactregistry.ffprod.ps1 -CredentialJsonPath "D:\nasubi\inuichiba_ff\ffprod.inuichiba-deployer@xxxx.iam.gserviceaccount.com.json"
# Start-Sleep -Seconds 60
# firebase deploy --only functions --force
# reset-artifactregistry.ffprod.ps1 (ffprod用)
# <説明>
# 🔐 認証用 .json ファイルについて補足：
# 以下のようなファイルが存在している場合
#  **Cloud Functions 用に作成した「deployer」アカウント**を使用すること
# ✅ 使用推奨（Cloud Functions 管理用）:
#   - ffprod.inuichiba-deployer@xxxx.iam.gserviceaccount.com.json
# ❌ 使用しない（参考情報）:
#   - ffprod.firebase-adminsdk-xxxxx@～ → Firebase SDK用（自動生成）
#   - ffprod.757611015224-compute@～ → GCF実行用（自動生成）
#   - ffprod.inuichiba-ffprod@appspot.～ → GAE用（自動生成）
# <注意>
# jsonファイルは.gitignore対象だから、gitに含めちゃダメ


if (-not $CredentialJsonPath) {
  Write-Host "❌ JSON認証ファイルのパスが未指定です。-CredentialJsonPath を指定してください。" -ForegroundColor Red
  exit 1
}
# 環境変数 GOOGLE_APPLICATION_CREDENTIALS を設定
# JSON 認証ファイルのパス（サービスアカウント）をここで指定
Write-Host "🔧 環境変数 GOOGLE_APPLICATION_CREDENTIALS を設定しています..." -ForegroundColor Cyan
$env:GOOGLE_APPLICATION_CREDENTIALS = $CredentialJsonPath


# プロジェクトやリージョンなどの共通設定
$PROJECT_ID = "inuichiba-ffprod"
$REGION = "asia-northeast1"
$REPO_NAME = "gcf-artifacts"

# プロジェクト番号を取得（service-* 形式のアカウントに使用）
Write-Host "🔎 プロジェクト番号を取得中..." -ForegroundColor Cyan
$PROJECT_NUMBER = (gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# リポジトリ削除（存在していれば）
Write-Host "🚮 Artifact Registry リポジトリ [$REPO_NAME] を削除中..." -ForegroundColor Yellow
gcloud artifacts repositories delete $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --quiet

# リポジトリ再作成
Write-Host "✅ リポジトリ [$REPO_NAME] を作成中..." -ForegroundColor Green
gcloud artifacts repositories create $REPO_NAME `
  --project=$PROJECT_ID `
  --repository-format=docker `
  --location=$REGION `
  --description="For Firebase Cloud Functions builds"


# 🔻 脆弱性スキャンを明示的に無効化する処理を追加
Write-Host "`n🚫 脆弱性スキャンを無効化中..." -ForegroundColor Yellow
gcloud beta artifacts repositories update $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --clear-vulnerability-scanning


# IAM ロール付与（Cloud Build / Artifact Registry / Serverless）
Write-Host "🔐 各サービスアカウントに IAM ロールを付与中..." -ForegroundColor Cyan

$SERVICE_ACCOUNTS = @(
  "service-$PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com",
  "service-$PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com",
  "service-$PROJECT_NUMBER@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

foreach ($SA in $SERVICE_ACCOUNTS) {
  Write-Host "➡️ writer ロールを付与: $SA" -ForegroundColor DarkCyan
  gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
    --project=$PROJECT_ID `
    --location=$REGION `
    --member="serviceAccount:$SA" `
    --role="roles/artifactregistry.writer"

  Write-Host "➡️ reader ロールを付与: $SA" -ForegroundColor DarkCyan
    gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
    --project=$PROJECT_ID `
    --location=$REGION `
    --member="serviceAccount:$SA" `
    --role="roles/artifactregistry.reader"
}

# プロジェクトレベルで writer 付与（Cloud Build 用）
$CLOUD_BUILD = "$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
Write-Host "📦 プロジェクトレベルで writer ロールを付与: $CLOUD_BUILD" -ForegroundColor DarkCyan
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$CLOUD_BUILD" `
  --role="roles/artifactregistry.writer"

# プロジェクトレベルで reader 付与（Cloud Build 用）
Write-Host "📦 プロジェクトレベルで reader ロールを付与: $CLOUD_BUILD" -ForegroundColor DarkCyan
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$CLOUD_BUILD" `
  --role="roles/artifactregistry.reader"

# GCF 管理サービスアカウントに reader 付与
$GCF_ADMIN_SA = "service-$PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com"
Write-Host "👤 GCF 管理アカウントに reader ロールを付与: $GCF_ADMIN_SA" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --member="serviceAccount:$GCF_ADMIN_SA" `
  --role="roles/artifactregistry.reader"

# Cloud Functions 実行アカウント（compute@developer）
$COMPUTE_SA = "$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
Write-Host "➡️ reader 付与中: compute@developer ($COMPUTE_SA)" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME `
  --project=$PROJECT_ID `
  --location=$REGION `
  --member="serviceAccount:$COMPUTE_SA" `
  --role="roles/artifactregistry.reader"


# 🔻 脆弱性スキャンがきちんと無効化されてるか確認
Write-Host "`n🚫 脆弱性スキャンは SCANNING_DISABLED ならOK" -ForegroundColor Yellow
gcloud artifacts repositories describe gcf-artifacts `
--project=$PROJECT_ID `
--location=$REGION `
--format="value(vulnerabilityScanningConfig.enablementState)"


Write-Host "🌟 完了しました！このあと以下のコマンドを実行してください:" -ForegroundColor Green
Write-Host "   Start-Sleep -Seconds 60" -ForegroundColor Green
Write-Host "   firebase deploy --only functions --force" -ForegroundColor Green
