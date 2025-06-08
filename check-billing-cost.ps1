<#
.SYNOPSIS
GCP プロジェクトの当月の課金額（概算）を表示。

.PARAMETER env
ffprod または ffdev（プロジェクトIDに自動変換）

.EXECUTION
powershell -ExecutionPolicy Bypass -File .\check-billing-cost.ps1 -env ffprod

.NOTES
- GCP 課金APIは月次ベースのため、1日〜当日までの累積額になります
- 実際の請求額とは最大±10%程度の差があります（推定値のため）
- ログイン済・対象プロジェクト選択済であること
	（gcloud auth list, gcloud config set project inuichiba-ffprod）

.実行方法
powershell -ExecutionPolicy Bypass -File .\check-billing-cost.ps1 -env ffprod

#>

param (
  [ValidateSet("ffprod", "ffdev")]
  [string]$env = "ffprod"
)

$projectId = "inuichiba-$env"
$billingAccountId = $(gcloud beta billing projects describe $projectId --format="value(billingAccountName)" 2>$null) -replace 'billingAccounts/', ''

if (-not $billingAccountId) {
  Write-Host "❌ プロジェクト $projectId に紐づく Billing Account が見つかりません。" -ForegroundColor Red
  exit 1
}

Write-Host "📡 課金情報を取得中（$projectId / Billing Account: $billingAccountId）..." -ForegroundColor Cyan

# 当月の開始・終了日を算出
$today = Get-Date
$startDate = $today.ToString("yyyy-MM") + "-01"
$endDate = $today.ToString("yyyy-MM-dd")

# Cloud Billing APIからコスト取得
$billingJson = gcloud beta billing accounts list --format=json | ConvertFrom-Json
$projectFilter = "project=$projectId"
$command = "gcloud beta billing accounts list --format=""value(name)"""

$costs = gcloud beta billing accounts budgets list `
  --billing-account=$billingAccountId `
  --format="json" | ConvertFrom-Json

$estimate = gcloud alpha billing accounts reports list `
  --billing-account=$billingAccountId `
  --start-time=$startDate `
  --end-time=$endDate `
  --filter="project=$projectId" `
  --format="value(project, cost)"

if (-not $estimate) {
  Write-Host "📭 課金記録はまだ存在しないか、取得できませんでした。" -ForegroundColor Yellow
  exit 0
}

Write-Host "`n💰 現在の課金状況（$env / $startDate ～ $endDate）:" -ForegroundColor Green
$estimate -split "`n" | ForEach-Object {
  $parts = $_ -split "\s+"
  if ($parts.Length -eq 2) {
    Write-Host ("📌 プロジェクト: {0}`n   合計金額: ¥{1}" -f $parts[0], [math]::Round([decimal]$parts[1], 2))
  }
}
