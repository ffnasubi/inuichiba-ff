# ======================================================
# ✅ Firebase 無課金化のための休眠スクリプト（pause-firebase.ps1）
# ------------------------------------------------------
# このスクリプトは GCP/Firebase の課金対象リソースを削除または無効化し、
# 利用していない時間帯の課金を最小化することを目的としています。
#
# 🔍 チェック対象一覧：
# - Firebase Functions（Gen2）: 削除
# - Firebase Secrets（Secret Manager）: 削除
# - Artifact Registry（gcf-artifacts）: 削除
# - Cloud Storage（削除禁止バケット）: 存在確認（prodのみ）
# - GCR（旧: Container Registry）: 不要イメージの確認
#
# 🛠 追加チェック推奨：
# - Cloud Build: 頻度・保存期間に注意（builds?project=...）
# - Cloud Logging: 保存期間を「1日以下」に短縮（logs/storage）
# - Pub/Sub: 未使用なら Topics/Subs を削除
# - Artifact Registryの脆弱性スキャン: [設定]から無効に（既に無効ならOK）
#
# 📌 全ての確認リンクは check-status.html に記載
# ======================================================
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\pause-firebase.ps1
# ======================================================

$projectIds = @("inuichiba-ffprod", "inuichiba-ffdev")  # 必要に応じて片方だけ実行可能
$functions = @("webhook")
$region = "asia-northeast1"

foreach ($project in $projectIds) {
  switch ($project) {
    "inuichiba-ffprod" {
      $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffprod.json"
      $envName = "ffprod"
    }
    "inuichiba-ffdev" {
      $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"
      $envName = "ffdev"
    }
    default {
      Write-Host "❌ 未知の環境名です: $project" -ForegroundColor Red
      exit 1
    }
  }  


  Write-Host "🧹 [$project] cleanup-remains.ps1 による GCF バケットと Artifact Registry 等の削除..." -ForegroundColor Green
  powershell -ExecutionPolicy Bypass -File .\cleanup-remains.ps1 -env $envName


  Write-Host "🌙 [$project] Firebase Functions 削除開始..." -ForegroundColor Green
    foreach ($fn in $functions) {
      Write-Host "🧹 関数 $fn を削除中..." -ForegroundColor DarkCyan
      firebase functions:delete $fn --region $region --force --project=$project
    }
  
  Write-Host "🔐 [$project] Secret Manager の全 Secret を取得中..." -ForegroundColor Cyan
  $secrets = gcloud secrets list --project=$project --format="value(name)"

  if ($secrets.Count -eq 0) {
    Write-Host "✅ [$project] 削除対象の Secrets は存在しません。" -ForegroundColor Cyan
  } else {
    foreach ($secret in $secrets) {
      Write-Host "🗑 [$project] Secret [$secret] を削除中..." -ForegroundColor Green
      $result = gcloud secrets delete $secret --project=$project --quiet 2>&1
      if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ [$project] Secret [$secret] の削除に失敗しました: $result" -ForegroundColor Red
      } else {
        Write-Host "✅ [$project] Secret [$secret] を削除しました。" -ForegroundColor Cyan
      }
    }
  }

  Write-Host "🧹 [$project] Cloud Run Functions を削除中（保険的措置）..." -ForegroundColor Green
  $runServices = gcloud run services list --platform=managed --region=$region --project=$project --format="value(metadata.name)"
  foreach ($svc in $runServices) {
    Write-Host "🗑 Cloud Run Service [$svc] を削除中..." -ForegroundColor DarkCyan
    gcloud run services delete $svc --platform=managed --region=$region --project=$project --quiet
  }

}
  
Write-Host "`n✅ すべての削除処理が完了しました。これで課金対象は一時停止状態になりました。" -ForegroundColor Cyan

# HTMLファイルを既定のブラウザで開く
$reportPath = "pause_firebase_check.html"
if (Test-Path $reportPath) {
    Start-Process $reportPath
    Write-Host "🔴 「pause_firebase 休眠チェック用リンク($reportPath)」をブラウザで開きました" -ForegroundColor Red 
    Write-Host "🔴 知らない間に課金されてないかしっかりチェックしてください" -ForegroundColor Red 

} else {
    Write-Host "⚠️ $reportPath が見つかりませんでした。" -ForegroundColor Yellow
}


