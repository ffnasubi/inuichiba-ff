# PowerShell スクリプト: run-monthly-cleanup.ps1
# cleanup-hosting-channels.ps1 を実行し、ログを指定フォルダに保存
# Windowsのタスクスケジューラに設定してるので、
# 毎月1日,15日の9時と9時5分に実行されてログに保存される
# ログ保存先は.backup/log

param (
  [Parameter(Mandatory = $true)]
  [ValidateSet("ffprod", "ffdev")]
  [string]$env
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$logDir = ".backup/log"
$logFile = "$logDir/cleanup-hosting-channels-$env-$timestamp.txt"

if (-not (Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# 実行＆ログ保存
.\cleanup-hosting-channels.ps1 -env $env *>&1 | Tee-Object -FilePath $logFile

Write-Host "`n📝 ログ保存完了: $logFile" -ForegroundColor Cyan
