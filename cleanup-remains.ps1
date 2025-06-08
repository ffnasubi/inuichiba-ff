# ----------------------------------------------
# cleanup-remains.ps1
# GCF Gen1/Gen2 関連の不要なりソ-ス (Cloud Storage バケットと Artifact Registry、GCR 残骸) や 
# 課金対象を一掃
# Firebase Functions のデプロイ後や長期休眠時の後片付け用途
# 
# ★ 安全指針（必ず守ってください）
# ✅ 主な削除対象（再作成されるため削除OK）
# - Cloud Storage バケット
#     - gcf-sources-*
#     - gcf-v2-sources-*
#     - gcf-v2-uploads-*
#     - staging.$projectId.appspot.com
#     - gcf-v2-uploads-$projectNumber.asia-northeast1.cloudfunctions.appspot.com
#     - gcf-v2-sources-$projectNumber-asia-northeast1
# - Artifact Registry: 
#     - gcf-artifacts（functions デプロイ時に再作成）
# - GCR (Container Registry)
#     - asia.gcr.io/$projectId/*（旧GCF v1の残骸）
# 
# ⚠️ 削除禁止（特に ffprod は要注意）
# - Cloud Storage:
#     - $projectId-cloudfunctions（例: inuichiba-ffprod-cloudfunctions）
#       - Firebase Functions Gen2 の本番運用に必要な専用バケット
#       - 一度削除すると手動での復旧は不可能
# - 保護対象の Cloud Storage バケット:
#     - $projectId.firebasestorage.app（例: inuichiba-ffprod.firebasestorage.app）
#       - Firebase Hosting に直接は使っていなくても、
#         Cloudflare・LINE Bot 等からの画像配信で参照されることがあります
#       - 🔥 削除すると画像配信が停止し、重大な影響を与えるため削除禁止
# ❗ 安全のため、`ffprod` 環境では保護対象のバケットは除外して処理されます
# 
# - GCR（Google Container Registry）について:
#     - Firebase Functions（特に Gen1）では、内部的に GCR（asia.gcr.io/$projectId）に Docker イメージが残る場合があります
#     - これらは手動で削除しない限り永続的に残り、**ストレージ課金の対象となる可能性があります**
#     - Firebase CLI や Cloud Build の処理では自動削除されないため、**明示的な削除が推奨されます**
#     - GCR は今後 Artifact Registry に移行される予定のため、なるべく GCR を使わない構成へ
# ----------------------------------------------
#   powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env ffdev
# ----------------------------------------------

param (
  [string]$env = "ffprod"
)


# ✅ 対象プロジェクトの判定と認証設定
switch ($env) {
  "ffprod" { 
    $projectId = "inuichiba-ffprod"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json" 
  }
  "ffdev"  { 
    $projectId = "inuichiba-ffdev"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json" 
  }
  default {
    Write-Host "❌ 未知の環境名: $env" -ForegroundColor Red
    exit 1
  }
}


# プロジェクト設定を gcloud に反映
gcloud config set project $projectId | Out-Null

Write-Host "`n===========================================" -ForegroundColor Yellow
Write-Host "🧹 [$projectId] の GCF 残骸を削除中..." -ForegroundColor Yellow
Write-Host   "===========================================" -ForegroundColor Yellow

# GCR build images 削除（Firebase Functions V2 残骸）
Write-Host "`n🧱 GCR build イメージの gcf 残骸を削除中..." -ForegroundColor Cyan
$gcrImagePath = "gcr.io/$projectId/gcf"

try {
  $digests = gcloud container images list-tags $gcrImagePath `
      --project=$projectId `
      --format="value(digest)"

  if (-not $digests) {
    Write-Host "✅ GCR に残っている gcf build イメージはありません。" -ForegroundColor Green
  } else {
    foreach ($digest in $digests) {
      Write-Host "🗑 digest $($digest.Substring(0, 12))... を削除中 (build image)..." -ForegroundColor DarkCyan
      gcloud container images delete "$imagePath@$digest" `
          --project=$projectId `
          --quiet `
          --force-delete-tags
    }
    Write-Host "✅ [$projectId] の GCR の gcf build イメージをすべて削除しました。" -ForegroundColor Green
  }
}
catch {
  Write-Host "❌ [$projectId] のGCR build イメージ削除中にエラーが発生しました: $_" -ForegroundColor Red
}


# 不要バケット一覧を取得
Write-Host "`n🔍 不要なバケットを検索中..." -ForegroundColor Cyan
$buckets = gcloud storage buckets list --project=$projectId --format="value(name)"
$bucketsToDelete = $buckets | Where-Object {
  $_ -match "^gcf-v2-uploads" -or
  $_ -match "^gcf-v2-sources" -or
  $_ -match "^gcf-sources" -or
  $_ -eq "staging.$projectId.appspot.com"
}


# 🔎 プロジェクト番号を取得して動的に明示バケットを追加
Write-Host "🔎 プロジェクト番号を取得中..." -ForegroundColor Cyan
$projectNumber = (gcloud projects describe $projectId --format="value(projectNumber)")

# 🔎 明示的な gcf-v2-* バケット（uploads / sources）を追加
$explicitBuckets = @(
  "gcf-v2-uploads-$projectNumber.asia-northeast1.cloudfunctions.appspot.com",
  "gcf-v2-sources-$projectNumber-asia-northeast1"
)

# 🔎 削除対象を追加
foreach ($explicit in $explicitBuckets) {
  if ($buckets -contains $explicit -and -not ($bucketsToDelete -contains $explicit)) {
    Write-Host "➕ 明示的に削除対象に追加: $explicit" -ForegroundColor DarkCyan
    $bucketsToDelete += $explicit
  }
}


# 🧹 バケット削除
if ($bucketsToDelete.Count -eq 0) {
  Write-Host "✅ 削除対象バケットは見つかりませんでした。" -ForegroundColor Green
} else {
  foreach ($bucket in $bucketsToDelete) {
    Write-Host "🧹 バケットの中身を削除中: $bucket" -ForegroundColor Cyan
    gsutil -m rm -r "gs://$bucket/**" 2>$null

    Write-Host "🗑️ バケット削除中: $bucket" -ForegroundColor DarkCyan
    gcloud storage buckets delete "gs://$bucket" --quiet
  }
  Write-Host "`n✅ バケットのクリーンアップ完了！" -ForegroundColor Green
}


# 🏺 Artifact Registry の gcf-artifacts リポジトリを削除（リージョン: asia-northeast1）
Write-Host "`n🔍 Artifact Registry の gcf-artifacts を削除中..." -ForegroundColor Cyan
$repoExists = & gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1 --project=$projectId 2>$null
if ($repoExists) {
  gcloud artifacts repositories delete gcf-artifacts `
    --location=asia-northeast1 `
    --project=$projectId `
    --quiet
  Write-Host "✅ gcf-artifacts を削除しました。" -ForegroundColor Green
} else {
  Write-Host "⏭ gcf-artifacts は存在しませんでした。スキップします。" -ForegroundColor Gray
}


# ----------------------------------------------
# ✅ 削除禁止バケットの存在チェック（ffprod限定）
# 
# ✅ 削除禁止バケット [$projectId-cloudfunctions] の存在チェック（ffprodのみ）
#
# 🔸 このバケットは Firebase Functions (Gen2) において、
#     デプロイ中の内部的な処理で使用される場合があります（GCPの仕様は非公開）
#
# 🔸 実際、ffprod 環境ではこのバケットが存在しないとデプロイ時にエラーとなりました
#     - 「バケットが存在しない」と明示され、デプロイ失敗
#
# 🔸 一方、ffdev 環境ではこのバケットがなくても問題なく動作することが確認されています
#     - おそらく GCP の構成・世代・初期状態によって挙動が異なります
#
# 🔒 そのため、ffprod においては「保険として削除禁止」とし、
#     ffdev ではバケットが無ければそのままスキップする方針です

# 🛡️ 削除禁止バケットチェック（ffprodのみ）
if ($projectId -eq "inuichiba-ffprod") {
  Write-Host "`n🔍 削除禁止バケット [$projectId-cloudfunctions] の存在確認中..." -ForegroundColor Cyan
  $mustExistBucket = "$projectId-cloudfunctions"
  $exists = gcloud storage buckets list --project=$projectId --format="value(name)" | Where-Object { $_ -eq $mustExistBucket }

  if ($exists) {
    Write-Host "✅ 削除禁止バケット(1/2)は正常に存在します: gs://$mustExistBucket" -ForegroundColor Green
    Write-Host "URL: https://console.cloud.google.com/storage/browser/$mustExistBucket?project=$projectId" -ForegroundColor Green
  } else {
    Write-Host "❌ 削除禁止バケット(1/2)が見つかりません！復旧が必要です！" -ForegroundColor Red
    Write-Host "URL（存在しないはず）: https://console.cloud.google.com/storage/browser/$mustExistBucket?project=$projectId" -ForegroundColor Red
  }

  # 🔍 firebasestorage.app バケットの保護確認
  $mustExistBucket2 = "$projectId.firebasestorage.app"
  $exists2 = gcloud storage buckets list --project=$projectId --format="value(name)" | Where-Object { $_ -eq $mustExistBucket2 }

  if ($exists2) {
    Write-Host "`n✅ 削除禁止バケット(2/2)は正常に存在します: gs://$mustExistBucket2" -ForegroundColor Green
    Write-Host "URL: https://console.cloud.google.com/storage/browser/$mustExistBucket2?project=$projectId" -ForegroundColor Green
  } else {
    Write-Host "❌ firebasestorage.app バケットが見つかりません！削除済み or 利用不可状態の可能性あり" -ForegroundColor Red
  }
} else {
  Write-Host "`n🔍 [$projectId] では削除禁止バケットの存在チェックはスキップします（ffprodのみ実行）" -ForegroundColor DarkCyan
}

# ✅ ⚠️ ゴーストバケット表示について
# - Cloud Console 上に gcf-v2-uploads-* や gcf-v2-sources-* が表示されることがあります
# - しかし、gcloud storage buckets delete で 404 が返る場合は実体はすでに消えています
# - この状態は「UIキャッシュやインデックスラグ」による見た目の残骸です
# - 機能に影響はなく、操作上は放置して問題ありません
# - ※気になるなら gcloud storage buckets delete で手動確認した記録を残すこと(404ならGCP上には存在しない)
#   → gcloud storage buckets delete "gs://gcf-v2-uploads-757611015224-asia-northeast1" --quiet
#   → gcloud storage buckets delete "gs://gcf-v2-sources-757611015224-asia-northeast1" --quiet
#   → gcloud storage buckets delete "gs://gcf-v2-uploads-412413670174-asia-northeast1" --quiet
#   → gcloud storage buckets delete "gs://gcf-v2-sources-412413670174-asia-northeast1" --quiet

# - この後以下を実行して0ならホントに存在しない
#   → gcloud storage buckets list --project=inuichiba-ffprod --filter="name:gcf-v2-uploads-757611015224-asia-northeast1"
#   → gcloud storage buckets list --project=inuichiba-ffprod --filter="name:gcf-v2-sources-757611015224-asia-northeast1"
#   → gcloud storage buckets list --project=inuichiba-ffdev  --filter="name:gcf-v2-uploads-412413670174-asia-northeast1"
#   → gcloud storage buckets list --project=inuichiba-ffdev  --filter="name:gcf-v2-sources-412413670174-asia-northeast1"

# ✅ gcf-v2-* 系の削除確認
Write-Host "`n🔍 不要な gcf-v2-* バケットが残っていないか確認..." -ForegroundColor Cyan
# ✅ ⚠️ ffdev はバケットが完全に0の場合、filterに対してWARNINGが出ます
# - 実害はなく「nameフィールドがないからfilterが効かない」と言ってるだけ
# - Listed 0 items が出ていれば正常動作
# - ビビらなくてOK
$remainingV2Buckets = gcloud storage buckets list --project=$projectId --format="value(name)" | Where-Object { $_ -like "gcf-v2-*" }

if ($remainingV2Buckets.Count -eq 0) {
  Write-Host "✅ gcf-v2-* バケットはすべて削除済みです。" -ForegroundColor Green
} else {
  Write-Host "❌ 残っている gcf-v2-* バケット:" -ForegroundColor Red
  $remainingV2Buckets | ForEach-Object { Write-Host " - gs://$_" -ForegroundColor Red }
}


# 🏺 Artifact Registry の gcf-artifacts 存在チェック（削除後確認）
Write-Host "`n🔍 Artifact Registry の gcf-artifacts が存在するか確認..." -ForegroundColor Cyan
$repoExists = & gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1 --project=$projectId 2>$null
if ($repoExists) {
  Write-Host "❌ gcf-artifacts がまだ存在します！削除漏れの可能性あり。" -ForegroundColor Red
  Write-Host "URL: https://console.cloud.google.com/artifacts/docker/$projectId/asia-northeast1/gcf-artifacts?project=$projectId" -ForegroundColor Red
} else {
  Write-Host "✅ gcf-artifacts は存在しません（削除済み）(OK)" -ForegroundColor Green
}


# ----------------------------------------------

# 🔎 Ghost Bucket注意
Write-Host "`n⚠️ バケットが404エラーで消えない場合、Cloud Consoleにゴーストとして表示されることがあります。" -ForegroundColor Yellow
Write-Host "→ APIやgcloudが404なら実体は存在していません。機能に影響はありません。" -ForegroundColor Yellow

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "✅ [$projectId] の GCF 残骸削除が完了しました！" -ForegroundColor Cyan
Write-Host   "=====================================================" -ForegroundColor Cyan

Write-Host "`n以下の処理は休眠処理(pause-firebase.ps1)には不要だが、デプロイには必要。面倒なのでここに含める"  -ForegroundColor DarkCyan


<#
===============================================================
✅ Cloud Build / Cloud Logging / PubSub の課金抑制
---------------------------------------------------------------
このスクリプトは、Cloud Functions のデプロイ後に呼び出して、
以下の「見落としがちな課金源」を自動的に削除・初期化します。

🔸 削除対象リスト：
- Cloud Build によって作られるビルドアーティファクトのバケット
- Logging により保存されたログ保持ポリシー確認（削除はUIからのみ実行可能）
  -- "pause_firebase 休眠チェック用リンク(pause-firebase-check.html)" から確認のこと
- Pub/Sub に自動生成された Topic / Subscription の削除

📌 本番環境(ffprod)は24時間稼働であるため、使わないリソースは即削除して
課金を最小限に抑えます。
===============================================================
#>

# Cloud Build アーティファクトバケットの削除（存在する場合）
Write-Host "`n🔍 [$projectId] Cloud Build アーティファクト用 GCS バケットの削除を試みます..." -ForegroundColor Cyan
$buildBuckets = gcloud storage buckets list --project=$projectId --format="value(name)" | Where-Object { $_ -like "cloudbuild-artifacts*" }
foreach ($bucket in $buildBuckets) {
  Write-Host "🗑️ バケット $bucket を削除中..." -ForegroundColor DarkCyan
  gsutil -m rm -r "gs://$bucket/**" 2>$null
  gcloud storage buckets delete "gs://$bucket" --quiet
}
if ($buildBuckets.Count -eq 0) {
  Write-Host "✅ Cloud Build アーティファクトバケットは存在しません。" -ForegroundColor Green
}

# Pub/Sub Topics および Subscriptions の削除
Write-Host "`n🔍 [$projectId] Pub/Sub Topics / Subscriptions を削除します（未使用時のみ）..." -ForegroundColor Cyan
$topics = gcloud pubsub topics list --project=$projectId --format="value(name)"
foreach ($topic in $topics) {
  Write-Host "🧨 トピック削除: $topic" -ForegroundColor Yellow
  gcloud pubsub topics delete $topic --project=$projectId --quiet
}

$subs = gcloud pubsub subscriptions list --project=$projectId --format="value(name)"
foreach ($sub in $subs) {
  Write-Host "🧨 サブスクリプション削除: $sub" -ForegroundColor Yellow
  gcloud pubsub subscriptions delete $sub --project=$projectId --quiet
}

Write-Host "`n✅ [$projectId] の課金源削除スクリプトが完了しました。" -ForegroundColor Green


