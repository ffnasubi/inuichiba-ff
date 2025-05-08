# reset-hosting-channels.ps1
# 🔧 Firebase Hosting の Preview チャンネル（expire 30日）を完全削除する
# 🔐 ffdev/ffprod の切替可
# 🔁 最後に一覧を表示して確認

# 実行方法
# powershell -ExecutionPolicy Bypass -File .\reset-hosting-channels.ps1 -Env ffdev
# powershell -ExecutionPolicy Bypass -File .\reset-hosting-channels.ps1 -Env ffprod

# その後以下を実行
# firebase deploy --only hosting --config=firebase.ffdev.json --project=inuichiba-ffdev
# firebase deploy --only hosting --config=firebase.ffprod.json --project=inuichiba-ffprod


param(
  [string]$Env = "ffdev"
)

$projectMap = @{
  ffdev = "inuichiba-ffdev"
  ffprod = "inuichiba-ffprod"
}

$projectId = $projectMap[$Env]

if (-not $projectId) {
  Write-Host "❌ 無効な環境名です。-Env ffdev または ffprod を指定してください。" -ForegroundColor Red
  exit 1
}

Write-Host "🚨 [$Env] Firebase Hosting チャンネルを完全リセットします！" -ForegroundColor Yellow
Write-Host "🔍 プロジェクトID: $projectId" -ForegroundColor Gray

# チャンネル一覧取得（json形式）
$json = & firebase hosting:channel:list --project=$projectId --json | Out-String | ConvertFrom-Json

if ($json.channels.Count -eq 0) {
  Write-Host "✅ 削除対象のチャンネルはありません。" -ForegroundColor Green
  exit 0
}

foreach ($channel in $json.channels) {
  $nameParts = $channel.name -split "/"
  $site = $nameParts[1]
  $channelId = $nameParts[3]
  
  Write-Host "🗑 チャンネル削除中: $channelId (サイト: $site)" -ForegroundColor Red
  & firebase hosting:channel:delete $channelId --site=$site --project=$projectId --force
}

Write-Host "`n📋 現在のチャンネル一覧:" -ForegroundColor Yellow
firebase hosting:channel:list --project=$projectId
