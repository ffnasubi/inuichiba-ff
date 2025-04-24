#!/bin/bash

# reset-artifactregistry.ffprod.sh
# Firebase Cloud Functions 用 Artifact Registry 再作成と IAM ロール自動付与（ffprod用）
# 実行方法
# chmod +x .sh/reset-artifactregistry.ffprod.sh
# .sh/reset-artifactregistry.ffprod.sh
 

set -e

PROJECT_ID="inuichiba-ffprod"
REGION="asia-northeast1"
REPO_NAME="gcf-artifacts"
CREDENTIAL_PATH="./deployer.ffprod.json"

if [[ ! -f "$CREDENTIAL_PATH" ]]; then
  echo "❌ 認証ファイルが見つかりません: $CREDENTIAL_PATH"
  exit 1
fi

export GOOGLE_APPLICATION_CREDENTIALS="$CREDENTIAL_PATH"
echo "🔧 GOOGLE_APPLICATION_CREDENTIALS を設定しました"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# 旧リポジトリ削除（存在しなくても無視）
echo "🚮 リポジトリ削除: $REPO_NAME"
gcloud artifacts repositories delete "$REPO_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --quiet || true

# リポジトリ再作成
echo "✅ リポジトリ作成: $REPO_NAME"
gcloud artifacts repositories create "$REPO_NAME" \
  --project="$PROJECT_ID" \
  --repository-format=docker \
  --location="$REGION" \
  --description="For Firebase Cloud Functions builds"

# 脆弱性スキャン無効化
echo "🚫 脆弱性スキャンを無効化中..."
gcloud beta artifacts repositories update "$REPO_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --clear-vulnerability-scanning

# IAM ロール付与
SERVICE_ACCOUNTS=(
  "service-$PROJECT_NUMBER@serverless-robot-prod.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-cloudbuild.iam.gserviceaccount.com"
  "service-$PROJECT_NUMBER@gcp-sa-artifactregistry.iam.gserviceaccount.com"
)

for SA in "${SERVICE_ACCOUNTS[@]}"; do
  for ROLE in writer reader; do
    echo "➡️ $ROLE ロールを付与: $SA"
    gcloud artifacts repositories add-iam-policy-binding "$REPO_NAME" \
      --project="$PROJECT_ID" \
      --location="$REGION" \
      --member="serviceAccount:$SA" \
      --role="roles/artifactregistry.$ROLE"
  done
done

# Cloud Build サービスアカウントにプロジェクトレベルのロール付与
CLOUD_BUILD="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"
echo "📦 Cloud Build にプロジェクトロールを付与: $CLOUD_BUILD"
for ROLE in writer reader; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$CLOUD_BUILD" \
    --role="roles/artifactregistry.$ROLE"
done

# その他サービスアカウントに reader 付与
GCF_ADMIN_SA="service-$PROJECT_NUMBER@gcf-admin-robot.iam.gserviceaccount.com"
COMPUTE_SA="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

for SA in "$GCF_ADMIN_SA" "$COMPUTE_SA"; do
  echo "👤 reader 付与中: $SA"
  gcloud artifacts repositories add-iam-policy-binding "$REPO_NAME" \
    --project="$PROJECT_ID" \
    --location="$REGION" \
    --member="serviceAccount:$SA" \
    --role="roles/artifactregistry.reader"
done

# スキャン設定確認
echo "\n🚫 スキャン状態確認: SCANNING_DISABLED ならOK"
gcloud artifacts repositories describe "$REPO_NAME" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --format="value(vulnerabilityScanningConfig.enablementState)"

# 案内
cat << EOF

🌟 完了しました！次のコマンドを実行してください：
   sleep 120

✅ 開発環境へのデプロイ
   firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force

✅ 本番環境へのデプロイ
   firebase deploy --only functions --project=inuichiba-ffprod --config=firebase.ffprod.json --force
EOF
