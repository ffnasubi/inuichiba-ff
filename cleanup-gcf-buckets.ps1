# ----------------------------------------------
# GCF Gen1/Gen2 関連の不要な Cloud Storage バケットと Artifact Registry を削除
# 
# ✅ 安全指針（必ず守ってください）
# 【削除OK】
# - gcf-v2-sources-*
# - gcf-v2-uploads-*
# - gcf-sources-*
# - staging.$projectId.appspot.com
# - 明示的追加バケット:
#     - gcf-v2-uploads-$projectNumber.asia-northeast1.cloudfunctions.appspot.com
#     - gcf-v2-sources-$projectNumber-asia-northeast1
# - Artifact Registry: gcf-artifacts（再作成されるため削除OK）
#
# 【削除禁止】
# - $projectId-cloudfunctions（例: inuichiba-ffprod-cloudfunctions）
#   - Firebase Hosting・Functions Gen2の運用必須バケット
#   - 一度削除すると手動では再作成できません
#
# 使用例:
#   powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffprod
#   powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffdev
# ----------------------------------------------

param (
  [string]$env = "ffprod"
)

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

gcloud config set project $projectId | Out-Null

# 🔍 まずバケット一覧を取得
Write-Host "`n🔍 不要なバケットを検索中..." -ForegroundColor Cyan
$buckets = gcloud storage buckets list --project=$projectId --format="value(name)"
$bucketsToDelete = $buckets | Where-Object {
  $_ -match "^gcf-v2-uploads" -or
  $_ -match "^gcf-v2-sources" -or
  $_ -match "^gcf-sources" -or
  $_ -eq "staging.$projectId.appspot.com"
}

# 🔎 プロジェクト番号を取得して動的にバケット名を構築
Write-Host "🔎 プロジェクト番号を取得中..." -ForegroundColor Cyan
$projectNumber = (gcloud projects describe $projectId --format="value(projectNumber)")

# 🔽 明示的な GCF v2 バケット（uploads / sources）を環境別に追加
$explicitBuckets = @(
  "gcf-v2-uploads-$projectNumber.asia-northeast1.cloudfunctions.appspot.com",
  "gcf-v2-sources-$projectNumber-asia-northeast1"
)
foreach ($explicit in $explicitBuckets) {
  if ($buckets -contains $explicit -and -not ($bucketsToDelete -contains $explicit)) {
    Write-Host "➕ 明示的に削除対象に追加: $explicit" -ForegroundColor Cyan
    $bucketsToDelete += $explicit
  }
}


if ($bucketsToDelete.Count -eq 0) {
  Write-Host "✅ 削除対象バケットは見つかりませんでした。" -ForegroundColor Green
} else {
  foreach ($bucket in $bucketsToDelete) {
    Write-Host "🧹 中身を削除中: $bucket" -ForegroundColor Cyan
    gsutil -m rm -r "gs://$bucket/**" 2>$null

    Write-Host "🗑️ 削除中: $bucket" -ForegroundColor Yellow
    gcloud storage buckets delete "gs://$bucket" --quiet
  }
  Write-Host "`n✅ バケットのクリーンアップ完了！" -ForegroundColor Green
}


# Artifact Registry の gcf-artifacts リポジトリを削除
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
# ▼ なぜ ffprod だけチェックするのか？
# - ffprod は過去に GCF v1 でデプロイされた歴史がある
# - GCF v2 に移行した現在も、プロジェクト内部で v1 の遺産（バケット紐付け）が残っている
# - このバケット（$projectId-cloudfunctions）が存在しないと ffprod はデプロイエラーになる
# - 実際、Cloudflare Pages へ移行後も、ffprod のデプロイ時に「バケットが無い」とエラーが発生した
# - そのため「削除禁止」としてわざわざ作成し、今後も保護する方針にしている
#
# ▼ 一方、ffdev は初回から GCF v2 世代で作られており、このバケットを必要としない
# - ffdev はバケットが無くても問題なくデプロイが通る（v2 + Artifact Registryベース）
# - よって ffdev ではこのチェックは不要（意図的にスキップする）
# 
# → ffprod だけチェックするのが、運用方針として適切
if ($projectId -eq "inuichiba-ffprod") {
  Write-Host "`n🔍 削除禁止バケット（$projectId-cloudfunctions）が存在するか確認..." -ForegroundColor Cyan
  $mustExistBucket = "$projectId-cloudfunctions"
  $exists = gcloud storage buckets list --project=$projectId --format="value(name)" | Where-Object { $_ -eq $mustExistBucket }

  if ($exists) {
    Write-Host "✅ 削除禁止バケットは正常に存在します: gs://$mustExistBucket" -ForegroundColor Green
    Write-Host "URL: https://console.cloud.google.com/storage/browser/$mustExistBucket?project=$projectId" -ForegroundColor Gray
  } else {
    Write-Host "❌ 削除禁止バケットが見つかりません！復旧が必要です！" -ForegroundColor Red
    Write-Host "URL（存在しないはず）: https://console.cloud.google.com/storage/browser/$mustExistBucket?project=$projectId" -ForegroundColor Red
  }
} else {
  Write-Host "`n🔍 [$projectId] では削除禁止バケットの存在チェックはスキップします（ffprodのみ実行）" -ForegroundColor Yellow
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

# ✅ Artifact Registry の gcf-artifacts 確認
Write-Host "`n🔍 Artifact Registry の gcf-artifacts が存在するか確認..." -ForegroundColor Cyan
$repoExists = & gcloud artifacts repositories describe gcf-artifacts --location=asia-northeast1 --project=$projectId 2>$null
if ($repoExists) {
  Write-Host "❌ gcf-artifacts がまだ存在します！削除漏れの可能性あり。" -ForegroundColor Red
  Write-Host "URL: https://console.cloud.google.com/artifacts/docker/$projectId/asia-northeast1/gcf-artifacts?project=$projectId" -ForegroundColor Red
} else {
  Write-Host "✅ gcf-artifacts は存在しません（削除済み）" -ForegroundColor Green
}
# ----------------------------------------------

# 🔎 Ghost Bucket注意
Write-Host "`n⚠️ バケットが404エラーで消えない場合、Cloud Consoleにゴーストとして表示されることがあります。" -ForegroundColor Yellow
Write-Host "→ APIやgcloudが404なら実体は存在していません。機能に影響はありません。" -ForegroundColor Yellow

Write-Host "`n✅ クリーンアップ完了！" -ForegroundColor Green
