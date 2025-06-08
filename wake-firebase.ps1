# wake-firebase.ps1
# Firebase Functions を復旧（起床）させるための統合スクリプト
#
# ✅ 実行順:
#   1. reset-artifactregistry.ps1 を呼び出し、gcf-artifacts を初期化
#   2. deploy-and-cleanup.ps1 を実行し、Functions を再デプロイ
#
# ✅ 目的:
#   - GCF Gen2 環境を正しく初期化
#   - Secrets / Artifact Registry / IAM を再構成
#   - 必要な関数を再デプロイして 24h起動状態に戻す
#
# ✅ 備考:
#   - reset-artifactregistry.ps1 は冪等設計で安全です
#   - secrets の再登録と deploy はこの順序で実行される必要があります
# ----------------------------------------------
# 前提: firebase login / gcloud auth login が済んでいること
# firebase login
# gcloud auth login
# ----------------------------------------------
# 実行方法
# cd D:\nasubi\inuichiba_ff
# powershell -ExecutionPolicy Bypass -File .\wake-firebase.ps1 


$envKeys = @("ffprod", "ffdev")  
# $projectIdMap = @{ ffprod = "inuichiba-ffprod"; ffdev = "inuichiba-ffdev" }
# $configFileMap = @{ ffprod = "firebase.ffprod.json"; ffdev = "firebase.ffdev.json" }
# $credentialsMap = @{
#    ffprod = "D:\nasubi\inuichiba_ff\deployer.ffprod.json"
#    ffdev  = "D:\nasubi\inuichiba_ff\deployer.ffdev.json"
# }
  
foreach ($envKey in $envKeys) {
#   $projectId = $projectIdMap[$envKey]
#   $configFile = $configFileMap[$envKey]
    $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\nasubi\inuichiba_ff\deployer.$envKey.json"

		Write-Host "`n🚀 [$envKey] IAM ロールの付与処理開始..." -ForegroundColor Cyan
    powershell -ExecutionPolicy Bypass -File .\reset-artifactregistry.ps1 -env $envKey
						
		# Write-Host "`n🚀 [$envKey] Secrets 登録処理開始..." -ForegroundColor Cyan
    # Secretsの再登録（us-central1回避用に別スクリプトを呼ぶ）
    # powershell -ExecutionPolicy Bypass -File .\.env.set_secrets.ps1 -Env $envKey -deleteOldVersions

    Write-Host "`n🧩 [$envKey] Firebase Functions をデプロイ中..." -ForegroundColor Cyan
		powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env $envKey
		
		if ($LASTEXITCODE -ne 0) {
 		 	Write-Host "❌ deploy-and-cleanup.ps1 の実行に失敗しました" -ForegroundColor Red
		} else {
    	Write-Host "✅ [$envKey] の復旧処理完了！" -ForegroundColor Green
		}
}

Write-Host "`n🎉 全プロジェクトの復旧処理が完了しました！" -ForegroundColor Green

# 💡 タイムアウト時の再実行案内
Write-Host "`n💡 タイムアウト等で失敗した場合は、以下のコマンドを手動で実行してください：" -ForegroundColor Cyan
Write-Host "`n【inuichiba-ffprod】" -ForegroundColor DarkCyan
Write-Host "powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffprod" -ForegroundColor Cyan

Write-Host "`n【inuichiba-ffdev】" -ForegroundColor DarkCyan
Write-Host "powershell -ExecutionPolicy Bypass -File .\deploy-and-cleanup.ps1 -env ffdev" -ForegroundColor Cyan

Write-Host "`n👆 上記コマンドをコピペして再試行してください。" -ForegroundColor Cyan

