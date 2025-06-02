<#
===============================================================
✅ Cloud Build / Cloud Logging / PubSub の課金抑制用スクリプト
---------------------------------------------------------------
このスクリプトは、Cloud Functions のデプロイ後に呼び出して、
以下の「見落としがちな課金源」を自動的に削除・初期化します。

🔸 削除対象リスト：
- Cloud Build によって作られるビルドアーティファクトのバケット
- Logging により保存されたログ保持ポリシー確認（削除はUIから）
  -- "pause_firebase 休眠チェック用リンク(pause-firebase-check.html)" から確認のこと
- Pub/Sub に自動生成された Topic / Subscription の削除

📌 本番環境(ffprod)は24時間稼働であるため、使わないリソースは即削除して
課金を最小限に抑えます。

🛠 実行方法：
powershell -ExecutionPolicy Bypass -File .\cleanup-postdeploy-extra.ps1 -env ffprod
===============================================================
#>

param (
  [Parameter(Mandatory=$true)]
  [ValidateSet("ffprod", "ffdev")]
  [string]$env
)

# プロジェクト設定
switch ($env) {
  "ffprod" {
    $projectId = "inuichiba-ffprod"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json"
  }
  "ffdev" {
    $projectId = "inuichiba-ffdev"
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"
  }
}

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
