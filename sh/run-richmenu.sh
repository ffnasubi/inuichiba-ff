#!/bin/bash

# run-richmenu.sh
# リッチメニューを環境別に初期化する（ffdev / ffprod）
# 最初に実行すれば、自動的に古いメニューを削除して新しいリッチメニューができる
# chmod +x ./sh/run-richmenu.sh
# .sh//run-richmenu.sh
 

set -e

ENV=${1:-ffdev}  # 引数なければ ffdev が既定値
SECRETS_FILE=".env.secrets.${ENV}.txt"

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "❌ Secretsファイルが見つかりません: $SECRETS_FILE"
  exit 1
fi

echo "🔧 Secretsファイルから環境変数をロード中: $SECRETS_FILE"
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  KEY=$(echo "$line" | cut -d= -f1 | xargs)
  VALUE=$(echo "$line" | cut -d= -f2- | xargs)
  export "$KEY"="$VALUE"
done < "$SECRETS_FILE"

# GCLOUD_PROJECT をここで明示的に設定
if [[ "$ENV" == "ffdev" ]]; then
  export GCLOUD_PROJECT="inuichiba-ffdev"
elif [[ "$ENV" == "ffprod" ]]; then
  export GCLOUD_PROJECT="inuichiba-ffprod"
else
  echo "❌ 無効な環境名です: $ENV。ffdev または ffprod を指定してください"
  exit 1
fi

echo -e "\n🚀 リッチメニュー初期化を開始（環境: $ENV）..."
node functions/richmenu-manager/batchCreateRichMenu.js
