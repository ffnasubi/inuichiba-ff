# cleanup-hosting-channels.ps1
# 目的: Firebase Hosting の古いチャネルを確認・削除する
# 課金対象になるので、最低でも月1回は実行すること
# 実行方法
# .\cleanup-hosting-channels.ps1 -env ffdev
# .\cleanup-hosting-channels.ps1 -env ffprod


param (
  [Parameter(Mandatory=$true)]
  [ValidateSet("ffprod", "ffdev")]
  [string]$env
)

# 環境に応じたプロジェクトID
switch ($env) {
  "ffprod" { $projectId = "inuichiba-ffprod" }
  "ffdev"  { $projectId = "inuichiba-ffdev" }
}

Write-Host "`n🔍 Firebase Hosting チャネル一覧を取得中: $projectId`n" -ForegroundColor Cyan

# firebase.json を一時的に生成（必要）
$firebaseJsonPath = "firebase.json"
Copy-Item "firebase.$env.json" $firebaseJsonPath -Force

# チャネル一覧取得
$channelList = firebase hosting:channel:list --project=$projectId --json | ConvertFrom-Json

if (-not $channelList) {
  Write-Host "⚠️ チャネル情報を取得できませんでした。" -ForegroundColor Yellow
  Remove-Item $firebaseJsonPath -Force
  exit 1
}

# live を除くチャネルを抽出
$removableChannels = $channelList.results | Where-Object { $_.name -ne "live" }

if ($removableChannels.Count -eq 0) {
  Write-Host "✅ 削除対象のチャネルはありません（live以外は存在しません）" -ForegroundColor Green
  Remove-Item $firebaseJsonPath -Force
  exit 0
}

Write-Host "`n🗑️ 以下のチャネルを削除しますか？" -ForegroundColor Yellow
$removableChannels | ForEach-Object { Write-Host " - $($_.name)" }

$confirm = Read-Host "`n続行するには Y を入力してください（他はキャンセル）"
if ($confirm -ne "Y") {
  Write-Host "❌ 中止されました。" -ForegroundColor Red
  Remove-Item $firebaseJsonPath -Force
  exit 1
}

# 削除処理
foreach ($channel in $removableChannels) {
  Write-Host "`n🧹 削除中: $($channel.name)"
  firebase hosting:channel:delete $channel.name --project=$projectId --force
}

# 後始末
Remove-Item $firebaseJsonPath -Force
Write-Host "`n✅ 完了しました！" -ForegroundColor Green

