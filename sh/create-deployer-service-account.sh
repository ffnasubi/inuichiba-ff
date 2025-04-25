#!/bin/bash

# create-deployer-service-account.sh
# Firebase Functions デプロイ用サービスアカウントの作成＆鍵発行スクリプト (Mac/Linux用)
# --------------------------------------
# - ffdev または ffprod 用のサービスアカウントを確認または作成
# - 既存の鍵をすべて削除（使用中の鍵はスキップ）
# - 新しいJSON鍵を作成してカレントディレクトリに保存
# - サービスアカウントに roles/editor を付与
# --------------------------------------
# 実行例:
#   ./create-deployer-service-account.sh ffdev
#   ./create-deployer-service-account.sh ffprod

# パラメータ取得
ENV=${1:-ffdev}  # 指定なければ ffdev を使う

# 定数設定
PROJECT_ID="inuichiba-$ENV"
SA_NAME="$ENV-inuichiba-deployer"
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
OUTPUT_JSON="deployer.$ENV.json"

echo "🔍 プロジェクト: $PROJECT_ID"
echo "🔍 サービスアカウント: $SA_EMAIL"

# サービスアカウント存在確認
if ! gcloud iam service-accounts list --project="$PROJECT_ID" --format="value(email)" | grep -q "$SA_EMAIL"; then
  echo "🆕 サービスアカウントを新規作成中..."
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Firebase Deploy Service Account" \
    --project="$PROJECT_ID"
else
  echo "✅ サービスアカウントは既に存在します。"
fi

# roles/editor をプロジェクトレベルで付与
echo "🔐 サービスアカウントに roles/editor を付与中..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/editor"

# 既存の鍵の削除
echo "🧹 既存の鍵を取得して削除中（使用中の鍵はスキップ）..."
KEY_IDS=$(gcloud iam service-accounts keys list \
  --iam-account="$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --format="value(name.basename())")

for KEY_ID in $KEY_IDS; do
  echo "   🔻 削除: $KEY_ID"
  if ! gcloud iam service-accounts keys delete "$KEY_ID" \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --quiet 2>/dev/null; then
    echo "   ⚠️ 削除スキップ（使用中/ロック中の可能性あり）: $KEY_ID"
  fi
done

# 新しい鍵の作成
echo "🔐 新しい鍵を作成し、$OUTPUT_JSON に保存中..."
gcloud iam service-accounts keys create "$OUTPUT_JSON" \
  --iam-account="$SA_EMAIL" \
  --project="$PROJECT_ID"

# 完了メッセージ（日本語）
echo ""
echo "✅ 環境 [$ENV] 用の共通鍵を作成しました！"
echo "📌 次の環境変数を設定して使用してください:"
echo "   export GOOGLE_APPLICATION_CREDENTIALS=\"$(pwd)/$OUTPUT_JSON\""
echo ""
echo "📌 この共通鍵は以下の両方で使用可能です:"
echo "   - Firebase Functions をデプロイする場合（開発環境）:"
echo "       firebase deploy --only functions --project=inuichiba-$ENV --config=firebase.$ENV.json --force"
echo "   - gcf-artifacts を削除し IAM ロールを再付与する場合（開発環境）:"
echo "       ./reset-artifactregistry.sh $ENV"
