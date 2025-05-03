#!/bin/bash

# .env.set_secrets.sh
# Secrets を登録する
# 初回のみ実行
# chmod +x .sh/.env.set_secrets.sh
# 以降の実行方法
# Usage: ./sh/.env.set_secrets.sh [ffdev|ffprod] [--delete-old]
# 以降の実行例
# ./sh/.env.set_secrets.sh ffdev                # 開発環境へ登録
# ./sh/.env.set_secrets.sh ffprod --delete-old  # 本番環境＋古いバージョン削除

set -e

ENV=${1:-ffdev}  # default to ffdev
DELETE_OLD=false
if [[ "$2" == "--delete-old" ]]; then
  DELETE_OLD=true
fi

# Mapping project IDs and secrets files
if [[ "$ENV" == "ffdev" ]]; then
  PROJECT_ID="inuichiba-ffdev"
  ENV_PATH=".env.secrets.ffdev.txt"
elif [[ "$ENV" == "ffprod" ]]; then
  PROJECT_ID="inuichiba-ffprod"
  ENV_PATH=".env.secrets.ffprod.txt"
else
  echo "❌ Invalid environment name: use ffdev or ffprod"
  exit 1
fi

# Enable Secret Manager API (if not already)
echo "🔗 Enabling Secret Manager API for $PROJECT_ID..."
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID

# Check if secrets file exists
if [[ ! -f "$ENV_PATH" ]]; then
  echo "❌ Secrets file not found: $ENV_PATH"
  exit 1
fi

# Show existing secrets before update
echo "📋 Secrets before update:"
gcloud secrets list --project=$PROJECT_ID --format="table(name,replication.policy)"

# Read and set each secret
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  KEY=$(echo "$line" | cut -d= -f1 | xargs)
  VALUE=$(echo "$line" | cut -d= -f2- | xargs)

  if gcloud secrets describe "$KEY" --project=$PROJECT_ID &>/dev/null; then
    echo "🔁 [$KEY] exists → adding new version..."
  else
    echo "🆕 [$KEY] does not exist → creating..."
    gcloud secrets create "$KEY" --replication-policy="user-managed" --locations="asia-northeast1"  --project=$PROJECT_ID
  fi

  echo -n "$VALUE" | gcloud secrets versions add "$KEY" --data-file=- --project=$PROJECT_ID
  echo "✅ [$KEY] updated"
done < "$ENV_PATH"

# Show secrets after update
echo "\n📋 Secrets after update:"
gcloud secrets list --project=$PROJECT_ID --format="table(name,replication.policy)"

# Deploy and optionally delete old secret versions
if [ "$DELETE_OLD" = true ]; then
  echo "\n🚀 Deploying Firebase functions for $PROJECT_ID..."
  firebase deploy --only functions --project=$PROJECT_ID

  echo "\n🧹 Starting interactive cleanup of old secret versions..."
  for SECRET in $(gcloud secrets list --project=$PROJECT_ID --format="value(name)"); do
    echo "\n🔐 Secret: $SECRET"
    VERSIONS=$(gcloud secrets versions list "$SECRET" \
      --project=$PROJECT_ID \
      --sort-by="~createTime" \
      --format="value(name,state)")

    SKIPPED=false
    while IFS= read -r line; do
      VERSION=$(echo "$line" | awk '{print $1}')
      STATE=$(echo "$line" | awk '{print $2}')

      if [[ "$SKIPPED" == false && "$STATE" == "ENABLED" ]]; then
        echo "⏭ Skipping latest ENABLED version $VERSION"
        SKIPPED=true
        continue
      fi

      if [[ "$STATE" == "DESTROYED" ]]; then
        echo "☠️ Version $VERSION already DESTROYED → skipping"
        continue
      fi

      read -p "❓ Delete $SECRET version $VERSION ($STATE)? (y/N): " CONFIRM
      if [[ "$CONFIRM" == "y" ]]; then
        echo "🗑 Deleting version $VERSION of $SECRET"
        gcloud secrets versions destroy "$VERSION" --secret="$SECRET" --project=$PROJECT_ID --quiet
      else
        echo "⏭ Skipped version $VERSION"
      fi
    done <<< "$VERSIONS"
  done
fi

# Final listing of all secret versions
echo "\n📊 Final secret versions state:"
for SECRET in $(gcloud secrets list --project=$PROJECT_ID --format="value(name)"); do
  echo "\n🔎 Secret: $SECRET"
  gcloud secrets versions list "$SECRET" \
    --project=$PROJECT_ID \
    --sort-by="name" \
    --format="table(name,state,createTime)"
done

# Done
echo "\n🌟 [$ENV] Secrets update completed. You may close this terminal."
