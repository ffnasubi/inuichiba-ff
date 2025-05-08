# wake-firebase.ps1
# ===============================
# Firebase Functions + Hosting + Secrets 復旧スクリプト
# (詳細はwake-firebase.mdと★最低限覚えとこう.txtをよむこと)
# Secrets 登録は .env.set_secrets.ps1 に一任する
# ===============================
# 前提1: firebase login / gcloud auth login が済んでいること
# firebase login
# gcloud auth login
# 前提2：PowerShellでルートから以下を実行すること(IAMロールをつけるため)
# .\reset-artifactregistry.ps1 -env ffdev
# .\reset-artifactregistry.ps1 -env ffprod
# 実行方法
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\wake-firebase.ps1

$envKeys = @("ffprod", "ffdev")  
# $projectIdMap = @{ ffprod = "inuichiba-ffprod"; ffdev = "inuichiba-ffdev" }
# $configFileMap = @{ ffprod = "firebase.ffprod.json"; ffdev = "firebase.ffdev.json" }
# $credentialsMap = @{
#     ffprod = "D:\nasubi\inuichiba_ff\deployer.ffprod.json"
#    ffdev  = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"
# }
  
foreach ($envKey in $envKeys) {
#   $projectId = $projectIdMap[$envKey]
#   $configFile = $configFileMap[$envKey]
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.$envKey.json"

    Write-Host "`n🚀 [$envKey] Secrets 再登録処理開始..." -ForegroundColor Cyan

    # Secretsの再登録（us-central1回避用に別スクリプトを呼ぶ）
    powershell -ExecutionPolicy Bypass -File .\.env.set_secrets.ps1 -Env $envKey -deleteOldVersions

    Write-Host "`n🧩 [$envKey] Firebase Functions をデプロイ中..." -ForegroundColor Cyan
		powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env $envKey

    Write-Host "🧱 [$envKey] Firebase Hosting をデプロイ中..." -ForegroundColor Cyan
		.\cleanup-hosting-and-deploy.ps1 -env $envKey

    Write-Host "✅ [$envKey] の復旧処理完了！" -ForegroundColor Green
}

Write-Host "`n🎉 全プロジェクトの復旧処理が完了しました！" -ForegroundColor Green

# 💡 タイムアウト時の再実行案内
Write-Host "`n💡 タイムアウト等で失敗した場合は、以下のコマンドを手動で実行してください：" -ForegroundColor Cyan
Write-Host "`n【inuichiba-ffprod】" -ForegroundColor Cyan
Write-Host "firebase deploy --only functions --project=inuichiba-ffprod --config=firebase.ffprod.json --force" -ForegroundColor Green
Write-Host "powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffprod" -ForegroundColor Green

Write-Host "`n【inuichiba-ffdev】" -ForegroundColor Cyan
Write-Host "firebase deploy --only functions --project=inuichiba-ffdev --config=firebase.ffdev.json --force" -ForegroundColor Green
Write-Host "powershell -ExecutionPolicy Bypass -File .\cleanup-gcf-buckets.ps1 -env ffdev" -ForegroundColor Green

Write-Host "`n👆 上記コマンドをコピペして再試行してください。" -ForegroundColor Cyan
