# ===============================
# Firebase 休眠スクリプト（FF + Artifact Registry + Hosting + Secret manager）
# 対象: inuichiba-ffprod / inuichiba-ffdev の両方
# これで課金対象からはずれる
# 実行方法
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\pause-firebase.ps1
# ===============================

$projectIds = @("inuichiba-ffprod", "inuichiba-ffdev")  # 必要に応じて ffprod を外して実行
$functions = @("webhook")
$region = "asia-northeast1"

foreach ($project in $projectIds) {
    Write-Host "🌙 [$project] Firebase Functions 削除開始..."
    foreach ($fn in $functions) {
        Write-Host "🧹 関数 $fn を削除中..."
        firebase functions:delete $fn --region $region --force --project=$project
    }

    Write-Host "📦 Artifact Registry (gcf-artifacts) を削除中..."
    gcloud artifacts repositories delete gcf-artifacts --location=$region --project=$project --quiet

    Write-Host "🛑 Firebase Hosting を無効化中..."
    firebase hosting:disable --project=$project

    Write-Host "🚫 Hosting 全チャネルを削除中（Preview + live 含む）..."
    $channels = firebase hosting:channel:list --project=$project --json | ConvertFrom-Json
    foreach ($channel in $channels) {
        $channelId = $channel.id
        Write-Host "🗑 チャネル [$channelId] を削除中..."
        firebase hosting:channel:delete $channelId --project=$project --force
    }

    Write-Host "🔐 Secret Manager の全 Secret を削除中..."
    $secrets = gcloud secrets list --project=$project --format="value(name)"
    foreach ($secret in $secrets) {
        Write-Host "🗑 Secret [$secret] を削除中..."
        gcloud secrets delete $secret --project=$project --quiet
    }   

    Write-Host "🧹 Cloud Run Functions を削除中（保険的措置）..."
    $runServices = gcloud run services list --platform=managed --region=$region --project=$project --format="value(metadata.name)"
    foreach ($svc in $runServices) {
        Write-Host "🗑 Cloud Run Service [$svc] を削除中..."
        gcloud run services delete $svc --platform=managed --region=$region --project=$project --quiet
    }

}

Write-Host "`n✅ すべての削除処理が完了しました。これで課金対象は一時停止状態になりました。"
Write-Host "💰 請求確認はこちら → https://console.cloud.google.com/billing"