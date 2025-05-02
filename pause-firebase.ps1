# ===============================
# Firebase 休眠スクリプト（FF + Artifact Registry + Hosting + Secret manager）
# 対象: inuichiba-ffprod / inuichiba-ffdev
# これで課金対象からはずれる
# 実行方法
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\pause-firebase.ps1
# ===============================

$projectIds = @("inuichiba-ffprod", "inuichiba-ffdev")
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

    Write-Host "🔐 Secret Manager の全 Secret を削除中..."
    $secrets = gcloud secrets list --project=$project --format="value(name)"
    foreach ($secret in $secrets) {
    Write-Host "🗑 Secret [$secret] を削除中..."
    gcloud secrets delete $secret --project=$project --quiet
}

}

Write-Host "`n✅ すべての削除処理が完了しました。これで課金対象は一時停止状態になりました。"
