#!/bin/bash

# reset-artifactregistry.ffdev.sh
# 有償化しかねない Firebase Cloud Functions用 Artifact Registry を初期化し IAMロールを再付与
# 実行方法
# chmod +x ./sh/reset-artifactregistry.ffdev.sh
# ./sh/reset-artifactregistry.ffdev.sh


set -e

PROJECT_ID="inuichiba-ffdev"
REGION="asia-northeast1"
REPO_NAME="gcf-artifacts"
CREDENTIAL_PATH="./deployer.ffdev.json"

if [[ ! -f "$CREDENTIAL_PATH" ]]; then
  echo "❌ 認証ファイルが見つかりません: $CREDENTIAL_PATH"
  exit 1
fi

export GOOGLE_APPLICATION_CREDENTIALS="$CREDENTIAL_PATH"
echo "🔧 GOOGLE_APPLICATION_CREDENTIALS を設定済み"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# 有効化するAPI
for api in artifactregistry.googleapis.com cloudbuild.googleapis.com; do
  echo "🔗 有効化: $api"
  gcloud services enable "$api" --project="$PROJECT_ID"
done

sleep 30  # API有効化待ち

# 旧リポジトリ削除（エラー無視）
echo "🚮 旧リポジトリ削除: $REPO_NAME"
gcloud artifacts repositories delete "$REPO_NAME" \
  --project="$PROJECT_ID" --location="$REGION" --quiet || true

# リポジトリ作成
echo "✅ 新リポジトリ作成: $REPO_NAME"
gcloud artifacts repositories create "$REPO_NAME" \
  --project="$PROJECT_ID" --repository-format=docker \
  --location="$REGION" \
  --description="For Firebase Cloud Functions builds"

# 脆弱性スキャン無効化チェック
echo "🚫 脆弱性スキャン状態確認中..."
VULN_STATUS=$(gcloud artifacts repositories describe "$REPO_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="value(vulnerabilityScanningConfig.enablementState)")

if [[ "$VULN_STATUS" == "SCANNING_ENABLED" ]]; then
  echo "⚠️ 無効化中..."
  gcloud beta artifacts repositories update "$REPO_NAME" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --clear-vulnerability-scanning
else
  echo "✅ スキャンは無効"
fi

# IAM ロール付与
SERVICE_ACCOUNTS=(
  "service-$PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

for SA in "${SERVICE_ACCOUNTS[@]}"; do
  for ROLE in writer reader; do
    echo "➡️ $ROLE ロール付与: $SA"
    gcloud artifacts repositories add-iam-policy-binding "$REPO_NAME" \
      --project="$PROJECT_ID" --location="$REGION" \
      --member="serviceAccount:$SA" \
      --role="roles/artifactregistry.$ROLE"
  done
done

# Cloud Build サービスアカウント確認とロール付与
CLOUD_BUILD="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
if gcloud iam service-accounts list --project="$PROJECT_ID" --format="value(email)" | grep -q "$CLOUD_BUILD"; then
  echo "📦 Cloud Build に IAM ロールを付与: $CLOUD_BUILD"
  for ROLE in writer reader; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
      --member="serviceAccount:$CLOUD_BUILD" \
      --role="roles/artifactregistry.$ROLE"
  done
else
  echo "⚠️ Cloud Build SA が存在しません。スキップします。"
fi

# GCF管理アカウントとComputeアカウントにreader付与
GCF_ADMIN_SA="service-$PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com"
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

for EXTRA_SA in "$GCF_ADMIN_SA" "$COMPUTE_SA"; do
  echo "👤 reader 付与中: $EXTRA_SA"
  gcloud artifacts repositories add-iam-policy-binding "$REPO_NAME" \
    --project="$PROJECT_ID" --location="$REGION" \
    --member="serviceAccount:$EXTRA_SA" \
    --role="roles/artifactregistry.reader"
done

# 完了メッセージ
echo -e "\n🌟 完了しました！以下のコマンドを実行してください："
echo "   sleep 120"
echo "   ✅ 開発環境へのデプロイ"
echo "   firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force"
echo "   ✅ 本番環境へのデプロイ"
echo "   firebase deploy --only functions --project=inuichiba-ffprod --config=firebase.ffprod.json --force"
