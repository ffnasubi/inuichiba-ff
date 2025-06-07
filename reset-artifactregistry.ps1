# 軽量リファクタ版 reset-artifactregistry.ps1（必要なロール付与と冪等性確保）

# 以下コメントは、軽量リファクタ版作成前のものであることに留意すること（必要以上のロールが付与されてる説明有）
<#[
# reset-artifactregistry.ps1 
# 実行方法 (管理者として PowerShell 起動後）
cd D:\nasubi\inuichiba_ff
# ffdev環境
powershell -ExecutionPolicy Bypass -File .\reset-artifactregistry.ps1 -env ffdev
# ffprod環境
powershell -ExecutionPolicy Bypass -File .\reset-artifactregistry.ps1 -env ffprod

🔐 「サービスアカウントの秘密鍵 JSON（例：deployer.ffdev.json）の取得方法」
✅ 目的：
Firebase Cloud Functions デプロイ用に使う
「deployer」サービスアカウントの秘密鍵（.json）を生成する。

🪜 ステップバイステップ：GCP コンソールから取得（GUI編）
※ただcreate-deployer-service-account.ps1を実行する方が早い
🔹 ① GCPコンソールにログイン
https://console.cloud.google.com/
※対象プロジェクト（例：inuichiba-ffdev）を選択
🔹 ② 左上三メニュー →「IAMと管理」→「サービスアカウント」
🔹 ③ deployer.ffdev アカウントを探す
例：
inuichiba-deployer@xxxx.iam.gserviceaccount.com

※なければ「サービスアカウントを作成」で作れます（後述）
🔹 ④ 該当アカウントの右端「︙」→「鍵を管理」
→「鍵を追加」→「新しい鍵を作成」
→ JSON形式を選んで「作成」ボタンをクリック
  ※ ブラウザが自動的に .json ファイルをダウンロードします。

🔐 ファイル名と配置ルール（統一）
環境	ファイル名	配置場所
ffdev	deployer.ffdev.json	プロジェクトルート
ffprod	deployer.ffprod.json	プロジェクトルート

※jsonファイルは.gitignore対象だから、gitに含めちゃダメ

.SYNOPSIS
Firebase Cloud Functions 用 Artifact Registry を初期化し IAM 権限を再付与します。
ffdev / ffprod に対応（envは "ffdev" または "ffprod" のみ）。

.DESCRIPTION
- deployer.ffdev.json / deployer.ffprod.json で認証
- asia-northeast1 リージョンに gcf-artifacts を作成
- 脆弱性スキャンを無効化
- 必須サービスアカウントに writer/reader 権限を付与
- スクリプト完了後に firebase deploy を案内
#>

# ─────────────────────────────
# 🔐 付与している IAM ロールとその目的
# ─────────────────────────────
# 📄 Artifact Registry の "reader" と "writer" を両方付ける理由：
#   - writer：デプロイ時（Cloud Buildがpush）
#   - reader：実行時（Functionsがpull）
#   - 権限不足だと「イメージが見つからない」などのエラーになる。

# 📦 roles/artifactregistry.writer
# → Artifact Registry に Docker イメージを push（書き込み）するために必要。
#   - Firebase Functions デプロイ時に Cloud Build がイメージを書き込む。

# 📦 roles/artifactregistry.reader
# → Artifact Registry にある Docker イメージを pull（読み取り）するために必要。
#   - Functions 実行時にイメージを参照する全サービスで使用。

# 🏗 Cloud Build 関連アカウント
#   - $PROJECT_NUMBER@cloudbuild.gserviceaccount.com（ユーザー管理サービス）
#   - Cloud Build が Firebase Functions をビルド・デプロイするために必要。
#   - プロジェクトレベルで writer / reader 両方を付与。

# 🤖 serverless-robot-prod
#   - Firebase Cloud Functions の実行基盤サービス。
#   - Functions 実行時に Artifact Registry からイメージを取得するので reader / writer 権限が必要。

# 🤖 gcp-sa-cloudbuild
#   - Cloud Build システムアカウント（内部制御用）。
#   - イメージの生成や関数デプロイに必要な操作を行う。

# 🤖 gcp-sa-artifactregistry
#   - Artifact Registry の内部制御用サービスアカウント。
#   - 自動レプリケーションやアクセス制御に関わる。reader / writer を持たせておく。

# 👤 gcf-admin-robot
#   - GCF（Google Cloud Functions）管理アカウント。
#   - Functionsの起動・構成・更新などの管理操作で Artifact Registry への読み取りが必要。

# 👷‍♂️ compute@developer
#   - Cloud Functions や他の GCP サービスで使用される汎用実行アカウント。
#   - Function の裏で走る compute resource（特に 2nd Gen Functions）などの reader 必須。

# 🔍 注意：
#   これらのロール付与は最小限に見えて実は「Firebase Functionsを100%安定稼働させるための推奨構成」です。
#   将来的なエラー（イメージ取得失敗、ビルド失敗）を防ぐためにも、本番・開発問わず統一することがベストです。
# 

param (
  [ValidateSet("ffdev", "ffprod")]
  [string]$env = "ffdev"
)

# 固定情報
$projectFullId = "inuichiba-$env"
$credentialFile = ".\deployer.$env.json"
$region = "asia-northeast1"
$repoName = "gcf-artifacts"
$env:GOOGLE_APPLICATION_CREDENTIALS = $credentialFile

# 🔐 認証ファイル確認
if (-not (Test-Path $credentialFile)) {
  Write-Host "❌ 認証ファイルが見つかりません: $credentialFile" -ForegroundColor Red
  exit 1
}

Write-Host "🔧 GOOGLE_APPLICATION_CREDENTIALS を設定中..." -ForegroundColor Cyan
$env:GOOGLE_APPLICATION_CREDENTIALS = $credentialFile

# プロジェクト番号取得
Write-Host "🔎 プロジェクト番号を取得中..." -ForegroundColor Cyan
$projectNumber = (gcloud projects describe $projectFullId --format="value(projectNumber)")

# 必須API有効化
Write-Host "🔗 APIを有効化中..." -ForegroundColor Cyan
gcloud services enable artifactregistry.googleapis.com --project=$projectFullId
gcloud services enable cloudbuild.googleapis.com --project=$projectFullId
Start-Sleep -Seconds 10

# 旧リポジトリ削除
Write-Host "🧹 旧リポジトリ削除..." -ForegroundColor Yellow
$exists = gcloud artifacts repositories list --project=$projectFullId --location=$region --format="value(name)" | Where-Object { $_ -match $repoName }
if ($exists) {
  gcloud artifacts repositories delete $repoName --project=$projectFullId --location=$region --quiet
}

# 新リポジトリ作成
Write-Host "📦 新リポジトリ作成..." -ForegroundColor Green
gcloud artifacts repositories create $repoName `
  --project=$projectFullId `
  --repository-format=docker `
  --location=$region `
  --description="For Firebase Cloud Functions builds"

# 脆弱性スキャン無効化
Write-Host "🚫 脆弱性スキャンの無効化..." -ForegroundColor Yellow
$vulnStatus = gcloud artifacts repositories describe $repoName `
  --project=$projectFullId `
  --location=$region `
  --format="value(vulnerabilityScanningConfig.enablementState)"

if ($vulnStatus -eq "SCANNING_ENABLED") {
  gcloud beta artifacts repositories update $repoName `
    --project=$projectFullId `
    --location=$region `
    --clear-vulnerability-scanning
  Write-Host "✅ 無効化しました（OK）。" -ForegroundColor Green
} else {
  Write-Host "✅ 既に無効です（OK）。" -ForegroundColor Green
}

#  IAMロール付与（wreiter + reader）
Write-Host "🔐 IAMロールを付与中..." -ForegroundColor Cyan
$SERVICE_ACCOUNTS = @(
  "service-$projectNumber@serverless-robot-prod.iam.gserviceaccount.com",
  "service-$projectNumber@gcp-sa-cloudbuild.iam.gserviceaccount.com",
  "service-$projectNumber@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

foreach ($sa in $SERVICE_ACCOUNTS) {
  Write-Host "➡️ writer: $sa" -ForegroundColor DarkCyan
  gcloud artifacts repositories add-iam-policy-binding $repoName `
    --project=$projectFullId --location=$region `
    --member="serviceAccount:$sa" `
    --role="roles/artifactregistry.writer"

  Write-Host "➡️ reader: $sa" -ForegroundColor DarkCyan
  gcloud artifacts repositories add-iam-policy-binding $repoName `
    --project=$projectFullId --location=$region `
    --member="serviceAccount:$sa" `
    --role="roles/artifactregistry.reader"
}

# Cloud Build サービスアカウントに IAM ロールを付与
$CLOUD_BUILD = "$projectNumber@cloudbuild.gserviceaccount.com"
Write-Host "📦 Cloud Build SA に IAM ロールを付与中..." -ForegroundColor DarkCyan
gcloud projects add-iam-policy-binding $projectFullId `
  --member="serviceAccount:$CLOUD_BUILD" `
  --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding $projectFullId `
  --member="serviceAccount:$CLOUD_BUILD" `
  --role="roles/artifactregistry.reader"

# GCF管理ロボット → reader
$GCF_ADMIN = "service-$projectNumber@gcf-admin-robot.iam.gserviceaccount.com"
Write-Host "👤 GCF 管理SAに reader 権限を付与: $GCF_ADMIN" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $repoName `
  --project=$projectFullId --location=$region `
  --member="serviceAccount:$GCF_ADMIN" `
  --role="roles/artifactregistry.reader"

# Cloud Functions 実行用
$COMPUTE_SA = "$projectNumber-compute@developer.gserviceaccount.com"
Write-Host "🏃‍♂️ compute@developer に reader 権限: $COMPUTE_SA" -ForegroundColor DarkCyan
gcloud artifacts repositories add-iam-policy-binding $repoName `
  --project=$projectFullId --location=$region `
  --member="serviceAccount:$COMPUTE_SA" `
  --role="roles/artifactregistry.reader"

# スキャン状態の最終確認
Write-Host "`n🚫 脆弱性スキャンは SCANNING_DISABLED ならOK" -ForegroundColor Yellow
gcloud artifacts repositories describe $repoName `
  --project=$projectFullId `
  --location=$region `
  --format="value(vulnerabilityScanningConfig.enablementState)"

 
# ✅ 完了メッセージ
Write-Host "🌟 完了しました！このあと以下のコマンドを実行してください:" -ForegroundColor Cyan
Write-Host "   Start-Sleep -Seconds 120" -ForegroundColor Green
