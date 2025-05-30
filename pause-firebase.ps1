# ===============================
# Firebase 休眠スクリプト（FF + Artifact Registry + Secret manager）
# 対象: inuichiba-ffprod / inuichiba-ffdev の両方
# 目的: Firebase Functions, GCFバケット, Secrets 等の課金要因を削除して休眠状態にする
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\pause-firebase.ps1
# ===============================

$projectIds = @("inuichiba-ffprod", "inuichiba-ffdev")  # 必要に応じて片方だけ実行可能
$functions = @("webhook")
$region = "asia-northeast1"

foreach ($project in $projectIds) {
  switch ($project) {
    "inuichiba-ffprod" { $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json" }
    "inuichiba-ffdev"  { $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json" }
    default {
      Write-Host "❌ 未知の環境名です: $project" -ForegroundColor Red
      exit 1
    }
  }

  Write-Host "📦 [$project] GCF 関連バケットの確認中..."
  $bucketList = gcloud storage buckets list --project=$project --filter="name~gcf-v2-" --format="value(name)"
  if ($bucketList.Count -eq 0) {
    Write-Host "✅ [$project] GCF 関連バケットは存在しません。" -ForegroundColor Green
  } else {
    Write-Host "🧹 [$project] GCF 関連バケットを削除中..."
    foreach ($bucket in $bucketList) {
      # ffprod環境 では cloudfunctions バケットは削除しない
      if ($project -eq "inuichiba-ffprod" -and $bucket -eq "inuichiba-ffprod-cloudfunctions") {
        Write-Host "⛔ 保護対象バケット [$bucket] は削除対象外のためスキップします。" -ForegroundColor Yellow
        continue
      }

      # ✅ ffdev 環境では削除してよい（存在すれば）
      Write-Host "🗑 バケット [$bucket] を削除中..."
      gcloud storage buckets delete $bucket --project=$project --quiet
    }

    Write-Host "🧹 cleanup-gcf-buckets.ps1 による Artifact Registry 等の削除..."
    powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env $project
  }

  Write-Host "🌙 [$project] Firebase Functions 削除開始..."
  foreach ($fn in $functions) {
    Write-Host "🧹 関数 $fn を削除中..."
    firebase functions:delete $fn --region $region --force --project=$project
  }

  Write-Host "🔐 [$project] Secret Manager の全 Secret を取得中..."
  $secrets = gcloud secrets list --project=$project --format="value(name)"

  if ($secrets.Count -eq 0) {
    Write-Host "✅ [$project] 削除対象の Secrets は存在しません。"
  } else {
    foreach ($secret in $secrets) {
      Write-Host "🗑 [$project] Secret [$secret] を削除中..."
      $result = gcloud secrets delete $secret --project=$project --quiet 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ [$project] Secret [$secret] の削除に失敗しました: $result" -ForegroundColor Red
      } else {
        Write-Host "✅ [$project] Secret [$secret] を削除しました。"
      }
    }
  }

  Write-Host "🧹 [$project] Cloud Run Functions を削除中（保険的措置）..."
  $runServices = gcloud run services list --platform=managed --region=$region --project=$project --format="value(metadata.name)"
  foreach ($svc in $runServices) {
    Write-Host "🗑 Cloud Run Service [$svc] を削除中..."
    gcloud run services delete $svc --platform=managed --region=$region --project=$project --quiet
  }
}
  
Write-Host "`n✅ すべての削除処理が完了しました。これで課金対象は一時停止状態になりました。"
Write-Host "💰 請求確認はこちら → https://console.cloud.google.com/billing"