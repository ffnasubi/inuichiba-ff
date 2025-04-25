#!/bin/bash

# reset-artifactregistry.sh
# Firebase Cloud Functions 用 Artifact Registry を初期化し、IAMロールを付与する (Mac/Linux対応・完全自動版)
# 実行方法
# 開発環境
# ./reset-artifactregistry.sh ffdev
# 本番環境
# ./reset-artifactregistry.sh ffprod


# --- パラメータ受け取り ---
ENV=${1:-ffdev}
PROJECT_ID="inuichiba-$ENV"
REGION="asia-northeast1"
REPO_NAME="gcf-artifacts"
CREDENTIALS_FILE="deployer.$ENV.json"

echo "🔧 対象プロジェクト: $PROJECT_ID"
echo "🔧 リージョン: $REGION"

# --- 認証ファイルチェック ---
if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "❌ 認証ファイルが見つかりません: $CREDENTIALS_FILE"
  echo "🔴 まず create-deployer-service-account.sh を実行して鍵を作成してください。"
  exit 1
fi

# --- 認証設定 ---
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/$CREDENTIALS_FILE"
echo "✅ 認証ファイルを設定しました: $GOOGLE_APPLICATION_CREDENTIALS"

# --- 必要なAPIを有効化 ---
echo "🔗 必要なAPI (Artifact Registry, Cloud Build) を有効化中..."
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID

# --- 少し待機 ---
echo "⏳ API反映のため30秒待機中..."
sleep 30

# --- 既存リポジトリ削除 ---
echo "🚮 旧リポジトリ [$REPO_NAME] を削除中..."
gcloud artifacts repositories delete $REPO_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --quiet

# --- 新リポジトリ作成 ---
echo "✅ 新リポジトリ [$REPO_NAME] を作成中..."
gcloud artifacts repositories create $REPO_NAME \
  --project=$PROJECT_ID \
  --repository-format=docker \
  --location=$REGION \
  --description="For Firebase Cloud Functions builds"

# --- 脆弱性スキャン無効化 ---
echo "🚫 脆弱性スキャンの状態を確認中..."
VULN_STATUS=$(gcloud artifacts repositories describe $REPO_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --format="value(vulnerabilityScanningConfig.enablementState)")

if [ "$VULN_STATUS" = "SCANNING_ENABLED" ]; then
  echo "⚠️ スキャンが有効なので無効化します..."
  gcloud beta artifacts repositories update $REPO_NAME \
    --project=$PROJECT_ID \
    --location=$REGION \
    --clear-vulnerability-scanning
else
  echo "✅ 脆弱性スキャンは既に無効です。"
fi

# --- IAMロール付与 ---
echo "🔐 IAMロールを付与中..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

SERVICE_ACCOUNTS=(
  "service-$PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

for SA in "${SERVICE_ACCOUNTS[@]}"; do
  echo "➡️ writer/reader: $SA"
  gcloud artifacts repositories add-iam-policy-binding $REPO_NAME \
    --project=$PROJECT_ID --location=$REGION \
    --member="serviceAccount:$SA" \
    --role="roles/artifactregistry.writer"

  gcloud artifacts repositories add-iam-policy-binding $REPO_NAME \
    --project=$PROJECT_ID --location=$REGION \
    --member="serviceAccount:$SA" \
    --role="roles/artifactregistry.reader"
done

# --- Cloud Build SA ---
CLOUD_BUILD="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
echo "📦 Cloud Build SA に IAM ロールを付与中..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$CLOUD_BUILD" \
  --role="roles/artifactregistry.writer"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$CLOUD_BUILD" \
  --role="roles/artifactregistry.reader"

# --- GCF 管理アカウント ---
GCF_ADMIN="service-$PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com"
echo "👤 GCF 管理SAに reader 権限を付与: $GCF_ADMIN"
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME \
  --project=$PROJECT_ID --location=$REGION \
  --member="serviceAccount:$GCF_ADMIN" \
  --role="roles/artifactregistry.reader"

# --- Compute 実行SA ---
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"
echo "🏃‍♂️ compute@developer に reader 権限: $COMPUTE_SA"
gcloud artifacts repositories add-iam-policy-binding $REPO_NAME \
  --project=$PROJECT_ID --location=$REGION \
  --member="serviceAccount:$COMPUTE_SA" \
  --role="roles/artifactregistry.reader"

# --- スキャン状態再確認 ---
echo ""
echo "🚫 脆弱性スキャン状態（SCANNING_DISABLED ならOK）:"
gcloud artifacts repositories describe $REPO_NAME \
  --project=$PROJECT_ID \
  --location=$REGION \
  --format="value(vulnerabilityScanningConfig.enablementState)"

# --- 完了メッセージ ---
echo ""
echo "🌟 完了しました！Firebase Functions をデプロイするには以下を実行してください:"
echo "   firebase deploy --only functions --project=$PROJECT_ID --config=firebase.$ENV.json --force"
