# cleanup-hosting-and-deploy.ps1
# hosting のキャッシュを削除し、Hosting を新しい状態で画像ファイルを登録し直す
# そのあとhostingをデプロイ
#
# 注意
# public配下のファイルは削除される
# 以下のファイルからpublicへコピーされる
# public_input/assets-hosting/images/
# public_input/assets-hosting/carousel/
#
# 実行方法
# .\cleanup-hosting-and-deploy.ps1 -env ffprod
# .\cleanup-hosting-and-deploy.ps1 -env ffdev


param (
  [ValidateSet("ffprod", "ffdev")]
  [string]$env = "ffprod"
)

# プロジェクト・設定ファイル
switch ($env) {
  "ffprod" {
    $projectId = "inuichiba-ffprod"
    $configFile = "firebase.ffprod.json"
  }
  "ffdev" {
    $projectId = "inuichiba-ffdev"
    $configFile = "firebase.ffdev.json"
  }
}

Write-Host "`n🌿 Firebase Hosting 環境: $env" -ForegroundColor Cyan
Write-Host "🔧 プロジェクトID: $projectId"
Write-Host "🗂  コンフィグファイル: $configFile`n"

# 1. public フォルダのクリーンアップ
$publicDir = "public"
if (Test-Path $publicDir) {
  Write-Host "🧹 public フォルダをクリーンアップ..."
  Remove-Item "$publicDir\*" -Recurse -Force
} else {
  New-Item -ItemType Directory -Path $publicDir | Out-Null
}

# 2. 入力元ディレクトリ
$inputBase = "public_input/assets-hosting"
$srcImages = Join-Path $inputBase "images"
$srcCarousel = Join-Path $inputBase "carousel"

if (!(Test-Path $srcImages) -or !(Test-Path $srcCarousel)) {
  Write-Host "❌ コピー元フォルダが見つかりません：$srcImages または $srcCarousel" -ForegroundColor Red
  exit 1
}

# 3. コピー処理
Write-Host "📥 images と carousel を public にコピー中..."
Copy-Item $srcImages "$publicDir\images" -Recurse -Force
Copy-Item $srcCarousel "$publicDir\carousel" -Recurse -Force

# 4. .firebase キャッシュの削除（念のため）
if (Test-Path ".firebase") {
  Write-Host "🧹 .firebase 内の hosting キャッシュを削除中..."
  Get-ChildItem ".firebase" -Recurse -Include "hosting.*.json" | Remove-Item -Force
}

# 5. デプロイ
Write-Host "🚀 Firebase Hosting にデプロイ中..."
firebase deploy --only hosting --project=$projectId --config=$configFile --force

Write-Host "`n🎉 Hosting の再構築とデプロイが完了しました！（$env）" -ForegroundColor Green
